import Combine
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

    /// Song IDs belonging to the currently badged tile, used to notice when
    /// something external (Siri, the Music app) takes over the system queue.
    @ObservationIgnored private var currentTrackIDs: Set<String> = []
    /// True once we've seen the current tile's own music actually playing —
    /// proves the IDs are comparable before we ever clear the badge.
    @ObservationIgnored private var confirmedOwnPlayback = false
    @ObservationIgnored private var queueObserver: AnyCancellable?

    nonisolated init() {}

    private var player: SystemMusicPlayer { .shared }

    /// Watches the system queue so the playing-tile badge reflects reality:
    /// if foreign content replaces our queue, the badge clears. Call once.
    func startMonitoring() {
        guard queueObserver == nil else { return }
        queueObserver = SystemMusicPlayer.shared.queue.objectWillChange
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.reconcilePlayingTile() }
            }
    }

    /// Clears the badge when the audio no longer belongs to the badged tile.
    /// Conservative: only clears after confirming the tile's own tracks
    /// played first, so a harmless ID-format mismatch never false-clears.
    private func reconcilePlayingTile() {
        guard playingTileID != nil, !currentTrackIDs.isEmpty,
            let entry = SystemMusicPlayer.shared.queue.currentEntry,
            case .song(let song) = entry.item
        else { return }

        if currentTrackIDs.contains(song.id.rawValue) {
            confirmedOwnPlayback = true
        } else if confirmedOwnPlayback {
            // Something external took over the queue (e.g. Siri playing a
            // catalog song). The badged tile no longer reflects what's heard.
            playingTileID = nil
            currentTrackIDs = []
            confirmedOwnPlayback = false
        }
    }

    /// Records the badged tile's track IDs so reconcile can tell our music
    /// from foreign content. Uses tracks already fetched when available,
    /// otherwise fetches in the background without blocking audio.
    private func trackBadge(for tile: Tile, playlist: Playlist, knownTracks: [Track]?) {
        currentTrackIDs = []
        confirmedOwnPlayback = false
        if let knownTracks {
            currentTrackIDs = Set(knownTracks.map { $0.id.rawValue })
            return
        }
        let tileID = tile.id
        Task { [weak self] in
            guard let detailed = try? await playlist.with([.tracks]) else { return }
            let ids = Set((detailed.tracks ?? []).map { $0.id.rawValue })
            await MainActor.run {
                guard let self, self.playingTileID == tileID else { return }
                self.currentTrackIDs = ids
            }
        }
    }

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

        var knownTracks: [Track]?
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
            knownTracks = Array(cleanTracks)
        }
        player.state.shuffleMode = tile.shuffle ? .songs : .off
        player.state.repeatMode = tile.repeatAll ? .all : MusicPlayer.RepeatMode.none
        // Optimistic, so the tile badge and Now Playing respond instantly.
        playingTileID = tile.id
        trackBadge(for: tile, playlist: playlist, knownTracks: knownTracks)
        do {
            try await player.play()
        } catch {
            playingTileID = nil
            currentTrackIDs = []
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
