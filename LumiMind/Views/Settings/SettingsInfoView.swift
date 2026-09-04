//
//  SettingsInfoView.swift
//  LumiMind
//
//  Generic in-app content screen used for Privacy Policy, Terms of
//  Service, and Helpdesk/Contact — until real hosted pages exist.
//  Swap `body` text for the real legal copy later; navigation and
//  styling stay the same.
//

import SwiftUI

struct SettingsInfoView: View {
    let title: String
    let body: String

    var body_: some View {
        ScrollView {
            Text(body)
                .font(DesignSystem.body)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.8))
                .padding(DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.backgroundMain.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // var body: some View { body_ }
}

// MARK: - Helpdesk (contact, not just static text)

struct HelpdeskView: View {
    private let supportEmail = "support@lumimind.app"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Need help?")
                    .font(DesignSystem.title2)
                    .foregroundColor(DesignSystem.backgroundOnboarding)

                Text("Reach out and we'll get back to you as soon as we can.")
                    .font(DesignSystem.body)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))

                Link(destination: URL(string: "mailto:\(supportEmail)")!) {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text(supportEmail)
                    }
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm + DesignSystem.Spacing.xxs)
                }
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.backgroundMain.ignoresSafeArea())
        .navigationTitle("Helpdesk")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Placeholder legal copy

enum SettingsLegalContent {
    static let privacyPolicy = """
    Privacy Policy

    Last updated: September 2026

    LumiMind ("we", "our", "the app") respects your privacy. This policy explains what information we collect and how we use it.

    Information We Collect
    • Account information: your name, email address, and date of birth when you sign up.
    • Game activity: your scores, streaks, and progress across brain-training games.
    • Device information: basic technical data (device type, OS version) used for app functionality and crash diagnostics.

    How We Use Your Information
    • To create and manage your account.
    • To track your progress, streaks, and personalize your daily games.
    • To improve app performance and fix bugs.

    We do not sell your personal information to third parties.

    Data Storage
    Your data is stored securely on our servers. Passwords are never stored in plain text.

    Your Choices
    You can update your information from the Settings screen at any time. To request deletion of your account and associated data, contact us at support@lumimind.app.

    Children's Privacy
    LumiMind is not directed at children under 13, and we do not knowingly collect data from children under 13.

    Changes to This Policy
    We may update this policy from time to time. Continued use of the app after changes means you accept the updated policy.

    Contact
    Questions about this policy? Email support@lumimind.app.
    """

    static let termsOfService = """
    Terms of Service

    Last updated: September 2026

    By creating an account and using LumiMind, you agree to these terms.

    Your Account
    You're responsible for keeping your login credentials secure. You must provide accurate information when signing up, including a valid email and birthdate.

    Acceptable Use
    You agree not to:
    • Use the app for any unlawful purpose.
    • Attempt to reverse-engineer, hack, or disrupt the app or its backend.
    • Share your account with others.

    Content and Intellectual Property
    All games, designs, graphics, and content within LumiMind are owned by us or our licensors. You may not copy, distribute, or create derivative works from app content without permission.

    No Medical Advice
    LumiMind is designed for casual cognitive training and entertainment. It is not a medical device and does not diagnose, treat, or cure any condition. Consult a qualified professional for medical concerns.

    Termination
    We may suspend or terminate accounts that violate these terms. You may delete your account at any time by contacting support@lumimind.app.

    Limitation of Liability
    LumiMind is provided "as is" without warranties of any kind. We are not liable for any indirect or consequential damages arising from your use of the app.

    Changes to These Terms
    We may update these terms periodically. Continued use of the app after changes means you accept the updated terms.

    Contact
    Questions about these terms? Email support@lumimind.app.
    """
}