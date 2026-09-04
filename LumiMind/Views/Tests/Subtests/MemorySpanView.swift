import SwiftUI

// MARK: - MemorySpanView
//
// Sequence-recall subtest. A digit sequence flashes one number at a
// time; the user taps a 0–9 keypad back in forward or reverse order.
// Span length increases by 1 after each correct round; ends after 2
// consecutive misses. Longest successfully-completed span is the score.

struct MemorySpanView: View {
    enum Direction {
        case forward
        case reverse
    }

    enum RoundPhase {
        case showingSequence
        case awaitingInput
        case roundResult(correct: Bool)
    }

    let direction: Direction
    /// (longestCompletedSpan, maxPossibleSpan, durationSeconds)
    let onComplete: (Int, Int, Int) -> Void

    private static let startingSpan = 3
    private static let maxSpan = 9
    private static let digitDisplaySeconds = 0.8

    @State private var currentSpan = MemorySpanView.startingSpan
    @State private var sequence: [Int] = []
    @State private var displayIndexShown: Int = -1
    @State private var userInput: [Int] = []
    @State private var roundPhase: RoundPhase = .showingSequence
    @State private var missCount = 0
    @State private var longestCompletedSpan = 0
    @State private var startedAt = Date()

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Text(direction == .forward ? "Repeat in the same order" : "Repeat in reverse order")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))

            sequenceDisplay

            Spacer()

            if case .awaitingInput = roundPhase {
                inputProgress
                keypad
            } else if case .roundResult(let correct) = roundPhase {
                resultBadge(correct: correct)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .onAppear { startRound() }
    }

    private var sequenceDisplay: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.memoryGradient)
                .frame(width: 120, height: 120)

            if case .showingSequence = roundPhase, displayIndexShown >= 0, displayIndexShown < sequence.count {
                Text("\(sequence[displayIndexShown])")
                    .font(DesignSystem.roundedFont(size: 44, weight: .bold))
                    .foregroundColor(.white)
            } else if case .awaitingInput = roundPhase {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private var inputProgress: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(0..<currentSpan, id: \.self) { i in
                Circle()
                    .fill(i < userInput.count ? DesignSystem.backgroundOnboarding : DesignSystem.backgroundOnboarding.opacity(0.15))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.xs), count: 5), spacing: DesignSystem.Spacing.xs) {
            ForEach(0...9, id: \.self) { digit in
                Button(action: { tapDigit(digit) }) {
                    Text("\(digit)")
                        .font(DesignSystem.headline)
                        .foregroundColor(DesignSystem.backgroundOnboarding)
                        .frame(width: 52, height: 52)
                        .background(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func resultBadge(correct: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 34))
                .foregroundColor(correct ? .green : .red)
            Text(correct ? "Correct" : "Not quite")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
    }

    // MARK: - Round flow

    private func startRound() {
        userInput = []
        sequence = (0..<currentSpan).map { _ in Int.random(in: 0...9) }
        roundPhase = .showingSequence
        displayIndexShown = -1
        playSequence()
    }

    private func playSequence() {
        Task {
            for i in 0..<sequence.count {
                displayIndexShown = i
                try? await Task.sleep(nanoseconds: UInt64(Self.digitDisplaySeconds * 1_000_000_000))
                displayIndexShown = -1
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            roundPhase = .awaitingInput
        }
    }

    private func tapDigit(_ digit: Int) {
        guard case .awaitingInput = roundPhase else { return }
        userInput.append(digit)
        guard userInput.count == sequence.count else { return }

        let expected = direction == .forward ? sequence : sequence.reversed()
        let isCorrect = userInput.elementsEqual(expected)
        roundPhase = .roundResult(correct: isCorrect)

        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            if isCorrect {
                longestCompletedSpan = max(longestCompletedSpan, currentSpan)
                missCount = 0
                if currentSpan >= Self.maxSpan {
                    finish()
                } else {
                    currentSpan += 1
                    startRound()
                }
            } else {
                missCount += 1
                if missCount >= 2 {
                    finish()
                } else {
                    startRound()
                }
            }
        }
    }

    private func finish() {
        let duration = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
        onComplete(longestCompletedSpan, Self.maxSpan, duration)
    }
}