//
//  CognitiveTestModels.swift
//  LumiMind
//
//  Shared types for the Cognitive Test session flow. Local-only for
//  now — no backend routes for cognitive-test results yet, so the
//  session's final composite is submitted through the existing
//  GameResultViewModel/GameResult pipeline (see TestSessionViewModel).
//

import Foundation

// MARK: - CognitiveSubtest

enum CognitiveSubtest: String, CaseIterable, Identifiable {
    case trailMakingA
    case trailMakingB
    case forwardMemorySpan
    case reverseMemorySpan
    case digitSymbolCoding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trailMakingA: return "Trail Making A"
        case .trailMakingB: return "Trail Making B"
        case .forwardMemorySpan: return "Forward Memory Span"
        case .reverseMemorySpan: return "Reverse Memory Span"
        case .digitSymbolCoding: return "Digit Symbol Coding"
        }
    }

    var instructions: String {
        switch self {
        case .trailMakingA:
            return "Tap the numbered circles in order, from 1 to \(TrailMakingView.Mode.a.nodeCount), as quickly as you can."
        case .trailMakingB:
            return "Tap the circles in order, alternating between numbers and letters: 1, A, 2, B, 3, C…"
        case .forwardMemorySpan:
            return "You'll see a sequence of numbers flash one at a time. Tap them back in the same order."
        case .reverseMemorySpan:
            return "You'll see a sequence of numbers flash one at a time. Tap them back in reverse order."
        case .digitSymbolCoding:
            return "Use the key at the top to match each number to its symbol. Work through as many as you can before time runs out."
        }
    }

    var iconName: String {
        switch self {
        case .trailMakingA, .trailMakingB: return "point.topleft.down.curvedto.point.bottomright.up"
        case .forwardMemorySpan, .reverseMemorySpan: return "square.stack.3d.up.fill"
        case .digitSymbolCoding: return "square.grid.3x3.fill"
        }
    }

    /// Maps to an existing GameCategory purely so this reuses
    /// DesignSystem's locked gradients — no new tokens added.
    var category: GameCategory {
        switch self {
        case .trailMakingA, .trailMakingB: return .attention
        case .forwardMemorySpan, .reverseMemorySpan: return .memory
        case .digitSymbolCoding: return .speed
        }
    }

    var domainLabel: String {
        switch self {
        case .trailMakingA, .trailMakingB: return "Attention"
        case .forwardMemorySpan, .reverseMemorySpan: return "Memory"
        case .digitSymbolCoding: return "Processing Speed"
        }
    }
}

// MARK: - SubtestResult

/// Outcome of a single completed subtest. `rawScore` is whatever the
/// subtest's own interaction produces (correct count, longest span,
/// etc.) — `TestSessionViewModel` normalizes these into one composite
/// score when the full session finishes.
struct SubtestResult: Equatable {
    let subtest: CognitiveSubtest
    let rawScore: Int
    let maxPossibleScore: Int
    let durationSeconds: Int

    var normalizedPercent: Double {
        guard maxPossibleScore > 0 else { return 0 }
        return Double(rawScore) / Double(maxPossibleScore)
    }

    /// Computed at creation time in TestSessionViewModel via
    /// CognitiveScoring, since it depends on the subtest's domain norm.
    var percentile: Int = 0

    var percentileRangeLabel: String {
        CognitiveScoring.percentileRangeLabel(for: percentile)
    }
}