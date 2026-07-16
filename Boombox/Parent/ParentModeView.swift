import SwiftData
import SwiftUI

/// Setup: the tile manager, with settings reachable from the toolbar and
/// Done returning to the listener wall. On first entry it presents the
/// guided onboarding.
struct ParentModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(MusicService.self) private var music
    @Query private var allSettings: [AppSettings]
    @State private var showOnboarding = false

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
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            MetricsView()
                        } label: {
                            Image(systemName: "chart.bar")
                        }
                        .accessibilityLabel("Listening")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .onAppear {
            if let settings = allSettings.first, !settings.hasOnboarded {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                allSettings.first?.hasOnboarded = true
                try? modelContext.save()
                showOnboarding = false
            }
            .environment(music)
        }
    }
}
