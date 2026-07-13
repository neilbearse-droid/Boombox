import Foundation
import MusicKit
import Observation

/// Owns MusicKit authorization, subscription state, and the library playlist
/// cache used to resolve tiles. Authorization is only ever requested from
/// parent mode — the permission dialog must never surprise the listener.
@MainActor
@Observable
final class MusicService {
    var authStatus: MusicAuthorization.Status = MusicAuthorization.currentStatus
    var subscription: MusicSubscription?
    private(set) var libraryPlaylists: [Playlist] = []
    /// True once at least one library fetch has succeeded. Orphan detection
    /// only runs after a successful fetch, so a network blip never hides tiles.
    private(set) var libraryLoaded = false

    nonisolated init() {}

    /// The wall shows the "Music needs setup" card when this is true.
    var needsSetup: Bool {
        if authStatus != .authorized { return true }
        if let subscription, !subscription.canPlayCatalogContent { return true }
        return false
    }

    /// Called from parent mode only.
    func requestAuthorization() async {
        authStatus = await MusicAuthorization.request()
        if authStatus == .authorized {
            await refreshLibrary()
        }
    }

    /// Long-running observer; call once from a .task.
    func observeSubscription() async {
        for await update in MusicSubscription.subscriptionUpdates {
            subscription = update
        }
    }

    func refreshLibrary() async {
        authStatus = MusicAuthorization.currentStatus
        guard authStatus == .authorized else { return }
        do {
            var request = MusicLibraryRequest<Playlist>()
            request.limit = 500
            let response = try await request.response()
            libraryPlaylists = Array(response.items)
            libraryLoaded = true
        } catch {
            // Keep the previous cache; never orphan tiles on a failed fetch.
        }
    }

    func playlist(withID id: String) -> Playlist? {
        libraryPlaylists.first { $0.id.rawValue == id }
    }

    /// A tile is orphaned when its playlist was deleted in the Music app.
    /// Orphaned tiles auto-hide from the wall and surface in the tile manager.
    func isOrphaned(_ tile: Tile) -> Bool {
        libraryLoaded && playlist(withID: tile.playlistID) == nil
    }
}
