import SwiftUI

// MARK: - ScienceExplainerView
//
// Reusable post-game screen shown after any game submits its result.
// Explains the cognitive science behind the game, then shows the
// score. Score is folded into this screen rather than a separate
// GameScoreView (scope decision — no dedicated score/history screen
// exists yet). Falls back to a placeholder if score is nil so a
// submission failure/race never crashes this screen.
//
// Visual pass: category shown as a tinted pill instead of plain
// caption text, lightbulb glyph added next to "The Science", icon
// badge gets a ring + shadow, score card gets a translucent icon
// watermark for depth. No data flow, models, or navigation touched —
// still renders only `game` and `score` as before.

struct ScienceExplainerView: View {
    let game: GameCatalog.Game
    let score: Int?
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        header
                        explainerCard
                        scoreCard
                    }
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
                }

                continueButton
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: game.iconName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(game.category.gradient)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(.white.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)

            Text(game.category.rawValue.uppercased())
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(
                    Capsule().fill(game.category.gradient).opacity(0.15)
                )

            Text(game.name)
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
    }

    private var explainerCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                Text("The Science")
                    .font(DesignSystem.headline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)
            }

            Text(game.scienceExplainer)
                .font(DesignSystem.body)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private var scoreCard: some View {
        ZStack {
            Image(systemName: game.iconName)
                .font(.system(size: 110, weight: .bold))
                .foregroundColor(.white.opacity(0.12))
                .rotationEffect(.degrees(-12))
                .offset(x: 70, y: -6)

            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text("Your Score")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                Text(score.map(String.init) ?? "—")
                    .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
        }
        .background(game.category.gradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Continue")
                .font(DesignSystem.buttonLabel)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.primaryGradient)
        .clipShape(Capsule())
        .shadow(color: Color(hex: "#6D5DE7").opacity(0.35), radius: 14, y: 8)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScienceExplainerView(game: GameCatalog.games[0], score: 780, onContinue: {})
    }
}