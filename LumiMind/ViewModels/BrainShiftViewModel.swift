import Foundation
import SwiftUI
import Combine

// MARK: - BrainShiftViewModel
//
// Task-switching game: a two-attribute stimulus ("5E" = digit 5,
// letter E) is judged against whichever of two rules is currently
// active — "Is the number even?" or "Is the letter a vowel?" — with
// YES/NO answers. The rule switches unpredictably every 2-4 rounds
// (interval widens/narrows with difficulty), which is the actual
// cognitive-switching challenge; there's no separate "trap answer"
// mechanic needed since the two rules already read different
// attributes of the same stimulus.
//
// Structured to match LostInMigrationViewModel / FlowSwitchViewModel:
// a single continuous timed session (no countdown phase — starts
// immediately in init, same as those two), a DifficultyProfile keyed
// by level, and rolling-accuracy-driven difficulty adjustment. Scoring
// follows the original Brain Shift design doc's point values (+100
// correct / -25 incorrect / -15 timeout, speed + streak bonus) rather
// than Lost in Migration's meter/multiplier — different specified
// scoring models for different games.
//
// `currentTrial` (active) and `nextTrial` (queued) are always both
// populated, matching the reference screenshot's two-card layout: the
// upcoming card is shown blank with its own rule question already
// visible below it.

@MainActor
final class BrainShiftViewModel: ObservableObject {

    // MARK: Rule & stimulus

    enum GameRule: Equatable {
        case numberParity, letterVowel

        var question: String {
            switch self {
            case .numberParity: return "Is the number even?"
            case .letterVowel:  return "Is the letter a vowel?"
            }
        }
    }

    struct Trial: Equatable {
        let digit: Int
        let letter: Character
        let rule: GameRule
        let correctAnswerIsYes: Bool

        var label: String { "\(digit)\(letter)" }
        var accessibilityLabel: String { "Number \(digit), letter \(letter)" }
    }

    private struct RoundResult {
        let isCorrect: Bool
        let isTimeout: Bool
        let responseTime: Double
    }

    // MARK: Phase
    //
    // No countdown phase — matches LostInMigrationViewModel/
    // FlowSwitchViewModel, both of which start their session timer and
    // first trial immediately in init.

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    // MARK: Difficulty

    private struct DifficultyProfile {
        let responseWindowSeconds: Double
        let minRoundsBeforeSwitch: Int
        let maxRoundsBeforeSwitch: Int
    }

    private static func profile(for level: Int) -> DifficultyProfile {
        switch level {
        case 1:  return .init(responseWindowSeconds: 3.0, minRoundsBeforeSwitch: 4, maxRoundsBeforeSwitch: 6)
        case 2:  return .init(responseWindowSeconds: 2.5, minRoundsBeforeSwitch: 3, maxRoundsBeforeSwitch: 5)
        case 3:  return .init(responseWindowSeconds: 2.0, minRoundsBeforeSwitch: 2, maxRoundsBeforeSwitch: 4)
        case 4:  return .init(responseWindowSeconds: 1.6, minRoundsBeforeSwitch: 2, maxRoundsBeforeSwitch: 3)
        default: return .init(responseWindowSeconds: 1.3, minRoundsBeforeSwitch: 2, maxRoundsBeforeSwitch: 3)
        }
    }

    private static let maxDifficultyLevel = 5
    private static let vowels: [Character] = ["A", "E", "I", "O", "U"]
    private static let consonants: [Character] = ["B", "C", "D", "F", "G", "H", "J", "K", "L", "M", "N", "P", "R", "S", "T", "W"]

    // MARK: Tunables

    static let sessionDurationSeconds: Double = 60
    private static let correctBase = 100
    private static let incorrectPenalty = 25
    private static let timeoutPenalty = 15
    private static let feedbackPauseSeconds: Double = 0.3

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentTrial: Trial
    @Published private(set) var nextTrial: Trial
    @Published private(set) var score: Int = 0
    @Published private(set) var timeRemaining: Double = BrainShiftViewModel.sessionDurationSeconds
    @Published private(set) var lastAnswerWasCorrect: Bool?
    @Published private(set) var justSwitchedRule: Bool = false

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    var timeRemainingLabel: String {
        let clamped = max(0, Int(timeRemaining.rounded(.up)))
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    // MARK: Results

    private(set) var finalCorrectCount = 0
    private(set) var finalIncorrectCount = 0
    private(set) var finalTimeoutCount = 0
    private(set) var finalAccuracy: Double = 0
    private(set) var finalAverageResponseTime: Double = 0
    private(set) var bestStreak: Int = 0

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool

    private var activeRule: GameRule = .numberParity
    private var roundsSinceSwitch = 0
    private var roundsUntilSwitch = 4
    private var difficultyLevel = 1
    private var streak = 0
    private var rollingResults: [Bool] = []
    private var results: [RoundResult] = []

    private var hasAnsweredCurrentRound = false
    private var roundStartedAt: Date?
    private var gameStartedAt: Date?
    private var roundTimeoutTask: Task<Void, Never>?
    private var sessionTimerTask: Task<Void, Never>?

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        self.currentTrial = Self.generateTrial(rule: .numberParity)
        self.nextTrial = Self.generateTrial(rule: .numberParity)
        gameStartedAt = Date()
        currentTrial = Self.generateTrial(rule: nextRuleInSequence())
        nextTrial = Self.generateTrial(rule: nextRuleInSequence())
        startSessionTimer()
        beginRound()
    }

    // MARK: - Setup / reset

    func setUpNewGame() {
        roundTimeoutTask?.cancel()
        sessionTimerTask?.cancel()

        score = 0
        streak = 0
        bestStreak = 0
        timeRemaining = Self.sessionDurationSeconds
        lastAnswerWasCorrect = nil
        justSwitchedRule = false
        activeRule = .numberParity
        roundsSinceSwitch = 0
        difficultyLevel = 1
        let startProfile = Self.profile(for: 1)
        roundsUntilSwitch = Int.random(in: startProfile.minRoundsBeforeSwitch...startProfile.maxRoundsBeforeSwitch)
        rollingResults = []
        results = []
        gameStartedAt = Date()

        currentTrial = Self.generateTrial(rule: nextRuleInSequence())
        nextTrial = Self.generateTrial(rule: nextRuleInSequence())

        phase = .playing
        startSessionTimer()
        beginRound()
    }

    // MARK: - Session timer (matches LostInMigrationViewModel / FlowSwitchViewModel exactly)

    private func startSessionTimer() {
        sessionTimerTask = Task { [weak self] in
            while let self, self.timeRemaining > 0, self.phase == .playing {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
                self.timeRemaining = max(0, self.timeRemaining - 0.1)
            }
            guard let self, self.phase == .playing else { return }
            self.endGame()
        }
    }

    // MARK: - Rule sequencing

    private func nextRuleInSequence() -> GameRule {
        if roundsSinceSwitch >= roundsUntilSwitch {
            activeRule = (activeRule == .numberParity) ? .letterVowel : .numberParity
            roundsSinceSwitch = 0
            let p = Self.profile(for: difficultyLevel)
            roundsUntilSwitch = Int.random(in: p.minRoundsBeforeSwitch...p.maxRoundsBeforeSwitch)
        }
        roundsSinceSwitch += 1
        return activeRule
    }

    // MARK: - Trial generation

    private static func generateTrial(rule: GameRule) -> Trial {
        let digit = Int.random(in: 0...9)
        let letter = (vowels + consonants).randomElement()!
        let isVowel = vowels.contains(letter)
        let correctAnswerIsYes = (rule == .numberParity) ? (digit % 2 == 0) : isVowel
        return Trial(digit: digit, letter: letter, rule: rule, correctAnswerIsYes: correctAnswerIsYes)
    }

    // MARK: - Round lifecycle

    private func beginRound() {
        guard phase == .playing, timeRemaining > 0 else { return }
        roundTimeoutTask?.cancel()

        hasAnsweredCurrentRound = false
        lastAnswerWasCorrect = nil
        roundStartedAt = Date()

        let window = Self.profile(for: difficultyLevel).responseWindowSeconds
        roundTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.handleTimeout()
        }
    }

    private func handleTimeout() {
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        streak = 0
        lastAnswerWasCorrect = false
        recordRound(isCorrect: false, isTimeout: true, responseTime: Self.profile(for: difficultyLevel).responseWindowSeconds, scoreEarned: -Self.timeoutPenalty)
        advance()
    }

    // MARK: - Responding

    func answer(isYes: Bool) {
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        roundTimeoutTask?.cancel()

        let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? Self.profile(for: difficultyLevel).responseWindowSeconds
        let isCorrect = isYes == currentTrial.correctAnswerIsYes
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
        case ..<0.75: return 50
        case ..<1.25: return 30
        case ..<2.00: return 15
        default:      return 0
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
        score = max(0, score + scoreEarned)
        results.append(RoundResult(isCorrect: isCorrect, isTimeout: isTimeout, responseTime: responseTime))
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

    // MARK: - Advance the two-card queue

    private func advance() {
        guard timeRemaining > 0 else {
            endGame()
            return
        }
        let previousRule = currentTrial.rule
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.feedbackPauseSeconds * 1_000_000_000))
            guard let self, self.phase == .playing else { return }
            self.currentTrial = self.nextTrial
            self.nextTrial = Self.generateTrial(rule: self.nextRuleInSequence())
            if self.currentTrial.rule != previousRule {
                self.justSwitchedRule = true
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    self?.justSwitchedRule = false
                }
            }
            guard self.timeRemaining > 0 else {
                self.endGame()
                return
            }
            self.beginRound()
        }
    }

    // MARK: - Game over + scoring

    private func endGame() {
        guard phase == .playing else { return }
        roundTimeoutTask?.cancel()
        sessionTimerTask?.cancel()

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
        let duration = gameStartedAt.map { max(1, Int(Date().timeIntervalSince($0).rounded())) } ?? Int(Self.sessionDurationSeconds)

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