import SwiftUI

/// Parent mode ("Setup"): the tile manager, with settings reachable from the
/// toolbar and Done returning to the listener wall.
struct ParentModeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TileManagerView()
                .navigationTitle("Tiles")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
