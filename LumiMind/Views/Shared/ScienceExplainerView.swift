import SwiftUI

// MARK: - ScienceExplainerView
//
// Post-game screen. Shows the score, a "New High Score" callout when
// earned, and the science explainer. `gameResultViewModel` is optional
// (default nil) so existing call sites keep compiling — pass it in to
// enable real Past Best / New High Score / Plays Today, all computed
// from `results` (no separate stats model needed).
//
// NOTE: Cards/Accuracy/Response Time/Unlock/rank-trophy from the
// Lumosity reference were left out — none have a backing data model.
// "Play Again" currently still calls `onContinue` (same as old
// "Continue" — returns to library). Wire a real replay callback
// through GamesLibraryView's *Destination wrappers if you want actual
// same-game replay instead.

struct ScienceExplainerView: View {
    let game: GameCatalog.Game
    let score: Int?
    var gameResultViewModel: GameResultViewModel? = nil
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var gameResults: [GameResult] {
        guard let gameResultViewModel else { return [] }
        return gameResultViewModel.results.filter { $0.gameName == game.name }
    }

    /// First entry is the just-submitted play (inserted at index 0 by
    /// submitResult). Past best excludes it.
    private var pastBest: Int? {
        gameResults.dropFirst().map(\.score).max()
    }

    private var isNewHighScore: Bool {
        guard let score, let pastBest else { return score != nil && pastBest == nil && !gameResults.isEmpty ? true : false }
        return score > pastBest
    }

    private var playsToday: Int {
        let calendar = Calendar.current
        return gameResults.filter { calendar.isDateInToday($0.playedAt) }.count
    }

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
        }
        .frame(height: 90)
    }

    // MARK: Content

    private var content: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                headline
                scoreBanner
                statsSection
                explainerCard
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
    }

    private var headline: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(game.category.rawValue.uppercased())
                .font(DesignSystem.roundedFont(size: 13, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))

            Text(isNewHighScore ? "New High Score!" : "Nice Work!")
                .font(DesignSystem.title)
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
    }

    private var scoreBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Plays Today")
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.85))
                Text("\(playsToday)")
                    .font(DesignSystem.roundedFont(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Text(score.map(String.init) ?? "—")
                .font(DesignSystem.roundedFont(size: 32, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Today")
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.85))
                if isNewHighScore {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(game.category.gradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private var statsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Divider()
            statRow(label: "Past Best", value: pastBest.map(String.init) ?? "—")
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
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: onContinue) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: "arrow.left")
                    Text("All Games")
                }
                .font(DesignSystem.buttonLabel)
                .foregroundColor(Color(hex: "#6D5DE7"))
            }

            Button(action: onContinue) {
                Text("Play Again")
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
        ScienceExplainerView(game: GameCatalog.games[0], score: 780, gameResultViewModel: GameResultViewModel(), onContinue: {})
    }
}