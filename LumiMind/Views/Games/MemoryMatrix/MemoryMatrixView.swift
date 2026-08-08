import SwiftUI

// MARK: - MemoryMatrixView
//
// The user's first actual gameplay experience. Renders whatever
// `MemoryMatrixViewModel` currently reports — grid, timer, phase — and
// forwards taps into it. All gameplay/scoring/submission logic lives in
// the ViewModel; this View is purely presentational + navigation.
//
// Background switches to the cream main-app token here (first taste of
// the main app aesthetic), unlike the navy used through onboarding and
// FitTestIntroView. Header uses the locked Memory category gradient.

struct MemoryMatrixView: View {
    @StateObject private var viewModel: MemoryMatrixViewModel

    /// Called after the result has been submitted and the user taps
    /// "Continue" — the caller routes to Results / 30-Day Plan (#12).
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = true, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: MemoryMatrixViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: 4)

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                header

                grid
                    .padding(.horizontal, DesignSystem.Spacing.md)

                Spacer()
            }
            .padding(.top, DesignSystem.Spacing.lg)

            if case .preview = viewModel.phase {
                previewOverlay
            }

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…", showsSpinner: true)
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
                Text("Memory Matrix")
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)

                Spacer()

                Label("\(viewModel.timeRemaining)s", systemImage: "timer")
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            HStack {
                Text("\(viewModel.matchedPairs)/\(MemoryMatrixViewModel.pairCount) pairs matched")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.memoryGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.sm) {
            ForEach(viewModel.cards) { card in
                CardTile(card: card) {
                    viewModel.tap(card)
                }
            }
        }
    }

    // MARK: Preview overlay

    private var previewOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Spacer()
            Text("Memorize the board!")
                .font(DesignSystem.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.backgroundOnboarding.opacity(0.85))
                .clipShape(Capsule())
                .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: Submitting / finished overlays

    private func statusOverlay(message: String, showsSpinner: Bool) -> some View {
        ZStack {
            DesignSystem.backgroundOnboarding.opacity(0.55).ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.md) {
                if showsSpinner {
                    ProgressView()
                        .tint(DesignSystem.backgroundMain)
                }
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

// MARK: - CardTile

private struct CardTile: View {
    let card: MemoryMatrixViewModel.Card
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                .fill(fillStyle)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if card.isFaceUp || card.isMatched {
                        Image(systemName: card.symbolName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(card.isFaceUp || card.isMatched)
        .animation(.easeOut(duration: 0.2), value: card.isFaceUp)
    }

    private var fillStyle: AnyShapeStyle {
        if card.isMatched {
            AnyShapeStyle(DesignSystem.memoryGradient.opacity(0.5))
        } else if card.isFaceUp {
            AnyShapeStyle(DesignSystem.memoryGradient)
        } else {
            AnyShapeStyle(DesignSystem.backgroundOnboarding.opacity(0.85))
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryMatrixView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to Results / 30-Day Plan") }
    )
}