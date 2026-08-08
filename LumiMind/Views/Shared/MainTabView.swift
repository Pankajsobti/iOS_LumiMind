import SwiftUI

// MARK: - MainTabView
//
// The main-app shell RootView switches into once onboarding is
// complete (or immediately after login, for returning users). Hosts
// exactly the 5 tabs defined by DesignSystem.TabItem. Only Today
// (HomeView) has real content this step — the other 4 are stubs to be
// replaced in later backlog items.
//
// Owns the single `GameResultViewModel` instance shared by every tab
// that needs game-result data, so results submitted in one tab (e.g.
// Games) are immediately visible to another (e.g. My Brain) without
// re-fetching.

struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var gameResultViewModel = GameResultViewModel()

    var body: some View {
        TabView {
            HomeView(authViewModel: authViewModel, gameResultViewModel: gameResultViewModel)
                .tabItem {
                    Label(TabItem.today.rawValue, systemImage: "sun.max.fill")
                }

            GamesLibraryView(gameResultViewModel: gameResultViewModel)
                .tabItem {
                    Label(TabItem.games.rawValue, systemImage: "gamecontroller.fill")
                }

           MyBrainView(gameResultViewModel: gameResultViewModel)
                .tabItem {
                     Label(TabItem.myBrain.rawValue, systemImage: "brain.head.profile")
                }

            ComingSoonTabView(tab: .discover)
                .tabItem {
                    Label(TabItem.discover.rawValue, systemImage: "sparkles")
                }

            ComingSoonTabView(tab: .tests)
                .tabItem {
                    Label(TabItem.tests.rawValue, systemImage: "checklist")
                }
        }
        .tint(DesignSystem.backgroundOnboarding)
    }
}

// MARK: - ComingSoonTabView
//
// Placeholder for the 4 tabs not yet built. Replace each with its real
// screen as those backlog items land — nothing else in MainTabView
// needs to change when that happens.

private struct ComingSoonTabView: View {
    let tab: TabItem

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(tab.rawValue)
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
    MainTabView(authViewModel: AuthViewModel())
}