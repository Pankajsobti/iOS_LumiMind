import SwiftUI

struct TestProgressHeaderView: View {
    let currentIndex: Int
    let total: Int
    let progress: Double

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            HStack {
                Text("Subtest \(currentIndex + 1) of \(total)")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DesignSystem.backgroundOnboarding.opacity(0.08))
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