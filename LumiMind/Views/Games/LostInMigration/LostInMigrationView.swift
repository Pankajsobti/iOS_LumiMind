import SwiftUI

// MARK: - LostInMigrationView
//
// REWRITE to match the reference screenshot: a soft sky backdrop
// (clouds, sun, tree-line — self-contained the same way
// TrainOfThoughtView's forestBackdrop is scoped to that screen only),
// a header with a pause glyph + TIME + SCORE, a plus-shaped bird
// formation, and a swipe gesture over the whole board — the same
// input pattern as FlowSwitchView's `leafField`. Purely
// presentational: all gameplay state comes from
// LostInMigrationViewModel, and swipes are forwarded into
// `respond(_:)`.

struct LostInMigrationView: View {
    @StateObject private var viewModel: LostInMigrationViewModel
    var onComplete: () -> Void

    /// Spacing between adjacent birds in the formation, in points.
    private static let birdSpacing: CGFloat = 64
    private static let birdSize: CGFloat = 40

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: LostInMigrationViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            skyBackdrop

            VStack(spacing: DesignSystem.Spacing.lg) {
                header
                Spacer()
                formation
                instructionCaption
                Spacer()
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

    // MARK: Sky backdrop
    //
    // Self-contained palette scoped to this screen only, same
    // pattern TrainOfThoughtView already uses for its forest — no
    // new tokens added to DesignSystem.

    private static let skyTop = Color(hex: "#8FD9DC")
    private static let skyBottom = Color(hex: "#4FB8C4")
    private static let cloudColor = Color.white.opacity(0.55)
    private static let sunColor = Color.white.opacity(0.45)
    private static let treeColor = Color(hex: "#3FA6AE").opacity(0.55)

    private var skyBackdrop: some View {
        ZStack {
            LinearGradient(colors: [Self.skyTop, Self.skyBottom], startPoint: .top, endPoint: .bottom)

            CloudShape().fill(Self.cloudColor)
                .frame(width: 130, height: 55)
                .position(x: 90, y: 150)
            CloudShape().fill(Self.cloudColor)
                .frame(width: 150, height: 60)
                .position(x: 330, y: 300)
            CloudShape().fill(Self.cloudColor)
                .frame(width: 120, height: 50)
                .position(x: 110, y: 470)

            Circle().fill(Self.sunColor)
                .frame(width: 90, height: 90)
                .position(x: 320, y: 400)

            VStack {
                Spacer()
                treeLine
            }
        }
        .ignoresSafeArea()
    }

    private var treeLine: some View {
        HStack(spacing: -10) {
            ForEach(0..<9, id: \.self) { i in
                MigrationTreeSilhouette()
                    .fill(Self.treeColor)
                    .frame(width: 44, height: 66)
                    .offset(y: (i % 2 == 0 ? 4 : -4))
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: { /* pause owned by caller / navigation */ }) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
            }
            .buttonStyle(.plain)

            Spacer()

            statPill(label: "TIME", value: viewModel.timeRemainingLabel)
            statPill(label: "SCORE", value: "\(viewModel.score)")
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private func statPill(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(DesignSystem.roundedFont(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
            Text(value)
                .font(DesignSystem.roundedFont(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.white.opacity(0.18))
        .clipShape(Capsule())
    }

    // MARK: Formation

    private var formation: some View {
        ZStack {
            ForEach(viewModel.currentTrial.birds) { bird in
                BirdSprite(
                    isTarget: bird.isTarget,
                    heading: bird.direction.rotationDegrees,
                    size: bird.isTarget ? Self.birdSize : Self.birdSize * 0.88
                )
                .offset(
                    x: CGFloat(bird.slot.offset.x) * Self.birdSpacing,
                    y: CGFloat(bird.slot.offset.y) * Self.birdSpacing
                )
            }
        }
        .frame(height: Self.birdSpacing * 2 + Self.birdSize)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 16)
                .onEnded { value in
                    viewModel.respond(Self.direction(for: value.translation))
                }
        )
        .allowsHitTesting(viewModel.phase == .playing)
        .animation(.easeOut(duration: 0.12), value: viewModel.currentTrial.birds)
    }

    private static func direction(for translation: CGSize) -> LostInMigrationViewModel.Direction {
        if abs(translation.width) > abs(translation.height) {
            return translation.width > 0 ? .right : .left
        } else {
            return translation.height > 0 ? .down : .up
        }
    }

    // MARK: Instruction / feedback

    @ViewBuilder
    private var instructionCaption: some View {
        if let correct = viewModel.lastAnswerWasCorrect {
            Text(correct ? "Nice!" : "Not quite")
                .font(DesignSystem.headline)
                .foregroundColor(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        } else {
            Text("Swipe in the direction of the middle bird")
                .font(DesignSystem.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
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

// MARK: - Preview

#Preview {
    LostInMigrationView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}