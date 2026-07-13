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
        case nothingPlayable
    }

    /// The tile whose playlist currently owns the queue (set by this app).
    private(set) var playingTileID: UUID?
    /// The tile currently spinning up, for a loading state on its face.
    private(set) var startingTileID: UUID?

    nonisolated init() {}

    private var player: SystemMusicPlayer { .shared }

    /// Queues the playlist item directly — no track fetch, no extra library
    /// round trip — so audio starts as fast as the system player allows.
    /// Pass the cached playlist from MusicService when available; the
    /// library lookup only runs on a cache miss.
    ///
    /// With allowExplicit false the fast path can't be used: the track list
    /// is fetched and explicit-tagged songs are stripped before queueing.
    func play(tile: Tile, playlist cached: Playlist?, allowExplicit: Bool = true) async throws {
        startingTileID = tile.id
        defer { startingTileID = nil }

        let playlist: Playlist
        if let cached {
            playlist = cached
        } else {
            var request = MusicLibraryRequest<Playlist>()
            request.filter(matching: \.id, equalTo: MusicItemID(tile.playlistID))
            guard let found = try await request.response().items.first else {
                throw PlaybackError.playlistNotFound
            }
            playlist = found
        }

        if allowExplicit {
            player.queue = SystemMusicPlayer.Queue(for: [playlist])
        } else {
            let detailed = try await playlist.with([.tracks])
            let cleanTracks = (detailed.tracks ?? []).filter {
                $0.contentRating != .explicit
            }
            guard !cleanTracks.isEmpty else {
                throw PlaybackError.nothingPlayable
            }
            player.queue = SystemMusicPlayer.Queue(for: cleanTracks)
        }
        player.state.shuffleMode = tile.shuffle ? .songs : .off
        player.state.repeatMode = tile.repeatAll ? .all : MusicPlayer.RepeatMode.none
        // Optimistic, so the tile badge and Now Playing respond instantly.
        playingTileID = tile.id
        do {
            try await player.play()
        } catch {
            playingTileID = nil
            throw error
        }
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
