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
