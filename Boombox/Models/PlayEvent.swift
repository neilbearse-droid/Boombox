import Foundation
import SwiftData

enum PlayEventKind: String, Codable {
    /// The listener tapped a tile.
    case tilePlay
    /// A song started (logged while the app is running).
    case song
    /// A touch was swallowed by the debounce/repeat-tap guard — a signal
    /// that taps are landing more than once.
    case tapIgnored
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
    /// System output volume (0–1) when a song started, for the parent's
    /// "how loud is it back there" signal.
    var volume: Double?

    var kind: PlayEventKind {
        get { PlayEventKind(rawValue: kindRaw) ?? .tilePlay }
        set { kindRaw = newValue.rawValue }
    }

    init(
        kind: PlayEventKind, tileLabel: String?, songTitle: String?,
        artistName: String?, volume: Double? = nil
    ) {
        self.date = .now
        self.kindRaw = kind.rawValue
        self.tileLabel = tileLabel
        self.songTitle = songTitle
        self.artistName = artistName
        self.volume = volume
    }
}
