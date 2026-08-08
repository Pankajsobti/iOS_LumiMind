//
//  User.swift
//  LumiMind
//
//  Codable model matching the backend `User` document exactly.
//  See LumiMind-Backend/API_CONTRACT.md for the canonical JSON shape.
//
//  NOTE: `passwordHash` is intentionally NOT modeled here — it is a
//  backend-only field and is never sent to the client.
//

import Foundation

// MARK: - User

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String

    /// Set via `PATCH /users/onboarding`. Nil/absent until the user
    /// completes onboarding.
    var goals: [String]?

    /// Set via `PATCH /users/onboarding`. Nil/absent until the user
    /// completes onboarding.
    var difficultyLevel: String?

    var categoryScores: CategoryScores
    var streak: Int
    var lastPlayedDate: Date?

    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email
        case goals
        case difficultyLevel
        case categoryScores
        case streak
        case lastPlayedDate
        case createdAt
        case updatedAt
    }
}

// MARK: - CategoryScores

/// Per-category score tracking. Keys are locked to match the six
/// `GameCategory` cases defined in `DesignSystem.swift`, serialized as
/// camelCase to match the Mongoose `categoryScores` sub-schema exactly.
///
/// Canonical mapping (see API_CONTRACT.md):
///   Speed -> speed | Memory -> memory | Attention -> attention
///   Flexibility -> flexibility | Problem Solving -> problemSolving | Math -> math
struct CategoryScores: Codable, Equatable {
    var speed: Double
    var memory: Double
    var attention: Double
    var flexibility: Double
    var problemSolving: Double
    var math: Double

    static let zero = CategoryScores(
        speed: 0, memory: 0, attention: 0,
        flexibility: 0, problemSolving: 0, math: 0
    )

    /// Look up a score by `GameCategory`, using the locked category
    /// list from `DesignSystem.swift` so callers never hardcode keys.
    subscript(category: GameCategory) -> Double {
        switch category {
        case .speed: return speed
        case .memory: return memory
        case .attention: return attention
        case .flexibility: return flexibility
        case .problemSolving: return problemSolving
        case .math: return math
        }
    }
}