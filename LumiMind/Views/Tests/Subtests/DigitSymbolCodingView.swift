import SwiftUI

// MARK: - DigitSymbolCodingView
//
// Symbol-matching subtest. A fixed digit→symbol key (1–9) is shown at
// top. Cells present a digit with 4 symbol options; user taps the
// matching symbol. Timed — score is correct answers before time runs out.

struct DigitSymbolCodingView: View {
    /// (correctCount, attemptedCount, durationSeconds)
    let onComplete: (Int, Int, Int) -> Void

    private static let timeLimit = 90
    private static let symbols = ["star.fill", "heart.fill", "bolt.fill", "moon.fill", "cloud.fill", "leaf.fill", "flame.fill", "drop.fill", "sparkle"]
    private static let key: [Int: String] = Dictionary(uniqueKeysWithValues: Array(1...9).enumerated().map { ($0.offset + 1, symbols[$0.offset]) })

    @State private var currentDigit: Int = 1
    @State private var options: [String] = []
    @State private var correctCount = 0
    @State private var attemptedCount = 0
    @State private var timeRemaining = DigitSymbolCodingView.timeLimit
    @State private var startedAt = Date()
    @State private var feedbackSymbol: String?
    @State private var feedbackWasCorrect = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            keyRow

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
        .padding(.horizontal, DesignSystem.Spacing.md)
        .onAppear {
            nextItem()
            startTimer()
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

    private func nextItem() {
        currentDigit = Int.random(in: 1...9)
        feedbackSymbol = nil
        let correctSymbol = Self.key[currentDigit] ?? Self.symbols[0]
        var pool = Self.symbols.filter { $0 != correctSymbol }.shuffled().prefix(3).map { $0 }
        pool.append(correctSymbol)
        options = pool.shuffled()
    }

    private func select(_ symbol: String) {
        guard feedbackSymbol == nil, timeRemaining > 0 else { return }
        attemptedCount += 1
        let correctSymbol = Self.key[currentDigit] ?? ""
        let isCorrect = symbol == correctSymbol
        feedbackSymbol = symbol
        feedbackWasCorrect = isCorrect
        if isCorrect { correctCount += 1 }

        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if timeRemaining > 0 {
                nextItem()
            }
        }
    }

    private func startTimer() {
        Task {
            while timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                timeRemaining -= 1
            }
            finish()
        }
    }

    private func finish() {
        let duration = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
        onComplete(correctCount, max(attemptedCount, 1), duration)
    }
}