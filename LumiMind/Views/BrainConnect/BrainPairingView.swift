import SwiftUI

/// Purely cosmetic "device pairing" sequence for the pitch — no real
/// hardware is contacted. Sells the illusion before the toggle turns on.
struct BrainPairingView: View {
    var onConnected: () -> Void

    private enum Stage: Int, CaseIterable {
        case scanning, found, pairing, connected
        var title: String {
            switch self {
            case .scanning: "Scanning for devices…"
            case .found: "Found: LumiMind Neuroband"
            case .pairing: "Pairing…"
            case .connected: "Connected"
            }
        }
    }

    @State private var stage: Stage = .scanning
    @State private var pulse = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.primaryGradient, lineWidth: 3)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulse ? 1.15 : 0.9)
                    .opacity(pulse ? 0.2 : 0.6)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)

                Image(systemName: stage == .connected ? "checkmark.circle.fill" : "waveform.path.ecg")
                    .font(.system(size: 40))
                    .foregroundStyle(DesignSystem.primaryGradient)
            }
            .onAppear { pulse = true }

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(stage.title)
                    .font(DesignSystem.headline)
                    .foregroundColor(.white)
                    .id(stage)
                    .transition(.opacity)
                if stage != .connected {
                    Text("LumiMind Neuroband · EEG v1")
                        .font(DesignSystem.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Stage.allCases, id: \.self) { s in
                    Capsule()
                        .fill(s.rawValue <= stage.rawValue ? AnyShapeStyle(DesignSystem.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.15)))
                        .frame(width: s == stage ? 24 : 8, height: 6)
                        .animation(.spring(response: 0.4), value: stage)
                }
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.backgroundOnboarding.ignoresSafeArea())
        .onAppear { advance() }
    }

    private func advance() {
        let delays: [Stage: Double] = [.scanning: 1.4, .found: 1.1, .pairing: 1.6, .connected: 0.9]
        func step(_ current: Stage) {
            guard let delay = delays[current] else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let next = Stage(rawValue: current.rawValue + 1) else { return }
                withAnimation(.easeInOut) { stage = next }
                if next == .connected {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onConnected() }
                } else {
                    step(next)
                }
            }
        }
        step(.scanning)
    }
}