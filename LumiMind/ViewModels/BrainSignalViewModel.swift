import Foundation
import Combine
import SwiftUI

/// Abstraction so a real hardware device can later plug into the exact
/// same interface the simulated source below implements — the view and
/// view model never need to change, only the concrete source.
protocol BrainSignalSource {
    func currentAmplitudes(at time: TimeInterval) -> [BrainWaveBand: Double]
    func currentParameters() -> BrainSignalParameters
}

enum BrainWaveBand: String, CaseIterable, Identifiable {
    case delta = "Delta"
    case theta = "Theta"
    case alpha = "Alpha"
    case beta = "Beta"
    case gamma = "Gamma"

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

    /// Mirrors DesignSystem's locked category-gradient hex values.
    /// (Duplicated here only because LinearGradient doesn't expose its
    /// stops — see note above about promoting these into DesignSystem.)
    var strokeColors: [Color] {
        switch self {
        case .delta: return [Color(hex: "#4A7BFF"), Color(hex: "#6FA8FF")] // problemSolvingGradient
        case .theta: return [Color(hex: "#9B3F8F"), Color(hex: "#D46BB5")] // memoryGradient
        case .alpha: return [Color(hex: "#00C2A8"), Color(hex: "#5EEAD4")] // attentionGradient
        case .beta:  return [Color(hex: "#FF5E5B"), Color(hex: "#FFB347")] // speedGradient
        case .gamma: return [Color(hex: "#F857A6"), Color(hex: "#FF7CA3")] // flexibilityGradient
        }
    }

    fileprivate var phaseSeed: Double {
        switch self {
        case .delta: return 0
        case .theta: return 1.3
        case .alpha: return 2.6
        case .beta:  return 3.9
        case .gamma: return 5.2
        }
    }

    fileprivate var baseFrequency: Double {
        switch self {
        case .delta: return 0.6
        case .theta: return 1.1
        case .alpha: return 1.8
        case .beta:  return 2.6
        case .gamma: return 3.4
        }
    }
}

struct BrainSignalParameters {
    var focus: Double
    var calm: Double
    var workload: Double
    var signalQuality: Double

    static let idle = BrainSignalParameters(focus: 0.3, calm: 0.6, workload: 0.2, signalQuality: 0.9)
}

/// Generates realistic-looking synthetic EEG-style data — layered sine
/// waves with drifting amplitude and light noise — so the full UI can
/// be built and demoed before real hardware is wired in.
struct SimulatedBrainSignalSource: BrainSignalSource {
    var isDuringGameplay: Bool = false

    func currentAmplitudes(at time: TimeInterval) -> [BrainWaveBand: Double] {
        var result: [BrainWaveBand: Double] = [:]
        for band in BrainWaveBand.allCases {
            let drift = sin(time * 0.07 + band.phaseSeed) * 0.15
            let noise = Double.random(in: -0.05...0.05)
            let raw = sin(time * band.baseFrequency + band.phaseSeed) * (0.5 + drift) + noise
            result[band] = max(-1, min(1, raw))
        }
        return result
    }

    func currentParameters() -> BrainSignalParameters {
        let activity = isDuringGameplay ? 0.25 : 0.0
        return BrainSignalParameters(
            focus: clamp(0.45 + activity + Double.random(in: -0.08...0.08)),
            calm: clamp(0.55 - activity + Double.random(in: -0.08...0.08)),
            workload: clamp(0.3 + activity + Double.random(in: -0.1...0.1)),
            signalQuality: clamp(0.85 + Double.random(in: -0.05...0.1))
        )
    }

    private func clamp(_ v: Double) -> Double { max(0, min(1, v)) }
}

@MainActor
final class BrainSignalViewModel: ObservableObject {
    enum ConnectionState { case connecting, live }

    @Published private(set) var parameters: BrainSignalParameters = .idle
    @Published private(set) var connectionState: ConnectionState = .connecting

    /// Passed in when opened from a game (phase 2 hook) — nil for the
    /// standalone Settings entry point.
    let activeGameName: String?

    private let source: BrainSignalSource
    private var parameterTimer: AnyCancellable?

    init(activeGameName: String? = nil, source: BrainSignalSource? = nil) {
        self.activeGameName = activeGameName
        self.source = source ?? SimulatedBrainSignalSource(isDuringGameplay: activeGameName != nil)
    }

    /// Sampled per-frame by the waveform's TimelineView — not @Published
    /// since it drives Canvas drawing directly rather than SwiftUI diffing.
    func amplitudes(at time: TimeInterval) -> [BrainWaveBand: Double] {
        source.currentAmplitudes(at: time)
    }

    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            self?.connectionState = .live
        }
        parameterTimer = Timer.publish(every: 1.4, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.parameters = self.source.currentParameters()
                }
            }
    }

    func stop() {
        parameterTimer?.cancel()
    }
}