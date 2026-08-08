import SwiftUI

// MARK: - ResultsPlanView
//
// Shown immediately after MemoryMatrixView finishes. Purely
// presentational — displays the score/duration handed off from the
// just-completed Fit Test (already submitted via GameResultViewModel
// inside MemoryMatrixViewModel) and a placeholder "30-Day Plan" teaser.
// Makes no network calls of its own.
//
// All gameplay data is optional and defaults to friendly fallback copy,
// so this view can never crash — including when used standalone in an
// Xcode preview with no real Fit Test having run.

struct ResultsPlanView: View {
    /// Score from the just-completed Fit Test. Nil-safe: shows fallback
    /// copy if unavailable for any reason.
    var score: Int?

    /// Duration of the just-completed Fit Test, in seconds. Optional —
    /// purely a nice-to-have detail, never required to render.
    var durationSeconds: Int?

    /// Advances to Difficulty selection (backlog #13).
    var onContinue: () -> Void

    /// The 3 categories teased in the "30-Day Plan" preview. Fixed to a
    /// friendly, varied subset rather than all 6 to keep the teaser
    /// scannable — not tied to any real plan-generation logic yet.
    private let previewCategories: [GameCategory] = [.memory, .speed, .attention]

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    header
                        .padding(.top, DesignSystem.Spacing.xl)

                    scoreCard

                    planTeaser

                    Spacer(minLength: DesignSystem.Spacing.xl)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            VStack {
                Spacer()
                continueButton
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.backgroundMain.opacity(0), DesignSystem.backgroundMain],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 90)
                        .allowsHitTesting(false),
                        alignment: .top
                    )
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("You're off to a great start!")
                .font(DesignSystem.title)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .multilineTextAlignment(.center)

            Text("Here's your baseline from the Fit Test")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
        }
    }

    // MARK: Score card

    private var scoreCard: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("MEMORY MATRIX SCORE")
                .font(DesignSystem.roundedFont(size: 12, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
                .tracking(1)

            Text(scoreDisplayText)
                .font(DesignSystem.roundedFont(size: 44, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)

            if let durationSeconds {
                Text("Completed in \(durationSeconds)s")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
        .background(DesignSystem.memoryGradient.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius)
                .strokeBorder(DesignSystem.backgroundOnboarding.opacity(0.06), lineWidth: 1)
        )
    }

    private var scoreDisplayText: String {
        guard let score else { return "—" }
        return "\(score)"
    }

    // MARK: 30-Day Plan teaser

    private var planTeaser: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Your 30-Day Plan")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            // Placeholder framing copy — swap before ship.
            Text("We'll help you build focus, memory, and speed over the next 30 days, with games tailored to your goals.")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.65))

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(previewCategories) { category in
                    CategoryTeaserChip(category: category)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.backgroundOnboarding.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    // MARK: Continue CTA

    private var continueButton: some View {
        Button(action: onContinue) {
            Text("See My Plan")
                .font(DesignSystem.buttonLabel)
                .foregroundColor(DesignSystem.backgroundMain)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.primaryGradient)
        .clipShape(Capsule())
    }
}

// MARK: - CategoryTeaserChip
//
// Small decorative preview chip for the plan teaser — uses only the
// locked per-category gradients from DesignSystem, no new colors.

private struct CategoryTeaserChip: View {
    let category: GameCategory

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Circle()
                .fill(category.gradient)
                .frame(width: 40, height: 40)

            Text(category.rawValue)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
    }
}

// MARK: - Previews

#Preview("With score") {
    ResultsPlanView(
        score: 780,
        durationSeconds: 47,
        onContinue: { print("Continue to Difficulty selection") }
    )
}

#Preview("No data (fallback)") {
    ResultsPlanView(
        score: nil,
        durationSeconds: nil,
        onContinue: { print("Continue to Difficulty selection") }
    )
}