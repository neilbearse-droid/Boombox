import MusicKit
import SwiftData
import SwiftUI
import UIKit

/// Everything the parent needs to get the phone ready, in one place.
struct SetupChecklistView: View {
    @Environment(MusicService.self) private var music
    @Query private var tiles: [Tile]

    private let guidedAccessURL = URL(
        string: "https://support.apple.com/en-us/HT202612")!

    var body: some View {
        List {
            Section("Apple Music") {
                HStack {
                    statusIcon(music.authStatus == .authorized)
                    Text("Music permission")
                    Spacer()
                    switch music.authStatus {
                    case .authorized:
                        Text("Allowed").foregroundStyle(.secondary)
                    case .notDetermined:
                        Button("Allow") {
                            Task { await music.requestAuthorization() }
                        }
                    default:
                        Link(
                            "Open Settings",
                            destination: URL(string: UIApplication.openSettingsURLString)!)
                    }
                }

                HStack {
                    statusIcon(music.subscription?.canPlayCatalogContent == true)
                    Text("Apple Music subscription")
                    Spacer()
                    if music.subscription == nil {
                        Text("Checking…").foregroundStyle(.secondary)
                    } else if music.subscription?.canPlayCatalogContent == true {
                        Text("Active").foregroundStyle(.secondary)
                    } else {
                        Text("Not active").foregroundStyle(.orange)
                    }
                }
            }

            Section("Music Wall") {
                HStack {
                    statusIcon(!tiles.isEmpty)
                    Text(tiles.isEmpty ? "No tiles yet" : "\(tiles.count) tiles configured")
                }
            }

            Section {
                Link(destination: guidedAccessURL) {
                    Label("How to set up Guided Access", systemImage: "lock.iphone")
                }
            } header: {
                Text("Lockdown")
            } footer: {
                Text("Guided Access keeps the phone in this app. Triple-click the side button to start and stop it.")
            }

            Section {
                Label("Reduce Loud Sounds", systemImage: "ear")
            } header: {
                Text("Hearing")
            } footer: {
                Text("The app cannot cap volume itself. Turn on Settings > Sounds & Haptics > Headphone Safety > Reduce Loud Sounds.")
            }
        }
        .navigationTitle("Setup Checklist")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusIcon(_ done: Bool) -> some View {
        Image(systemName: done ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(done ? Color.green : Color.secondary)
    }
}
