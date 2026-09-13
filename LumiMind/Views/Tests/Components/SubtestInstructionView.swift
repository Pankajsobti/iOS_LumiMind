import SwiftUI
import Combine

struct SubtestInstructionView: View {
    let subtest: CognitiveSubtest
    let timeLimitSeconds: Int
    let onBegin: () -> Void

    var body: some View {
        ZStack {
            if subtest == .forwardMemorySpan || subtest == .reverseMemorySpan {
                Image("bg-lake-sunset")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                DesignSystem.backgroundMain.ignoresSafeArea()
            }

            VStack(spacing: DesignSystem.Spacing.lg) {
                Spacer()

                Group {
                    if subtest == .trailMakingA {
                        MiniTrailPreview(mode: .a)
                    } else if subtest == .trailMakingB {
                        MiniTrailPreview(mode: .b)
                    } else if subtest == .forwardMemorySpan || subtest == .reverseMemorySpan {
                        Image("brain-mascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 110, height: 110)
                    } else {
                        Image(systemName: subtest.iconName)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 88, height: 88)
                            .background(subtest.category.gradient)
                            .clipShape(Circle())
                    }
                }

                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(subtest.domainLabel.uppercased())
                        .font(DesignSystem.caption)
                        .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))

                    Text(subtest.title)
                        .font(DesignSystem.title2)
                        .foregroundColor(DesignSystem.backgroundOnboarding)
                }

                Text(subtest.instructions)
                    .font(DesignSystem.body)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                Text("Time limit: \(timeLimitSeconds / 60 > 0 ? "\(timeLimitSeconds / 60)m " : "")\(timeLimitSeconds % 60 > 0 ? "\(timeLimitSeconds % 60)s" : "")")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))

                Spacer()
                Spacer()

                Button(action: onBegin) {
                    Text("Begin")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
                .buttonStyle(.plain)
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - MiniTrailPreview
//
// Small looping animation shown on the Trail Making A/B instruction
// screens: dots light up and connect one at a time on a timer, giving
// a live preview of the interaction instead of a static icon.
private struct MiniTrailPreview: View {
    let mode: TrailMakingView.Mode
    @State private var step: Int = 0

    private let points: [CGPoint] = [
        CGPoint(x: 20, y: 60), CGPoint(x: 45, y: 20), CGPoint(x: 68, y: 50),
        CGPoint(x: 40, y: 68), CGPoint(x: 68, y: 15)
    ]

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignSystem.attentionGradient)
                .frame(width: 88, height: 88)

            Path { path in
                guard step > 0 else { return }
                path.move(to: points[0])
                for i in 1...step {
                    path.addLine(to: points[min(i, points.count - 1)])
                }
            }
            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            ForEach(points.indices, id: \.self) { i in
                Circle()
                    .fill(Color.white)
                    .frame(width: i <= step ? 10 : 7, height: i <= step ? 10 : 7)
                    .opacity(i <= step ? 1 : 0.5)
                    .position(points[i])
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: step)
            }
        }
        .frame(width: 88, height: 88)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                step = (step + 1) % points.count
            }
        }
    }
}