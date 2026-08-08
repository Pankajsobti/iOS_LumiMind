import SwiftUI

// MARK: - StreakConfirmationView
//
// The last onboarding screen. Purely a celebratory transition — no
// network calls, no further onboarding navigation. Displays the real
// `streak` value already on `currentUser` (set by the backend after the
// Fit Test's GameResult submission in step 11), falling back to "Day 1"
// if it's unexpectedly nil/0 rather than showing something broken.
//
// Navigation note: RootView drives navigation via a plain `Group` +
// `switch` over `RootDestination`, not a `NavigationStack` — so there's
// no swipe-back gesture to disable here. `onFinishOnboarding` is simply
// expected to flip RootView's `destination` to `.main`, at which point
// this view is removed from the hierarchy entirely (not pushed under
// anything), so onboarding naturally isn't re-enterable via back nav.

struct StreakConfirmationView: View {
    @ObservedObject var authViewModel: AuthViewModel

    /// Triggers RootView's transition into the main tab app (Home /
    /// Today tab, backlog #15).
    var onFinishOnboarding: () -> Void

    private var streakDisplayText: String {
        guard let streak = authViewModel.currentUser?.streak, streak > 0 else {
            return "Day 1"
        }
        return "Day \(streak)"
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    streakBadge

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(streakDisplayText)
                            .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                            .foregroundColor(DesignSystem.backgroundOnboarding)

                        Text("Your streak has started!")
                            .font(DesignSystem.title2)
                            .foregroundColor(DesignSystem.backgroundOnboarding)
                            .multilineTextAlignment(.center)

                        Text("Come back tomorrow to keep it going.")
                            .font(DesignSystem.subheadline)
                            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()
                Spacer()

                Button(action: onFinishOnboarding) {
                    Text("Let's Go")
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

    // MARK: Streak badge

    private var streakBadge: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.primaryGradient)
                .frame(width: 120, height: 120)

            Image(systemName: "flame.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(DesignSystem.backgroundMain)
        }
    }
}

// MARK: - Previews

#Preview("With real streak") {
    let vm = AuthViewModel()
    return StreakConfirmationView(
        authViewModel: vm,
        onFinishOnboarding: { print("Finish onboarding — route RootView to .main") }
    )
}

#Preview("Fallback (no streak yet)") {
    StreakConfirmationView(
        authViewModel: AuthViewModel(),
        onFinishOnboarding: { print("Finish onboarding — route RootView to .main") }
    )
}