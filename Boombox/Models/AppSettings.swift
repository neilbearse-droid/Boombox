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
    /// Heavier haptic on accepted taps so the listener feels the tap land.
    var strongHaptics: Bool = false
    /// Cap on tiles shown on the wall: 0 = all, 1 = one big tile, or 2/4.
    var maxTiles: Int = 0
    /// Quiet hours: wall sleeps and music soft-stops inside the window.
    var quietHoursEnabled: Bool = false
    var quietStartMinutes: Int = 21 * 60
    var quietEndMinutes: Int = 7 * 60
    /// Daily listening budget in minutes; 0 = no limit.
    var dailyLimitMinutes: Int = 0
    /// Label / Now Playing text multiplier: 1.0 normal, 1.25 large, 1.5 huge.
    var textScale: Double = 1.0
    /// Spoken-confirmation speed multiplier: 1.0 normal, 0.75 slower.
    var speechRate: Double = 1.0
    /// Thick, auto-contrast borders on tiles for low vision.
    var highContrastTiles: Bool = false
    /// Show big-text lyrics on Now Playing (best-effort, community source).
    var showLyrics: Bool = false
    /// Dim overlay strength on the listener screens: 0 off … ~0.45 high.
    var screenDim: Double = 0

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
