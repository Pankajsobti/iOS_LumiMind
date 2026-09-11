import Foundation
import Combine

// MARK: - MemoryMatrixViewModel
//
// Owns all gameplay state for the spatial-memory version of Memory Matrix:
// a square grid of tiles, a subset of which briefly highlight so the
// player can memorize their LOCATIONS, then the player must tap those
// same locations from memory. There are no pairs, no symbols, and no
// matching — the only data is `grid position -> was this highlighted?`.
//
// Submission: unchanged from the previous implementation. This
// ViewModel holds a `GameResultViewModel` and calls `submitResult(...)`
// itself the moment the session ends, so the View doesn't need to
// remember to do it.
//
// ASSUMPTION (flagging per project convention): the previous game ended
// on a 60s timeout. This version has no natural timeout, so a wrong tap
// now plays the role the timeout used to play — it ends the whole
// session and triggers submission, with the score reflecting how far
// the player got. If a wrong tap should instead just restart the
// current level, that's a small change confined to `tap(_:)`.

@MainActor
final class MemoryMatrixViewModel: ObservableObject {

    // MARK: Game phase

    enum Phase: Equatable {
        case preview      // pattern is shown; all input disabled
        case recall       // pattern hidden; player is tapping tiles
        case submitting   // session just ended, result is being submitted
        case finished(score: Int) // submission complete (or failed — see submissionErrorMessage)
    }

    // MARK: Tile model

    enum TileState: Equatable {
        case normal        // □ default appearance, nothing revealed
        case highlighted   // ■ shown only during the preview
        case correct       // ✓ tapped during recall and it was a target
        case incorrect     // ✕ tapped during recall and it was NOT a target
    }

    struct Tile: Identifiable, Equatable {
        let id: Int   // flat index: row * gridSize + col
        let row: Int
        let col: Int
        var state: TileState
    }

    // MARK: Level / difficulty progression
    //
    // Configurable in one place rather than scattered through the
    // gameplay logic. `levelProgression` is the exact table from the
    // spec (Level 1...8); `config(forLevel:)` continues the same
    // cadence indefinitely past the table (grid size +1 every 2
    // levels, target count +1 every level) so difficulty keeps
    // climbing without hardcoding every future level.

    static let levelProgression: [(gridSize: Int, targetCount: Int)] = [
        (3, 3), (3, 4),
        (4, 5), (4, 6),
        (5, 7), (5, 8),
        (6, 9), (6, 10)
    ]

    static func config(forLevel level: Int) -> (gridSize: Int, targetCount: Int) {
        precondition(level >= 1)
        if level <= levelProgression.count {
            return levelProgression[level - 1]
        }
        let levelsPerGridSize = 2
        let pairIndex = (level - 1) / levelsPerGridSize
        let subIndex = (level - 1) % levelsPerGridSize
        let baseGridSize = levelProgression[0].gridSize
        let baseTargetCount = levelProgression[0].targetCount
        let gridSize = baseGridSize + pairIndex
        let targetCount = baseTargetCount + (pairIndex * levelsPerGridSize) + subIndex
        return (gridSize, targetCount)
    }

    // MARK: Timing tunables

    /// How long the pattern stays visible before hiding. Spec calls for
    /// ~1–1.5s; kept as a single tunable rather than inlined.
    static let previewDurationSeconds: Double = 1.3
    /// Brief pause after a round is fully solved, before the next
    /// (harder) pattern appears.
    static let interRoundDelaySeconds: Double = 0.9
    /// Brief pause after a wrong tap so the player can see the error
    /// feedback before the session ends and results are submitted.
    static let errorFeedbackDelaySeconds: Double = 0.9

    // MARK: Published state

    @Published private(set) var tiles: [Tile] = []
    @Published private(set) var phase: Phase = .preview
    @Published private(set) var level: Int = 1
    @Published private(set) var gridSize: Int = MemoryMatrixViewModel.config(forLevel: 1).gridSize
    @Published private(set) var targetCount: Int = MemoryMatrixViewModel.config(forLevel: 1).targetCount
    @Published private(set) var targetsFound: Int = 0
    @Published private(set) var isInputLocked = false
    /// Briefly true right after a round is solved, so the View can show
    /// a transient success banner. Cleared when the next round starts.
    @Published private(set) var roundJustCompleted = false

    /// Whether tiles should currently respond to taps at all — combines
    /// the phase check with the transition/error lock so the View can
    /// gate hit-testing on the whole grid with one flag.
    var canInteract: Bool { phase == .recall && !isInputLocked }

    /// True once any tile in the current round has been marked wrong —
    /// lets the View show error feedback without duplicating state.
    var hasError: Bool { tiles.contains { $0.state == .incorrect } }

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    /// Whether this playthrough should be submitted with `isFitTest: true`.
    /// Preserved from the previous implementation unchanged.
    private let isFitTest: Bool

    /// The ground-truth target positions for the current round, as flat
    /// indices into a `gridSize x gridSize` grid. Generated once per
    /// round, before the preview begins, and never regenerated or
    /// mutated until the next round starts.
    private var targetPositions: Set<Int> = []

    private var gameStartedAt: Date?
    private var completedRounds = 0
    private var totalCorrectTaps = 0

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = true) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        setUpNewGame()
    }

    // MARK: - Setup

    /// Resets the whole session back to Level 1 and starts the first round.
    func setUpNewGame() {
        completedRounds = 0
        totalCorrectTaps = 0
        isInputLocked = false
        roundJustCompleted = false
        gameStartedAt = Date()
        startRound(level: 1)
    }

    /// Builds a fresh random pattern for `level`, shows it briefly, then
    /// hides it and enters the recall phase.
    private func startRound(level: Int) {
        let config = Self.config(forLevel: level)
        self.level = level
        self.gridSize = config.gridSize
        self.targetCount = config.targetCount
        self.targetsFound = 0
        self.roundJustCompleted = false

        let positions = Self.generateTargetPositions(count: config.targetCount, gridSize: config.gridSize)
        targetPositions = positions

        tiles = (0..<(config.gridSize * config.gridSize)).map { index in
            Tile(
                id: index,
                row: index / config.gridSize,
                col: index % config.gridSize,
                state: positions.contains(index) ? .highlighted : .normal
            )
        }

        phase = .preview
        isInputLocked = true

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.previewDurationSeconds * 1_000_000_000))
            self?.hidePatternAndBeginRecall()
        }
    }

    private func hidePatternAndBeginRecall() {
        guard phase == .preview else { return }
        tiles = tiles.map { tile in
            var t = tile
            t.state = .normal
            return t
        }
        phase = .recall
        isInputLocked = false
    }

    /// Picks `count` unique random positions out of a `gridSize x gridSize`
    /// grid. Uses `shuffled().prefix(...)` rather than repeated random
    /// draws so uniqueness is guaranteed with no retry loop needed.
    private static func generateTargetPositions(count: Int, gridSize: Int) -> Set<Int> {
        var allPositions = Array(0..<(gridSize * gridSize))
        allPositions.shuffle()
        return Set(allPositions.prefix(count))
    }

    // MARK: - Tap handling

    func tap(_ tile: Tile) {
        guard canInteract else { return }
        guard let index = tiles.firstIndex(where: { $0.id == tile.id }) else { return }
        guard tiles[index].state == .normal else { return } // already answered / not tappable

        if targetPositions.contains(index) {
            tiles[index].state = .correct
            targetsFound += 1
            totalCorrectTaps += 1

            if targetsFound == targetCount {
                roundSucceeded()
            }
        } else {
            tiles[index].state = .incorrect
            isInputLocked = true
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.errorFeedbackDelaySeconds * 1_000_000_000))
                self?.endGame()
            }
        }
    }

    private func roundSucceeded() {
        isInputLocked = true
        roundJustCompleted = true
        completedRounds += 1

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.interRoundDelaySeconds * 1_000_000_000))
            guard let self else { return }
            self.startRound(level: self.level + 1)
        }
    }

    // MARK: - Game over + scoring

    /// Score formula (kept intentionally simple and explicit, same spirit
    /// as the previous implementation's formula):
    ///   score = (completedRounds * 100) + (totalCorrectTaps * 10), floored at 0.
    /// Completing a full round is worth far more than any single correct
    /// tap, so the score is primarily a measure of how many levels of
    /// increasing spatial difficulty the player cleared, with correct
    /// taps within the level that ended the session still counting for
    /// something.
    private func computeScore() -> Int {
        max(0, completedRounds * 100 + totalCorrectTaps * 10)
    }

    private func endGame() {
        guard phase == .preview || phase == .recall else { return }

        let score = computeScore()
        let duration: Int
        if let gameStartedAt {
            duration = max(1, Int(Date().timeIntervalSince(gameStartedAt).rounded()))
        } else {
            duration = 0
        }

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Memory Matrix",
                category: "Memory",
                score: score,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: score)
        }
    }
}