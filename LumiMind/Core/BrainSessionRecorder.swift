import Foundation

/// Lightweight record of "the last game the user finished." Written from
/// ScienceExplainerView (the shared post-game screen every game already
/// routes through), read by BrainSignalView. No individual game file
/// needs to know this feature exists.
enum BrainSessionRecorder {
    private static let gameIdKey = "brainSession.gameId"
    private static let timestampKey = "brainSession.timestamp"

    /// Call this once when ScienceExplainerView appears.
    static func record(gameId: String) {
        UserDefaults.standard.set(gameId, forKey: gameIdKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
    }

    struct Session {
        let game: GameCatalog.Game
        let timestamp: Date
    }

    /// Most recently finished game, if it ended within `window` seconds —
    /// so a session from yesterday never leaks into a fresh demo today.
    static func recentSession(window: TimeInterval = 30 * 60) -> Session? {
        guard
            let gameId = UserDefaults.standard.string(forKey: gameIdKey),
            let game = GameCatalog.games.first(where: { $0.id == gameId })
        else { return nil }

        let raw = UserDefaults.standard.double(forKey: timestampKey)
        guard raw > 0 else { return nil }
        let date = Date(timeIntervalSince1970: raw)
        guard Date().timeIntervalSince(date) <= window else { return nil }

        return Session(game: game, timestamp: date)
    }
}