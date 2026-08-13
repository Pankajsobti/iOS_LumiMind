import Foundation
import Combine

// MARK: - HomeViewModel
//
// SOURCE OF TRUTH: `AuthViewModel.currentUser`. This ViewModel does NOT
// cache or duplicate streak/category-score state locally — every read
// goes straight through to `authViewModel.currentUser` so Home can
// never drift out of sync with any other screen sharing the same
// `AuthViewModel` instance (e.g. right after DifficultySelectionView's
// `submitOnboarding` call updates `currentUser`). The only state this
// ViewModel owns itself is `isRefreshing`, purely a UI-loading flag.
//
// `GameResultViewModel.fetchStats()` is intentionally NOT used here —
// `User.categoryScores`/`streak` already live on `currentUser` and stay
// current via `AuthViewModel`, so calling a second endpoint for the
// same data would just be a duplicate source of truth to keep in sync.

@MainActor
final class HomeViewModel: ObservableObject {
    private let authViewModel: AuthViewModel

    @Published private(set) var isRefreshing = false

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }

    // MARK: Derived state (always read through to currentUser)

    var streak: Int {
        authViewModel.currentUser?.streak ?? 0
    }

    /// True while we don't yet have a user to show anything real for —
    /// HomeView should render a loading/placeholder state in this case.
    var isLoadingUser: Bool {
        authViewModel.currentUser == nil
    }

    /// Placeholder "recommendation" logic: cycles through the 6 locked
    /// games once per calendar day, independent of any actual
    /// difficulty/goals/performance data. Real recommendation logic is
    /// out of scope for this build prompt.
    var recommendedGame: GameName {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % GameName.allCases.count
        return GameName.allCases[index]
    }

    /// Only Memory Matrix is actually built (step 11) — everything else
    /// routes to a "Coming soon" stub until backlog #19.
    var isRecommendedGamePlayable: Bool {
        recommendedGame == .memoryMatrix
    }

    // MARK: Today's Workout card

    var workoutNumber: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    }

    let totalWorkouts = 30

    var todaysExercises: [GameCatalog.Game] {
        GameCatalog.games
    }

    func isPlayable(_ game: GameCatalog.Game) -> Bool {
        game.id == "memory_matrix"
    }

    // MARK: Refresh

    /// Fetches the current user if we don't already have one in memory
    /// (e.g. app relaunched with a stored token but `currentUser` not
    /// yet hydrated). Safe to call every time HomeView appears — it's a
    /// no-op if `currentUser` is already populated.
    func refreshIfNeeded() async {
        guard authViewModel.currentUser == nil else { return }
        isRefreshing = true
        await authViewModel.fetchCurrentUser()
        isRefreshing = false
    }
}