import SwiftUI

// MARK: - MemoryMatrixView
//
// Renders whatever `MemoryMatrixViewModel` currently reports — the grid
// of tiles, current phase, level, and progress — and forwards taps into
// it. All gameplay/scoring/submission logic lives in the ViewModel; this
// View is purely presentational + navigation, same as before.
//
// Background/gradient usage unchanged from the previous implementation:
// cream `backgroundMain` for the game surface, `memoryGradient` for the
// header and highlighted tiles, `backgroundOnboarding` for overlay
// surfaces and the resting tile color.

struct MemoryMatrixView: View {
    @StateObject private var viewModel: MemoryMatrixViewModel

    /// Called after the result has been submitted and the user taps
    /// "Continue" — unchanged from the previous implementation.
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = true, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: MemoryMatrixViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), count: viewModel.gridSize)
    }

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

            if viewModel.roundJustCompleted {
                successBanner
            }

            if viewModel.hasError {
                errorBanner
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

                Text("Level \(viewModel.level)")
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            HStack {
                Text("\(viewModel.targetsFound)/\(viewModel.targetCount) found")
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
            ForEach(viewModel.tiles) { tile in
                TileView(tile: tile) {
                    viewModel.tap(tile)
                }
            }
        }
        .allowsHitTesting(viewModel.canInteract)
        .animation(.easeInOut(duration: 0.2), value: viewModel.gridSize)
    }

    // MARK: Preview overlay

    private var previewOverlay: some View {
        VStack {
            Spacer()
            Text("Memorize the pattern!")
                .font(DesignSystem.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.backgroundOnboarding.opacity(0.85))
                .clipShape(Capsule())
                .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: Transient round-outcome banners

    private var successBanner: some View {
        VStack {
            Spacer()
            Text("Nice! Next pattern coming up…")
                .font(DesignSystem.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.memoryGradient)
                .clipShape(Capsule())
                .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: viewModel.roundJustCompleted)
    }

    private var errorBanner: some View {
        VStack {
            Spacer()
            Text("Not quite — that spot wasn't highlighted")
                .font(DesignSystem.headline)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(Color(hex: "#FF6B4A"))
                .clipShape(Capsule())
                .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: viewModel.hasError)
    }

    // MARK: Submitting / finished overlays
    // Unchanged from the previous implementation.

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

// MARK: - TileView

private struct TileView: View {
    let tile: MemoryMatrixViewModel.Tile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                .fill(fillStyle)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    switch tile.state {
                    case .correct:
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    case .incorrect:
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    case .normal, .highlighted:
                        EmptyView()
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(tile.state != .normal)
        .animation(.easeOut(duration: 0.2), value: tile.state)
    }

    private var fillStyle: AnyShapeStyle {
        switch tile.state {
        case .highlighted:
            AnyShapeStyle(DesignSystem.memoryGradient)
        case .correct:
            AnyShapeStyle(DesignSystem.memoryGradient)
        case .incorrect:
            AnyShapeStyle(Color(hex: "#FF6B4A"))
        case .normal:
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