//
//  MemorySpanView.swift
//  LumiMind
//
//  Sequence-recall subtest. A digit sequence flashes one number at a
//  time; the user taps a 0–9 keypad back in forward or reverse order.
//  Span length increases by 1 after each correct round; ends after 2
//  consecutive misses. Longest successfully-completed span is the score.
//
//  VISUAL THEME: "Memory Darkroom" — a warm photo-developing metaphor
//  built entirely with SwiftUI shapes/paths (no external image assets),
//  using DesignSystem.memoryGradient (plum → berry) as the developing
//  light. Scoring, timing, and the completion callback contract are
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

    @State private var photoScale: CGFloat = 0.85
    @State private var photoOpacity: Double = 0
    @State private var developAmount: CGFloat = 0 // 0 = blurred/gray, 1 = sharp/color
    @State private var wobble: Double = 0
    @State private var flashOpacity: Double = 0
    @State private var overexposed = false
    @State private var shake: CGFloat = 0
    @State private var dustMotes: [DustMote] = MemorySpanView.makeDustMotes()

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain
                .ignoresSafeArea()

            AmbientDarkroomBackground(dustMotes: dustMotes)
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                filmString

                Spacer()

                Text(direction == .forward ? "Repeat in the same order" : "Repeat in reverse order")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))

                polaroidStage
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
            .padding(.top, DesignSystem.Spacing.sm)

            // Full-scene flash overlay for the correct-answer moment.
            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear { startRound() }
    }

    // MARK: - Hanging film string (progress indicator)

    private var filmString: some View {
        GeometryReader { geo in
            let count = max(currentSpan, 1)
            let spacing = min(46, (geo.size.width - 40) / CGFloat(count))

            ZStack(alignment: .top) {
                StringPath()
                    .stroke(DesignSystem.backgroundOnboarding.opacity(0.25), lineWidth: 1.5)
                    .frame(height: 14)

                HStack(spacing: spacing - 30) {
                    ForEach(0..<count, id: \.self) { i in
                        HangingPhotoThumb(filled: i < userInput.count)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }
        }
        .frame(height: 46)
    }

    // MARK: - Polaroid stage (digit reveal / idle icon)

    private var polaroidStage: some View {
        PolaroidCard(
            content: {
                Group {
                    if case .showingSequence = roundPhase,
                       displayIndexShown >= 0,
                       displayIndexShown < sequence.count {
                        Text("\(sequence[displayIndexShown])")
                            .font(DesignSystem.roundedFont(size: 44, weight: .bold))
                            .foregroundColor(.white)
                            .id(displayIndexShown)
                    } else if case .awaitingInput = roundPhase {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            },
            developAmount: developAmount,
            overexposed: overexposed
        )
        .scaleEffect(photoScale)
        .opacity(photoOpacity)
        .rotationEffect(.degrees(wobble))
        .offset(x: shake)
    }

    // MARK: - Keypad (shutter-dial buttons)

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.xs), count: 5),
            spacing: DesignSystem.Spacing.sm
        ) {
            ForEach(0...9, id: \.self) { digit in
                ShutterButton(digit: digit) {
                    tapDigit(digit)
                }
            }
        }
    }

    // MARK: - Result feedback

    private func resultBadge(correct: Bool) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: correct ? "camera.fill" : "photo.badge.exclamationmark")
                .font(.system(size: 30))
                .foregroundColor(correct ? DesignSystem.backgroundOnboarding.opacity(0.8) : .red.opacity(0.7))
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
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                    photoScale = 1.0
                    photoOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.45)) {
                    developAmount = 1
                }
                triggerFlash(peak: 0.35, duration: 0.18)
                triggerWobble()

                try? await Task.sleep(nanoseconds: UInt64(Self.digitDisplaySeconds * 1_000_000_000))

                withAnimation(.easeIn(duration: 0.22)) {
                    photoScale = 0.9
                    photoOpacity = 0
                }
                developAmount = 0
                displayIndexShown = -1

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                photoScale = 1.0
                photoOpacity = 1
                roundPhase = .awaitingInput
            }
            withAnimation(.easeOut(duration: 0.3)) { developAmount = 1 }
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
        overexposed = false
        shake = 0
        flashOpacity = 0
        wobble = 0
    }

    private func triggerFlash(peak: Double, duration: Double) {
        withAnimation(.easeOut(duration: duration * 0.4)) { flashOpacity = peak }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 0.4 * 1_000_000_000))
            withAnimation(.easeIn(duration: duration * 0.6)) { flashOpacity = 0 }
        }
    }

    private func triggerWobble() {
        let angle = Double.random(in: -3...3)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) { wobble = angle }
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { wobble = 0 }
        }
    }

    private func playCorrectFeedback() {
        triggerFlash(peak: 0.55, duration: 0.3)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            photoScale = 1.08
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                photoScale = 0.9
                photoOpacity = 0
            }
        }
    }

    private func playIncorrectFeedback() {
        withAnimation(.easeIn(duration: 0.12)) { overexposed = true }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)

        Task {
            // Brief overexposed flicker before settling gray.
            for _ in 0..<2 {
                withAnimation(.easeInOut(duration: 0.06)) { flashOpacity = 0.4 }
                try? await Task.sleep(nanoseconds: 60_000_000)
                withAnimation(.easeInOut(duration: 0.06)) { flashOpacity = 0 }
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
            withAnimation(.easeInOut(duration: 0.3)) { developAmount = 0.15 }

            let offsets: [CGFloat] = [-6, 6, -4, 4, 0]
            for o in offsets {
                withAnimation(.easeInOut(duration: 0.06)) { shake = o }
                try? await Task.sleep(nanoseconds: 60_000_000)
            }
        }
    }

    private static func makeDustMotes() -> [DustMote] {
        (0..<12).map { i in
            DustMote(
                x: CGFloat.random(in: 0.05...0.95),
                y: CGFloat.random(in: 0.1...0.85),
                size: CGFloat.random(in: 2...4),
                duration: Double.random(in: 3.0...5.5),
                delay: Double(i) * 0.2
            )
        }
    }
}

// MARK: - Ambient darkroom background

private struct DustMote: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let duration: Double
    let delay: Double
}

/// A warm, softly-vignetted darkroom wash with two blurred glow pools
/// and a field of slowly drifting, twinkling dust motes. Fixed-count
/// implicit SwiftUI animations only — no per-frame Canvas work.
private struct AmbientDarkroomBackground: View {
    let dustMotes: [DustMote]
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(DesignSystem.memoryGradient)
                    .frame(width: geo.size.width * 0.85)
                    .blur(radius: 100)
                    .opacity(animate ? 0.10 : 0.05)
                    .offset(x: -geo.size.width * 0.22, y: -geo.size.height * 0.15)

                Circle()
                    .fill(DesignSystem.memoryGradient)
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 110)
                    .opacity(animate ? 0.08 : 0.04)
                    .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.4)

                ForEach(dustMotes) { mote in
                    Circle()
                        .fill(DesignSystem.memoryGradient)
                        .frame(width: mote.size, height: mote.size)
                        .position(x: mote.x * geo.size.width, y: mote.y * geo.size.height)
                        .opacity(animate ? 0.6 : 0.1)
                        .offset(y: animate ? -14 : 0)
                        .animation(
                            .easeInOut(duration: mote.duration).repeatForever(autoreverses: true).delay(mote.delay),
                            value: animate
                        )
                }
            }
            .onAppear { animate = true }
        }
        .allowsHitTesting(false)
    }
}

/// A gently sagging string, used as the visual line the photo
/// thumbnails hang from.
private struct StringPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.width, y: 0),
            control: CGPoint(x: rect.width / 2, y: rect.height)
        )
        return path
    }
}

/// A tiny clothespin silhouette used above each hanging photo thumb.
private struct ClothespinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: rect.width * 0.3, height: rect.width * 0.3))
        return path
    }
}

// MARK: - Hanging photo thumbnail (progress indicator)

private struct HangingPhotoThumb: View {
    let filled: Bool
    @State private var sway = false

    var body: some View {
        VStack(spacing: 1) {
            ClothespinShape()
                .fill(DesignSystem.backgroundOnboarding.opacity(filled ? 0.6 : 0.25))
                .frame(width: 8, height: 6)

            RoundedRectangle(cornerRadius: 3)
                .fill(filled ? AnyShapeStyle(DesignSystem.memoryGradient) : AnyShapeStyle(Color.white))
                .frame(width: 18, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(DesignSystem.backgroundOnboarding.opacity(filled ? 0.15 : 0.2), lineWidth: 1)
                )
                .shadow(color: filled ? Color.black.opacity(0.15) : .clear, radius: 2, y: 1)
        }
        .rotationEffect(.degrees(sway ? 2.5 : -2.5), anchor: .top)
        .scaleEffect(filled ? 1.0 : 0.9)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: filled)
        .onAppear {
            withAnimation(.easeInOut(duration: Double.random(in: 2.0...3.0)).repeatForever(autoreverses: true)) {
                sway = true
            }
        }
    }
}

// MARK: - Polaroid card

/// The classic Polaroid silhouette: a colored "photo" pane inset in a
/// thick white/cream border, weighted at the bottom. `developAmount`
/// drives a blur + desaturation wash that clears as the shot "develops";
/// `overexposed` flashes the pane white-hot on a miss.
private struct PolaroidCard<Content: View>: View {
    @ViewBuilder let content: Content
    let developAmount: CGFloat
    let overexposed: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                DesignSystem.memoryGradient
                content
            }
            .frame(width: 128, height: 108)
            .overlay(
                Color.white.opacity(overexposed ? 0.85 : Double(1 - developAmount) * 0.55)
            )
            .blur(radius: overexposed ? 3 : Double(1 - developAmount) * 3.5)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer().frame(height: 18)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
    }
}

// MARK: - Shutter-dial keypad button

/// A round "camera shutter" button — a ring of aperture blades that
/// snap toward closed on tap, with the digit steady at the center.
private struct ShutterButton: View {
    let digit: Int
    let action: () -> Void

    @State private var pressed = false
    @State private var bladesClosed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                pressed = true
                bladesClosed = true
            }
            action()
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                    pressed = false
                    bladesClosed = false
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(DesignSystem.backgroundOnboarding.opacity(0.06))
                    .frame(width: 52, height: 52)

                ForEach(0..<6, id: \.self) { i in
                    ApertureBlade()
                        .fill(DesignSystem.memoryGradient)
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(Double(i) * 60))
                        .scaleEffect(bladesClosed ? 1.15 : 1.0)
                }
                .clipShape(Circle())

                Circle()
                    .fill(Color.white.opacity(0.001)) // keeps hit area circular
                    .frame(width: 52, height: 52)

                Text("\(digit)")
                    .font(DesignSystem.headline)
                    .foregroundColor(.white)
            }
            .frame(width: 52, height: 52)
            .scaleEffect(pressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

/// A single wedge-shaped aperture blade.
private struct ApertureBlade: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.5, y: rect.midY - rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.5, y: rect.midY + rect.height * 0.15))
        path.closeSubpath()
        return path
    }
}