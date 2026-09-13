import SwiftUI

// MARK: - DigitSymbolCodingView
//
// Symbol-matching subtest. A fixed digit→symbol key (1–9) is studied for
// a fixed period, then hidden. Cells present a digit with 4 symbol
// options; user taps the matching symbol. Timed — score is correct
// answers before time runs out. 3 consecutive wrong answers triggers a
// short refresher re-reveal of the key.

struct DigitSymbolCodingView: View {
    /// (correctCount, attemptedCount, durationSeconds)
    let onComplete: (Int, Int, Int) -> Void

    private enum Phase {
        case initialStudy
        case quiz
        case restudy
    }

    private static let timeLimit = 90
    private static let initialStudyDuration = 15
    private static let restudyDuration = 10
    private static let wrongStreakThreshold = 3

    private static let symbols = ["star.fill", "heart.fill", "bolt.fill", "moon.fill", "cloud.fill", "leaf.fill", "flame.fill", "drop.fill", "sparkle"]
    private static let key: [Int: String] = Dictionary(uniqueKeysWithValues: Array(1...9).enumerated().map { ($0.offset + 1, symbols[$0.offset]) })

    @State private var phase: Phase = .initialStudy
    @State private var studySecondsRemaining = DigitSymbolCodingView.initialStudyDuration

    @State private var currentDigit: Int = 1
    @State private var options: [String] = []
    @State private var correctCount = 0
    @State private var attemptedCount = 0
    @State private var consecutiveWrong = 0
    @State private var timeRemaining = DigitSymbolCodingView.timeLimit
    @State private var startedAt = Date()
    @State private var feedbackSymbol: String?
    @State private var feedbackWasCorrect = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            switch phase {
            case .initialStudy, .restudy:
                studyPhaseView
            case .quiz:
                quizPhaseView
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .onAppear {
            beginInitialStudy()
        }
    }

    // MARK: - Study phase (initial + refresher)

    private var studyPhaseView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text(phase == .initialStudy ? "Memorize the key!" : "Quick refresher!")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .padding(.top, DesignSystem.Spacing.sm)

            keyRow

            Spacer()

            Text("\(studySecondsRemaining)s")
                .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Spacer()
        }
    }

    // MARK: - Quiz phase

    private var quizPhaseView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Text("\(timeRemaining)s")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))

            Text("\(currentDigit)")
                .font(DesignSystem.roundedFont(size: 56, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)

            optionsRow

            Spacer()

            Text("\(correctCount) correct")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
        }
    }

    private var keyRow: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            ForEach(1...9, id: \.self) { digit in
                VStack(spacing: 2) {
                    Text("\(digit)")
                        .font(DesignSystem.caption)
                        .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                    Image(systemName: Self.key[digit] ?? "")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.backgroundOnboarding)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    private var optionsRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(options, id: \.self) { symbol in
                Button(action: { select(symbol) }) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(feedbackColor(for: symbol))
                        .frame(width: 64, height: 64)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                                .stroke(feedbackSymbol == symbol ? (feedbackWasCorrect ? Color.green : Color.red) : .clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(feedbackSymbol != nil)
            }
        }
    }

    private func feedbackColor(for symbol: String) -> Color {
        guard feedbackSymbol == symbol else { return DesignSystem.backgroundOnboarding }
        return feedbackWasCorrect ? .green : .red
    }

    // MARK: - Phase transitions

    private func beginInitialStudy() {
        phase = .initialStudy
        studySecondsRemaining = Self.initialStudyDuration
        runStudyCountdown {
            beginQuiz()
        }
    }

    private func beginQuiz() {
        phase = .quiz
        nextItem()
        startedAt = Date()
        runQuizTimer()
    }

    private func beginRestudy() {
        phase = .restudy
        studySecondsRemaining = Self.restudyDuration
        runStudyCountdown {
            phase = .quiz
            nextItem()
        }
    }

    private func runStudyCountdown(onFinished: @escaping () -> Void) {
        Task {
            while studySecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                studySecondsRemaining -= 1
            }
            onFinished()
        }
    }

    private func runQuizTimer() {
        Task {
            while timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                // Only counts down while actively quizzing — pauses during a refresher.
                if phase == .quiz {
                    timeRemaining -= 1
                }
            }
            finish()
        }
    }

    // MARK: - Game logic

    private func nextItem() {
        currentDigit = Int.random(in: 1...9)
        feedbackSymbol = nil
        let correctSymbol = Self.key[currentDigit] ?? Self.symbols[0]
        var pool = Self.symbols.filter { $0 != correctSymbol }.shuffled().prefix(3).map { $0 }
        pool.append(correctSymbol)
        options = pool.shuffled()
    }

    private func select(_ symbol: String) {
        guard phase == .quiz, feedbackSymbol == nil, timeRemaining > 0 else { return }
        attemptedCount += 1
        let correctSymbol = Self.key[currentDigit] ?? ""
        let isCorrect = symbol == correctSymbol
        feedbackSymbol = symbol
        feedbackWasCorrect = isCorrect

        if isCorrect {
            correctCount += 1
            consecutiveWrong = 0
        } else {
            consecutiveWrong += 1
        }

        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard timeRemaining > 0, phase == .quiz else { return }

            if consecutiveWrong >= Self.wrongStreakThreshold {
                consecutiveWrong = 0
                beginRestudy()
            } else {
                nextItem()
            }
        }
    }

    private func finish() {
        let duration = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
        onComplete(correctCount, max(attemptedCount, 1), duration)
    }
}