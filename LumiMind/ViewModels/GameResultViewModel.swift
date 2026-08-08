//
//  GameResultViewModel.swift
//  LumiMind
//
//  Owns game-result history and stats state. Game screens submit
//  results through this ViewModel; history/calendar/stats screens
//  read from it.
//

import Foundation
import Combine

/// Local struct mirroring `GET /users/me/stats`'s response shape
/// (see API_CONTRACT.md). Kept as a small dedicated type rather than a
/// raw tuple since `@Published` values must be Equatable-friendly and
/// tuples don't work well with SwiftUI diffing.
struct UserStats: Equatable {
    var categoryScores: CategoryScores
    var streak: Int
    var lastPlayedDate: Date?
}

@MainActor
final class GameResultViewModel: ObservableObject {
    @Published var results: [GameResult] = []
    @Published var stats: UserStats?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient? = nil) {
        self.apiClient = apiClient ?? .shared
    }

    // MARK: - Submit a result

    /// Submits a new game result. On success, prepends it to `results`
    /// and refreshes `stats` from the `updatedUser` the backend returns
    /// (no extra round trip needed — see API_CONTRACT.md's
    /// `POST /game-results` response shape).
    func submitResult(
        gameName: String,
        category: String,
        score: Int,
        durationSeconds: Int,
        isFitTest: Bool = false
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let body = CreateGameResultRequest(
                gameName: gameName,
                category: category,
                score: score,
                durationSeconds: durationSeconds,
                isFitTest: isFitTest
            )
            let response: CreateGameResultResponse = try await apiClient.request(
                endpoint: .gameResults,
                method: .post,
                body: body,
                requiresAuth: true
            )
            results.insert(response.gameResult, at: 0)
            stats = UserStats(
                categoryScores: response.updatedUser.categoryScores,
                streak: response.updatedUser.streak,
                lastPlayedDate: response.updatedUser.lastPlayedDate
            )
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Fetch history

    func fetchResults(category: String? = nil, limit: Int? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched: [GameResult] = try await apiClient.request(
                endpoint: .gameResultsList(category: category, limit: limit),
                method: .get,
                requiresAuth: true
            )
            results = fetched
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Fetch stats

    func fetchStats() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: StatsResponse = try await apiClient.request(
                endpoint: .meStats,
                method: .get,
                requiresAuth: true
            )
            stats = UserStats(
                categoryScores: response.categoryScores,
                streak: response.streak,
                lastPlayedDate: response.lastPlayedDate
            )
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Error mapping

    private static func message(for error: Error) -> String {
        (error as? APIClientError)?.errorDescription ?? error.localizedDescription
    }
}