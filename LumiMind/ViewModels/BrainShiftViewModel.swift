import Foundation
import Combine

// MARK: - BrainShiftViewModel
//
// Owns gameplay state for Brain Shift: each round shows an item with
// two independent attributes (color, shape). The user sorts it into
// a Left/Right bucket according to whichever rule is currently active
// (sort by color, or sort by shape). The rule switches unannounced
// every 4–6 rounds. Mirrors LostInMigrationViewModel's conventions —
// View only renders published state and forwards taps into
// `chooseBucket(_:)`; this ViewModel submits the result itself the
// moment the game ends.

@MainActor
final class BrainShiftViewModel: ObservableObject {

    // MARK: Game phase

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    enum Rule: Equatable {
        case color
        case shape

        var label: String {
            switch self {
            case .color: return "Sort by Color"
            case .shape: return "Sort by Shape"
            }
        }
    }

    enum ItemColor: CaseIterable { case red, blue }
    enum ItemShape: CaseIterable { case circle, square }

    enum Bucket {
        case left
        case right
    }

    struct RoundItem: Equatable {
        let color: ItemColor
        let shape: ItemShape
    }

    private struct Round {
        let item: RoundItem
        let rule: Rule
        /// True for the first two rounds under a (newly or
        /// previously) active rule — this is the cognitive-flexibility
        /// signal the game is meant to measure, so correct answers
        /// here score a bonus.
        let isEarlyAfterSwitch: Bool
    }

    // MARK: Tunables

    static let totalRounds = 20
    static let responseWindowSeconds: Double = 3.5
    private static let minRoundsPerRule = 4
    private static let maxRoundsPerRule = 6

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentRoundIndex: Int = 0
    @Published private(set) var currentItem: RoundItem = RoundItem(color: .red, shape: .circle)
    @Published private(set) var currentRule: Rule = .color
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
        var rule: Rule = Bool.random() ? .color : .shape
        var roundsUntilSwitch = Int.random(in: minRoundsPerRule...maxRoundsPerRule)
        var positionInRule = 0

        for _ in 0..<count {
            if positionInRule >= roundsUntilSwitch {
                rule = (rule == .color) ? .shape : .color
                roundsUntilSwitch = Int.random(in: minRoundsPerRule...maxRoundsPerRule)
                positionInRule = 0
            }

            let item = RoundItem(
                color: ItemColor.allCases.randomElement()!,
                shape: ItemShape.allCases.randomElement()!
            )
            let isEarly = positionInRule < 2
            result.append(Round(item: item, rule: rule, isEarlyAfterSwitch: isEarly))
            positionInRule += 1
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
        currentItem = rounds[index].item
        currentRule = rounds[index].rule
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
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        wrongCount += 1
        lastAnswerWasCorrect = false
        runningScore -= 15
        advanceToNextRound()
    }

    // MARK: - Answering

    /// Scoring rule: a correct answer scores 30–90 points on a linear
    /// scale based on reaction time within the response window. Correct
    /// answers landing in the first two rounds after a rule switch (or
    /// the game's opening rule) earn an extra +40 "adapted fast" bonus
    /// — that quick re-adaptation is the specific cognitive-flexibility
    /// signal this game measures, more than raw speed alone. Wrong
    /// answers and timeouts subtract 15. Final score is floored at 0.
    func chooseBucket(_ bucket: Bucket) {
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        roundTask?.cancel()

        let round = rounds[currentRoundIndex]
        let correctBucket = Self.correctBucket(for: round.item, rule: round.rule)
        let isCorrect = (bucket == correctBucket)

        if isCorrect {
            correctCount += 1
            lastAnswerWasCorrect = true

            let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? Self.responseWindowSeconds
            let clampedElapsed = min(max(elapsed, 0), Self.responseWindowSeconds)
            let speedFraction = 1.0 - (clampedElapsed / Self.responseWindowSeconds)
            runningScore += 30 + Int((60.0 * speedFraction).rounded())

            if round.isEarlyAfterSwitch {
                runningScore += 40
            }
        } else {
            wrongCount += 1
            lastAnswerWasCorrect = false
            runningScore -= 15
        }

        advanceToNextRound()
    }

    private static func correctBucket(for item: RoundItem, rule: Rule) -> Bucket {
        switch rule {
        case .color:
            return item.color == .red ? .left : .right
        case .shape:
            return item.shape == .circle ? .left : .right
        }
    }

    private func advanceToNextRound() {
        let nextIndex = currentRoundIndex + 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
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
                gameName: "Brain Shift",
                category: "Flexibility",
                score: score,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: score)
        }
    }
}