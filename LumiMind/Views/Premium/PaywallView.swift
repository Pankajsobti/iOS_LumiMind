import SwiftUI

// MARK: - PaywallView
//
// Premium upsell shell (Build Prompt #21). This is a UI/UX-complete
// paywall for a college portfolio project — there is NO real payment
// processing wired up. The primary CTA shows a "Coming Soon" alert
// instead of starting a purchase; swap that alert for a real StoreKit
// flow when/if that becomes in scope.
//
// OUT OF SCOPE (flagged, not silently invented): `GamesLibraryView`
// (step 16) only lists the 6 MVP games from `GameCatalog` — there are
// no locked/premium game entries yet to tap into this screen from. This
// view is therefore standalone and reusable: present it via `.sheet`
// from wherever a future locked-content entry point is added (a
// "More Workouts" card, a Discover-tab upsell banner, etc.) without any
// changes needed here.
//
// Design decision (per build prompt (c)): dark navy background with
// the primary orange-coral gradient as the hero treatment, matching
// the auth/onboarding "high-stakes decision" screens rather than the
// cream main-app background.

struct PaywallView: View {
    /// Presentation-agnostic dismiss handler. Defaults to the SwiftUI
    /// environment's dismiss action so this works as a `.sheet` with no
    /// extra wiring, but a caller can override it if presented another way.
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var environmentDismiss
    @State private var showComingSoonAlert = false

    private let features: [(icon: String, text: String)] = [
        ("gamecontroller.fill", "Unlock every game, including future releases"),
        ("chart.line.uptrend.xyaxis", "Advanced insights across all 6 categories"),
        ("bolt.fill", "Unlimited daily training sessions"),
        ("sparkles", "New games and challenges added first")
    ]

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding.ignoresSafeArea()

            VStack(spacing: 0) {
                closeButton

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        hero
                        featureList
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                }

                ctaButton
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            // Placeholder only — no StoreKit/payment integration exists
            // yet. Replace this alert with a real purchase flow later.
            Text("Premium purchases aren't available yet. Check back soon!")
        }
    }

    // MARK: Close

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.trailing, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.sm)
        }
    }

    private func dismiss() {
        if let onDismiss {
            onDismiss()
        } else {
            environmentDismiss()
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.primaryGradient)
                    .frame(width: 96, height: 96)

                Image(systemName: "crown.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("LumiMind Premium")
                .font(DesignSystem.largeTitle)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Unlock all games, advanced insights, and more.")
                .font(DesignSystem.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Feature list

    private var featureList: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(features, id: \.text) { feature in
                HStack(spacing: DesignSystem.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.primaryGradient)
                            .frame(width: 36, height: 36)
                        Image(systemName: feature.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(feature.text)
                        .font(DesignSystem.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
            }
        }
    }

    // MARK: CTA
    //
    // Placeholder only — triggers a "Coming Soon" alert rather than a
    // real purchase. Wire up StoreKit here when payment is in scope.

    private var ctaButton: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Button(action: { showComingSoonAlert = true }) {
                Text("Upgrade to Premium")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(DesignSystem.primaryGradient)
            .clipShape(Capsule())

            Text("No payment required for this demo")
                .font(DesignSystem.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
}