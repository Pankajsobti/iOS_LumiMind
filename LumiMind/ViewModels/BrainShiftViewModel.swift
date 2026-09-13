import Foundation
import SwiftUI
import Combine

// MARK: - BrainShiftViewModel
//
// REWRITE: replaces the previous 1-back symbol-matching implementation
// (which didn't match the "Brain Shift" design doc) with the actual
// task-switching mechanic: the player is given a CURRENT RULE (COLOR
// or SHAPE) and must classify a two-attribute stimulus according to
// that rule only, ignoring the other attribute. The rule changes
// unpredictably every 2-4 rounds, and answer options are sometimes
// salted with the "trap" answer (what would be correct under the
// OTHER rule) so the task tests rule-switching, not just recognition
// — see `generateTrial(roundNumber:rule:level:forceInterference:)`.
//
// Architecture mirrors LostInMigrationViewModel: explicit Phase enum,
// a per-round Task-based timer always cancelled before a new one
// starts, a DifficultyProfile keyed by level, rolling-accuracy-driven
// difficulty adjustment. Scoring follows the Brain Shift design doc's
// point values (+100 correct / -25 incorrect / -15 timeout, plus
// speed + streak bonuses) rather than Lost in Migration's
// meter/multiplier system — different games, different specified
// scoring models.
//
// ASSUMPTION (flagging per project convention): Standard mode only
// (20 rounds). Persistence, haptics, and pause/resume are NOT
// implemented — flag if you want those added.

@MainActor
final class BrainShiftViewModel: ObservableObject {

    // MARK: Rule & stimulus

    enum GameRule: Equatable {
        case color, shape

        var label: String {
            switch self {
            case .color: return "COLOR"
            case .shape: return "SHAPE"
            }
        }
    }

    enum ItemColor: CaseIterable, Equatable {
        case red, blue, green, yellow, purple, orange

        var label: String {
            switch self {
            case .red: return "RED"
            case .blue: return "BLUE"
            case .green: return "GREEN"
            case .yellow: return "YELLOW"
            case .purple: return "PURPLE"
            case .orange: return "ORANGE"
            }
        }

        var color: Color {
            switch self {
            case .red:    return Color(hex: "#FF5E5B")
            case .blue:   return Color(hex: "#4A7BFF")
            case .green:  return Color(hex: "#2ECC71")
            case .yellow: return Color(hex: "#F5C518")
            case .purple: return Color(hex: "#9B59B6")
            case .orange: return Color(hex: "#FF9F43")
            }
        }
    }

    enum ItemShape: CaseIterable, Equatable {
        case circle, square, triangle, star, diamond

        var label: String {
            switch self {
            case .circle: return "CIRCLE"
            case .square: return "SQUARE"
            case .triangle: return "TRIANGLE"
            case .star: return "STAR"
            case .diamond: return "DIAMOND"
            }
        }

        var systemImageName: String {
            switch self {
            case .circle:   return "circle.fill"
            case .square:   return "square.fill"
            case .triangle: return "triangle.fill"
            case .star:     return "star.fill"
            case .diamond:  return "diamond.fill"
            }
        }
    }

    struct Stimulus: Equatable {
        let color: ItemColor
        let shape: ItemShape

        /// Non-color-dependent accessibility description, e.g. "Red circle"
        /// (doc section 27/28 — never communicate via color alone).
        var accessibilityLabel: String {
            "\(color.label.capitalized) \(shape.label.lowercased())"
        }
    }

    struct Trial {
        let roundNumber: Int
        let rule: GameRule
        let stimulus: Stimulus
        /// Always text labels, never color-only swatches.
        let options: [String]
        let correctAnswer: String
        let isInterferenceTrial: Bool
    }

    private struct RoundResult {
        let roundNumber: Int
        let rule: GameRule
        let isCorrect: Bool
        let isTimeout: Bool
        let responseTime: Double
        let scoreEarned: Int
        let difficultyLevel: Int
    }

    // MARK: Phase & round lifecycle

    enum Phase: Equatable {
        case countdown(Int) // 3, 2, 1, 0 == "GO"
        case playing
        case submitting
        case finished(score: Int)
    }

    enum RoundLifecycle: Equatable {
        case ready, active, answered, timedOut
    }

    // MARK: Difficulty

    private struct DifficultyProfile {
        let responseWindowSeconds: Double
        let optionCount: Int
        let interferenceProbability: Double
        let minRoundsBeforeSwitch: Int
        let maxRoundsBeforeSwitch: Int
    }

    private static func profile(for level: Int) -> DifficultyProfile {
        switch level {
        case 1:  return .init(responseWindowSeconds: 3.0, optionCount: 3, interferenceProbability: 0.25, minRoundsBeforeSwitch: 3, maxRoundsBeforeSwitch: 4)
        case 2:  return .init(responseWindowSeconds: 2.5, optionCount: 3, interferenceProbability: 0.4,  minRoundsBeforeSwitch: 2, maxRoundsBeforeSwitch: 4)
        case 3:  return .init(responseWindowSeconds: 2.1, optionCount: 4, interferenceProbability: 0.55, minRoundsBeforeSwitch: 2, maxRoundsBeforeSwitch: 3)
        case 4:  return .init(responseWindowSeconds: 1.8, optionCount: 4, interferenceProbability: 0.65, minRoundsBeforeSwitch: 2, maxRoundsBeforeSwitch: 3)
        default: return .init(responseWindowSeconds: 1.5, optionCount: 5, interferenceProbability: 0.75, minRoundsBeforeSwitch: 2, maxRoundsBeforeSwitch: 3)
        }
    }

    private static let maxDifficultyLevel = 5

    // MARK: Tunables (doc sections 13-15, 19)

    static let totalRounds = 20
    private static let correctBase = 100
    private static let incorrectPenalty = 25
    private static let timeoutPenalty = 15
    private static let feedbackPauseSeconds: Double = 0.45

    // MARK: Published state

    @Published private(set) var phase: Phase = .countdown(3)
    @Published private(set) var currentTrial: Trial
    @Published private(set) var roundLifecycle: RoundLifecycle = .ready
    @Published private(set) var score: Int = 0
    @Published private(set) var streak: Int = 0
    @Published private(set) var bestStreak: Int = 0
    @Published private(set) var timeRemainingFraction: Double = 1.0
    @Published private(set) var lastAnswerWasCorrect: Bool?
    @Published private(set) var lastScoreDelta: Int = 0
    @Published private(set) var justSwitchedRule: Bool = false

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Results (doc sections 20-21)

    private(set) var finalCorrectCount = 0
    private(set) var finalIncorrectCount = 0
    private(set) var finalTimeoutCount = 0
    private(set) var finalAccuracy: Double = 0
    private(set) var finalAverageResponseTime: Double = 0

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool

    private var currentRule: GameRule = .color
    private var roundsSinceRuleStart = 0
    private var roundsUntilNextSwitch = 3
    private var difficultyLevel = 1
    private var rollingResults: [Bool] = []
    private var results: [RoundResult] = []

    private var roundStartedAt: Date?
    private var gameStartedAt: Date?
    private var roundTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        self.currentTrial = Self.generateTrial(roundNumber: 1, rule: .color, level: 1, forceInterference: false)
        setUpNewGame()
    }

    // MARK: - Setup / reset

    func setUpNewGame() {
        roundTask?.cancel()
        countdownTask?.cancel()
        score = 0
        streak = 0
        bestStreak = 0
        lastAnswerWasCorrect = nil
        lastScoreDelta = 0
        justSwitchedRule = false
        currentRule = .color
        roundsSinceRuleStart = 0
        difficultyLevel = 1
        rollingResults = []
        results = []
        roundLifecycle = .ready
        let startProfile = Self.profile(for: 1)
        roundsUntilNextSwitch = Int.random(in: startProfile.minRoundsBeforeSwitch...startProfile.maxRoundsBeforeSwitch)
        currentTrial = Self.generateTrial(roundNumber: 1, rule: currentRule, level: difficultyLevel, forceInterference: false)
        runCountdown()
    }

    // MARK: - Countdown (doc section 4)

    private func runCountdown() {
        phase = .countdown(3)
        countdownTask = Task { [weak self] in
            for tick in stride(from: 3, through: 0, by: -1) {
                guard let self else { return }
                self.phase = .countdown(tick)
                try? await Task.sleep(nanoseconds: 700_000_000)
                if Task.isCancelled { return }
            }
            guard let self, !Task.isCancelled else { return }
            self.gameStartedAt = Date()
            self.phase = .playing
            self.beginRound(1)
        }
    }

    // MARK: - Trial generation (doc sections 6-8)

    private static func generateTrial(roundNumber: Int, rule: GameRule, level: Int, forceInterference: Bool) -> Trial {
        let profile = profile(for: level)
        let colorPoolSize = min(3 + (level - 1), ItemColor.allCases.count)
        let shapePoolSize = min(3 + (level - 1), ItemShape.allCases.count)
        let colors = Array(ItemColor.allCases.shuffled().prefix(colorPoolSize))
        let shapes = Array(ItemShape.allCases.shuffled().prefix(shapePoolSize))

        let stimulusColor = colors.randomElement()!
        let stimulusShape = shapes.randomElement()!
        let stimulus = Stimulus(color: stimulusColor, shape: stimulusShape)

        let correctAnswer = rule == .color ? stimulusColor.label : stimulusShape.label
        let otherRuleAnswer = rule == .color ? stimulusShape.label : stimulusColor.label

        let includeInterference = forceInterference || Double.random(in: 0...1) < profile.interferenceProbability

        var pool: [String] = rule == .color ? colors.map(\.label) : shapes.map(\.label)
        pool.removeAll { $0 == correctAnswer }
        pool.shuffle()

        var options: Set<String> = [correctAnswer]
        if includeInterference, otherRuleAnswer != correctAnswer {
            options.insert(otherRuleAnswer)
        }
        for candidate in pool where options.count < profile.optionCount {
            options.insert(candidate)
        }
        let fillerPool = rule == .color ? ItemColor.allCases.map(\.label) : ItemShape.allCases.map(\.label)
        for candidate in fillerPool.shuffled() where options.count < profile.optionCount {
            options.insert(candidate)
        }

        return Trial(
            roundNumber: roundNumber,
            rule: rule,
            stimulus: stimulus,
            options: Array(options).shuffled(),
            correctAnswer: correctAnswer,
            isInterferenceTrial: options.contains(otherRuleAnswer) && otherRuleAnswer != correctAnswer
        )
    }

    // MARK: - Round lifecycle (doc sections 24-25, 41)

    private func beginRound(_ roundNumber: Int) {
        guard roundNumber <= Self.totalRounds else {
            endGame()
            return
        }
        roundTask?.cancel()

        var switched = false
        if roundsSinceRuleStart >= roundsUntilNextSwitch {
            currentRule = (currentRule == .color) ? .shape : .color
            roundsSinceRuleStart = 0
            let profile = Self.profile(for: difficultyLevel)
            roundsUntilNextSwitch = Int.random(in: profile.minRoundsBeforeSwitch...profile.maxRoundsBeforeSwitch)
            switched = true
        }
        roundsSinceRuleStart += 1

        currentTrial = Self.generateTrial(roundNumber: roundNumber, rule: currentRule, level: difficultyLevel, forceInterference: switched)
        roundLifecycle = .active
        lastAnswerWasCorrect = nil
        roundStartedAt = Date()
        timeRemainingFraction = 1.0

        if switched {
            justSwitchedRule = true
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 900_000_000)
                self?.justSwitchedRule = false
            }
        }

        let window = Self.profile(for: difficultyLevel).responseWindowSeconds
        roundTask = Task { [weak self] in
            let steps = 24
            let stepDuration = window / Double(steps)
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                self.timeRemainingFraction = max(0, 1.0 - Double(step) / Double(steps))
            }
            guard let self, !Task.isCancelled else { return }
            self.handleTimeout()
        }
    }

    private func handleTimeout() {
        guard phase == .playing, roundLifecycle == .active else { return }
        roundLifecycle = .timedOut
        streak = 0
        lastAnswerWasCorrect = false
        recordRound(isCorrect: false, isTimeout: true, responseTime: Self.profile(for: difficultyLevel).responseWindowSeconds, scoreEarned: -Self.timeoutPenalty)
        advance()
    }

    // MARK: - Answering (doc sections 9-12)

    func answer(_ selected: String) {
        guard phase == .playing, roundLifecycle == .active else { return }
        roundLifecycle = .answered
        roundTask?.cancel()

        let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? Self.profile(for: difficultyLevel).responseWindowSeconds
        let isCorrect = selected == currentTrial.correctAnswer
        lastAnswerWasCorrect = isCorrect

        var delta = isCorrect ? Self.correctBase : -Self.incorrectPenalty

        if isCorrect {
            streak += 1
            bestStreak = max(bestStreak, streak)
            delta += Self.speedBonus(for: elapsed)
            delta += Self.streakBonus(for: streak)
        } else {
            streak = 0
        }

        recordRound(isCorrect: isCorrect, isTimeout: false, responseTime: elapsed, scoreEarned: delta)
        advance()
    }

    private static func speedBonus(for elapsed: Double) -> Int {
        switch elapsed {
        case ..<0.75:  return 50
        case ..<1.25:  return 30
        case ..<2.00:  return 15
        default:       return 0
        }
    }

    private static func streakBonus(for streak: Int) -> Int {
        switch streak {
        case 10: return 100
        case 5:  return 50
        case 3:  return 25
        default: return 0
        }
    }

    private func recordRound(isCorrect: Bool, isTimeout: Bool, responseTime: Double, scoreEarned: Int) {
        let previousScore = score
        score = max(0, score + scoreEarned)
        lastScoreDelta = score - previousScore

        results.append(RoundResult(
            roundNumber: currentTrial.roundNumber,
            rule: currentTrial.rule,
            isCorrect: isCorrect,
            isTimeout: isTimeout,
            responseTime: responseTime,
            scoreEarned: scoreEarned,
            difficultyLevel: difficultyLevel
        ))

        rollingResults.append(isCorrect)
        if rollingResults.count > 8 { rollingResults.removeFirst() }
        if results.count % 4 == 0 { adjustDifficultyIfNeeded() }
    }

    private func adjustDifficultyIfNeeded() {
        guard rollingResults.count >= 6 else { return }
        let accuracy = Double(rollingResults.filter { $0 }.count) / Double(rollingResults.count)
        if accuracy > 0.9 {
            difficultyLevel = min(difficultyLevel + 1, Self.maxDifficultyLevel)
        } else if accuracy < 0.6 {
            difficultyLevel = max(difficultyLevel - 1, 1)
        }
    }

    private func advance() {
        let nextRound = currentTrial.roundNumber + 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.feedbackPauseSeconds * 1_000_000_000))
            guard let self else { return }
            self.beginRound(nextRound)
        }
    }

    // MARK: - Game over + scoring (doc sections 20-21)

    private func endGame() {
        guard phase == .playing else { return }
        roundTask?.cancel()

        let correct = results.filter { $0.isCorrect }.count
        let timeouts = results.filter { $0.isTimeout }.count
        let incorrect = results.count - correct - timeouts
        let avgResponse = results.isEmpty ? 0 : results.map(\.responseTime).reduce(0, +) / Double(results.count)

        finalCorrectCount = correct
        finalIncorrectCount = incorrect
        finalTimeoutCount = timeouts
        finalAccuracy = results.isEmpty ? 0 : Double(correct) / Double(results.count)
        finalAverageResponseTime = avgResponse

        let finalScore = score
        let duration = gameStartedAt.map { max(1, Int(Date().timeIntervalSince($0).rounded())) } ?? 0

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Brain Shift",
                category: "Flexibility",
                score: finalScore,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: finalScore)
        }
    }
}