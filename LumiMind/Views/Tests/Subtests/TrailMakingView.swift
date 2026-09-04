import SwiftUI

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
                // Completed path
                Path { path in
                    guard nextExpectedIndex > 0, nodePositions.count > 1 else { return }
                    path.move(to: nodePositions[0])
                    for i in 1..<nextExpectedIndex {
                        path.addLine(to: nodePositions[i])
                    }
                }
                .stroke(DesignSystem.backgroundOnboarding.opacity(0.4), lineWidth: 2)

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
                startTimer()
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
        .overlay(alignment: .top) {
            Text("\(timeRemaining)s")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .padding(.top, DesignSystem.Spacing.xxs)
        }
    }

    private func nodeView(index: Int, label: String) -> some View {
        let isCompleted = index < nextExpectedIndex
        let isWrong = wrongTapNodeID == index

        return Text(label)
            .font(DesignSystem.headline)
            .foregroundColor(isCompleted ? .white : DesignSystem.backgroundOnboarding)
            .frame(width: 40, height: 40)
            .background(isCompleted ? AnyShapeStyle(mode == .a ? DesignSystem.attentionGradient : DesignSystem.attentionGradient) : AnyShapeStyle(Color.white))
            .overlay(
                Circle().stroke(isWrong ? Color.red : DesignSystem.backgroundOnboarding.opacity(0.15), lineWidth: isWrong ? 2 : 1)
            )
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .onTapGesture { handleTap(on: index) }
    }

    private func handleTap(on index: Int) {
        guard index == nextExpectedIndex else {
            wrongTapNodeID = index
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                wrongTapNodeID = nil
            }
            return
        }
        nextExpectedIndex += 1
        if nextExpectedIndex == labels.count {
            finish()
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