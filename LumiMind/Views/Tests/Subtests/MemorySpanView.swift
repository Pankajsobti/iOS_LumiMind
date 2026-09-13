//
//  MemorySpanView.swift
//  LumiMind
//
//  Sequence-recall subtest. A digit sequence flashes one number at a
//  time; the user taps a 0–9 keypad back in forward or reverse order.
//  Span length increases by 1 after each correct round; ends after 2
//  consecutive misses. Longest successfully-completed span is the score.
//
//  VISUAL THEME: "Jack-o'-Lantern Patch" — a Halloween night scene
//  (crescent moon, drifting bats, pumpkin-patch horizon, embers) built
//  around DesignSystem.memorySpanPumpkinGradient / .memorySpanNight.
//  Scoring, timing, and the completion callback contract are
//  unchanged — this pass is animation/illustration only.
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

    // MARK: Visual-only state (new)

    @State private var faceGlow: Double = 0
    @State private var pumpkinScale: CGFloat = 0.9
    @State private var grinAmount: CGFloat = 0
    @State private var shake: CGFloat = 0
    @State private var smokeActive = false
    @State private var sparkActive = false
    @State private var sparkID = 0
    @State private var bats: [Bat] = MemorySpanView.makeBats()
    @State private var embers: [Ember] = MemorySpanView.makeEmbers()

    private var driftForward: Bool { direction == .forward }

    private enum LanternFaceContent {
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
            DesignSystem.backgroundMain
                .ignoresSafeArea()

            HalloweenNightBackground(bats: bats, embers: embers, driftForward: driftForward)
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                batProgressRow
                    .padding(.top, DesignSystem.Spacing.sm)

                Spacer()

                Text(direction == .forward ? "Repeat in the same order" : "Repeat in reverse order")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))

                pumpkinStage
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

    // MARK: - Bat progress row (replaces gray dots)

    private var batProgressRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(0..<currentSpan, id: \.self) { i in
                ProgressBat(filled: i < userInput.count)
            }
        }
    }

    // MARK: - Jack-o'-lantern stage

    private var pumpkinStage: some View {
        ZStack {
            JackOLanternView(glow: faceGlow, grinAmount: grinAmount, content: faceContent)
                .scaleEffect(pumpkinScale)
                .offset(x: shake)

            if sparkActive {
                EmberBurst(seed: sparkID, upward: true)
            }
            if smokeActive {
                SmokePuff()
                    .offset(y: -30)
            }
        }
    }

    // MARK: - Keypad (mini pumpkin buttons)

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.xs), count: 5),
            spacing: DesignSystem.Spacing.sm
        ) {
            ForEach(0...9, id: \.self) { digit in
                MiniPumpkinButton(digit: digit) {
                    tapDigit(digit)
                }
            }
        }
    }

    // MARK: - Result feedback

    private func resultBadge(correct: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: correct ? "sparkles" : "moon.stars.fill")
                .font(.system(size: 30))
                .foregroundColor(correct ? DesignSystem.memorySpanNight.opacity(0.8) : .red.opacity(0.7))
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
                displayIndexShown = i
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    faceGlow = 1
                    pumpkinScale = 1.0
                }
                try? await Task.sleep(nanoseconds: UInt64(Self.digitDisplaySeconds * 1_000_000_000))

                withAnimation(.easeIn(duration: 0.2)) {
                    faceGlow = 0
                    pumpkinScale = 0.94
                }
                displayIndexShown = -1

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                faceGlow = 0.6
                pumpkinScale = 1.0
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
        grinAmount = 0
        shake = 0
        smokeActive = false
        sparkActive = false
    }

    private func playCorrectFeedback() {
        sparkID += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            grinAmount = 1
            faceGlow = 1
            pumpkinScale = 1.12
            sparkActive = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                pumpkinScale = 1.0
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            sparkActive = false
        }
    }

    private func playIncorrectFeedback() {
        withAnimation(.easeInOut(duration: 0.3)) {
            faceGlow = 0.15
        }
        smokeActive = true
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        Task {
            let offsets: [CGFloat] = [-6, 6, -4, 4, 0]
            for o in offsets {
                withAnimation(.easeInOut(duration: 0.06)) { shake = o }
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            smokeActive = false
        }
    }

    private static func makeBats() -> [Bat] {
        (0..<3).map { i in
            Bat(
                x: CGFloat.random(in: 0.1...0.9),
                y: CGFloat.random(in: 0.05...0.25),
                scale: CGFloat.random(in: 0.8...1.2),
                duration: Double.random(in: 3.0...4.5),
                delay: Double(i) * 0.6
            )
        }
    }

    private static func makeEmbers() -> [Ember] {
        (0..<10).map { i in
            Ember(
                x: CGFloat.random(in: 0.05...0.95),
                y: CGFloat.random(in: 0.5...0.95),
                size: CGFloat.random(in: 2...4),
                duration: Double.random(in: 2.6...4.2),
                delay: Double(i) * 0.2
            )
        }
    }
}

// MARK: - Ambient models

private struct Bat: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let duration: Double
    let delay: Double
}

private struct Ember: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let duration: Double
    let delay: Double
}

// MARK: - Ambient Halloween night scene

/// Twilight sky wash, a crescent moon, drifting bats, a pumpkin-patch
/// horizon, and rising embers. Fixed-count implicit SwiftUI animations
/// only — no per-frame Canvas work, cheap on device.
private struct HalloweenNightBackground: View {
    let bats: [Bat]
    let embers: [Ember]
    let driftForward: Bool
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [DesignSystem.memorySpanNight.opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: .center
                )

                ZStack {
                    Circle()
                        .fill(DesignSystem.memorySpanPumpkinGradient)
                        .frame(width: 54, height: 54)
                    Circle()
                        .fill(DesignSystem.backgroundMain)
                        .frame(width: 54, height: 54)
                        .offset(x: 16, y: -10)
                }
                .position(x: geo.size.width * 0.82, y: geo.size.height * 0.1)
                .opacity(0.9)

                ForEach(bats) { bat in
                    BatShape()
                        .fill(DesignSystem.memorySpanNight.opacity(0.55))
                        .frame(width: 22 * bat.scale, height: 10 * bat.scale)
                        .position(
                            x: (driftForward ? bat.x : 1 - bat.x) * geo.size.width + (animate ? 40 : -40),
                            y: bat.y * geo.size.height + (animate ? -6 : 6)
                        )
                        .animation(
                            .easeInOut(duration: bat.duration).repeatForever(autoreverses: true).delay(bat.delay),
                            value: animate
                        )
                }

                ForEach(embers) { ember in
                    Circle()
                        .fill(DesignSystem.memorySpanPumpkinGradient)
                        .frame(width: ember.size, height: ember.size)
                        .position(x: ember.x * geo.size.width, y: ember.y * geo.size.height)
                        .opacity(animate ? 0.8 : 0.1)
                        .offset(y: animate ? -18 : 0)
                        .animation(
                            .easeInOut(duration: ember.duration).repeatForever(autoreverses: true).delay(ember.delay),
                            value: animate
                        )
                }

                PatchHorizonShape()
                    .fill(DesignSystem.memorySpanNight.opacity(0.85))
                    .frame(height: 46)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .onAppear { animate = true }
        }
        .allowsHitTesting(false)
    }
}

private struct BatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.3))
        path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: w * 0.2, y: h))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.5), control: CGPoint(x: w * 0.3, y: h * 0.1))
        path.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w * 0.7, y: h * 0.1))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.3), control: CGPoint(x: w * 0.8, y: h))
        path.closeSubpath()
        return path
    }
}

private struct PatchHorizonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.6))
        path.addCurve(to: CGPoint(x: w * 0.25, y: h * 0.35),
                       control1: CGPoint(x: w * 0.08, y: h * 0.5),
                       control2: CGPoint(x: w * 0.15, y: h * 0.3))
        path.addCurve(to: CGPoint(x: w * 0.45, y: h * 0.6),
                       control1: CGPoint(x: w * 0.35, y: h * 0.4),
                       control2: CGPoint(x: w * 0.4, y: h * 0.55))
        path.addCurve(to: CGPoint(x: w * 0.7, y: h * 0.3),
                       control1: CGPoint(x: w * 0.55, y: h * 0.5),
                       control2: CGPoint(x: w * 0.6, y: h * 0.25))
        path.addCurve(to: CGPoint(x: w, y: h * 0.55),
                       control1: CGPoint(x: w * 0.82, y: h * 0.35),
                       control2: CGPoint(x: w * 0.92, y: h * 0.45))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Progress bat

private struct ProgressBat: View {
    let filled: Bool
    @State private var flap = false

    var body: some View {
        BatShape()
            .fill(filled ? AnyShapeStyle(DesignSystem.memorySpanPumpkinGradient) : AnyShapeStyle(DesignSystem.memorySpanNight.opacity(0.2)))
            .frame(width: 18, height: 9)
            .scaleEffect(x: 1, y: flap ? 0.7 : 1.0)
            .scaleEffect(filled ? 1.0 : 0.85)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: filled)
            .onAppear {
                if filled {
                    withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                        flap = true
                    }
                }
            }
    }
}

// MARK: - Jack-o'-lantern

/// The central pumpkin. `glow` (0–1) drives face brightness and a soft
/// halo; `grinAmount` widens the mouth on a correct answer. The digit
/// is the LAST layer in the stack — nothing renders above it, which is
/// what fixes the earlier "invisible number" bug.
private struct JackOLanternView: View {
    let glow: Double
    let grinAmount: CGFloat
    let content: MemorySpanView.LanternFaceContentPublic

    var body: some View {
        ZStack {
            PumpkinShape()
                .fill(DesignSystem.memorySpanPumpkinGradient)
                .frame(width: 150, height: 130)
                .blur(radius: 26)
                .opacity(glow * 0.55)

            PumpkinShape()
                .fill(DesignSystem.memorySpanPumpkinGradient)
                .frame(width: 128, height: 108)
                .overlay(PumpkinRidges())
                .brightness(glow * 0.12 - 0.06)

            RoundedRectangle(cornerRadius: 3)
                .fill(DesignSystem.memorySpanNight)
                .frame(width: 12, height: 20)
                .rotationEffect(.degrees(-8))
                .offset(y: -60)

            VStack(spacing: 6) {
                HStack(spacing: 22) {
                    Triangle().fill(DesignSystem.memorySpanNight.opacity(0.3 + glow * 0.7)).frame(width: 16, height: 16)
                    Triangle().fill(DesignSystem.memorySpanNight.opacity(0.3 + glow * 0.7)).frame(width: 16, height: 16)
                }
                GrinShape(amount: grinAmount)
                    .fill(DesignSystem.memorySpanNight.opacity(0.3 + glow * 0.7))
                    .frame(width: 46, height: 14)
            }
            .offset(y: -6)

            faceOverlay
                .offset(y: 18)
        }
    }

    @ViewBuilder
    private var faceOverlay: some View {
        switch content {
        case .digit(let text, let id):
            Text(text)
                .font(DesignSystem.roundedFont(size: 40, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2)
                .id(id)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .opacity
                ))
        case .tapPrompt:
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.85))
                .transition(.opacity)
        case .blank:
            EmptyView()
        }
    }
}

private struct PumpkinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect.insetBy(dx: 0, dy: rect.height * 0.02))
        return path
    }
}

private struct PumpkinRidges: View {
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: geo.size.width / 5) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, geo.size.width * 0.12)
        }
        .clipShape(PumpkinShape())
        .allowsHitTesting(false)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct GrinShape: Shape {
    var amount: CGFloat

    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height * (0.5 + amount * 0.5)
        let teeth = 5
        let step = w / CGFloat(teeth)
        path.move(to: CGPoint(x: 0, y: 0))
        for i in 0..<teeth {
            let x1 = step * (CGFloat(i) + 0.5)
            let x2 = step * CGFloat(i + 1)
            path.addLine(to: CGPoint(x: x1, y: h))
            path.addLine(to: CGPoint(x: x2, y: 0))
        }
        path.addLine(to: CGPoint(x: w, y: h * 0.3))
        path.addLine(to: CGPoint(x: 0, y: h * 0.3))
        path.closeSubpath()
        return path
    }
}

// MARK: - Mini pumpkin keypad button

private struct MiniPumpkinButton: View {
    let digit: Int
    let action: () -> Void

    @State private var pressed = false
    @State private var litUp = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
                pressed = true
                litUp = true
            }
            action()
            Task {
                try? await Task.sleep(nanoseconds: 130_000_000)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    pressed = false
                    litUp = false
                }
            }
        }) {
            ZStack {
                PumpkinShape()
                    .fill(DesignSystem.memorySpanPumpkinGradient)
                    .overlay(PumpkinShape().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    .brightness(litUp ? 0.15 : 0)
                    .shadow(color: Color.black.opacity(0.15), radius: 3, y: 2)

                Text("\(digit)")
                    .font(DesignSystem.headline)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1)
            }
            .frame(width: 52, height: 52)
            .scaleEffect(pressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feedback effects

private struct EmberBurst: View {
    let seed: Int
    let upward: Bool
    private let particles: [(dx: CGFloat, dy: CGFloat, size: CGFloat)]

    init(seed: Int, upward: Bool) {
        self.seed = seed
        self.upward = upward
        particles = (0..<8).map { _ in
            let angle = Double.random(in: 0..<360)
            let radius = CGFloat.random(in: 25...65)
            let rad = angle * .pi / 180
            var dy = sin(rad) * radius
            if upward { dy -= 20 }
            return (dx: cos(rad) * radius, dy: dy, size: CGFloat.random(in: 4...7))
        }
    }

    var body: some View {
        ZStack {
            ForEach(0..<particles.count, id: \.self) { i in
                Circle()
                    .fill(DesignSystem.memorySpanPumpkinGradient)
                    .frame(width: particles[i].size, height: particles[i].size)
                    .offset(x: particles[i].dx, y: particles[i].dy)
                    .opacity(0.85)
            }
        }
        .transition(.opacity)
    }
}

private struct SmokePuff: View {
    @State private var rise = false

    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 30, height: 30)
            .blur(radius: 7)
            .offset(y: rise ? -36 : 0)
            .opacity(rise ? 0 : 0.7)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { rise = true }
            }
    }
}