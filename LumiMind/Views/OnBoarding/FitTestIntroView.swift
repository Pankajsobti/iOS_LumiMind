import SwiftUI

// MARK: - FitTestIntroView
//
// Reached after successful signup (per step 10's wiring). Still uses
// the navy onboarding background — gameplay itself (MemoryMatrixView)
// is where the cream main-app aesthetic begins. Purely presentational:
// one headline/body pair (placeholder copy) and a single Start CTA.

struct FitTestIntroView: View {
    /// Launches MemoryMatrixView. The caller owns navigation/presentation.
    var onStart: () -> Void

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Let's find your starting point")
                        .font(DesignSystem.title)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .multilineTextAlignment(.center)

                    // Placeholder copy — swap before ship.
                    Text("Let's see where you're starting from — this quick game helps us build your 30-day plan.")
                        .font(DesignSystem.subheadline)
                        .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                Spacer()
                Spacer()

                Button(action: onStart) {
                    Text("Start")
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