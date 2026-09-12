import Foundation
import SwiftUI
import Combine

// MARK: - FlowSwitchViewModel
//
// Task-switching game: each trial shows a leaf that POINTS one
// direction and DRIFTS (moves) another. Leaf color selects which
// property is relevant — green = pointing, orange = movement — so
// the player must inhibit the irrelevant cue and, on top of that,
// re-orient whenever the color (rule) switches trial-to-trial.
//
// Difficulty (incongruent %, switch %, response window, drift
// distance) auto-adapts off a rolling accuracy window, re-evaluated
// every 5 trials so a single lucky/unlucky answer can't swing it.

@MainActor
final class FlowSwitchViewModel: ObservableObject {

    // MARK: Phase

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    // MARK: Direction

    enum Direction: CaseIterable, Equatable {
        case up, down, left, right

        /// Unit vector, used to compute drift offset.
        var vector: CGSize {
            switch self {
            case .up:    return CGSize(width: 0, height: -1)
            case .down:  return CGSize(width: 0, height: 1)
            case .left:  return CGSize(width: -1, height: 0)
            case .right: return CGSize(width: 1, height: 0)
            }
        }

        /// Rotation applied to LeafShape (which points "up" at 0°)
        /// so the leaf visually points this direction.
        var rotationDegrees: Double {
            switch self {
            case .up:    return 0
            case .right: return 90
            case .down:  return 180
            case .left:  return 270
            }
        }
    }

    // MARK: Leaf color / rule

    enum LeafColor: CaseIterable, Equatable {
        case green, orange

        var color: Color {
            switch self {
            case .green:  return Color(hex: "#2ECC71")
            case .orange: return Color(hex: "#FF8A3D")
            }
        }

        var ruleLabel: String {
            switch self {
            case .green:  return "FOLLOW POINTING"
            case .orange: return "FOLLOW MOVEMENT"
            }
        }
    }

    // MARK: Trial

    struct Trial {
        let color: LeafColor
        let pointing: Direction
        let movement: Direction
        let isSwitchTrial: Bool

        var correctDirection: Direction { color == .green ? pointing : movement }
        var isCongruent: Bool { pointing == movement }
    }

    // MARK: Difficulty

    private struct DifficultyProfile {
        let incongruentProbability: Double
        let switchProbability: Double
        let responseWindow: Double
        let driftDistance: Double
    }

    private static func profile(for level: Int) -> DifficultyProfile {
        switch level {
        case 1:  return .init(incongruentProbability: 0.25, switchProbability: 0.25, responseWindow: 2.4, driftDistance: 40)
        case 2:  return .init(incongruentProbability: 0.35, switchProbability: 0.30, responseWindow: 2.1, driftDistance: 50)
        case 3:  return .init(incongruentProbability: 0.45, switchProbability: 0.35, responseWindow: 1.8, driftDistance: 60)
        case 4:  return .init(incongruentProbability: 0.55, switchProbability: 0.40, responseWindow: 1.5, driftDistance: 70)
        default: return .init(incongruentProbability: 0.65, switchProbability: 0.45, responseWindow: 1.3, driftDistance: 80)
        }
    }

    // MARK: Tunables (scoring — original curve, not a Lumosity match)

    static let totalTrials = 24
    private static let meterMax = 5
    private static let maxMultiplier = 8
    private static let basePoints = 40
    private static let finalBonusPerMultiplier = 200
    private static let minValidReactionMs: Double = 80

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var trialIndex: Int = 0
    @Published private(set) var currentTrial: Trial
    @Published private(set) var leafOffset: CGSize = .zero
    @Published private(set) var score: Int = 0
    @Published private(set) var multiplier: Int = 1
    @Published private(set) var meter: Int = 0
    @Published private(set) var timeRemainingFraction: Double = 1.0
    @Published private(set) var lastAnswerFeedback: Bool?

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool

    private var difficultyLevel: Int = 1
    private var rollingResults: [Bool] = []

    private var previousColor: LeafColor?
    private var colorRunLength: Int = 0

    private var correctCount = 0
    private var wrongCount = 0
    private var missCount = 0
    private var switchCorrect = 0
    private var switchTotal = 0
    private var incongruentCorrect = 0
    private var incongruentTotal = 0

    private var trialTask: Task<Void, Never>?
    private var responseLocked = false
    private var trialStartedAt: Date?
    private var gameStartedAt: Date?

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        // Placeholder — replaced immediately by beginTrial(at: 0).
        self.currentTrial = Trial(color: .green, pointing: .up, movement: .up, isSwitchTrial: false)
        gameStartedAt = Date()
        beginTrial(at: 0)
    }

    // MARK: - Trial generation

    private func generateTrial() -> Trial {
        let profile = Self.profile(for: difficultyLevel)

        let color: LeafColor
        if let previousColor {
            if colorRunLength >= 4 {
                // Fairness constraint: never let one color run past 4.
                color = previousColor == .green ? .orange : .green
            } else {
                let shouldSwitch = Double.random(in: 0...1) < profile.switchProbability
                color = shouldSwitch ? (previousColor == .green ? .orange : .green) : previousColor
            }
        } else {
            color = LeafColor.allCases.randomElement()!
        }

        let pointing = Direction.allCases.randomElement()!
        let movement: Direction
        if Double.random(in: 0...1) < profile.incongruentProbability {
            movement = Direction.allCases.filter { $0 != pointing }.randomElement()!
        } else {
            movement = pointing
        }

        let isSwitch = previousColor != nil && color != previousColor
        colorRunLength = (color == previousColor) ? colorRunLength + 1 : 1
        previousColor = color

        return Trial(color: color, pointing: pointing, movement: movement, isSwitchTrial: isSwitch)
    }

    // MARK: - Trial lifecycle

    private func beginTrial(at index: Int) {
        guard index < Self.totalTrials else {
            endGame()
            return
        }
        trialTask?.cancel()

        trialIndex = index
        currentTrial = generateTrial()
        responseLocked = false
        leafOffset = .zero
        timeRemainingFraction = 1.0
        lastAnswerFeedback = nil
        trialStartedAt = Date()
        phase = .playing

        let profile = Self.profile(for: difficultyLevel)
        let vector = currentTrial.movement.vector
        withAnimation(.linear(duration: profile.responseWindow)) {
            leafOffset = CGSize(
                width: vector.width * profile.driftDistance,
                height: vector.height * profile.driftDistance
            )
        }

        trialTask = Task { [weak self] in
            guard let self else { return }
            let steps = 20
            let stepDuration = profile.responseWindow / Double(steps)
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
        guard phase == .playing, !responseLocked else { return }
        responseLocked = true
        processResult(isCorrect: false, wasMiss: true)
    }

    // MARK: - Responding

    func respond(_ direction: Direction) {
        guard phase == .playing, !responseLocked else { return }

        let elapsedMs = (trialStartedAt.map { Date().timeIntervalSince($0) } ?? 1) * 1000
        // Ignore accidental double-taps registered implausibly fast.
        guard elapsedMs >= Self.minValidReactionMs else { return }

        responseLocked = true
        trialTask?.cancel()

        let isCorrect = direction == currentTrial.correctDirection
        processResult(isCorrect: isCorrect, wasMiss: false)
    }

    // MARK: - Scoring + stats

    private func processResult(isCorrect: Bool, wasMiss: Bool) {
        if isCorrect {
            correctCount += 1
            score += Self.basePoints * multiplier
            meter += 1
            if meter >= Self.meterMax {
                meter = 0
                multiplier = min(multiplier + 1, Self.maxMultiplier)
            }
            lastAnswerFeedback = true
        } else {
            if wasMiss { missCount += 1 } else { wrongCount += 1 }
            if meter > 0 {
                meter = 0
            } else {
                multiplier = max(multiplier - 1, 1)
            }
            lastAnswerFeedback = false
        }

        if currentTrial.isSwitchTrial {
            switchTotal += 1
            if isCorrect { switchCorrect += 1 }
        }
        if !currentTrial.isCongruent {
            incongruentTotal += 1
            if isCorrect { incongruentCorrect += 1 }
        }

        rollingResults.append(isCorrect)
        if rollingResults.count > 10 { rollingResults.removeFirst() }
        if trialIndex % 5 == 4 { adjustDifficultyIfNeeded() }

        let nextIndex = trialIndex + 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self else { return }
            self.beginTrial(at: nextIndex)
        }
    }

    private func adjustDifficultyIfNeeded() {
        guard rollingResults.count >= 6 else { return }
        let accuracy = Double(rollingResults.filter { $0 }.count) / Double(rollingResults.count)
        if accuracy >= 0.9 {
            difficultyLevel = min(difficultyLevel + 1, 5)
        } else if accuracy < 0.7 {
            difficultyLevel = max(difficultyLevel - 1, 1)
        }
    }

    // MARK: - Game over

    private func endGame() {
        guard phase == .playing else { return }
        trialTask?.cancel()

        let finalScore = score + Self.finalBonusPerMultiplier * multiplier
        let duration: Int
        if let gameStartedAt {
            duration = max(1, Int(Date().timeIntervalSince(gameStartedAt).rounded()))
        } else {
            duration = Self.totalTrials * 2
        }

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Flow Switch",
                category: "Flexibility",
                score: finalScore,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: finalScore)
        }
    }
}