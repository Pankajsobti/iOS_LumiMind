import SwiftUI

// MARK: - PiratePassageView
//
// Presentational only — renders whatever PiratePassageViewModel
// reports. The board is a GeometryReader-sized square so ship/pirate
// markers, the dashed planned-path line, and the faint patrol-route
// previews can all be positioned with pixel-accurate `.position()`
// on top of the LazyVGrid tile layer.

struct PiratePassageView: View {
    @StateObject private var viewModel: PiratePassageViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PiratePassageViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                header

                board
                    .padding(.horizontal, DesignSystem.Spacing.md)

                hintRow

                controls
            }
            .padding(.top, DesignSystem.Spacing.lg)

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…")
            }

            if case .levelResult(let result) = viewModel.phase {
                resultOverlay(result)
            }

            if case .finished(let score) = viewModel.phase {
                finishedOverlay(score: score)
            }
        }
    }

    // MARK: Header — Level / Trial / Score, per spec's top-bar layout

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("LEVEL")
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.75))
                Text("\(min(viewModel.levelIndex + 1, PiratePassageViewModel.totalLevels)) / \(PiratePassageViewModel.totalLevels)")
                    .font(DesignSystem.roundedFont(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("TRIAL")
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.75))
                Text("\(viewModel.attempt) of 2")
                    .font(DesignSystem.roundedFont(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("SCORE")
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.75))
                Text("\(viewModel.runningScore)")
                    .font(DesignSystem.roundedFont(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.problemSolvingGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Board

    private var board: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / CGFloat(max(viewModel.cols, viewModel.rows))

            ZStack {
                // Ocean board backdrop
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                    .fill(Color(hex: "#5EEAD4").opacity(0.14))

                tileLayer(cell: cell)
                patrolRoutePreviewLayer(cell: cell)
                hintLayer(cell: cell)
                plannedPathLayer(cell: cell)
                pirateLayer(cell: cell)
                shipLayer(cell: cell)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: viewModel.cols)
    }

    private func tileLayer(cell: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 3) {
            ForEach(viewModel.cells) { gridCell in
                Button {
                    viewModel.tapTile(at: gridCell.position)
                } label: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tileFill(for: gridCell))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if gridCell.isObstacle {
                                Image(systemName: "mountain.2.fill")
                                    .font(.system(size: cell * 0.32))
                                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.55))
                            } else if gridCell.isEnd {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: cell * 0.4))
                                    .foregroundColor(Color(hex: "#F5A623"))
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.phase != .planning)
            }
        }
    }

    private func tileFill(for cell: PiratePassageViewModel.GridCell) -> Color {
        if cell.isObstacle {
            return DesignSystem.backgroundOnboarding.opacity(0.18)
        }
        return Color(hex: "#5EEAD4").opacity(0.22)
    }

    /// Faint, color-coded preview of each pirate's patrol shape so the
    /// player can study routes before committing to a plan.
    private func patrolRoutePreviewLayer(cell: CGFloat) -> some View {
        Canvas { context, _ in
            for pirate in viewModel.pirates {
                var path = Path()
                for (index, position) in pirate.cells.enumerated() {
                    let point = center(for: position, cell: cell)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(
                    path,
                    with: .color(Color(hex: pirate.colorHex).opacity(0.35)),
                    style: StrokeStyle(lineWidth: 2, dash: [3, 4])
                )
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func hintLayer(cell: CGFloat) -> some View {
        if let hintPath = viewModel.hintPath {
            Canvas { context, _ in
                var path = Path()
                for (index, position) in hintPath.enumerated() {
                    let point = center(for: position, cell: cell)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(
                    path,
                    with: .color(Color(hex: "#F5A623").opacity(0.8)),
                    style: StrokeStyle(lineWidth: 3, dash: [2, 5])
                )
            }
            .allowsHitTesting(false)
        }
    }

    private func plannedPathLayer(cell: CGFloat) -> some View {
        Canvas { context, _ in
            guard viewModel.currentPath.count > 1 else { return }
            var path = Path()
            for (index, position) in viewModel.currentPath.enumerated() {
                let point = center(for: position, cell: cell)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(
                path,
                with: .color(.white),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 9])
            )
            context.stroke(
                path,
                with: .color(DesignSystem.backgroundOnboarding.opacity(0.5)),
                style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [1, 9])
            )
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.15), value: viewModel.currentPath)
    }

    private func pirateLayer(cell: CGFloat) -> some View {
        ForEach(viewModel.pirates) { pirate in
            let position = animatedPosition(for: pirate)
            PirateShipView(colorHex: pirate.colorHex, isPlayer: false)
                .frame(width: cell * 0.7, height: cell * 0.7)
                .position(center(for: position, cell: cell))
                .animation(.easeInOut(duration: 0.45), value: position)
        }
    }

    private func animatedPosition(for pirate: PiratePassageViewModel.Patrol) -> PiratePassageViewModel.Position {
        if viewModel.phase == .executing || isLevelResultPhase {
            let index = viewModel.pirates.firstIndex(where: { $0.id == pirate.id }) ?? 0
            if index < viewModel.animatedPiratePositions.count {
                return viewModel.animatedPiratePositions[index]
            }
        }
        return pirate.position(atTick: 0)
    }

    private var isLevelResultPhase: Bool {
        if case .levelResult = viewModel.phase { return true }
        return false
    }

    private func shipLayer(cell: CGFloat) -> some View {
        let shipPosition = (viewModel.phase == .executing || isLevelResultPhase)
            ? viewModel.animatedShipPosition
            : (viewModel.currentPath.first ?? PiratePassageViewModel.Position(row: 0, col: 0))
        return PirateShipView(colorHex: "#FFB347", isPlayer: true)
            .frame(width: cell * 0.78, height: cell * 0.78)
            .position(center(for: shipPosition, cell: cell))
            .animation(.easeInOut(duration: 0.45), value: shipPosition)
    }

    private func center(for position: PiratePassageViewModel.Position, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(position.col) + 0.5) * cell, y: (CGFloat(position.row) + 0.5) * cell)
    }

    // MARK: Hint

    private var hintRow: some View {
        HStack {
            Spacer()
            Button {
                viewModel.requestHint()
            } label: {
                Label("Need a hint?", systemImage: "lightbulb.fill")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.phase != .planning || viewModel.hintPath != nil)
            .opacity(viewModel.hintPath == nil ? 1 : 0.4)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: Bottom controls — UNDO / GO

    private var controls: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                viewModel.undo()
            } label: {
                Text("UNDO")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(DesignSystem.backgroundOnboarding.opacity(viewModel.canUndo ? 1 : 0.35))
            .clipShape(Capsule())
            .disabled(!viewModel.canUndo)

            Button {
                viewModel.go()
            } label: {
                Text("GO")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(viewModel.canGo ? AnyShapeStyle(DesignSystem.primaryGradient) : AnyShapeStyle(DesignSystem.backgroundOnboarding.opacity(0.35)))
            .clipShape(Capsule())
            .disabled(!viewModel.canGo)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.lg)
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

    private func resultOverlay(_ result: PiratePassageViewModel.LevelResult) -> some View {
        ZStack {
            DesignSystem.backgroundOnboarding.opacity(0.55).ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: result.success ? "star.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(result.success ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))

                Text(result.success ? "Treasure Found!" : "Caught by a Pirate!")
                    .font(DesignSystem.title2)
                    .foregroundColor(DesignSystem.backgroundMain)

                if let reason = result.collisionReason {
                    Text(reason)
                        .font(DesignSystem.caption)
                        .foregroundColor(DesignSystem.backgroundMain.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                if result.success {
                    VStack(spacing: 4) {
                        summaryRow(label: "Moves used", value: "\(result.movesUsed)")
                        summaryRow(label: "Optimal moves", value: "\(result.optimalMoves)")
                        summaryRow(label: "Bonus", value: result.bonus > 0 ? "+\(result.bonus)" : "—")
                        summaryRow(label: "Level score", value: "\(result.levelScore)")
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                } else if result.attempt >= 2 {
                    Text("Second-attempt levels score at a reduced rate.")
                        .font(DesignSystem.caption)
                        .foregroundColor(DesignSystem.backgroundMain.opacity(0.6))
                }

                Button {
                    if result.success {
                        viewModel.advanceToNextLevel()
                    } else {
                        viewModel.retryLevel()
                    }
                } label: {
                    Text(result.success ? "Continue" : "Retry")
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

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
            Spacer()
            Text(value)
                .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                .foregroundColor(DesignSystem.backgroundMain)
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

// MARK: - Custom Ship Rendering

private enum PirateShipShape {
    static func hull(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.06, y: rect.minY + h * 0.60))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.94, y: rect.minY + h * 0.60))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.90))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.20, y: rect.minY + h * 0.90))
        path.closeSubpath()
        return path
    }
    static func mast(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.62))
        return path
    }
    static func sail(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.10))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.60))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.18, y: rect.minY + h * 0.60))
        path.closeSubpath()
        return path
    }
    static func flag(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.72, y: rect.minY + h * 0.10))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY + h * 0.17))
        path.closeSubpath()
        return path
    }
    static func wake(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(
            x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.88,
            width: rect.width * 0.80, height: rect.height * 0.14
        ))
    }
}

/// Original, hand-drawn pirate ship — hull, mast, sail, and a
/// color-coded pennant — with a subtle continuous bob for life.
/// Not a system symbol or borrowed artwork.
private struct PirateShipView: View {
    let colorHex: String
    let isPlayer: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let bob = sin(t * 2.4) * 1.6

            GeometryReader { geo in
                let rect = CGRect(origin: .zero, size: geo.size)
                ZStack {
                    PirateShipShape.wake(in: rect)
                        .fill(Color.white.opacity(0.25))

                    Group {
                        PirateShipShape.hull(in: rect)
                            .fill(LinearGradient(
                                colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.65)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .overlay(PirateShipShape.hull(in: rect).stroke(Color.black.opacity(0.3), lineWidth: 1))

                        PirateShipShape.mast(in: rect)
                            .stroke(Color.black.opacity(0.55), lineWidth: max(1, rect.width * 0.03))

                        PirateShipShape.sail(in: rect)
                            .fill(Color.white.opacity(isPlayer ? 0.97 : 0.88))
                            .overlay(PirateShipShape.sail(in: rect).stroke(Color.black.opacity(0.15), lineWidth: 1))

                        PirateShipShape.flag(in: rect)
                            .fill(isPlayer ? Color(hex: "#F5A623") : Color(hex: colorHex))
                    }
                    .offset(y: bob)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PiratePassageView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}