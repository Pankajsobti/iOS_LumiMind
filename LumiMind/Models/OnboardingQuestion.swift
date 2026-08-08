import Foundation

// MARK: - OnboardingQuestion
//
// Local, view-layer-only data model describing a single onboarding
// question. This is NOT an API model — it exists purely to drive the
// generic `QuestionnaireView` / `QuestionnaireFlowView` components.
//
// Keeping this separate from `APIModels.swift` means the questionnaire
// UI can be restyled, reordered, or extended (e.g. difficulty selection
// in backlog item #13) without ever touching networking code, and
// without any question-specific text living inside the view files.

struct OnboardingQuestion: Identifiable, Equatable {
    let id: String
    let prompt: String
    let subtitle: String?
    let options: [OnboardingOption]
    let selectionLimit: SelectionLimit

    init(
        id: String,
        prompt: String,
        subtitle: String? = nil,
        options: [OnboardingOption],
        selectionLimit: SelectionLimit = .multiple(max: nil)
    ) {
        self.id = id
        self.prompt = prompt
        self.subtitle = subtitle
        self.options = options
        self.selectionLimit = selectionLimit
    }
}

// MARK: - OnboardingOption

struct OnboardingOption: Identifiable, Equatable, Hashable {
    let id: String
    let label: String

    init(id: String, label: String) {
        self.id = id
        self.label = label
    }
}

// MARK: - SelectionLimit
//
// Governs how many options a user may pick for a given question.
// `.single` is used for things like difficulty level; `.multiple` is
// used for things like goals, optionally capped at a max count.

enum SelectionLimit: Equatable {
    case single
    case multiple(max: Int?)

    var isSingleSelect: Bool {
        if case .single = self { return true }
        return false
    }

    /// nil means "no cap" for multi-select.
    var maxSelections: Int? {
        switch self {
        case .single:
            return 1
        case .multiple(let max):
            return max
        }
    }
}

// MARK: - Sample data
//
// Placeholder content for QuestionnaireFlowView's default preview flow.
// Real question sets (goals, attention type, difficulty, etc.) should be
// constructed the same way — as plain `OnboardingQuestion` values — and
// passed in from wherever the flow is presented. Nothing below is
// referenced by the view files' rendering logic; it's sample data only.

extension OnboardingQuestion {
    static let sampleOnboardingFlow: [OnboardingQuestion] = [
        OnboardingQuestion(
            id: "goals",
            prompt: "What brings you to LumiMind?",
            subtitle: "Select all that apply",
            options: [
                OnboardingOption(id: "focus", label: "Improve focus"),
                OnboardingOption(id: "memory", label: "Sharpen memory"),
                OnboardingOption(id: "stress", label: "Reduce stress"),
                OnboardingOption(id: "habit", label: "Build a daily habit"),
                OnboardingOption(id: "fun", label: "Just for fun")
            ],
            selectionLimit: .multiple(max: nil)
        ),
        OnboardingQuestion(
            id: "commitment",
            prompt: "How much time can you commit daily?",
            subtitle: nil,
            options: [
                OnboardingOption(id: "5min", label: "5 minutes"),
                OnboardingOption(id: "10min", label: "10 minutes"),
                OnboardingOption(id: "20min", label: "20+ minutes")
            ],
            selectionLimit: .single
        ),
        OnboardingQuestion(
            id: "attentionType",
            prompt: "What's your attention type?",
            subtitle: "Pick the one that fits best",
            options: [
                OnboardingOption(id: "visual", label: "Visual"),
                OnboardingOption(id: "auditory", label: "Auditory"),
                OnboardingOption(id: "kinesthetic", label: "Hands-on")
            ],
            selectionLimit: .single
        )
    ]
}