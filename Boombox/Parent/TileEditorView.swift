import PhotosUI
import SwiftData
import SwiftUI

/// Edit one tile: icon (playlist artwork, emoji, or photo), label, spoken
/// name, colour swatch, shuffle, repeat, and wall visibility.
struct TileEditorView: View {
    @Bindable var tile: Tile

    @State private var photoItem: PhotosPickerItem?
    @State private var emojiText: String = ""

    var body: some View {
        Form {
            Section("Label") {
                TextField("Label", text: $tile.label)
                TextField(
                    "Spoken name (optional)",
                    text: Binding(
                        get: { tile.spokenName ?? "" },
                        set: { tile.spokenName = $0.isEmpty ? nil : $0 }))
            }

            Section("Icon") {
                Picker("Icon type", selection: $tile.iconType) {
                    Text("Artwork").tag(TileIconType.artwork)
                    Text("Emoji").tag(TileIconType.emoji)
                    Text("Photo").tag(TileIconType.photo)
                }
                .pickerStyle(.segmented)

                switch tile.iconType {
                case .emoji:
                    HStack {
                        TextField("Tap to type an emoji", text: $emojiText)
                            .onChange(of: emojiText) { _, newValue in
                                guard let last = newValue.last else { return }
                                let single = String(last)
                                if emojiText != single { emojiText = single }
                                tile.iconValue = single
                            }
                        if let emoji = tile.iconValue, tile.iconType == .emoji {
                            Text(emoji).font(.system(size: 36))
                        }
                    }
                case .photo:
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose Photo", systemImage: "photo")
                    }
                    if let filename = tile.iconValue,
                        tile.iconType == .photo,
                        let image = PhotoStore.load(filename)
                    {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                case .artwork:
                    Text("Uses the playlist's own artwork.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Colour") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                    ForEach(TilePalette.swatches) { swatch in
                        Button {
                            tile.colourID = swatch.id
                        } label: {
                            Circle()
                                .fill(swatch.background(calmMode: false))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if tile.colourID == swatch.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(swatch.textColor(calmMode: false))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(swatch.name)
                        .accessibilityAddTraits(
                            tile.colourID == swatch.id ? .isSelected : [])
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Playback") {
                Toggle("Shuffle", isOn: $tile.shuffle)
                Toggle("Repeat all", isOn: $tile.repeatAll)
            }

            Section {
                Toggle(
                    "Show on wall",
                    isOn: Binding(
                        get: { !tile.isHidden },
                        set: { tile.isHidden = !$0 }))
            }
        }
        .navigationTitle("Edit Tile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if tile.iconType == .emoji {
                emojiText = tile.iconValue ?? ""
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                    let filename = PhotoStore.save(data)
                else { return }
                if tile.iconType == .photo, let old = tile.iconValue {
                    PhotoStore.delete(old)
                }
                tile.iconValue = filename
                tile.iconType = .photo
            }
        }
    }
}
