import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query private var allSettings: [AppSettings]

    var body: some View {
        if let settings = allSettings.first {
            SettingsForm(settings: settings)
        } else {
            // AppSettings is created at launch; this should never appear.
            ProgressView()
        }
    }
}

private struct SettingsForm: View {
    @Bindable var settings: AppSettings
    @State private var showChangePIN = false

    var body: some View {
        Form {
            Section("Music Wall") {
                Picker("Columns", selection: $settings.columns) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                }
                .pickerStyle(.segmented)
                Toggle("Show labels", isOn: $settings.showLabels)
            }

            Section {
                Toggle("Spoken confirmations", isOn: $settings.speakOnPlay)
                Toggle("Calm Mode", isOn: $settings.calmMode)
            } footer: {
                Text("Calm Mode removes all animation and mutes the tile colours.")
            }

            Section("Now Playing") {
                Toggle("Next Song button", isOn: $settings.showNextButton)
            }

            Section {
                Toggle("Allow explicit songs", isOn: $settings.allowExplicit)
            } header: {
                Text("Content")
            } footer: {
                Text("When off, songs marked explicit are skipped during playback and hidden in the playlist builder. Starting a tile takes slightly longer while filtering. iOS Screen Time can also block explicit music device-wide.")
            }

            Section {
                Toggle("Reduce repeat taps", isOn: $settings.reduceRepeatTaps)
            } header: {
                Text("Touch")
            } footer: {
                Text("Ignores extra touches for a moment after each tap. Turn on if taps often register more than once.")
            }

            Section("Parent PIN") {
                Button("Change PIN") {
                    showChangePIN = true
                }
            }

            Section("Setup") {
                NavigationLink("Setup Checklist") {
                    SetupChecklistView()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showChangePIN) {
            PINGateView(
                mode: .change,
                onSuccess: { showChangePIN = false },
                onCancel: { showChangePIN = false })
        }
    }
}
