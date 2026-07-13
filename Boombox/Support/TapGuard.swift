import Foundation

/// Soaks up spurious repeat touches for listeners whose taps land more than
/// once. Only consulted when the "Reduce repeat taps" setting is on.
@MainActor
enum TapGuard {
    private static var lastAccepted: [String: Date] = [:]

    /// Records an accepted interaction and reports whether it was allowed.
    /// Returns false while `id` is still cooling down.
    static func allow(_ id: String, cooldown: TimeInterval) -> Bool {
        let now = Date.now
        if let last = lastAccepted[id], now.timeIntervalSince(last) < cooldown {
            return false
        }
        lastAccepted[id] = now
        return true
    }

    /// Stamps an event (e.g. leaving a screen) without gating it, so other
    /// controls can hold off briefly — a trailing touch after "back" should
    /// not start a random tile on the wall underneath.
    static func stamp(_ id: String) {
        lastAccepted[id] = .now
    }

    static func isCooling(_ id: String, cooldown: TimeInterval) -> Bool {
        guard let last = lastAccepted[id] else { return false }
        return Date.now.timeIntervalSince(last) < cooldown
    }
}
