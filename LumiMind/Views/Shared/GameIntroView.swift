import SwiftUI

// MARK: - GameIntroView
//
// Reusable intro screen shown before any game starts. Renders the
// game's category, name, description, and rules from GameCatalog.
// `gameResultViewModel` is optional (default nil) so existing call
// sites keep compiling unchanged — pass it in to enable the real
// Best Score / Total Plays stats row, computed from that ViewModel's
// `results` array (no separate stats model exists for this yet).
//
// NOTE: "Best Stat", "Game LPI/Unlock", and rank hexagons from the
// Lumosity reference were intentionally left out — none of them have
// a backing data model (no accuracy tracking, no premium/entitlement
// field, no progression/tier system). Add them here once those exist
// instead of faking placeholder values.

struct GameIntroView<Destination: View>: View {
    let game: GameCatalog.Game
    var gameResultViewModel: GameResultViewModel? = nil
    @ViewBuilder let destination: () -> Destination

    @Environment(\.dismiss) private var dismiss

    private var matchingResults: [GameResult] {
        guard let gameResultViewModel else { return [] }
        return gameResultViewModel.results.filter { $0.gameName == game.name }
    }
    private var bestScore: Int? { matchingResults.map(\.score).max() }
    private var totalPlays: Int { matchingResults.count }

    var body: some View {
        ZStack(alignment: .top) {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: 0) {
                heroHeader
                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Hero header

    private var heroHeader: some View {
        ZStack(alignment: .topLeading) {
            game.category.gradient

            GeometryReader { geo in
                Image(systemName: game.iconName)
                    .font(.system(size: 160, weight: .bold))
                    .foregroundColor(.white.opacity(0.12))
                    .rotationEffect(.degrees(-10))
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.55)
            }

            VStack(alignment: .leading, spacing: 0) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.leading, DesignSystem.Spacing.md)

                Spacer()

                Text(game.name)
                    .font(DesignSystem.largeTitle)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
        .frame(height: 230)
        .clipped()
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                breadcrumb
                descriptionText
                statsSection
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
    }

    private var breadcrumb: some View {
        Text(game.category.rawValue.uppercased())
            .font(DesignSystem.roundedFont(size: 13, weight: .bold))
            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
    }

    private var descriptionText: some View {
        Text(game.shortDescription)
            .font(DesignSystem.body)
            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Divider()
            statRow(label: "Best Score", value: bestScore.map(String.init) ?? "—")
            Divider()
            statRow(label: "Total Plays", value: "\(totalPlays)")
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
            Spacer()
            Text(value)
                .font(DesignSystem.body)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: { dismiss() }) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: "arrow.left")
                    Text("All Games")
                }
                .font(DesignSystem.buttonLabel)
                .foregroundColor(Color(hex: "#6D5DE7"))
            }

            NavigationLink(destination: destination) {
                Text("Play")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.primaryGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(.white)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GameIntroView(game: GameCatalog.games[0], gameResultViewModel: GameResultViewModel()) {
            ComingSoonView(gameName: "Memory Matrix", category: .memory)
        }
    }
}