//
//  CognitiveTestIntroView.swift
//  LumiMind
//
//  Full-screen scrollable intro for the NCPT-style cognitive
//  assessment, reached via the "Tests" tab. 100% free — no paywall,
//  no upsell anywhere in this flow.
//
//  Sample score, subtest breakdown, stat callouts, and citations
//  below are placeholder/mock content for layout — swap for real
//  data/citations before shipping.
//

import SwiftUI

struct CognitiveTestIntroView: View {
    /// Launches the actual assessment flow. Caller owns navigation/presentation.
    var onStart: () -> Void
    /// Navigates to past-attempts history. Caller owns navigation/presentation.
    var onViewHistory: () -> Void
    /// Most recent completed session's score, if any — shown as a
    /// small summary card so returning from Results isn't a dead end.
    var latestScore: Int?

    @State private var expandedFAQID: UUID?

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        heroSection
                        whatIsSection
                        domainGridSection
                        whyTakeItSection
                        sampleReportSection
                        whatYoullLearnSection
                        faqSection
                        scientificValidationSection
                        finalCTASection
                    }
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }

                stickyCTABar
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checklist")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(DesignSystem.primaryGradient)
                .clipShape(Circle())

            Text("Your Annual Brain Check-In")
                .font(DesignSystem.title)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .multilineTextAlignment(.center)

            Text("A quick, science-backed assessment across memory, attention, speed, and reasoning — free, every year.")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
                .multilineTextAlignment(.center)

            trustBadgesRow
                .padding(.top, DesignSystem.Spacing.xs)

            if let latestScore {
                latestResultCard(score: latestScore)
                    .padding(.top, DesignSystem.Spacing.xs)
            }

            Button(action: onViewHistory) {
                Text("View Past Attempts")
                    .font(DesignSystem.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.backgroundOnboarding)
            }
            .buttonStyle(.plain)
            .padding(.top, DesignSystem.Spacing.xxs)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var trustBadgesRow: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            TrustBadge(text: "500K+ Users")
            TrustBadge(text: "Scientifically Validated")
            TrustBadge(text: "Annual Tracking")
        }
    }

        private func latestResultCard(score: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Latest Result")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
                Text(CognitiveScoring.performanceBadge(forScore: score).label)
                    .font(DesignSystem.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.backgroundOnboarding)
            }
            Spacer()
            Text("\(score)")
                .font(DesignSystem.roundedFont(size: 24, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }

    // MARK: - What Is Section

    private var whatIsSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(DesignSystem.attentionGradient)
                .clipShape(Circle())

            Text("What is the Cognitive Check-In?")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .multilineTextAlignment(.center)

            Text("A structured set of short games that measure how your brain performs today across four core domains — so you can track changes year over year.")
                .font(DesignSystem.body)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - Domain Grid

    private static let domains: [DomainInfo] = [
        DomainInfo(name: "Memory", description: "How well you encode and recall information.", icon: "square.stack.3d.up.fill", category: .memory),
        DomainInfo(name: "Attention", description: "How well you filter distraction and stay focused.", icon: "eye.fill", category: .attention),
        DomainInfo(name: "Processing Speed", description: "How quickly you take in and react to information.", icon: "bolt.fill", category: .speed),
        DomainInfo(name: "Reasoning", description: "How well you solve novel problems.", icon: "puzzlepiece.fill", category: .problemSolving)
    ]

    private var domainGridSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Four Core Domains")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .padding(.horizontal, DesignSystem.Spacing.md)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DesignSystem.Spacing.sm), GridItem(.flexible(), spacing: DesignSystem.Spacing.sm)], spacing: DesignSystem.Spacing.sm) {
                ForEach(Self.domains) { domain in
                    DomainCard(domain: domain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Why Take It

    private var whyTakeItSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Why Take It?")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .padding(.horizontal, DesignSystem.Spacing.md)

            HStack(spacing: DesignSystem.Spacing.sm) {
                BenefitCard(icon: "chart.line.uptrend.xyaxis", title: "Track Progress", subtitle: "See how your scores shift year to year.")
                BenefitCard(icon: "person.2.fill", title: "Compare with Peers", subtitle: "See how you stack up by age group.")
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Sample Report

    private static let sampleSubtests: [SubtestScore] = [
        SubtestScore(name: "Word Recall", domain: "Memory", percentileRange: "70th–80th"),
        SubtestScore(name: "Visual Search", domain: "Attention", percentileRange: "60th–70th"),
        SubtestScore(name: "Reaction Time", domain: "Processing Speed", percentileRange: "80th–90th"),
        SubtestScore(name: "Pattern Match", domain: "Reasoning", percentileRange: "65th–75th"),
        SubtestScore(name: "Digit Span", domain: "Memory", percentileRange: "75th–85th"),
        SubtestScore(name: "Task Switching", domain: "Attention", percentileRange: "55th–65th")
    ]

    private var sampleReportSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Sample Report")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: DesignSystem.Spacing.xxs) {
                Text("109")
                    .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                    .foregroundColor(.white)
                Text("Above Average")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Self.sampleSubtests) { subtest in
                    SubtestRow(subtest: subtest)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - What You'll Learn

    private static let learnPoints: [String] = [
        "Your current standing across memory, attention, speed, and reasoning.",
        "How your results compare to others in your age range.",
        "A baseline to track against next year's check-in."
    ]

    private var whatYoullLearnSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("What You'll Learn")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(Self.learnPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.backgroundOnboarding)
                        Text(point)
                            .font(DesignSystem.body)
                            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.85))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - FAQ

    private static let faqItems: [FAQItem] = [
        FAQItem(question: "How long does it take?", answer: "About 10–15 minutes for the full set of games."),
        FAQItem(question: "Is my data private?", answer: "Yes. Your results are tied to your account and are never shared or sold."),
        FAQItem(question: "How accurate is it?", answer: "It's designed to reliably track relative changes in your own performance over time, not to be a precise clinical measurement."),
        FAQItem(question: "Is this a medical diagnosis?", answer: "No. This is not a diagnostic or medical tool. Talk to a doctor if you have concerns about your cognitive health."),
        FAQItem(question: "Is there an age requirement?", answer: "The assessment is designed for adults. It isn't calibrated for children or teens.")
    ]

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Frequently Asked Questions")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .padding(.horizontal, DesignSystem.Spacing.md)

            VStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Self.faqItems) { item in
                    FAQRow(item: item, isExpanded: expandedFAQID == item.id) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedFAQID = (expandedFAQID == item.id) ? nil : item.id
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Scientific Validation

    private var scientificValidationSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Backed by Research")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            HStack(spacing: DesignSystem.Spacing.sm) {
                StatCallout(value: "500K+", label: "Assessments Taken")
                StatCallout(value: "94%", label: "Would Retake")
            }

            VStack(spacing: DesignSystem.Spacing.xs) {
                // Placeholder citations — swap in real published sources.
                CitationCard(citation: "Chen et al., Journal of Cognitive Assessment, 2023", summary: "Validated the underlying task battery against standard neuropsychological measures.")
                CitationCard(citation: "Patel & Osei, Aging & Cognition Review, 2022", summary: "Found consistent year-over-year tracking of processing speed changes using similar short-form tasks.")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    // MARK: - Final CTA

    private var finalCTASection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Ready to Begin?")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Button(action: onStart) {
                Text("Start Assessment")
                    .font(DesignSystem.buttonLabel)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .buttonStyle(.plain)
            .background(DesignSystem.primaryGradient)
            .clipShape(Capsule())

            Text("100% free. No account changes, no upsells. Your results stay private.")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    // MARK: - Sticky Bottom Bar

    private var stickyCTABar: some View {
        Button(action: onStart) {
            Text("Start Assessment")
                .font(DesignSystem.buttonLabel)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.primaryGradient)
        .clipShape(Capsule())
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.xs)
        .padding(.bottom, DesignSystem.Spacing.md)
        .background(DesignSystem.backgroundMain.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Supporting Data Types

private struct DomainInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let category: GameCategory
}

private struct SubtestScore: Identifiable {
    let id = UUID()
    let name: String
    let domain: String
    let percentileRange: String
}

private struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - Supporting Subviews

private struct TrustBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DesignSystem.caption)
            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xxs)
            .background(DesignSystem.backgroundOnboarding.opacity(0.06))
            .clipShape(Capsule())
    }
}

private struct DomainCard: View {
    let domain: DomainInfo

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Image(systemName: domain.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(DesignSystem.gradient(for: domain.category))
                .clipShape(Circle())

            Text(domain.name)
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Text(domain.description)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.sm)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

private struct BenefitCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Text(title)
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Text(subtitle)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.sm)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

private struct SubtestRow: View {
    let subtest: SubtestScore

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(subtest.name)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)

                Text(subtest.domain.uppercased())
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
            }

            Spacer()

            Text(subtest.percentileRange)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(DesignSystem.backgroundOnboarding.opacity(0.06))
                .clipShape(Capsule())
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
    }
}

private struct FAQRow: View {
    let item: FAQItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Button(action: onToggle) {
                HStack {
                    Text(item.question)
                        .font(DesignSystem.subheadline)
                        .foregroundColor(DesignSystem.backgroundOnboarding)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
                    .transition(.opacity)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

private struct StatCallout: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text(value)
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)
            Text(label)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.sm)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

private struct CitationCard: View {
    let citation: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(citation)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))

            Text(summary)
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.sm)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

// MARK: - Preview

#Preview {
    CognitiveTestIntroView(
        onStart: { print("Start tapped — launch assessment flow") },
        onViewHistory: { print("View history tapped") },
        latestScore: 109
    )
}