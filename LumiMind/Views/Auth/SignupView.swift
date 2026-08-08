import SwiftUI

// MARK: - SignupView
//
// Reached from SocialProofView's "Continue" CTA. Unlike LoginView, a
// successful signup here also submits the onboarding answers collected
// earlier in QuestionnaireFlowView, then proceeds to the Fit Test intro
// (backlog #11) — new users go through onboarding once; returning users
// (LoginView) skip straight to the main app.
//
// This view does NOT know about QuestionnaireFlowView's raw
// `[String: Set<String>]` answer dictionary or its placeholder question
// IDs — that mapping is the caller's responsibility (RootView, once
// wired up), so this component stays reusable even if question IDs
// change later (e.g. backlog #13 difficulty selection). It only needs
// the two already-resolved values `submitOnboarding` expects.

struct SignupView: View {
    @ObservedObject var authViewModel: AuthViewModel

    /// Pre-extracted from the onboarding questionnaire answers by the
    /// caller. Passed straight through to `submitOnboarding` after
    /// signup succeeds.
    let goals: [String]
    let difficultyLevel: String

    /// Called once signup AND the onboarding submission have both
    /// completed. RootView is expected to route to the Fit Test intro.
    var onSignupComplete: () -> Void

    /// Lets the user back out to SocialProofView / questionnaire.
    var onCancel: () -> Void

    @State private var email = ""
    @State private var password = ""

    /// True once signup succeeded and we're submitting onboarding
    /// answers — kept distinct from `authViewModel.isLoading` so the
    /// button shows a spinner through both network calls, not just
    /// the first.
    @State private var isSubmittingOnboarding = false

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && !password.isEmpty
    }

    private var isBusy: Bool {
        authViewModel.isLoading || isSubmittingOnboarding
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, DesignSystem.Spacing.xxl)
                    .padding(.bottom, DesignSystem.Spacing.xl)

                fields

                if let errorMessage = authViewModel.errorMessage {
                    errorBanner(errorMessage)
                        .padding(.top, DesignSystem.Spacing.md)
                }

                Spacer()

                submitButton
                    .padding(.bottom, DesignSystem.Spacing.sm)

                Button(action: onCancel) {
                    Text("Back")
                        .font(DesignSystem.body)
                        .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                        .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .buttonStyle(.plain)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("Create your account")
                .font(DesignSystem.title)
                .foregroundColor(DesignSystem.backgroundMain)

            Text("Save your progress and pick up anywhere")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            AuthTextField(
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )
            AuthTextField(
                placeholder: "Password",
                text: $password,
                isSecure: true,
                textContentType: .newPassword
            )
        }
    }

    // MARK: Error banner

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(DesignSystem.subheadline)
            .foregroundColor(Color(hex: "#FF6B4A"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "#FF6B4A").opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }

    // MARK: Submit

    private var submitButton: some View {
        Button(action: handleSignup) {
            ZStack {
                if isBusy {
                    ProgressView()
                        .tint(DesignSystem.backgroundMain)
                } else {
                    Text("Sign Up")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(DesignSystem.backgroundMain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.primaryGradient)
        .clipShape(Capsule())
        .disabled(!isFormValid || isBusy)
        .opacity((!isFormValid || isBusy) ? 0.5 : 1)
    }

    // MARK: Signup + onboarding submission

    private func handleSignup() {
        Task {
            await authViewModel.signup(email: email, password: password)

            // Only proceed to submit onboarding answers if signup actually
            // succeeded (e.g. not a 409 duplicate-email failure).
            guard authViewModel.isAuthenticated else { return }

            isSubmittingOnboarding = true
            await authViewModel.submitOnboarding(goals: goals, difficultyLevel: difficultyLevel)
            isSubmittingOnboarding = false

            // submitOnboarding surfaces its own failure via errorMessage;
            // only advance if it didn't set one.
            if authViewModel.errorMessage == nil {
                onSignupComplete()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SignupView(
        authViewModel: AuthViewModel(),
        goals: ["focus", "memory"],
        difficultyLevel: "10min",
        onSignupComplete: { print("Signup + onboarding complete — route to Fit Test intro") },
        onCancel: { print("Back to SocialProof") }
    )
}