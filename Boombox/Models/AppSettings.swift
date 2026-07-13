import Foundation
import SwiftData

@Model
final class AppSettings {
    var columns: Int = 2
    var showLabels: Bool = true
    var speakOnPlay: Bool = true
    var calmMode: Bool = false
    var showNextButton: Bool = false
    /// When false, explicit-tagged songs are skipped in playback and hidden
    /// in the playlist builder.
    var allowExplicit: Bool = true
    /// Ignores extra touches for a moment after each accepted tap, for
    /// listeners whose taps land several times.
    var reduceRepeatTaps: Bool = false

    init() {}

    /// The app keeps exactly one AppSettings row. Fetch it, creating it on first run.
    static func fetchOrCreate(in context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
