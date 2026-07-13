import MusicKit
import SwiftUI

/// Full-screen Now Playing. At most three controls, all 88 pt or larger:
/// Back (top, "Music"), Pause/Play (dominant, centre), optional Next Song.
/// Going back never stops the music.
struct NowPlayingView: View {
    let tile: Tile
    let settings: AppSettings

    @Environment(MusicService.self) private var music
    @Environment(PlaybackService.self) private var playback
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var playerState = SystemMusicPlayer.shared.state
    @ObservedObject private var queue = SystemMusicPlayer.shared.queue

    private var swatch: TileSwatch { TilePalette.swatch(tile.colourID) }
    private var isPlaying: Bool { playerState.playbackStatus == .playing }

    private var currentSong: Song? {
        if case .song(let song) = queue.currentEntry?.item {
            return song
        }
        return nil
    }

    private var displayArtwork: Artwork? {
        currentSong?.artwork ?? music.playlist(withID: tile.playlistID)?.artwork
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                backButton
                Spacer()
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 8)

            artworkView
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Text(tile.label)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let title = queue.currentEntry?.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            progressBar
                .padding(.horizontal, 40)
                .padding(.top, 20)

            Spacer(minLength: 8)

            controls
                .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Pieces

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 24))
                Text("Music")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
            }
            .frame(minWidth: 140, minHeight: 88)
        }
        .accessibilityLabel("Music")
    }

    @ViewBuilder
    private var artworkView: some View {
        if let displayArtwork {
            ArtworkImage(displayArtwork, width: 300, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 24))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(swatch.background(calmMode: settings.calmMode))
                    .frame(width: 300, height: 300)
                if tile.iconType == .emoji, let emoji = tile.iconValue {
                    Text(emoji).font(.system(size: 130))
                } else if tile.iconType == .photo,
                    let filename = tile.iconValue,
                    let image = PhotoStore.load(filename)
                {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 300, height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 110))
                        .foregroundStyle(swatch.textColor(calmMode: settings.calmMode))
                }
            }
        }
    }

    /// Simple non-interactive progress. No scrubber.
    private var progressBar: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let duration = currentSong?.duration ?? 0
            let elapsed = SystemMusicPlayer.shared.playbackTime
            ProgressView(value: duration > 0 ? min(elapsed / duration, 1) : 0)
                .tint(swatch.background(calmMode: settings.calmMode))
        }
        .accessibilityHidden(true)
    }

    private var controls: some View {
        HStack(spacing: 32) {
            Button {
                Haptics.soft()
                if isPlaying {
                    playback.pause()
                } else {
                    Task { await playback.resume() }
                }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(swatch.textColor(calmMode: settings.calmMode))
                    .frame(width: 128, height: 128)
                    .background(
                        Circle().fill(swatch.background(calmMode: settings.calmMode)))
            }
            .buttonStyle(TilePressStyle(calmMode: settings.calmMode))
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            if settings.showNextButton {
                Button {
                    Haptics.soft()
                    Task { await playback.skipToNext() }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 96, height: 96)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(TilePressStyle(calmMode: settings.calmMode))
                .accessibilityLabel("Next Song")
            }
        }
    }
}
