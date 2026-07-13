import Foundation

/// The JSON contract between the app and the widget extension. The widget
/// target keeps its own copy of these types (same field names — the JSON is
/// the interface); change one, change both.
struct WidgetSnapshot: Codable {
    var calmMode: Bool
    var tiles: [WidgetTile]
}

struct WidgetTile: Codable, Identifiable {
    var id: UUID
    var label: String
    var colourID: Int
    /// "emoji" | "symbol" | "image" | "plain"
    var kind: String
    /// Emoji character, SF Symbol name, or an image filename inside the
    /// App Group's WidgetIcons directory.
    var value: String?
}

enum SharedWidgetConstants {
    /// Convention: the group ID is "group." + the app's bundle ID, and the
    /// widget's bundle ID is the app's + ".Widgets". Keep the APP_GROUP_ID
    /// build setting in the project aligned with this.
    static var appGroupID: String {
        var base = Bundle.main.bundleIdentifier ?? "com.example.Boombox"
        if base.hasSuffix(".Widgets") {
            base.removeLast(".Widgets".count)
        }
        return "group." + base
    }

    static let snapshotFilename = "widget-tiles.json"
    static let iconsDirectory = "WidgetIcons"
}
