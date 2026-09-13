import SwiftUI
import UIKit

// MARK: - TrailMakingView
//
// Connect-the-dots subtest. Mode A: tap 1→2→3… in order. Mode B:
// alternates number/letter (1→A→2→B…). Node layout is randomized
// fresh each time the view appears (see generatePositions) so the
// pattern is never the same twice.

struct TrailMakingView: View {
    enum Mode {
        case a
        case b

        var nodeCount: Int {
            switch self {
            case .a: return 12
            case .b: return 12
            }
        }

        var labels: [String] {
            switch self {
            case .a:
                return (1...nodeCount).map(String.init)
            case .b:
                // Alternate 1, A, 2, B, 3, C...
                var result: [String] = []
                let letters = "ABCDEFGHIJKL".map(String.init)
                for i in 0..<(nodeCount / 2) {
                    result.append(String(i + 1))
                    result.append(letters[i])
                }
                return result
            }
        }
    }

    let mode: Mode
    /// (correctTapsInOrder, totalNodes, durationSeconds)
    let onComplete: (Int, Int, Int) -> Void

    @State private var nodePositions: [CGPoint] = []
    @State private var nextExpectedIndex: Int = 0
    @State private var wrongTapNodeID: Int?
    @State private var bounceNodeID: Int?
    @State private var pathProgress: CGFloat = 0
    @State private var pulseActive: Bool = false
    @State private var isFinishing = false
    @State private var startedAt = Date()
    @State private var timeRemaining: Int
    private let timeLimit: Int

    init(mode: Mode, onComplete: @escaping (Int, Int, Int) -> Void) {
        self.mode = mode
        self.onComplete = onComplete
        self.timeLimit = mode == .a ? 60 : 90
        _timeRemaining = State(initialValue: mode == .a ? 60 : 90)
    }

    private var labels: [String] { mode.labels }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundView

                if nodePositions.count > 1 {
                    TrailPathShape(points: nodePositions, progress: pathProgress)
                        .stroke(
                            DesignSystem.attentionGradient,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color(hex: "#00C2A8").opacity(0.25), radius: 3)
                }

                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    if index < nodePositions.count {
                        nodeView(index: index, label: label)
                            .position(nodePositions[index])
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                if nodePositions.isEmpty {
                    nodePositions = Self.generatePositions(count: mode.nodeCount, in: geo.size)
                }
                pulseActive = true
                startTimer()
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
        .overlay(alignment: .top) {
            timerRing
                .padding(.top, DesignSystem.Spacing.xxs)
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            DesignSystem.backgroundMain

            Circle()
                .fill(DesignSystem.attentionGradient)
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .opacity(0.16)
                .offset(x: -130, y: -220)

            Circle()
                .fill(DesignSystem.primaryGradient)
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .opacity(0.12)
                .offset(x: 130, y: 240)

            DotGridBackground(color: DesignSystem.backgroundOnboarding.opacity(0.05))
        }
        .ignoresSafeArea()
    }

    // MARK: - Timer ring

    private var timerRing: some View {
        let fraction = timeLimit > 0 ? CGFloat(timeRemaining) / CGFloat(timeLimit) : 0
        let isUrgent = timeRemaining <= 10

        return ZStack {
            Circle()
                .stroke(DesignSystem.backgroundOnboarding.opacity(0.1), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, fraction))
                .stroke(
                    isUrgent ? AnyShapeStyle(Color.red) : AnyShapeStyle(DesignSystem.attentionGradient),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timeRemaining)
            Text("\(timeRemaining)")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.7))
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Node

    private func nodeView(index: Int, label: String) -> some View {
        let isCompleted = index < nextExpectedIndex
        let isNext = index == nextExpectedIndex
        let isWrong = wrongTapNodeID == index
        let isBouncing = bounceNodeID == index

        return ZStack {
            if isNext {
                Circle()
                    .stroke(DesignSystem.attentionGradient, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .scaleEffect(pulseActive ? 1.5 : 1.0)
                    .opacity(pulseActive ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.1).repeatForever(autoreverses: false),
                        value: pulseActive
                    )
            }

            Circle()
                .fill(
                    isCompleted
                        ? AnyShapeStyle(DesignSystem.attentionGradient)
                        : AnyShapeStyle(
                            RadialGradient(
                                colors: [Color.white, Color(hex: "#DCEFEA")],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 34
                            )
                          )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    // Glass highlight
                    Circle()
                        .trim(from: 0.5, to: 0.97)
                        .stroke(Color.white.opacity(isCompleted ? 0.5 : 0.9), lineWidth: 3)
                        .rotationEffect(.degrees(-45))
                        .blur(radius: 0.5)
                        .padding(3)
                )
                .overlay(
                    Circle().stroke(
                        isWrong ? Color.red : DesignSystem.backgroundOnboarding.opacity(0.12),
                        lineWidth: isWrong ? 2.5 : 1
                    )
                )
                .overlay(
                    Text(label)
                        .font(DesignSystem.headline)
                        .foregroundColor(isCompleted ? .white : DesignSystem.backgroundOnboarding)
                )
                .shadow(
                    color: isCompleted ? Color(hex: "#00C2A8").opacity(0.4) : Color(hex: "#00C2A8").opacity(0.15),
                    radius: isCompleted ? 6 : 3,
                    y: 2
                )
                .scaleEffect(isBouncing ? 1.25 : 1.0)
                .modifier(ShakeEffect(animatableData: isWrong ? 1 : 0))
        }
        .onTapGesture { handleTap(on: index) }
    }

    private func handleTap(on index: Int) {
        guard !isFinishing else { return }

        guard index == nextExpectedIndex else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.linear(duration: 0.35)) {
                wrongTapNodeID = index
            }
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                withAnimation { wrongTapNodeID = nil }
            }
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        bounceNodeID = index
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            nextExpectedIndex += 1
            pathProgress = CGFloat(max(0, nextExpectedIndex - 1))
        }
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            bounceNodeID = nil
        }

        if nextExpectedIndex == labels.count {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isFinishing = true
            Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                finish()
            }
        }
    }

    private func startTimer() {
        Task {
            while timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard nextExpectedIndex < labels.count else { return }
                timeRemaining -= 1
            }
            if nextExpectedIndex < labels.count {
                finish()
            }
        }
    }

    private func finish() {
        let duration = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
        onComplete(nextExpectedIndex, labels.count, duration)
    }

    /// Generates a fresh random layout every call — no fixed seed —
    /// so the pattern differs on every playthrough. Uses simple
    /// rejection sampling to keep nodes from spawning too close
    /// together or overlapping.
    private static func generatePositions(count: Int, in size: CGSize) -> [CGPoint] {
        var points: [CGPoint] = []
        let margin: CGFloat = 30
        let minDistance: CGFloat = 62
        let maxAttemptsPerPoint = 200

        let usableWidth = max(margin + 1, size.width - margin)
        let usableHeight = max(margin + 1, size.height - margin)

        for _ in 0..<count {
            var placed = false
            var attempt = 0
            while !placed && attempt < maxAttemptsPerPoint {
                let candidate = CGPoint(
                    x: CGFloat.random(in: margin...usableWidth),
                    y: CGFloat.random(in: margin...usableHeight)
                )
                let farEnough = points.allSatisfy { existing in
                    let dx = existing.x - candidate.x
                    let dy = existing.y - candidate.y
                    return (dx * dx + dy * dy) >= (minDistance * minDistance)
                }
                if farEnough {
                    points.append(candidate)
                    placed = true
                }
                attempt += 1
            }
            if !placed {
                // Fallback: accept a random point anyway rather than
                // looping forever if the canvas is too small/crowded.
                points.append(CGPoint(
                    x: CGFloat.random(in: margin...usableWidth),
                    y: CGFloat.random(in: margin...usableHeight)
                ))
            }
        }
        return points
    }
}

// MARK: - TrailPathShape
//
// Animatable path that progressively reveals the connecting line as
// `progress` increases (integer part = fully-drawn segments, fractional
// part = partial next segment), so the trail visibly "draws itself" on
// each correct tap rather than snapping in.
private struct TrailPathShape: Shape {
    var points: [CGPoint]
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1, progress > 0 else { return path }

        path.move(to: points[0])
        let fullSegments = min(Int(progress), points.count - 1)
        if fullSegments >= 1 {
            for i in 1...fullSegments {
                path.addLine(to: points[i])
            }
        }

        let remainder = progress - CGFloat(fullSegments)
        if remainder > 0, fullSegments < points.count - 1 {
            let start = points[fullSegments]
            let end = points[fullSegments + 1]
            let x = start.x + (end.x - start.x) * remainder
            let y = start.y + (end.y - start.y) * remainder
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

// MARK: - DotGridBackground
//
// Faint dot-grid texture drawn once per frame via Canvas, used to give
// the subtest background subtle depth instead of a flat fill.
private struct DotGridBackground: View {
    var spacing: CGFloat = 26
    var dotSize: CGFloat = 2
    var color: Color

    var body: some View {
        Canvas { context, size in
            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    y += spacing
                }
                x += spacing
            }
        }
    }
}

// MARK: - ShakeEffect
//
// Horizontal oscillation used to signal a wrong tap on a node.
private struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 6
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = travelDistance * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}