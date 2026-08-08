import SwiftUI

// MARK: - ComingSoonView
//
// Reusable placeholder screen for the 5 MVP games that don't have a
// real gameplay screen yet. Shown when a GamesLibraryView card is
// tapped for anything other than Memory Matrix. Swap the call site for
// the real game view as each one lands (backlog #19) — nothing else
// needs to change.

struct ComingSoonView: View {
    let gameName: String
    let category: GameCategory

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                Circle()
                    .fill(category.gradient)
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: "hourglass")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }

                Text(gameName)
                    .font(DesignSystem.title2)
                    .foregroundColor(DesignSystem.backgroundOnboarding)

                Text("Coming soon")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .navigationTitle(gameName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ComingSoonView(gameName: "Speed Match", category: .speed)
    }
}