import UIKit

/// Haptics only — no UI sound effects anywhere in the app. The strong
/// variant helps a listener feel that a tap landed, so they don't re-tap.
enum Haptics {
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func tap(strong: Bool) {
        UIImpactFeedbackGenerator(style: strong ? .heavy : .soft).impactOccurred()
    }
}
