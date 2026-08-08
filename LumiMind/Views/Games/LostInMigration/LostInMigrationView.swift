import SwiftUI

// MARK: - LostInMigrationView
//
// Presentational only — renders whatever LostInMigrationViewModel
// reports and forwards taps into `tapItem(at:)`. Same structure as
// SpeedMatchView/MemoryMatrixView: header uses the category gradient,
// finished overlay shows score with a Continue button that calls
// onComplete (caller routes to ScienceExplainerView).

struct LostInMigrationView: View {
    @StateObject private var viewModel: LostInMigrationViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: LostInMigrationViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: viewModel.gridColumns)
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                header

                Spacer()

                grid
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                feedbackLabel
                    .frame(height: 22)

                Spacer()
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
                Text("Lost in Migration")
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)
                Spacer()
                Text("\(min(viewModel.currentRoundIndex + 1, LostInMigrationViewModel.totalRounds))/\(LostInMigrationViewModel.totalRounds)")
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            ProgressBar(fraction: viewModel.timeRemainingFraction)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.attentionGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.sm) {
            ForEach(viewModel.items) { item in
                Button {
                    viewModel.tapItem(at: item.id)
                } label: {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                        .fill(DesignSystem.attentionGradient.opacity(0.15))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(DesignSystem.backgroundOnboarding)
                                .rotationEffect(.degrees(item.rotationDegrees))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(viewModel.phase != .playing)
        .animation(.easeOut(duration: 0.15), value: viewModel.items)
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if let correct = viewModel.lastAnswerWasCorrect {
            Text(correct ? "Spotted it!" : "Missed it")
                .font(DesignSystem.headline)
                .foregroundColor(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        } else {
            Text(" ")
                .font(DesignSystem.headline)
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
    LostInMigrationView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}