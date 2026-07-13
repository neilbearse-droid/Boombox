import Foundation
import SwiftData

enum PlayEventKind: String, Codable {
    /// The listener tapped a tile.
    case tilePlay
    /// A song started (logged while the app is running).
    case song
}

/// One row of listening history. Labels are denormalized so history stays
/// readable even after a tile or playlist is deleted.
@Model
final class PlayEvent {
    var date: Date = Date.now
    var kindRaw: String = PlayEventKind.tilePlay.rawValue
    var tileLabel: String?
    var songTitle: String?
    var artistName: String?

    var kind: PlayEventKind {
        get { PlayEventKind(rawValue: kindRaw) ?? .tilePlay }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: PlayEventKind, tileLabel: String?, songTitle: String?, artistName: String?) {
        self.date = .now
        self.kindRaw = kind.rawValue
        self.tileLabel = tileLabel
        self.songTitle = songTitle
        self.artistName = artistName
    }
}
