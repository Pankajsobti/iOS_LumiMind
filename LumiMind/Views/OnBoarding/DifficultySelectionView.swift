import SwiftUI

// MARK: - DifficultySelectionView
//
// Reused single-select mode of QuestionnaireView (step 8) rather than a
// bespoke picker. `submitOnboarding(goals:difficultyLevel:)` doesn't
// support a partial update — both fields are always sent together — so
// this screen resends the goals already stored on `currentUser` (set at
// signup, step 10) alongside the newly-picked `difficultyLevel`.
//
// LOCKED difficulty strings (defined here since the API contract left
// this open): "Beginner", "Intermediate", "Advanced". These are used
// as both the option IDs and the exact `difficultyLevel` value sent to
// `PATCH /users/onboarding` — no separate mapping table to drift out of
// sync.

struct DifficultySelectionView: View {
    @ObservedObject var authViewModel: AuthViewModel

    /// Advances to the Streak confirmation screen (backlog #14) once
    /// `submitOnboarding` succeeds.
    var onContinue: () -> Void

    @State private var selectedOptionIDs: Set<String> = []

    private static let difficultyQuestion = OnboardingQuestion(
        id: "difficultyLevel",
        prompt: "Pick your difficulty",
        subtitle: "You can change this anytime",
        options: [
            OnboardingOption(id: "Beginner", label: "Beginner"),
            OnboardingOption(id: "Intermediate", label: "Intermediate"),
            OnboardingOption(id: "Advanced", label: "Advanced")
        ],
        selectionLimit: .single
    )

    private var canContinue: Bool {
        !selectedOptionIDs.isEmpty && !authViewModel.isLoading
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        // QuestionnaireView (step 8) hardcodes cream text/pill
                        // colors designed to sit on DesignSystem.backgroundOnboarding
                        // (navy) — that's what every prior onboarding screen used.
                        // This screen's background is cream instead, so we house
                        // QuestionnaireView inside a navy card rather than modifying
                        // the shared component itself; this keeps it looking correct
                        // (and keeps QuestionnaireView reusable as-is elsewhere).
                        QuestionnaireView(
                            question: Self.difficultyQuestion,
                            selectedOptionIDs: $selectedOptionIDs
                        )
                        .padding(DesignSystem.Spacing.lg)
                        .background(DesignSystem.backgroundOnboarding)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))

                        if let errorMessage = authViewModel.errorMessage {
                            errorBanner(errorMessage)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.xl)
                }

                continueButton
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
    }

    // MARK: Error banner (matches Login/SignupView styling)

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

    // MARK: Continue CTA

    private var continueButton: some View {
        Button(action: handleContinue) {
            ZStack {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(DesignSystem.backgroundMain)
                } else {
                    Text("Continue")
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
        .disabled(!canContinue)
        .opacity(canContinue ? 1 : 0.5)
    }

    // MARK: Submit

    private func handleContinue() {
        guard let difficultyLevel = selectedOptionIDs.first else { return }
        let existingGoals = authViewModel.currentUser?.goals ?? []

        Task {
            await authViewModel.submitOnboarding(goals: existingGoals, difficultyLevel: difficultyLevel)
            if authViewModel.errorMessage == nil {
                onContinue()
            }
            // On failure, errorMessage is now set and displayed above —
            // the user stays on this screen with their selection intact
            // and can retry via the same Continue button.
        }
    }
}

// MARK: - Preview

#Preview {
    DifficultySelectionView(
        authViewModel: AuthViewModel(),
        onContinue: { print("Continue to Streak confirmation") }
    )
}