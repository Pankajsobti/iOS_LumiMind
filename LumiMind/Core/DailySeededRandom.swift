import Foundation

/// Deterministically picks N items from a collection, seeded by a
/// user id + today's date, so the selection is stable all day but
/// changes daily — no backend field required.
enum DailySeededRandom {
    static func pick<T>(_ count: Int, from items: [T], userID: String, date: Date = Date()) -> [T] {
        guard items.count > count else { return items }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        var generator = SeededGenerator(seed: "\(userID)-\(dateString)".stableHash)
        return Array(items.shuffled(using: &generator).prefix(count))
    }
}

/// SplitMix64 — deterministic across launches, unlike Swift's built-in
/// randomly-seeded Hasher.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private extension String {
    /// FNV-1a — stable hash across runs.
    var stableHash: UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return hash
    }
}