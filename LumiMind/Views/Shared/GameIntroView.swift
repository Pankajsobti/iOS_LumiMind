import SwiftUI

// MARK: - GameIntroView
//
// Reusable intro/tutorial screen shown before any game starts. Renders
// the tapped game's category gradient, name, and rules from
// GameCatalog. Knows nothing about which destination is real vs.
// "Coming soon" — the caller supplies that via `destination`.

struct GameIntroView<Destination: View>: View {
    let game: GameCatalog.Game
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        ZStack {
            game.category.gradient.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                Spacer(minLength: DesignSystem.Spacing.xl)

                Image(systemName: game.iconName)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 96, height: 96)
                    .background(.white.opacity(0.18))
                    .clipShape(Circle())

                Text(game.category.rawValue.uppercased())
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.85))

                Text(game.name)
                    .font(DesignSystem.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                rulesCard

                Spacer()

                NavigationLink(destination: destination) {
                    Text("Play")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(DesignSystem.backgroundOnboarding)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            ForEach(game.rules, id: \.self) { rule in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    Text(rule)
                        .font(DesignSystem.body)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.lg)
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