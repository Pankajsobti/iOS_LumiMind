//
//  TestSessionViewModel.swift
//  LumiMind
//
//  Owns the cognitive test session: which subtest is active, overall
//  progress, the per-subtest timer, and collected results. Mirrors
//  MemoryMatrixViewModel's pattern (phase enum + Combine timer +
//  auto-submit through GameResultViewModel on completion) but drives
//  a sequence of 5 subtests instead of one game.
//

import Foundation
import Combine

@MainActor
final class TestSessionViewModel: ObservableObject {

    // MARK: Phase

    enum Phase: Equatable {
        case instructions   // pre-subtest instruction screen
        case running         // subtest interaction is live
        case transition       // brief "Nice work" beat between subtests
        case submitting        // all subtests done, result posting
        case finished(score: Int)
    }

    static let subtestOrder: [CognitiveSubtest] = [
        .trailMakingA, .trailMakingB, .forwardMemorySpan, .reverseMemorySpan, .digitSymbolCoding
    ]

    /// Per-subtest time limit shown/enforced by the subtest's own view.
    /// Exposed here so the progress header and instruction screen can
    /// display it without duplicating the numbers.
    static func timeLimitSeconds(for subtest: CognitiveSubtest) -> Int {
        switch subtest {
        case .trailMakingA: return 60
        case .trailMakingB: return 90
        case .forwardMemorySpan, .reverseMemorySpan: return 120
        case .digitSymbolCoding: return 90
        }
    }

    // MARK: Published state

    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var phase: Phase = .instructions
    @Published private(set) var results: [SubtestResult] = []

    var currentSubtest: CognitiveSubtest { Self.subtestOrder[currentIndex] }
    var totalSubtests: Int { Self.subtestOrder.count }
    var progress: Double { Double(currentIndex) / Double(totalSubtests) }
    var isLastSubtest: Bool { currentIndex == totalSubtests - 1 }

    var isBusySubmitting: Bool { gameResultViewModel.isLoading }
    var submissionErrorMessage: String? { gameResultViewModel.errorMessage }

    // MARK: Private

    private let gameResultViewModel: GameResultViewModel
    private var sessionStartedAt: Date?

    init(gameResultViewModel: GameResultViewModel) {
        self.gameResultViewModel = gameResultViewModel
        sessionStartedAt = Date()
    }

    // MARK: - Flow control

    /// Called by the instruction screen's "Begin" button.
    func beginCurrentSubtest() {
        guard phase == .instructions else { return }
        phase = .running
    }

    /// Called by a subtest view when its interaction ends (completed
    /// or timed out). Advances to a brief transition beat, then either
    /// the next subtest's instructions or final submission.
    func completeCurrentSubtest(rawScore: Int, maxPossibleScore: Int, durationSeconds: Int) {
        guard phase == .running else { return }

        var result = SubtestResult(
            subtest: currentSubtest,
            rawScore: rawScore,
            maxPossibleScore: maxPossibleScore,
            durationSeconds: durationSeconds
        )
        result.percentile = CognitiveScoring.percentile(
            forNormalizedPercent: result.normalizedPercent,
            domainLabel: currentSubtest.domainLabel
        )
        results.append(result)
        phase = .transition

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self?.advance()
        }
    }

    private func advance() {
        if isLastSubtest {
            submitSession()
        } else {
            currentIndex += 1
            phase = .instructions
        }
    }

    // MARK: - Submission

    /// Composite score: mean of each subtest's normalized percent,
    /// scaled to 0–100. Simple and explicit, same spirit as
    /// MemoryMatrixViewModel's scoring comment — easy to justify, easy
    /// to replace with a real normed formula later.
    private func computeCompositeScore() -> Int {
        CognitiveScoring.grandIndexScore(results: results)
    }

    private func submitSession() {
        phase = .submitting
        let score = computeCompositeScore()
        let totalDuration: Int
        if let sessionStartedAt {
            totalDuration = max(1, Int(Date().timeIntervalSince(sessionStartedAt).rounded()))
        } else {
            totalDuration = results.reduce(0) { $0 + $1.durationSeconds }
        }

        Task { [weak self] in
            guard let self else { return }
            await self.gameResultViewModel.submitResult(
                gameName: "Cognitive Test",
                category: "Cognitive Test",
                score: score,
                durationSeconds: totalDuration,
                isFitTest: false
            )
            self.phase = .finished(score: score)
        }
    }
}