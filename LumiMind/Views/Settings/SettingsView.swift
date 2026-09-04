import SwiftUI

// MARK: - SettingsView
// Presented as a sheet from HomeView's gear icon. Free app — no
// paywall gating. Notification/Sound toggles are local-only
// (@AppStorage) since no backend field exists for them yet.

struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("settings.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("settings.soundEnabled") private var soundEnabled = true

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.backgroundMain.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        profileHeader
                        preferencesSection
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

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Preferences").font(DesignSystem.headline).foregroundColor(DesignSystem.backgroundOnboarding)
            settingsCard {
                Toggle("Notifications", isOn: $notificationsEnabled).tint(DesignSystem.backgroundOnboarding)
                Divider()
                Toggle("Sound", isOn: $soundEnabled).tint(DesignSystem.backgroundOnboarding)
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Account").font(DesignSystem.headline).foregroundColor(DesignSystem.backgroundOnboarding)
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