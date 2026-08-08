import SwiftUI

// MARK: - LoginView
//
// Reached from WelcomeView's "Log In" secondary action. Returning users
// skip onboarding entirely — on success this routes straight into the
// main app (the caller supplies `onLoginSuccess`, mirroring the
// closure-based pattern used by WelcomeView / QuestionnaireFlowView /
// SocialProofView; RootView owns the actual destination change).

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel

    /// Called once `authViewModel.isAuthenticated` flips true after a
    /// successful login. RootView is expected to route to `.main`.
    var onLoginSuccess: () -> Void

    /// Lets the user back out to WelcomeView.
    var onCancel: () -> Void

    @State private var email = ""
    @State private var password = ""

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && !password.isEmpty
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
        // Auth succeeded (isAuthenticated flips true inside AuthViewModel) —
        // hand control back to whoever owns navigation.
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                onLoginSuccess()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("Welcome back")
                .font(DesignSystem.title)
                .foregroundColor(DesignSystem.backgroundMain)

            Text("Log in to continue your training")
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
                textContentType: .password
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
        Button {
            Task { await authViewModel.login(email: email, password: password) }
        } label: {
            ZStack {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(DesignSystem.backgroundMain)
                } else {
                    Text("Log In")
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
        .disabled(!isFormValid || authViewModel.isLoading)
        .opacity((!isFormValid || authViewModel.isLoading) ? 0.5 : 1)
    }
}

// MARK: - Preview

#Preview {
    LoginView(
        authViewModel: AuthViewModel(),
        onLoginSuccess: { print("Logged in — route to main app") },
        onCancel: { print("Back to Welcome") }
    )
}