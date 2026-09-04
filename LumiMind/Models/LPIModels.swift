//
//  LPIModels.swift
//  LumiMind
//
//  Reference-benchmark math backing the "LPI" tab: percentile
//  comparisons and strength labels. The backend has no
//  population-aggregate endpoint yet (see API_CONTRACT.md), so these
//  are static, clearly-labeled placeholder benchmarks — swap in a real
//  backend-computed percentile once that endpoint exists.
//

import Foundation

enum LPIBenchmark {
    static let mean: Double = 500
    static let standardDeviation: Double = 180

    /// Percentile (0–99) for a raw score against the reference
    /// distribution, via the standard normal CDF.
    static func percentile(forScore score: Double) -> Int {
        guard score > 0 else { return 0 }
        let z = (score - mean) / standardDeviation
        let cdf = 0.5 * (1 + erf(z / 2.0.squareRoot()))
        let value = Int((cdf * 100).rounded())
        return min(max(value, 0), 99)
    }

    static func strengthLabel(forPercentile percentile: Int) -> String {
        switch percentile {
        case 0..<20: return "Developing"
        case 20..<40: return "Below Average"
        case 40..<60: return "Average"
        case 60..<80: return "Above Average"
        default: return "Elite"
        }
    }
}