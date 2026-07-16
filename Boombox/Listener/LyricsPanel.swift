import MusicKit
import SwiftUI

/// Big-text lyrics for Now Playing. Synced lyrics highlight and auto-scroll
/// the current line (karaoke-style); unsynced lyrics show as large scrollable
/// text. Shown in place of the artwork when the parent enables lyrics.
struct LyricsPanel: View {
    let song: Song?
    let textScale: Double
    let calmMode: Bool

    @State private var lyrics = LyricsService()
    @State private var activeLineID: UUID?

    var body: some View {
        Group {
            if lyrics.isLoading {
                centered { ProgressView() }
            } else if let words = lyrics.current {
                lyricsList(words)
            } else {
                // Calm, not an error: many songs simply have no words on file.
                centered {
                    VStack(spacing: 14) {
                        Image(systemName: "music.note")
                            .font(.system(size: 44))
                            .foregroundStyle(.tertiary)
                        Text("Just enjoy the music.")
                            .font(.system(
                                size: 22 * textScale, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
            }
        }
        .task(id: song?.id) {
            guard let song else { return }
            await lyrics.loadIfNeeded(for: song)
        }
    }

    private func lyricsList(_ words: LyricsService.Lyrics) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(words.lines) { line in
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(
                                    size: 26 * textScale, weight: .bold, design: .rounded))
                                .foregroundStyle(color(for: line, in: words))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                }
                .onChange(of: currentLineID(words)) { _, id in
                    guard words.synced, let id else { return }
                    withAnimation(calmMode ? nil : .easeInOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The line whose timestamp is the latest one at or before now.
    private func currentLineID(_ words: LyricsService.Lyrics) -> UUID? {
        guard words.synced else { return nil }
        let now = SystemMusicPlayer.shared.playbackTime
        return words.lines.last { ($0.time ?? .infinity) <= now }?.id
    }

    private func color(for line: LyricsService.Line, in words: LyricsService.Lyrics) -> Color {
        guard words.synced else { return .primary }
        return line.id == currentLineID(words) ? .primary : .secondary
    }
}
