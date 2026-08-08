import Foundation
import Combine

// MARK: - SplittingSeedsViewModel
//
// Owns gameplay state for Splitting Seeds: each round shows a pile of
// seeds already split into two groups alongside a proposed "seeds per
// group" claim, and the user judges True/False on whether the pile
// splits evenly into that claim. Total seed counts are always
// generated as even numbers, so an exact even split always exists —
// no round is ever unsolvable. Mirrors SpeedMatchViewModel's timing
// pattern given this game's explicit Math/Speed hybrid nature — View
// only renders published state and forwards taps into `answer(_:)`;
// this ViewModel submits the result itself the moment the game ends.

@MainActor
final class SplittingSeedsViewModel: ObservableObject {

    // MARK: Game phase

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    enum Answer {
        case trueAnswer
        case falseAnswer
    }

    private struct Round {
        let totalSeeds: Int
        let claimedPerGroup: Int
        /// Whether `claimedPerGroup * 2 == totalSeeds`.
        let isCorrectClaim: Bool
    }

    // MARK: Tunables

    static let totalRounds = 15
    static let baseResponseWindowSeconds: Double = 4.0
    static let minResponseWindowSeconds: Double = 1.75

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentRoundIndex: Int = 0
    @Published private(set) var totalSeeds: Int = 0
    @Published private(set) var claimedPerGroup: Int = 0
    /// 1.0 = window just opened, 0.0 = window closed.
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
    private var currentResponseWindow: Double = SplittingSeedsViewModel.baseResponseWindowSeconds

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

    /// Generates a mix of correct and incorrect claims. Total seed
    /// counts are always chosen as even numbers scaled by round
    /// difficulty, so an exact even split (`totalSeeds / 2`) always
    /// exists — a "correct" claim round is never accidentally
    /// unsolvable. Incorrect claims offset the true half-value by a
    /// small random amount that's guaranteed non-zero.
    private static func generateRounds(count: Int) -> [Round] {
        var result: [Round] = []
        for index in 0..<count {
            let progress = Double(index) / Double(max(1, count - 1))
            let maxHalf = 6 + Int((24.0 * progress).rounded()) // grows from 6 to 30
            let half = Int.random(in: 2...max(2, maxHalf))
            let total = half * 2

            let isCorrect = Bool.random()
            let claimed: Int
            if isCorrect {
                claimed = half
            } else {
                let offset = Int.random(in: 1...max(1, half / 2 + 1))
                claimed = Bool.random() ? half + offset : max(0, half - offset)
            }
            let actuallyCorrect = (claimed == half)
            result.append(Round(totalSeeds: total, claimedPerGroup: claimed, isCorrectClaim: actuallyCorrect))
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
        let round = rounds[index]
        totalSeeds = round.totalSeeds
        claimedPerGroup = round.claimedPerGroup
        hasAnsweredCurrentRound = false
        roundStartedAt = Date()
        timeRemainingFraction = 1.0

        let progress = Double(index) / Double(max(1, Self.totalRounds - 1))
        currentResponseWindow = Self.baseResponseWindowSeconds - (Self.baseResponseWindowSeconds - Self.minResponseWindowSeconds) * progress

        roundTask = Task { [weak self] in
            guard let self else { return }
            let steps = 20
            let stepDuration = self.currentResponseWindow / Double(steps)
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
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        wrongCount += 1
        lastAnswerWasCorrect = false
        runningScore -= 20
        advanceToNextRound()
    }

    // MARK: - Answering

    /// Scoring rule (consistent with Speed Match's precedent): a
    /// correct answer scores 40–100 points on a linear scale based on
    /// reaction time — instant taps earn the full 100, taps at the
    /// edge of the window still earn 40. Wrong answers and timeouts
    /// subtract 20. Final score is floored at 0.
    func answer(_ answer: Answer) {
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        roundTask?.cancel()

        let round = rounds[currentRoundIndex]
        let userSaysTrue = (answer == .trueAnswer)
        let isCorrect = userSaysTrue == round.isCorrectClaim

        if isCorrect {
            correctCount += 1
            lastAnswerWasCorrect = true

            let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? currentResponseWindow
            let clampedElapsed = min(max(elapsed, 0), currentResponseWindow)
            let speedFraction = 1.0 - (clampedElapsed / currentResponseWindow)
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
            try? await Task.sleep(nanoseconds: 250_000_000)
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
            duration = Int(Double(Self.totalRounds) * Self.baseResponseWindowSeconds)
        }

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Splitting Seeds",
                category: "Math",
                score: score,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: score)
        }
    }
}