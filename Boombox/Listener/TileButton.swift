import MusicKit
import SwiftUI

/// One tile on the music wall. Minimum 160 pt tall at 2-up — far beyond the
/// 88 pt floor every listener-mode target must clear.
struct TileButton: View {
    let tile: Tile
    let columns: Int
    let showLabel: Bool
    let calmMode: Bool
    /// This tile's playlist owns the queue (badge shows).
    let isCurrent: Bool
    /// Music is audibly coming out right now (badge animates unless calm).
    let isAudiblyPlaying: Bool
    let isLoading: Bool
    let artwork: Artwork?
    var textScale: Double = 1.0
    var highContrast: Bool = false
    let action: () -> Void

    private var swatch: TileSwatch { TilePalette.swatch(tile.colourID) }
    private var iconSize: CGFloat { columns == 1 ? 108 : 84 }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    icon
                    if showLabel && !tile.label.isEmpty {
                        Text(tile.label)
                            .font(.system(
                                size: 22 * textScale, weight: .semibold, design: .rounded))
                            .foregroundStyle(swatch.textColor(calmMode: calmMode))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isCurrent {
                    EqualizerBadge(animated: isAudiblyPlaying && !calmMode)
                        .padding(10)
                }

                if isLoading {
                    ProgressView()
                        .tint(swatch.textColor(calmMode: calmMode))
                        .padding(14)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: columns == 1 ? 220 : 168)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(swatch.background(calmMode: calmMode)))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        swatch.textColor(calmMode: calmMode).opacity(0.9),
                        lineWidth: highContrast ? 4 : 0))
        }
        .buttonStyle(TilePressStyle(calmMode: calmMode))
        .accessibilityLabel(tile.label)
        .accessibilityHint(isCurrent ? "Now playing" : "Plays this music")
    }

    @ViewBuilder
    private var icon: some View {
        switch tile.iconType {
        case .emoji:
            if let emoji = tile.iconValue, emoji.count == 1 {
                Text(emoji)
                    .font(.system(size: iconSize))
            } else {
                placeholderIcon
            }
        case .symbol:
            if let name = tile.iconValue, UIImage(systemName: name) != nil {
                Image(systemName: name)
                    .font(.system(size: iconSize * 0.7, weight: .semibold))
                    .foregroundStyle(swatch.textColor(calmMode: calmMode))
                    .frame(width: iconSize, height: iconSize)
            } else {
                placeholderIcon
            }
        case .photo, .albumCover:
            if let filename = tile.iconValue, let image = PhotoStore.load(filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                placeholderIcon
            }
        case .artwork:
            if let artwork {
                ArtworkImage(artwork, width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                placeholderIcon
            }
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "music.note")
            .font(.system(size: iconSize * 0.6))
            .foregroundStyle(swatch.textColor(calmMode: calmMode))
            .frame(width: iconSize, height: iconSize)
    }
}

/// Immediate press state. Calm Mode and Reduce Motion drop the scale change
/// and animation, leaving only a plain opacity dip.
struct TilePressStyle: ButtonStyle {
    let calmMode: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let still = calmMode || reduceMotion
        return configuration.label
            .scaleEffect(configuration.isPressed && !still ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(
                still ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed)
    }
}
