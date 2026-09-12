import Foundation
import SwiftUI
import Combine

// MARK: - FlowSwitchViewModel
//
// Continuous-flow model: leaves have persistent positions and a
// constant velocity (one axis at a time, since movement is always
// axial). Position is NOT re-computed by a timer tick in the
// ViewModel — it's derived on demand from (anchor + velocity *
// elapsed-since-referenceTime), wrapped into 0...1 space. The View
// reads anchors/velocity/referenceTime and animates every frame via
// TimelineView, so leaves never stop moving, including while waiting
// for input and across trial boundaries.
//
// When a trial ends (answer or timeout), we "freeze" each leaf's
// currently-interpolated position into a new anchor, reset
// referenceTime to now, and pick a new velocity for the next trial —
// so leaves keep flowing continuously through the transition instead
// of snapping or pausing.

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

        var vector: CGVector {
            switch self {
            case .up:    return CGVector(dx: 0, dy: -1)
            case .down:  return CGVector(dx: 0, dy: 1)
            case .left:  return CGVector(dx: -1, dy: 0)
            case .right: return CGVector(dx: 1, dy: 0)
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

    // MARK: Leaf instance
    //
    // `anchorX`/`anchorY` are normalized (0...1) positions as of
    // `referenceTime`. The View derives the LIVE position by adding
    // `velocity * elapsedSinceReferenceTime` and wrapping — it never
    // mutates these directly.

    struct LeafInstance: Identifiable, Equatable {
        let id: Int
        var anchorX: CGFloat
        var anchorY: CGFloat
    }

    // MARK: Trial (direction/color state only — position lives separately)

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
        /// Fraction of field crossed per second.
        let speed: Double
        let leafCount: Int
    }

    private static func profile(for level: Int) -> DifficultyProfile {
        switch level {
        case 1:  return .init(incongruentProbability: 0.25, switchProbability: 0.25, responseWindow: 1.7, speed: 0.16, leafCount: 6)
        case 2:  return .init(incongruentProbability: 0.35, switchProbability: 0.30, responseWindow: 1.5, speed: 0.20, leafCount: 7)
        case 3:  return .init(incongruentProbability: 0.45, switchProbability: 0.35, responseWindow: 1.3, speed: 0.25, leafCount: 8)
        case 4:  return .init(incongruentProbability: 0.55, switchProbability: 0.40, responseWindow: 1.1, speed: 0.30, leafCount: 9)
        default: return .init(incongruentProbability: 0.65, switchProbability: 0.45, responseWindow: 0.95, speed: 0.36, leafCount: 10)
        }
    }

    // MARK: Tunables

    static let gameDurationSeconds: Double = 60
    private static let meterMax = 5
    private static let maxMultiplier = 8
    private static let basePoints = 40
    private static let finalBonusPerMultiplier = 200
    private static let minValidReactionMs: Double = 80
    /// Minimum normalized spacing enforced when placing/adding leaves.
    private static let minLeafSpacing: CGFloat = 0.14

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentTrial: Trial
    @Published private(set) var leaves: [LeafInstance] = []
    /// Normalized units per second. Only one axis is ever non-zero.
    @Published private(set) var velocity: CGVector = .zero
    /// Anchors above are valid as of this instant; live position =
    /// anchor + velocity * (now - referenceTime), wrapped to 0...1.
    @Published private(set) var referenceTime: Date = Date()
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
    private var nextLeafID = 0

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
        self.currentTrial = Trial(color: .green, pointing: .up, movement: .up, isSwitchTrial: false)
        gameStartedAt = Date()
        leaves = Self.makeAnchors(count: Self.profile(for: 1).leafCount, existing: [], nextID: &nextLeafID)
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

    // MARK: - Position helpers

    private static func wrapped(_ value: CGFloat) -> CGFloat {
        var v = value.truncatingRemainder(dividingBy: 1)
        if v < 0 { v += 1 }
        return v
    }

    /// Live position of a leaf right now, given the current anchor/velocity/referenceTime.
    private func livePosition(of leaf: LeafInstance, at date: Date = Date()) -> CGPoint {
        let elapsed = date.timeIntervalSince(referenceTime)
        let x = Self.wrapped(leaf.anchorX + CGFloat(velocity.dx) * CGFloat(elapsed))
        let y = Self.wrapped(leaf.anchorY + CGFloat(velocity.dy) * CGFloat(elapsed))
        return CGPoint(x: x, y: y)
    }

    /// Builds `count` anchors, keeping as many of `existing`'s (already
    /// live-resolved) positions as possible and only generating new
    /// random ones for any shortfall, so growing/shrinking the leaf
    /// count doesn't restart the whole field.
    private static func makeAnchors(count: Int, existing: [LeafInstance], nextID: inout Int) -> [LeafInstance] {
        var result = Array(existing.prefix(count))
        while result.count < count {
            var candidate: LeafInstance
            var attempts = 0
            repeat {
                candidate = LeafInstance(
                    id: nextID,
                    anchorX: CGFloat.random(in: 0.05...0.95),
                    anchorY: CGFloat.random(in: 0.05...0.95)
                )
                attempts += 1
            } while attempts < 20 && result.contains(where: {
                abs($0.anchorX - candidate.anchorX) < minLeafSpacing && abs($0.anchorY - candidate.anchorY) < minLeafSpacing
            })
            nextID += 1
            result.append(candidate)
        }
        return result
    }

    // MARK: - Trial generation

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

        return Trial(color: color, pointing: pointing, movement: movement, isSwitchTrial: isSwitch)
    }

    // MARK: - Trial lifecycle

    private func beginTrial() {
        guard phase == .playing, timeRemaining > 0 else { return }
        trialTask?.cancel()

        // Freeze current live positions into new anchors so leaves
        // don't jump when velocity changes for the new trial.
        let now = Date()
        let frozen = leaves.map { leaf -> LeafInstance in
            let live = livePosition(of: leaf, at: now)
            return LeafInstance(id: leaf.id, anchorX: live.x, anchorY: live.y)
        }

        let profile = Self.profile(for: difficultyLevel)
        leaves = Self.makeAnchors(count: profile.leafCount, existing: frozen, nextID: &nextLeafID)
        referenceTime = now

        currentTrial = generateTrial()
        velocity = CGVector(
            dx: currentTrial.movement.vector.dx * profile.speed,
            dy: currentTrial.movement.vector.dy * profile.speed
        )

        responseLocked = false
        lastAnswerFeedback = nil
        trialStartedAt = now

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

        // Leaves keep flowing continuously through this gap — only the
        // *decision* pauses briefly (input stays locked) before the
        // next trial's direction/color takes over.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
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