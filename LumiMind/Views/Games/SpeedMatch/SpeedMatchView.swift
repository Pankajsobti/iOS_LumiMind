import SwiftUI

// MARK: - SpeedMatchView
//
// Presentational only — renders whatever SpeedMatchViewModel reports
// and forwards taps into `answer(_:)`. Visual pass: stat bar (TIME +
// live SCORE) replaces the old title/round-counter header, symbol card
// is now a flat white card with a gradient-tinted glyph instead of a
// gradient-filled card, and the footer is a full-width split NO/YES
// bar instead of capsule buttons. No ViewModel bindings, callbacks, or
// scoring logic were touched — only `score` was added as a published
// read-out of the existing private accumulator.

struct SpeedMatchView: View {
    @StateObject private var viewModel: SpeedMatchViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SpeedMatchViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                statBar
                progressDots

                Spacer()

                symbolCard

                questionText

                feedbackLabel
                    .frame(height: 22)

                Spacer()
            }
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.horizontal, DesignSystem.Spacing.md)

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…")
            }

            if case .finished(let score) = viewModel.phase {
                finishedOverlay(score: score)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            answerBar
        }
    }

    // MARK: Stat bar (TIME | SCORE)

    private var statBar: some View {
        HStack(spacing: 0) {
            statColumn(label: "TIME", value: timeRemainingText)
            Divider()
                .frame(height: 28)
                .overlay(DesignSystem.backgroundOnboarding.opacity(0.15))
            statColumn(label: "SCORE", value: "\(viewModel.score)")
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }

    private func statColumn(label: String, value: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
            Text(value)
                .font(DesignSystem.roundedFont(size: 17, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
        .frame(maxWidth: .infinity)
    }

    private var timeRemainingText: String {
        let totalSeconds = SpeedMatchViewModel.responseWindowSeconds
        let remaining = max(0, viewModel.timeRemainingFraction) * totalSeconds
        let displaySeconds = Int(remaining.rounded(.up))
        let minutes = displaySeconds / 60
        let seconds = displaySeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: Progress dots (cosmetic only — no lives/streak/multiplier exist in the ViewModel)

    private var progressDots: some View {
        ProgressDotsView(
            totalDots: 5,
            filledFraction: Double(viewModel.currentRoundIndex) / Double(max(1, SpeedMatchViewModel.totalRounds - 1)),
            fillColor: DesignSystem.speedGradient
        )
    }

    // MARK: Symbol card

        private var symbolCard: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius)
            .fill(.white)
            .frame(width: 180, height: 180)
            .shadow(color: DesignSystem.backgroundOnboarding.opacity(0.08), radius: 12, y: 6)
            .overlay {
                ZStack {
                    if !viewModel.currentSymbol.isEmpty {
                        Image(systemName: viewModel.currentSymbol)
                            .font(.system(size: 64, weight: .semibold))
                            .foregroundStyle(DesignSystem.speedGradient)
                            .frame(width: 180, height: 180)   // <- key fix: matches card, so move() slides full width
                            .id(viewModel.currentRoundIndex)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(width: 180, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentRoundIndex)
    }

    private var questionText: some View {
        Text("Does this symbol match the previous symbol?")
            .font(DesignSystem.body)
            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.65))
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    @ViewBuilder
    private var feedbackLabel: some View {
        if let correct = viewModel.lastAnswerWasCorrect {
            Text(correct ? "Correct!" : "Missed it")
                .font(DesignSystem.headline)
                .foregroundColor(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        } else {
            Text(" ")
                .font(DesignSystem.headline)
        }
    }

    // MARK: Answer bar (full-width split NO / YES)

    private var answerBar: some View {
        HStack(spacing: 0) {
            answerHalf(title: "NO") { viewModel.answer(.noMatch) }
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1)
            answerHalf(title: "YES") { viewModel.answer(.match) }
        }
        .frame(height: 76)
        .background(
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea(edges: .bottom)
        )
        .disabled(viewModel.phase != .playing)
        .opacity(viewModel.phase == .playing ? 1 : 0.5)
    }

    private func answerHalf(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.roundedFont(size: 19, weight: .bold))
                .foregroundStyle(DesignSystem.primaryGradient)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: Overlays (unchanged)

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

// MARK: - ProgressDotsView (new reusable component)

/// A row of small dots showing coarse progress toward completion.
/// Purely decorative — takes a 0...1 fraction and a fill style, no
/// concept of lives/streaks/attempts. Reusable on any screen that
/// wants a lightweight progress indicator distinct from a full bar.
struct ProgressDotsView: View {
    let totalDots: Int
    let filledFraction: Double
    let fillColor: LinearGradient

    var body: some View {
        let filledCount = Int((Double(totalDots) * min(1, max(0, filledFraction))).rounded())
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(0..<totalDots, id: \.self) { index in
                Circle()
                    .fill(index < filledCount ? AnyShapeStyle(fillColor) : AnyShapeStyle(DesignSystem.backgroundOnboarding.opacity(0.15)))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SpeedMatchView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}