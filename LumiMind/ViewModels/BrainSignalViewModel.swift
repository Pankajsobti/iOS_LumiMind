import Foundation
import Combine
import SwiftUI

protocol BrainSignalSource {
    func currentAmplitudes(at time: TimeInterval) -> [BrainWaveBand: Double]
    func currentParameters() -> BrainSignalParameters
    func currentCategoryScores() -> [GameCategory: Double]
}

enum BrainWaveBand: String, CaseIterable, Identifiable {
    case delta = "Delta", theta = "Theta", alpha = "Alpha", beta = "Beta", gamma = "Gamma"

    var id: String { rawValue }

    var frequencyLabel: String {
        switch self {
        case .delta: return "0.5–4 Hz"
        case .theta: return "4–8 Hz"
        case .alpha: return "8–13 Hz"
        case .beta:  return "13–30 Hz"
        case .gamma: return "30–100 Hz"
        }
    }

    var strokeColors: [Color] {
        switch self {
        case .delta: return [Color(hex: "#4A7BFF"), Color(hex: "#6FA8FF")]
        case .theta: return [Color(hex: "#9B3F8F"), Color(hex: "#D46BB5")]
        case .alpha: return [Color(hex: "#00C2A8"), Color(hex: "#5EEAD4")]
        case .beta:  return [Color(hex: "#FF5E5B"), Color(hex: "#FFB347")]
        case .gamma: return [Color(hex: "#F857A6"), Color(hex: "#FF7CA3")]
        }
    }

    fileprivate var phaseSeed: Double {
        switch self { case .delta: 0; case .theta: 1.3; case .alpha: 2.6; case .beta: 3.9; case .gamma: 5.2 }
    }
    fileprivate var baseFrequency: Double {
        switch self { case .delta: 0.6; case .theta: 1.1; case .alpha: 1.8; case .beta: 2.6; case .gamma: 3.4 }
    }
}

struct BrainSignalParameters {
    var focus: Double, calm: Double, workload: Double, signalQuality: Double
    static let idle = BrainSignalParameters(focus: 0.3, calm: 0.6, workload: 0.2, signalQuality: 0.9)
}

// MARK: - Idle simulated source (no recent game played)

struct SimulatedBrainSignalSource: BrainSignalSource {
    func currentAmplitudes(at time: TimeInterval) -> [BrainWaveBand: Double] {
        var result: [BrainWaveBand: Double] = [:]
        for band in BrainWaveBand.allCases {
            let drift = sin(time * 0.07 + band.phaseSeed) * 0.15
            let noise = Double.random(in: -0.05...0.05)
            result[band] = max(-1, min(1, sin(time * band.baseFrequency + band.phaseSeed) * (0.5 + drift) + noise))
        }
        return result
    }

    func currentParameters() -> BrainSignalParameters {
        BrainSignalParameters(
            focus: clamp(0.45 + .random(in: -0.08...0.08)),
            calm: clamp(0.55 + .random(in: -0.08...0.08)),
            workload: clamp(0.3 + .random(in: -0.1...0.1)),
            signalQuality: clamp(0.88 + .random(in: -0.05...0.08))
        )
    }

    func currentCategoryScores() -> [GameCategory: Double] {
        var result: [GameCategory: Double] = [:]
        for category in GameCategory.allCases {
            result[category] = clamp(0.5 + Double.random(in: -0.12...0.12))
        }
        return result
    }

    private func clamp(_ v: Double) -> Double { max(0, min(1, v)) }
}

// MARK: - Post-game source (the actual demo payload)

struct BrainSeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xdeadbeef : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

struct PostGameBrainSignalSource: BrainSignalSource {
    struct SessionInsight { let dominantBand: BrainWaveBand; let changeDescription: String }

    let category: GameCategory
    private let seed: UInt64
    private let parameters: BrainSignalParameters

    init(category: GameCategory, seed: UInt64) {
        self.category = category
        self.seed = seed
        var gen = BrainSeededGenerator(seed: seed)
        let bias = Self.parameterBias(category)
        func jitter(_ base: Double) -> Double { max(0.15, min(0.97, base + Double.random(in: -0.09...0.09, using: &gen))) }
        parameters = BrainSignalParameters(
            focus: jitter(bias.focus), calm: jitter(bias.calm),
            workload: jitter(bias.workload), signalQuality: jitter(0.91)
        )
    }

    func currentAmplitudes(at time: TimeInterval) -> [BrainWaveBand: Double] {
        var result: [BrainWaveBand: Double] = [:]
        let dominance = Self.bandDominance(for: category)
        for band in BrainWaveBand.allCases {
            let amp = dominance[band] ?? 0.5
            let drift = sin(time * 0.09 + band.phaseSeed) * 0.1
            let noise = Double.random(in: -0.04...0.04)
            result[band] = max(-1, min(1, sin(time * band.baseFrequency + band.phaseSeed) * (amp + drift) + noise))
        }
        return result
    }

    func currentParameters() -> BrainSignalParameters { parameters }

    /// One score per cognitive category — the just-played game's own
    /// category scores highest, related categories get realistic
    /// spillover, and everything re-jitters slightly on every call.
    func currentCategoryScores() -> [GameCategory: Double] {
        var result: [GameCategory: Double] = [:]
        let baseline = Self.categoryBaseline(for: category)
        for cat in GameCategory.allCases {
            let base = baseline[cat] ?? 0.5
            result[cat] = max(0.12, min(0.98, base + Double.random(in: -0.05...0.05)))
        }
        return result
    }

    func insight() -> SessionInsight {
        var gen = BrainSeededGenerator(seed: seed &+ 99)
        let dominant = Self.bandDominance(for: category).max(by: { $0.value < $1.value })?.key ?? .beta
        let percent = Int.random(in: 12...31, using: &gen)
        return SessionInsight(dominantBand: dominant, changeDescription: "\(dominant.rawValue) activity rose ~\(percent)% during this session")
    }

    private static func parameterBias(_ c: GameCategory) -> (focus: Double, calm: Double, workload: Double) {
        switch c {
        case .speed: (0.78, 0.35, 0.72)
        case .memory: (0.72, 0.55, 0.60)
        case .attention: (0.80, 0.40, 0.65)
        case .flexibility: (0.70, 0.42, 0.75)
        case .problemSolving: (0.68, 0.50, 0.70)
        case .math: (0.74, 0.38, 0.68)
        }
    }

    private static func bandDominance(for c: GameCategory) -> [BrainWaveBand: Double] {
        switch c {
        case .speed:          [.delta: 0.25, .theta: 0.30, .alpha: 0.35, .beta: 0.75, .gamma: 0.55]
        case .memory:         [.delta: 0.30, .theta: 0.70, .alpha: 0.60, .beta: 0.40, .gamma: 0.30]
        case .attention:      [.delta: 0.25, .theta: 0.35, .alpha: 0.45, .beta: 0.70, .gamma: 0.65]
        case .flexibility:    [.delta: 0.30, .theta: 0.40, .alpha: 0.40, .beta: 0.65, .gamma: 0.60]
        case .problemSolving: [.delta: 0.35, .theta: 0.55, .alpha: 0.60, .beta: 0.50, .gamma: 0.35]
        case .math:           [.delta: 0.30, .theta: 0.40, .alpha: 0.45, .beta: 0.68, .gamma: 0.58]
        }
    }

    /// Own category scores highest; adjacent skills that plausibly
    /// share cognitive load get moderate spillover; the rest sit lower.
    private static func categoryBaseline(for c: GameCategory) -> [GameCategory: Double] {
        switch c {
        case .speed:
            [.speed: 0.88, .memory: 0.55, .attention: 0.70, .flexibility: 0.60, .problemSolving: 0.50, .math: 0.58]
        case .memory:
            [.speed: 0.52, .memory: 0.90, .attention: 0.62, .flexibility: 0.48, .problemSolving: 0.58, .math: 0.50]
        case .attention:
            [.speed: 0.60, .memory: 0.58, .attention: 0.89, .flexibility: 0.55, .problemSolving: 0.52, .math: 0.48]
        case .flexibility:
            [.speed: 0.58, .memory: 0.50, .attention: 0.60, .flexibility: 0.87, .problemSolving: 0.55, .math: 0.46]
        case .problemSolving:
            [.speed: 0.48, .memory: 0.60, .attention: 0.55, .flexibility: 0.58, .problemSolving: 0.90, .math: 0.62]
        case .math:
            [.speed: 0.55, .memory: 0.52, .attention: 0.50, .flexibility: 0.45, .problemSolving: 0.60, .math: 0.91]
        }
    }
}

// MARK: - View model

@MainActor
final class BrainSignalViewModel: ObservableObject {
    enum ConnectionState { case connecting, live }
    enum Mode {
        case idle
        case postGame(game: GameCatalog.Game, insight: PostGameBrainSignalSource.SessionInsight, timestamp: Date)
    }

    @Published private(set) var parameters: BrainSignalParameters = .idle
    @Published private(set) var categoryScores: [GameCategory: Double] =
        Dictionary(uniqueKeysWithValues: GameCategory.allCases.map { ($0, 0.5) })
    @Published private(set) var connectionState: ConnectionState = .connecting
    let mode: Mode

    private let source: BrainSignalSource
    private var parameterTimer: AnyCancellable?

    init() {
        if let session = BrainSessionRecorder.recentSession() {
            let seed = UInt64(session.timestamp.timeIntervalSince1970)
            let postGame = PostGameBrainSignalSource(category: session.game.category, seed: seed)
            source = postGame
            mode = .postGame(game: session.game, insight: postGame.insight(), timestamp: session.timestamp)
        } else {
            source = SimulatedBrainSignalSource()
            mode = .idle
        }
    }

    func amplitudes(at time: TimeInterval) -> [BrainWaveBand: Double] { source.currentAmplitudes(at: time) }

    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in self?.connectionState = .live }
        refresh()
        parameterTimer = Timer.publish(every: 1.6, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        withAnimation(.easeInOut(duration: 0.8)) {
            parameters = source.currentParameters()
            categoryScores = source.currentCategoryScores()
        }
    }

    func stop() { parameterTimer?.cancel() }
}