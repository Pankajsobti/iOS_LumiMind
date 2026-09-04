import SwiftUI

// MARK: - MyBrainTab

private enum MyBrainTab: String, CaseIterable, Identifiable {
    case lpi = "LPI"
    case training = "Training"
    var id: String { rawValue }
}

// MARK: - MyBrainView
//
// The "My Brain" tab container: streak card, LPI/Training sub-tab
// switcher, and logout. Sub-tab content lives in `LPISectionView` and
// `TrainingSectionView`. Reads `stats`/`results` off the shared
// `GameResultViewModel`, same as before.

struct MyBrainView: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: MyBrainViewModel
    @State private var showLogoutConfirmation = false
    @State private var selectedTab: MyBrainTab = .lpi

    init(gameResultViewModel: GameResultViewModel, authViewModel: AuthViewModel) {
        self.gameResultViewModel = gameResultViewModel
        self.authViewModel = authViewModel
        _viewModel = StateObject(wrappedValue: MyBrainViewModel(gameResultViewModel: gameResultViewModel))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.backgroundMain.ignoresSafeArea()

                if gameResultViewModel.stats == nil && !viewModel.hasLoadedOnce {
                    loadingState
                } else {
                    content
                }
            }
            .navigationTitle("My Brain")
        }
        .task {
            await viewModel.load()
        }
    }

    private var loadingState: some View {
        ProgressView()
            .tint(DesignSystem.backgroundOnboarding)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                if let error = gameResultViewModel.errorMessage {
                    Text(error)
                        .font(DesignSystem.caption)
                        .foregroundColor(.red)
                }

                streakCard
                    .padding(.top, DesignSystem.Spacing.md)

                tabSwitcher

                Group {
                    switch selectedTab {
                    case .lpi:
                        LPISectionView(gameResultViewModel: gameResultViewModel, viewModel: viewModel)
                    case .training:
                        TrainingSectionView(gameResultViewModel: gameResultViewModel, viewModel: viewModel)
                    }
                }

                logoutSection

                Spacer(minLength: DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: Streak card

    private var streakCard: some View {
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
                Text("\(gameResultViewModel.stats?.streak ?? 0)-day streak")
                    .font(DesignSystem.headline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)
                Text(lastPlayedText)
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
            }

            Spacer()
        }
    }

    private var lastPlayedText: String {
        guard let date = gameResultViewModel.stats?.lastPlayedDate else {
            return "No games played yet"
        }
        return "Last played \(Self.relativeFormatter.localizedString(for: date, relativeTo: Date()))"
    }

    // MARK: Tab switcher

    private var tabSwitcher: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            ForEach(MyBrainTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: DesignSystem.Spacing.xxs) {
                        Text(tab.rawValue.uppercased())
                            .font(DesignSystem.subheadline.weight(.semibold))
                            .foregroundColor(
                                selectedTab == tab
                                    ? DesignSystem.backgroundOnboarding
                                    : DesignSystem.backgroundOnboarding.opacity(0.4)
                            )

                        Rectangle()
                            .fill(
                                selectedTab == tab
                                    ? AnyShapeStyle(DesignSystem.primaryGradient)
                                    : AnyShapeStyle(Color.clear)
                            )
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: Logout

    private var logoutSection: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            Text("Log Out")
                .font(DesignSystem.headline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm + DesignSystem.Spacing.xxs)
                .background(Color.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
        }
        .alert("Log Out?", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                authViewModel.logout()
            }
        } message: {
            Text("You'll need to log back in to continue your training.")
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

// MARK: - Preview

#Preview {
    MyBrainView(gameResultViewModel: GameResultViewModel(), authViewModel: AuthViewModel())
}