//
//  CognitiveScoring.swift
//  LumiMind
//
//  Converts raw subtest performance into percentiles and an overall
//  Grand Index Score, using a normal-distribution assumption per
//  domain (z-score against an assumed population mean/SD, mapped
//  through the standard normal CDF).
//
//  NOTE: mean/SD values below are placeholder normative assumptions,
//  not real population data — swap in actual norms when available.
//

import Foundation

enum CognitiveScoring {

    /// Assumed population mean/SD (in normalized-percent terms, 0–100)
    /// per domain. Placeholder — replace with real normative data.
    private struct Norm {
        let mean: Double
        let sd: Double
    }

    private static let domainNorms: [String: Norm] = [
        "Attention": Norm(mean: 70, sd: 15),
        "Memory": Norm(mean: 65, sd: 15),
        "Processing Speed": Norm(mean: 75, sd: 12),
        "Reasoning": Norm(mean: 68, sd: 15)
    ]

    /// Converts a subtest's normalized percent (0.0–1.0) into a
    /// percentile (0–100) using the domain's assumed normal
    /// distribution.
    static func percentile(forNormalizedPercent normalizedPercent: Double, domainLabel: String) -> Int {
        let norm = domainNorms[domainLabel] ?? Norm(mean: 70, sd: 15)
        let scorePercent = normalizedPercent * 100
        let z = (scorePercent - norm.mean) / norm.sd
        let percentile = standardNormalCDF(z) * 100
        return Int(percentile.rounded().clamped(to: 1...99))
    }

    /// Buckets a percentile into a display range, e.g. 72 -> "70th–80th".
    static func percentileRangeLabel(for percentile: Int) -> String {
        let lowerBound = max(1, (percentile / 10) * 10)
        let upperBound = min(99, lowerBound + 10)
        return "\(ordinal(lowerBound))–\(ordinal(upperBound))"
    }

    /// Grand Index Score: average z-score across all subtests, scaled
    /// to a standard-score distribution (mean 100, SD 15 — same scale
    /// convention as IQ-style composite scores).
    static func grandIndexScore(results: [SubtestResult]) -> Int {
        guard !results.isEmpty else { return 100 }

        let zScores: [Double] = results.map { result in
            let norm = domainNorms[result.subtest.domainLabel] ?? Norm(mean: 70, sd: 15)
            let scorePercent = result.normalizedPercent * 100
            return (scorePercent - norm.mean) / norm.sd
        }

        let averageZ = zScores.reduce(0, +) / Double(zScores.count)
        let standardScore = 100 + (averageZ * 15)
        return Int(standardScore.rounded().clamped(to: 40...160))
    }

    // MARK: - Math helpers

    /// Standard normal CDF via the Abramowitz & Stegun erf approximation.
    private static func standardNormalCDF(_ z: Double) -> Double {
        0.5 * (1 + erf(z / Double(2).squareRoot()))
    }

    private static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100) {
        case 11...13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

        /// Shared badge label/color for a Grand Index Score, used by both
    /// TestResultsView and TestHistoryView so the two never drift.
    static func performanceBadge(forScore score: Int) -> (label: String, colorHex: String) {
        switch score {
        case 115...: return ("Well Above Average", "#2ECC71")
        case 108..<115: return ("Above Average", "#2ECC71")
        case 92..<108: return ("Average", "#0F1B2D")
        case 85..<92: return ("Below Average", "#FF5E5B")
        default: return ("Well Below Average", "#FF5E5B")
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}