//
//  WelcomeView.swift
//  LumiMind
//
//  Shown after SplashView resolves to "not authenticated." Purely
//  navigational — no backend calls. Navigation is callback-driven
//  (`onGetStarted` / `onLogIn`) rather than owning any NavigationStack
//  itself, matching the pattern RootView already established with
//  SplashView's `onFinished` closure.
//

import SwiftUI

struct WelcomeView: View {
    /// Advances toward the onboarding questionnaire (build prompt #8).
    var onGetStarted: () -> Void

    /// Routes to the Login screen (build prompt #10).
    var onLogIn: () -> Void

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("LumiMind")
                        .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                        .foregroundColor(DesignSystem.backgroundMain)

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Train your brain in minutes a day")
                            .font(DesignSystem.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(DesignSystem.backgroundMain)

                        Text("Quick, adaptive games across six core skills — with progress you can actually see.")
                            .font(DesignSystem.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }

                Spacer()
                Spacer()

                VStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: onGetStarted) {
                        Text("Get Started")
                            .font(DesignSystem.buttonLabel)
                            .foregroundColor(DesignSystem.backgroundMain)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    }
                    .background(DesignSystem.primaryGradient)
                    .clipShape(Capsule())

                    Button(action: onLogIn) {
                        Text("Log In")
                            .font(DesignSystem.body)
                            .foregroundColor(DesignSystem.backgroundMain.opacity(0.85))
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
    }
}

#Preview {
    WelcomeView(onGetStarted: {}, onLogIn: {})
}