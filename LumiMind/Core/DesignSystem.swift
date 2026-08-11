//
//  DesignSystem.swift
//  LumiMind
//
//  Single source of truth for colors, gradients, typography, spacing,
//  and corner radii used across the entire app.
//
//  RULE: Every other screen must reference `DesignSystem` instead of
//  hardcoding hex values, fonts, spacing, or radii. Nothing in this
//  file contains view logic or screen-specific code — tokens and
//  reusable style helpers only.
//
//  All values below are LOCKED for the rest of the project.
//

import SwiftUI

// MARK: - DesignSystem

enum DesignSystem {

    // MARK: - Core Backgrounds

    /// Onboarding / Auth flow background — dark navy (#0F1B2D)
    static let backgroundOnboarding = Color(hex: "#0F1B2D")

    /// Main app background — warm cream (#F5F1E8)
    static let backgroundMain = Color(hex: "#F5F1E8")

    // MARK: - Primary Gradient

    /// Primary button gradient — violet-to-lavender (#6D5DE7 → #A19AFE)
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "#6D5DE7"), Color(hex: "#A19AFE")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Game Category Gradients
    //
    // Six distinct, harmonious 2-color gradients — one per game category.
    // Each occupies a different region of the color wheel from the
    // violet-lavender primary so categories stay visually distinguishable
    // at a glance. Memory was shifted from indigo/violet to plum/berry
    // since it previously overlapped with the new primary hue.

    /// Speed — fiery red-orange to amber. Urgent, fast, high-energy.
    static let speedGradient = LinearGradient(
        colors: [Color(hex: "#FF5E5B"), Color(hex: "#FFB347")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Memory — plum to berry pink. Calm, contemplative, deep focus.
    /// (Shifted off indigo/violet, which now overlaps the primary gradient.)
    static let memoryGradient = LinearGradient(
        colors: [Color(hex: "#9B3F8F"), Color(hex: "#D46BB5")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Attention — teal to aqua. Sharp, alert, precise.
    static let attentionGradient = LinearGradient(
        colors: [Color(hex: "#00C2A8"), Color(hex: "#5EEAD4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Flexibility — magenta to pink. Fluid, adaptive, playful.
    static let flexibilityGradient = LinearGradient(
        colors: [Color(hex: "#F857A6"), Color(hex: "#FF7CA3")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Problem Solving — cobalt to sky blue. Logical, clear-headed, cool.
    static let problemSolvingGradient = LinearGradient(
        colors: [Color(hex: "#4A7BFF"), Color(hex: "#6FA8FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Math — emerald to mint green. Precise, growth-oriented.
    static let mathGradient = LinearGradient(
        colors: [Color(hex: "#2ECC71"), Color(hex: "#58D68D")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Convenience lookup so category gradients can be selected dynamically.
    static func gradient(for category: GameCategory) -> LinearGradient {
        switch category {
        case .speed:          return speedGradient
        case .memory:         return memoryGradient
        case .attention:      return attentionGradient
        case .flexibility:    return flexibilityGradient
        case .problemSolving: return problemSolvingGradient
        case .math:           return mathGradient
        }
    }

    // MARK: - Typography
    //
    // Rounded sans-serif throughout the app (SF Rounded via the
    // `.rounded` design on the system font).

    /// Returns a rounded-design system font at the given size and weight.
    static func roundedFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // Common semantic text styles, all built on the rounded font.
    static let largeTitle = roundedFont(size: 34, weight: .bold)
    static let title      = roundedFont(size: 28, weight: .bold)
    static let title2     = roundedFont(size: 22, weight: .semibold)
    static let headline   = roundedFont(size: 17, weight: .semibold)
    static let body       = roundedFont(size: 17, weight: .regular)
    static let subheadline = roundedFont(size: 15, weight: .regular)
    static let caption    = roundedFont(size: 13, weight: .regular)
    static let buttonLabel = roundedFont(size: 17, weight: .bold)

    // MARK: - Spacing Scale
    //
    // A consistent 4pt-based spacing scale. Reference these instead of
    // hardcoding padding/spacing values on screens.

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radii

    enum Radius {
        /// Buttons are fully rounded (pill-shaped). Apply via
        /// `.clipShape(Capsule())` or a radius >= half the button height.
        static let buttonRadius: CGFloat = 999

        /// Cards use a 20–24pt corner radius. `cardRadius` is the
        /// standard value; `cardRadiusCompact` covers smaller card
        /// contexts while staying within the locked 20–24pt range.
        static let cardRadius: CGFloat = 24
        static let cardRadiusCompact: CGFloat = 20
    }
}

// MARK: - Game Category

/// The six game categories used across the app, each mapped to its own
/// locked gradient in `DesignSystem`.
enum GameCategory: String, CaseIterable, Identifiable {
    case speed = "Speed"
    case memory = "Memory"
    case attention = "Attention"
    case flexibility = "Flexibility"
    case problemSolving = "Problem Solving"
    case math = "Math"

    var id: String { rawValue }

    var gradient: LinearGradient {
        DesignSystem.gradient(for: self)
    }
}

// MARK: - Tab Item

/// The five bottom tab bar destinations. Icons are intentionally not
/// assigned yet — this is identifiers only, per the current build scope.
enum TabItem: String, CaseIterable, Identifiable {
    case today = "Today"
    case games = "Games"
    case myBrain = "My Brain"
    case discover = "Discover"
    case tests = "Tests"

    var id: String { rawValue }
}

// MARK: - Color(hex:) Helper

extension Color {
    /// Creates a `Color` from a hex string, e.g. "#FF6B4A" or "FF6B4A".
    /// Supports 6-digit (RGB) and 8-digit (ARGB) hex strings.
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 8: // ARGB
            (a, r, g, b) = ((rgb >> 24) & 0xFF, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
        case 6: // RGB
            (a, r, g, b) = (255, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}