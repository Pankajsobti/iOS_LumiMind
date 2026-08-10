import SwiftUI
import UIKit

struct SocialProofView: View {
    enum Variant {
        case afterGoals
        case afterCategories

        var headline: String {
            switch self {
            case .afterGoals: return "You're not starting from zero"
            case .afterCategories: return "Small sessions, real change"
            }
        }

        var body: String {
            switch self {
            case .afterGoals:
                return "Everyone's cognitive profile is different. We'll map yours before building your plan."
            case .afterCategories:
                return "A few focused minutes a day is enough to see your thinking sharpen over time."
            }
        }
    }

    let variant: Variant
    var onContinue: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            DesignSystem.backgroundOnboarding
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                InterstitialMark(variant: variant)
                    .frame(width: 100, height: 100)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.9)

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(variant.headline)
                        .font(DesignSystem.title)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .multilineTextAlignment(.center)

                    Text(variant.body)
                        .font(DesignSystem.body)
                        .foregroundColor(DesignSystem.backgroundMain.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Spacer()
                Spacer()

                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onContinue()
                }) {
                    Text("Continue")
                        .font(DesignSystem.buttonLabel)
                        .foregroundColor(DesignSystem.backgroundMain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                }
                .buttonStyle(.plain)
                .background(DesignSystem.primaryGradient)
                .clipShape(Capsule())
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                hasAppeared = true
            }
        }
    }
}

private struct InterstitialMark: View {
    let variant: SocialProofView.Variant

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let points = nodePoints(w: w, h: h)

            ZStack {
                Path { path in
                    for i in 0..<points.count {
                        for j in (i + 1)..<points.count {
                            path.move(to: points[i])
                            path.addLine(to: points[j])
                        }
                    }
                }
                .stroke(
                    DesignSystem.backgroundMain.opacity(0.55),
                    style: StrokeStyle(lineWidth: w * 0.06, lineCap: .round)
                )

                ForEach(points.indices, id: \.self) { i in
                    Circle()
                        .fill(DesignSystem.backgroundMain.opacity(1.0 - Double(i) * 0.12))
                        .frame(width: w * (0.20 - CGFloat(i) * 0.015))
                        .position(points[i])
                }
            }
        }
    }

    private func nodePoints(w: CGFloat, h: CGFloat) -> [CGPoint] {
        switch variant {
        case .afterGoals:
            return [
                CGPoint(x: w * 0.5, y: h * 0.28),
                CGPoint(x: w * 0.30, y: h * 0.56),
                CGPoint(x: w * 0.70, y: h * 0.56)
            ]
        case .afterCategories:
            return [
                CGPoint(x: w * 0.30, y: h * 0.35),
                CGPoint(x: w * 0.70, y: h * 0.35),
                CGPoint(x: w * 0.30, y: h * 0.65),
                CGPoint(x: w * 0.70, y: h * 0.65)
            ]
        }
    }
}

#Preview {
    SocialProofView(variant: .afterGoals, onContinue: {
        print("Continue tapped")
    })
}