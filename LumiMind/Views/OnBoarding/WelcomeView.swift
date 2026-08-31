//
//  WelcomeView.swift
//  LumiMind
//
//  Shown after SplashView resolves to "not authenticated." Purely
//  navigational — no backend calls. Re-skinned from a Lumosity-style
//  reference (icon collage → wordmark → headline → CTA → login link →
//  legal footer) using LumiMind's locked DesignSystem tokens.
//
//  NOTE: Top mark uses a placeholder SF Symbol styled with DesignSystem
//  tokens. Swap for `Image("AppIcon")` (or your actual asset name) once
//  the icon is added to Assets.xcassets — see TODO below.
//

import SwiftUI

struct WelcomeView: View {
    /// Advances toward the onboarding questionnaire (build prompt #8).
    var onGetStarted: () -> Void

    /// Routes to the existing login flow. Optional so this view still
    /// compiles/previews if a caller doesn't wire it (defaults to a no-op).
    var onLogin: () -> Void = {}

    @State private var collageVisible = false

    // TODO: replace these with your real Terms/Privacy URLs.
    private let termsURL = URL(string: "https://lumimind.app/terms")!
    private let privacyURL = URL(string: "https://lumimind.app/privacy")!

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                iconCollage
                    .frame(height: 170)
                    .opacity(collageVisible ? 1 : 0)
                    .offset(y: collageVisible ? 0 : 16)
                    .onAppear {
                        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                            collageVisible = true
                        }
                    }

                Spacer(minLength: DesignSystem.Spacing.lg)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    // TODO: replace with Image("AppIcon") once added to Assets.xcassets
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(DesignSystem.primaryGradient)

                    Text("LumiMind")
                        .font(DesignSystem.title2)
                        .foregroundColor(DesignSystem.backgroundMain)
                }

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Discover\nwhat your mind\ncan do")
                        .font(DesignSystem.largeTitle)
                        .multilineTextAlignment(.center)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .padding(.top, DesignSystem.Spacing.lg)

                    Text("Sign up to train your brain for free.")
                        .font(DesignSystem.body)
                        .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                }
                .padding(.top, DesignSystem.Spacing.md)

                Spacer()

                VStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: onGetStarted) {
                        Text("Get started")
                            .font(DesignSystem.buttonLabel)
                            .foregroundColor(DesignSystem.backgroundMain)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                    }
                    .background(DesignSystem.primaryGradient)
                    .clipShape(Capsule())

                    Button(action: onLogin) {
                        Text("Already have an account?")
                            .font(DesignSystem.subheadline)
                            .foregroundColor(Color(hex: "#A19AFE"))
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                legalFooter
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Icon Collage

    private var iconCollage: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#6D5DE7").opacity(0.35), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 220
            )

            ForEach(collageIcons) { icon in
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact / 2)
                    .fill(icon.gradient)
                    .frame(width: icon.size, height: icon.size)
                    .overlay(
                        Image(systemName: icon.symbol)
                            .font(.system(size: icon.size * 0.42, weight: .semibold))
                            .foregroundColor(DesignSystem.backgroundMain)
                    )
                    .rotationEffect(.degrees(icon.rotation))
                    .offset(x: icon.xOffset, y: icon.yOffset)
            }
        }
        .frame(maxWidth: .infinity)
        .mask(
            LinearGradient(
                colors: [.black, .black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// Symbols are grouped by GameCategory so the collage previews what's
    /// actually inside the app (Speed, Memory, Attention, Flexibility,
    /// Problem Solving, Math) rather than generic decoration.
    /// TODO: once real per-game icon assets exist, swap these SF Symbols
    /// for e.g. Image("icon_speedMatch"), Image("icon_memoryMatrix") etc.
    /// for a much stronger brand tie-in.
    private var collageIcons: [CollageIcon] {
        [
            CollageIcon(symbol: "bolt.fill", gradient: DesignSystem.speedGradient, size: 52, xOffset: -120, yOffset: -20, rotation: -6),
            CollageIcon(symbol: "brain.head.profile", gradient: DesignSystem.memoryGradient, size: 60, xOffset: -40, yOffset: -40, rotation: 4),
            CollageIcon(symbol: "eye.fill", gradient: DesignSystem.attentionGradient, size: 48, xOffset: 40, yOffset: -15, rotation: -3),
            CollageIcon(symbol: "arrow.triangle.2.circlepath", gradient: DesignSystem.flexibilityGradient, size: 56, xOffset: 120, yOffset: -35, rotation: 7),
            CollageIcon(symbol: "puzzlepiece.fill", gradient: DesignSystem.problemSolvingGradient, size: 50, xOffset: -80, yOffset: 40, rotation: 5),
            CollageIcon(symbol: "function", gradient: DesignSystem.mathGradient, size: 46, xOffset: 0, yOffset: 55, rotation: -5),
            CollageIcon(symbol: "sparkles", gradient: DesignSystem.speedGradient, size: 40, xOffset: 90, yOffset: 45, rotation: 8),
            CollageIcon(symbol: "chart.line.uptrend.xyaxis", gradient: DesignSystem.memoryGradient, size: 42, xOffset: -140, yOffset: 60, rotation: -8),
        ]
    }

    private struct CollageIcon: Identifiable {
        let id = UUID()
        let symbol: String
        let gradient: LinearGradient
        let size: CGFloat
        let xOffset: CGFloat
        let yOffset: CGFloat
        let rotation: Double
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text("By signing up, you agree to our")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundMain.opacity(0.5))

            HStack(spacing: 4) {
                Link("Terms of Service", destination: termsURL)
                Text(",")
                Link("Privacy Policy", destination: privacyURL)
                Text(".")
            }
            .font(DesignSystem.caption)
            .foregroundColor(DesignSystem.backgroundMain.opacity(0.6))
            .underline()
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    WelcomeView(onGetStarted: {}, onLogin: {})
}