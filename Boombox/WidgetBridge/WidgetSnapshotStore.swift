import Foundation
import MusicKit
import UIKit
import WidgetKit

/// Writes the widget's data into the App Group container: a JSON snapshot of
/// the widget-enabled tiles plus pre-rendered icon image files (photos and
/// album covers are copied; playlist artwork is downloaded once at 300px).
/// The widget extension only ever reads files — no MusicKit, no SwiftData.
/// Main-actor-bound because it reads MusicService's playlist cache; the
/// slow parts (download, file writes) suspend rather than block.
@MainActor
enum WidgetSnapshotStore {
    /// App-side status for the Setup Checklist: whether the app can reach
    /// the shared container and how many widget tiles it last wrote.
    static func diagnostic(tiles: [Tile]) -> (groupReachable: Bool, eligible: Int, wrote: Bool) {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedWidgetConstants.appGroupID)
        let eligible = tiles.filter { !$0.isHidden && $0.showInWidget }.count
        var wrote = false
        if let container {
            let url = container.appendingPathComponent(
                SharedWidgetConstants.snapshotFilename)
            wrote = FileManager.default.fileExists(atPath: url.path)
        }
        return (container != nil, eligible, wrote)
    }

    static func write(tiles: [Tile], calmMode: Bool, music: MusicService) async {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedWidgetConstants.appGroupID)
        else {
            // App Group not provisioned yet; the widget shows its setup hint.
            return
        }
        let iconsDir = container.appendingPathComponent(
            SharedWidgetConstants.iconsDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: iconsDir, withIntermediateDirectories: true)

        let selected = tiles
            .filter { !$0.isHidden && $0.showInWidget }
            .sorted { $0.sortIndex < $1.sortIndex }
            .prefix(6)

        var infos: [WidgetTile] = []
        var referencedFiles = Set<String>()
        for tile in selected {
            let info = await makeInfo(for: tile, iconsDir: iconsDir, music: music)
            if info.kind == "image", let file = info.value {
                referencedFiles.insert(file)
            }
            infos.append(info)
        }

        // Drop icon files no longer referenced by any widget tile.
        if let files = try? FileManager.default.contentsOfDirectory(atPath: iconsDir.path) {
            for file in files where !referencedFiles.contains(file) {
                try? FileManager.default.removeItem(
                    at: iconsDir.appendingPathComponent(file))
            }
        }

        let snapshot = WidgetSnapshot(calmMode: calmMode, tiles: infos)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(
                to: container.appendingPathComponent(SharedWidgetConstants.snapshotFilename),
                options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func makeInfo(
        for tile: Tile, iconsDir: URL, music: MusicService
    ) async -> WidgetTile {
        func info(kind: String, value: String?) -> WidgetTile {
            WidgetTile(
                id: tile.id, label: tile.label, colourID: tile.colourID,
                kind: kind, value: value)
        }

        switch tile.iconType {
        case .emoji:
            if let value = tile.iconValue, value.count == 1 {
                return info(kind: "emoji", value: value)
            }
        case .symbol:
            if let value = tile.iconValue, UIImage(systemName: value) != nil {
                return info(kind: "symbol", value: value)
            }
        case .photo, .albumCover:
            if let filename = tile.iconValue {
                let source = PhotoStore.directory.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: source.path) {
                    let destName = tile.id.uuidString + ".img"
                    let dest = iconsDir.appendingPathComponent(destName)
                    try? FileManager.default.removeItem(at: dest)
                    if (try? FileManager.default.copyItem(at: source, to: dest)) != nil {
                        return info(kind: "image", value: destName)
                    }
                }
            }
        case .artwork:
            if let artwork = music.playlist(withID: tile.playlistID)?.artwork,
                let url = artwork.url(width: 300, height: 300),
                let (data, _) = try? await URLSession.shared.data(from: url)
            {
                let destName = tile.id.uuidString + ".img"
                let dest = iconsDir.appendingPathComponent(destName)
                if (try? data.write(to: dest, options: .atomic)) != nil {
                    return info(kind: "image", value: destName)
                }
            }
        }
        return info(kind: "plain", value: nil)
    }
}
