import SwiftUI

// MARK: - FitTestIntroView
//
// Reached after successful signup (per step 10's wiring). Still uses
// the navy onboarding background — gameplay itself (MemoryMatrixView)
// is where the cream main-app aesthetic begins.

struct FitTestIntroView: View {
    /// Launches MemoryMatrixView. The caller owns navigation/presentation.
    var onStart: () -> Void

    /// Skips the Fit Test (and the rest of onboarding) entirely,
    /// dropping the user straight into the main app.
    var onSkip: () -> Void

    private let steps: [(title: String, subtitle: String)] = [
        ("Play 3 quick games", "We'll measure where you're starting from."),
        ("See how you compare", "Against others with similar goals."),
        ("Get your plan", "Built around your actual results.")
    ]

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Let's find your baseline")
                        .font(DesignSystem.title)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .multilineTextAlignment(.center)

                    Text("Three quick games, then your plan.")
                        .font(DesignSystem.subheadline)
                        .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Text("\(index + 1)")
                                .font(DesignSystem.headline)
                                .foregroundColor(DesignSystem.backgroundMain)
                                .frame(width: DesignSystem.Spacing.xl, height: DesignSystem.Spacing.xl)
                                .background(DesignSystem.primaryGradient)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                                Text(step.title)
                                    .font(DesignSystem.headline)
                                    .foregroundColor(DesignSystem.backgroundMain)

                                Text(step.subtitle)
                                    .font(DesignSystem.subheadline)
                                    .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.xl)

                Spacer()
                Spacer()

                Button(action: onStart) {
                    Text("Start Fit Test")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
                .buttonStyle(.plain)
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
                .shadow(color: DesignSystem.backgroundMain.opacity(0.35), radius: 14, x: 0, y: 8)
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Button(action: onSkip) {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("Skip for now")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(DesignSystem.body)
                    .foregroundColor(DesignSystem.backgroundMain.opacity(0.65))
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FitTestIntroView(
        onStart: { print("Start tapped — launch MemoryMatrixView") },
        onSkip: { print("Skip tapped — go straight to main") }
    )
}