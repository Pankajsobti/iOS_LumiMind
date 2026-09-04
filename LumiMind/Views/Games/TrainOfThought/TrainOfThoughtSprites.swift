import SwiftUI

// MARK: - StationSprite
//
// A small flat "toy castle" built entirely from shapes, colored per
// destination. No external image assets — keeps the game self
// contained and on-brand with DesignSystem colors.

struct StationSprite: View {
    let colorHex: String
    var size: CGFloat = 42

    private var base: Color { Color(hex: colorHex) }
    private var shade: Color { base.darker(by: 0.22) }
    private var trim: Color { Color(hex: "#EFEAD8") }

    var body: some View {
        let w = size, h = size * 1.15

        ZStack {
            // Twin towers
            HStack(spacing: w * 0.34) {
                tower(width: w * 0.24, height: h * 0.34)
                tower(width: w * 0.24, height: h * 0.34)
            }
            .offset(y: -h * 0.18)

            // Keep body
            RoundedRectangle(cornerRadius: 3)
                .fill(base)
                .frame(width: w * 0.68, height: h * 0.5)
                .offset(y: h * 0.14)

            // Door
            RoundedRectangle(cornerRadius: 2)
                .fill(trim)
                .frame(width: w * 0.2, height: h * 0.24)
                .offset(y: h * 0.26)

            // Windows
            HStack(spacing: w * 0.2) {
                windowSquare(w * 0.13)
                windowSquare(w * 0.13)
            }
            .offset(y: h * 0.06)
        }
        .frame(width: w, height: h)
        .compositingGroup()
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private func tower(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(shade)
                .frame(width: width, height: height * 0.4)
            RoundedRectangle(cornerRadius: 1)
                .fill(shade)
                .frame(width: width, height: height * 0.6)
        }
    }

    private func windowSquare(_ side: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(trim)
            .frame(width: side, height: side)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - TrainSprite
//
// A small flat toy train, colored to match its destination station.
// Faces the direction of travel via `heading` (radians).

struct TrainSprite: View {
    let colorHex: String
    var size: CGFloat = 26
    var heading: Angle = .zero

    private var base: Color { Color(hex: colorHex) }
    private var shade: Color { base.darker(by: 0.25) }
    private var trim: Color { Color(hex: "#EFEAD8") }

    var body: some View {
        let w = size, h = size * 0.62

        ZStack {
            // Body
            RoundedRectangle(cornerRadius: h * 0.3)
                .fill(base)
                .frame(width: w, height: h)

            // Cab
            RoundedRectangle(cornerRadius: h * 0.2)
                .fill(base)
                .frame(width: w * 0.42, height: h * 1.3)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(trim)
                        .frame(width: w * 0.24, height: h * 0.5)
                        .offset(y: -h * 0.18)
                )
                .offset(x: -w * 0.26, y: -h * 0.32)

            // Wheels
            HStack(spacing: w * 0.28) {
                wheel(h * 0.34)
                wheel(h * 0.34)
                wheel(h * 0.34)
            }
            .offset(y: h * 0.42)

            // Smokestack
            RoundedRectangle(cornerRadius: 1.5)
                .fill(shade)
                .frame(width: w * 0.1, height: h * 0.32)
                .offset(x: w * 0.32, y: -h * 0.5)
        }
        .frame(width: w, height: h * 1.5)
        .rotationEffect(heading)
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
    }

    private func wheel(_ diameter: CGFloat) -> some View {
        Circle().fill(shade).frame(width: diameter, height: diameter)
    }
}

// MARK: - Color darkening helper

private extension Color {
    /// Returns a darker shade of this color, mixed toward black by
    /// `amount` (0...1). Used to derive trim/shadow tones for sprites
    /// from a single base hex, so each destination only needs one
    /// color value.
    func darker(by amount: Double) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: Double(r) * (1 - amount),
            green: Double(g) * (1 - amount),
            blue: Double(b) * (1 - amount),
            opacity: Double(a)
        )
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        StationSprite(colorHex: "#FF5E5B")
        StationSprite(colorHex: "#4A7BFF")
        TrainSprite(colorHex: "#00C2A8")
    }
    .padding()
    .background(Color(hex: "#F5F1E8"))
}