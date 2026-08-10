import SwiftUI

// MARK: - FitTestIntroView
//
// Reached after successful signup (per step 10's wiring). Still uses
// the navy onboarding background — gameplay itself (MemoryMatrixView)
// is where the cream main-app aesthetic begins.

struct FitTestIntroView: View {
    /// Launches MemoryMatrixView. The caller owns navigation/presentation.
    var onStart: () -> Void

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
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FitTestIntroView(onStart: {
        print("Start tapped — launch MemoryMatrixView")
    })
}