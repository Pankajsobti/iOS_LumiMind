import SwiftUI

// MARK: - LeafShape
//
// Original teardrop artwork, tip pointing "up" at 0° rotation.

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: h * 0.65), control: CGPoint(x: w * 0.95, y: h * 0.15))
        path.addQuadCurve(to: CGPoint(x: w / 2, y: h), control: CGPoint(x: w * 0.75, y: h * 0.95))
        path.addQuadCurve(to: CGPoint(x: 0, y: h * 0.65), control: CGPoint(x: w * 0.25, y: h * 0.95))
        path.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: w * 0.05, y: h * 0.15))
        return path
    }
}

// MARK: - FlowSwitchView
//
// Restyle pass: dark navy play field (own token below, not reusing
// backgroundMain/Onboarding since neither matches this game's look),
// a TIME | SCORE | multiplier-dots header bar, a scattered group of
// leaves per trial with no rule-label text, and swipe/button input.

struct FlowSwitchView: View {
    @StateObject private var viewModel: FlowSwitchViewModel
    var onComplete: () -> Void

    /// Scoped to this screen only — a dark navy play-field background,
    /// distinct from DesignSystem's onboarding/main backgrounds.
    private static let fieldBackground = Color(hex: "#101B2C")

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: FlowSwitchViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            Self.fieldBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                statBar
                leafField
                controls
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…")
            }

            if case .finished(let score) = viewModel.phase {
                finishedOverlay(score: score)
            }
        }
    }

    // MARK: Top stat bar

    private var statBar: some View {
        HStack(spacing: 0) {
            statGroup(label: "TIME", value: viewModel.timeRemainingLabel)
            divider
            statGroup(label: "SCORE", value: "\(viewModel.score)")
            divider
            multiplierGroup
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.white.opacity(0.08))
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1)
            .padding(.vertical, DesignSystem.Spacing.xxs)
    }

    private func statGroup(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(DesignSystem.roundedFont(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
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
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.meter ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            Text("x\(viewModel.multiplier)")
                .font(DesignSystem.roundedFont(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Leaf field

    private var leafField: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(viewModel.currentTrial.leaves) { leaf in
                    LeafShape()
                        .fill(viewModel.currentTrial.color.color)
                        .frame(width: 56, height: 72)
                        .overlay(
                            LeafShape().stroke(Color.white, lineWidth: 3)
                        )
                        .rotationEffect(.degrees(viewModel.currentTrial.pointing.rotationDegrees))
                        .position(
                            x: leaf.baseX * geo.size.width + viewModel.leafOffset.width,
                            y: leaf.baseY * geo.size.height + viewModel.leafOffset.height
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        viewModel.respond(Self.direction(for: value.translation))
                    }
            )
        }
        .disabled(viewModel.phase != .playing)
    }

    private static func direction(for translation: CGSize) -> FlowSwitchViewModel.Direction {
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        } else {
            return translation.height > 0 ? .down : .up
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            directionButton(.up)
            HStack(spacing: DesignSystem.Spacing.xl) {
                directionButton(.left)
                directionButton(.down)
                directionButton(.right)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .disabled(viewModel.phase != .playing)
    }

    private func directionButton(_ direction: FlowSwitchViewModel.Direction) -> some View {
        Button {
            viewModel.respond(direction)
        } label: {
            Image(systemName: arrowSystemName(direction))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func arrowSystemName(_ direction: FlowSwitchViewModel.Direction) -> String {
        switch direction {
        case .up:    return "arrow.up"
        case .down:  return "arrow.down"
        case .left:  return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    // MARK: Overlays

    private func statusOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView().tint(.white)
                Text(message)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(Self.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        }
    }

    private func finishedOverlay(score: Int) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Time's up!")
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)

                Text("Score: \(score)")
                    .font(DesignSystem.roundedFont(size: 28, weight: .bold))
                    .foregroundColor(.white)

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
            .background(Self.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        }
    }
}

// MARK: - Preview

#Preview {
    FlowSwitchView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}