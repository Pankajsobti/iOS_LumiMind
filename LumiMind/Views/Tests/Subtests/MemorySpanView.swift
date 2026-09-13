//
//  MemorySpanView.swift
//  LumiMind
//
//  Sequence-recall subtest. A digit sequence flashes one number at a
//  time; the user taps a 0–9 keypad back in forward or reverse order.
//  Span length increases by 1 after each correct round; ends after 2
//  consecutive misses. Longest successfully-completed span is the score.
//
//  VISUAL THEME: "Amethyst Cavern" — a faceted crystal-shard metaphor
//  built on DesignSystem.memoryGradient (plum → berry). Scoring, timing,
//  and the completion callback contract are unchanged from the prior
//  version — this pass is animation/illustration only.
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

    // MARK: Core state (unchanged logic/timing from prior version)

    @State private var currentSpan = MemorySpanView.startingSpan
    @State private var sequence: [Int] = []
    @State private var displayIndexShown: Int = -1
    @State private var userInput: [Int] = []
    @State private var roundPhase: RoundPhase = .showingSequence
    @State private var missCount = 0
    @State private var longestCompletedSpan = 0
    @State private var startedAt = Date()

    // MARK: Visual-only state (new)

    @State private var sparkles: [SparkleDot] = MemorySpanView.makeSparkles()
    @State private var glowPulse = false
    @State private var crystalScale: CGFloat = 1.0
    @State private var crackProgress: CGFloat = 0
    @State private var crystalDim = false
    @State private var shake: CGFloat = 0
    @State private var shatterID = 0
    @State private var shatterActive = false

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain
                .ignoresSafeArea()

            AmbientCavernBackground(sparkles: sparkles)
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                Spacer()

                Text(direction == .forward ? "Repeat in the same order" : "Repeat in reverse order")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))

                crystalStage
                    .frame(height: 150)

                Spacer()

                Group {
                    if case .awaitingInput = roundPhase {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            inputProgress
                            keypad
                        }
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
        .onAppear {
            startRound()
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glowPulse.toggle()
            }
        }
    }

    // MARK: - Crystal stage (digit reveal / idle icon)

    private var crystalStage: some View {
        ZStack {
            crystalBody
            digitOrIcon
            if shatterActive {
                ShatterBurst(seed: shatterID)
            }
        }
        .offset(x: shake)
    }

    private var crystalBody: some View {
        ZStack {
            // Glow halo
            CrystalShardShape()
                .fill(DesignSystem.memoryGradient)
                .frame(width: 132, height: 132)
                .blur(radius: 22)
                .opacity(glowPulse ? 0.5 : 0.3)

            // Main faceted gem
            CrystalShardShape()
                .fill(DesignSystem.memoryGradient)
                .frame(width: 120, height: 120)
                .overlay(
                    CrystalShardShape()
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
                .overlay(
                    CrackShape()
                        .trim(from: 0, to: crackProgress)
                        .stroke(DesignSystem.backgroundOnboarding.opacity(0.45), lineWidth: 2)
                        .frame(width: 120, height: 120)
                )
                .opacity(crystalDim ? 0.55 : 1.0)
        }
        .scaleEffect(crystalScale)
        // Reverse mode inverts the gem's point (down vs. up) — the
        // digit text itself is a sibling view and is never rotated,
        // so legibility during "watch" is unaffected.
        .rotation3DEffect(
            .degrees(direction == .reverse ? 180 : 0),
            axis: (x: 0, y: 0, z: 1)
        )
    }

    private var digitOrIcon: some View {
        Group {
            if case .showingSequence = roundPhase,
               displayIndexShown >= 0,
               displayIndexShown < sequence.count {
                Text("\(sequence[displayIndexShown])")
                    .font(DesignSystem.roundedFont(size: 44, weight: .bold))
                    .foregroundColor(.white)
                    .id(displayIndexShown)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.4).combined(with: .opacity),
                        removal: .scale(scale: 1.3).combined(with: .opacity)
                    ))
            } else if case .awaitingInput = roundPhase {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.85))
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Progress indicator (crystal shards, replaces gray dots)

    private var inputProgress: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(0..<currentSpan, id: \.self) { i in
                ProgressShard(filled: i < userInput.count)
            }
        }
    }

    // MARK: - Keypad (gem-cut buttons)

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.xs), count: 5),
            spacing: DesignSystem.Spacing.sm
        ) {
            ForEach(0...9, id: \.self) { digit in
                GemButton(digit: digit) {
                    tapDigit(digit)
                }
            }
        }
    }

    // MARK: - Result feedback

    private func resultBadge(correct: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: correct ? "sparkles" : "xmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(correct ? DesignSystem.backgroundOnboarding.opacity(0.8) : .red.opacity(0.75))
            Text(correct ? "Correct" : "Not quite")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    // MARK: - Round flow (logic/timing unchanged)

    private func startRound() {
        userInput = []
        sequence = (0..<currentSpan).map { _ in Int.random(in: 0...9) }
        roundPhase = .showingSequence
        displayIndexShown = -1
        resetVisualFeedback()
        playSequence()
    }

    private func playSequence() {
        Task {
            for i in 0..<sequence.count {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    displayIndexShown = i
                }
                try? await Task.sleep(nanoseconds: UInt64(Self.digitDisplaySeconds * 1_000_000_000))

                withAnimation(.easeIn(duration: 0.18)) {
                    displayIndexShown = -1
                }
                triggerShatterPulse()

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            withAnimation(.easeInOut(duration: 0.3)) {
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
            playCorrectFeedback()
        } else {
            playIncorrectFeedback()
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

    // MARK: - Visual feedback helpers (new)

    private func resetVisualFeedback() {
        crackProgress = 0
        crystalDim = false
        shake = 0
        shatterActive = false
        crystalScale = 1.0
    }

    private func triggerShatterPulse() {
        shatterID += 1
        withAnimation(.easeOut(duration: 0.2)) { shatterActive = true }
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(.easeIn(duration: 0.15)) { shatterActive = false }
        }
    }

    private func playCorrectFeedback() {
        shatterID += 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
            crystalScale = 1.15
            shatterActive = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                crystalScale = 1.0
            }
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeIn(duration: 0.2)) { shatterActive = false }
        }
    }

    private func playIncorrectFeedback() {
        withAnimation(.easeInOut(duration: 0.25)) {
            crackProgress = 1.0
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.easeInOut(duration: 0.4)) {
                crystalDim = true
            }
            let offsets: [CGFloat] = [-6, 6, -4, 4, 0]
            for o in offsets {
                withAnimation(.easeInOut(duration: 0.06)) { shake = o }
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
        }
    }

    // MARK: - Ambient sparkle generation

    private static func makeSparkles() -> [SparkleDot] {
        (0..<14).map { i in
            SparkleDot(
                x: CGFloat.random(in: 0.05...0.95),
                y: CGFloat.random(in: 0.05...0.9),
                size: CGFloat.random(in: 2...4),
                delay: Double(i) * 0.15
            )
        }
    }
}

// MARK: - Shapes

/// A pointed faceted gem silhouette. Used for the central crystal,
/// progress shards, and keypad buttons. Point-up by default; the
/// central crystal flips it 180° for reverse-span mode.
private struct CrystalShardShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.32))
        path.addLine(to: CGPoint(x: w * 0.78, y: h))
        path.addLine(to: CGPoint(x: w * 0.22, y: h))
        path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.32))
        path.closeSubpath()
        return path
    }
}

/// A small triangular fragment used in the shatter burst.
private struct ShardFragment: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Jagged crack line revealed via `.trim` on incorrect answers.
private struct CrackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.width * 0.34, y: rect.height * 0.44))
        path.addLine(to: CGPoint(x: rect.width * 0.56, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.86))
        return path
    }
}

// MARK: - Ambient background

private struct SparkleDot: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let delay: Double
}

/// Two blurred gradient blobs (slow glow pulse) plus a field of
/// twinkling sparkle dots. Fixed-count, implicit SwiftUI animations
/// only — no per-frame Canvas work, so this stays cheap on device.
private struct AmbientCavernBackground: View {
    let sparkles: [SparkleDot]
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(DesignSystem.memoryGradient)
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 80)
                    .opacity(pulse ? 0.14 : 0.08)
                    .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.2)

                Circle()
                    .fill(DesignSystem.memoryGradient)
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 90)
                    .opacity(pulse ? 0.10 : 0.05)
                    .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.35)

                ForEach(sparkles) { dot in
                    Circle()
                        .fill(Color.white)
                        .frame(width: dot.size, height: dot.size)
                        .position(x: dot.x * geo.size.width, y: dot.y * geo.size.height)
                        .opacity(pulse ? 0.9 : 0.2)
                        .animation(
                            .easeInOut(duration: 2.4)
                                .repeatForever(autoreverses: true)
                                .delay(dot.delay),
                            value: pulse
                        )
                }
            }
            .onAppear { pulse = true }
        }
        .allowsHitTesting(false)
    }
}

/// Brief burst of fragments flying outward from the crystal, shown
/// each time a digit exits during "watch" and on correct answers.
private struct ShatterBurst: View {
    let seed: Int
    private let fragments: [(dx: CGFloat, dy: CGFloat, rotation: Double)]

    init(seed: Int) {
        self.seed = seed
        fragments = (0..<7).map { _ in
            let angle = Double.random(in: 0..<360)
            let radius = CGFloat.random(in: 30...60)
            let rad = angle * .pi / 180
            return (dx: cos(rad) * radius, dy: sin(rad) * radius, rotation: Double.random(in: 0...180))
        }
    }

    var body: some View {
        ZStack {
            ForEach(0..<fragments.count, id: \.self) { i in
                ShardFragment()
                    .fill(DesignSystem.memoryGradient)
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(fragments[i].rotation))
                    .offset(x: fragments[i].dx, y: fragments[i].dy)
                    .opacity(0.9)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Progress shard

private struct ProgressShard: View {
    let filled: Bool

    var body: some View {
        CrystalShardShape()
            .fill(filled ? AnyShapeStyle(DesignSystem.memoryGradient) : AnyShapeStyle(Color.white.opacity(0.3)))
            .frame(width: 10, height: 14)
            .overlay(
                CrystalShardShape()
                    .stroke(DesignSystem.backgroundOnboarding.opacity(filled ? 0 : 0.15), lineWidth: 1)
            )
            .scaleEffect(filled ? 1.0 : 0.85)
            .shadow(color: filled ? Color.black.opacity(0.15) : .clear, radius: 2, y: 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: filled)
    }
}

// MARK: - Gem keypad button

private struct GemButton: View {
    let digit: Int
    let action: () -> Void

    @State private var pressed = false
    @State private var glint = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressed = true }
            glint = false
            withAnimation(.easeOut(duration: 0.35)) { glint = true }
            action()
            Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pressed = false }
            }
        }) {
            ZStack {
                CrystalShardShape()
                    .fill(DesignSystem.memoryGradient)
                    .overlay(
                        CrystalShardShape()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                    .overlay(glintOverlay)
                    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 2)

                Text("\(digit)")
                    .font(DesignSystem.headline)
                    .foregroundColor(.white)
            }
            .frame(width: 52, height: 52)
            .scaleEffect(pressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var glintOverlay: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geo.size.width * 0.5)
                .rotationEffect(.degrees(20))
                .offset(x: glint ? geo.size.width : -geo.size.width)
        }
        .mask(CrystalShardShape())
        .allowsHitTesting(false)
    }
}