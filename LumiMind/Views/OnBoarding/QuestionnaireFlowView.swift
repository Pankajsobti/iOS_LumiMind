import SwiftUI

// MARK: - QuestionnaireFlowView
//
// Sequences a list of `OnboardingQuestion`s through `QuestionnaireView`,
// interleaved with `SocialProofView` interstitials at fixed points, one
// step at a time, with Back/Continue navigation and a step indicator
// (dots reflect question steps only — interstitials aren't counted).
// Collects answers into local state ([question.id: Set<optionID>]) and
// hands the finished dictionary back via `onComplete` when the user
// finishes the last step.
//
// Deliberately stateless regarding networking: no `APIClient` or
// `AuthViewModel` calls happen here. Submitting the collected answers
// is the responsibility of whatever screen owns `onComplete`.
//
// Background/text pairing matches WelcomeView (dark navy background,
// cream text) so the transition from "Get Started" feels continuous.

struct QuestionnaireFlowView: View {

    /// A single step in the flow — either a question or a no-input
    /// interstitial (`SocialProofView`).
    private enum FlowStep: Identifiable {
        case question(OnboardingQuestion)
        case interstitial(SocialProofView.Variant)

        var id: String {
            switch self {
            case .question(let q): return "question_\(q.id)"
            case .interstitial(let v): return "interstitial_\(v)"
            }
        }
    }

    @State private var steps: [FlowStep]

    /// Called once the user completes the final step, with the full
    /// set of answers keyed by `OnboardingQuestion.id`.
    let onComplete: ([String: Set<String>]) -> Void

    /// Optional: called if the user backs out of the very first step.
    var onCancel: (() -> Void)? = nil

    @State private var currentIndex: Int = 0
    @State private var answers: [String: Set<String>] = [:]

    init(
        questions: [OnboardingQuestion] = OnboardingQuestion.sampleOnboardingFlow,
        onComplete: @escaping ([String: Set<String>]) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        var initialSteps = questions.map { FlowStep.question($0) }
        if let goalsIndex = questions.firstIndex(where: { $0.id == "goals" }) {
            initialSteps.insert(.interstitial(.afterGoals), at: goalsIndex + 1)
        }
        _steps = State(initialValue: initialSteps)
        self.onComplete = onComplete
        self.onCancel = onCancel
    }

    private var currentStep: FlowStep {
        steps[currentIndex]
    }

    private var isLastStep: Bool {
        currentIndex == steps.count - 1
    }

    /// Indices of question-type steps only, for the progress dots.
    private var questionStepIndices: [Int] {
        steps.indices.filter {
            if case .question = steps[$0] { return true }
            return false
        }
    }

    private func selectionBinding(for question: OnboardingQuestion) -> Binding<Set<String>> {
        Binding(
            get: { answers[question.id] ?? [] },
            set: { answers[question.id] = $0 }
        )
    }

    private func canContinue(for question: OnboardingQuestion) -> Bool {
        !(answers[question.id] ?? []).isEmpty
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            switch currentStep {
            case .question(let question):
                VStack(spacing: 0) {
                    progressDots
                        .padding(.top, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.xl)

                    QuestionnaireView(
                        question: question,
                        selectedOptionIDs: selectionBinding(for: question)
                    )
                    .id(question.id) // forces a clean transition between questions
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                    Spacer()

                    footerButtons(for: question)
                        .padding(.bottom, DesignSystem.Spacing.sm)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

            case .interstitial(let variant):
                SocialProofView(variant: variant, onContinue: goNext)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    // MARK: Progress indicator

    private var progressDots: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(questionStepIndices, id: \.self) { index in
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

    // MARK: Footer navigation (question steps only)

    private func footerButtons(for question: OnboardingQuestion) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Button(action: goNext) {
                Text(isLastStep ? "Finish" : "Continue")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(DesignSystem.backgroundMain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(DesignSystem.primaryGradient)
            .clipShape(Capsule())
            .disabled(!canContinue(for: question))
            .opacity(canContinue(for: question) ? 1 : 0.5)

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
        if case .question(let question) = currentStep {
            guard canContinue(for: question) else { return }
            if question.id == "goals" {
                expandForSelectedGoals()
            }
        }

        if isLastStep {
            onComplete(answers)
        } else {
            currentIndex += 1
        }
    }

    /// Inserts one skill-focus question per category implied by the
    /// user's goal selections, right after the "afterGoals" interstitial,
    /// followed by the "afterCategories" interstitial. Removes any
    /// previously-inserted skill questions and that interstitial first,
    /// so going back and changing goals doesn't leave stale screens.
    private func expandForSelectedGoals() {
        let selectedGoalIDs = answers["goals"] ?? []
        let categories = SkillCategory.categories(forSelectedGoalIDs: selectedGoalIDs)
        let skillSteps = categories.map { FlowStep.question(OnboardingQuestion.skillFocusQuestion(for: $0)) }

        steps.removeAll {
            if case .question(let q) = $0, q.id.hasPrefix("skillFocus_") { return true }
            if case .interstitial(.afterCategories) = $0 { return true }
            return false
        }

        if let afterGoalsIndex = steps.firstIndex(where: {
            if case .interstitial(.afterGoals) = $0 { return true }
            return false
        }) {
            steps.insert(contentsOf: skillSteps, at: afterGoalsIndex + 1)
            steps.insert(.interstitial(.afterCategories), at: afterGoalsIndex + 1 + skillSteps.count)
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