import Combine
import Foundation
import MusicKit
import Observation

/// Owns every time-based control: quiet hours, the sleep timer, the daily
/// listening budget, the "music is almost done" warning, and the soft stop
/// (pause at the next song boundary rather than mid-chorus, with a hard cap
/// so an eight-minute song can't stretch bedtime forever).
@MainActor
@Observable
final class ScheduleService {
    /// Quiet hours are active right now — wall shows the asleep card.
    private(set) var quietActive = false
    /// The daily listening budget is used up — wall shows the done card.
    private(set) var restActive = false
    /// A stop is coming within ~2 minutes — show/speak the gentle warning.
    private(set) var warningActive = false
    /// Sleep timer deadline, if armed.
    private(set) var sleepDeadline: Date?
    /// Minutes of music heard today (counted while the app is running).
    private(set) var todayMinutes = 0

    @ObservationIgnored private var speech: SpeechManager?
    @ObservationIgnored private var cancellable: AnyCancellable?
    @ObservationIgnored private var lastTick: Date?
    @ObservationIgnored private var pendingSoftStop = false
    @ObservationIgnored private var softStopHardDeadline: Date?
    @ObservationIgnored private var lastWarningAt: Date?

    nonisolated init() {}

    // MARK: - Time helpers

    static func minutesOfDay(_ date: Date = .now) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Whether a start–end window (minutes of day, may wrap past midnight)
    /// contains the given moment.
    static func windowContains(start: Int, end: Int, date: Date = .now) -> Bool {
        let now = minutesOfDay(date)
        if start == end { return true }
        if start < end { return now >= start && now < end }
        return now >= start || now < end
    }

    /// True when a scheduled tile should appear on the wall right now.
    func isTileAvailable(_ tile: Tile) -> Bool {
        guard tile.hasTimeWindow else { return true }
        return Self.windowContains(
            start: tile.windowStartMinutes, end: tile.windowEndMinutes)
    }

    // MARK: - Sleep timer

    func armSleepTimer(minutes: Int) {
        sleepDeadline = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        warningActive = false
        lastWarningAt = nil
    }

    func cancelSleepTimer() {
        sleepDeadline = nil
        warningActive = false
        pendingSoftStop = false
        softStopHardDeadline = nil
    }

    // MARK: - Lifecycle

    /// Call once. Watches song changes so a pending soft stop lands on a
    /// song boundary.
    func start(speech: SpeechManager) {
        self.speech = speech
        guard cancellable == nil else { return }
        cancellable = SystemMusicPlayer.shared.queue.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.pendingSoftStop else { return }
                    self.completeSoftStop()
                }
            }
    }

    /// Called every ~20 seconds from the root view while the app runs.
    func tick(settings: AppSettings) {
        let now = Date.now

        // Accumulate listening time while music is audibly playing.
        if SystemMusicPlayer.shared.state.playbackStatus == .playing,
            let lastTick
        {
            addListeningSeconds(min(now.timeIntervalSince(lastTick), 120))
        }
        lastTick = now
        todayMinutes = storedTodaySeconds() / 60

        // Quiet hours.
        let quietNow =
            settings.quietHoursEnabled
            && Self.windowContains(
                start: settings.quietStartMinutes, end: settings.quietEndMinutes)
        if quietNow && !quietActive {
            beginSoftStop()
        }
        quietActive = quietNow

        // Daily budget.
        let restNow =
            settings.dailyLimitMinutes > 0
            && todayMinutes >= settings.dailyLimitMinutes
        if restNow && !restActive {
            beginSoftStop()
        }
        restActive = restNow

        // Sleep timer.
        if let deadline = sleepDeadline {
            if now >= deadline {
                sleepDeadline = nil
                beginSoftStop()
            } else if deadline.timeIntervalSince(now) <= 120 {
                warn(speak: settings.speakOnPlay)
            }
        }

        // Warn ahead of quiet hours too.
        if settings.quietHoursEnabled, !quietNow,
            minutesUntil(settings.quietStartMinutes) <= 2
        {
            warn(speak: settings.speakOnPlay)
        }

        // Soft-stop hard cap: never drift more than 6 minutes past a stop.
        if pendingSoftStop, let cap = softStopHardDeadline, now >= cap {
            completeSoftStop()
        }

        // Clear a stale warning once nothing is pending.
        if warningActive, sleepDeadline == nil, !pendingSoftStop,
            !(settings.quietHoursEnabled && minutesUntil(settings.quietStartMinutes) <= 2)
        {
            warningActive = false
        }
    }

    // MARK: - Private

    private func minutesUntil(_ startMinutes: Int) -> Int {
        let now = Self.minutesOfDay()
        return (startMinutes - now + 1440) % 1440
    }

    private func warn(speak: Bool) {
        // At most one spoken warning per 10 minutes.
        if let last = lastWarningAt, Date.now.timeIntervalSince(last) < 600 {
            warningActive = true
            return
        }
        lastWarningAt = .now
        warningActive = true
        if speak {
            speech?.speak("The music is almost done.")
        }
    }

    private func beginSoftStop() {
        warningActive = false
        guard SystemMusicPlayer.shared.state.playbackStatus == .playing else {
            return
        }
        pendingSoftStop = true
        softStopHardDeadline = Date.now.addingTimeInterval(360)
    }

    private func completeSoftStop() {
        pendingSoftStop = false
        softStopHardDeadline = nil
        warningActive = false
        SystemMusicPlayer.shared.pause()
    }

    // MARK: - Daily listening storage

    private func todayKey() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        return "listening-\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private func storedTodaySeconds() -> Int {
        UserDefaults.standard.integer(forKey: todayKey())
    }

    private func addListeningSeconds(_ seconds: TimeInterval) {
        let key = todayKey()
        UserDefaults.standard.set(
            UserDefaults.standard.integer(forKey: key) + Int(seconds), forKey: key)
    }
}
