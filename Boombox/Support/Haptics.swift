import UIKit

/// Soft haptics only — no UI sound effects anywhere in the app.
enum Haptics {
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
