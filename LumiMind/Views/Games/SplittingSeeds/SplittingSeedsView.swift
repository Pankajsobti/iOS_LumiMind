//
//  SplittingSeedsView.swift
//  LumiMind
//
//  Presentational only — renders the seed pile + rotating stick and
//  forwards the drag angle into the ViewModel's `updateStickAngle(to:)`,
//  and the lock-in tap into `lockIn()`. Header/HUD follows the same
//  pattern as the other five games (category gradient card). Play field
//  now carries a forest backdrop (leaves + simple bird silhouettes,
//  drawn natively rather than as bitmap assets) closer to the reference,
//  with a real wooden-look stick and larger, clearly-fixed teardrop seeds.
//

import SwiftUI

struct SplittingSeedsView: View {
    @StateObject private var viewModel: SplittingSeedsViewModel
    var onComplete: () -> Void

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SplittingSeedsViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            DesignSystem.backgroundMain.ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                header
                playField
                    .padding(.horizontal, DesignSystem.Spacing.md)
                lockInButton
            }
            .padding(.vertical, DesignSystem.Spacing.lg)

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…")
            }

            if case .finished(let score) = viewModel.phase {
                finishedOverlay(score: score)
            }
        }
    }

    // MARK: Header (TIME / SCORE / LEVEL + pips)

    private var header: some View {
        HStack {
            hudItem(label: "TIME", value: formattedTime)
            Spacer()
            hudItem(label: "SCORE", value: "\(viewModel.score)")
            Spacer()
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                Text("LEVEL \(viewModel.level)")
                    .font(DesignSystem.roundedFont(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                HStack(spacing: 5) {
                    ForEach(0..<SplittingSeedsViewModel.roundsPerLevel, id: \.self) { index in
                        Circle()
                            .fill(index < viewModel.roundInLevel ? .white : .white.opacity(0.35))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.mathGradient)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private func hudItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(label)
                .font(DesignSystem.roundedFont(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
            Text(value)
                .font(DesignSystem.headline)
                .foregroundColor(.white)
        }
    }

    private var formattedTime: String {
        let minutes = viewModel.timeRemaining / 60
        let seconds = viewModel.timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: Play field

    private var playField: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let playRadius = min(geo.size.width, geo.size.height) / 2 - DesignSystem.Spacing.md
            let stickLength = playRadius * 2.3

            ZStack {
                forestBackdrop(size: geo.size)

                // Stick — wooden
                woodenStick(length: stickLength)
                    .scaleEffect(viewModel.lastAnswerWasCorrect != nil ? 1.04 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.lastAnswerWasCorrect)
                    .rotationEffect(.radians(viewModel.stickAngle))
                    .position(center)

                // Pivot marker
                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color(hex: "#4A2E17").opacity(0.4), lineWidth: 2))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .position(center)

                // Seeds — fixed positions, teardrop shape, don't move
                ForEach(viewModel.seeds) { seed in
                    SeedShape()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#4A3728"), Color(hex: "#241811")],
                                startPoint: .top, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 20, height: 26)
                        .rotationEffect(.radians(seed.angle + .pi / 2))
                        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                        .position(seedPosition(seed, center: center, playRadius: playRadius))
                }

                // Count bubbles
                countBubble(count: viewModel.leftCount, isLeft: true, center: center, playRadius: playRadius)
                countBubble(count: viewModel.rightCount, isLeft: false, center: center, playRadius: playRadius)

                if let correct = viewModel.lastAnswerWasCorrect {
                    Text(correct ? "Correct!" : "Not quite")
                        .font(DesignSystem.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
                        .clipShape(Capsule())
                        .position(x: center.x, y: DesignSystem.Spacing.lg)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        guard dx != 0 || dy != 0 else { return }
                        viewModel.updateStickAngle(to: atan2(dy, dx))
                    }
            )
            .disabled(viewModel.phase != .playing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    // MARK: Forest backdrop (leaves + simple bird silhouettes, native-drawn)

    private func forestBackdrop(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#4E7A52"), Color(hex: "#3B5F40")],
                startPoint: .top, endPoint: .bottom
            )

            // Corner leaf clusters
            leafCluster
                .position(x: 28, y: 24)
            leafCluster
                .rotationEffect(.degrees(180))
                .position(x: size.width - 28, y: size.height - 24)

            // Two simple bird silhouettes, opposite corners — like the reference
            BirdSilhouette()
                .fill(Color(hex: "#6B4226"))
                .frame(width: 34, height: 26)
                .position(x: size.width - 40, y: 34)
            BirdSilhouette()
                .fill(Color(hex: "#6B4226"))
                .scaleEffect(x: -1, y: 1)
                .frame(width: 34, height: 26)
                .position(x: 40, y: size.height - 34)
        }
    }

    private var leafCluster: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "leaf.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#2F4D33").opacity(0.6))
                    .rotationEffect(.degrees(Double(i) * 35))
                    .offset(x: CGFloat(i) * 6, y: CGFloat(i) * 4)
            }
        }
    }

    private func seedPosition(_ seed: SplittingSeedsViewModel.Seed, center: CGPoint, playRadius: CGFloat) -> CGPoint {
        let r = playRadius * seed.radiusFraction
        return CGPoint(
            x: center.x + r * cos(seed.angle),
            y: center.y + r * sin(seed.angle)
        )
    }

    private func woodenStick(length: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#A9764B"), Color(hex: "#6B4226")],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: length, height: 14)
            .overlay(
                Capsule().stroke(Color(hex: "#4A2E17").opacity(0.5), lineWidth: 1)
            )
            .overlay(
                HStack(spacing: length / 7) {
                    ForEach(0..<6, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(hex: "#4A2E17").opacity(0.22))
                            .frame(width: 1)
                    }
                }
                .frame(width: length, height: 14)
                .clipShape(Capsule())
            )
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    /// Bubble sits at a fixed offset perpendicular-ish to the stick on its
    /// respective side, rotating with the stick so it stays visually paired
    /// with the seeds on that side.
    private func countBubble(count: Int, isLeft: Bool, center: CGPoint, playRadius: CGFloat) -> some View {
        let perpendicular = viewModel.stickAngle + (isLeft ? .pi / 2 : -.pi / 2)
        let r = playRadius * 0.55
        let position = CGPoint(
            x: center.x + r * cos(perpendicular),
            y: center.y + r * sin(perpendicular)
        )
        return Text("\(count)")
            .font(DesignSystem.roundedFont(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 34, height: 34)
            .background(DesignSystem.mathGradient)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .position(position)
            .animation(.easeOut(duration: 0.12), value: count)
    }

    // MARK: Lock-in button

    private var lockInButton: some View {
        Button {
            viewModel.lockIn()
        } label: {
            Text("Lock In Split")
                .font(DesignSystem.buttonLabel)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.primaryGradient)
        .clipShape(Capsule())
        .padding(.horizontal, DesignSystem.Spacing.md)
        .disabled(viewModel.phase != .playing)
    }

    // MARK: Overlays

    private func statusOverlay(message: String) -> some View {
        ZStack {
            DesignSystem.backgroundOnboarding.opacity(0.55).ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView().tint(DesignSystem.backgroundMain)
                Text(message)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundMain)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.backgroundOnboarding)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        }
    }

    private func finishedOverlay(score: Int) -> some View {
        ZStack {
            DesignSystem.backgroundOnboarding.opacity(0.55).ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Nice work!")
                    .font(DesignSystem.title2)
                    .foregroundColor(DesignSystem.backgroundMain)

                Text("Score: \(score)")
                    .font(DesignSystem.roundedFont(size: 28, weight: .bold))
                    .foregroundColor(DesignSystem.backgroundMain)

                if let error = viewModel.submissionErrorMessage {
                    Text(error)
                        .font(DesignSystem.caption)
                        .foregroundColor(Color(hex: "#FF6B4A"))
                        .multilineTextAlignment(.center)
                }

                Button(action: onComplete) {
                    Text("Continue")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
                .buttonStyle(.plain)
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: 320)
            .background(DesignSystem.backgroundOnboarding)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
        }
    }
}

// MARK: - SeedShape

/// Simple teardrop, point-up before rotation.
private struct SeedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: h * 0.65), control: CGPoint(x: w * 0.95, y: h * 0.15))
        path.addArc(center: CGPoint(x: w / 2, y: h * 0.65), radius: w / 2, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        path.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: w * 0.05, y: h * 0.15))
        path.closeSubpath()
        return path
    }
}

// MARK: - BirdSilhouette

/// A minimal, single-color bird silhouette — round body, small head, beak,
/// simple tail. Drawn natively (no bitmap asset) to stay consistent with
/// the app's flat, token-driven art direction.
private struct BirdSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Body
        path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.25, width: w * 0.6, height: h * 0.6))
        // Head
        path.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.05, width: w * 0.35, height: h * 0.35))
        // Beak
        path.move(to: CGPoint(x: w * 0.9, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 1.0, y: h * 0.24))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.3))
        path.closeSubpath()
        // Tail
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.5))
        path.addLine(to: CGPoint(x: 0, y: h * 0.35))
        path.addLine(to: CGPoint(x: 0, y: h * 0.6))
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    SplittingSeedsView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}