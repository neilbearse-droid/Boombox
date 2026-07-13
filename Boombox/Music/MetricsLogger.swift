import Combine
import Foundation
import MusicKit
import Observation
import SwiftData

/// Writes listening history: tile taps as they happen, and song changes
/// observed from the system player's queue while the app is running.
/// (Playback belongs to the Music app, so songs played while Boombox is
/// fully closed can't be seen — the metrics screen says so.)
@MainActor
@Observable
final class MetricsLogger {
    @ObservationIgnored private var cancellable: AnyCancellable?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var playback: PlaybackService?
    @ObservationIgnored private var lastSongKey: String?

    nonisolated init() {}

    func start(context: ModelContext, playback: PlaybackService) {
        self.context = context
        self.playback = playback
        guard cancellable == nil else { return }
        cancellable = SystemMusicPlayer.shared.queue.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.recordCurrentSongIfNew()
                }
            }
    }

    func logTilePlay(_ tile: Tile) {
        context?.insert(
            PlayEvent(
                kind: .tilePlay, tileLabel: tile.label,
                songTitle: nil, artistName: nil))
    }

    private func recordCurrentSongIfNew() {
        guard let context,
            let entry = SystemMusicPlayer.shared.queue.currentEntry,
            !entry.title.isEmpty
        else { return }

        var artist: String?
        if case .song(let song) = entry.item {
            artist = song.artistName
        }
        let key = entry.title + "|" + (artist ?? "")
        guard key != lastSongKey else { return }
        lastSongKey = key

        let tileLabel = currentTileLabel()
        context.insert(
            PlayEvent(
                kind: .song, tileLabel: tileLabel,
                songTitle: entry.title, artistName: artist))
    }

    private func currentTileLabel() -> String? {
        guard let context, let tileID = playback?.playingTileID else { return nil }
        var descriptor = FetchDescriptor<Tile>(
            predicate: #Predicate { $0.id == tileID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.label
    }

    /// History is capped at 90 days; called once per launch.
    func pruneOldEvents() {
        guard let context else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
        try? context.delete(
            model: PlayEvent.self,
            where: #Predicate { $0.date < cutoff })
    }
}
