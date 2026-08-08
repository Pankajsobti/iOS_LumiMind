import SwiftUI

struct GamesLibraryView: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    @State private var path = NavigationPath()

    private let columns = [
        GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
        GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DesignSystem.backgroundMain.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                        ForEach(GameCatalog.games) { game in
                            NavigationLink(value: game) {
                                GameCard(game: game)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Games")
            .navigationDestination(for: GameCatalog.Game.self) { game in
                GameIntroView(game: game) {
                    destination(for: game)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for game: GameCatalog.Game) -> some View {
        if game.id == "memory_matrix" {
            MemoryMatrixDestination(
                gameResultViewModel: gameResultViewModel,
                game: game,
                popToRoot: { path = NavigationPath() }
            )
        } else if game.id == "speed_match" {
            SpeedMatchDestination(
                gameResultViewModel: gameResultViewModel,
                game: game,
                popToRoot: { path = NavigationPath() }
            )
        } else {
            ComingSoonView(gameName: game.name, category: game.category)
        }
    }
}

// MARK: - MemoryMatrixDestination
//
// On completion, routes through ScienceExplainerView (score pulled from
// the just-submitted result) instead of dismissing straight back.
// "Continue" on that screen pops the whole stack back to the library.

private struct MemoryMatrixDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        MemoryMatrixView(
            gameResultViewModel: gameResultViewModel,
            isFitTest: false,
            onComplete: { showScienceExplainer = true }
        )
        .navigationDestination(isPresented: $showScienceExplainer) {
            ScienceExplainerView(
                game: game,
                score: gameResultViewModel.results.first?.score,
                onContinue: popToRoot
            )
        }
    }
}

// MARK: - SpeedMatchDestination
//
// Mirrors MemoryMatrixDestination exactly: on completion, routes
// through ScienceExplainerView with the just-submitted score, then
// "Continue" pops the whole stack back to the library.

private struct SpeedMatchDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        SpeedMatchView(
            gameResultViewModel: gameResultViewModel,
            isFitTest: false,
            onComplete: { showScienceExplainer = true }
        )
        .navigationDestination(isPresented: $showScienceExplainer) {
            ScienceExplainerView(
                game: game,
                score: gameResultViewModel.results.first?.score,
                onContinue: popToRoot
            )
        }
    }
}

// MARK: - GameCard

private struct GameCard: View {
    let game: GameCatalog.Game

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: game.iconName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: DesignSystem.Spacing.lg)

            Text(game.category.rawValue.uppercased())
                .font(DesignSystem.caption)
                .foregroundColor(.white.opacity(0.85))

            Text(game.name)
                .font(DesignSystem.headline)
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(game.category.gradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }
}

// MARK: - Preview

#Preview {
    GamesLibraryView(gameResultViewModel: GameResultViewModel())
}