//
//  SplittingSeedsView.swift
//  LumiMind
//
//  Presentational only — renders the seed pile + rotating stick and
//  forwards the drag angle into the ViewModel's `updateStickAngle(to:)`,
//  and the lock-in tap into `lockIn()`. Seeds have a fixed "home" angle
//  used for scoring (unchanged, lives in the ViewModel), but their
//  DISPLAY position is nudged here as the stick sweeps near them —
//  simulating the stick physically pushing seeds aside — then springs
//  back once the stick passes. Purely visual; does not affect gameplay.
//
//  This revision layers in a richer forest arena, a wood-grain stick
//  with tip caps and a drag glow, glossy seeds with idle wobble, a
//  "ready to lock" glow once the current split matches the target, a
//  confetti burst on correct answers, a level-up celebration banner,
//  and glassmorphism-styled HUD cards. Nothing here changes scoring —
//  every visual effect reads from the ViewModel's existing published
//  state (or from purely local @State), never writes gameplay truth.
//

import SwiftUI

// MARK: - SplittingSeedsView

struct SplittingSeedsView: View {
    @StateObject private var viewModel: SplittingSeedsViewModel
    var onComplete: () -> Void

    // Ambient / decorative state — none of this feeds back into gameplay.
    @State private var pivotPulse = false
    @State private var isDragging = false
    @State private var ambientPhase: CGFloat = 0
    @State private var confettiBurstID = 0
    @State private var showLevelUpBanner = false
    @State private var lastCelebratedLevel = 1
    @State private var scoreDisplay: Int = 0

    init(gameResultViewModel: GameResultViewModel, isFitTest: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: SplittingSeedsViewModel(gameResultViewModel: gameResultViewModel, isFitTest: isFitTest))
        self.onComplete = onComplete
    }

    /// True once the live left/right split equals the round's two targets
    /// (order-independent) — drives the "ready to lock" glow before the
    /// user even taps. Purely a display hint; `lockIn()` still re-checks.
    private var isSplitMatchingTarget: Bool {
        [viewModel.leftCount, viewModel.rightCount].sorted() == [viewModel.targetGroupA, viewModel.targetGroupB].sorted()
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(phase: ambientPhase)
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                header
                targetBanner
                playField
                    .padding(.horizontal, DesignSystem.Spacing.md)
                lockInButton
            }
            .padding(.vertical, DesignSystem.Spacing.lg)

            if showLevelUpBanner {
                LevelUpBanner(level: viewModel.level)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                    .zIndex(5)
            }

            if case .submitting = viewModel.phase {
                statusOverlay(message: "Saving your result…")
                    .transition(.opacity)
                    .zIndex(10)
            }

            if case .finished(let score) = viewModel.phase {
                finishedOverlay(score: score)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pivotPulse = true
            }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                ambientPhase = 1
            }
            scoreDisplay = viewModel.score
            lastCelebratedLevel = viewModel.level
        }
        .onChange(of: viewModel.score) { newValue in
            withAnimation(.easeOut(duration: 0.45)) {
                scoreDisplay = newValue
            }
        }
        .onChange(of: viewModel.level) { newLevel in
            guard newLevel != lastCelebratedLevel else { return }
            lastCelebratedLevel = newLevel
            guard newLevel > 1 else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showLevelUpBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showLevelUpBanner = false
                }
            }
        }
        .onChange(of: viewModel.lastAnswerWasCorrect) { newValue in
            if newValue == true {
                confettiBurstID += 1
            }
        }
    }

    // MARK: Header (TIME / SCORE / LEVEL + pips)

    private var header: some View {
        HStack(alignment: .center) {
            hudItem(icon: "clock.fill", label: "TIME", value: formattedTime)

            Spacer(minLength: 4)

            VStack(spacing: 2) {
                Text("\(scoreDisplay)")
                    .font(DesignSystem.roundedFont(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("SCORE")
                    .font(DesignSystem.roundedFont(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xxs) {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11))
                    Text("LEVEL \(viewModel.level)")
                        .font(DesignSystem.roundedFont(size: 13, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 5) {
                    ForEach(0..<SplittingSeedsViewModel.roundsPerLevel, id: \.self) { index in
                        Capsule()
                            .fill(index < viewModel.roundInLevel ? Color.white : Color.white.opacity(0.32))
                            .frame(width: index < viewModel.roundInLevel ? 16 : 7, height: 7)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.roundInLevel)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            ZStack {
                DesignSystem.mathGradient
                LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#2ECC71").opacity(0.28), radius: 14, y: 6)
        .padding(.horizontal, DesignSystem.Spacing.md)
    }

    private func hudItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(DesignSystem.roundedFont(size: 12, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.82))
            Text(value)
                .font(DesignSystem.headline)
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private var formattedTime: String {
        let minutes = viewModel.timeRemaining / 60
        let seconds = viewModel.timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: Target banner

    private var targetBanner: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(DesignSystem.backgroundOnboarding.opacity(0.16))
                    .frame(width: 28, height: 28)
                Image(systemName: "divide.circle.fill")
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.8))
            }

            Text("Split into ")
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.8))
            + Text("\(viewModel.targetGroupA)")
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .fontWeight(.bold)
            + Text(" and ")
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.8))
            + Text("\(viewModel.targetGroupB)")
                .foregroundColor(DesignSystem.backgroundOnboarding)
                .fontWeight(.bold)

            if isSplitMatchingTarget && viewModel.phase == .playing {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#2ECC71"))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .font(DesignSystem.headline)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(.ultraThinMaterial)
        .background(.white.opacity(0.35))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(isSplitMatchingTarget ? Color(hex: "#2ECC71").opacity(0.7) : .white.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .id("\(viewModel.targetGroupA)-\(viewModel.targetGroupB)")
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.targetGroupA)
        .animation(.easeInOut(duration: 0.25), value: isSplitMatchingTarget)
    }

    // MARK: Play field

    private var playField: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let playRadius = min(geo.size.width, geo.size.height) / 2 - DesignSystem.Spacing.md
            let stickLength = playRadius * 2.3

            ZStack {
                arenaBackdrop(size: geo.size)

                RadialGradient(
                    colors: [.clear, .black.opacity(0.16)],
                    center: .center,
                    startRadius: playRadius * 0.4,
                    endRadius: playRadius * 1.3
                )

                soilPatch(radius: playRadius * 0.42)
                    .position(center)

                woodenStick(length: stickLength)
                    .scaleEffect(viewModel.lastAnswerWasCorrect != nil ? 1.04 : 1.0)
                    .rotation3DEffect(.degrees(isDragging ? 4 : 0), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                    .rotationEffect(.radians(viewModel.stickAngle))
                    .shadow(color: isDragging ? Color(hex: "#FFD166").opacity(0.55) : .clear, radius: isDragging ? 18 : 0)
                    .animation(.interpolatingSpring(stiffness: 260, damping: 22), value: viewModel.stickAngle)
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: viewModel.lastAnswerWasCorrect)
                    .animation(.easeOut(duration: 0.2), value: isDragging)
                    .position(center)

                pivotMarker
                    .position(center)

                // Seeds — home angle fixed (scoring truth), but display
                // position is nudged aside as the stick sweeps near them.
                ForEach(viewModel.seeds) { seed in
                    seedView(seed)
                        .position(seedDisplayPosition(seed, center: center, playRadius: playRadius, stickAngle: viewModel.stickAngle))
                        .animation(.interpolatingSpring(stiffness: 300, damping: 18), value: viewModel.stickAngle)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                        .id(seed.id)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.seeds)

                countBubble(count: viewModel.leftCount, isLeft: true, center: center, playRadius: playRadius, isMatched: isSplitMatchingTarget)
                countBubble(count: viewModel.rightCount, isLeft: false, center: center, playRadius: playRadius, isMatched: isSplitMatchingTarget)

                ConfettiBurst(trigger: confettiBurstID)

                if let correct = viewModel.lastAnswerWasCorrect {
                    feedbackBanner(correct: correct, center: center)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        guard dx != 0 || dy != 0 else { return }
                        isDragging = true
                        viewModel.updateStickAngle(to: atan2(dy, dx))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .disabled(viewModel.phase != .playing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }

    // MARK: Forest arena backdrop

    private func arenaBackdrop(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#6AA36E"), Color(hex: "#3B5F40")],
                startPoint: .top, endPoint: .bottom
            )

            hillsSilhouette(size: size)

            leafCluster
                .position(x: 28, y: 24)
            leafCluster
                .rotationEffect(.degrees(180))
                .position(x: size.width - 28, y: size.height - 24)

            treeTrunk
                .position(x: 16, y: size.height - 6)
            treeTrunk
                .scaleEffect(x: -1, y: 1)
                .position(x: size.width - 16, y: 8)

            BirdSilhouette()
                .fill(Color(hex: "#6B4226"))
                .frame(width: 34, height: 26)
                .offset(y: sin(ambientPhase * 2 * .pi * 2) * 3)
                .position(x: size.width - 40, y: 34)
            BirdSilhouette()
                .fill(Color(hex: "#6B4226"))
                .scaleEffect(x: -1, y: 1)
                .frame(width: 34, height: 26)
                .offset(y: cos(ambientPhase * 2 * .pi * 2) * 3)
                .position(x: 40, y: size.height - 34)
        }
    }

    private func hillsSilhouette(size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height * 0.82))
            path.addCurve(
                to: CGPoint(x: size.width * 0.5, y: size.height * 0.9),
                control1: CGPoint(x: size.width * 0.2, y: size.height * 0.7),
                control2: CGPoint(x: size.width * 0.35, y: size.height * 0.95)
            )
            path.addCurve(
                to: CGPoint(x: size.width, y: size.height * 0.8),
                control1: CGPoint(x: size.width * 0.7, y: size.height * 0.85),
                control2: CGPoint(x: size.width * 0.85, y: size.height * 0.7)
            )
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
        .fill(Color(hex: "#2F4D33").opacity(0.35))
    }

    private var treeTrunk: some View {
        VStack(spacing: -6) {
            Circle()
                .fill(Color(hex: "#2F4D33").opacity(0.55))
                .frame(width: 26, height: 26)
            Rectangle()
                .fill(Color(hex: "#4A3728").opacity(0.4))
                .frame(width: 5, height: 18)
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

    private func soilPatch(radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#5B4331").opacity(0.5), .clear],
                    center: .center, startRadius: 0, endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
    }

    // MARK: Pivot

    private var pivotMarker: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.6), lineWidth: 2)
                .scaleEffect(pivotPulse ? 2.0 : 1.0)
                .opacity(pivotPulse ? 0 : 0.8)
                .frame(width: 14, height: 14)
            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color(hex: "#4A2E17").opacity(0.4), lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
    }

    /// Base position from the seed's fixed home angle (used for scoring, unchanged).
    private func seedPosition(_ seed: SplittingSeedsViewModel.Seed, center: CGPoint, playRadius: CGFloat) -> CGPoint {
        let r = playRadius * seed.radiusFraction
        return CGPoint(
            x: center.x + r * cos(seed.angle),
            y: center.y + r * sin(seed.angle)
        )
    }

    /// Display-only position: nudges the seed away from the stick's line as
    /// the stick sweeps close to the seed's home angle, and pushes it
    /// slightly outward too — simulating the stick physically shoving it
    /// aside. Springs back to its home position once the stick moves away.
    /// Scoring never reads this — only `seed.angle` (the fixed home angle).
    private func seedDisplayPosition(
        _ seed: SplittingSeedsViewModel.Seed,
        center: CGPoint,
        playRadius: CGFloat,
        stickAngle: Double
    ) -> CGPoint {
        let influenceZone = 0.5 // radians — how close the stick must get to start pushing
        let maxAngularPush = 0.4 // radians — max angular nudge at closest approach
        let maxRadialPush: CGFloat = 14 // points — max outward shove at closest approach

        var diff = seed.angle - stickAngle
        // Normalize to (-pi, pi]
        while diff > .pi { diff -= 2 * .pi }
        while diff <= -.pi { diff += 2 * .pi }
        let absDiff = abs(diff)

        guard absDiff < influenceZone else {
            return seedPosition(seed, center: center, playRadius: playRadius)
        }

        let closeness = (influenceZone - absDiff) / influenceZone // 0...1, 1 = stick right on top of seed
        let pushDirection: Double = diff >= 0 ? 1 : -1
        let nudgedAngle = seed.angle + pushDirection * maxAngularPush * closeness
        let nudgedRadius = playRadius * seed.radiusFraction + maxRadialPush * closeness

        return CGPoint(
            x: center.x + nudgedRadius * cos(nudgedAngle),
            y: center.y + nudgedRadius * sin(nudgedAngle)
        )
    }

    // MARK: Seed rendering

    private func seedView(_ seed: SplittingSeedsViewModel.Seed) -> some View {
        let wobble = sin(ambientPhase * 2 * .pi * 1.4 + Double(seed.id)) * 0.02
        return ZStack {
            SeedShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#4A3728"), Color(hex: "#241811")],
                        startPoint: .top, endPoint: .bottomTrailing
                    )
                )
            SeedShape()
                .trim(from: 0, to: 0.26)
                .stroke(Color.white.opacity(0.32), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .padding(3)
        }
        .frame(width: 20, height: 26)
        .rotationEffect(.radians(seed.angle + .pi / 2 + wobble))
        .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
    }

    private func woodenStick(length: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#B98254"), Color(hex: "#6B4226")],
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
                .overlay(
                    LinearGradient(colors: [.white.opacity(isDragging ? 0.35 : 0.15), .clear], startPoint: .top, endPoint: .bottom)
                        .clipShape(Capsule())
                )

            tipKnob.offset(x: length / 2 - 6)
            tipKnob.offset(x: -(length / 2 - 6))
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }

    private var tipKnob: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#8C6239"), Color(hex: "#4A2E17")],
                    center: .topLeading, startRadius: 1, endRadius: 14
                )
            )
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(Color(hex: "#4A2E17").opacity(0.6), lineWidth: 1))
    }

    private func countBubble(count: Int, isLeft: Bool, center: CGPoint, playRadius: CGFloat, isMatched: Bool) -> some View {
        let perpendicular = viewModel.stickAngle + (isLeft ? .pi / 2 : -.pi / 2)
        let r = playRadius * 0.55
        let position = CGPoint(
            x: center.x + r * cos(perpendicular),
            y: center.y + r * sin(perpendicular)
        )
        return Text("\(count)")
            .font(DesignSystem.roundedFont(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(isMatched ? AnyView(Color(hex: "#2ECC71")) : AnyView(DesignSystem.mathGradient))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .overlay(
                Circle()
                    .stroke(Color(hex: "#2ECC71").opacity(isMatched ? 0.8 : 0), lineWidth: 4)
                    .scaleEffect(isMatched ? 1.28 : 1.0)
            )
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .position(position)
            .animation(.interpolatingSpring(stiffness: 260, damping: 22), value: position.x)
            .animation(.spring(response: 0.25, dampingFraction: 0.45), value: count)
            .animation(.easeInOut(duration: 0.3), value: isMatched)
    }

    private func feedbackBanner(correct: Bool, center: CGPoint) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
            Text(correct ? "Correct!" : "Not quite")
                .font(DesignSystem.headline)
        }
        .foregroundColor(.white)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(correct ? Color(hex: "#2ECC71") : Color(hex: "#FF6B4A"))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        .position(x: center.x, y: DesignSystem.Spacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.lastAnswerWasCorrect)
    }

    // MARK: Lock-in button

    private var lockInButton: some View {
        Button {
            viewModel.lockIn()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: isSplitMatchingTarget ? "checkmark.seal.fill" : "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .bold))
                Text("Lock In Split")
                    .font(DesignSystem.buttonLabel)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .buttonStyle(PressableButtonStyle())
        .background(
            ZStack {
                DesignSystem.primaryGradient
                if isSplitMatchingTarget {
                    LinearGradient(colors: [.white.opacity(0.32), .clear], startPoint: .leading, endPoint: .trailing)
                        .blendMode(.overlay)
                }
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(hex: "#2ECC71").opacity(isSplitMatchingTarget ? 0.9 : 0), lineWidth: 3)
                .scaleEffect(isSplitMatchingTarget ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isSplitMatchingTarget)
        )
        .shadow(color: Color(hex: "#6D5DE7").opacity(isSplitMatchingTarget ? 0.55 : 0.35), radius: isSplitMatchingTarget ? 16 : 10, y: 5)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .disabled(viewModel.phase != .playing)
        .animation(.easeInOut(duration: 0.25), value: isSplitMatchingTarget)
    }

    // MARK: Overlays

    private func statusOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView()
                    .tint(DesignSystem.backgroundMain)
                    .scaleEffect(1.2)
                Text(message)
                    .font(DesignSystem.subheadline)
                    .foregroundColor(DesignSystem.backgroundMain)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(.ultraThinMaterial)
            .background(DesignSystem.backgroundOnboarding.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        }
    }

    private func finishedOverlay(score: Int) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.primaryGradient)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color(hex: "#6D5DE7").opacity(0.5), radius: 14, y: 6)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }

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
                .buttonStyle(PressableButtonStyle())
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial)
            .background(DesignSystem.backgroundOnboarding.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
            .overlay(ConfettiBurst(trigger: 1).allowsHitTesting(false))
        }
    }
}

// MARK: - PressableButtonStyle

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - SeedShape

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

private struct BirdSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.25, width: w * 0.6, height: h * 0.6))
        path.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.05, width: w * 0.35, height: h * 0.35))
        path.move(to: CGPoint(x: w * 0.9, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 1.0, y: h * 0.24))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.3))
        path.closeSubpath()
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.5))
        path.addLine(to: CGPoint(x: 0, y: h * 0.35))
        path.addLine(to: CGPoint(x: 0, y: h * 0.6))
        path.closeSubpath()

        return path
    }
}

// MARK: - AmbientBackdrop

/// Full-screen backdrop behind the whole game: a deep gradient with a
/// handful of drifting firefly-style particles whose positions are
/// derived purely from `phase` (0...1, looping) so no timers or extra
/// per-frame state are needed.
private struct AmbientBackdrop: View {
    let phase: CGFloat
    private let fireflyCount = 7

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#1F3B2C"), Color(hex: "#16241C")],
                    startPoint: .top, endPoint: .bottom
                )

                ForEach(0..<fireflyCount, id: \.self) { index in
                    let seed = CGFloat(index) * 47.0
                    let angle = (phase * 2 * .pi) + seed
                    let x = geo.size.width * (0.15 + 0.7 * (0.5 + 0.5 * sin(angle * 0.6 + seed)))
                    let y = geo.size.height * (0.1 + 0.8 * (0.5 + 0.5 * cos(angle * 0.8 + seed * 1.3)))
                    Circle()
                        .fill(Color(hex: "#FFE08A"))
                        .frame(width: 3, height: 3)
                        .shadow(color: Color(hex: "#FFE08A"), radius: 5)
                        .opacity(0.3 + 0.35 * sin(angle + seed))
                        .position(x: x, y: y)
                }

                RadialGradient(
                    colors: [.clear, .black.opacity(0.45)],
                    center: .center, startRadius: geo.size.width * 0.3, endRadius: geo.size.width
                )
            }
        }
    }
}

// MARK: - LevelUpBanner

private struct LevelUpBanner: View {
    let level: Int

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 34, weight: .bold))
            Text("Level \(level)!")
                .font(DesignSystem.roundedFont(size: 22, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(DesignSystem.primaryGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color(hex: "#6D5DE7").opacity(0.5), radius: 20, y: 10)
    }
}

// MARK: - ConfettiBurst

/// A short-lived confetti burst, re-triggered whenever `trigger` changes.
/// Pieces are generated on trigger and animated outward + downward with
/// fading opacity — purely decorative, no gameplay state involved.
private struct ConfettiBurst: View {
    let trigger: Int
    @State private var pieces: [Piece] = []

    private struct Piece: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
        var rotation: Double
        var scale: CGFloat
        var opacity: Double
    }

    private static let colors: [Color] = [
        Color(hex: "#2ECC71"), Color(hex: "#FFD166"), Color(hex: "#FF6B4A"),
        Color(hex: "#6D5DE7"), Color(hex: "#4FD1C5")
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(piece.color)
                        .frame(width: 6, height: 10)
                        .rotationEffect(.degrees(piece.rotation))
                        .scaleEffect(piece.scale)
                        .opacity(piece.opacity)
                        .position(x: piece.x, y: piece.y)
                }
            }
            .onChange(of: trigger) { newValue in
                guard newValue > 0 else { return }
                burst(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func burst(in size: CGSize) {
        let originX = size.width / 2
        let originY = size.height * 0.35
        pieces = (0..<18).map { _ in
            Piece(
                x: originX,
                y: originY,
                color: Self.colors.randomElement() ?? .white,
                rotation: Double.random(in: 0..<360),
                scale: CGFloat.random(in: 0.6...1.1),
                opacity: 1
            )
        }
        for index in pieces.indices {
            let dx = CGFloat.random(in: -90...90)
            let dy = CGFloat.random(in: 80...220)
            let duration = Double.random(in: 0.7...1.1)
            withAnimation(.easeOut(duration: duration).delay(Double.random(in: 0...0.08))) {
                pieces[index].x += dx
                pieces[index].y += dy
                pieces[index].rotation += Double.random(in: 180...540)
                pieces[index].opacity = 0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SplittingSeedsView(
        gameResultViewModel: GameResultViewModel(),
        onComplete: { print("Continue to ScienceExplainerView") }
    )
}