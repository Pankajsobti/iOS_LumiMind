//
//  LPISectionView.swift
//  LumiMind
//
//  "LPI" sub-tab of My Brain: overall + per-category performance
//  index, percentile comparison, and per-game strength/progress
//  profiles. Every card here is unlocked — this is the free
//  equivalent of a premium-gated feature in a reference app.
//

import SwiftUI

struct LPISectionView: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    @ObservedObject var viewModel: MyBrainViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            overallCard
            categoryRows
            howYouCompareCard
            gameStrengthCard
            gameProgressCard
        }
    }

    // MARK: Overall

    private var overallCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(DesignSystem.backgroundOnboarding)
                Text("Brain Performance Index")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                    .textCase(.uppercase)
            }

            Divider()

            Text("Overall Index")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            if let overall = viewModel.overallLPI {
                Text(scoreText(overall))
                    .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                    .foregroundStyle(DesignSystem.primaryGradient)
            } else {
                Text("Your Overall Index will be available immediately after playing a game from each of the Training Areas below.")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    // MARK: Per-category rows

    private var categoryRows: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(GameCategory.allCases) { category in
                categoryRow(category)
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

            Text(score > 0 ? scoreText(score) : "--")
                .font(DesignSystem.roundedFont(size: 20, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + DesignSystem.Spacing.xxs)
        .background(category.gradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }

    // MARK: How You Compare

    private var howYouCompareCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("How You Compare")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            if let overallPercentile = viewModel.overallPercentile {
                Text("You score better than \(overallPercentile)% of players overall.")
                    .font(DesignSystem.body)
                    .foregroundColor(DesignSystem.backgroundOnboarding)

                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(GameCategory.allCases) { category in
                        if let p = viewModel.percentile(for: category) {
                            comparisonRow(category: category, percentile: p)
                        }
                    }
                }
            } else {
                placeholderText("Play a game in every Training Area to see how you compare.")
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private func comparisonRow(category: GameCategory, percentile: Int) -> some View {
        HStack {
            Text(category.rawValue)
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
            Spacer()
            Text("Top \(100 - percentile)%")
                .font(DesignSystem.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
    }

    // MARK: Game Strength Profile

    private var gameStrengthCard: some View {
        let entries = viewModel.gameStrengthProfile(results: gameResultViewModel.results)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Game Strength Profile")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            if entries.isEmpty {
                placeholderText("Play a game to see your strength profile.")
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.gameName)
                                    .font(DesignSystem.headline)
                                    .foregroundColor(DesignSystem.backgroundOnboarding)
                                Text(LPIBenchmark.strengthLabel(forPercentile: entry.percentile))
                                    .font(DesignSystem.caption)
                                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                            }
                            Spacer()
                            Text("\(entry.latestScore)")
                                .font(DesignSystem.roundedFont(size: 18, weight: .bold))
                                .foregroundColor(DesignSystem.backgroundOnboarding)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background((entry.category?.gradient ?? DesignSystem.primaryGradient).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    // MARK: Game Progress Profile

    private var gameProgressCard: some View {
        let entries = viewModel.gameProgressProfile(results: gameResultViewModel.results)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Game Progress Profile")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            if entries.isEmpty {
                placeholderText("Play a game more than once to track your progress.")
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.gameName)
                                .font(DesignSystem.headline)
                                .foregroundColor(DesignSystem.backgroundOnboarding)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: entry.percentChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                Text("\(abs(Int(entry.percentChange)))%")
                            }
                            .font(DesignSystem.subheadline.weight(.semibold))
                            .foregroundColor(entry.percentChange >= 0 ? Color(hex: "#2ECC71") : Color(hex: "#FF5E5B"))
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(Color.white.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    // MARK: Helpers

    private func placeholderText(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.subheadline)
            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
    }

    private func scoreText(_ score: Double) -> String {
        score == score.rounded() ? String(Int(score)) : String(format: "%.1f", score)
    }
}