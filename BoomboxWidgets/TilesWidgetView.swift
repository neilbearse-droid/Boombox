import SwiftUI
import WidgetKit

/// Timery-style grid: small = 1 tile, medium = 2, large = 2×2 or 2×3
/// depending on how many tiles the parent enabled for the widget.
/// Lock Screen families play the first widget tile.
struct TilesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TilesEntry

    var body: some View {
        if let snapshot = entry.snapshot, !snapshot.tiles.isEmpty {
            content(snapshot)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
            Text("Open Boombox to set up tiles.")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let calm = snapshot.calmMode
        let tiles = snapshot.tiles

        switch family {
        case .systemSmall:
            TileCell(tile: tiles[0], calm: calm, iconSize: 44, showLabel: true)
                .widgetURL(WidgetStore.playURL(for: tiles[0]))

        case .systemMedium:
            HStack(spacing: 8) {
                ForEach(tiles.prefix(2)) { tile in
                    Link(destination: WidgetStore.playURL(for: tile)) {
                        TileCell(tile: tile, calm: calm, iconSize: 36, showLabel: true)
                    }
                }
            }

        case .systemLarge:
            let shown = Array(tiles.prefix(6))
            let rows = stride(from: 0, to: shown.count, by: 2).map {
                Array(shown[$0..<min($0 + 2, shown.count)])
            }
            VStack(spacing: 8) {
                ForEach(0..<rows.count, id: \.self) { rowIndex in
                    HStack(spacing: 8) {
                        ForEach(rows[rowIndex]) { tile in
                            Link(destination: WidgetStore.playURL(for: tile)) {
                                TileCell(
                                    tile: tile, calm: calm,
                                    iconSize: rows.count > 2 ? 30 : 40,
                                    showLabel: true)
                            }
                        }
                        if rows[rowIndex].count == 1 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                accessoryIcon(tiles[0])
                    .font(.system(size: 22))
            }
            .widgetURL(WidgetStore.playURL(for: tiles[0]))

        case .accessoryRectangular:
            HStack(spacing: 8) {
                accessoryIcon(tiles[0])
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Play")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(tiles[0].label)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .widgetURL(WidgetStore.playURL(for: tiles[0]))

        default:
            TileCell(tile: tiles[0], calm: calm, iconSize: 40, showLabel: true)
                .widgetURL(WidgetStore.playURL(for: tiles[0]))
        }
    }

    /// Monochrome-friendly icon for Lock Screen families.
    @ViewBuilder
    private func accessoryIcon(_ tile: WidgetTile) -> some View {
        switch tile.kind {
        case "emoji":
            Text(tile.value ?? "🎵")
        case "symbol":
            Image(systemName: tile.value ?? "music.note")
                .widgetAccentable()
        default:
            Image(systemName: "music.note")
                .widgetAccentable()
        }
    }
}

/// One tile in a Home Screen widget: swatch background, icon, short label.
struct TileCell: View {
    let tile: WidgetTile
    let calm: Bool
    let iconSize: CGFloat
    let showLabel: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(WidgetPalette.background(tile.colourID, calmMode: calm))
            VStack(spacing: 4) {
                icon
                if showLabel && !tile.label.isEmpty {
                    Text(tile.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            WidgetPalette.textColor(tile.colourID, calmMode: calm))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(tile.label)
    }

    @ViewBuilder
    private var icon: some View {
        switch tile.kind {
        case "emoji":
            Text(tile.value ?? "🎵")
                .font(.system(size: iconSize))
        case "symbol":
            Image(systemName: tile.value ?? "music.note")
                .font(.system(size: iconSize * 0.8, weight: .semibold))
                .foregroundStyle(
                    WidgetPalette.textColor(tile.colourID, calmMode: calm))
        case "image":
            if let filename = tile.value,
                let image = WidgetStore.iconImage(filename)
            {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSize + 12, height: iconSize + 12)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                fallbackIcon
            }
        default:
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "music.note")
            .font(.system(size: iconSize * 0.7))
            .foregroundStyle(WidgetPalette.textColor(tile.colourID, calmMode: calm))
    }
}
