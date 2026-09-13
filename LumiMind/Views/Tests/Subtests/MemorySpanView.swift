//
//  MemorySpanView.swift
//  LumiMind
//
//  Sequence-recall subtest. A digit sequence flashes one number at a
//  time; the user taps a 0–9 keypad back in forward or reverse order.
//  Span length increases by 1 after each correct round; ends after 2
//  consecutive misses. Longest successfully-completed span is the score.
//
//  VISUAL THEME: "Lakeside" — a painted lake/mountain/sunset scene
//  (bg-lake-sunset asset) with gradient number cards from
//  DesignSystem.memorySpanCardPalette. Scoring, timing, and the
//  completion callback contract are unchanged from the original
//  Halloween pass — this is illustration only.
//

import SwiftUI
import UIKit

// MARK: - MemorySpanView

struct MemorySpanView: View {
    enum Direction {
        case forward
        case reverse
    }

    enum RoundPhase: Equatable {
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

    // MARK: Core state (unchanged logic/timing)

    @State private var currentSpan = MemorySpanView.startingSpan
    @State private var sequence: [Int] = []
    @State private var displayIndexShown: Int = -1
    @State private var userInput: [Int] = []
    @State private var roundPhase: RoundPhase = .showingSequence
    @State private var missCount = 0
    @State private var longestCompletedSpan = 0
    @State private var startedAt = Date()

    private var driftForward: Bool { direction == .forward }

    fileprivate enum LanternFaceContent {
        case digit(String, id: Int)
        case tapPrompt
        case blank
    }

    private var faceContent: LanternFaceContent {
        switch roundPhase {
        case .showingSequence:
            if displayIndexShown >= 0, displayIndexShown < sequence.count {
                return .digit("\(sequence[displayIndexShown])", id: displayIndexShown)
            }
            return .blank
        case .awaitingInput:
            return .tapPrompt
        case .roundResult:
            return .blank
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: DesignSystem.Spacing.md) {
                progressRow
                    .padding(.top, DesignSystem.Spacing.sm)

                Spacer()

                Text(direction == .forward ? "Repeat in the same order" : "Repeat in reverse order")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.8))

                sequenceStage
                    .frame(height: 170)

                Spacer()

                Group {
                    if case .awaitingInput = roundPhase {
                        keypad
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if case .roundResult(let correct) = roundPhase {
                        resultBadge(correct: correct)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: roundPhase)

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .onAppear { startRound() }
    }

    // MARK: - Progress row

    private var progressRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(0..<currentSpan, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(i < userInput.count ? AnyShapeStyle(DesignSystem.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.4)))
                    .frame(width: 18, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: userInput.count)
            }
        }
    }

    // MARK: - Sequence stage

    private var sequenceStage: some View {
        ZStack {
            switch faceContent {
            case .digit(let text, let id):
                RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                    .fill(DesignSystem.memorySpanCardGradient(forDigit: Int(text) ?? 0))
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .overlay(
                        Text(text)
                            .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .id(id)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .opacity
                    ))
            case .tapPrompt:
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 96, height: 96)
                    .background(DesignSystem.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
            case .blank:
                EmptyView()
            }
        }
    }

    // MARK: - Keypad

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.xs), count: 5),
            spacing: DesignSystem.Spacing.sm
        ) {
            ForEach(0...9, id: \.self) { digit in
                GradientNumberCard(digit: digit) {
                    tapDigit(digit)
                }
            }
        }
    }

    // MARK: - Result feedback

    private func resultBadge(correct: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(correct ? .green.opacity(0.85) : .red.opacity(0.7))
            Text(correct ? "Correct" : "Not quite")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.8))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    // MARK: - Round flow (logic/timing unchanged)

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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                roundPhase = .awaitingInput
            }
        }
    }

    private func tapDigit(_ digit: Int) {
        guard case .awaitingInput = roundPhase else { return }
        userInput.append(digit)
        guard userInput.count == sequence.count else { return }

        let expected = direction == .forward ? sequence : sequence.reversed()
        let isCorrect = userInput.elementsEqual(expected)

        withAnimation(.easeInOut(duration: 0.25)) {
            roundPhase = .roundResult(correct: isCorrect)
        }

        if isCorrect {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }

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

// MARK: - Gradient number card (keypad button)

private struct GradientNumberCard: View {
    let digit: Int
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { pressed = true }
            action()
            Task {
                try? await Task.sleep(nanoseconds: 130_000_000)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pressed = false }
            }
        }) {
            Text("\(digit)")
                .font(DesignSystem.headline)
                .foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(DesignSystem.memorySpanCardGradient(forDigit: digit))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
                .scaleEffect(pressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
    }
}