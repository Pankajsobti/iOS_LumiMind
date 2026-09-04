//
//  SettingsView.swift
//  LumiMind
//
//  Presented as a sheet from HomeView's gear icon. Free app — no
//  subscription/payment section. Password update and account deletion
//  are left out of this pass since they need new backend endpoints
//  (authController has no matching routes yet).
//
//  Local-only settings (notifications, sound, background, theme) use
//  @AppStorage since no backend field exists for them.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("settings.backgroundMusicEnabled") private var backgroundMusicEnabled = true
    @AppStorage("settings.soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("settings.screenBackground") private var screenBackground = "system"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.backgroundMain.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        profileHeader
                        myInformationSection
                        notificationsSection
                        gameSettingsSection
                        supportSection
                        accountSection
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.backgroundOnboarding)
                }
            }
        }
    }

    // MARK: Profile header

    private var profileHeader: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle().fill(DesignSystem.primaryGradient).frame(width: 72, height: 72)
                Text(initials)
                    .font(DesignSystem.title2)
                    .foregroundColor(.white)
            }
            Text(authViewModel.currentUser?.fullName ?? "")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: "flame.fill").foregroundColor(DesignSystem.backgroundOnboarding)
                Text("\(authViewModel.currentUser?.streak ?? 0)-day streak")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    private var initials: String {
        let name = authViewModel.currentUser?.fullName ?? ""
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    // MARK: My information (read-only)

    private var myInformationSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("My Information")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            settingsCard {
                infoRow(label: "First name", value: authViewModel.currentUser?.fullName ?? "—")
                Divider()
                infoRow(label: "Email", value: authViewModel.currentUser?.email ?? "—")
                if let dob = authViewModel.currentUser?.dateOfBirth {
                    Divider()
                    infoRow(label: "Birthdate", value: Self.dateFormatter.string(from: dob))
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignSystem.body)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
            Spacer()
            Text(value)
                .font(DesignSystem.body)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Notifications")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            settingsCard {
                Toggle("Notifications", isOn: $notificationsEnabled)
                    .tint(DesignSystem.backgroundOnboarding)
            }
        }
    }

    // MARK: Game settings

    private var gameSettingsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Game Settings")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            settingsCard {
                Toggle("Background music", isOn: $backgroundMusicEnabled)
                    .tint(DesignSystem.backgroundOnboarding)
                Divider()
                Toggle("Sound effects", isOn: $soundEffectsEnabled)
                    .tint(DesignSystem.backgroundOnboarding)
                Divider()
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Screen Background")
                        .font(DesignSystem.body)
                        .foregroundColor(DesignSystem.backgroundOnboarding)

                    HStack(spacing: DesignSystem.Spacing.lg) {
                        backgroundOption(label: "Dark", value: "dark")
                        backgroundOption(label: "Light", value: "light")
                        backgroundOption(label: "System", value: "system")
                    }
                }
            }
        }
    }

    private func backgroundOption(label: String, value: String) -> some View {
        Button {
            screenBackground = value
        } label: {
            HStack(spacing: DesignSystem.Spacing.xxs) {
                Image(systemName: screenBackground == value ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(screenBackground == value ? DesignSystem.backgroundOnboarding : DesignSystem.backgroundOnboarding.opacity(0.3))
                Text(label)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Support / legal

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Support")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Link(destination: URL(string: "https://lumimind.app/help")!) {
                Text("Visit our helpdesk")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm + DesignSystem.Spacing.xxs)
            }
            .background(DesignSystem.attentionGradient)
            .clipShape(Capsule())

            settingsCard {
                legalLink(title: "Privacy Policy", url: "https://lumimind.app/privacy")
                Divider()
                legalLink(title: "Terms of Service", url: "https://lumimind.app/terms")
            }

            Text("App version 1.0.0")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func legalLink(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                    .font(DesignSystem.body)
                    .foregroundColor(DesignSystem.backgroundOnboarding)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.3))
            }
        }
    }

    // MARK: Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Account")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            settingsCard {
                Button(role: .destructive) {
                    authViewModel.logout()
                    dismiss()
                } label: {
                    HStack { Text("Log Out").font(DesignSystem.body); Spacer() }
                        .foregroundColor(.red)
                }
            }
        }
    }

    // MARK: Shared card container

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) { content() }
            .padding(DesignSystem.Spacing.md)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

#Preview {
    SettingsView(authViewModel: AuthViewModel())
}