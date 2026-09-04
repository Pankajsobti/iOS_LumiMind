import SwiftUI

// MARK: - TestSessionView
//
// Top-level container for the 5-subtest Cognitive Test session.
// Hosts the progress header and switches between each subtest's
// instruction screen, its live interaction, and the brief transition
// beat, per TestSessionViewModel's `phase`.

struct TestSessionView: View {
    @StateObject private var viewModel: TestSessionViewModel
        let onSessionFinished: (Int, [SubtestResult]) -> Void

    init(gameResultViewModel: GameResultViewModel, onSessionFinished: @escaping (Int) -> Void) {
        _viewModel = StateObject(wrappedValue: TestSessionViewModel(gameResultViewModel: gameResultViewModel))
        self.onSessionFinished = onSessionFinished
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: 0) {
                if viewModel.phase != .instructions {
                    TestProgressHeaderView(
                        currentIndex: viewModel.currentIndex,
                        total: viewModel.totalSubtests,
                        progress: viewModel.progress
                    )
                }

                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.phase) { phase in
            if case .finished(let score) = phase {
                onSessionFinished(score, viewModel.results)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .instructions:
            SubtestInstructionView(
                subtest: viewModel.currentSubtest,
                timeLimitSeconds: TestSessionViewModel.timeLimitSeconds(for: viewModel.currentSubtest),
                onBegin: { viewModel.beginCurrentSubtest() }
            )

        case .running:
            subtestView(for: viewModel.currentSubtest)

        case .transition:
            transitionView

        case .submitting:
            submittingView

        case .finished:
            // Parent (onSessionFinished) handles navigation away —
            // this is a brief fallback in case that transition lags.
            submittingView
        }
    }

    @ViewBuilder
    private func subtestView(for subtest: CognitiveSubtest) -> some View {
        switch subtest {
        case .trailMakingA:
            TrailMakingView(mode: .a) { correct, total, duration in
                viewModel.completeCurrentSubtest(rawScore: correct, maxPossibleScore: total, durationSeconds: duration)
            }
        case .trailMakingB:
            TrailMakingView(mode: .b) { correct, total, duration in
                viewModel.completeCurrentSubtest(rawScore: correct, maxPossibleScore: total, durationSeconds: duration)
            }
        case .forwardMemorySpan:
            MemorySpanView(direction: .forward) { longestSpan, maxSpan, duration in
                viewModel.completeCurrentSubtest(rawScore: longestSpan, maxPossibleScore: maxSpan, durationSeconds: duration)
            }
        case .reverseMemorySpan:
            MemorySpanView(direction: .reverse) { longestSpan, maxSpan, duration in
                viewModel.completeCurrentSubtest(rawScore: longestSpan, maxPossibleScore: maxSpan, durationSeconds: duration)
            }
        case .digitSymbolCoding:
            DigitSymbolCodingView { correct, total, duration in
                viewModel.completeCurrentSubtest(rawScore: correct, maxPossibleScore: total, durationSeconds: duration)
            }
        }
    }

    private var transitionView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Text(viewModel.isLastSubtest ? "Last one done!" : "Nice work")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var submittingView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
                .tint(DesignSystem.backgroundOnboarding)
            Text("Calculating your results…")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}