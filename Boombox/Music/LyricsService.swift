import Foundation
import MusicKit
import Observation

/// Best-effort lyrics from LRCLIB (lrclib.net) — a free, open, no-key
/// community lyrics database. Apple Music does not expose lyrics to
/// third-party apps through MusicKit, so this is a separate source: it
/// won't always have a match, and it isn't Apple's official lyrics.
@MainActor
@Observable
final class LyricsService {
    struct Line: Identifiable {
        let id = UUID()
        let time: TimeInterval?  // nil when the lyrics are unsynced
        let text: String
    }

    struct Lyrics {
        let lines: [Line]
        let synced: Bool
    }

    private(set) var current: Lyrics?
    private(set) var isLoading = false
    private(set) var failed = false
    @ObservationIgnored private var loadedKey: String?

    nonisolated init() {}

    func loadIfNeeded(for song: Song) async {
        let key = song.id.rawValue
        guard key != loadedKey else { return }
        loadedKey = key
        current = nil
        failed = false
        isLoading = true
        defer { isLoading = false }

        guard var components = URLComponents(string: "https://lrclib.net/api/get") else {
            failed = true
            return
        }
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: song.artistName),
            URLQueryItem(name: "track_name", value: song.title),
            URLQueryItem(name: "album_name", value: song.albumTitle ?? ""),
            URLQueryItem(
                name: "duration",
                value: String(Int(song.duration ?? 0))),
        ]
        guard let url = components.url else {
            failed = true
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Boombox (github.com/neilbearse-droid)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                let payload = try? JSONDecoder().decode(LRCLIBResponse.self, from: data)
            else {
                failed = true
                return
            }
            // Only apply if the song hasn't changed while we were fetching.
            guard loadedKey == key else { return }
            current = parse(payload)
            failed = current == nil
        } catch {
            failed = true
        }
    }

    private func parse(_ payload: LRCLIBResponse) -> Lyrics? {
        if let synced = payload.syncedLyrics, !synced.isEmpty {
            let lines = parseLRC(synced)
            if !lines.isEmpty { return Lyrics(lines: lines, synced: true) }
        }
        if let plain = payload.plainLyrics, !plain.isEmpty {
            let lines = plain.split(separator: "\n", omittingEmptySubsequences: false)
                .map { Line(time: nil, text: String($0)) }
            return Lyrics(lines: lines, synced: false)
        }
        return nil
    }

    /// Parses `[mm:ss.xx] text` LRC lines into timed lines, in order.
    private func parseLRC(_ raw: String) -> [Line] {
        var result: [Line] = []
        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            guard line.first == "[", let close = line.firstIndex(of: "]") else { continue }
            let stamp = line[line.index(after: line.startIndex)..<close]
            let text = String(line[line.index(after: close)...])
                .trimmingCharacters(in: .whitespaces)
            let parts = stamp.split(separator: ":")
            guard parts.count == 2,
                let minutes = Double(parts[0]),
                let seconds = Double(parts[1])
            else { continue }
            result.append(Line(time: minutes * 60 + seconds, text: text))
        }
        return result
    }

    private struct LRCLIBResponse: Decodable {
        let plainLyrics: String?
        let syncedLyrics: String?
    }
}
