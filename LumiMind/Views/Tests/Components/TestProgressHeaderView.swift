import SwiftUI

struct TestProgressHeaderView: View {
    let currentIndex: Int
    let total: Int
    let progress: Double
    var isDark: Bool = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            HStack {
                Text("Subtest \(currentIndex + 1) of \(total)")
                    .font(DesignSystem.caption)
                    .foregroundColor(isDark ? .white.opacity(0.75) : DesignSystem.backgroundOnboarding.opacity(0.6))
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(isDark ? Color.white.opacity(0.15) : DesignSystem.backgroundOnboarding.opacity(0.08))
                    Capsule()
                        .fill(DesignSystem.primaryGradient)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
    }
}