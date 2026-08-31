import SwiftUI

// MARK: - BrainShiftView
//
// Presentational only — renders whatever BrainShiftViewModel reports
// and forwards taps into `answer(isMatch:)`. Header uses the
// Flexibility category gradient, finished overlay shows score with a
// Continue button that calls onComplete (caller routes to
// ScienceExplainerView), same as the other games.

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
                instructionBanner

                Spacer()

                itemCard

                feedbackLabel
                    .frame(height: 22)

                Spacer()

                answerButtons
            }
            .padding(.vertical, DesignSystem.Spacing.lg)

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…")
            }

            if case .finished(let score) = viewModel.phase {
                finishedOverlay(score: score)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Brain Shift")
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.currentDecisionNumber)/\(BrainShiftViewModel.totalRounds)")
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            ProgressBar(fraction: viewModel.phase == .memorize ? 1.0 : viewModel.timeRemainingFraction)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.flexibilityGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Instruction banner

    private var instructionBanner: some View {
        Text(viewModel.phase == .memorize ? "Remember this symbol" : "Does this match the previous symbol?")
            .font(DesignSystem.headline)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.flexibilityGradient.opacity(0.7))
            .clipShape(Capsule())
    }

    // MARK: Item card

    private var itemCard: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius)
            .fill(DesignSystem.backgroundOnboarding.opacity(0.06))
            .frame(width: 160, height: 160)
            .overlay {
                Image(systemName: viewModel.currentSymbol.systemImageName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(viewModel.currentSymbol.color)
                    .frame(width: 90, height: 90)
            }
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if let correct = viewModel.lastAnswerWasCorrect {
            Text(correct ? "Correct!" : "Not quite")
                .font(DesignSystem.headline)
                .foregroundColor(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        } else {
            Text(" ")
                .font(DesignSystem.headline)
        }
    }

    // MARK: Answer buttons

    private var answerButtons: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            answerButton(isMatch: false, label: "NO")
            answerButton(isMatch: true, label: "YES")
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .disabled(viewModel.phase != .playing)
    }

    private func answerButton(isMatch: Bool, label: String) -> some View {
        Button {
            viewModel.answer(isMatch: isMatch)
        } label: {
            Text(label)
                .font(DesignSystem.buttonLabel)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.flexibilityGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
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