import SwiftUI

// MARK: - TrainOfThoughtView
//
// Presentational only — renders TrainOfThoughtViewModel's published
// state and forwards switch taps into `toggleSwitch(_:)`.
//
// REVISION (background pass, matching the Splitting Seeds rework):
// previously the track sat inside its own bordered cream "board" card,
// floating below a solid teal title card, on a backdrop with trees
// only along the very bottom edge. Per the reference art, the real
// game has the track sitting directly on an open forest — no board
// card at all — with trees scattered across the whole screen and a
// couple of larger "sentinel" trees anchoring the corners, and a slim
// translucent HUD bar instead of a solid title card. This revision
// makes those changes. Track rendering, switches, stations, trains,
// and all scoring/collision logic in the ViewModel are untouched —
// only the backdrop, the board's framing, and the header's styling
// changed.
//
// ASSUMPTION (flagging per project convention): dropped the on-screen
// "Train of Thought" title text, since neither the reference art nor
// the other games (LostInMigration, SplittingSeeds) show a title
// during gameplay — the name is already shown on GameIntroView before
// this screen. Also added a pause button to match those two screens'
// header convention (no-op placeholder, same as elsewhere). Flag
// either if you want them handled differently.

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
            ForestBackdrop()
                .ignoresSafeArea()

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

    // MARK: Header (pause + TIME / SCORE / multiplier, glass style)
    //
    // Restyled from a solid attentionGradient title card into the same
    // translucent glass HUD used by LostInMigrationView / the reworked
    // SplittingSeedsView, so the forest backdrop shows through.

    private var header: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            pauseButton

            statRow
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(.ultraThinMaterial)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private var pauseButton: some View {
        Button(action: { /* pause owned by caller / navigation */ }) {
            Image(systemName: "pause.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
    //
    // No longer a bordered/shadowed cream card — the track, switches,
    // stations, and trains now sit directly on the open forest
    // backdrop, matching the reference art. The fixed frame size is
    // kept only as the coordinate space the ViewModel's segment/
    // station/switch points are authored against — it's otherwise
    // invisible.

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
    }

    // MARK: Toy-railway track rendering
    //
    // Each segment is drawn as two thin parallel rails with
    // perpendicular wooden ties in between — a small geometry helper
    // computes the perpendicular offset per segment so this works for
    // any polyline, not just straight single-segment tracks. Colors
    // lightened slightly from the original so the rails read clearly
    // against the green backdrop instead of a cream board.

    private static let railColor = Color(hex: "#E8E1CE")
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

// MARK: - ForestBackdrop
//
// Full-screen scene behind the whole game, matching the reference art:
// a solid pine-green gradient with trees scattered across the entire
// screen (not just a strip at the bottom) plus two larger "sentinel"
// trees anchoring the top corners. Scoped to this file only (own
// color constants / specs), same pattern SplittingSeedsView's
// ForestBackdrop uses — no new tokens added to DesignSystem.

private struct ForestBackdrop: View {
    private static let top = Color(hex: "#2F8F5D")
    private static let bottom = Color(hex: "#123A26")

    private struct TreeSpec: Identifiable {
        let id = Int.random(in: 0...Int.max)
        let position: UnitPoint
        let scale: CGFloat
        let opacity: Double
    }

    /// Scattered background trees across the whole screen.
    private static let scatteredTrees: [TreeSpec] = [
        TreeSpec(position: UnitPoint(x: 0.1, y: 0.2), scale: 0.55, opacity: 0.35),
        TreeSpec(position: UnitPoint(x: 0.85, y: 0.15), scale: 0.45, opacity: 0.3),
        TreeSpec(position: UnitPoint(x: 0.05, y: 0.55), scale: 0.6, opacity: 0.3),
        TreeSpec(position: UnitPoint(x: 0.92, y: 0.48), scale: 0.5, opacity: 0.3),
        TreeSpec(position: UnitPoint(x: 0.15, y: 0.85), scale: 0.65, opacity: 0.35),
        TreeSpec(position: UnitPoint(x: 0.88, y: 0.82), scale: 0.55, opacity: 0.3),
        TreeSpec(position: UnitPoint(x: 0.5, y: 0.06), scale: 0.4, opacity: 0.22),
        TreeSpec(position: UnitPoint(x: 0.5, y: 0.94), scale: 0.45, opacity: 0.25),
        TreeSpec(position: UnitPoint(x: 0.28, y: 0.35), scale: 0.35, opacity: 0.18),
        TreeSpec(position: UnitPoint(x: 0.72, y: 0.65), scale: 0.35, opacity: 0.18)
    ]

    /// The two larger, more prominent "sentinel" trees anchoring the
    /// top corners, matching the reference art's bigger corner pines.
    private static let sentinelTrees: [TreeSpec] = [
        TreeSpec(position: UnitPoint(x: 0.02, y: 0.02), scale: 1.4, opacity: 0.55),
        TreeSpec(position: UnitPoint(x: 0.98, y: 0.03), scale: 1.2, opacity: 0.5)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom)

                RadialGradient(
                    colors: [Color(hex: "#3FAE73").opacity(0.35), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: geo.size.width
                )

                ForEach(Self.scatteredTrees) { tree in
                    TreeSilhouette()
                        .fill(Color(hex: "#0E2A1C").opacity(tree.opacity))
                        .frame(width: 46 * tree.scale, height: 70 * tree.scale)
                        .position(x: geo.size.width * tree.position.x, y: geo.size.height * tree.position.y)
                }

                ForEach(Self.sentinelTrees) { tree in
                    TreeSilhouette()
                        .fill(Color(hex: "#173B2C").opacity(tree.opacity))
                        .frame(width: 46 * tree.scale, height: 70 * tree.scale)
                        .position(x: geo.size.width * tree.position.x, y: geo.size.height * tree.position.y)
                }

                RadialGradient(
                    colors: [.clear, .black.opacity(0.22)],
                    center: .center,
                    startRadius: geo.size.width * 0.4,
                    endRadius: geo.size.width * 1.1
                )
            }
        }
    }
}

// MARK: - TreeSilhouette
//
// Simple stacked-triangle pine, used only for the forest backdrop.

private struct TreeSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let tiers = 3
        let tierHeight = h * 0.7 / CGFloat(tiers)

        for i in 0..<tiers {
            let top = CGFloat(i) * tierHeight * 0.72
            let bottom = top + tierHeight
            let widthFactor = 1.0 - CGFloat(i) * 0.22
            path.move(to: CGPoint(x: w / 2, y: top))
            path.addLine(to: CGPoint(x: w / 2 - (w / 2) * widthFactor, y: bottom))
            path.addLine(to: CGPoint(x: w / 2 + (w / 2) * widthFactor, y: bottom))
            path.closeSubpath()
        }

        // Trunk
        path.addRect(CGRect(x: w * 0.45, y: h * 0.78, width: w * 0.1, height: h * 0.22))
        return path
    }
}

// MARK: - Preview

#Preview {
    TrainOfThoughtView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}