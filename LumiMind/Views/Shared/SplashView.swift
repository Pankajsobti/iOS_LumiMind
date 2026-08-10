//
//  SplashView.swift
//  LumiMind
//
//  First screen shown on cold start. Purely visual/transitional — no
//  buttons, no user interaction. On appear it checks Keychain (via
//  AuthViewModel.fetchCurrentUser()) for an existing session, then
//  calls `onFinished` once both a minimum display duration AND the
//  session check have settled, so the parent (RootView) can route to
//  onboarding or the main app.
//

import SwiftUI

struct SplashView: View {
    @ObservedObject var authViewModel: AuthViewModel

    /// Called exactly once, after the session check resolves (success,
    /// failure, or timeout) and the minimum display duration has passed.
    var onFinished: () -> Void

    /// Keeps the splash from flashing on fast networks.
    private let minimumDisplayDuration: Double = 0.75

    /// Hard ceiling on how long we wait for the network check, so a
    /// hung request can never leave this screen stuck. If this fires
    /// first, we still route using whatever `isAuthenticated` currently
    /// is — which AuthViewModel seeds from Keychain token presence at
    /// init, so this degrades gracefully rather than defaulting to
    /// "logged out" unfairly.
    private let maxSessionCheckDuration: Double = 5.0

    /// Drives the entrance animation only — has no effect on
    /// `runSessionCheck` timing below.
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            DesignSystem.memoryGradient
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                SplashLogoMark()
                    .frame(width: 100, height: 100)

                Text("LumiMind")
                    .font(DesignSystem.roundedFont(size: 32, weight: .bold))
                    .foregroundColor(DesignSystem.backgroundMain)
            }
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                hasAppeared = true
            }
        }
        .task {
            await runSessionCheck()
        }
    }

    private func runSessionCheck() async {
        async let minimumDelay: Void = sleep(minimumDisplayDuration)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await authViewModel.fetchCurrentUser() }
            group.addTask { await sleep(maxSessionCheckDuration) }
            await group.next()
            group.cancelAll()
        }

        await minimumDelay

        await MainActor.run {
            onFinished()
        }
    }

    /// Non-throwing sleep helper — swallows `CancellationError` so a
    /// cancelled timer never propagates as a crash or unhandled error.
    private func sleep(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

/// The connected-node mark from the app icon, redrawn in code so it
/// scales and matches `DesignSystem` tokens exactly — no image asset.
private struct SplashLogoMark: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let top    = CGPoint(x: w * 0.5,  y: h * 0.28)
            let left   = CGPoint(x: w * 0.30, y: h * 0.56)
            let right  = CGPoint(x: w * 0.70, y: h * 0.56)
            let bottom = CGPoint(x: w * 0.5,  y: h * 0.68)

            ZStack {
                Path { path in
                    path.move(to: top)
                    path.addLine(to: left)
                    path.move(to: top)
                    path.addLine(to: right)
                    path.move(to: left)
                    path.addLine(to: right)
                }
                .stroke(
                    DesignSystem.backgroundMain.opacity(0.55),
                    style: StrokeStyle(lineWidth: w * 0.06, lineCap: .round)
                )

                node(at: top, size: w * 0.20, opacity: 1.0)
                node(at: left, size: w * 0.19, opacity: 0.95)
                node(at: right, size: w * 0.19, opacity: 0.85)
                node(at: bottom, size: w * 0.15, opacity: 0.65)
            }
        }
    }

    private func node(at point: CGPoint, size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(DesignSystem.backgroundMain.opacity(opacity))
            .frame(width: size, height: size)
            .position(point)
    }
}

#Preview {
    SplashView(authViewModel: AuthViewModel(), onFinished: {})
}