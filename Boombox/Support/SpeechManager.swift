import AVFoundation
import Observation

/// Speaks short confirmations like "Playing Imagine Dragons".
/// Language stays literal and short everywhere the listener hears it.
@Observable
final class SpeechManager {
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}
