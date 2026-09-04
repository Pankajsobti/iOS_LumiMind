//
//  TrainingSectionView.swift
//  LumiMind
//
//  "Training" sub-tab of My Brain: 4-week activity calendar, past-4-
//  weeks summary, streaks, and full training history list.
//

import SwiftUI

struct TrainingSectionView: View {
    @ObservedObject var gameResultViewModel: GameResultViewModel
    @ObservedObject var viewModel: MyBrainViewModel

    private static let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            calendarCard
            summaryCard
            streaksCard
            historySection
        }
    }

    // MARK: Calendar

    private var calendarCard: some View {
        let grid = viewModel.fourWeekGrid(results: gameResultViewModel.results)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Training History")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            Text("Tap on an active day to see more details")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))

            HStack {
                ForEach(Self.dayLetters, id: \.self) { letter in
                    Text(letter)
                        .font(DesignSystem.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
                Text("Plays")
                    .font(DesignSystem.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.5))
                    .frame(width: 44)
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(grid, id: \.self) { row in
                    HStack {
                        ForEach(row, id: \.self) { day in
                            dayDot(day)
                                .frame(maxWidth: .infinity)
                        }
                        Text("\(viewModel.playCount(forWeekRow: row, results: gameResultViewModel.results))")
                            .font(DesignSystem.subheadline)
                            .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                            .frame(width: 44)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private func dayDot(_ day: Date) -> some View {
        let active = viewModel.isActive(day, results: gameResultViewModel.results)
        let today = viewModel.isToday(day)

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(active ? AnyShapeStyle(DesignSystem.primaryGradient) : AnyShapeStyle(Color.gray.opacity(0.15)))
                    .frame(width: 28, height: 28)
                if active {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            if today {
                TodayMarker()
                    .fill(Color(hex: "#FF5E5B"))
                    .frame(width: 8, height: 6)
            }
        }
    }

    // MARK: Past 4 weeks

    private var summaryCard: some View {
        let summary = viewModel.pastFourWeeksSummary(results: gameResultViewModel.results)

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Past 4 Weeks")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            HStack {
                statBlock(value: summary.activeDays, label: "Active Days")
                Spacer()
                statBlock(value: summary.gameplays, label: "Gameplays")
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    // MARK: Streaks

    private var streaksCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Your Streaks")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            HStack {
                statBlock(
                    value: gameResultViewModel.stats?.streak ?? 0,
                    label: "Current Streak",
                    icon: "flame.fill"
                )
                Spacer()
                statBlock(
                    value: viewModel.longestStreak(results: gameResultViewModel.results),
                    label: "Longest Streak",
                    icon: "flame.fill"
                )
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private func statBlock(value: Int, label: String, icon: String? = nil) -> some View {
        VStack(spacing: DesignSystem.Spacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "#FF5E5B"))
            }
            Text("\(value)")
                .font(DesignSystem.roundedFont(size: 28, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)
            Text(label)
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .textCase(.uppercase)
        }
    }

    // MARK: Full history list (same row pattern as before)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("All Sessions")
                .font(DesignSystem.title2)
                .foregroundColor(DesignSystem.backgroundOnboarding)

            if gameResultViewModel.results.isEmpty {
                if viewModel.hasLoadedOnce {
                    emptyHistoryState
                } else {
                    ProgressView()
                        .tint(DesignSystem.backgroundOnboarding)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.xl)
                }
            } else {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(gameResultViewModel.results) { result in
                        historyRow(result)
                    }
                }
            }
        }
    }

    private var emptyHistoryState: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.4))
            Text("No games played yet")
                .font(DesignSystem.headline)
                .foregroundColor(DesignSystem.backgroundOnboarding)
            Text("Play a game to start building your training history.")
                .font(DesignSystem.caption)
                .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .background(Color.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadius))
    }

    private func historyRow(_ result: GameResult) -> some View {
        let catalogGame = GameCatalog.games.first { $0.name == result.gameName }
        let category = catalogGame?.category ?? GameCategory(rawValue: result.category)
        let gradient = category?.gradient ?? DesignSystem.primaryGradient

        return HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: catalogGame?.iconName ?? "gamecontroller.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.gameName)
                    .font(DesignSystem.headline)
                    .foregroundColor(DesignSystem.backgroundOnboarding)
                Text("\(category?.rawValue ?? result.category) • \(Self.dateFormatter.string(from: result.playedAt))")
                    .font(DesignSystem.caption)
                    .foregroundColor(DesignSystem.backgroundOnboarding.opacity(0.6))
            }

            Spacer()

            Text("\(result.score)")
                .font(DesignSystem.roundedFont(size: 18, weight: .bold))
                .foregroundColor(DesignSystem.backgroundOnboarding)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.cardRadiusCompact))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

/// Small upward-pointing triangle used as the "today" marker under the
/// active calendar dot.
private struct TodayMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}