import Foundation
import SwiftData

enum TileIconType: String, Codable, CaseIterable {
    /// The playlist's own artwork.
    case artwork
    /// One album cover from the playlist, chosen by the parent and cached
    /// locally (iconValue is a filename in Application Support).
    case albumCover
    case emoji
    /// An SF Symbol name (iconValue is the symbol name).
    case symbol
    case photo
}

@Model
final class Tile {
    var id: UUID = UUID()
    var playlistID: String = ""
    var label: String = ""
    var spokenName: String?
    var iconTypeRaw: String = TileIconType.artwork.rawValue
    var iconValue: String?
    var colourID: Int = 0
    var shuffle: Bool = false
    var repeatAll: Bool = true
    var isHidden: Bool = false
    var showInWidget: Bool = true
    var sortIndex: Int = 0
    var createdAt: Date = Date.now

    var iconType: TileIconType {
        get { TileIconType(rawValue: iconTypeRaw) ?? .artwork }
        set { iconTypeRaw = newValue.rawValue }
    }

    /// The name spoken aloud when the tile is tapped. Falls back to the label.
    var effectiveSpokenName: String {
        let spoken = spokenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return spoken.isEmpty ? label : spoken
    }

    init(
        playlistID: String,
        label: String,
        iconType: TileIconType = .artwork,
        iconValue: String? = nil,
        colourID: Int = 0,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.playlistID = playlistID
        self.label = label
        self.spokenName = nil
        self.iconTypeRaw = iconType.rawValue
        self.iconValue = iconValue
        self.colourID = colourID
        self.shuffle = false
        self.repeatAll = true
        self.isHidden = false
        self.showInWidget = true
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}
