//
//  SplittingSeedsViewModel.swift
//  LumiMind
//
//  Owns gameplay state for Splitting Seeds: seeds sit at fixed random
//  positions each round, the user rotates a stick (View forwards drag
//  angle into `updateStickAngle(to:)`), live per-side counts are
//  recomputed on every angle change, and `lockIn()` checks for an even
//  split. Seed count is always even, so an exact 50/50 angle always
//  exists — no round is unsolvable. Wrong locks cost time instead of a
//  life (GameResult has no lives field); correct locks add score and
//  advance a 4-round pip indicator, leveling up every 4 correct rounds.

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

        let isCorrect = leftCount == rightCount
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
            try? await Task.sleep(nanoseconds: 450_000_000) // let the user see correct/incorrect feedback
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