import SwiftUI

// MARK: - BrainShiftView
//
// Skinned to match the reference screenshot: a teal wood-grain
// backdrop, a header with a dark pause square + TIME/SCORE stat
// pills (mirrors LostInMigrationView's `header`/`statPill`), two
// stacked white stimulus cards (active on top with its rule question
// above it, the queued one below with ITS question underneath), and a
// flat navy NO/YES split bar. Original hand-painted grain texture via
// Canvas — same technique as LostInMigrationView's `grainOverlay`,
// just horizontal wood-grain streaks instead of a paper-dot pattern —
// not a copy of any reference art asset.

struct BrainShiftView: View {
    @StateObject private var viewModel: BrainShiftViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: BrainShiftViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    // MARK: Palette (local to this screen — original, not copied from any reference asset)

    private static let backdropTop = Color(hex: "#2E9AA0")
    private static let backdropBottom = Color(hex: "#1B6E74")
    private static let stimulusColor = Color(hex: "#F2A93B")
    private static let cyanAccent = Color(hex: "#29C7EE")
    private static let barColor = Color(hex: "#0B242A")
    private static let statBoxColor = Color.black.opacity(0.22)

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.md)

                Spacer(minLength: DesignSystem.Spacing.xl)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    questionBubble(text: viewModel.currentTrial.rule.question, highlighted: viewModel.justSwitchedRule)
                    stimulusCard(trial: viewModel.currentTrial)
                }

                Spacer(minLength: DesignSystem.Spacing.lg)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    stimulusCard(trial: nil)
                    questionBubble(text: viewModel.nextTrial.rule.question, highlighted: false)
                }

                Spacer(minLength: DesignSystem.Spacing.xl)

                answerBar
            }
            .opacity(viewModel.phase == .playing ? 1 : 0.15)
            .disabled(viewModel.phase != .playing)

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…")
            }

            if case .finished(let score) = viewModel.phase {
                finishedOverlay(score: score)
            }
        }
    }

    // MARK: Backdrop — original teal wood-grain texture (Canvas-painted, same technique as LostInMigrationView's grainOverlay)

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [Self.backdropTop, Self.backdropBottom], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                var rng = BrainShiftGrainRNG(seed: 7)
                for _ in 0..<34 {
                    let y = CGFloat.random(in: 0...size.height, using: &rng)
                    let thickness = CGFloat.random(in: 1...3, using: &rng)
                    let opacity = Double.random(in: 0.04...0.10, using: &rng)
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addCurve(
                        to: CGPoint(x: size.width, y: y + CGFloat.random(in: -14...14, using: &rng)),
                        control1: CGPoint(x: size.width * 0.33, y: y + CGFloat.random(in: -10...10, using: &rng)),
                        control2: CGPoint(x: size.width * 0.66, y: y + CGFloat.random(in: -10...10, using: &rng))
                    )
                    context.stroke(path, with: .color(.black.opacity(opacity)), lineWidth: thickness)
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    // MARK: Header (mirrors LostInMigrationView's header/statPill pattern)

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: { /* pause owned by caller / navigation */ }) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Self.cyanAccent)
                    .frame(width: 34, height: 34)
                    .background(Self.barColor)
            }
            .buttonStyle(.plain)

            Spacer()

            statBox(label: "TIME", value: viewModel.timeRemainingLabel)
            statBox(label: "SCORE", value: "\(viewModel.score)")
        }
    }

    private func statBox(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(DesignSystem.roundedFont(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
            Text(value)
                .font(DesignSystem.roundedFont(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .background(Self.statBoxColor)
    }

    // MARK: Question bubble

    private func questionBubble(text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(DesignSystem.roundedFont(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, 6)
            .background(Color.black.opacity(highlighted ? 0.34 : 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(highlighted ? 1.06 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: highlighted)
            .accessibilityLabel(text)
    }

    // MARK: Stimulus card
    //
    // `trial == nil` renders the blank "on deck" card from the
    // reference screenshot's lower slot.

    @ViewBuilder
    private func stimulusCard(trial: BrainShiftViewModel.Trial?) -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
            .fill(Color.white)
            .frame(width: 190, height: 150)
            .overlay {
                if let trial {
                    Text(trial.label)
                        .font(DesignSystem.roundedFont(size: 48, weight: .bold))
                        .foregroundColor(Self.stimulusColor)
                        .accessibilityLabel(trial.accessibilityLabel)
                        .id(trial.label + "\(trial.rule)")
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: trial?.label)
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    // MARK: Answer bar

    private var answerBar: some View {
        HStack(spacing: 0) {
            answerButton(label: "NO", isYes: false)
            Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1)
            answerButton(label: "YES", isYes: true)
        }
        .frame(height: 64)
        .background(Self.barColor)
    }

    private func answerButton(label: String, isYes: Bool) -> some View {
        Button {
            viewModel.answer(isYes: isYes)
        } label: {
            Text(label)
                .font(DesignSystem.roundedFont(size: 20, weight: .bold))
                .foregroundColor(Self.cyanAccent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Overlays (unchanged pattern from the other games)

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

                VStack(spacing: 4) {
                    Text("Accuracy: \(Int((viewModel.finalAccuracy * 100).rounded()))%")
                    Text("Best streak: \(viewModel.bestStreak)")
                    Text(String(format: "Avg response: %.2fs", viewModel.finalAverageResponseTime))
                }
                .font(DesignSystem.subheadline)
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

// MARK: - BrainShiftGrainRNG
//
// Deterministic RNG so the backdrop's grain streaks render the same
// pattern every redraw instead of flickering — same role as
// MigrationGrainRNG in LostInMigrationSprites.swift, named distinctly
// to avoid a redeclaration collision with that file.

private struct BrainShiftGrainRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Preview

#Preview {
    BrainShiftView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}