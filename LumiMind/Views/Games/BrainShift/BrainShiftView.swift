import SwiftUI

// MARK: - BrainShiftView
//
// Presentational only — renders whatever BrainShiftViewModel reports
// and forwards taps into `chooseBucket(_:)`. Same structure as the
// other three games: header uses the category gradient, finished
// overlay shows score with a Continue button that calls onComplete
// (caller routes to ScienceExplainerView).

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

                itemCard

                feedbackLabel
                    .frame(height: 22)

                Spacer()

                buckets
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
                Text("\(min(viewModel.currentRoundIndex + 1, BrainShiftViewModel.totalRounds))/\(BrainShiftViewModel.totalRounds)")
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            ProgressBar(fraction: viewModel.timeRemainingFraction)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.flexibilityGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Rule banner

    private var ruleBanner: some View {
        Text(viewModel.currentRule.label)
            .font(DesignSystem.headline)
            .foregroundColor(.white)
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
                itemShape
                    .fill(itemColor)
                    .frame(width: 90, height: 90)
            }
    }

    private var itemColor: Color {
        viewModel.currentItem.color == .red ? Color(hex: "#F857A6") : Color(hex: "#4A7BFF")
    }

    private var itemShape: AnyShape {
        if viewModel.currentItem.shape == .circle {
            AnyShape(Circle())
        } else {
            AnyShape(RoundedRectangle(cornerRadius: 12))
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

    // MARK: Buckets

    private var buckets: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            bucketButton(bucket: .left)
            bucketButton(bucket: .right)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .disabled(viewModel.phase != .playing)
    }

    private func bucketButton(bucket: BrainShiftViewModel.Bucket) -> some View {
        Button {
            viewModel.chooseBucket(bucket)
        } label: {
            VStack(spacing: DesignSystem.Spacing.xxs) {
                bucketIcon(for: bucket)
                    .frame(width: 32, height: 32)
                Text(bucketLabel(for: bucket))
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.flexibilityGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }

    private func bucketLabel(for bucket: BrainShiftViewModel.Bucket) -> String {
        switch (viewModel.currentRule, bucket) {
        case (.color, .left): return "Red"
        case (.color, .right): return "Blue"
        case (.shape, .left): return "Circle"
        case (.shape, .right): return "Square"
        }
    }

    @ViewBuilder
    private func bucketIcon(for bucket: BrainShiftViewModel.Bucket) -> some View {
        switch (viewModel.currentRule, bucket) {
        case (.color, .left):
            Circle().fill(Color(hex: "#F857A6"))
        case (.color, .right):
            Circle().fill(Color(hex: "#4A7BFF"))
        case (.shape, .left):
            Circle().fill(.white)
        case (.shape, .right):
            RoundedRectangle(cornerRadius: 6).fill(.white)
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