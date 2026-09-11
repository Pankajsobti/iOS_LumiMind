import SwiftUI

// MARK: - MemoryMatrixView
//
// Renders whatever `MemoryMatrixViewModel` currently reports — the grid
// of tiles, current phase, level, and progress — and forwards taps into
// it. All gameplay/scoring/submission logic lives in the ViewModel; this
// View is purely presentational + navigation, same as before.
//
// RESTYLE PASS: layout now matches the reference "game board" look —
// a top stat bar (pause / tiles / trial / score) above a single bordered
// board containing a gapless grid of square cells. Colors come from the
// new `matrixBoardBackground` / `matrixTileResting` / `matrixTileGradient`
// tokens added to DesignSystem specifically for this screen (see that
// file's "Memory Matrix Board" section) — so the brown/teal look is
// still sourced from DesignSystem, not hardcoded here.
//
// Session length is now fixed at `MemoryMatrixViewModel.totalTrials`
// (12), matching the reference's "TRIAL 7 of 12".

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
        Array(repeating: GridItem(.flexible(), spacing: 0), count: viewModel.gridSize)
    }

    var body: some View {
        ZStack {
            DesignSystem.matrixBoardBackground
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                statBar

                Spacer()

                board
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()
                Spacer()
            }
            .padding(.top, DesignSystem.Spacing.md)

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

    // MARK: Top stat bar

    private var statBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: { /* pause action owned by caller / navigation */ }) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(DesignSystem.backgroundOnboarding.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            statGroup(label: "TILES", value: "\(viewModel.targetCount)")
            statGroup(label: "TRIAL", value: "\(viewModel.level) of \(MemoryMatrixViewModel.totalTrials)")
            statGroup(label: "SCORE", value: "\(viewModel.liveScore)")
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private func statGroup(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(DesignSystem.roundedFont(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .tracking(0.5)
            Text(value)
                .font(DesignSystem.roundedFont(size: 17, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: Board

    private var board: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(viewModel.tiles) { tile in
                TileView(tile: tile) {
                    viewModel.tap(tile)
                }
            }
        }
        .padding(DesignSystem.Spacing.xs)
        .background(DesignSystem.matrixBoardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                .stroke(Color.white.opacity(0.25), lineWidth: 3)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
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
                .background(DesignSystem.matrixTileGradient)
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
                .background(DesignSystem.matrixTileGradient)
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
            Color.black.opacity(0.55).ignoresSafeArea()
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
            Color.black.opacity(0.55).ignoresSafeArea()

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
                        .foregroundColor(.white)
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
            fillStyle
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
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

    private var fillStyle: AnyView {
        switch tile.state {
        case .highlighted:
            return AnyView(Rectangle().fill(DesignSystem.matrixTileGradient))
        case .correct:
            return AnyView(Rectangle().fill(DesignSystem.matrixTileGradient))
        case .incorrect:
            return AnyView(Rectangle().fill(Color(hex: "#FF6B4A")))
        case .normal:
            return AnyView(Rectangle().fill(DesignSystem.matrixTileResting))
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