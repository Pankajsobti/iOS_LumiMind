import SwiftUI

struct GamesLibraryView: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    @State private var path = NavigationPath()
    @State private var searchText = ""

    // TODO: replace with real streak/energy fields once backend exposes them.
    private var streakCount: Int { 0 }
    private var energyText: String { "--" }

    private var filteredGames: [GameCatalog.Game]? {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return GameCatalog.games.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DesignSystem.backgroundMain.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        topBar
                        Text("Games")
                            .font(DesignSystem.largeTitle)
                            .foregroundColor(.primary)
                        searchBar

                        if let filtered = filteredGames {
                            GameRow(title: nil, games: filtered)
                        } else {
                            GameRow(title: "Today's games", games: GameCatalog.todaysGames)
                            ForEach(GameCategory.allCases) { category in
                                let games = GameCatalog.games(in: category)
                                if !games.isEmpty {
                                    GameRow(title: category.rawValue, games: games)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: GameCatalog.Game.self) { game in
                GameIntroView(game: game) {
                    destination(for: game)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            statPill(icon: "flame.fill", tint: streakCount > 0 ? Color(hex: "#FF8A3D") : .gray.opacity(0.5), text: "\(streakCount)")
            statPill(icon: "bolt.fill", tint: Color(hex: "#FFC93D"), text: energyText)
            Spacer()
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
    }

    private func statPill(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            Image(systemName: icon).foregroundColor(tint)
            Text(text).font(DesignSystem.headline).foregroundColor(.primary)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("What do you want to play?", text: $searchText)
                .font(DesignSystem.body)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func destination(for game: GameCatalog.Game) -> some View {
        switch game.id {
        case "memory_matrix":
            MemoryMatrixDestination(gameResultViewModel: gameResultViewModel, game: game, popToRoot: { path = NavigationPath() })
        case "speed_match":
            SpeedMatchDestination(gameResultViewModel: gameResultViewModel, game: game, popToRoot: { path = NavigationPath() })
        case "lost_in_migration":
            LostInMigrationDestination(gameResultViewModel: gameResultViewModel, game: game, popToRoot: { path = NavigationPath() })
        case "brain_shift":
            BrainShiftDestination(gameResultViewModel: gameResultViewModel, game: game, popToRoot: { path = NavigationPath() })
        case "pirate_passage":
            PiratePassageDestination(gameResultViewModel: gameResultViewModel, game: game, popToRoot: { path = NavigationPath() })
        case "splitting_seeds":
            SplittingSeedsDestination(gameResultViewModel: gameResultViewModel, game: game, popToRoot: { path = NavigationPath() })
        case "train_of_thought":
            TrainOfThoughtDestination(gameResultViewModel: gameResultViewModel, game: game, popToRoot: { path = NavigationPath() })    
        default:
            ComingSoonView(gameName: game.name, category: game.category)
        }
    }
}

// MARK: - GameRow

private struct GameRow: View {
    let title: String?
    let games: [GameCatalog.Game]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let title {
                Text(title)
                    .font(DesignSystem.title2)
                    .foregroundColor(.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(games) { game in
                        NavigationLink(value: game) {
                            GameTile(game: game)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - GameTile

private struct GameTile: View {
    let game: GameCatalog.Game

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                    .fill(game.category.gradient)
                    .frame(width: 140, height: 130)
                    .overlay(
                        Group {
                            if let customImageName = game.customImageName {
                              Image(customImageName)
                              .resizable()
                              .aspectRatio(contentMode: .fill)
                              .frame(width: 140, height: 130)
                              .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
                            } else {
                                Image(systemName: game.iconName)
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    )

                if game.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(Circle())
                        .padding(6)
                }
            }

            Text(game.name)
                .font(DesignSystem.headline)
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(game.category.rawValue)
                .font(DesignSystem.caption)
                .foregroundColor(.gray)
        }
        .frame(width: 140, alignment: .leading)
    }
}

// MARK: - Destination wrappers (unchanged from before)

private struct MemoryMatrixDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        MemoryMatrixView(gameResultViewModel: gameResultViewModel, isFitTest: false, onComplete: { showScienceExplainer = true })
            .navigationDestination(isPresented: $showScienceExplainer) {
                ScienceExplainerView(game: game, score: gameResultViewModel.results.first?.score, onContinue: popToRoot)
            }
    }
}

private struct SpeedMatchDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        SpeedMatchView(gameResultViewModel: gameResultViewModel, isFitTest: false, onComplete: { showScienceExplainer = true })
            .navigationDestination(isPresented: $showScienceExplainer) {
                ScienceExplainerView(game: game, score: gameResultViewModel.results.first?.score, onContinue: popToRoot)
            }
    }
}

private struct LostInMigrationDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        LostInMigrationView(gameResultViewModel: gameResultViewModel, isFitTest: false, onComplete: { showScienceExplainer = true })
            .navigationDestination(isPresented: $showScienceExplainer) {
                ScienceExplainerView(game: game, score: gameResultViewModel.results.first?.score, onContinue: popToRoot)
            }
    }
}

private struct BrainShiftDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        BrainShiftView(gameResultViewModel: gameResultViewModel, isFitTest: false, onComplete: { showScienceExplainer = true })
            .navigationDestination(isPresented: $showScienceExplainer) {
                ScienceExplainerView(game: game, score: gameResultViewModel.results.first?.score, onContinue: popToRoot)
            }
    }
}

private struct PiratePassageDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        PiratePassageView(gameResultViewModel: gameResultViewModel, isFitTest: false, onComplete: { showScienceExplainer = true })
            .navigationDestination(isPresented: $showScienceExplainer) {
                ScienceExplainerView(game: game, score: gameResultViewModel.results.first?.score, onContinue: popToRoot)
            }
    }
}

private struct SplittingSeedsDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        SplittingSeedsView(gameResultViewModel: gameResultViewModel, isFitTest: false, onComplete: { showScienceExplainer = true })
            .navigationDestination(isPresented: $showScienceExplainer) {
                ScienceExplainerView(game: game, score: gameResultViewModel.results.first?.score, onContinue: popToRoot)
            }
    }
}

private struct TrainOfThoughtDestination: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    let game: GameCatalog.Game
    let popToRoot: () -> Void
    @State private var showScienceExplainer = false

    var body: some View {
        TrainOfThoughtView(gameResultViewModel: gameResultViewModel, isFitTest: false, onComplete: { showScienceExplainer = true })
            .navigationDestination(isPresented: $showScienceExplainer) {
                ScienceExplainerView(game: game, score: gameResultViewModel.results.first?.score, onContinue: popToRoot)
            }
    }
}

#Preview {
    GamesLibraryView(gameResultViewModel: GameResultViewModel())
}