import SwiftUI

// MARK: - HomeView
//
// The "Today" tab and first main-app screen the user lands on, either
// after StreakConfirmationView (new users) or directly after login
// (returning users). Reads everything through HomeViewModel, whose
// single source of truth is AuthViewModel.currentUser — see that file's
// header comment for why no separate stats fetch happens here.

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var gameResultViewModel: GameResultViewModel
    @StateObject private var viewModel: HomeViewModel

    private enum Route: Hashable {
        case memoryMatrix
        /// Carries the raw game name string rather than `GameName` itself,
        /// since `GameName` isn't declared `Hashable` in GameResult.swift.
        case comingSoon(String)
    }

        @State private var path: [Route] = []
        @State private var showSettings = false

    init(authViewModel: AuthViewModel, gameResultViewModel: GameResultViewModel) {
        self.authViewModel = authViewModel
        self.gameResultViewModel = gameResultViewModel
        _viewModel = StateObject(wrappedValue: HomeViewModel(authViewModel: authViewModel))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DesignSystem.backgroundMain
                    .ignoresSafeArea()

                if viewModel.isLoadingUser {
                    loadingState
                } else {
                    content
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(DesignSystem.backgroundOnboarding)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(authViewModel: authViewModel)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .memoryMatrix:
                    MemoryMatrixView(
                        gameResultViewModel: gameResultViewModel,
                        isFitTest: false
                    ) {
                        path.removeAll()
                    }
                case .comingSoon(let gameNameRawValue):
                    ComingSoonGameView(gameName: gameNameRawValue)
                }
            }
        }
        .task {
            await viewModel.refreshIfNeeded()
        }
    }

    // MARK: Loading state

    private var loadingState: some View {
        ProgressView()
            .tint(DesignSystem.backgroundOnboarding)
    }

    // MARK: Main content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                streakRow
                    .padding(.top, DesignSystem.Spacing.md)

                Text("Hi, \(viewModel.displayName)")
                    .font(DesignSystem.title)
                    .foregroundColor(DesignSystem.backgroundOnboarding)

                TodaysWorkoutCardView(
                    workoutNumber: viewModel.workoutNumber,
                    totalWorkouts: viewModel.totalWorkouts,
                    exercises: viewModel.todaysExercises,
                    isPlayable: viewModel.isPlayable,
                    onStart: startRecommendedGame,
                    onSelectExercise: startExercise
                )

                Spacer(minLength: DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    // MARK: Streak row

    private var streakRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(DesignSystem.primaryGradient)
                    .frame(width: 44, height: 44)

                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.backgroundMain)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("\(viewModel.streak)-day streak")
                    .font(DesignSystem.headline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)
                Text(viewModel.streak > 0 ? "Keep it going today" : "Start your streak today")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
            }

            Spacer()
        }
    }

    // MARK: Actions

    private func startRecommendedGame() {
        path.append(.memoryMatrix)
    }

    private func startExercise(_ game: GameCatalog.Game) {
        if viewModel.isPlayable(game) {
            path.append(.memoryMatrix)
        } else {
            path.append(.comingSoon(game.name))
        }
    }
}

// MARK: - ComingSoonGameView
//
// Stub destination for the 5 games not yet built (backlog #19). Kept
// here rather than as a separate file since it's a placeholder with no
// real behavior — split it out once real per-game screens replace it.

private struct ComingSoonGameView: View {
    let gameName: String

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(gameName)
                    .font(DesignSystem.title2)
                    .foregroundColor(DesignSystem.backgroundOnboarding)
                Text("Coming soon")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView(
        authViewModel: AuthViewModel(),
        gameResultViewModel: GameResultViewModel()
    )
}