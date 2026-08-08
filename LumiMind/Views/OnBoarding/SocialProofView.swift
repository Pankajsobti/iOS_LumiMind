import SwiftUI

// MARK: - SocialProofView
//
// Static, persuasive screen shown between the onboarding questionnaire
// and signup (RootDestination.login). Purely presentational: no
// networking, no user input, no selections — just a headline, a few
// stat callouts, and a single CTA that advances the flow.
//
// Navigation follows the same closure-based pattern as WelcomeView /
// QuestionnaireFlowView (no NavigationStack, no new mechanism) — the
// caller (RootView, once wired up) owns the actual destination change.
//
// All copy/numbers below are PLACEHOLDER content to be swapped for real
// claims later — clearly marked, not shipped as final marketing copy.

struct SocialProofView: View {
    /// Advances to the next onboarding step (Login/Signup — backlog #10).
    var onContinue: () -> Void

    // MARK: Placeholder content — swap before ship

    private let headline = "Join thousands building a sharper mind"
    private let stats: [StatCallout] = [
        StatCallout(value: "50K+", label: "Learners onboard (placeholder)"),
        StatCallout(value: "20%", label: "Avg. improvement in 30 days (placeholder)"),
        StatCallout(value: "4.8★", label: "Average app rating (placeholder)")
    ]

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text(headline)
                        .font(DesignSystem.title)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                    statCallouts
                }

                Spacer()
                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
                .buttonStyle(.plain)
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
    }

    // MARK: Stat callouts

    private var statCallouts: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(stats) { stat in
                HStack(spacing: DesignSystem.Spacing.md) {
                    Text(stat.value)
                        .font(DesignSystem.roundedFont(size: 22, weight: .bold))
                        .foregroundColor(DesignSystem.backgroundMain)
                        .frame(minWidth: 64, alignment: .leading)

                    Text(stat.label)
                        .font(DesignSystem.subheadline)
                        .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))

                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.backgroundMain.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}

// MARK: - StatCallout

private struct StatCallout: Identifiable {
    let id = UUID()
    let value: String
    let label: String
}

// MARK: - Preview

#Preview {
    SocialProofView(onContinue: {
        print("Continue tapped — advance to Login/Signup")
    })
}