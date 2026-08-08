import Foundation
import Combine

// MARK: - LostInMigrationViewModel
//
// Owns gameplay state for Lost in Migration: each round shows a grid
// of directional arrows all pointing the same way except one odd one
// out; the user taps the odd arrow within a shrinking time window.
// Mirrors SpeedMatchViewModel's conventions — View only renders
// published state and forwards taps into `tapItem(at:)`; this
// ViewModel submits the result itself the moment the game ends.

@MainActor
final class LostInMigrationViewModel: ObservableObject {

    // MARK: Game phase

    enum Phase: Equatable {
        case playing
        case submitting
        case finished(score: Int)
    }

    struct GridItemState: Identifiable, Equatable {
        let id: Int
        let rotationDegrees: Double
        let isOddOne: Bool
    }

    // MARK: Tunables

    static let totalRounds = 10
    static let baseGridSize = 9          // 3x3 grid to start
    static let maxGridSize = 16          // 4x4 grid at harder rounds
    static let baseTimeWindowSeconds: Double = 4.0
    static let minTimeWindowSeconds: Double = 1.75

    private static let directions: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]

    // MARK: Published state

    @Published private(set) var phase: Phase = .playing
    @Published private(set) var currentRoundIndex: Int = 0
    @Published private(set) var items: [GridItemState] = []
    @Published private(set) var gridColumns: Int = 3
    /// 1.0 = window just opened, 0.0 = window closed. Drives the
    /// on-screen countdown bar.
    @Published private(set) var timeRemainingFraction: Double = 1.0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var wrongCount: Int = 0
    @Published private(set) var lastAnswerWasCorrect: Bool?

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private state

    private let gameResultViewModel: GameResultViewModel
    private let isFitTest: Bool
    private var roundStartedAt: Date?
    private var gameStartedAt: Date?
    private var roundTask: Task<Void, Never>?
    private var hasAnsweredCurrentRound = false
    private var runningScore: Int = 0
    private var currentTimeWindow: Double = LostInMigrationViewModel.baseTimeWindowSeconds

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
        phase = .playing
        gameStartedAt = Date()
        beginRound(at: 0)
    }

    // MARK: - Round lifecycle

    private func beginRound(at index: Int) {
        guard index < Self.totalRounds else {
            endGame()
            return
        }
        roundTask?.cancel()

        currentRoundIndex = index
        hasAnsweredCurrentRound = false
        roundStartedAt = Date()
        timeRemainingFraction = 1.0

        // Difficulty ramps with round index: grid grows, window shrinks.
        let progress = Double(index) / Double(max(1, Self.totalRounds - 1))
        let gridSize = Self.baseGridSize + Int((Double(Self.maxGridSize - Self.baseGridSize) * progress).rounded())
        let columns = Int(Double(gridSize).squareRoot().rounded(.up))
        gridColumns = columns
        currentTimeWindow = Self.baseTimeWindowSeconds - (Self.baseTimeWindowSeconds - Self.minTimeWindowSeconds) * progress

        items = Self.generateGrid(size: columns * columns)

        roundTask = Task { [weak self] in
            guard let self else { return }
            let steps = 20
            let stepDuration = self.currentTimeWindow / Double(steps)
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                if Task.isCancelled { return }
                self.timeRemainingFraction = max(0, 1.0 - Double(step) / Double(steps))
            }
            guard !Task.isCancelled else { return }
            self.handleTimeout()
        }
    }

    private static func generateGrid(size: Int) -> [GridItemState] {
        guard size > 1 else {
            return [GridItemState(id: 0, rotationDegrees: 0, isOddOne: false)]
        }
        let commonDirection = directions.randomElement() ?? 0
        var oddDirection = directions.randomElement() ?? 0
        while oddDirection == commonDirection {
            oddDirection = directions.randomElement() ?? 0
        }
        let oddIndex = Int.random(in: 0..<size)

        return (0..<size).map { index in
            GridItemState(
                id: index,
                rotationDegrees: index == oddIndex ? oddDirection : commonDirection,
                isOddOne: index == oddIndex
            )
        }
    }

    private func handleTimeout() {
        // No tap before the window closes counts as a miss.
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        wrongCount += 1
        lastAnswerWasCorrect = false
        runningScore -= 15
        advanceToNextRound()
    }

    // MARK: - Tap handling

    /// Scoring rule: a correct tap scores 30–100 points on a linear
    /// scale based on reaction time within that round's window —
    /// instant taps earn the full 100, taps right at the edge still
    /// earn 30. Wrong taps and timeouts subtract 15. Final score is
    /// floored at 0.
    func tapItem(at id: Int) {
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        guard let tapped = items.first(where: { $0.id == id }) else { return }

        hasAnsweredCurrentRound = true
        roundTask?.cancel()

        if tapped.isOddOne {
            correctCount += 1
            lastAnswerWasCorrect = true

            let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? currentTimeWindow
            let clampedElapsed = min(max(elapsed, 0), currentTimeWindow)
            let speedFraction = 1.0 - (clampedElapsed / currentTimeWindow)
            runningScore += 30 + Int((70.0 * speedFraction).rounded())
        } else {
            wrongCount += 1
            lastAnswerWasCorrect = false
            runningScore -= 15
        }

        advanceToNextRound()
    }

    private func advanceToNextRound() {
        let nextIndex = currentRoundIndex + 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // brief pause so feedback is visible
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
            duration = Int(Double(Self.totalRounds) * Self.baseTimeWindowSeconds)
        }

        phase = .submitting

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Lost in Migration",
                category: "Attention",
                score: score,
                durationSeconds: duration,
                isFitTest: isFitTest
            )
            self.phase = .finished(score: score)
        }
    }
}