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
    // new tokens added to DesignSystem. Layered for depth: a
    // multi-stop sky, a soft sun halo, faint slow-drifting migrating
    // birds up in the distance, several depth-varied clouds, two
    // rolling hill silhouettes behind the tree line, and a very
    // subtle static paper-grain texture tying it back to the
    // reference screenshot's paper-like background.

    private static let skyTop = Color(hex: "#8FD9DC")
    private static let skyBottom = Color(hex: "#4FB8C4")
    private static let skyHighlight = Color(hex: "#6FD4D6")
    private static let cloudColor = Color.white
    private static let sunColor = Color.white.opacity(0.55)
    private static let farHillColor = Color(hex: "#3FA6AE").opacity(0.3)
    private static let nearHillColor = Color(hex: "#2E8A93").opacity(0.45)
    private static let treeColor = Color(hex: "#256F78").opacity(0.55)

    private struct CloudSpec: Identifiable {
        let id = UUID()
        let position: CGPoint
        let width: CGFloat
        let height: CGFloat
        let opacity: Double
        let drift: CGFloat
        let duration: Double
        let delay: Double
    }

    private struct DistantBirdSpec: Identifiable {
        let id = UUID()
        let position: CGPoint
        let size: CGFloat
        let opacity: Double
        let drift: CGFloat
        let duration: Double
        let delay: Double
    }

    private static let clouds: [CloudSpec] = [
        CloudSpec(position: CGPoint(x: 90, y: 130), width: 120, height: 50, opacity: 0.55, drift: 14, duration: 9, delay: 0),
        CloudSpec(position: CGPoint(x: 335, y: 215), width: 90, height: 40, opacity: 0.4, drift: 10, duration: 7, delay: 1.2),
        CloudSpec(position: CGPoint(x: 60, y: 335), width: 140, height: 55, opacity: 0.5, drift: 16, duration: 11, delay: 0.5),
        CloudSpec(position: CGPoint(x: 345, y: 465), width: 100, height: 42, opacity: 0.35, drift: 12, duration: 8, delay: 2)
    ]

    private static let distantBirds: [DistantBirdSpec] = [
        DistantBirdSpec(position: CGPoint(x: 250, y: 95), size: 14, opacity: 0.3, drift: 18, duration: 6, delay: 0),
        DistantBirdSpec(position: CGPoint(x: 290, y: 118), size: 10, opacity: 0.22, drift: 14, duration: 5, delay: 0.4),
        DistantBirdSpec(position: CGPoint(x: 140, y: 490), size: 12, opacity: 0.25, drift: 16, duration: 7, delay: 0.8)
    ]

    private var skyBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Self.skyHighlight, Self.skyTop, Self.skyBottom],
                startPoint: .top, endPoint: .bottom
            )

            sunGlow
                .position(x: 320, y: 400)

            ForEach(Self.distantBirds) { bird in
                DriftingSprite(position: bird.position, driftRange: bird.drift, duration: bird.duration, delay: bird.delay) {
                    BirdShape()
                        .fill(Color.white.opacity(bird.opacity))
                        .frame(width: bird.size, height: bird.size * 0.9)
                        .rotationEffect(.degrees(90))
                }
            }

            ForEach(Self.clouds) { cloud in
                DriftingSprite(position: cloud.position, driftRange: cloud.drift, duration: cloud.duration, delay: cloud.delay) {
                    CloudShape()
                        .fill(Self.cloudColor.opacity(cloud.opacity))
                        .frame(width: cloud.width, height: cloud.height)
                }
            }

            VStack(spacing: 0) {
                Spacer()
                farHills
                nearHills.offset(y: -18)
                treeLine.offset(y: -30)
            }

            grainOverlay
        }
        .ignoresSafeArea()
    }

    private var sunGlow: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Self.sunColor.opacity(0.5), .clear], center: .center, startRadius: 8, endRadius: 95))
                .frame(width: 190, height: 190)
            Circle()
                .fill(Self.sunColor)
                .frame(width: 90, height: 90)
        }
    }

    private var farHills: some View {
        MigrationHillShape()
            .fill(Self.farHillColor)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
    }

    private var nearHills: some View {
        MigrationHillShape()
            .fill(Self.nearHillColor)
            .frame(height: 78)
            .frame(maxWidth: .infinity)
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

    /// Very faint static dot texture, seeded so it doesn't re-randomize
    /// (and thus flicker) on every redraw — a light nod to the paper
    /// texture in the reference screenshot without any real cost.
    private var grainOverlay: some View {
        Canvas { context, size in
            var rng = MigrationGrainRNG(seed: 42)
            for _ in 0..<140 {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let r = CGFloat.random(in: 0.5...1.4, using: &rng)
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)), with: .color(.white.opacity(0.05)))
            }
        }
        .allowsHitTesting(false)
        .blendMode(.overlay)
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