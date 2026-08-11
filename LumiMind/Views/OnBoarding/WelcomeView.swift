//
//  WelcomeView.swift
//  LumiMind
//
//  Shown after SplashView resolves to "not authenticated." Purely
//  navigational — no backend calls. Navigation is callback-driven
//  (`onGetStarted`) matching the pattern RootView already established
//  with SplashView's `onFinished` closure.
//
//  NOTE: Top mark uses a placeholder SF Symbol styled with DesignSystem
//  tokens. Swap for `Image("AppIcon")` (or your actual asset name) once
//  the icon is added to Assets.xcassets — see TODO below.
//

import SwiftUI

struct WelcomeView: View {
    /// Advances toward the onboarding questionnaire (build prompt #8).
    var onGetStarted: () -> Void

    private let steps: [String] = [
        "Your goals",
        "A quick fit test",
        "Your personalized plan"
    ]

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    // TODO: replace with Image("AppIcon") once added to Assets.xcassets
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(DesignSystem.primaryGradient)

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Let's get to know your mind")
                            .font(DesignSystem.title)
                            .multilineTextAlignment(.center)
                            .foregroundColor(DesignSystem.backgroundMain)

                        Text("A few quick questions, then we'll build a training plan around how you actually think.")
                            .font(DesignSystem.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Text("\(index + 1)")
                                    .font(DesignSystem.headline)
                                    .foregroundColor(DesignSystem.backgroundMain)
                                    .frame(width: 28, height: 28)
                                    .background(DesignSystem.primaryGradient)
                                    .clipShape(Circle())

                                Text(step)
                                    .font(DesignSystem.body)
                                    .foregroundColor(DesignSystem.backgroundMain)

                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xl)
                    .padding(.top, DesignSystem.Spacing.sm)
                }

                Spacer()
                Spacer()

                Button(action: onGetStarted) {
                    Text("Continue")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
} 