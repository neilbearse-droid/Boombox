import SwiftUI

/// A thumbnail of the music wall: a 2×2 grid of the listener's first tiles
/// in their real colours with their real emoji/symbols. Used on the Now
/// Playing back button so "back" is a picture of the choose screen, not a
/// word. Purely decorative — the enclosing button carries the label.
struct MiniWallPreview: View {
    let tiles: [Tile]
    let calmMode: Bool

    private let cell: CGFloat = 24
    private let gap: CGFloat = 4

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<2, id: \.self) { col in
                        miniTile(at: row * 2 + col)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func miniTile(at index: Int) -> some View {
        if index < tiles.count {
            let tile = tiles[index]
            let swatch = TilePalette.swatch(tile.colourID)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(swatch.background(calmMode: calmMode))
                miniIcon(for: tile, textColor: swatch.textColor(calmMode: calmMode))
            }
            .frame(width: cell, height: cell)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.25))
                .frame(width: cell, height: cell)
        }
    }

    @ViewBuilder
    private func miniIcon(for tile: Tile, textColor: Color) -> some View {
        switch tile.iconType {
        case .emoji:
            if let emoji = tile.iconValue, emoji.count == 1 {
                Text(emoji).font(.system(size: 13))
            }
        case .symbol:
            if let name = tile.iconValue, UIImage(systemName: name) != nil {
                Image(systemName: name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(textColor)
            }
        default:
            // Artwork and photos are illegible at this size; the tile's
            // colour is the recognizable part.
            EmptyView()
        }
    }
}
