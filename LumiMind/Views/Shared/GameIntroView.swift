import SwiftUI

// MARK: - GameIntroView
//
// Reusable intro/tutorial screen shown before any game starts. Renders
// the tapped game's category gradient, name, and rules from
// GameCatalog. Knows nothing about which destination is real vs.
// "Coming soon" — the caller supplies that via `destination`.
//
// Visual pass: numbered step badges replace plain bullet dots,
// shortDescription tagline added under the title, icon badge gets a
// ring + shadow for depth, Play button gets a shadow + chevron.
// No logic, callbacks, or data flow were touched.

struct GameIntroView<Destination: View>: View {
    let game: GameCatalog.Game
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        ZStack {
            game.category.gradient.ignoresSafeArea()

            // Decorative depth — purely cosmetic, no new colors introduced.
            GeometryReader { geo in
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 260, height: 260)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.08)
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 200, height: 200)
                    .position(x: geo.size.width * 0.1, y: geo.size.height * 0.85)
            }
            .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                Spacer(minLength: DesignSystem.Spacing.xl)

                iconBadge

                VStack(spacing: DesignSystem.Spacing.xxs) {
                    Text(game.category.rawValue.uppercased())
                        .font(DesignSystem.caption)
                        .foregroundColor(.white.opacity(0.85))

                    Text(game.name)
                        .font(DesignSystem.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(game.shortDescription)
                        .font(DesignSystem.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.top, DesignSystem.Spacing.xxs)
                }

                rulesCard

                Spacer()

                playButton
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var iconBadge: some View {
        Image(systemName: game.iconName)
            .font(.system(size: 44, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 96, height: 96)
            .background(.white.opacity(0.18))
            .clipShape(Circle())
            .overlay(
                Circle().stroke(.white.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(Array(game.rules.enumerated()), id: \.offset) { index, rule in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    stepBadge(index + 1)
                    Text(rule)
                        .font(DesignSystem.body)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func stepBadge(_ number: Int) -> some View {
        Text("\(number)")
            .font(DesignSystem.roundedFont(size: 13, weight: .bold))
            .foregroundColor(DesignSystem.backgroundOnboarding)
            .frame(width: 22, height: 22)
            .background(.white)
            .clipShape(Circle())
    }

    private var playButton: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text("Play")
                    .font(DesignSystem.buttonLabel)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(DesignSystem.backgroundOnboarding)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.lg)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GameIntroView(game: GameCatalog.games[0]) {
            ComingSoonView(gameName: "Memory Matrix", category: .memory)
        }
    }
}