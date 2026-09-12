import Foundation
import SwiftUI
import Combine

// MARK: - FlowSwitchViewModel
//
// Continuous, timer-bound version: a session runs for `gameDuration`
// seconds. Each trial shows a GROUP of leaves (not one) that all share
// the same color/pointing/movement, drifting together — matching how
// the reference plays. The rule (green = pointing, orange = movement)
// is communicated only through leaf color; there is no on-screen text
// hint, so the player has to have internalized the rule from the
// tutorial. Trials auto-advance on input or per-trial timeout; the
// session itself ends when the countdown reaches zero.

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

        var vector: CGSize {
            switch self {
            case .up:    return CGSize(width: 0, height: -1)
            case .down:  return CGSize(width: 0, height: 1)
            case .left:  return CGSize(width: -1, height: 0)
            case .right: return CGSize(width: 1, height: 0)
            }
        }

        /// Rotation applied to LeafShape (which points "up" at 0°).
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
    }

    // MARK: Leaf instance (one visual leaf within the current group)

    struct LeafInstance: Identifiable, Equatable {
        let id: Int
        /// Normalized start position within the play area, 0...1.
        let baseX: CGFloat
        let baseY: CGFloat
    }

    // MARK: Trial

    struct Trial {
        let color: LeafColor
        let pointing: Direction
        let movement: Direction
        let isSwitchTrial: Bool
        let leaves: [LeafInstance]

        var correctDirection: Direction { color == .green ? pointing : movement }
        var isCongruent: Bool { pointing == movement }
    }

    // MARK: Difficulty

    private struct DifficultyProfile {
        let incongruentProbability: Double
        let switchProbability: Double
        let responseWindow: Double
        let driftDistance: Double
        let leafCount: Int
    }

    private static func profile(for level: Int) -> DifficultyProfile {
        switch level {
        case 1:  return .init(incongruentProbability: 0.25, switchProbability: 0.25, responseWindow: 1.6, driftDistance: 90,  leafCount: 5)
        case 2:  return .init(incongruentProbability: 0.35, switchProbability: 0.30, responseWindow: 1.4, driftDistance: 110, leafCount: 6)
        case 3:  return .init(incongruentProbability: 0.45, switchProbability: 0.35, responseWindow: 1.2, driftDistance: 130, leafCount: 7)
        case 4:  return .init(incongruentProbability: 0.55, switchProbability: 0.40, responseWindow: 1.0, driftDistance: 150, leafCount: 8)
        default: return .init(incongruentProbability: 0.65, switchProbability: 0.45, responseWindow: 0.85, driftDistance: 170, leafCount: 9)
        }
    }

    // MARK: Tunables

    /// Total session length. Not hard-coded elsewhere — change here only.
    static let gameDurationSeconds: Double = 60
    private static let meterMax = 5
    private static let maxMultiplier = 8
    private static let basePoints = 40
    private static let finalBonusPerMultiplier = 200
    private static let minValidReactionMs: Double = 80

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentTrial: Trial
    @Published private(set) var leafOffset: CGSize = .zero
    @Published private(set) var score: Int = 0
    @Published private(set) var multiplier: Int = 1
    @Published private(set) var meter: Int = 0
    @Published private(set) var timeRemaining: Double = FlowSwitchViewModel.gameDurationSeconds
    @Published private(set) var lastAnswerFeedback: Bool?

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    var timeRemainingLabel: String {
        let clamped = max(0, Int(timeRemaining.rounded(.up)))
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool

    private var difficultyLevel: Int = 1
    private var rollingResults: [Bool] = []
    private var trialsCompleted = 0

    private var previousColor: LeafColor?
    private var colorRunLength: Int = 0

    private var switchCorrect = 0
    private var switchTotal = 0
    private var incongruentCorrect = 0
    private var incongruentTotal = 0
    private var correctCount = 0
    private var wrongCount = 0
    private var missCount = 0

    private var trialTask: Task<Void, Never>?
    private var sessionTimerTask: Task<Void, Never>?
    private var responseLocked = false
    private var trialStartedAt: Date?
    private var gameStartedAt: Date?

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        self.currentTrial = Trial(color: .green, pointing: .up, movement: .up, isSwitchTrial: false, leaves: [])
        gameStartedAt = Date()
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

    private static func randomLeafPositions(count: Int) -> [LeafInstance] {
        var positions: [LeafInstance] = []
        var attempts = 0
        while positions.count < count && attempts < count * 20 {
            attempts += 1
            let x = CGFloat.random(in: 0.08...0.92)
            let y = CGFloat.random(in: 0.06...0.62)
            let tooClose = positions.contains { abs($0.baseX - x) < 0.16 && abs($0.baseY - y) < 0.16 }
            if !tooClose {
                positions.append(LeafInstance(id: positions.count, baseX: x, baseY: y))
            }
        }
        // Fallback: fill any remainder without the spacing constraint.
        while positions.count < count {
            positions.append(LeafInstance(
                id: positions.count,
                baseX: CGFloat.random(in: 0.08...0.92),
                baseY: CGFloat.random(in: 0.06...0.62)
            ))
        }
        return positions
    }

    private func generateTrial() -> Trial {
        let profile = Self.profile(for: difficultyLevel)

        let color: LeafColor
        if let previousColor {
            if colorRunLength >= 4 {
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

        let leaves = Self.randomLeafPositions(count: profile.leafCount)
        return Trial(color: color, pointing: pointing, movement: movement, isSwitchTrial: isSwitch, leaves: leaves)
    }

    // MARK: - Trial lifecycle

    private func beginTrial() {
        guard phase == .playing, timeRemaining > 0 else { return }
        trialTask?.cancel()

        currentTrial = generateTrial()
        responseLocked = false
        leafOffset = .zero
        lastAnswerFeedback = nil
        trialStartedAt = Date()

        let profile = Self.profile(for: difficultyLevel)
        let vector = currentTrial.movement.vector
        withAnimation(.linear(duration: profile.responseWindow)) {
            leafOffset = CGSize(
                width: vector.width * profile.driftDistance,
                height: vector.height * profile.driftDistance
            )
        }

        trialTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(profile.responseWindow * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
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

        trialsCompleted += 1
        rollingResults.append(isCorrect)
        if rollingResults.count > 10 { rollingResults.removeFirst() }
        if trialsCompleted % 5 == 0 { adjustDifficultyIfNeeded() }

        guard timeRemaining > 0 else {
            endGame()
            return
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let self, self.phase == .playing else { return }
            self.beginTrial()
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
        sessionTimerTask?.cancel()

        let finalScore = score + Self.finalBonusPerMultiplier * multiplier
        let duration: Int
        if let gameStartedAt {
            duration = max(1, Int(Date().timeIntervalSince(gameStartedAt).rounded()))
        } else {
            duration = Int(Self.gameDurationSeconds)
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