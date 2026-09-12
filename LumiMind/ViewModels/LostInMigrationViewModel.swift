import Foundation
import Combine

// MARK: - LostInMigrationViewModel
//
// REWRITE: this is now a true flanker task, matching the reference
// design doc rather than the previous "odd rotated arrow in a grid"
// mechanic. A formation of birds is shown; only the CENTER bird's
// direction is ever correct. Surrounding birds are pure distractors
// and must never determine correctness (this invariant is enforced in
// `respond(_:)` — it only ever compares against `currentTrial.target`).
//
// Session shape mirrors FlowSwitchViewModel: one continuous timed
// session (default 45s) rather than a fixed round count, a 4-dot
// meter + multiplier scoring system, and rolling-accuracy-driven
// difficulty (see `adjustDifficultyIfNeeded`). Per-trial timeout
// handling (a trial that isn't answered in time counts as a miss)
// mirrors the previous implementation's `handleTimeout`.
//
// ASSUMPTION (flagging per project convention): scoring/meter/
// multiplier rules follow the newly-supplied logic doc (50 × multiplier
// per correct answer, wrong/timeout only costs meter/multiplier
// progress, no direct score subtraction, end-of-session bonus =
// 100 × final multiplier). This replaces the old "+30..100 / -15"
// formula entirely. Flag if you wanted the old scoring kept alongside
// the new formation/UI.

@MainActor
final class LostInMigrationViewModel: ObservableObject {

    // MARK: Phase

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    // MARK: Direction

    enum Direction: CaseIterable, Equatable {
        case up, down, left, right

        /// Rotation applied to BirdShape (which points "up" at 0°).
        var rotationDegrees: Double {
            switch self {
            case .up:    return 0
            case .right: return 90
            case .down:  return 180
            case .left:  return 270
            }
        }
    }

    // MARK: Formation slots
    //
    // Fixed, named positions rather than a generic grid — the center
    // slot is always the target; every other slot is always a
    // distractor. `.outer*` slots are only populated at higher
    // difficulty levels to add visual clutter (see DifficultyProfile).

    enum Slot: CaseIterable, Equatable {
        case center, up, down, left, right
        case outerUpLeft, outerUpRight, outerDownLeft, outerDownRight

        /// Normalized offset from the formation's center, in units of
        /// one "bird spacing". The View multiplies this by its own
        /// spacing constant to get actual points.
        var offset: (x: Double, y: Double) {
            switch self {
            case .center:        return (0, 0)
            case .up:            return (0, -1)
            case .down:          return (0, 1)
            case .left:          return (-1, 0)
            case .right:         return (1, 0)
            case .outerUpLeft:   return (-1, -1)
            case .outerUpRight:  return (1, -1)
            case .outerDownLeft: return (-1, 1)
            case .outerDownRight: return (1, 1)
            }
        }

        static let innerRing: [Slot] = [.up, .down, .left, .right]
        static let outerRing: [Slot] = [.outerUpLeft, .outerUpRight, .outerDownLeft, .outerDownRight]
    }

    struct BirdState: Identifiable, Equatable {
        let slot: Slot
        let direction: Direction
        let isTarget: Bool
        var id: String { "\(slot)" }
    }

    struct Trial {
        let target: Direction
        let birds: [BirdState]
        let isCongruent: Bool
    }

    // MARK: Difficulty

    private struct DifficultyProfile {
        let responseWindowSeconds: Double
        /// Chance a given trial is incongruent (surrounding birds
        /// disagree with the target).
        let incongruentProbability: Double
        /// Chance each individual distractor picks its OWN random
        /// direction rather than mirroring the trial's chosen
        /// distractor direction — higher values create more
        /// "directionally varied" flocks per the design doc.
        let varietyProbability: Double
        let includesOuterRing: Bool
    }

    private static func profile(for level: Int) -> DifficultyProfile {
        switch level {
        case 1:  return .init(responseWindowSeconds: 1.8, incongruentProbability: 0.25, varietyProbability: 0.0,  includesOuterRing: false)
        case 2:  return .init(responseWindowSeconds: 1.55, incongruentProbability: 0.35, varietyProbability: 0.15, includesOuterRing: false)
        case 3:  return .init(responseWindowSeconds: 1.3, incongruentProbability: 0.45, varietyProbability: 0.30, includesOuterRing: false)
        case 4:  return .init(responseWindowSeconds: 1.1, incongruentProbability: 0.55, varietyProbability: 0.45, includesOuterRing: true)
        default: return .init(responseWindowSeconds: 0.9, incongruentProbability: 0.65, varietyProbability: 0.60, includesOuterRing: true)
        }
    }

    private static let maxDifficultyLevel = 5

    // MARK: Tunables

    static let sessionDurationSeconds: Double = 45
    static let meterMax = 4
    static let maxMultiplier = 10
    static let basePoints = 50
    static let endBonusPerMultiplier = 100

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentTrial: Trial
    @Published private(set) var score: Int = 0
    @Published private(set) var multiplier: Int = 1
    @Published private(set) var meter: Int = 0
    @Published private(set) var timeRemaining: Double = LostInMigrationViewModel.sessionDurationSeconds
    @Published private(set) var lastAnswerWasCorrect: Bool?

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    var timeRemainingLabel: String {
        let clamped = max(0, Int(timeRemaining.rounded(.up)))
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool

    private var difficultyLevel = 1
    private var rollingResults: [Bool] = []
    private var trialsCompleted = 0
    private var correctCount = 0
    private var wrongCount = 0
    private var missCount = 0

    private var sessionTimerTask: Task<Void, Never>?
    private var trialTimeoutTask: Task<Void, Never>?
    private var responseLocked = false
    private var gameStartedAt: Date?

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        self.currentTrial = Self.generateTrial(level: 1)
        gameStartedAt = Date()
        startSessionTimer()
        beginTrial()
    }

    // MARK: - Setup / reset

    func setUpNewGame() {
        sessionTimerTask?.cancel()
        trialTimeoutTask?.cancel()
        score = 0
        multiplier = 1
        meter = 0
        timeRemaining = Self.sessionDurationSeconds
        lastAnswerWasCorrect = nil
        difficultyLevel = 1
        rollingResults = []
        trialsCompleted = 0
        correctCount = 0
        wrongCount = 0
        missCount = 0
        responseLocked = false
        phase = .playing
        gameStartedAt = Date()
        currentTrial = Self.generateTrial(level: 1)
        startSessionTimer()
        beginTrial()
    }

    // MARK: - Session timer

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

    // MARK: - Trial generation
    //
    // Invariant (per design doc): the CENTER bird's direction is the
    // only thing that determines correctness. Every other slot is
    // generated independently and never fed back into scoring.

    private static func generateTrial(level: Int) -> Trial {
        let profile = profile(for: level)
        let target = Direction.allCases.randomElement()!

        let isIncongruent = Double.random(in: 0...1) < profile.incongruentProbability
        // The "base" distractor direction: matches the target on
        // congruent trials, or a different direction on incongruent
        // ones. Individual distractors may still deviate from this
        // per `varietyProbability`, per the doc's "directionally
        // varied flock" difficulty axis.
        let baseDistractorDirection: Direction = isIncongruent
            ? Direction.allCases.filter { $0 != target }.randomElement()!
            : target

        var slots = Slot.innerRing
        if profile.includesOuterRing {
            slots += Slot.outerRing
        }

        var birds: [BirdState] = [BirdState(slot: .center, direction: target, isTarget: true)]
        for slot in slots {
            let direction: Direction
            if Double.random(in: 0...1) < profile.varietyProbability {
                direction = Direction.allCases.randomElement()!
            } else {
                direction = baseDistractorDirection
            }
            birds.append(BirdState(slot: slot, direction: direction, isTarget: false))
        }

        let isCongruent = birds.filter { !$0.isTarget }.allSatisfy { $0.direction == target }
        return Trial(target: target, birds: birds, isCongruent: isCongruent)
    }

    // MARK: - Trial lifecycle

    private func beginTrial() {
        guard phase == .playing, timeRemaining > 0 else { return }
        trialTimeoutTask?.cancel()

        currentTrial = Self.generateTrial(level: difficultyLevel)
        lastAnswerWasCorrect = nil
        responseLocked = false

        let window = Self.profile(for: difficultyLevel).responseWindowSeconds
        trialTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.handleTimeout()
        }
    }

    private func handleTimeout() {
        guard phase == .playing, !responseLocked else { return }
        responseLocked = true
        missCount += 1
        lastAnswerWasCorrect = false
        registerStreakMiss()
        finishTrialAndAdvance()
    }

    // MARK: - Responding

    /// The View calls this from its swipe gesture. `direction` is
    /// compared ONLY against `currentTrial.target` — surrounding
    /// birds never participate in this check.
    func respond(_ direction: Direction) {
        guard phase == .playing, !responseLocked else { return }
        responseLocked = true
        trialTimeoutTask?.cancel()

        let isCorrect = direction == currentTrial.target
        lastAnswerWasCorrect = isCorrect

        if isCorrect {
            correctCount += 1
            score += Self.basePoints * multiplier
            registerStreakSuccess()
        } else {
            wrongCount += 1
            registerStreakMiss()
        }

        finishTrialAndAdvance()
    }

    private func finishTrialAndAdvance() {
        trialsCompleted += 1
        rollingResults.append(lastAnswerWasCorrect == true)
        if rollingResults.count > 10 { rollingResults.removeFirst() }
        if trialsCompleted % 5 == 0 { adjustDifficultyIfNeeded() }

        guard timeRemaining > 0 else {
            endGame()
            return
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000) // brief pause so feedback is visible
            guard let self, self.phase == .playing else { return }
            self.beginTrial()
        }
    }

    // MARK: - Meter / multiplier
    //
    // Mirrors FlowSwitchViewModel's rule exactly: a correct answer
    // fills the meter; a full meter converts into +1 multiplier and
    // resets. A wrong answer / timeout drains the meter first, and
    // only reduces the multiplier once the meter is already empty.
    // Score is never subtracted directly for a wrong answer.

    private func registerStreakSuccess() {
        meter += 1
        if meter >= Self.meterMax {
            meter = 0
            multiplier = min(multiplier + 1, Self.maxMultiplier)
        }
    }

    private func registerStreakMiss() {
        if meter > 0 {
            meter = 0
        } else {
            multiplier = max(multiplier - 1, 1)
        }
    }

    private func adjustDifficultyIfNeeded() {
        guard rollingResults.count >= 6 else { return }
        let accuracy = Double(rollingResults.filter { $0 }.count) / Double(rollingResults.count)
        if accuracy >= 0.85 {
            difficultyLevel = min(difficultyLevel + 1, Self.maxDifficultyLevel)
        } else if accuracy < 0.6 {
            difficultyLevel = max(difficultyLevel - 1, 1)
        }
    }

    // MARK: - Game over + scoring

    private func endGame() {
        guard phase == .playing else { return }
        sessionTimerTask?.cancel()
        trialTimeoutTask?.cancel()

        let bonus = Self.endBonusPerMultiplier * multiplier
        let finalScore = max(0, score + bonus)
        let duration = gameStartedAt.map { max(1, Int(Date().timeIntervalSince($0).rounded())) } ?? Int(Self.sessionDurationSeconds)

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Lost in Migration",
                category: "Attention",
                score: finalScore,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: finalScore)
        }
    }
}