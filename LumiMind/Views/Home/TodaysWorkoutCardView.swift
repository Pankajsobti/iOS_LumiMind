import SwiftUI

struct TodaysWorkoutCardView: View {
    let workoutNumber: Int
    let totalWorkouts: Int
    let exercises: [GameCatalog.Game]
    let isPlayable: (GameCatalog.Game) -> Bool
    let onStart: () -> Void
    let onSelectExercise: (GameCatalog.Game) -> Void

    private var progress: Double {
        guard totalWorkouts > 0 else { return 0 }
        return Double(workoutNumber) / Double(totalWorkouts)
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            progressRing
            titleBlock
            startButton
            exerciseList
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.backgroundOnboarding.opacity(0.1), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(DesignSystem.primaryGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            ZStack {
                Circle().fill(DesignSystem.primaryGradient)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 64, height: 64)
        }
        .frame(width: 88, height: 88)
    }

    private var titleBlock: some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            Text("Workout \(workoutNumber) of \(totalWorkouts)")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
            Text("Your First Workout")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)
            Text("Each game works a different part of your thinking. Let's give them all a try.")
                .font(DesignSystem.subheadline)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var startButton: some View {
        Button(action: onStart) {
            Text("Start")
                .font(DesignSystem.buttonLabel)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm + DesignSystem.Spacing.xxs)
        }
        .buttonStyle(.plain)
        .background(DesignSystem.primaryGradient)
        .clipShape(Capsule())
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Today's Exercises")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            ForEach(exercises) { game in
                Button { onSelectExercise(game) } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(game.category.gradient)
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: game.iconName).foregroundColor(.white))

                        VStack(alignment: .leading, spacing: 0) {
                            Text(game.name)
                                .font(DesignSystem.headline)
                                .foregroundColor(DesignSystem.backgroundOnboarding)
                            Text(game.category.rawValue.uppercased())
                                .font(DesignSystem.caption)
                                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
                        }

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}