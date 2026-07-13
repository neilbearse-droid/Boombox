import MusicKit
import SwiftData
import SwiftUI

/// List of tiles with drag-to-reorder, hide/show, edit, and delete.
/// Deleting a tile never touches the underlying Apple Music playlist.
struct TileManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(MusicService.self) private var music
    @Query(sort: \Tile.sortIndex) private var tiles: [Tile]

    @State private var showPlaylistPicker = false
    @State private var showPlaylistBuilder = false
    @State private var tileToDelete: Tile?

    private var orphanCount: Int {
        tiles.filter { music.isOrphaned($0) }.count
    }

    var body: some View {
        List {
            if orphanCount > 0 {
                Section {
                    Label(
                        orphanCount == 1
                            ? "1 tile's playlist was deleted in Apple Music. It is hidden from the wall."
                            : "\(orphanCount) tiles' playlists were deleted in Apple Music. They are hidden from the wall.",
                        systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                }
            }

            Section {
                ForEach(tiles) { tile in
                    NavigationLink {
                        TileEditorView(tile: tile)
                    } label: {
                        TileManagerRow(
                            tile: tile,
                            isOrphaned: music.isOrphaned(tile),
                            artwork: music.playlist(withID: tile.playlistID)?.artwork)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            tileToDelete = tile
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            tile.isHidden.toggle()
                        } label: {
                            Label(
                                tile.isHidden ? "Show" : "Hide",
                                systemImage: tile.isHidden ? "eye" : "eye.slash")
                        }
                    }
                }
                .onMove(perform: move)
            } footer: {
                if tiles.isEmpty {
                    Text("Add a tile to put music on the wall.")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showPlaylistPicker = true
                    } label: {
                        Label("From a Playlist", systemImage: "music.note.list")
                    }
                    Button {
                        showPlaylistBuilder = true
                    } label: {
                        Label("Build a New Playlist", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Tile")
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showPlaylistPicker) {
            PlaylistPickerView()
                .environment(music)
        }
        .sheet(isPresented: $showPlaylistBuilder) {
            PlaylistBuilderView()
                .environment(music)
        }
        .confirmationDialog(
            "Delete this tile?",
            isPresented: Binding(
                get: { tileToDelete != nil },
                set: { if !$0 { tileToDelete = nil } }),
            presenting: tileToDelete
        ) { tile in
            Button("Delete Tile", role: .destructive) {
                delete(tile)
            }
        } message: { _ in
            Text("The playlist stays in Apple Music. Only the tile is removed.")
        }
        .task {
            await music.refreshLibrary()
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = tiles
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, tile) in reordered.enumerated() {
            tile.sortIndex = index
        }
    }

    private func delete(_ tile: Tile) {
        if tile.iconType == .photo || tile.iconType == .albumCover,
            let filename = tile.iconValue
        {
            PhotoStore.delete(filename)
        }
        modelContext.delete(tile)
        tileToDelete = nil
    }
}

private struct TileManagerRow: View {
    let tile: Tile
    let isOrphaned: Bool
    let artwork: Artwork?

    private var swatch: TileSwatch { TilePalette.swatch(tile.colourID) }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(tile.label)
                    .font(.headline)
                if isOrphaned {
                    Label("Playlist deleted", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if tile.isHidden {
                    Text("Hidden")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .opacity(tile.isHidden || isOrphaned ? 0.5 : 1)
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(swatch.background(calmMode: false))
                .frame(width: 44, height: 44)
            switch tile.iconType {
            case .emoji:
                if let emoji = tile.iconValue, emoji.count == 1 {
                    Text(emoji).font(.system(size: 24))
                }
            case .symbol:
                if let name = tile.iconValue, UIImage(systemName: name) != nil {
                    Image(systemName: name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(swatch.textColor(calmMode: false))
                }
            case .photo, .albumCover:
                if let filename = tile.iconValue, let image = PhotoStore.load(filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            case .artwork:
                if let artwork {
                    ArtworkImage(artwork, width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
