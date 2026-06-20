//
//  EditSongView.swift
//  MithunMusicApp
//

import PhotosUI
import SwiftUI
import UIKit

/// Edits a song's title, artist, album, and cover art. Independent artists use
/// this to label and brand tracks they've imported or recorded.
struct EditSongView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var song: Song

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var artworkData: Data?
    @State private var pickerItem: PhotosPickerItem?

    init(song: Song) {
        self.song = song
        _title = State(initialValue: song.title)
        _artist = State(initialValue: song.artist)
        _album = State(initialValue: song.album)
        _artworkData = State(initialValue: song.artworkData)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        artworkPreview
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label(artworkData == nil ? "Add Artwork" : "Change Artwork",
                                  systemImage: "photo")
                        }

                        if artworkData != nil {
                            Button(role: .destructive) {
                                artworkData = nil
                                pickerItem = nil
                            } label: {
                                Label("Remove Artwork", systemImage: "trash")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    LabeledContent("Title") {
                        TextField("Title", text: $title).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Artist") {
                        TextField("Artist", text: $artist).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Album") {
                        TextField("Album", text: $album).multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .onChange(of: pickerItem) { loadArtwork() }
        }
    }

    @ViewBuilder
    private var artworkPreview: some View {
        if let artworkData, let image = UIImage(data: artworkData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: song.artworkHue, saturation: 0.65, brightness: 0.9),
                        Color(hue: (song.artworkHue + 0.07).truncatingRemainder(dividingBy: 1),
                              saturation: 0.8, brightness: 0.4),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "music.note")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private func loadArtwork() {
        guard let pickerItem else { return }
        Task {
            if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                artworkData = Self.downscaled(data) ?? data
            }
        }
    }

    private func save() {
        let cleanedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        song.title = trimmedTitle
        song.artist = cleanedArtist.isEmpty ? "Unknown Artist" : cleanedArtist
        song.album = cleanedAlbum.isEmpty ? "Unknown Album" : cleanedAlbum
        song.artworkData = artworkData
        dismiss()
    }

    /// Downscales picked artwork to a reasonable size so it doesn't bloat storage.
    private static func downscaled(_ data: Data, maxDimension: CGFloat = 600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > maxDimension else {
            return image.jpegData(compressionQuality: 0.85)
        }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
