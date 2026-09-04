import SwiftUI

// MARK: - TestHistoryView
//
// "Past Attempts" list for the Cognitive Test, in the same spirit as
// LPISectionView's Game Progress Profile: a scrollable list of past
// scores plus a simple trend indicator vs. the previous attempt.
// Reads off the shared GameResultViewModel, filtered to this
// feature's `category` string — no new backend route needed.

struct TestHistoryView: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel

    private static let cognitiveTestCategory = "Cognitive Test"

    private var attempts: [GameResult] {
        gameResultViewModel.results
            .filter { $0.category == Self.cognitiveTestCategory }
            .sorted { $0.playedAt > $1.playedAt }
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            if gameResultViewModel.isLoading && attempts.isEmpty {
                ProgressView()
                    .tint(DesignSystem.backgroundOnboarding)
            } else if attempts.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Past Attempts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await gameResultViewModel.fetchResults(category: Self.cognitiveTestCategory)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34))
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.3))
            Text("No attempts yet")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
            Text("Take the Cognitive Test to start tracking your results over time.")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                if attempts.count >= 2 {
                    trendCard
                }

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(attempts.enumerated()), id: \.element.id) { index, attempt in
                        let previous = index + 1 < attempts.count ? attempts[index + 1] : nil
                        AttemptRow(attempt: attempt, previousScore: previous?.score)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private var trendCard: some View {
        let latest = attempts[0].score
        let first = attempts[attempts.count - 1].score
        let change = latest - first

        return VStack(spacing: DesignSystem.Spacing.xxs) {
            Text("Since Your First Attempt")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))

            HStack(spacing: 4) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(change >= 0 ? "+" : "")\(change) points")
            }
            .font(DesignSystem.title2)
            .foregroundColor(change >= 0 ? Color(hex: "#2ECC71") : Color(hex: "#FF5E5B"))
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }
}

private struct AttemptRow: View {
    let attempt: GameResult
    let previousScore: Int?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dateFormatter.string(from: attempt.playedAt))
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)

                Text(CognitiveScoring.performanceBadge(forScore: attempt.score).label)
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(attempt.score)")
                    .font(DesignSystem.roundedFont(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.backgroundOnboarding)

                if let previousScore {
                    let delta = attempt.score - previousScore
                    Text("\(delta >= 0 ? "+" : "")\(delta)")
                        .font(DesignSystem.caption)
                        .foregroundColor(delta >= 0 ? Color(hex: "#2ECC71") : Color(hex: "#FF5E5B"))
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}