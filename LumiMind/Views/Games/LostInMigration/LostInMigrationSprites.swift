import SwiftUI

// MARK: - LostInMigration sprite shapes
//
// All original vector shapes (no third-party assets) — kept in their
// own file mirroring the TrainOfThoughtSprites.swift convention so
// LostInMigrationView.swift stays focused on layout/state.

// MARK: BirdShape
//
// A single closed bezier silhouette: a pointed head, two smoothly
// swept wings (curved rather than straight-edged, so it reads as an
// actual bird instead of an arrowhead), and a shallow forked tail —
// mirroring a classic swallow-in-flight glyph. Points "up" at 0°
// rotation; the View rotates it per-direction.

struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()

        path.move(to: CGPoint(x: w * 0.5, y: 0)) // head tip

        // Right wing: sweeps out wide, then curves back in toward the body.
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.58),
            control1: CGPoint(x: w * 0.78, y: h * 0.04),
            control2: CGPoint(x: w * 0.97, y: h * 0.26)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.56, y: h * 0.66),
            control1: CGPoint(x: w * 0.86, y: h * 0.63),
            control2: CGPoint(x: w * 0.68, y: h * 0.6)
        )
        // Right tail feather, out to the fork tip.
        path.addCurve(
            to: CGPoint(x: w * 0.64, y: h),
            control1: CGPoint(x: w * 0.6, y: h * 0.8),
            control2: CGPoint(x: w * 0.67, y: h * 0.92)
        )
        // Notch of the fork.
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.8))
        // Left tail feather, mirrored.
        path.addLine(to: CGPoint(x: w * 0.36, y: h))
        path.addCurve(
            to: CGPoint(x: w * 0.44, y: h * 0.66),
            control1: CGPoint(x: w * 0.33, y: h * 0.92),
            control2: CGPoint(x: w * 0.4, y: h * 0.8)
        )
        // Left wing, mirrored.
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.58),
            control1: CGPoint(x: w * 0.32, y: h * 0.6),
            control2: CGPoint(x: w * 0.14, y: h * 0.63)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: w * 0.03, y: h * 0.26),
            control2: CGPoint(x: w * 0.22, y: h * 0.04)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: BirdSprite
//
// Wraps BirdShape with a soft gradient fill, thin highlight stroke,
// depth shadow, and a gentle continuous wing-flap (a slow vertical
// squash/stretch applied BEFORE rotation, so it flaps along the
// bird's own body axis regardless of which way it's facing). The
// target bird gets a marginally brighter fill/shadow — a subtle cue,
// not a giveaway, matching the "identify by position, not a glowing
// outline" rule from the design doc.

struct BirdSprite: View {
    let isTarget: Bool
    let heading: Double
    var size: CGFloat = 40

    @State private var flap = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let bodyGradient = LinearGradient(
        colors: [Color(hex: "#33454F"), Color(hex: "#121A20")],
        startPoint: .top, endPoint: .bottom
    )
    private static let targetGradient = LinearGradient(
        colors: [Color(hex: "#3D5866"), Color(hex: "#16222A")],
        startPoint: .top, endPoint: .bottom
    )

    var body: some View {
        BirdShape()
            .fill(isTarget ? Self.targetGradient : Self.bodyGradient)
            .overlay(
                BirdShape().stroke(Color.white.opacity(isTarget ? 0.4 : 0.2), lineWidth: 1.2)
            )
            .frame(width: size, height: size * 0.9)
            .scaleEffect(x: 1, y: flap ? 1.05 : 0.95, anchor: .center)
            .rotationEffect(.degrees(heading))
            .shadow(color: .black.opacity(isTarget ? 0.3 : 0.18), radius: isTarget ? 5 : 3, y: 2)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    Animation.easeInOut(duration: 0.55)
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...0.3))
                ) {
                    flap = true
                }
            }
    }
}

// MARK: CloudShape
//
// Three overlapping rounded lobes — an original, simplified cloud
// silhouette for the sky backdrop.

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addEllipse(in: CGRect(x: 0, y: h * 0.35, width: w * 0.55, height: h * 0.65))
        path.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.05, width: w * 0.55, height: h * 0.75))
        path.addEllipse(in: CGRect(x: w * 0.5, y: h * 0.3, width: w * 0.5, height: h * 0.6))
        return path
    }
}

// MARK: TreeSilhouette
//
// Simple stacked-triangle pine, used for the ground line along the
// bottom of the sky backdrop.

struct MigrationTreeSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let tiers = 3
        let tierHeight = h * 0.7 / CGFloat(tiers)

        for i in 0..<tiers {
            let top = CGFloat(i) * tierHeight * 0.72
            let bottom = top + tierHeight
            let widthFactor = 1.0 - CGFloat(i) * 0.22
            path.move(to: CGPoint(x: w / 2, y: top))
            path.addLine(to: CGPoint(x: w / 2 - (w / 2) * widthFactor, y: bottom))
            path.addLine(to: CGPoint(x: w / 2 + (w / 2) * widthFactor, y: bottom))
            path.closeSubpath()
        }

        path.addRect(CGRect(x: w * 0.45, y: h * 0.78, width: w * 0.1, height: h * 0.22))
        return path
    }
}