//
//  SplittingSeedsViewModel.swift
//  LumiMind
//
//  Owns gameplay state for Splitting Seeds: each round has seeds at
//  fixed random positions plus two FIXED TARGET numbers (e.g. "6 and 2")
//  that the round requires. A hidden solution angle is generated first,
//  and the actual seed counts at that angle become the round's targets —
//  guaranteeing a solution always exists. The user rotates the stick
//  (View forwards drag angle into `updateStickAngle(to:)`), live counts
//  update per side, and `lockIn()` checks whether the current split
//  (order-independent) matches the two targets. Wrong locks cost time
//  instead of a life; correct locks add score and advance a 4-round pip
//  indicator, leveling up every 4 correct rounds.

import Foundation
import Combine
import UIKit

@MainActor
final class SplittingSeedsViewModel: ObservableObject {

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    struct Seed: Identifiable, Equatable {
        let id: Int
        /// Fixed angle from the pivot, in radians.
        let angle: Double
        /// Fixed distance from the pivot, as a fraction (0.28...1.0) of the play radius.
        let radiusFraction: Double
    }

    // MARK: Tunables

    static let roundsPerLevel = 4
    static let totalGameSeconds = 90
    static let baseSeedCount = 8
    static let maxSeedCount = 16
    static let wrongAnswerTimePenalty = 5

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var seeds: [Seed] = []
    /// Radians. The View's DragGesture drives this live via `updateStickAngle(to:)`.
    @Published private(set) var stickAngle: Double = 0.35
    @Published private(set) var leftCount: Int = 0
    @Published private(set) var rightCount: Int = 0
    /// The two group sizes this round requires the split to match (order-independent).
    @Published private(set) var targetGroupA: Int = 0
    @Published private(set) var targetGroupB: Int = 0
    @Published private(set) var timeRemaining: Int = SplittingSeedsViewModel.totalGameSeconds
    @Published private(set) var score: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var roundInLevel: Int = 0 // drives the pip indicator, 0..<roundsPerLevel
    @Published private(set) var lastAnswerWasCorrect: Bool?

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool
    private var timerCancellable: AnyCancellable?
    private var gameStartedAt: Date?
    private var isLockingIn = false

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false) {
        self.gameResultViewModel = gameResultViewModel
        self.isFitTest = isFitTest
        setUpNewGame()
    }

    // MARK: - Setup

    func setUpNewGame() {
        timerCancellable?.cancel()
        score = 0
        level = 1
        roundInLevel = 0
        timeRemaining = Self.totalGameSeconds
        lastAnswerWasCorrect = nil
        gameStartedAt = Date()
        phase = .playing
        beginRound()
        startTimer()
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard phase == .playing else { return }
        timeRemaining -= 1
        if timeRemaining <= 0 {
            timeRemaining = 0
            endGame()
        }
    }

    // MARK: - Round lifecycle

    private func beginRound() {
        let count = min(Self.maxSeedCount, Self.baseSeedCount + (level - 1) * 2)
        seeds = Self.generateSeeds(count: count, level: level)
        stickAngle = Double.random(in: 0..<(2 * .pi))
        isLockingIn = false
        lastAnswerWasCorrect = nil

        let (a, b) = Self.generateTargets(for: seeds)
        targetGroupA = a
        targetGroupB = b

        recomputeCounts()
    }

    private static func generateSeeds(count: Int, level: Int) -> [Seed] {
        let tightness = min(0.5, Double(level - 1) * 0.06)
        let minRadius = 0.28 + tightness
        let maxRadius = max(minRadius + 0.1, 1.0 - tightness)
        return (0..<count).map { index in
            Seed(
                id: index,
                angle: Double.random(in: 0..<(2 * .pi)),
                radiusFraction: Double.random(in: minRadius...maxRadius)
            )
        }
    }

    /// Picks a hidden "solution angle" and reads off the actual seed
    /// counts at that angle — this guarantees a real stick angle exists
    /// that produces exactly these two numbers. Retries a few times to
    /// avoid a degenerate 0/N target.
    private static func generateTargets(for seeds: [Seed]) -> (Int, Int) {
        guard !seeds.isEmpty else { return (0, 0) }
        for _ in 0..<6 {
            let solutionAngle = Double.random(in: 0..<(2 * .pi))
            let left = seeds.filter { isOnLeft(seedAngle: $0.angle, stickAngle: solutionAngle) }.count
            let right = seeds.count - left
            if left > 0 && right > 0 {
                return (left, right)
            }
        }
        // Fallback: even split.
        let half = seeds.count / 2
        return (half, seeds.count - half)
    }

    // MARK: - Drag updates

    /// Called live from the View's DragGesture as the user rotates the stick.
    func updateStickAngle(to angle: Double) {
        guard phase == .playing else { return }
        stickAngle = angle
        recomputeCounts()
    }

    private func recomputeCounts() {
        var left = 0
        var right = 0
        for seed in seeds {
            if Self.isOnLeft(seedAngle: seed.angle, stickAngle: stickAngle) {
                left += 1
            } else {
                right += 1
            }
        }
        leftCount = left
        rightCount = right
    }

    /// Which half-plane (relative to the stick's line through the pivot) the seed falls on.
    private static func isOnLeft(seedAngle: Double, stickAngle: Double) -> Bool {
        sin(seedAngle - stickAngle) >= 0
    }

    // MARK: - Lock in

    func lockIn() {
        guard phase == .playing, !isLockingIn, !seeds.isEmpty else { return }
        isLockingIn = true

        let currentSplit = [leftCount, rightCount].sorted()
        let target = [targetGroupA, targetGroupB].sorted()
        let isCorrect = currentSplit == target
        lastAnswerWasCorrect = isCorrect

        if isCorrect {
            score += 100
            roundInLevel += 1
            if roundInLevel >= Self.roundsPerLevel {
                roundInLevel = 0
                level += 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            timeRemaining = max(0, timeRemaining - Self.wrongAnswerTimePenalty)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000) // let the user see the tick/cross feedback
            guard let self else { return }
            if self.timeRemaining <= 0 {
                self.endGame()
            } else {
                self.beginRound()
            }
        }
    }

    // MARK: - Game over + scoring

    private func endGame() {
        guard phase == .playing else { return }
        timerCancellable?.cancel()

        let duration: Int
        if let gameStartedAt {
            duration = max(1, Int(Date().timeIntervalSince(gameStartedAt).rounded()))
        } else {
            duration = Self.totalGameSeconds
        }

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Splitting Seeds",
                category: "Math",
                score: self.score,
                durationSeconds: duration,
                isFitTest: self.isFitTest
            )
            self.phase = .finished(score: self.score)
        }
    }
}