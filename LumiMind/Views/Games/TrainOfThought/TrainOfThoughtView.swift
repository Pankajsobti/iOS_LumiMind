import SwiftUI

// MARK: - TrainOfThoughtView
//
// Presentational only — renders TrainOfThoughtViewModel's published
// state and forwards switch taps into `toggleSwitch(_:)`. Header now
// mirrors FlowSwitchView's stat bar (TIME / SCORE / multiplier),
// sitting inside the existing attentionGradient card. Track is drawn
// as a toy-railway (parallel rails + perpendicular ties) instead of a
// flat line. Finished overlay unchanged.

struct TrainOfThoughtView: View {
    @StateObject private var viewModel: TrainOfThoughtViewModel
    var onComplete: () -> Void

    private static let boardSize = CGSize(width: 340, height: 470)

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
            Text("Train of Thought")
                .font(DesignSystem.title2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            statRow
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.attentionGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Stat row (Flow-Switch-style TIME / SCORE / multiplier)

    private var statRow: some View {
        HStack(spacing: 0) {
            statGroup(label: "TIME", value: viewModel.timeRemainingLabel)
            statDivider
            statGroup(label: "SCORE", value: "\(viewModel.currentScore)")
            statDivider
            multiplierGroup
        }
        .frame(height: 44)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: 26)
    }

    private func statGroup(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(DesignSystem.roundedFont(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .tracking(0.5)
            Text(value)
                .font(DesignSystem.roundedFont(size: 17, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private var multiplierGroup: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<TrainOfThoughtViewModel.meterMax, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.meter ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            Text("x\(viewModel.multiplier)")
                .font(DesignSystem.roundedFont(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
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

    // MARK: Toy-railway track rendering
    //
    // Each segment is drawn as two thin parallel rails with
    // perpendicular wooden ties in between — a small geometry helper
    // computes the perpendicular offset per segment so this works for
    // any polyline, not just straight single-segment tracks.

    private static let railColor = Color(hex: "#B7AF9E")
    private static let tieColor = Color(hex: "#8B6F4E")
    private static let railOffset: CGFloat = 5
    private static let tieSpacing: CGFloat = 16
    private static let tieLength: CGFloat = 14

    private var trackCanvas: some View {
        Canvas { context, _ in
            for segment in TrainOfThoughtViewModel.segments.values {
                Self.drawRailTrack(points: segment.points, in: context)
            }
        }
    }

    private static func drawRailTrack(points: [CGPoint], in context: GraphicsContext) {
        guard points.count > 1 else { return }

        for i in 0..<points.count - 1 {
            let p0 = points[i], p1 = points[i + 1]
            let dx = p1.x - p0.x, dy = p1.y - p0.y
            let len = hypot(dx, dy)
            guard len > 0 else { continue }
            let ux = dx / len, uy = dy / len
            let px = -uy, py = ux // unit perpendicular

            // Ties first, so rails render on top.
            var tieDistance: CGFloat = 0
            while tieDistance <= len {
                let cx = p0.x + ux * tieDistance
                let cy = p0.y + uy * tieDistance
                var tie = Path()
                tie.move(to: CGPoint(x: cx - px * tieLength / 2, y: cy - py * tieLength / 2))
                tie.addLine(to: CGPoint(x: cx + px * tieLength / 2, y: cy + py * tieLength / 2))
                context.stroke(tie, with: .color(tieColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                tieDistance += tieSpacing
            }

            // Two parallel rails.
            for sign: CGFloat in [-1, 1] {
                var rail = Path()
                rail.move(to: CGPoint(x: p0.x + px * railOffset * sign, y: p0.y + py * railOffset * sign))
                rail.addLine(to: CGPoint(x: p1.x + px * railOffset * sign, y: p1.y + py * railOffset * sign))
                context.stroke(rail, with: .color(railColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
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

// MARK: - Preview

#Preview {
    TrainOfThoughtView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}