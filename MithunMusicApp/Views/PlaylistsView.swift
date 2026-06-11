//
//  PlaylistsView.swift
//  MithunMusicApp
//

import SwiftData
import SwiftUI

struct PlaylistsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Playlist.dateCreated, order: .reverse) private var playlists: [Playlist]

    @State private var isNamingPlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "music.note.list")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 48, height: 48)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .font(.body)
                                Text("\(playlist.songs.count) songs · \(playlist.formattedTotalDuration)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(playlists[index])
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newPlaylistName = ""
                        isNamingPlaylist = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                }
            }
            .alert("New Playlist", isPresented: $isNamingPlaylist) {
                TextField("Name", text: $newPlaylistName)
                Button("Create") {
                    let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    context.insert(Playlist(name: name))
                }
                Button("Cancel", role: .cancel) {}
            }
            .overlay {
                if playlists.isEmpty {
                    ContentUnavailableView(
                        "No Playlists",
                        systemImage: "music.note.list",
                        description: Text("Tap + to create your first playlist.")
                    )
                }
            }
        }
    }
}

struct PlaylistDetailView: View {
    @Environment(PlayerManager.self) private var player
    @Bindable var playlist: Playlist

    @State private var isAddingSongs = false

    var body: some View {
        List {
            ForEach(playlist.sortedSongs) { song in
                Button {
                    player.play(song, in: playlist.sortedSongs)
                } label: {
                    SongRow(song: song, isCurrent: player.currentSong === song)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        playlist.songs.removeAll { $0 === song }
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(playlist.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingSongs = true
                } label: {
                    Label("Add Songs", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingSongs) {
            AddSongsSheet(playlist: playlist)
        }
        .overlay {
            if playlist.songs.isEmpty {
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "music.note",
                    description: Text("Tap + to add songs from your library.")
                )
            }
        }
    }
}

struct AddSongsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var playlist: Playlist
    @Query(sort: \Song.title) private var allSongs: [Song]

    var body: some View {
        NavigationStack {
            List(allSongs) { song in
                let isIncluded = playlist.songs.contains { $0 === song }
                Button {
                    if isIncluded {
                        playlist.songs.removeAll { $0 === song }
                    } else {
                        playlist.songs.append(song)
                    }
                } label: {
                    HStack {
                        SongRow(song: song)
                        Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isIncluded ? Color.accentColor : .secondary)
                            .font(.title3)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
