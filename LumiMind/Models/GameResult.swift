//
//  GameResult.swift
//  LumiMind
//
//  Codable model matching the backend `GameResult` document exactly.
//  See LumiMind-Backend/API_CONTRACT.md for the canonical JSON shape.
//

import Foundation

// MARK: - GameResult

struct GameResult: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let gameName: String
    let category: String
    let score: Int
    let durationSeconds: Int
    let isFitTest: Bool
    let playedAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case gameName
        case category
        case score
        case durationSeconds
        case isFitTest
        case playedAt
    }
}

// MARK: - GameName
//
// The six locked games. Each maps to exactly one `GameCategory`
// (defined in DesignSystem.swift) so `category` is always derived
// from `gameName`, never typed separately by call sites.

enum GameName: String, CaseIterable, Codable {
    case memoryMatrix = "Memory Matrix"
    case speedMatch = "Speed Match"
    case lostInMigration = "Lost in Migration"
    case brainShift = "Brain Shift"
    case piratePassage = "Pirate Passage"
    case splittingSeeds = "Splitting Seeds"

    /// Locked game -> category mapping. Splitting Seeds -> Math, etc.
    var category: GameCategory {
        switch self {
        case .memoryMatrix:      return .memory
        case .speedMatch:        return .speed
        case .lostInMigration:   return .attention
        case .brainShift:        return .flexibility
        case .piratePassage:     return .problemSolving
        case .splittingSeeds:    return .math
        }
    }
}

// MARK: - GameCategory + API naming

extension GameCategory {
    /// The exact string sent/received as `GameResult.category` and used
    /// in the `category` gradient names. This IS `rawValue` — exposed
    /// here under an explicit name so call sites are self-documenting
    /// about which contract they're satisfying.
    var apiCategoryName: String { rawValue }

    /// camelCase key matching `User.categoryScores` JSON keys exactly
    /// (e.g. "Problem Solving" -> "problemSolving"). This is the ONLY
    /// place this mapping is defined — do not re-derive it elsewhere.
    var categoryScoresKey: String {
        switch self {
        case .speed:          return "speed"
        case .memory:         return "memory"
        case .attention:      return "attention"
        case .flexibility:    return "flexibility"
        case .problemSolving: return "problemSolving"
        case .math:            return "math"
        }
    }
}