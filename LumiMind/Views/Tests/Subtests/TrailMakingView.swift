import SwiftUI
import UIKit

// MARK: - TrailMakingView
//
// Connect-the-dots subtest. Mode A: tap 1→2→3… in order. Mode B:
// alternates number/letter (1→A→2→B…). Nodes are scattered at fixed
// pseudo-random positions per mode so layout is stable across runs.

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
                    nodePositions = Self.generatePositions(count: mode.nodeCount, in: geo.size, seed: mode == .a ? 1 : 2)
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

            Text(label)
                .font(DesignSystem.headline)
                .foregroundColor(isCompleted ? .white : DesignSystem.backgroundOnboarding)
                .frame(width: 40, height: 40)
                .background(
                    isCompleted ? AnyShapeStyle(DesignSystem.attentionGradient) : AnyShapeStyle(Color.white)
                )
                .overlay(
                    Circle().stroke(
                        isWrong ? Color.red : DesignSystem.backgroundOnboarding.opacity(0.15),
                        lineWidth: isWrong ? 2.5 : 1
                    )
                )
                .clipShape(Circle())
                .shadow(
                    color: isCompleted ? DesignSystem.backgroundOnboarding.opacity(0.15) : .black.opacity(0.05),
                    radius: isCompleted ? 4 : 2,
                    y: 1
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

    private static func generatePositions(count: Int, in size: CGSize, seed: Int) -> [CGPoint] {
        var generator = SeededGenerator(seed: seed)
        var points: [CGPoint] = []
        let margin: CGFloat = 30
        for _ in 0..<count {
            let x = CGFloat.random(in: margin...(max(margin + 1, size.width - margin)), using: &generator)
            let y = CGFloat.random(in: margin...(max(margin + 1, size.height - margin)), using: &generator)
            points.append(CGPoint(x: x, y: y))
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

/// Minimal seeded RNG so node layout is stable across app launches
/// for a given mode, rather than reshuffling every run.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}