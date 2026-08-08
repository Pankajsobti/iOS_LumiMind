import SwiftUI

// MARK: - PiratePassageView
//
// Presentational only — renders whatever PiratePassageViewModel
// reports and forwards taps into `tapTile(at:)`. Same structure as the
// other four games: header uses the category gradient, finished
// overlay shows score with a Continue button that calls onComplete
// (caller routes to ScienceExplainerView).

struct PiratePassageView: View {
    @StateObject private var viewModel: PiratePassageViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PiratePassageViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: viewModel.gridSize)
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                header

                grid
                    .padding(.horizontal, DesignSystem.Spacing.md)

                feedbackLabel
                    .frame(height: 22)

                resetButton

                Spacer()
            }
            .padding(.top, DesignSystem.Spacing.lg)

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
                Text("Pirate Passage")
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)
                Spacer()
                Text("Level \(min(viewModel.levelIndex + 1, PiratePassageViewModel.totalLevels))/\(PiratePassageViewModel.totalLevels)")
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            HStack {
                Text("Moves: \(viewModel.movesUsed)")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
            }
            ProgressBar(fraction: viewModel.timeRemainingFraction)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.problemSolvingGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(viewModel.cells) { cell in
                Button {
                    viewModel.tapTile(at: cell.position)
                } label: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(fillColor(for: cell))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if cell.isStart {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.white)
                            } else if cell.isEnd {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.white)
                            } else if cell.isObstacle {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 10))
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.phase != .playing || viewModel.isTransitioning)
            }
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.currentPath)
    }

    private func fillColor(for cell: PiratePassageViewModel.GridCell) -> Color {
        if cell.isObstacle {
            return DesignSystem.backgroundOnboarding.opacity(0.85)
        }
        if viewModel.currentPath.contains(cell.position) {
            return Color(hex: "#4A7BFF")
        }
        return DesignSystem.backgroundOnboarding.opacity(0.08)
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if let succeeded = viewModel.lastLevelSucceeded {
            Text(succeeded ? "Treasure found!" : "Time's up — next level")
                .font(DesignSystem.headline)
                .foregroundColor(succeeded ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        } else {
            Text(" ")
                .font(DesignSystem.headline)
        }
    }

    private var resetButton: some View {
        Button {
            viewModel.resetPath()
        } label: {
            Text("Reset Path")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.backgroundOnboarding.opacity(0.08))
        .clipShape(Capsule())
        .disabled(viewModel.phase != .playing || viewModel.isTransitioning)
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
    PiratePassageView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}