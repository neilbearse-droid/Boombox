import MusicKit
import SwiftData
import SwiftUI

/// Lets the parent pick one recognizable album cover from the tile's
/// playlist. The chosen artwork is downloaded once and cached locally, so
/// the tile renders instantly and keeps working offline.
struct AlbumCoverPickerView: View {
    @Bindable var tile: Tile
    @Environment(\.dismiss) private var dismiss

    private struct AlbumChoice: Identifiable {
        let id: String
        let title: String
        let artwork: Artwork
    }

    @State private var choices: [AlbumChoice] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
                    spacing: 16
                ) {
                    ForEach(choices) { choice in
                        Button {
                            Task { await select(choice) }
                        } label: {
                            VStack(spacing: 6) {
                                ArtworkImage(choice.artwork, width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(choice.title)
                                    .font(.caption)
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .disabled(isSaving)
                        .accessibilityLabel(choice.title)
                    }
                }
                .padding()
            }
            .overlay {
                if isLoading || isSaving {
                    ProgressView()
                } else if choices.isEmpty {
                    ContentUnavailableView(
                        "No covers found",
                        systemImage: "square.stack",
                        description: Text("This playlist's songs have no artwork yet."))
                }
            }
            .navigationTitle("Choose Album Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                "Couldn't use that cover",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                await load()
            }
        }
    }

    /// One entry per album in the playlist, in track order.
    private func load() async {
        defer { isLoading = false }
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(tile.playlistID))
        guard let playlist = try? await request.response().items.first,
            let detailed = try? await playlist.with([.tracks])
        else { return }

        var seen = Set<String>()
        var result: [AlbumChoice] = []
        for track in detailed.tracks ?? [] {
            guard let artwork = track.artwork else { continue }
            let key = track.albumTitle ?? track.title
            if seen.insert(key).inserted {
                result.append(AlbumChoice(id: key, title: key, artwork: artwork))
            }
        }
        choices = result
    }

    private func select(_ choice: AlbumChoice) async {
        guard let url = choice.artwork.url(width: 600, height: 600) else {
            errorMessage = "This cover has no image to download."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let filename = PhotoStore.save(data) else {
                errorMessage = "The image couldn't be saved."
                return
            }
            // Replace any previously stored image file for this tile.
            if tile.iconType == .photo || tile.iconType == .albumCover,
                let old = tile.iconValue
            {
                PhotoStore.delete(old)
            }
            tile.iconValue = filename
            tile.iconType = .albumCover
            dismiss()
        } catch {
            errorMessage = "The cover couldn't be downloaded. Check the connection."
        }
    }
}
