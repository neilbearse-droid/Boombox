import Foundation
import SwiftUI
import UIKit

/// Widget-side copy of the JSON contract written by the app's
/// WidgetSnapshotStore. Field names must match the app's copy exactly.
struct WidgetSnapshot: Codable {
    var calmMode: Bool
    var tiles: [WidgetTile]
}

struct WidgetTile: Codable, Identifiable {
    var id: UUID
    var label: String
    var colourID: Int
    var kind: String
    var value: String?
}

enum WidgetStore {
    /// "group." + the containing app's bundle ID (this extension's bundle ID
    /// minus the ".Widgets" suffix). Matches the app's derivation.
    static var appGroupID: String {
        var base = Bundle.main.bundleIdentifier ?? "com.example.Boombox.Widgets"
        if base.hasSuffix(".Widgets") {
            base.removeLast(".Widgets".count)
        }
        return "group." + base
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func load() -> WidgetSnapshot? {
        guard let container = containerURL else { return nil }
        let url = container.appendingPathComponent("widget-tiles.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func iconImage(_ filename: String) -> UIImage? {
        guard let container = containerURL else { return nil }
        let url = container
            .appendingPathComponent("WidgetIcons", isDirectory: true)
            .appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }

    static func playURL(for tile: WidgetTile) -> URL {
        URL(string: "boombox://play/\(tile.id.uuidString)")
            ?? URL(string: "boombox://play")!
    }
}

/// Widget-side copy of the app's 8-swatch palette, including Calm Mode
/// variants and WCAG-contrast label colour picking.
enum WidgetPalette {
    private struct RGB {
        let r: Double
        let g: Double
        let b: Double

        var color: Color { Color(red: r, green: g, blue: b) }

        var luminance: Double {
            func linear(_ c: Double) -> Double {
                c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
    }

    private static let standard: [RGB] = [
        RGB(r: 0.80, g: 0.20, b: 0.18), RGB(r: 0.90, g: 0.49, b: 0.08),
        RGB(r: 0.95, g: 0.77, b: 0.19), RGB(r: 0.16, g: 0.52, b: 0.26),
        RGB(r: 0.06, g: 0.48, b: 0.53), RGB(r: 0.12, g: 0.35, b: 0.75),
        RGB(r: 0.42, g: 0.27, b: 0.70), RGB(r: 0.80, g: 0.30, b: 0.55),
    ]

    private static let calm: [RGB] = [
        RGB(r: 0.76, g: 0.54, b: 0.52), RGB(r: 0.85, g: 0.68, b: 0.50),
        RGB(r: 0.90, g: 0.84, b: 0.62), RGB(r: 0.58, g: 0.72, b: 0.60),
        RGB(r: 0.54, g: 0.70, b: 0.71), RGB(r: 0.56, g: 0.65, b: 0.81),
        RGB(r: 0.66, g: 0.60, b: 0.78), RGB(r: 0.82, g: 0.64, b: 0.72),
    ]

    private static func rgb(_ id: Int, calmMode: Bool) -> RGB {
        let table = calmMode ? calm : standard
        return table.indices.contains(id) ? table[id] : table[0]
    }

    static func background(_ id: Int, calmMode: Bool) -> Color {
        rgb(id, calmMode: calmMode).color
    }

    static func textColor(_ id: Int, calmMode: Bool) -> Color {
        let l = rgb(id, calmMode: calmMode).luminance
        let contrastWithWhite = 1.05 / (l + 0.05)
        let contrastWithBlack = (l + 0.05) / 0.05
        return contrastWithWhite >= contrastWithBlack ? .white : .black
    }
}
