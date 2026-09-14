import SwiftUI

struct BrainSignalView: View {
    @StateObject private var viewModel = BrainSignalViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    heroSection
                    neuroScoreRing
                    cognitiveSkillGrid
                    if case .postGame(_, let insight, _) = viewModel.mode {
                        insightCallout(insight)
                    }
                    waveformStack
                    parameterGrid
                    if case .postGame(let game, _, _) = viewModel.mode {
                        explainerCard(game)
                    }
                    disclaimer
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }.foregroundColor(.white)
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: Hero

    @ViewBuilder
    private var heroSection: some View {
        switch viewModel.mode {
        case .idle:
            VStack(spacing: DesignSystem.Spacing.sm) {
                statusBadge
                Text("Brain Activity").font(DesignSystem.title).foregroundColor(.white)
                Text("Play a game, then come back here to see your session report.")
                    .font(DesignSystem.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        case .postGame(let game, _, let timestamp):
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.xxs) {
                    Image(systemName: game.iconName).foregroundColor(.white).font(.system(size: 12))
                    Text(game.category.rawValue).font(DesignSystem.caption).foregroundColor(.white)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xxs)
                .background(game.category.gradient)
                .clipShape(Capsule())

                Text("Your Brain During \(game.name)")
                    .font(DesignSystem.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(relativeString(timestamp))
                    .font(DesignSystem.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var statusBadge: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle().fill(viewModel.connectionState == .live ? Color.green : Color.yellow).frame(width: 8, height: 8)
            Text(viewModel.connectionState == .live ? "Live Signal" : "Connecting…")
                .font(DesignSystem.subheadline).foregroundColor(.white.opacity(0.8))
        }
    }

    private func relativeString(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return "Captured " + f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: Neuro score ring

    private var neuroScoreRing: some View {
        let gradient: LinearGradient = {
            if case .postGame(let game, _, _) = viewModel.mode { return game.category.gradient }
            return DesignSystem.primaryGradient
        }()
        let score = viewModel.parameters.focus * 0.5 + viewModel.parameters.calm * 0.3 + viewModel.parameters.signalQuality * 0.2
        return NeuroScoreRing(value: score, gradient: gradient)
    }

    // MARK: Cognitive skill breakdown (new)

    private var cognitiveSkillGrid: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Cognitive Skill Breakdown")
                .font(DesignSystem.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                ForEach(GameCategory.allCases) { category in
                    CognitiveScoreCard(
                        category: category,
                        score: viewModel.categoryScores[category] ?? 0.5,
                        isHighlighted: highlightedCategory == category
                    )
                }
            }
        }
    }

    private var highlightedCategory: GameCategory? {
        if case .postGame(let game, _, _) = viewModel.mode { return game.category }
        return nil
    }

    private func insightCallout(_ insight: PostGameBrainSignalSource.SessionInsight) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "sparkles").foregroundColor(.white)
            Text(insight.changeDescription).font(DesignSystem.subheadline).foregroundColor(.white)
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.primaryGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
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

    private func explainerCard(_ game: GameCatalog.Game) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Why This Happens").font(DesignSystem.headline).foregroundColor(.white)
            Text(game.scienceExplainer).font(DesignSystem.subheadline).foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private var disclaimer: some View {
        Text("Hardware pairing is still in progress — this is a preview using simulated signal data.")
            .font(DesignSystem.caption)
            .foregroundColor(.white.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.bottom, DesignSystem.Spacing.md)
    }
}

private struct NeuroScoreRing: View {
    let value: Double
    let gradient: LinearGradient

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 10)
            Circle()
                .trim(from: 0, to: value)
                .stroke(gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: value)
            VStack(spacing: 2) {
                Text("\(Int(value * 100))").font(DesignSystem.largeTitle).foregroundColor(.white)
                Text("Neuro Score").font(DesignSystem.caption).foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(width: 140, height: 140)
    }
}

private struct CognitiveScoreCard: View {
    let category: GameCategory
    let score: Double
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: category.glyphName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(category.gradient)
                Spacer()
                if isHighlighted {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            Text(category.rawValue)
                .font(DesignSystem.caption)
                .foregroundColor(.white.opacity(0.7))
            Text("\(Int(score * 100))%")
                .font(DesignSystem.title2)
                .foregroundColor(.white)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(category.gradient).frame(width: geo.size.width * score)
                }
            }
            .frame(height: 5)
        }
        .padding(DesignSystem.Spacing.md)
        .background(isHighlighted ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                .stroke(isHighlighted ? Color.white.opacity(0.3) : .clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }
}

private extension GameCategory {
    /// Local to this feature only — GameCatalog's icons are per-game,
    /// not per-category, so this doesn't touch DesignSystem or GameCatalog.
    var glyphName: String {
        switch self {
        case .speed: return "speedometer"
        case .memory: return "brain.head.profile"
        case .attention: return "eye"
        case .flexibility: return "arrow.triangle.2.circlepath"
        case .problemSolving: return "puzzlepiece.fill"
        case .math: return "plusminus.circle.fill"
        }
    }
}

private struct BrainWaveRow: View {
    let band: BrainWaveBand
    @ObservedObject var viewModel: BrainSignalViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            HStack {
                Text(band.rawValue).font(DesignSystem.subheadline).foregroundColor(.white.opacity(0.85))
                Text(band.frequencyLabel).font(DesignSystem.caption).foregroundColor(.white.opacity(0.4))
                Spacer()
            }
            TimelineView(.animation) { context in
                Canvas { ctx, size in
                    let path = wavePath(in: size, referenceDate: context.date)
                    ctx.stroke(path, with: .linearGradient(Gradient(colors: band.strokeColors), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), lineWidth: 2)
                }
            }
            .frame(height: 44)
        }
    }

    private func wavePath(in size: CGSize, referenceDate: Date) -> Path {
        var path = Path()
        let now = referenceDate.timeIntervalSinceReferenceDate
        let pixelsPerSecond: Double = 40
        let step: CGFloat = 2
        let midY = size.height / 2
        var x: CGFloat = 0
        var first = true
        while x <= size.width {
            let t = now - Double(size.width - x) / pixelsPerSecond
            let amp = viewModel.amplitudes(at: t)[band] ?? 0
            let y = midY - CGFloat(amp) * (size.height / 2 - 4)
            if first { path.move(to: CGPoint(x: x, y: y)); first = false } else { path.addLine(to: CGPoint(x: x, y: y)) }
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
            Text(title).font(DesignSystem.caption).foregroundColor(.white.opacity(0.6))
            Text("\(Int(value * 100))%").font(DesignSystem.title2).foregroundColor(.white)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(DesignSystem.primaryGradient).frame(width: geo.size.width * value)
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