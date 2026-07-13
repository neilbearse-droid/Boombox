import SwiftUI
import SwiftData

@main
struct BoomboxApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Tile.self, AppSettings.self, PlayEvent.self])
    }
}
