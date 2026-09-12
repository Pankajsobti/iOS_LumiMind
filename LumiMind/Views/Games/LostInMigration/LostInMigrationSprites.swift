import SwiftUI

// MARK: - LostInMigration sprite shapes
//
// All original vector shapes (no third-party assets) — kept in their
// own file mirroring the TrainOfThoughtSprites.swift convention so
// LostInMigrationView.swift stays focused on layout/state.

// MARK: BirdShape
//
// A simple chevron-with-a-notch silhouette: a clear forward "head"
// point plus two swept wings, with a V-notch cut into the trailing
// edge so it reads as a bird/paper-plane rather than a plain arrow.
// Points "up" at 0° rotation; the View rotates it per-direction.

struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: 0))              // head
        path.addLine(to: CGPoint(x: w, y: h))                  // right wingtip
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.62))     // trailing notch
        path.addLine(to: CGPoint(x: 0, y: h))                  // left wingtip
        path.closeSubpath()
        return path
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