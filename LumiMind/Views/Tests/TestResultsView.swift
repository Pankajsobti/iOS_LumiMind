import SwiftUI

// MARK: - TestResultsView
//
// Shown after TestSessionViewModel finishes. Result is already saved
// automatically at submission time (same auto-submit-on-completion
// pattern as MemoryMatrixViewModel/GameResultViewModel) — "Save to
// History" here is a confirmation affordance, not a second write.

struct TestResultsView: View {
    let grandIndexScore: Int
    let results: [SubtestResult]
    let onDone: () -> Void

    private var performanceBadge: (label: String, color: Color) {
        let badge = CognitiveScoring.performanceBadge(forScore: grandIndexScore)
        return (badge.label, Color(hex: badge.colorHex))
    }

    private var grandIndexPercentile: Int {
        // Grand Index is scaled mean 100 / SD 15 — convert back to a
        // percentile for display using the same normal-CDF logic.
        let z = Double(grandIndexScore - 100) / 15
        let p = (0.5 * (1 + erf(z / Double(2).squareRoot()))) * 100
        return Int(p.rounded().clamped(1...99))
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        scoreHeader
                        subtestBreakdown
                    }
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
                }

                bottomBar
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var scoreHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Grand Index Score")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))

            Text("\(grandIndexScore)")
                .font(DesignSystem.roundedFont(size: 56, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Text("\(CognitiveScoring.percentileRangeLabel(for: grandIndexPercentile)) percentile")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))

            Text(performanceBadge.label)
                .font(DesignSystem.caption)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(performanceBadge.color)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private var subtestBreakdown: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Breakdown")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .padding(.horizontal, DesignSystem.Spacing.md)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(TestSessionViewModel.subtestOrder, id: \.self) { subtest in
                    if let result = results.first(where: { $0.subtest == subtest }) {
                        SubtestResultCard(result: result)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("Saved to your history")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))

            Button(action: onDone) {
                Text("Done")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(DesignSystem.primaryGradient)
            .clipShape(Capsule())
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.xs)
        .padding(.bottom, DesignSystem.Spacing.md)
        .background(DesignSystem.backgroundMain.ignoresSafeArea(edges: .bottom))
    }
}

private struct SubtestResultCard: View {
    let result: SubtestResult

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: result.subtest.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(result.subtest.category.gradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(result.subtest.title)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)

                Text(result.subtest.domainLabel.uppercased())
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
            }

            Spacer()

            Text(result.percentileRangeLabel)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(DesignSystem.backgroundOnboarding.opacity(0.06))
                .clipShape(Capsule())
        }
        .padding(DesignSystem.Spacing.sm)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

private extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self { min(max(self, lo), hi) }
}