import Foundation
import MusicKit
import Observation

/// Plays tiles through SystemMusicPlayer so music survives backgrounding and
/// force-quit, and lock screen / Control Centre / AirPlay all work natively.
@MainActor
@Observable
final class PlaybackService {
    enum PlaybackError: Error {
        case playlistNotFound
        case emptyPlaylist
    }

    /// The tile whose playlist currently owns the queue (set by this app).
    private(set) var playingTileID: UUID?
    /// The tile currently spinning up, for a loading state on its face.
    private(set) var startingTileID: UUID?

    nonisolated init() {}

    private var player: SystemMusicPlayer { .shared }

    func play(tile: Tile) async throws {
        startingTileID = tile.id
        defer { startingTileID = nil }

        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(tile.playlistID))
        let response = try await request.response()
        guard let playlist = response.items.first else {
            throw PlaybackError.playlistNotFound
        }
        let detailed = try await playlist.with([.tracks])
        let tracks = detailed.tracks ?? []
        guard !tracks.isEmpty else {
            throw PlaybackError.emptyPlaylist
        }

        player.queue = SystemMusicPlayer.Queue(for: tracks)
        player.state.shuffleMode = tile.shuffle ? .songs : .off
        player.state.repeatMode = tile.repeatAll ? .all : MusicPlayer.RepeatMode.none
        try await player.play()
        playingTileID = tile.id
    }

    func pause() {
        player.pause()
    }

    func resume() async {
        try? await player.play()
    }

    func skipToNext() async {
        try? await player.skipToNextEntry()
    }
}
