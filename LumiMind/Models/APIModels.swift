//
//  APIModels.swift
//  LumiMind
//
//  Request/response wrapper structs for every endpoint under /api/v1.
//  See LumiMind-Backend/API_CONTRACT.md for the canonical JSON shapes
//  these must match exactly. No networking logic lives here — payload
//  shapes only.
//

import Foundation

// MARK: - Auth

/// Body for `POST /auth/signup` and `POST /auth/login`.
struct AuthRequest: Codable {
    let email: String
    let password: String
}

/// Response for `POST /auth/signup` and `POST /auth/login`.
struct AuthResponse: Codable {
    let token: String
    let user: User
}

// MARK: - Onboarding

/// Body for `PATCH /users/onboarding`.
struct OnboardingRequest: Codable {
    let goals: [String]
    let difficultyLevel: String
}

// MARK: - Game Results

/// Body for `POST /game-results`.
struct CreateGameResultRequest: Codable {
    let gameName: String
    let category: String
    let score: Int
    let durationSeconds: Int
    let isFitTest: Bool
}

/// Response for `POST /game-results`.
struct CreateGameResultResponse: Codable {
    let gameResult: GameResult
    let updatedUser: User
}

// MARK: - Stats

/// Response for `GET /users/me/stats`.
struct StatsResponse: Codable {
    let categoryScores: CategoryScores
    let streak: Int
    let lastPlayedDate: Date?
}

// MARK: - Errors

/// Canonical error shape returned by the backend on any non-2xx
/// response: `{ "error": "<message>" }`.
struct APIErrorResponse: Codable, Error {
    let error: String
}