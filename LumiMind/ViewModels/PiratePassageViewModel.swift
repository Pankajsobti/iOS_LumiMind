import Foundation
import Combine

// MARK: - PiratePassageViewModel
//
// Owns gameplay state for Pirate Passage: a grid with a start tile, an
// end/treasure tile, and obstacle tiles. Each level's grid is generated
// by first carving a guaranteed-solvable path via randomized DFS, then
// scattering obstacles only on the remaining non-path tiles — so every
// level is solvable by construction. The user taps adjacent open tiles
// to build a path from start to end before a per-level timer runs out.
// Mirrors BrainShiftViewModel's conventions — View only renders
// published state and forwards taps into `tapTile(at:)`; this
// ViewModel submits the result itself once all levels are done.

@MainActor
final class PiratePassageViewModel: ObservableObject {

    // MARK: Game phase

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    struct Position: Hashable {
        let row: Int
        let col: Int
    }

    struct GridCell: Identifiable, Equatable {
        let id: Int
        let position: Position
        let isObstacle: Bool
        let isStart: Bool
        let isEnd: Bool
    }

    private struct Level {
        let size: Int
        let cells: [GridCell]
        let start: Position
        let end: Position
        let optimalMoves: Int
        let cellLookup: [Position: GridCell]
    }

    // MARK: Tunables

    static let totalLevels = 3
    static let timePerLevelSeconds: Double = 30.0
    private static let gridSizes = [5, 6, 7]
    private static let obstacleProbability = 0.35

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var levelIndex: Int = 0
    @Published private(set) var gridSize: Int = 5
    @Published private(set) var cells: [GridCell] = []
    @Published private(set) var currentPath: [Position] = []
    @Published private(set) var movesUsed: Int = 0
    @Published private(set) var timeRemainingFraction: Double = 1.0
    @Published private(set) var lastLevelSucceeded: Bool?
    @Published private(set) var isTransitioning: Bool = false

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool
    private var levels: [Level] = []
    private var currentLevel: Level!
    private var levelStartedAt: Date?
    private var gameStartedAt: Date?
    private var levelTask: Task<Void, Never>?
    private var runningScore: Int = 0

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        setUpNewGame()
    }

    // MARK: - Setup

    func setUpNewGame() {
        levelTask?.cancel()
        runningScore = 0
        levelIndex = 0
        lastLevelSucceeded = nil
        levels = Self.gridSizes.prefix(Self.totalLevels).map { Self.generateLevel(size: $0) }
        phase = .playing
        gameStartedAt = Date()
        beginLevel(at: 0)
    }

    // MARK: - Level generation

    /// Guarantees solvability: `generatePath` performs a randomized DFS
    /// from start to end over the full (obstacle-free) grid, which is
    /// always fully connected, so a path is always found. Obstacles are
    /// then placed only on cells NOT on that discovered path, so the
    /// discovered path always remains a valid, open solution.
    private static func generateLevel(size: Int) -> Level {
        let path = generatePath(size: size)
        let pathSet = Set(path)
        let start = path.first ?? Position(row: 0, col: 0)
        let end = path.last ?? Position(row: size - 1, col: size - 1)

        var cells: [GridCell] = []
        var lookup: [Position: GridCell] = [:]
        var id = 0
        for row in 0..<size {
            for col in 0..<size {
                let position = Position(row: row, col: col)
                let isStart = position == start
                let isEnd = position == end
                let isObstacle: Bool
                if isStart || isEnd || pathSet.contains(position) {
                    isObstacle = false
                } else {
                    isObstacle = Double.random(in: 0...1) < obstacleProbability
                }
                let cell = GridCell(id: id, position: position, isObstacle: isObstacle, isStart: isStart, isEnd: isEnd)
                cells.append(cell)
                lookup[position] = cell
                id += 1
            }
        }

        return Level(
            size: size,
            cells: cells,
            start: start,
            end: end,
            optimalMoves: max(1, path.count - 1),
            cellLookup: lookup
        )
    }

    private static func generatePath(size: Int) -> [Position] {
        let start = Position(row: 0, col: 0)
        let end = Position(row: size - 1, col: size - 1)
        var visited = Set<Position>([start])
        var path = [start]

        func neighbors(of p: Position) -> [Position] {
            [(-1, 0), (1, 0), (0, -1), (0, 1)].compactMap { dr, dc in
                let np = Position(row: p.row + dr, col: p.col + dc)
                guard np.row >= 0, np.row < size, np.col >= 0, np.col < size else { return nil }
                return np
            }
        }

        func dfs() -> Bool {
            guard let current = path.last else { return false }
            if current == end { return true }
            for neighbor in neighbors(of: current).shuffled() {
                if !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    path.append(neighbor)
                    if dfs() { return true }
                    path.removeLast()
                }
            }
            return false
        }

        _ = dfs() // grid is always fully connected, so this always succeeds
        return path
    }

    // MARK: - Level lifecycle

    private func beginLevel(at index: Int) {
        guard index < levels.count else {
            endGame()
            return
        }
        levelTask?.cancel()

        levelIndex = index
        currentLevel = levels[index]
        gridSize = currentLevel.size
        cells = currentLevel.cells
        currentPath = [currentLevel.start]
        movesUsed = 0
        lastLevelSucceeded = nil
        isTransitioning = false
        levelStartedAt = Date()
        timeRemainingFraction = 1.0

        levelTask = Task { [weak self] in
            guard let self else { return }
            let steps = 30
            let stepDuration = Self.timePerLevelSeconds / Double(steps)
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                if Task.isCancelled { return }
                self.timeRemainingFraction = max(0, 1.0 - Double(step) / Double(steps))
            }
            guard !Task.isCancelled else { return }
            self.completeLevel(success: false)
        }
    }

    // MARK: - Tap handling

    /// Invalid taps (out-of-grid positions via a stale view, obstacle
    /// tiles, or non-adjacent tiles) are simply ignored — they never
    /// register as a move and never crash.
    func tapTile(at position: Position) {
        guard phase == .playing, !isTransitioning else { return }
        guard let cell = currentLevel.cellLookup[position], !cell.isObstacle else { return }
        guard let last = currentPath.last else { return }

        // Tapping the tile just before the current end undoes the last move.
        if currentPath.count >= 2, position == currentPath[currentPath.count - 2] {
            currentPath.removeLast()
            movesUsed += 1
            return
        }

        guard isAdjacent(position, last), !currentPath.contains(position) else { return }
        currentPath.append(position)
        movesUsed += 1

        if position == currentLevel.end {
            completeLevel(success: true)
        }
    }

    /// Clears the in-progress path back to the start tile without
    /// resetting the timer or move count — lets a stuck player retry
    /// their routing within the same level.
    func resetPath() {
        guard phase == .playing, !isTransitioning else { return }
        currentPath = [currentLevel.start]
    }

    private func isAdjacent(_ a: Position, _ b: Position) -> Bool {
        abs(a.row - b.row) + abs(a.col - b.col) == 1
    }

    // MARK: - Level completion + scoring

    /// Scoring rule: a completed level scores 100 base points, plus up
    /// to +50 for finishing quickly (linear on time remaining), minus 8
    /// points per move beyond that level's optimal path length. A
    /// timed-out level scores 0. Per-level scores sum into the final
    /// total, floored at 0.
    private func completeLevel(success: Bool) {
        levelTask?.cancel()
        isTransitioning = true
        lastLevelSucceeded = success

        let levelScore: Int
        if success {
            let elapsed = levelStartedAt.map { Date().timeIntervalSince($0) } ?? Self.timePerLevelSeconds
            let clampedElapsed = min(max(elapsed, 0), Self.timePerLevelSeconds)
            let speedFraction = 1.0 - (clampedElapsed / Self.timePerLevelSeconds)
            let extraMoves = max(0, movesUsed - currentLevel.optimalMoves)
            let movesPenalty = extraMoves * 8
            levelScore = max(0, 100 + Int((50.0 * speedFraction).rounded()) - movesPenalty)
        } else {
            levelScore = 0
        }
        runningScore += levelScore

        let nextIndex = levelIndex + 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000) // let the user see success/timeout feedback
            guard let self else { return }
            self.beginLevel(at: nextIndex)
        }
    }

    // MARK: - Game over

    private func endGame() {
        guard phase == .playing else { return }
        levelTask?.cancel()

        let score = max(0, runningScore)
        let duration: Int
        if let gameStartedAt {
            duration = max(1, Int(Date().timeIntervalSince(gameStartedAt).rounded()))
        } else {
            duration = Int(Double(Self.totalLevels) * Self.timePerLevelSeconds)
        }

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Pirate Passage",
                category: "Problem Solving",
                score: score,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: score)
        }
    }
}