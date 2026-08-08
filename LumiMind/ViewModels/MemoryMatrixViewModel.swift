import Foundation
import Combine

// MARK: - MemoryMatrixViewModel
//
// Owns all gameplay state for the Fit Test's Memory Matrix game: the
// card grid, the preview reveal, the countdown timer, match/mismatch
// logic, and score calculation. The View only renders `cards`/`phase`
// and forwards taps into `tap(_:)` — no gameplay logic lives in the View.
//
// Submission: this ViewModel holds a `GameResultViewModel` and calls
// `submitResult(...)` itself the moment the game ends (win or time-up),
// so "automatically submits on completion" doesn't depend on the View
// remembering to do it. The View only observes `phase`/`isBusySubmitting`
// to show a brief confirmation state.

@MainActor
final class MemoryMatrixViewModel: ObservableObject {

    // MARK: Game phase

    enum Phase: Equatable {
        case preview      // all cards briefly face-up so the user can memorize
        case playing       // timer running, user is tapping cards
        case submitting     // game just ended, result is being submitted
        case finished(score: Int) // submission complete (or failed — see errorMessage)
    }

    // MARK: Card model

    struct Card: Identifiable, Equatable {
        let id: Int
        let pairID: Int
        let symbolName: String
        var isFaceUp: Bool
        var isMatched: Bool
    }

    // MARK: Tunables

    static let pairCount = 8          // 8 pairs = 16 cards = 4x4 grid
    static let previewDurationSeconds = 3
    static let totalTimeSeconds = 60

    private static let symbolPool = [
        "star.fill", "heart.fill", "bolt.fill", "moon.fill",
        "cloud.fill", "leaf.fill", "flame.fill", "drop.fill"
    ]

    // MARK: Published state

    @Published private(set) var cards: [Card] = []
    @Published private(set) var phase: Phase = .preview
    @Published private(set) var timeRemaining: Int = MemoryMatrixViewModel.totalTimeSeconds
    @Published private(set) var matchedPairs: Int = 0
    @Published private(set) var wrongAttempts: Int = 0

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    /// Whether this playthrough should be submitted with `isFitTest: true`.
    /// `true` for the onboarding Fit Test (FitTestIntroView's flow);
    /// `false` for regular play launched from Home. Defaults to `true`
    /// to preserve the original Fit Test call site's behavior.
    private let isFitTest: Bool
    private var timerCancellable: AnyCancellable?
    private var startedPlayingAt: Date?
    private var selectedIndices: [Int] = []
    private var isResolvingMismatch = false

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = true) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        setUpNewGame()
    }

    // MARK: - Setup

    /// Builds a fresh shuffled grid and kicks off the preview reveal.
    func setUpNewGame() {
        timerCancellable?.cancel()
        matchedPairs = 0
        wrongAttempts = 0
        selectedIndices = []
        isResolvingMismatch = false
        timeRemaining = Self.totalTimeSeconds
        startedPlayingAt = nil

        let symbols = Array(Self.symbolPool.prefix(Self.pairCount))
        var built: [Card] = []
        for (pairID, symbol) in symbols.enumerated() {
            built.append(Card(id: pairID * 2, pairID: pairID, symbolName: symbol, isFaceUp: true, isMatched: false))
            built.append(Card(id: pairID * 2 + 1, pairID: pairID, symbolName: symbol, isFaceUp: true, isMatched: false))
        }
        cards = built.shuffled()
        phase = .preview

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.previewDurationSeconds) * 1_000_000_000)
            self?.beginPlaying()
        }
    }

    private func beginPlaying() {
        guard phase == .preview else { return }
        cards = cards.map { card in
            var c = card
            c.isFaceUp = false
            return c
        }
        phase = .playing
        startedPlayingAt = Date()
        startTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func tick() {
        guard phase == .playing else { return }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            timeRemaining = 0
            endGame()
        }
    }

    // MARK: - Tap handling

    func tap(_ card: Card) {
        guard phase == .playing, !isResolvingMismatch else { return }
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        guard !cards[index].isFaceUp, !cards[index].isMatched else { return }
        guard selectedIndices.count < 2 else { return }

        cards[index].isFaceUp = true
        selectedIndices.append(index)

        guard selectedIndices.count == 2 else { return }
        resolveSelection()
    }

    private func resolveSelection() {
        let firstIndex = selectedIndices[0]
        let secondIndex = selectedIndices[1]
        let isMatch = cards[firstIndex].pairID == cards[secondIndex].pairID

        if isMatch {
            cards[firstIndex].isMatched = true
            cards[secondIndex].isMatched = true
            matchedPairs += 1
            selectedIndices = []

            if matchedPairs == Self.pairCount {
                endGame()
            }
        } else {
            wrongAttempts += 1
            isResolvingMismatch = true
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 600_000_000) // let the user see the mismatch
                guard let self else { return }
                self.cards[firstIndex].isFaceUp = false
                self.cards[secondIndex].isFaceUp = false
                self.selectedIndices = []
                self.isResolvingMismatch = false
            }
        }
    }

    // MARK: - Game over + scoring

    /// Score formula (kept intentionally simple and explicit):
    ///   score = (matchedPairs * 100) − (wrongAttempts * 10), floored at 0.
    /// Rewards completing more pairs far more heavily than it penalizes
    /// wrong guesses, so a slow-but-thorough player still scores well —
    /// appropriate for a first-impression Fit Test rather than a
    /// punishing precision test.
    private func computeScore() -> Int {
        max(0, matchedPairs * 100 - wrongAttempts * 10)
    }

    private func endGame() {
        guard phase == .playing else { return }
        timerCancellable?.cancel()

        let score = computeScore()
        let duration: Int
        if let startedPlayingAt {
            duration = max(1, Int(Date().timeIntervalSince(startedPlayingAt).rounded()))
        } else {
            duration = Self.totalTimeSeconds - timeRemaining
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