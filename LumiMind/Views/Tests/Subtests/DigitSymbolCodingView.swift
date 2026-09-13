import SwiftUI

// MARK: - DigitSymbolCodingView
//
// Symbol-matching subtest. Logic/timing/scoring below is UNCHANGED from
// the original pass — only the presentation layer was reworked into a
// new "Cipher Grid" theme: a dark glowing backdrop with a faint
// constellation texture (self-contained here, no new DesignSystem
// tokens added — same scoped-palette pattern LostInMigrationView /
// TrailMakingView already use), gradient "cipher key" chips instead of
// plain white squares, glassmorphic answer tiles that flash per-answer
// color, and circular progress rings wrapping both countdowns instead
// of bare "Ns" text.

struct DigitSymbolCodingView: View {
    /// (correctCount, attemptedCount, durationSeconds)
    let onComplete: (Int, Int, Int) -> Void

    private enum Phase {
        case initialStudy
        case quiz
        case restudy
    }

    private static let timeLimit = 90
    private static let initialStudyDuration = 15
    private static let restudyDuration = 10
    private static let wrongStreakThreshold = 3

    private static let symbols = ["star.fill", "heart.fill", "bolt.fill", "moon.fill", "cloud.fill", "leaf.fill", "flame.fill", "drop.fill", "sparkle"]
    private static let key: [Int: String] = Dictionary(uniqueKeysWithValues: Array(1...9).enumerated().map { ($0.offset + 1, symbols[$0.offset]) })
    private static let symbolToDigit: [String: Int] = Dictionary(uniqueKeysWithValues: key.map { ($0.value, $0.key) })

    // MARK: Cipher Grid accent palette
    //
    // Cycles through the six locked category gradients so each of the
    // 9 symbols gets its own recognizable color identity. Reuses
    // existing DesignSystem tokens — no new hex values invented.
    private static let accentPalette: [(gradient: LinearGradient, glow: Color)] = [
        (DesignSystem.speedGradient, Color(hex: "#FF5E5B")),
        (DesignSystem.memoryGradient, Color(hex: "#9B3F8F")),
        (DesignSystem.attentionGradient, Color(hex: "#00C2A8")),
        (DesignSystem.flexibilityGradient, Color(hex: "#F857A6")),
        (DesignSystem.problemSolvingGradient, Color(hex: "#4A7BFF")),
        (DesignSystem.mathGradient, Color(hex: "#2ECC71"))
    ]

    private static func accent(forDigit digit: Int) -> (gradient: LinearGradient, glow: Color) {
        accentPalette[(digit - 1) % accentPalette.count]
    }

    @State private var phase: Phase = .initialStudy
    @State private var studySecondsRemaining = DigitSymbolCodingView.initialStudyDuration

    @State private var currentDigit: Int = 1
    @State private var options: [String] = []
    @State private var correctCount = 0
    @State private var attemptedCount = 0
    @State private var consecutiveWrong = 0
    @State private var timeRemaining = DigitSymbolCodingView.timeLimit
    @State private var startedAt = Date()
    @State private var feedbackSymbol: String?
    @State private var feedbackWasCorrect = false

    var body: some View {
        ZStack {
            cipherBackdrop

            VStack(spacing: DesignSystem.Spacing.lg) {
                switch phase {
                case .initialStudy, .restudy:
                    studyPhaseView
                case .quiz:
                    quizPhaseView
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .onAppear {
            beginInitialStudy()
        }
    }

    // MARK: - Backdrop
    //
    // Deep navy base with two soft blurred color blooms drifting behind
    // the content, plus a faint constellation of dots/connecting lines
    // for texture. Doesn't call `.ignoresSafeArea()` — it only paints
    // this view's own bounds, so it shouldn't bleed behind whatever
    // header/progress bar your Tests container already renders above
    // it (flagging this assumption — tell me if you actually want it
    // edge-to-edge and I'll add `.ignoresSafeArea()`).

    private var cipherBackdrop: some View {
        ZStack {
            DesignSystem.backgroundOnboarding

            LinearGradient(
                colors: [Color(hex: "#152541"), DesignSystem.backgroundOnboarding],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(DesignSystem.attentionGradient)
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .opacity(0.28)
                .offset(x: -120, y: -220)

            Circle()
                .fill(DesignSystem.primaryGradient)
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .opacity(0.24)
                .offset(x: 130, y: 260)

            CipherConstellation()
                .opacity(0.35)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Study phase (initial + refresher)

    private var studyPhaseView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text(phase == .initialStudy ? "Memorize the key!" : "Quick refresher!")
                .font(DesignSystem.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, DesignSystem.Spacing.sm)

            keyRow

            Spacer()

            countdownBadge(
                seconds: studySecondsRemaining,
                total: phase == .initialStudy ? Self.initialStudyDuration : Self.restudyDuration
            )

            Spacer()
        }
    }

    // MARK: - Quiz phase

    private var quizPhaseView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            countdownBadge(seconds: timeRemaining, total: Self.timeLimit, compact: true)

            digitPrompt

            optionsRow

            Spacer()

            Text("\(correctCount) correct")
                .font(DesignSystem.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Digit prompt
    //
    // The digit now sits inside a glowing gradient badge instead of
    // floating bare text.

    private var digitPrompt: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.primaryGradient)
                .frame(width: 96, height: 96)
                .shadow(color: Color(hex: "#6D5DE7").opacity(0.5), radius: 16, y: 6)

            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: 96, height: 96)

            Text("\(currentDigit)")
                .font(DesignSystem.roundedFont(size: 44, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Countdown badge
    //
    // Circular progress ring wrapping the remaining-seconds number —
    // used for both the study countdown and the quiz timer.

    private func countdownBadge(seconds: Int, total: Int, compact: Bool = false) -> some View {
        let fraction = total > 0 ? CGFloat(seconds) / CGFloat(total) : 0
        let urgent = seconds <= 10
        let size: CGFloat = compact ? 52 : 84

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: compact ? 4 : 6)

            Circle()
                .trim(from: 0, to: max(0, fraction))
                .stroke(
                    urgent ? AnyShapeStyle(Color(hex: "#FF5E5B")) : AnyShapeStyle(DesignSystem.attentionGradient),
                    style: StrokeStyle(lineWidth: compact ? 4 : 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: seconds)

            Text("\(seconds)s")
                .font(compact ? DesignSystem.caption : DesignSystem.roundedFont(size: 26, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Key row (study phases)
    //
    // Each digit gets its own gradient "cipher chip" from the accent
    // palette above (instead of an identical white square), with a
    // tinted glow and a subtle diagonal glass highlight.

    private var keyRow: some View {
        HStack(spacing: DesignSystem.Spacing.xxs) {
            ForEach(1...9, id: \.self) { digit in
                let accent = Self.accent(forDigit: digit)
                VStack(spacing: 2) {
                    Text("\(digit)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    Image(systemName: Self.key[digit] ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent.gradient)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.25), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .center
                                    )
                                )
                        )
                )
                .shadow(color: accent.glow.opacity(0.5), radius: 6, y: 3)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - Options row (quiz phase)
    //
    // Glassmorphic tiles: translucent material fill + a stroke in the
    // symbol's own accent gradient, icon rendered in that gradient. On
    // answer, the tapped tile flashes a solid green/red fill and scales
    // up briefly instead of just gaining a thin border ring.

    private var optionsRow: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(options, id: \.self) { symbol in
                let digit = Self.symbolToDigit[symbol] ?? 1
                let accent = Self.accent(forDigit: digit)
                let isAnswered = feedbackSymbol == symbol
                let isCorrectTile = isAnswered && feedbackWasCorrect
                let isWrongTile = isAnswered && !feedbackWasCorrect

                Button(action: { select(symbol) }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                            .fill(.ultraThinMaterial)

                        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                            .fill(
                                isCorrectTile ? AnyShapeStyle(Color(hex: "#2ECC71").opacity(0.85)) :
                                isWrongTile ? AnyShapeStyle(Color(hex: "#FF5E5B").opacity(0.85)) :
                                AnyShapeStyle(Color.clear)
                            )

                        RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact)
                            .stroke(isAnswered ? Color.white.opacity(0.6) : accent.glow.opacity(0.6), lineWidth: isAnswered ? 2 : 1.5)

                        Image(systemName: symbol)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(isAnswered ? AnyShapeStyle(Color.white) : AnyShapeStyle(accent.gradient))
                    }
                    .frame(width: 64, height: 64)
                    .shadow(color: accent.glow.opacity(isAnswered ? 0.1 : 0.35), radius: 8, y: 4)
                    .scaleEffect(isAnswered ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: feedbackSymbol)
                }
                .buttonStyle(.plain)
                .disabled(feedbackSymbol != nil)
            }
        }
    }

    // MARK: - Phase transitions

    private func beginInitialStudy() {
        phase = .initialStudy
        studySecondsRemaining = Self.initialStudyDuration
        runStudyCountdown {
            beginQuiz()
        }
    }

    private func beginQuiz() {
        phase = .quiz
        nextItem()
        startedAt = Date()
        runQuizTimer()
    }

    private func beginRestudy() {
        phase = .restudy
        studySecondsRemaining = Self.restudyDuration
        runStudyCountdown {
            phase = .quiz
            nextItem()
        }
    }

    private func runStudyCountdown(onFinished: @escaping () -> Void) {
        Task {
            while studySecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                studySecondsRemaining -= 1
            }
            onFinished()
        }
    }

    private func runQuizTimer() {
        Task {
            while timeRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                // Only counts down while actively quizzing — pauses during a refresher.
                if phase == .quiz {
                    timeRemaining -= 1
                }
            }
            finish()
        }
    }

    // MARK: - Game logic

    private func nextItem() {
        currentDigit = Int.random(in: 1...9)
        feedbackSymbol = nil
        let correctSymbol = Self.key[currentDigit] ?? Self.symbols[0]
        var pool = Self.symbols.filter { $0 != correctSymbol }.shuffled().prefix(3).map { $0 }
        pool.append(correctSymbol)
        options = pool.shuffled()
    }

    private func select(_ symbol: String) {
        guard phase == .quiz, feedbackSymbol == nil, timeRemaining > 0 else { return }
        attemptedCount += 1
        let correctSymbol = Self.key[currentDigit] ?? ""
        let isCorrect = symbol == correctSymbol
        feedbackSymbol = symbol
        feedbackWasCorrect = isCorrect

        if isCorrect {
            correctCount += 1
            consecutiveWrong = 0
        } else {
            consecutiveWrong += 1
        }

        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard timeRemaining > 0, phase == .quiz else { return }

            if consecutiveWrong >= Self.wrongStreakThreshold {
                consecutiveWrong = 0
                beginRestudy()
            } else {
                nextItem()
            }
        }
    }

    private func finish() {
        let duration = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
        onComplete(correctCount, max(attemptedCount, 1), duration)
    }
}

// MARK: - CipherConstellation
//
// Faint deterministic dot-and-line texture for the backdrop — the same
// "seeded RNG so it doesn't flicker on redraw" trick used elsewhere in
// the app, scoped to this file under its own type name to avoid any
// collision with existing seeded generators.

private struct CipherConstellation: View {
    var body: some View {
        Canvas { context, size in
            var rng = CipherGrainRNG(seed: 7)
            var points: [CGPoint] = []
            for _ in 0..<22 {
                points.append(
                    CGPoint(
                        x: CGFloat.random(in: 0...size.width, using: &rng),
                        y: CGFloat.random(in: 0...size.height, using: &rng)
                    )
                )
            }

            for i in points.indices {
                for j in (i + 1)..<points.count where j - i <= 2 {
                    let a = points[i], b = points[j]
                    let dx = a.x - b.x, dy = a.y - b.y
                    if (dx * dx + dy * dy) < 140 * 140 {
                        var path = Path()
                        path.move(to: a)
                        path.addLine(to: b)
                        context.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
                    }
                }
            }

            for point in points {
                let r = CGFloat.random(in: 1.2...2.4, using: &rng)
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - r / 2, y: point.y - r / 2, width: r, height: r)),
                    with: .color(.white.opacity(0.5))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CipherGrainRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}