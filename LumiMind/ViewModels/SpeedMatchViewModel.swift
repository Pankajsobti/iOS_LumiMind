import Foundation
import Combine

// MARK: - SpeedMatchViewModel
//
// Owns gameplay state for Speed Match: a rapid sequence of symbols
// where the user judges whether the current symbol matches the one
// immediately before it, within a short response window per round.
// Mirrors MemoryMatrixViewModel's conventions — View only renders
// published state and forwards taps into `answer(_:)`; this ViewModel
// submits the result itself the moment the game ends.

@MainActor
final class SpeedMatchViewModel: ObservableObject {

    // MARK: Game phase

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    enum Answer {
        case match
        case noMatch
    }

    private struct Round {
        let symbolName: String
        /// Whether this round's symbol matches the previous round's
        /// symbol. Always `false` for round 0 (no previous symbol).
        let isMatch: Bool
    }

    // MARK: Tunables

    static let totalRounds = 15
    static let responseWindowSeconds: Double = 2.0

    private static let symbolPool = [
        "star.fill", "heart.fill", "bolt.fill", "moon.fill",
        "cloud.fill", "leaf.fill", "flame.fill", "drop.fill",
        "sun.max.fill", "snowflake"
    ]

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentRoundIndex: Int = 0
    @Published private(set) var currentSymbol: String = ""
    /// 1.0 = window just opened, 0.0 = window closed. Drives the
    /// on-screen countdown bar.
    @Published private(set) var timeRemainingFraction: Double = 1.0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var wrongCount: Int = 0
    @Published private(set) var lastAnswerWasCorrect: Bool?

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool
    private var rounds: [Round] = []
    private var roundStartedAt: Date?
    private var gameStartedAt: Date?
    private var roundTask: Task<Void, Never>?
    private var hasAnsweredCurrentRound = false
    private var runningScore: Int = 0

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        setUpNewGame()
    }

    // MARK: - Setup

    func setUpNewGame() {
        roundTask?.cancel()
        correctCount = 0
        wrongCount = 0
        runningScore = 0
        currentRoundIndex = 0
        lastAnswerWasCorrect = nil
        rounds = Self.generateRounds(count: Self.totalRounds)
        phase = .playing
        gameStartedAt = Date()
        beginRound(at: 0)
    }

    private static func generateRounds(count: Int) -> [Round] {
        var result: [Round] = []
        var previousSymbol: String?

        for _ in 0..<count {
            let shouldMatch = previousSymbol != nil && Bool.random()
            let symbol: String
            if shouldMatch, let previousSymbol {
                symbol = previousSymbol
            } else {
                var candidate = symbolPool.randomElement()!
                if let previousSymbol {
                    while candidate == previousSymbol {
                        candidate = symbolPool.randomElement()!
                    }
                }
                symbol = candidate
            }
            result.append(Round(symbolName: symbol, isMatch: shouldMatch))
            previousSymbol = symbol
        }
        return result
    }

    // MARK: - Round lifecycle

    private func beginRound(at index: Int) {
        guard index < rounds.count else {
            endGame()
            return
        }
        roundTask?.cancel()

        currentRoundIndex = index
        currentSymbol = rounds[index].symbolName
        hasAnsweredCurrentRound = false
        roundStartedAt = Date()
        timeRemainingFraction = 1.0

        roundTask = Task { [weak self] in
            guard let self else { return }
            let steps = 20
            let stepDuration = Self.responseWindowSeconds / Double(steps)
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                if Task.isCancelled { return }
                self.timeRemainingFraction = max(0, 1.0 - Double(step) / Double(steps))
            }
            guard !Task.isCancelled else { return }
            self.handleTimeout()
        }
    }

    private func handleTimeout() {
        // No tap before the window closes counts as a miss — same
        // penalty path as an explicit wrong answer.
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        wrongCount += 1
        lastAnswerWasCorrect = false
        runningScore -= 20
        advanceToNextRound()
    }

    // MARK: - Answering

    /// Scoring rule: a correct answer scores 40–100 points on a linear
    /// scale based on reaction time — instant taps earn the full 100,
    /// taps right at the edge of the response window still earn 40, so
    /// speed is rewarded without making a last-moment-but-correct tap
    /// worthless. Wrong answers (including timeouts) subtract 20.
    /// Final score is floored at 0.
    func answer(_ answer: Answer) {
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        roundTask?.cancel()

        let round = rounds[currentRoundIndex]
        let userSaysMatch = (answer == .match)
        let isCorrect = userSaysMatch == round.isMatch

        if isCorrect {
            correctCount += 1
            lastAnswerWasCorrect = true

            let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? Self.responseWindowSeconds
            let clampedElapsed = min(max(elapsed, 0), Self.responseWindowSeconds)
            let speedFraction = 1.0 - (clampedElapsed / Self.responseWindowSeconds)
            runningScore += 40 + Int((60.0 * speedFraction).rounded())
        } else {
            wrongCount += 1
            lastAnswerWasCorrect = false
            runningScore -= 20
        }

        advanceToNextRound()
    }

    private func advanceToNextRound() {
        let nextIndex = currentRoundIndex + 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000) // brief pause so feedback is visible
            guard let self else { return }
            self.beginRound(at: nextIndex)
        }
    }

    // MARK: - Game over + scoring

    private func endGame() {
        guard phase == .playing else { return }
        roundTask?.cancel()

        let score = max(0, runningScore)
        let duration: Int
        if let gameStartedAt {
            duration = max(1, Int(Date().timeIntervalSince(gameStartedAt).rounded()))
        } else {
            duration = Int(Double(Self.totalRounds) * Self.responseWindowSeconds)
        }

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Speed Match",
                category: "Speed",
                score: score,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: score)
        }
    }
}