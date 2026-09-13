import SwiftUI

// MARK: - BrainShiftView
//
// REWRITE to match the actual "Brain Shift" task-switching design doc:
// a rule indicator (COLOR / SHAPE) that flashes when it changes, a
// two-attribute stimulus (shape + color), and a variable number of
// text-labeled answer buttons — never color-only, per the
// colorblind-accessibility requirement. Countdown, timer bar, score,
// and streak all come from BrainShiftViewModel; this view is
// presentation-only, matching the rest of the games.

struct BrainShiftView: View {
    @StateObject private var viewModel: BrainShiftViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BrainShiftViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                header
                ruleBanner

                Spacer()

                stimulusCard

                feedbackLabel
                    .frame(height: 22)

                Spacer()

                answerButtons
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
            .opacity(isPlayable ? 1 : 0.15)
            .disabled(!isPlayable)

            if case .countdown(let tick) = viewModel.phase {
                countdownOverlay(tick: tick)
            }

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…")
            }

            if case .finished(let score) = viewModel.phase {
                finishedOverlay(score: score)
            }
        }
    }

    private var isPlayable: Bool { viewModel.phase == .playing }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Brain Shift")
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.currentTrial.roundNumber)/\(BrainShiftViewModel.totalRounds)")
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            HStack {
                Text("Score \(viewModel.score)")
                    .font(DesignSystem.roundedFont(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                if viewModel.streak > 1 {
                    Text("🔥 ×\(viewModel.streak)")
                        .font(DesignSystem.roundedFont(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            ProgressBar(fraction: viewModel.timeRemainingFraction)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.flexibilityGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Rule banner (doc section 8 — animates on switch)

    private var ruleBanner: some View {
        Text("RULE: \(viewModel.currentTrial.rule.label)")
            .font(DesignSystem.headline)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.flexibilityGradient.opacity(0.7))
            .clipShape(Capsule())
            .scaleEffect(viewModel.justSwitchedRule ? 1.12 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: viewModel.justSwitchedRule)
            .accessibilityLabel("Current rule: \(viewModel.currentTrial.rule.label.capitalized)")
    }

    // MARK: Stimulus card

    private var stimulusCard: some View {
        let stimulus = viewModel.currentTrial.stimulus
        return RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius)
            .fill(DesignSystem.backgroundOnboarding.opacity(0.06))
            .frame(width: 160, height: 160)
            .overlay {
                Image(systemName: stimulus.shape.systemImageName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(stimulus.color.color)
                    .frame(width: 90, height: 90)
            }
            .accessibilityElement()
            .accessibilityLabel(stimulus.accessibilityLabel)
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if let correct = viewModel.lastAnswerWasCorrect {
            Text(correct ? "✓ Correct  +\(viewModel.lastScoreDelta)" : "✗ Not quite")
                .font(DesignSystem.headline)
                .foregroundColor(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        } else {
            Text(" ")
                .font(DesignSystem.headline)
        }
    }

    // MARK: Answer buttons (doc section 9, text-labeled per section 28)

    private var answerButtons: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(viewModel.currentTrial.options, id: \.self) { option in
                answerButton(option)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func answerButton(_ option: String) -> some View {
        Button {
            viewModel.answer(option)
        } label: {
            Text(option)
                .font(DesignSystem.buttonLabel)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.flexibilityGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
        .accessibilityLabel(option.capitalized)
    }

    // MARK: Countdown overlay (doc section 4)

    private func countdownOverlay(tick: Int) -> some View {
        ZStack {
            DesignSystem.backgroundMain.opacity(0.92).ignoresSafeArea()
            Text(tick == 0 ? "GO" : "\(tick)")
                .font(DesignSystem.roundedFont(size: 64, weight: .bold))
                .foregroundColor(.white)
                .id(tick)
                .transition(.scale.combined(with: .opacity))
                .animation(.easeOut(duration: 0.3), value: tick)
        }
    }

    // MARK: Overlays

    private func statusOverlay(message: String) -> some View {
        ZStack {
            DesignSystem.backgroundOnboarding.opacity(0.55).ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView().tint(DesignSystem.backgroundMain)
                Text(message)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundMain)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.backgroundOnboarding)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        }
    }

    private func finishedOverlay(score: Int) -> some View {
        ZStack {
            DesignSystem.backgroundOnboarding.opacity(0.55).ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Nice work!")
                    .font(DesignSystem.title2)
                    .foregroundColor(DesignSystem.backgroundMain)

                Text("Score: \(score)")
                    .font(DesignSystem.roundedFont(size: 28, weight: .bold))
                    .foregroundColor(DesignSystem.backgroundMain)

                VStack(spacing: 4) {
                    Text("Accuracy: \(Int((viewModel.finalAccuracy * 100).rounded()))%")
                    Text("Best streak: \(viewModel.bestStreak)")
                    Text(String(format: "Avg response: %.2fs", viewModel.finalAverageResponseTime))
                }
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundMain.opacity(0.8))

                if let error = viewModel.submissionErrorMessage {
                    Text(error)
                        .font(DesignSystem.caption)
                        .foregroundColor(Color(hex: "#FF6B4A"))
                        .multilineTextAlignment(.center)
                }

                Button(action: onComplete) {
                    Text("Continue")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
                .buttonStyle(.plain)
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: 320)
            .background(DesignSystem.backgroundOnboarding)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        }
    }
}

// MARK: - ProgressBar

private struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.3))
                Capsule().fill(.white)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Preview

#Preview {
    BrainShiftView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}