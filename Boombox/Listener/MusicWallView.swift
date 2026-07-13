import MusicKit
import SwiftData
import SwiftUI

/// The listener's home screen: a vertical-scrolling wall of big tiles.
/// Scroll and tap only — no swipes, long-presses, context menus, or refresh.
struct MusicWallView: View {
    @Environment(MusicService.self) private var music
    @Environment(PlaybackService.self) private var playback
    @Environment(SpeechManager.self) private var speech
    @Environment(MetricsLogger.self) private var metrics
    @Query(sort: \Tile.sortIndex) private var tiles: [Tile]
    @ObservedObject private var playerState = SystemMusicPlayer.shared.state

    let settings: AppSettings
    let openParentGate: () -> Void

    @State private var path: [UUID] = []
    @State private var lastTapTileID: UUID?
    @State private var lastTapTime: Date = .distantPast
    @State private var showPlaybackError = false

    private var visibleTiles: [Tile] {
        tiles.filter { !$0.isHidden && !music.isOrphaned($0) }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 16),
            count: settings.columns == 1 ? 1 : 2)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if music.needsSetup || visibleTiles.isEmpty {
                    SetupCard(action: openParentGate)
                        .padding(24)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(visibleTiles) { tile in
                            TileButton(
                                tile: tile,
                                columns: settings.columns,
                                showLabel: settings.showLabels,
                                calmMode: settings.calmMode,
                                isCurrent: playback.playingTileID == tile.id,
                                isAudiblyPlaying: playback.playingTileID == tile.id
                                    && playerState.playbackStatus == .playing,
                                isLoading: playback.startingTileID == tile.id,
                                artwork: music.playlist(withID: tile.playlistID)?.artwork
                            ) {
                                handleTap(tile)
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 96)
                }
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { tileID in
                if let tile = tiles.first(where: { $0.id == tileID }) {
                    NowPlayingView(tile: tile, settings: settings)
                }
            }
        }
        .fullScreenCover(isPresented: $showPlaybackError) {
            MessageCardView(message: "The music can't play right now.") {
                showPlaybackError = false
            }
        }
        .onOpenURL { url in
            // boombox://play/<tile-uuid> from the Home/Lock Screen widgets.
            guard url.scheme == "boombox", url.host == "play",
                let id = UUID(uuidString: url.lastPathComponent),
                let tile = tiles.first(where: { $0.id == id }),
                !tile.isHidden, !music.isOrphaned(tile)
            else { return }
            handleTap(tile)
        }
    }

    private func handleTap(_ tile: Tile) {
        // Repeat taps on the same tile within 500 ms are ignored.
        let now = Date.now
        if lastTapTileID == tile.id, now.timeIntervalSince(lastTapTime) < 0.5 {
            return
        }
        // Reduce repeat taps: one accepted wall tap per 1.5s, on ANY tile
        // (stray second touches often land on a neighbouring tile), and a
        // brief shield after coming back from Now Playing so a trailing
        // touch on the back button can't start a random tile.
        if settings.reduceRepeatTaps {
            if TapGuard.isCooling("navigation", cooldown: 1.0) { return }
            guard TapGuard.allow("wall", cooldown: 1.5) else { return }
        }
        lastTapTileID = tile.id
        lastTapTime = now

        Haptics.soft()

        // Tapping the tile that is already playing opens Now Playing
        // without restarting the music.
        if playback.playingTileID == tile.id {
            path = [tile.id]
            return
        }

        if settings.speakOnPlay {
            speech.speak("Playing \(tile.effectiveSpokenName)")
        }
        // Navigate immediately — state stays visible while the audio spins
        // up. If playback fails, pop back and show the friendly card.
        path = [tile.id]
        metrics.logTilePlay(tile)
        Task {
            do {
                try await playback.play(
                    tile: tile,
                    playlist: music.playlist(withID: tile.playlistID),
                    allowExplicit: settings.allowExplicit)
            } catch {
                path = []
                showPlaybackError = true
                if settings.speakOnPlay {
                    speech.speak("The music can't play right now.")
                }
            }
        }
    }
}

/// Shown when music needs setup or no tiles exist yet. Opens the parent gate.
private struct SetupCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: "music.note")
                    .font(.system(size: 44))
                Text("Music needs setup")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.secondarySystemBackground)))
        }
        .accessibilityLabel("Music needs setup")
    }
}
