import SwiftUI

/// One of the eight parent-assignable tile colours. Each swatch carries a
/// standard and a Calm Mode (muted) variant, and picks black or white label
/// text by WCAG contrast so every combination clears AA.
struct TileSwatch: Identifiable {
    struct RGB {
        let r: Double
        let g: Double
        let b: Double

        var color: Color { Color(red: r, green: g, blue: b) }

        /// WCAG relative luminance.
        var luminance: Double {
            func linear(_ c: Double) -> Double {
                c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
    }

    let id: Int
    let name: String
    let standard: RGB
    let calm: RGB

    func background(calmMode: Bool) -> Color {
        (calmMode ? calm : standard).color
    }

    /// Black or white, whichever has the higher contrast ratio on this swatch.
    func textColor(calmMode: Bool) -> Color {
        let l = (calmMode ? calm : standard).luminance
        let contrastWithWhite = 1.05 / (l + 0.05)
        let contrastWithBlack = (l + 0.05) / 0.05
        return contrastWithWhite >= contrastWithBlack ? .white : .black
    }
}

enum TilePalette {
    static let swatches: [TileSwatch] = [
        TileSwatch(id: 0, name: "Red",
                   standard: .init(r: 0.80, g: 0.20, b: 0.18),
                   calm: .init(r: 0.76, g: 0.54, b: 0.52)),
        TileSwatch(id: 1, name: "Orange",
                   standard: .init(r: 0.90, g: 0.49, b: 0.08),
                   calm: .init(r: 0.85, g: 0.68, b: 0.50)),
        TileSwatch(id: 2, name: "Yellow",
                   standard: .init(r: 0.95, g: 0.77, b: 0.19),
                   calm: .init(r: 0.90, g: 0.84, b: 0.62)),
        TileSwatch(id: 3, name: "Green",
                   standard: .init(r: 0.16, g: 0.52, b: 0.26),
                   calm: .init(r: 0.58, g: 0.72, b: 0.60)),
        TileSwatch(id: 4, name: "Teal",
                   standard: .init(r: 0.06, g: 0.48, b: 0.53),
                   calm: .init(r: 0.54, g: 0.70, b: 0.71)),
        TileSwatch(id: 5, name: "Blue",
                   standard: .init(r: 0.12, g: 0.35, b: 0.75),
                   calm: .init(r: 0.56, g: 0.65, b: 0.81)),
        TileSwatch(id: 6, name: "Purple",
                   standard: .init(r: 0.42, g: 0.27, b: 0.70),
                   calm: .init(r: 0.66, g: 0.60, b: 0.78)),
        TileSwatch(id: 7, name: "Pink",
                   standard: .init(r: 0.80, g: 0.30, b: 0.55),
                   calm: .init(r: 0.82, g: 0.64, b: 0.72)),
    ]

    static func swatch(_ id: Int) -> TileSwatch {
        swatches.first { $0.id == id } ?? swatches[0]
    }
}
