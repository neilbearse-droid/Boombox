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
    /// Single source of truth: the APP_GROUP_ID build setting, surfaced into
    /// Info.plist (which the entitlement also uses, so they can't disagree).
    /// Falls back to deriving from the bundle ID if the key is missing or
    /// its build variable didn't resolve.
    static var appGroupID: String {
        if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String,
            !id.isEmpty, !id.hasPrefix("$(")
        {
            return id
        }
        var base = Bundle.main.bundleIdentifier ?? "com.example.Boombox"
        if base.hasSuffix(".Widgets") {
            base.removeLast(".Widgets".count)
        }
        return "group." + base
    }

    static let snapshotFilename = "widget-tiles.json"
    static let iconsDirectory = "WidgetIcons"
}
