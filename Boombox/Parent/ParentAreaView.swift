import SwiftUI

/// Presented full-screen when the corner gear is held. Shows the PIN gate
/// first, then parent mode ("Setup") once unlocked.
struct ParentAreaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false

    var body: some View {
        if unlocked {
            ParentModeView()
        } else {
            PINGateView(
                mode: .unlock,
                onSuccess: { unlocked = true },
                onCancel: { dismiss() })
        }
    }
}
