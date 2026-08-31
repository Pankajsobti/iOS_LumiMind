import Foundation
import SwiftUI
import Combine

// MARK: - BrainShiftViewModel
//
// Owns gameplay state for Brain Shift: a 1-back symbol-matching task.
// One symbol is shown per beat; from the second symbol onward the
// player judges whether it matches the symbol shown immediately
// before it (Yes/No). View only renders published state and forwards
// taps into `answer(isMatch:)`; this ViewModel submits the result
// itself the moment the game ends.

@MainActor
final class BrainShiftViewModel: ObservableObject {

    // MARK: Game phase

    enum Phase: Equatable {
        /// Opening beat — first symbol is shown with no decision to make.
        case memorize
        case playing
        case submitting
        case finished(score: Int)
    }

    enum ItemSymbol: CaseIterable {
        case circle, square, triangle, star, hexagon, diamond

        var systemImageName: String {
            switch self {
            case .circle:   return "circle.fill"
            case .square:   return "square.fill"
            case .triangle: return "triangle.fill"
            case .star:     return "star.fill"
            case .hexagon:  return "hexagon.fill"
            case .diamond:  return "diamond.fill"
            }
        }

        /// Each symbol carries a fixed, distinct color so a "match" is
        /// a single unambiguous visual judgment (shape + color together).
        var color: Color {
            switch self {
            case .circle:   return Color(hex: "#4A7BFF")
            case .square:   return Color(hex: "#FF5E5B")
            case .triangle: return Color(hex: "#2ECC71")
            case .star:     return Color(hex: "#D46BB5")
            case .hexagon:  return Color(hex: "#00C2A8")
            case .diamond:  return Color(hex: "#F857A6")
            }
        }
    }

    private struct Round {
        let symbol: ItemSymbol
        /// nil for index 0 (memorize beat, no decision to make).
        let isMatch: Bool?
    }

    // MARK: Tunables

    /// Number of scored Yes/No decision rounds — excludes the opening
    /// "memorize" beat. Drives the header's "n/totalRounds" display.
    static let totalRounds = 20
    private static let totalItems = totalRounds + 1
    static let responseWindowSeconds: Double = 3.5
    private static let memorizeDurationSeconds: Double = 1.1
    /// Probability that consecutive symbols match — tuned for a roughly
    /// even mix of Yes/No correct answers across a session.
    private static let matchProbability: Double = 0.4

    // MARK: Published state

    @Published private(set) var phase: Phase = .memorize
    @Published private(set) var currentItemIndex: Int = 0
    @Published private(set) var currentSymbol: ItemSymbol = .circle
    /// 1.0 = window just opened, 0.0 = window closed.
    @Published private(set) var timeRemainingFraction: Double = 1.0
    @Published private(set) var correctCount: Int = 0
    @Published private(set) var wrongCount: Int = 0
    @Published private(set) var lastAnswerWasCorrect: Bool?

    /// 1-based decision round number for header display.
    var currentDecisionNumber: Int {
        min(max(currentItemIndex, 1), Self.totalRounds)
    }

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
        currentItemIndex = 0
        lastAnswerWasCorrect = nil
        rounds = Self.generateRounds(count: Self.totalItems)
        phase = .memorize
        gameStartedAt = Date()
        beginItem(at: 0)
    }

    private static func generateRounds(count: Int) -> [Round] {
        var symbols: [ItemSymbol] = [ItemSymbol.allCases.randomElement()!]
        for i in 1..<count {
            let previous = symbols[i - 1]
            if Double.random(in: 0...1) < matchProbability {
                symbols.append(previous)
            } else {
                var next = ItemSymbol.allCases.randomElement()!
                while next == previous {
                    next = ItemSymbol.allCases.randomElement()!
                }
                symbols.append(next)
            }
        }
        return symbols.enumerated().map { index, symbol in
            let isMatch = index == 0 ? nil : (symbol == symbols[index - 1])
            return Round(symbol: symbol, isMatch: isMatch)
        }
    }

    // MARK: - Item lifecycle

    private func beginItem(at index: Int) {
        guard index < rounds.count else {
            endGame()
            return
        }
        roundTask?.cancel()

        currentItemIndex = index
        currentSymbol = rounds[index].symbol
        hasAnsweredCurrentRound = false
        roundStartedAt = Date()
        timeRemainingFraction = 1.0

        if index == 0 {
            phase = .memorize
            roundTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Self.memorizeDurationSeconds * 1_000_000_000))
                guard let self, !Task.isCancelled else { return }
                self.beginItem(at: index + 1)
            }
            return
        }

        phase = .playing
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
        advanceToNextItem()
    }

    // MARK: - Answering

    /// Scoring: a correct Yes/No answer scores 30–90 points on a linear
    /// scale based on reaction time within the response window. Wrong
    /// answers and timeouts subtract 15. Final score is floored at 0.
    func answer(isMatch userSaysMatch: Bool) {
        guard phase == .playing, !hasAnsweredCurrentRound else { return }
        hasAnsweredCurrentRound = true
        roundTask?.cancel()

        let round = rounds[currentItemIndex]
        let actualIsMatch = round.isMatch ?? false
        let isCorrect = (userSaysMatch == actualIsMatch)

        if isCorrect {
            correctCount += 1
            lastAnswerWasCorrect = true

            let elapsed = roundStartedAt.map { Date().timeIntervalSince($0) } ?? Self.responseWindowSeconds
            let clampedElapsed = min(max(elapsed, 0), Self.responseWindowSeconds)
            let speedFraction = 1.0 - (clampedElapsed / Self.responseWindowSeconds)
            runningScore += 30 + Int((60.0 * speedFraction).rounded())
        } else {
            wrongCount += 1
            lastAnswerWasCorrect = false
            runningScore -= 15
        }

        advanceToNextItem()
    }

    private func advanceToNextItem() {
        let nextIndex = currentItemIndex + 1
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self else { return }
            self.beginItem(at: nextIndex)
        }
    }

    // MARK: - Game over + scoring

    private func endGame() {
        guard phase == .playing || phase == .memorize else { return }
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