import MusicKit
import SwiftData
import SwiftUI

/// Add a tile from any playlist already in the listener's Apple Music library.
struct PlaylistPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(MusicService.self) private var music
    @Query(sort: \Tile.sortIndex) private var tiles: [Tile]

    var body: some View {
        NavigationStack {
            List {
                ForEach(music.libraryPlaylists, id: \.id) { playlist in
                    Button {
                        addTile(for: playlist)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            if let artwork = playlist.artwork {
                                ArtworkImage(artwork, width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 44, height: 44)
                                    .overlay(Image(systemName: "music.note.list"))
                            }
                            Text(playlist.name)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if hasTile(for: playlist) {
                                Text("On wall")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if music.libraryPlaylists.isEmpty {
                    ContentUnavailableView(
                        "No playlists yet",
                        systemImage: "music.note.list",
                        description: Text("Build a new playlist, or add one in the Music app."))
                }
            }
            .navigationTitle("Choose a Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await music.refreshLibrary()
            }
        }
    }

    private func hasTile(for playlist: Playlist) -> Bool {
        tiles.contains { $0.playlistID == playlist.id.rawValue }
    }

    private func addTile(for playlist: Playlist) {
        let nextIndex = (tiles.map(\.sortIndex).max() ?? -1) + 1
        let tile = Tile(
            playlistID: playlist.id.rawValue,
            label: playlist.name,
            iconType: .artwork,
            colourID: tiles.count % TilePalette.swatches.count,
            sortIndex: nextIndex)
        modelContext.insert(tile)
    }
}
