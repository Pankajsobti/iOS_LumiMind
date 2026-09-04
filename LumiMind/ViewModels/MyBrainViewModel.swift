//
//  MyBrainViewModel.swift
//  LumiMind
//
//  Orchestrates the "My Brain" tab's data loading and derives the LPI
//  / Training tab data from the shared `GameResultViewModel`'s
//  `stats`/`results` — still the single source of truth, this only
//  computes view-facing values from it.
//

import Foundation
import Combine

@MainActor
final class MyBrainViewModel: ObservableObject {

    /// Bumped from 20 -> 200: the Training tab's 4-week calendar and
    /// streak math need more history than the old flat list did.
    static let historyLimit = 200

    @Published private(set) var hasLoadedOnce = false

    private let gameResultViewModel: GameResultViewModel
    private var calendar: Calendar { .current }

    init(gameResultViewModel: GameResultViewModel) {
        self.gameResultViewModel = gameResultViewModel
    }

    func load() async {
        async let statsFetch: Void = gameResultViewModel.fetchStats()
        async let resultsFetch: Void = gameResultViewModel.fetchResults(category: nil, limit: Self.historyLimit)
        _ = await (statsFetch, resultsFetch)
        hasLoadedOnce = true
    }

    // MARK: - LPI tab derived data

    var overallLPI: Double? {
        guard let scores = gameResultViewModel.stats?.categoryScores else { return nil }
        let values = GameCategory.allCases.map { scores[$0] }
        guard values.allSatisfy({ $0 > 0 }) else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func percentile(for category: GameCategory) -> Int? {
        guard let score = gameResultViewModel.stats?.categoryScores[category], score > 0 else { return nil }
        return LPIBenchmark.percentile(forScore: score)
    }

    var overallPercentile: Int? {
        let percentiles = GameCategory.allCases.compactMap { percentile(for: $0) }
        guard percentiles.count == GameCategory.allCases.count else { return nil }
        return percentiles.reduce(0, +) / percentiles.count
    }

    struct GameStrengthEntry: Identifiable {
        let id: String
        let gameName: String
        let category: GameCategory?
        let latestScore: Int
        let percentile: Int
    }

    func gameStrengthProfile(results: [GameResult]) -> [GameStrengthEntry] {
        let latestByGame = Dictionary(grouping: results, by: \.gameName)
            .compactMapValues { $0.sorted { $0.playedAt > $1.playedAt }.first }

        return latestByGame.values.map { result in
            let category = GameCatalog.games.first { $0.name == result.gameName }?.category
                ?? GameCategory(rawValue: result.category)
            return GameStrengthEntry(
                id: result.gameName,
                gameName: result.gameName,
                category: category,
                latestScore: result.score,
                percentile: LPIBenchmark.percentile(forScore: Double(result.score))
            )
        }
        .sorted { $0.gameName < $1.gameName }
    }

    struct GameProgressEntry: Identifiable {
        let id: String
        let gameName: String
        let firstScore: Int
        let latestScore: Int
        var percentChange: Double {
            guard firstScore != 0 else { return 0 }
            return (Double(latestScore) - Double(firstScore)) / Double(firstScore) * 100
        }
    }

    func gameProgressProfile(results: [GameResult]) -> [GameProgressEntry] {
        Dictionary(grouping: results, by: \.gameName)
            .compactMap { gameName, plays -> GameProgressEntry? in
                guard plays.count >= 2 else { return nil }
                let sorted = plays.sorted { $0.playedAt < $1.playedAt }
                guard let first = sorted.first, let latest = sorted.last else { return nil }
                return GameProgressEntry(id: gameName, gameName: gameName, firstScore: first.score, latestScore: latest.score)
            }
            .sorted { $0.gameName < $1.gameName }
    }

    // MARK: - Training tab derived data

    private func activeDays(from results: [GameResult]) -> Set<Date> {
        Set(results.map { calendar.startOfDay(for: $0.playedAt) })
    }

    func fourWeekGrid(results: [GameResult]) -> [[Date]] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday
        guard let currentWeekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
              let gridStart = calendar.date(byAdding: .day, value: -21, to: currentWeekStart) else {
            return []
        }

        return (0..<4).map { row in
            (0..<7).compactMap { col in
                calendar.date(byAdding: .day, value: row * 7 + col, to: gridStart)
            }
        }
    }

    func isActive(_ day: Date, results: [GameResult]) -> Bool {
        activeDays(from: results).contains(calendar.startOfDay(for: day))
    }

    func isToday(_ day: Date) -> Bool {
        calendar.isDateInToday(day)
    }

    func playCount(forWeekRow row: [Date], results: [GameResult]) -> Int {
        let daySet = Set(row.map { calendar.startOfDay(for: $0) })
        return results.filter { daySet.contains(calendar.startOfDay(for: $0.playedAt)) }.count
    }

    func pastFourWeeksSummary(results: [GameResult]) -> (activeDays: Int, gameplays: Int) {
        let today = calendar.startOfDay(for: Date())
        guard let windowStart = calendar.date(byAdding: .day, value: -27, to: today) else {
            return (0, 0)
        }
        let inWindow = results.filter { $0.playedAt >= windowStart }
        let days = Set(inWindow.map { calendar.startOfDay(for: $0.playedAt) })
        return (days.count, inWindow.count)
    }

    /// Longest run of consecutive active days in the loaded results.
    /// An approximation bounded by `historyLimit` — the backend has no
    /// dedicated "longest streak" field (see API_CONTRACT.md).
    func longestStreak(results: [GameResult]) -> Int {
        let days = activeDays(from: results).sorted()
        guard !days.isEmpty else { return 0 }

        var longest = 1
        var current = 1
        for i in 1..<days.count {
            guard let expected = calendar.date(byAdding: .day, value: 1, to: days[i - 1]) else { continue }
            if calendar.isDate(expected, inSameDayAs: days[i]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}