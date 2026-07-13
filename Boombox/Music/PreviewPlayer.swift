import AVFoundation
import Foundation
import Observation

/// Plays 30-second catalogue previews in the playlist builder through AVPlayer.
/// Preview assets end on their own; tapping the same song again stops early.
@MainActor
@Observable
final class PreviewPlayer {
    private(set) var playingURL: URL?
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    nonisolated init() {}

    func toggle(url: URL) {
        if playingURL == url {
            stop()
            return
        }
        stop()
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
        self.player = player
        playingURL = url
        player.play()
    }

    func stop() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        playingURL = nil
    }
}
