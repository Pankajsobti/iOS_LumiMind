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
    let optionStyle: OptionDisplayStyle

    init(
        id: String,
        prompt: String,
        subtitle: String? = nil,
        options: [OnboardingOption],
        selectionLimit: SelectionLimit = .multiple(max: nil),
        optionStyle: OptionDisplayStyle = .pill
    ) {
        self.id = id
        self.prompt = prompt
        self.subtitle = subtitle
        self.options = options
        self.selectionLimit = selectionLimit
        self.optionStyle = optionStyle
    }
}

// MARK: - OptionDisplayStyle

enum OptionDisplayStyle: Equatable {
    case pill
    case card
}

// MARK: - OnboardingOption

struct OnboardingOption: Identifiable, Equatable, Hashable {
    let id: String
    let label: String
    let description: String?

    init(id: String, label: String, description: String? = nil) {
        self.id = id
        self.label = label
        self.description = description
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
    static func skillFocusQuestion(for category: SkillCategory) -> OnboardingQuestion {
        OnboardingQuestion(
            id: "skillFocus_\(category.rawValue)",
            prompt: category.displayName,
            subtitle: category.subhead,
            options: category.options,
            selectionLimit: .multiple(max: nil),
            optionStyle: .card
        )
    }
}

enum SkillCategory: String, CaseIterable, Identifiable {
    case memory
    case attention
    case reasoning
    case flexibility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .memory: return "Memory"
        case .attention: return "Attention"
        case .reasoning: return "Reasoning"
        case .flexibility: return "Flexibility"
        }
    }

    var subhead: String {
        switch self {
        case .memory: return "Which part of your memory do you want to train?"
        case .attention: return "Which part of your attention do you want to train?"
        case .reasoning: return "Which part of your reasoning do you want to train?"
        case .flexibility: return "Which part of your flexibility do you want to train?"
        }
    }

    var options: [OnboardingOption] {
        switch self {
        case .memory:
            return [
                OnboardingOption(id: "workingMemory", label: "Working Memory", description: "Hold information in mind while you use it"),
                OnboardingOption(id: "recallSpeed", label: "Recall Speed", description: "Retrieve what you've learned, faster"),
                OnboardingOption(id: "patternMemory", label: "Pattern Memory", description: "Remember layouts and sequences"),
                OnboardingOption(id: "recognition", label: "Recognition", description: "Remember faces, names, and details")
            ]
        case .attention:
            return [
                OnboardingOption(id: "focusFiltering", label: "Focus Filtering", description: "Tune out distractions"),
                OnboardingOption(id: "multitasking", label: "Multitasking", description: "Track more than one thing at once"),
                OnboardingOption(id: "glanceAwareness", label: "Glance Awareness", description: "Take in a scene quickly"),
                OnboardingOption(id: "sustainedFocus", label: "Sustained Focus", description: "Stay locked in over time")
            ]
        case .reasoning:
            return [
                OnboardingOption(id: "logicalThinking", label: "Logical Thinking", description: "Work through problems step by step"),
                OnboardingOption(id: "planningAhead", label: "Planning Ahead", description: "Map out moves before acting"),
                OnboardingOption(id: "spatialReasoning", label: "Spatial Reasoning", description: "Picture how things fit and move"),
                OnboardingOption(id: "numberSense", label: "Number Sense", description: "Work confidently with numbers")
            ]
        case .flexibility:
            return [
                OnboardingOption(id: "taskSwitching", label: "Task Switching", description: "Move between tasks smoothly"),
                OnboardingOption(id: "impulseControl", label: "Impulse Control", description: "Pause before reacting"),
                OnboardingOption(id: "wordRecall", label: "Word Recall", description: "Pull the right word when you need it"),
                OnboardingOption(id: "patternGeneration", label: "Pattern Generation", description: "Come up with new combinations quickly")
            ]
        }
    }
}

extension SkillCategory {
    /// Maps the user's selected goal option IDs (from the "goals"
    /// question) to the skill categories they should see a follow-up
    /// screen for. "Just exploring" is exclusive — if present, skips
    /// all skill-focus screens regardless of other selections.
    static func categories(forSelectedGoalIDs goalIDs: Set<String>) -> [SkillCategory] {
        if goalIDs.contains("exploring") {
            return []
        }

        var result: Set<SkillCategory> = []
        for goalID in goalIDs {
            switch goalID {
            case "sharpenThinking":
                result.formUnion([.memory, .attention, .reasoning, .flexibility])
            case "strengthenMemory":
                result.insert(.memory)
            case "reasonBetter":
                result.insert(.reasoning)
            case "reactFaster":
                result.formUnion([.attention, .flexibility])
            case "stayActive":
                result.formUnion([.memory, .attention])
            default:
                break
            }
        }

        // Fixed display order, regardless of insertion order.
        let orderedAll: [SkillCategory] = [.memory, .attention, .reasoning, .flexibility]
        return orderedAll.filter { result.contains($0) }
    }
}

extension OnboardingQuestion {
    static let sampleOnboardingFlow: [OnboardingQuestion] = [
        OnboardingQuestion(
            id: "goals",
            prompt: "What brings you to LumiMind?",
            subtitle: "Select everything that applies.",
            options: [
                OnboardingOption(id: "sharpenThinking", label: "Sharpen my thinking overall"),
                OnboardingOption(id: "strengthenMemory", label: "Strengthen my memory"),
                OnboardingOption(id: "reasonBetter", label: "Improve how I reason through problems"),
                OnboardingOption(id: "reactFaster", label: "React and think faster"),
                OnboardingOption(id: "stayActive", label: "Stay mentally active day to day"),
                OnboardingOption(id: "exploring", label: "Just exploring")
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
        ),
        OnboardingQuestion(
            id: "gender",
            prompt: "How should we refer to you?",
            subtitle: "This helps us tailor comparisons to people like you.",
            options: [
                OnboardingOption(id: "male", label: "Male"),
                OnboardingOption(id: "female", label: "Female"),
                OnboardingOption(id: "nonBinary", label: "Non-binary"),
                OnboardingOption(id: "preferNotToSay", label: "Prefer not to say")
            ],
            selectionLimit: .single
        ),
        OnboardingQuestion(
            id: "education",
            prompt: "What's your education background?",
            subtitle: nil,
            options: [
                OnboardingOption(id: "someHighSchool", label: "Some high school"),
                OnboardingOption(id: "highSchool", label: "High school"),
                OnboardingOption(id: "someCollege", label: "Some college"),
                OnboardingOption(id: "associateDegree", label: "Associate degree"),
                OnboardingOption(id: "collegeDegree", label: "College degree"),
                OnboardingOption(id: "mastersDegree", label: "Master's degree"),
                OnboardingOption(id: "professionalDegree", label: "Professional degree"),
                OnboardingOption(id: "phd", label: "PhD")
            ],
            selectionLimit: .single,
            optionStyle: .card
        ),
        OnboardingQuestion(
            id: "referralSource",
            prompt: "How did you find LumiMind?",
            subtitle: nil,
            options: [
                OnboardingOption(id: "doctor", label: "Doctor or healthcare provider"),
                OnboardingOption(id: "friendFamily", label: "Friend or family"),
                OnboardingOption(id: "appStore", label: "App Store"),
                OnboardingOption(id: "playStore", label: "Play Store"),
                OnboardingOption(id: "socialMedia", label: "Social media"),
                OnboardingOption(id: "search", label: "Search"),
                OnboardingOption(id: "other", label: "Other")
            ],
            selectionLimit: .single
        )
    ]
}