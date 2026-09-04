import SwiftUI

struct SubtestInstructionView: View {
    let subtest: CognitiveSubtest
    let timeLimitSeconds: Int
    let onBegin: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            Image(systemName: subtest.iconName)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 88, height: 88)
                .background(subtest.category.gradient)
                .clipShape(Circle())

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.backgroundMain.ignoresSafeArea())
    }
}