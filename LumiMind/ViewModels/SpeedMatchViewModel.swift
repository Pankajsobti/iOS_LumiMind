import Foundation
import Combine

// MARK: - SpeedMatchViewModel
//
// Owns gameplay state for Speed Match: a rapid sequence of symbols
// where the user judges whether the current symbol matches the one
// immediately before it. Runs against a single overall session clock
// (`sessionDurationSeconds`) rather than a fixed round count or a
// per-round timeout — answer as many symbols as you can before time
// runs out. If time expires mid-round, the game simply ends; the
// in-progress round was never answered, so it's neither scored nor
// penalized either way.
//
// View only renders published state and forwards taps into
// `answer(_:)`; this ViewModel submits the result itself the moment
// the game ends.

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

    // MARK: Tunables

    /// Total time budget for the whole game — not per round.
    static let sessionDurationSeconds: Double = 60.0

    /// Reference window used only to compute the speed bonus on a
    /// correct answer (100 pts for an instant tap, decaying to a 40 pt
    /// floor). NOT an enforced timeout — taking longer than this no
    /// longer ends the round or counts as a miss.
    static let responseBonusWindowSeconds: Double = 2.0

    private static let symbolPool = [
        "star.fill", "heart.fill", "bolt.fill", "moon.fill",
        "cloud.fill", "leaf.fill", "flame.fill", "drop.fill",
        "sun.max.fill", "snowflake"
    ]

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentRoundIndex: Int = 0
    @Published private(set) var currentSymbol: String = ""
    /// 1.0 = session just started, 0.0 = time's up. This is now the
    /// OVERALL session clock, not a per-round window.
    @Published private(set) var timeRemainingFraction: Double = 1.0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var wrongCount: Int = 0
    @Published private(set) var lastAnswerWasCorrect: Bool?
    @Published private(set) var score: Int = 0

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool
    private var previousSymbol: String?
    private var currentRoundIsMatch = false
    private var roundStartedAt: Date?
    private var gameStartedAt: Date?
    private var sessionTask: Task<Void, Never>?
    private var hasAnsweredCurrentRound = false
    private var runningScore: Int = 0

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        setUpNewGame()
    }

    // MARK: - Setup

    func setUpNewGame() {
        sessionTask?.cancel()
        correctCount = 0
        wrongCount = 0
        runningScore = 0
        score = 0
        currentRoundIndex = 0
        lastAnswerWasCorrect = nil
        previousSymbol = nil
        timeRemainingFraction = 1.0
        phase = .playing
        gameStartedAt = Date()
        beginRound()
        startSessionTimer()
    }

    private static func nextRoundSymbol(after previousSymbol: String?) -> (symbol: String, isMatch: Bool) {
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
        return (symbol, shouldMatch)
    }

    // MARK: - Session clock

    private func startSessionTimer() {
        sessionTask?.cancel()
        sessionTask = Task { [weak self] in
            guard let self else { return }
            let steps = 600 // ~100ms resolution over the session
            let stepDuration = Self.sessionDurationSeconds / Double(steps)
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                if Task.isCancelled { return }
                self.timeRemainingFraction = max(0, 1.0 - Double(step) / Double(steps))
            }
            guard !Task.isCancelled else { return }
            // Time's up. The in-progress round (if any) was never
            // answered, so nothing to score or penalize — just end.
            self.endGame()
        }
    }

    // MARK: - Round lifecycle

    private func beginRound() {
        let next = Self.nextRoundSymbol(after: previousSymbol)
        currentSymbol = next.symbol
        currentRoundIsMatch = next.isMatch
        previousSymbol = next.symbol
        hasAnsweredCurrentRound = false
        roundStartedAt = Date()
    }

    // MARK: - Answering

    /// Scoring rule: a correct answer scores 40–100 points on a linear
    /// scale based on reaction time — instant taps earn the full 100,
    /// taps at or beyond `responseBonusWindowSeconds` still earn the
    /// 40 pt floor (no hard cutoff — just a shrinking bonus). Wrong
    /// answers subtract 20. Final score is floored at 0.
    func answer(_ answer: Answer) {
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true

        let userSaysMatch = (answer == .match)
        let isCorrect = userSaysMatch == currentRoundIsMatch

        if isCorrect {
            correctCount += 1
            lastAnswerWasCorrect = true

            let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? Self.responseBonusWindowSeconds
            let clampedElapsed = min(max(elapsed, 0), Self.responseBonusWindowSeconds)
            let speedFraction = 1.0 - (clampedElapsed / Self.responseBonusWindowSeconds)
            runningScore += 40 + Int((60.0 * speedFraction).rounded())
        } else {
            wrongCount += 1
            lastAnswerWasCorrect = false
            runningScore -= 20
        }
        score = max(0, runningScore)

        advanceToNextRound()
    }

    private func advanceToNextRound() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000) // brief pause so feedback is visible
            guard let self, self.phase == .playing else { return }
            self.currentRoundIndex += 1
            self.beginRound()
        }
    }

    // MARK: - Game over + scoring

    private func endGame() {
        guard phase == .playing else { return }
        sessionTask?.cancel()

        let score = max(0, runningScore)
        let duration: Int
        if let gameStartedAt {
            duration = max(1, Int(Date().timeIntervalSince(gameStartedAt).rounded()))
        } else {
            duration = Int(Self.sessionDurationSeconds)
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