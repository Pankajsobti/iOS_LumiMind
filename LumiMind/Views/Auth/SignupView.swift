import SwiftUI

// MARK: - SignupView

struct SignupView: View {
    @ObservedObject var authViewModel: AuthViewModel

    let goals: [String]
    let difficultyLevel: String

    var onSignupComplete: () -> Void
    var onCancel: () -> Void

    // Required
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreedToTerms = false
    @State private var agreedToPrivacy = false

    // Optional
    @State private var username = ""
    @State private var dateOfBirth = Date()
    @State private var includeDateOfBirth = false
    @State private var country = ""
    @State private var marketingConsent = false

    @State private var isSubmittingOnboarding = false

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        && !email.isEmpty && email.contains("@")
        && !password.isEmpty
        && password == confirmPassword
        && agreedToTerms
        && agreedToPrivacy
    }

    private var isBusy: Bool {
        authViewModel.isLoading || isSubmittingOnboarding
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, DesignSystem.Spacing.xxl)
                        .padding(.bottom, DesignSystem.Spacing.xl)

                    requiredFields
                    optionalFields
                        .padding(.top, DesignSystem.Spacing.lg)

                    if let errorMessage = authViewModel.errorMessage {
                        errorBanner(errorMessage)
                            .padding(.top, DesignSystem.Spacing.md)
                    }

                    submitButton
                        .padding(.top, DesignSystem.Spacing.xl)
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

    // MARK: Required fields

    private var requiredFields: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            AuthTextField(
                placeholder: "Full Name",
                text: $fullName,
                textContentType: .name
            )
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
            AuthTextField(
                placeholder: "Confirm Password",
                text: $confirmPassword,
                isSecure: true,
                textContentType: .newPassword
            )

            if !confirmPassword.isEmpty && password != confirmPassword {
                Text("Passwords don't match")
                    .font(DesignSystem.caption)
                    .foregroundColor(Color(hex: "#FF6B4A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            consentToggle(
                isOn: $agreedToTerms,
                label: "I agree to the Terms of Service"
            )
            consentToggle(
                isOn: $agreedToPrivacy,
                label: "I agree to the Privacy Policy"
            )
        }
    }

    // MARK: Optional fields

    private var optionalFields: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Optional")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundMain.opacity(0.5))

            AuthTextField(
                placeholder: "Username",
                text: $username,
                textContentType: .username
            )

            Toggle(isOn: $includeDateOfBirth) {
                Text("Add Date of Birth")
                    .font(DesignSystem.body)
                    .foregroundColor(DesignSystem.backgroundMain)
            }
            .tint(Color(hex: "#6D5DE7"))

            if includeDateOfBirth {
                DatePicker(
                    "Date of Birth",
                    selection: $dateOfBirth,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(.dark)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            AuthTextField(
                placeholder: "Country / Region",
                text: $country,
                textContentType: .countryName
            )

            consentToggle(
                isOn: $marketingConsent,
                label: "Send me tips, updates, and offers"
            )
        }
    }

    private func consentToggle(isOn: Binding<Bool>, label: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Button(action: { isOn.wrappedValue.toggle() }) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundStyle(
                        isOn.wrappedValue
                            ? AnyShapeStyle(DesignSystem.primaryGradient)
                            : AnyShapeStyle(DesignSystem.backgroundMain.opacity(0.4))
                    )
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)

            Text(label)
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundMain.opacity(0.85))

            Spacer()
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
            await authViewModel.signup(
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                email: email,
                password: password,
                username: username.isEmpty ? nil : username,
                dateOfBirth: includeDateOfBirth ? dateOfBirth : nil,
                country: country.isEmpty ? nil : country,
                marketingConsent: marketingConsent
            )

            guard authViewModel.isAuthenticated else { return }

            isSubmittingOnboarding = true
            await authViewModel.submitOnboarding(goals: goals, difficultyLevel: difficultyLevel)
            isSubmittingOnboarding = false

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
        onSignupComplete: { print("Signup + onboarding complete") },
        onCancel: { print("Back to SocialProof") }
    )
}