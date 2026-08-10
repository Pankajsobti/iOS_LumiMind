import SwiftUI
import UIKit

// MARK: - QuestionnaireView
//
// A single, fully reusable questionnaire screen. It renders whatever
// `OnboardingQuestion` it's given — prompt, optional subtitle, and a
// pill-shaped grid of options — and reports selection changes back
// through a `@Binding`. It has ZERO knowledge of "goals" vs "difficulty"
// vs "attention type"; all of that text lives in the `OnboardingQuestion`
// passed in, never here.
//
// Networking: none. This view only reads/writes the binding it's given.
//
// All styling below uses ONLY tokens that exist in the real
// DesignSystem.swift (backgroundOnboarding, backgroundMain,
// primaryGradient, roundedFont/semantic text styles, Spacing, Radius) —
// no invented color/font names.

struct QuestionnaireView: View {
    let question: OnboardingQuestion

    /// The set of currently-selected `OnboardingOption.id`s for this question.
    @Binding var selectedOptionIDs: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            header
            optionsContent
        }
    }

    @ViewBuilder
    private var optionsContent: some View {
        switch question.optionStyle {
        case .pill:
            optionsGrid
        case .card:
            optionsList
        }
    }

    private var optionsList: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(question.options) { option in
                OptionCard(
                    label: option.label,
                    description: option.description ?? "",
                    isSelected: selectedOptionIDs.contains(option.id)
                ) {
                    toggle(option)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(question.prompt)
                .font(DesignSystem.title)
                .foregroundColor(DesignSystem.backgroundMain)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = question.subtitle {
                Text(subtitle)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
            }
        }
    }

    // MARK: Options

    private var optionsGrid: some View {
        // Adaptive flow-style layout so pills wrap naturally regardless
        // of label length, without needing a custom Layout implementation.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: DesignSystem.Spacing.sm)],
            alignment: .leading,
            spacing: DesignSystem.Spacing.sm
        ) {
            ForEach(question.options) { option in
                OptionPill(
                    label: option.label,
                    isSelected: selectedOptionIDs.contains(option.id)
                ) {
                    toggle(option)
                }
            }
        }
    }

    // MARK: Selection logic

    private func toggle(_ option: OnboardingOption) {
        if question.selectionLimit.isSingleSelect {
            // Single-select: tapping an option always replaces the selection,
            // even re-tapping the same one (keeps exactly one selected).
            selectedOptionIDs = [option.id]
            return
        }

        if selectedOptionIDs.contains(option.id) {
            selectedOptionIDs.remove(option.id)
        } else {
            if let max = question.selectionLimit.maxSelections,
               selectedOptionIDs.count >= max {
                // At cap — ignore additional taps until something is deselected.
                return
            }
            selectedOptionIDs.insert(option.id)
        }
    }
}

// MARK: - OptionPill
//
// The single reusable pill/chip button. Selected state uses the primary
// orange-coral gradient; unselected uses the cream (`backgroundMain`)
// fill with dark navy text, mirroring the light/dark pairing already
// established in WelcomeView. No text is hardcoded here — `label` is
// always supplied by the caller.

private struct OptionPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(label)
                    .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? DesignSystem.backgroundMain : DesignSystem.backgroundOnboarding)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DesignSystem.roundedFont(size: 13, weight: .semibold))
                        .foregroundColor(DesignSystem.backgroundMain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(background)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? DesignSystem.backgroundMain.opacity(0.3) : DesignSystem.backgroundMain.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            DesignSystem.primaryGradient
        } else {
            DesignSystem.backgroundMain
        }
    }
}


private struct OptionCard: View {
    let label: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        } label: {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text(label)
                        .font(DesignSystem.headline)
                        .foregroundColor(isSelected ? DesignSystem.backgroundMain : DesignSystem.backgroundOnboarding)

                    Text(description)
                        .font(DesignSystem.subheadline)
                        .foregroundColor(
                            isSelected
                                ? DesignSystem.backgroundMain.opacity(0.8)
                                : DesignSystem.backgroundOnboarding.opacity(0.6)
                        )
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DesignSystem.roundedFont(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.backgroundMain)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                    .strokeBorder(
                        isSelected ? DesignSystem.backgroundMain.opacity(0.3) : DesignSystem.backgroundMain.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            DesignSystem.primaryGradient
        } else {
            DesignSystem.backgroundMain
        }
    }
}


// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selected: Set<String> = ["focus"]

        var body: some View {
            ZStack {
                DesignSystem.backgroundOnboarding.ignoresSafeArea()
                QuestionnaireView(
                    question: OnboardingQuestion.sampleOnboardingFlow[0],
                    selectedOptionIDs: $selected
                )
                .padding(DesignSystem.Spacing.lg)
            }
        }
    }

    return PreviewWrapper()
}