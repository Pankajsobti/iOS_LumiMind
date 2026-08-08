import SwiftUI

// MARK: - AuthTextField
//
// Single reusable, styled input used by both LoginView and SignupView
// so field styling (fill, radius, font) lives in one place instead of
// being duplicated per screen. Purely presentational — owns no
// networking or validation logic; the parent screen supplies the
// binding and decides what's valid.

struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: placeholderText)
                    .textContentType(textContentType)
            } else {
                TextField("", text: $text, prompt: placeholderText)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled(true)
            }
        }
        .font(DesignSystem.body)
        .foregroundColor(DesignSystem.backgroundOnboarding)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + DesignSystem.Spacing.xxs)
        .background(DesignSystem.backgroundMain)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }

    private var placeholderText: Text {
        Text(placeholder)
            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.4))
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var email = ""
        @State private var password = ""

        var body: some View {
            ZStack {
                DesignSystem.backgroundOnboarding.ignoresSafeArea()
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
                .padding(DesignSystem.Spacing.lg)
            }
        }
    }

    return PreviewWrapper()
}