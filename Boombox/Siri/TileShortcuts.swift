import AppIntents
import SwiftData

/// A configured tile, exposed to Siri and Shortcuts. The query only ever
/// returns tiles the caregiver has set up (and not hidden), so voice can
/// never reach arbitrary catalogue music — the whole point of Boombox's
/// curation survives the voice layer.
struct TileEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Music Tile"
    static var defaultQuery = TileQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TileQuery: EntityStringQuery {
    /// Fresh SwiftData context per query — App Intents can run outside the
    /// app's normal lifecycle. Schema matches the app's so the same store
    /// opens cleanly.
    @MainActor
    private func loadTiles(
        matching predicate: @escaping (Tile) -> Bool
    ) -> [TileEntity] {
        guard let container = try? ModelContainer(
            for: Tile.self, AppSettings.self, PlayEvent.self)
        else { return [] }
        let context = ModelContext(container)
        // Respect the caregiver's global Siri switch.
        let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first
        guard settings?.allowSiri ?? true else { return [] }
        let tiles = (try? context.fetch(FetchDescriptor<Tile>())) ?? []
        return tiles
            .filter { !$0.isHidden && predicate($0) }
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { TileEntity(id: $0.id, name: $0.effectiveSpokenName) }
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [TileEntity] {
        let wanted = Set(identifiers)
        return loadTiles { wanted.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [TileEntity] {
        loadTiles { _ in true }
    }

    /// Matches the spoken phrase against tile names so Siri resolves
    /// "the dragon music" to the right configured tile.
    @MainActor
    func entities(matching string: String) async throws -> [TileEntity] {
        let needle = string.lowercased()
        return loadTiles { tile in
            let name = tile.effectiveSpokenName.lowercased()
            return name == needle || name.contains(needle) || needle.contains(name)
        }
    }
}

/// "Play the dragon music." Plays only the named, configured tile.
struct PlayTileIntent: AppIntent {
    static var title: LocalizedStringResource = "Play a Music Tile"
    static var description = IntentDescription(
        "Plays one of the music tiles set up in Boombox.")
    /// Opens the app so playback runs through the normal path (schedules,
    /// limits, and the explicit filter all still apply).
    static var openAppWhenRun = true

    @Parameter(title: "Tile")
    var tile: TileEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        PlaybackIntentBridge.requestPlay(tileID: tile.id)
        return .result()
    }
}

struct BoomboxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayTileIntent(),
            phrases: [
                "Play \(\.$tile) on \(.applicationName)",
                "Play \(\.$tile) in \(.applicationName)",
                "\(.applicationName) play \(\.$tile)",
            ],
            shortTitle: "Play a Tile",
            systemImageName: "play.circle.fill")
    }
}
