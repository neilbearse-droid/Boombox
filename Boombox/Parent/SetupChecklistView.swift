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
                let status = WidgetSnapshotStore.diagnostic(tiles: tiles)
                HStack {
                    statusIcon(status.groupReachable)
                    Text("App Group")
                    Spacer()
                    Text(status.groupReachable ? "Connected" : "Not set up")
                        .foregroundStyle(status.groupReachable ? Color.secondary : Color.orange)
                }
                HStack {
                    statusIcon(status.wrote)
                    Text("Widget data sent")
                    Spacer()
                    Text("\(status.eligible) tiles")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Widgets")
            } footer: {
                Text(SharedWidgetConstants.appGroupID)
            }

            Section {
                Link(destination: guidedAccessURL) {
                    Label("How to set up Guided Access", systemImage: "lock.iphone")
                }
            } header: {
                Text("Lockdown")
            } footer: {
                Text("Guided Access keeps the phone in this app and turns Siri off while locked. Triple-click the side button to start and stop it. Boombox's own Siri commands only ever play tiles you set up — but Siri can otherwise play any music by voice, and Guided Access is what stops that.")
            }

            Section {
                Label("Reduce Loud Sounds", systemImage: "ear")
            } header: {
                Text("Hearing")
            } footer: {
                Text("The app cannot cap volume itself. Turn on Settings > Sounds & Haptics > Headphone Safety > Reduce Loud Sounds.")
            }

            Section {
                Label("Touch Accommodations", systemImage: "hand.point.up.left")
            } header: {
                Text("Touch")
            } footer: {
                Text("If taps still land more than once with Reduce Repeat Taps on, try Settings > Accessibility > Touch > Touch Accommodations. Hold Duration requires a brief press before a touch counts, and Ignore Repeat treats repeated touches as one — enforced system-wide.")
            }

            Section {
                Label("Music Haptics", systemImage: "hand.tap")
            } header: {
                Text("Feeling the Music")
            } footer: {
                Text("For a listener who is deaf or hard of hearing, turn on Settings > Accessibility > Music Haptics. The iPhone then taps out the rhythm of the music through its Taptic Engine while Boombox plays. It works automatically with the Apple Music that Boombox uses.")
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
