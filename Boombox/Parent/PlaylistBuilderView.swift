import MusicKit
import SwiftData
import SwiftUI

/// Build a new Apple Music playlist: search the catalogue across songs,
/// albums, and artists, preview 30 seconds, add songs, then create the
/// playlist in the listener's real library and drop a tile on the wall.
struct PlaylistBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(MusicService.self) private var music
    @Query(sort: \Tile.sortIndex) private var tiles: [Tile]
    @Query private var allSettings: [AppSettings]

    private var allowExplicit: Bool {
        allSettings.first?.allowExplicit ?? true
    }

    @State private var name = ""
    @State private var searchTerm = ""
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var draft: [Song] = []
    @State private var isSearching = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var previewPlayer = PreviewPlayer()

    var body: some View {
        NavigationStack {
            List {
                Section("Playlist Name") {
                    TextField("Name", text: $name)
                }

                if !draft.isEmpty {
                    Section("Added (\(draft.count))") {
                        ForEach(draft, id: \.id) { song in
                            HStack {
                                Text(song.title).lineLimit(1)
                                Spacer()
                                Button {
                                    draft.removeAll { $0.id == song.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove \(song.title)")
                            }
                        }
                    }
                }

                if isSearching {
                    Section { ProgressView() }
                }

                if !songs.isEmpty {
                    Section("Songs") {
                        ForEach(songs, id: \.id) { song in
                            SongRow(
                                song: song,
                                isAdded: draft.contains { $0.id == song.id },
                                previewPlayer: previewPlayer
                            ) {
                                add(song)
                            }
                        }
                    }
                }

                if !albums.isEmpty {
                    Section("Albums") {
                        ForEach(albums, id: \.id) { album in
                            NavigationLink {
                                AlbumSongsView(
                                    album: album,
                                    draft: $draft,
                                    previewPlayer: previewPlayer,
                                    allowExplicit: allowExplicit)
                            } label: {
                                HStack(spacing: 12) {
                                    if let artwork = album.artwork {
                                        ArtworkImage(artwork, width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    VStack(alignment: .leading) {
                                        Text(album.title).lineLimit(1)
                                        Text(album.artistName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if !artists.isEmpty {
                    Section("Artists") {
                        ForEach(artists, id: \.id) { artist in
                            NavigationLink {
                                ArtistSongsView(
                                    artist: artist,
                                    draft: $draft,
                                    previewPlayer: previewPlayer,
                                    allowExplicit: allowExplicit)
                            } label: {
                                HStack(spacing: 12) {
                                    if let artwork = artist.artwork {
                                        ArtworkImage(artwork, width: 44, height: 44)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "music.mic")
                                            .frame(width: 44, height: 44)
                                    }
                                    Text(artist.name).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $searchTerm,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search Apple Music")
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        previewPlayer.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task { await createPlaylist() }
                        }
                        .disabled(
                            name.trimmingCharacters(in: .whitespaces).isEmpty
                                || draft.isEmpty)
                    }
                }
            }
            .alert(
                "Couldn't create the playlist",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onDisappear {
                previewPlayer.stop()
            }
        }
    }

    private func add(_ song: Song) {
        guard !draft.contains(where: { $0.id == song.id }) else { return }
        draft.append(song)
    }

    private func search() async {
        let term = searchTerm.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            var request = MusicCatalogSearchRequest(
                term: term, types: [Song.self, Album.self, Artist.self])
            request.limit = 15
            let response = try await request.response()
            if allowExplicit {
                songs = Array(response.songs)
                albums = Array(response.albums)
            } else {
                songs = response.songs.filter { $0.contentRating != .explicit }
                albums = response.albums.filter { $0.contentRating != .explicit }
            }
            artists = Array(response.artists)
        } catch {
            songs = []
            albums = []
            artists = []
        }
    }

    private func createPlaylist() async {
        previewPlayer.stop()
        isCreating = true
        defer { isCreating = false }
        do {
            let playlist = try await MusicLibrary.shared.createPlaylist(
                name: name.trimmingCharacters(in: .whitespaces), items: draft)
            let nextIndex = (tiles.map(\.sortIndex).max() ?? -1) + 1
            let tile = Tile(
                playlistID: playlist.id.rawValue,
                label: playlist.name,
                iconType: .artwork,
                colourID: tiles.count % TilePalette.swatches.count,
                sortIndex: nextIndex)
            modelContext.insert(tile)
            // Pull the new playlist into the cache so the fresh tile doesn't
            // read as orphaned until the next refresh.
            await music.refreshLibrary()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A catalogue song with a 30-second preview button and an Add button.
struct SongRow: View {
    let song: Song
    let isAdded: Bool
    let previewPlayer: PreviewPlayer
    let onAdd: () -> Void

    private var previewURL: URL? {
        song.previewAssets?.first?.url
    }

    var body: some View {
        HStack(spacing: 12) {
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(song.title).lineLimit(1)
                    if song.contentRating == .explicit {
                        Image(systemName: "e.square.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Explicit")
                    }
                }
                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let previewURL {
                Button {
                    previewPlayer.toggle(url: previewURL)
                } label: {
                    Image(
                        systemName: previewPlayer.playingURL == previewURL
                            ? "stop.circle.fill" : "play.circle")
                    .font(.system(size: 26))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(
                    previewPlayer.playingURL == previewURL
                        ? "Stop preview" : "Play preview")
            }
            Button(action: onAdd) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(isAdded ? Color.green : Color.accentColor)
            }
            .buttonStyle(.borderless)
            .disabled(isAdded)
            .accessibilityLabel(isAdded ? "Added" : "Add \(song.title)")
        }
    }
}

/// Album drill-down: lists the album's songs with preview and Add.
struct AlbumSongsView: View {
    let album: Album
    @Binding var draft: [Song]
    let previewPlayer: PreviewPlayer
    var allowExplicit: Bool = true

    @State private var albumSongs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        List {
            ForEach(albumSongs, id: \.id) { song in
                SongRow(
                    song: song,
                    isAdded: draft.contains { $0.id == song.id },
                    previewPlayer: previewPlayer
                ) {
                    if !draft.contains(where: { $0.id == song.id }) {
                        draft.append(song)
                    }
                }
            }
        }
        .overlay {
            if isLoading { ProgressView() }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            defer { isLoading = false }
            guard let detailed = try? await album.with([.tracks]) else { return }
            albumSongs = (detailed.tracks ?? []).compactMap { track in
                if case .song(let song) = track { return song }
                return nil
            }
            if !allowExplicit {
                albumSongs.removeAll { $0.contentRating == .explicit }
            }
        }
    }
}

/// Artist drill-down: lists the artist's top songs with preview and Add.
struct ArtistSongsView: View {
    let artist: Artist
    @Binding var draft: [Song]
    let previewPlayer: PreviewPlayer
    var allowExplicit: Bool = true

    @State private var topSongs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        List {
            ForEach(topSongs, id: \.id) { song in
                SongRow(
                    song: song,
                    isAdded: draft.contains { $0.id == song.id },
                    previewPlayer: previewPlayer
                ) {
                    if !draft.contains(where: { $0.id == song.id }) {
                        draft.append(song)
                    }
                }
            }
        }
        .overlay {
            if isLoading { ProgressView() }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            defer { isLoading = false }
            guard let detailed = try? await artist.with([.topSongs]) else { return }
            topSongs = Array(detailed.topSongs ?? [])
            if !allowExplicit {
                topSongs.removeAll { $0.contentRating == .explicit }
            }
        }
    }
}
