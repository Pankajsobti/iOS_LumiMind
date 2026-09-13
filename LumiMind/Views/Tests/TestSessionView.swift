import SwiftUI

// MARK: - TestSessionView
//
// Top-level container for the 5-subtest Cognitive Test session.
// Hosts the progress header and switches between each subtest's
// instruction screen, its live interaction, and the brief transition
// beat, per TestSessionViewModel's `phase`.

typealias TestSessionCompletion = (Int, [SubtestResult]) -> Void

struct TestSessionView: View {
    @StateObject private var viewModel: TestSessionViewModel
    let onSessionFinished: TestSessionCompletion

    init(gameResultViewModel: GameResultViewModel, onSessionFinished: @escaping TestSessionCompletion) {
        _viewModel = StateObject(wrappedValue: TestSessionViewModel(gameResultViewModel: gameResultViewModel))
        self.onSessionFinished = onSessionFinished
    }

    private var isMemorySpanSubtest: Bool {
        viewModel.currentSubtest == .forwardMemorySpan || viewModel.currentSubtest == .reverseMemorySpan
    }

    var body: some View {
        ZStack {
            if isMemorySpanSubtest {
                Image("bg-lake-sunset")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                DesignSystem.backgroundMain.ignoresSafeArea()
            }

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
        .onChange(of: viewModel.phase) { _, newPhase in
            if case .finished(let score) = newPhase {
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
        SuccessTransitionView(
            categoryGradient: viewModel.currentSubtest.category.gradient,
            subtestTitle: viewModel.currentSubtest.title,
            completedCount: viewModel.results.count,
            totalCount: viewModel.totalSubtests,
            isLastSubtest: viewModel.isLastSubtest
        )
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

// MARK: - SuccessTransitionView
//
// Replaces the old static checkmark + "Nice work" text shown during
// TestSessionViewModel's brief `.transition` phase (~1.2s between
// subtests). Purely presentational — reads already-computed values
// from the parent, doesn't touch the ViewModel or its timing.
private struct SuccessTransitionView: View {
    let categoryGradient: LinearGradient
    let subtestTitle: String
    let completedCount: Int
    let totalCount: Int
    let isLastSubtest: Bool

    @State private var circleScale: CGFloat = 0.4
    @State private var circleOpacity: Double = 0
    @State private var checkProgress: CGFloat = 0
    @State private var burstActive = false
    @State private var textOpacity: Double = 0

    private var particleCount: Int { isLastSubtest ? 16 : 10 }

    var body: some View {
        ZStack {
            // Faint celebratory glow behind everything, echoes the
            // subtest's own category color rather than a generic tint.
            Circle()
                .fill(categoryGradient)
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .opacity(circleOpacity * 0.35)

            ForEach(0..<particleCount, id: \.self) { i in
                particle(index: i)
            }

            VStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(categoryGradient)
                        .frame(width: 88, height: 88)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)

                    CheckmarkShape()
                        .trim(from: 0, to: checkProgress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .frame(width: 36, height: 30)
                }
                .scaleEffect(circleScale)
                .opacity(circleOpacity)

                VStack(spacing: DesignSystem.Spacing.xxs) {
                    Text(isLastSubtest ? "Last one done!" : "Nice work")
                        .font(DesignSystem.title2)
                        .foregroundColor(DesignSystem.backgroundOnboarding)

                    Text(subtestTitle)
                        .font(DesignSystem.subheadline)
                        .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))

                    Text("\(completedCount) of \(totalCount) complete")
                        .font(DesignSystem.caption)
                        .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.45))
                        .padding(.top, DesignSystem.Spacing.xxs)
                }
                .opacity(textOpacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { animateIn() }
    }

    private func particle(index: Int) -> some View {
        let angle = (Double(index) / Double(particleCount)) * 2 * .pi
        let travel: CGFloat = isLastSubtest ? 130 : 95
        let dx = cos(angle) * travel
        let dy = sin(angle) * travel
        let size: CGFloat = index.isMultiple(of: 2) ? 8 : 5

        return Circle()
            .fill(categoryGradient)
            .frame(width: size, height: size)
            .offset(x: burstActive ? dx : 0, y: burstActive ? dy : 0)
            .opacity(burstActive ? 0 : 1)
            .scaleEffect(burstActive ? 0.4 : 1)
            .animation(
                .easeOut(duration: 0.7).delay(Double(index) * 0.015),
                value: burstActive
            )
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            circleScale = 1.0
            circleOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 0.35).delay(0.15)) {
            checkProgress = 1.0
        }
        withAnimation(.easeIn(duration: 0.3).delay(0.25)) {
            textOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            burstActive = true
        }
    }
}

// MARK: - CheckmarkShape
//
// Hand-drawn checkmark path (rather than SF Symbol) so it can be
// trimmed and animated stroke-by-stroke on appear.
private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}