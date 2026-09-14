import SwiftUI

struct BrainSignalView: View {
    @StateObject private var viewModel: BrainSignalViewModel
    @Environment(\.dismiss) private var dismiss

    init(activeGameName: String? = nil) {
        _viewModel = StateObject(wrappedValue: BrainSignalViewModel(activeGameName: activeGameName))
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    header
                    if let gameName = viewModel.activeGameName {
                        gameplayBanner(gameName)
                    }
                    waveformStack
                    parameterGrid
                    disclaimer
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundColor(.white)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var header: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(viewModel.connectionState == .live ? Color.green : Color.yellow)
                    .frame(width: 8, height: 8)
                Text(viewModel.connectionState == .live ? "Live Signal" : "Connecting…")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            Text("Brain Activity")
                .font(DesignSystem.title)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }

    private func gameplayBanner(_ gameName: String) -> some View {
        Text("Simulating during: \(gameName)")
            .font(DesignSystem.caption)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(DesignSystem.primaryGradient)
            .clipShape(Capsule())
    }

    private var waveformStack: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(BrainWaveBand.allCases) { band in
                BrainWaveRow(band: band, viewModel: viewModel)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private var parameterGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
            ParameterCard(title: "Focus", value: viewModel.parameters.focus)
            ParameterCard(title: "Calm", value: viewModel.parameters.calm)
            ParameterCard(title: "Workload", value: viewModel.parameters.workload)
            ParameterCard(title: "Signal Quality", value: viewModel.parameters.signalQuality)
        }
    }

    private var disclaimer: some View {
        Text("Hardware pairing is still in progress — this is a preview using simulated signal data.")
            .font(DesignSystem.caption)
            .foregroundColor(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.bottom, DesignSystem.Spacing.md)
    }
}

private struct BrainWaveRow: View {
    let band: BrainWaveBand
    @ObservedObject var viewModel: BrainSignalViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            HStack {
                Text(band.rawValue)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                Text(band.frequencyLabel)
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            TimelineView(.animation) { context in
                Canvas { canvasContext, size in
                    let path = wavePath(in: size, referenceDate: context.date)
                    canvasContext.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: band.strokeColors),
                            startPoint: .zero,
                            endPoint: CGPoint(x: size.width, y: 0)
                        ),
                        lineWidth: 2
                    )
                }
            }
            .frame(height: 44)
        }
    }

    /// x maps to elapsed time, so the trace looks like it's continuously
    /// scrolling left even though nothing is actually being buffered.
    private func wavePath(in size: CGSize, referenceDate: Date) -> Path {
        var path = Path()
        let now = referenceDate.timeIntervalSinceReferenceDate
        let pixelsPerSecond: Double = 40
        let step: CGFloat = 2
        let midY = size.height / 2

        var x: CGFloat = 0
        var first = true
        while x <= size.width {
            let timeAtX = now - Double(size.width - x) / pixelsPerSecond
            let amplitude = viewModel.amplitudes(at: timeAtX)[band] ?? 0
            let y = midY - CGFloat(amplitude) * (size.height / 2 - 4)
            if first { path.move(to: CGPoint(x: x, y: y)); first = false }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
            x += step
        }
        return path
    }
}

private struct ParameterCard: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.caption)
                .foregroundColor(.white.opacity(0.6))
            Text("\(Int(value * 100))%")
                .font(DesignSystem.title2)
                .foregroundColor(.white)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule()
                        .fill(DesignSystem.primaryGradient)
                        .frame(width: geo.size.width * value)
                }
            }
            .frame(height: 6)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

#Preview {
    NavigationStack { BrainSignalView() }
}