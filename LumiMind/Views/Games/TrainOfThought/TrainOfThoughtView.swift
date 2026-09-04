import SwiftUI

// MARK: - TrainOfThoughtView
//
// Presentational only — renders TrainOfThoughtViewModel's published
// state and forwards switch taps into `toggleSwitch(_:)`. Same
// structure as LostInMigrationView: header uses the category
// gradient, finished overlay shows score with a Continue button that
// calls onComplete (caller routes to ScienceExplainerView).

struct TrainOfThoughtView: View {
    @StateObject private var viewModel: TrainOfThoughtViewModel
    var onComplete: () -> Void

    private static let boardSize = CGSize(width: 340, height: 420)

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: TrainOfThoughtViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                header
                Spacer()
                board
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
                Text("Train of Thought")
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.successCount) routed")
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

    // MARK: Board

    private var board: some View {
        ZStack {
            trackCanvas
            ForEach(TrainOfThoughtViewModel.stations) { station in
                stationView(station)
                    .position(station.position)
            }
            ForEach(viewModel.switches) { sw in
                switchView(sw)
                    .position(sw.position)
            }
            ForEach(viewModel.trains) { train in
                trainView(train)
            }
        }
        .frame(width: Self.boardSize.width, height: Self.boardSize.height)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private var trackCanvas: some View {
        Canvas { context, _ in
            for segment in TrainOfThoughtViewModel.segments.values {
                var path = Path()
                path.move(to: segment.points[0])
                for point in segment.points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(.gray.opacity(0.35)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func stationView(_ station: TrainOfThoughtViewModel.StationState) -> some View {
        StationSprite(colorHex: station.colorHex, size: 40)
    }

    private func switchView(_ sw: TrainOfThoughtViewModel.SwitchState) -> some View {
        Button {
            viewModel.toggleSwitch(sw.id)
        } label: {
            ZStack {
                Circle().fill(DesignSystem.attentionGradient)
                    .frame(width: 30, height: 30)
                Image(systemName: sw.activeBranch == 0 ? "arrow.down.left" : "arrow.down.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.phase != .playing)
    }

    private func trainView(_ train: TrainOfThoughtViewModel.TrainState) -> some View {
        let seg = TrainOfThoughtViewModel.segments[train.currentSegmentId]
        let point = seg.map { TrainOfThoughtViewModel.point(at: train.progress, on: $0.points) } ?? .zero
        let heading = seg.map { headingAngle(for: train.progress, on: $0.points) } ?? .zero
        return TrainSprite(colorHex: train.colorHex, size: 26, heading: heading)
            .position(point)
            .animation(.linear(duration: 1.0 / 30.0), value: train.progress)
    }

    /// Approximates the train's facing direction by sampling a point
    /// just ahead on its current polyline and measuring the angle
    /// between the two — keeps the sprite visually oriented along
    /// the track instead of always facing the same way.
    private func headingAngle(for progress: Double, on points: [CGPoint]) -> Angle {
        let here = TrainOfThoughtViewModel.point(at: progress, on: points)
        let ahead = TrainOfThoughtViewModel.point(at: min(1, progress + 0.02), on: points)
        let dx = ahead.x - here.x
        let dy = ahead.y - here.y
        guard dx != 0 || dy != 0 else { return .zero }
        return Angle(radians: Double(atan2(dy, dx)))
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if let good = viewModel.lastEventWasGood {
            Text(good ? "On track!" : "Off route")
                .font(DesignSystem.headline)
                .foregroundColor(good ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        } else {
            Text(" ").font(DesignSystem.headline)
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

                Text("\(viewModel.successCount) routed · \(viewModel.mistakeCount) wrong · \(viewModel.collisionCount) collisions")
                    .font(DesignSystem.caption)
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
    TrainOfThoughtView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}