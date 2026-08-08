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

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("LumiMind")
                    .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                    .foregroundColor(DesignSystem.backgroundMain)

                Rectangle()
                    .fill(DesignSystem.primaryGradient)
                    .frame(width: 48, height: 4)
                    .clipShape(Capsule())

                ProgressView()
                    .padding(.top, DesignSystem.Spacing.sm)
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

#Preview {
    SplashView(authViewModel: AuthViewModel(), onFinished: {})
}