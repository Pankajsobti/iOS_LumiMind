import SwiftUI

// MARK: - MyBrainView
//
// The "My Brain" tab — stats/history dashboard. Reads `stats` and
// `results` directly off the shared `GameResultViewModel` (owned by
// `MainTabView`, passed down so results submitted elsewhere show up
// here without a re-fetch). `MyBrainViewModel` only orchestrates the
// initial concurrent load — see its header comment.

struct MyBrainView: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    @StateObject private var viewModel: MyBrainViewModel

    init(gameResultViewModel: GameResultViewModel) {
        self.gameResultViewModel = gameResultViewModel
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

    // MARK: Full-screen loading (first load only)

    private var loadingState: some View {
        ProgressView()
            .tint(DesignSystem.backgroundOnboarding)
    }

    // MARK: Content

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

                categoryBreakdownSection

                historySection

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

    // MARK: Category breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Category Scores")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(GameCategory.allCases) { category in
                    categoryRow(category)
                }
            }
        }
    }

    private func categoryRow(_ category: GameCategory) -> some View {
        let scores = gameResultViewModel.stats?.categoryScores ?? .zero
        let score = scores[category]

        return HStack {
            Text(category.rawValue)
                .font(DesignSystem.headline)
                .foregroundColor(.white)

            Spacer()

            Text(scoreText(score))
                .font(DesignSystem.roundedFont(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + DesignSystem.Spacing.xxs)
        .background(category.gradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }

    private func scoreText(_ score: Double) -> String {
        score == score.rounded() ? String(Int(score)) : String(format: "%.1f", score)
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Training History")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            if gameResultViewModel.results.isEmpty {
                if viewModel.hasLoadedOnce {
                    emptyHistoryState
                } else {
                    ProgressView()
                        .tint(DesignSystem.backgroundOnboarding)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.xl)
                }
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(gameResultViewModel.results) { result in
                        historyRow(result)
                    }
                }
            }
        }
    }

    private var emptyHistoryState: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.4))
            Text("No games played yet")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
            Text("Play a game to start building your training history.")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .background(Color.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private func historyRow(_ result: GameResult) -> some View {
        // GameCatalog is the canonical source for display name/icon;
        // fall back to the raw stored `category` string if a game isn't
        // (or is no longer) in the catalog, rather than dropping the row.
        let catalogGame = GameCatalog.games.first { $0.name == result.gameName }
        let category = catalogGame?.category ?? GameCategory(rawValue: result.category)
        let gradient = category?.gradient ?? DesignSystem.primaryGradient

        return HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: catalogGame?.iconName ?? "gamecontroller.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.gameName)
                    .font(DesignSystem.headline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)
                Text("\(category?.rawValue ?? result.category) • \(Self.dateFormatter.string(from: result.playedAt))")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
            }

            Spacer()

            Text("\(result.score)")
                .font(DesignSystem.roundedFont(size: 18, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
        // Tapping is a no-op for MVP — no result-detail view exists yet.
        // Flagged out of scope per Build Prompt #20.
    }

    // MARK: Formatters

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

// MARK: - Preview

#Preview {
    MyBrainView(gameResultViewModel: GameResultViewModel())
}