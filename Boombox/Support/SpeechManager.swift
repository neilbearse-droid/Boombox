import AVFoundation
import Observation

/// Speaks short confirmations like "Playing Imagine Dragons".
/// Language stays literal and short everywhere the listener hears it.
///
/// Speech runs on the app's own audio session, which by default is silenced
/// by the ring/silent switch and refuses to mix with the Music app. So we
/// switch to a .playback session (ignores the silent switch, like the music
/// itself does) that ducks the music while speaking, and deactivate when
/// done so the music comes back to full volume.
@Observable
final class SpeechManager {
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegateProxy = DelegateProxy()

    init() {
        delegateProxy.onSpeechDone = { [weak self] in
            self?.deactivateSession()
        }
        synthesizer.delegate = delegateProxy
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Speak anyway; worst case is the old silent-switch behaviour.
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false, options: [.notifyOthersOnDeactivation])
    }

    /// AVSpeechSynthesizerDelegate requires NSObject; kept separate so the
    /// manager itself can stay a plain @Observable class.
    private final class DelegateProxy: NSObject, AVSpeechSynthesizerDelegate {
        var onSpeechDone: (() -> Void)?

        func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer,
            didFinish utterance: AVSpeechUtterance
        ) {
            onSpeechDone?()
        }

        func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer,
            didCancel utterance: AVSpeechUtterance
        ) {
            onSpeechDone?()
        }
    }
}
