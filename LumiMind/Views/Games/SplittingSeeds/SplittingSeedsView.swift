//
//  SplittingSeedsView.swift
//  LumiMind
//
//  Presentational only — renders the seed pile + rotating stick and
//  forwards the drag angle into the ViewModel's `updateStickAngle(to:)`,
//  and the lock-in tap into `lockIn()`. Header/HUD follows the same
//  pattern as the other five games (category gradient card), reskinned
//  from Lumosity's forest scene onto LumiMind's cream background using
//  the Math category's emerald/mint gradient throughout instead of a
//  themed illustration.
//

import SwiftUI

struct SplittingSeedsView: View {
    @StateObject private var viewModel: SplittingSeedsViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SplittingSeedsViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                header
                playField
                    .padding(.horizontal, DesignSystem.Spacing.md)
                lockInButton
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

    // MARK: Header (TIME / SCORE / LEVEL + pips)

    private var header: some View {
        HStack {
            hudItem(label: "TIME", value: formattedTime)
            Spacer()
            hudItem(label: "SCORE", value: "\(viewModel.score)")
            Spacer()
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                Text("LEVEL \(viewModel.level)")
                    .font(DesignSystem.roundedFont(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                HStack(spacing: 5) {
                    ForEach(0..<SplittingSeedsViewModel.roundsPerLevel, id: \.self) { index in
                        Circle()
                            .fill(index < viewModel.roundInLevel ? .white : .white.opacity(0.35))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.mathGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private func hudItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(label)
                .font(DesignSystem.roundedFont(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Text(value)
                .font(DesignSystem.headline)
                .foregroundColor(.white)
        }
    }

    private var formattedTime: String {
        let minutes = viewModel.timeRemaining / 60
        let seconds = viewModel.timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: Play field

    private var playField: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let playRadius = min(geo.size.width, geo.size.height) / 2 - DesignSystem.Spacing.md
            let stickLength = playRadius * 2.3

            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius)
                    .fill(DesignSystem.mathGradient.opacity(0.12))

                // Stick
                Capsule()
                    .fill(DesignSystem.mathGradient)
                    .frame(width: stickLength, height: 10)
                    .rotationEffect(.radians(viewModel.stickAngle))
                    .scaleEffect(viewModel.lastAnswerWasCorrect != nil ? 1.04 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.lastAnswerWasCorrect)
                    .position(center)

                // Pivot marker
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(DesignSystem.backgroundOnboarding.opacity(0.3), lineWidth: 2))
                    .position(center)

                // Seeds
                ForEach(viewModel.seeds) { seed in
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.85))
                        .rotationEffect(.radians(seed.angle + .pi / 2))
                        .position(seedPosition(seed, center: center, playRadius: playRadius))
                }

                // Count bubbles
                countBubble(count: viewModel.leftCount, isLeft: true, center: center, playRadius: playRadius)
                countBubble(count: viewModel.rightCount, isLeft: false, center: center, playRadius: playRadius)

                if let correct = viewModel.lastAnswerWasCorrect {
                    Text(correct ? "Correct!" : "Not quite")
                        .font(DesignSystem.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
                        .clipShape(Capsule())
                        .position(x: center.x, y: DesignSystem.Spacing.lg)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        guard dx != 0 || dy != 0 else { return }
                        viewModel.updateStickAngle(to: atan2(dy, dx))
                    }
            )
            .disabled(viewModel.phase != .playing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private func seedPosition(_ seed: SplittingSeedsViewModel.Seed, center: CGPoint, playRadius: CGFloat) -> CGPoint {
        let r = playRadius * seed.radiusFraction
        return CGPoint(
            x: center.x + r * cos(seed.angle),
            y: center.y + r * sin(seed.angle)
        )
    }

    /// Bubble sits at a fixed offset perpendicular-ish to the stick on its
    /// respective side, rotating with the stick so it stays visually paired
    /// with the seeds on that side.
    private func countBubble(count: Int, isLeft: Bool, center: CGPoint, playRadius: CGFloat) -> some View {
        let perpendicular = viewModel.stickAngle + (isLeft ? .pi / 2 : -.pi / 2)
        let r = playRadius * 0.55
        let position = CGPoint(
            x: center.x + r * cos(perpendicular),
            y: center.y + r * sin(perpendicular)
        )
        return Text("\(count)")
            .font(DesignSystem.roundedFont(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 34, height: 34)
            .background(DesignSystem.mathGradient)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .position(position)
            .animation(.easeOut(duration: 0.12), value: count)
    }

    // MARK: Lock-in button

    private var lockInButton: some View {
        Button {
            viewModel.lockIn()
        } label: {
            Text("Lock In Split")
                .font(DesignSystem.buttonLabel)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.primaryGradient)
        .clipShape(Capsule())
        .padding(.horizontal, DesignSystem.Spacing.md)
        .disabled(viewModel.phase != .playing)
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

// MARK: - Preview

#Preview {
    SplittingSeedsView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}