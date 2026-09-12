import SwiftUI

// MARK: - LeafShape
//
// Simple teardrop, tip pointing "up" at 0° rotation — original
// artwork, no external assets.

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
// Presentational only — mirrors BrainShiftView's structure. Leaf
// points via rotation, drifts via animated offset; player responds
// with the four directional buttons or a swipe on the leaf itself.

struct FlowSwitchView: View {
    @StateObject private var viewModel: FlowSwitchViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: FlowSwitchViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                header
                ruleBanner

                Spacer()

                leafStage

                feedbackLabel
                    .frame(height: 22)

                Spacer()

                controls
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
                Text("Flow Switch")
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)
                Spacer()
                Text("\(min(viewModel.trialIndex + 1, FlowSwitchViewModel.totalTrials))/\(FlowSwitchViewModel.totalTrials)")
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
            ProgressBar(fraction: viewModel.timeRemainingFraction)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.flexibilityGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: Rule banner

    private var ruleBanner: some View {
        Text(viewModel.currentTrial.color.ruleLabel)
            .font(DesignSystem.headline)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(viewModel.currentTrial.color.color)
            .clipShape(Capsule())
    }

    // MARK: Leaf stage

    private var leafStage: some View {
        ZStack {
            LeafShape()
                .fill(viewModel.currentTrial.color.color.opacity(0.9))
                .frame(width: 70, height: 90)
                .rotationEffect(.degrees(viewModel.currentTrial.pointing.rotationDegrees))
                .shadow(color: viewModel.currentTrial.color.color.opacity(0.4), radius: 8)
                .offset(viewModel.leafOffset)
        }
        .frame(width: 220, height: 220)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    viewModel.respond(Self.direction(for: value.translation))
                }
        )
        .disabled(viewModel.phase != .playing)
    }

    private static func direction(for translation: CGSize) -> FlowSwitchViewModel.Direction {
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        } else {
            return translation.height > 0 ? .down : .up
        }
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if let correct = viewModel.lastAnswerFeedback {
            Text(correct ? "Correct!" : "Not quite")
                .font(DesignSystem.headline)
                .foregroundColor(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        } else {
            Text(" ")
                .font(DesignSystem.headline)
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
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(DesignSystem.flexibilityGradient)
                .clipShape(Circle())
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
    FlowSwitchView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}