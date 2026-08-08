import SwiftUI

// MARK: - QuestionnaireFlowView
//
// Sequences a list of `OnboardingQuestion`s through `QuestionnaireView`,
// one at a time, with Back/Continue navigation and a step indicator.
// Collects answers into local state ([question.id: Set<optionID>]) and
// hands the finished dictionary back via `onComplete` when the user
// finishes the last question.
//
// Deliberately stateless regarding networking: no `APIClient` or
// `AuthViewModel` calls happen here. Submitting the collected answers
// (e.g. via `AuthViewModel.submitOnboarding(goals:difficultyLevel:)`) is
// the responsibility of whatever screen owns `onComplete` — out of scope
// for this component per the build prompt.
//
// Background/text pairing matches WelcomeView (dark navy background,
// cream text) so the transition from "Get Started" feels continuous.

struct QuestionnaireFlowView: View {
    let questions: [OnboardingQuestion]

    /// Called once the user completes the final question, with the full
    /// set of answers keyed by `OnboardingQuestion.id`.
    let onComplete: ([String: Set<String>]) -> Void

    /// Optional: called if the user backs out of the very first question.
    var onCancel: (() -> Void)? = nil

    @State private var currentIndex: Int = 0
    @State private var answers: [String: Set<String>] = [:]

    init(
        questions: [OnboardingQuestion] = OnboardingQuestion.sampleOnboardingFlow,
        onComplete: @escaping ([String: Set<String>]) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.questions = questions
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    private var currentQuestion: OnboardingQuestion {
        questions[currentIndex]
    }

    private var isLastQuestion: Bool {
        currentIndex == questions.count - 1
    }

    private var currentSelectionBinding: Binding<Set<String>> {
        Binding(
            get: { answers[currentQuestion.id] ?? [] },
            set: { answers[currentQuestion.id] = $0 }
        )
    }

    private var canContinue: Bool {
        !(answers[currentQuestion.id] ?? []).isEmpty
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)

                QuestionnaireView(
                    question: currentQuestion,
                    selectedOptionIDs: currentSelectionBinding
                )
                .id(currentQuestion.id) // forces a clean transition between questions
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                Spacer()

                footerButtons
                    .padding(.bottom, DesignSystem.Spacing.sm)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    // MARK: Progress indicator

    private var progressDots: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(questions.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentIndex
                            ? AnyShapeStyle(DesignSystem.primaryGradient)
                            : AnyShapeStyle(DesignSystem.backgroundMain.opacity(0.25))
                    )
                    .frame(width: index == currentIndex ? 24 : 8, height: 8)
            }
        }
    }

    // MARK: Footer navigation

    private var footerButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: goNext) {
                Text(isLastQuestion ? "Finish" : "Continue")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(DesignSystem.backgroundMain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(DesignSystem.primaryGradient)
            .clipShape(Capsule())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)

            Button(action: goBack) {
                Text(currentIndex == 0 ? "Cancel" : "Back")
                    .font(DesignSystem.body)
                    .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                    .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Navigation logic

    private func goNext() {
        guard canContinue else { return }

        if isLastQuestion {
            onComplete(answers)
        } else {
            currentIndex += 1
        }
    }

    private func goBack() {
        if currentIndex == 0 {
            onCancel?()
        } else {
            currentIndex -= 1
        }
    }
}

// MARK: - Preview

#Preview {
    QuestionnaireFlowView(
        onComplete: { answers in
            print("Onboarding answers: \(answers)")
        },
        onCancel: {
            print("User cancelled onboarding questionnaire")
        }
    )
}