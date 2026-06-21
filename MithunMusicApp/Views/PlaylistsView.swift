//
//  PlaylistsView.swift
//  MithunMusicApp
//

import SwiftData
import SwiftUI

struct PlaylistsView: View {
    @Environment(\.modelContext) private var context
    @Environment(IntelligenceService.self) private var intelligence
    @Query(sort: \Playlist.dateCreated, order: .reverse) private var playlists: [Playlist]

    @State private var isCreatingPlaylist = false
    @State private var isSmartPlaylist = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(playlists) { playlist in
                    NavigationLink {
                        PlaylistDetailView(playlist: playlist)
                    } label: {
                        PlaylistRow(playlist: playlist)
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
                if intelligence.isAvailable {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isSmartPlaylist = true
                        } label: {
                            Label("Smart Playlist", systemImage: "sparkles")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingPlaylist = true
                    } label: {
                        Label("New Playlist", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isCreatingPlaylist) {
                CreatePlaylistSheet()
            }
            .sheet(isPresented: $isSmartPlaylist) {
                SmartPlaylistSheet()
            }
            .overlay {
                if playlists.isEmpty {
                    ContentUnavailableView {
                        Label("No Playlists", systemImage: "music.note.list")
                    } description: {
                        Text("Group your favorite tracks into a playlist.")
                    } actions: {
                        Button {
                            isCreatingPlaylist = true
                        } label: {
                            Label("New Playlist", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                }
            }
        }
    }
}

/// A single row in the playlists list: mosaic cover, name, and a track summary.
private struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            PlaylistArtwork(songs: playlist.sortedSongs, cornerRadius: 8)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(1)
                Text(playlist.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerManager.self) private var player
    @Environment(IntelligenceService.self) private var intelligence
    @Bindable var playlist: Playlist

    @State private var isAddingSongs = false
    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var isConfirmingDelete = false
    @State private var isSuggestingMeta = false
    @State private var aiError: String?

    private var songs: [Song] { playlist.sortedSongs }

    var body: some View {
        List {
            Section {
                header
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
            }

            if songs.isEmpty {
                Section {
                    emptyState
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(songs) { song in
                        Button {
                            player.play(song, in: songs)
                        } label: {
                            SongRow(song: song, isCurrent: player.currentSong === song)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                remove(song)
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isAddingSongs = true
                    } label: {
                        Label("Add Songs", systemImage: "plus")
                    }
                    Button {
                        draftName = playlist.name
                        isRenaming = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    if intelligence.isAvailable && !songs.isEmpty {
                        Button {
                            Task { await suggestMeta() }
                        } label: {
                            Label("Suggest Name & Blurb", systemImage: "sparkles")
                        }
                        .disabled(isSuggestingMeta)
                    }
                    Divider()
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isAddingSongs) {
            AddSongsSheet(playlist: playlist)
        }
        .alert("Rename Playlist", isPresented: $isRenaming) {
            TextField("Name", text: $draftName)
            Button("Save") {
                let trimmed = draftName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { playlist.name = trimmed }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \"\(playlist.name)\"?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Playlist", role: .destructive) {
                context.delete(playlist)
                dismiss()
            }
        } message: {
            Text("This removes the playlist. Your songs stay in the Library.")
        }
        .alert(
            "Couldn’t Generate",
            isPresented: Binding(get: { aiError != nil }, set: { if !$0 { aiError = nil } })
        ) {
            Button("OK") {}
        } message: {
            Text(aiError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            PlaylistArtwork(songs: songs, cornerRadius: 16)
                .frame(maxWidth: 220)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)

            VStack(spacing: 4) {
                Text(playlist.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text(playlist.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !playlist.note.isEmpty {
                    Text(playlist.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }

            HStack(spacing: 12) {
                Button {
                    player.play(songs, shuffled: false)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color(.white))
                }
                .buttonStyle(.borderedProminent)

                Button {
                    player.play(songs, shuffled: true)
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .fontWeight(.semibold)
            .disabled(songs.isEmpty)
            .padding(.top, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No songs yet")
                .font(.headline)
            Text("Add songs from your Library to start building this playlist.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                isAddingSongs = true
            } label: {
                Label("Add Songs", systemImage: "plus")
                    .foregroundStyle(Color(.label))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func remove(_ song: Song) {
        playlist.songs.removeAll { $0 === song }
    }

    private func suggestMeta() async {
        guard !songs.isEmpty else { return }
        isSuggestingMeta = true
        defer { isSuggestingMeta = false }
        do {
            let titles = songs.map { "\($0.title) — \($0.artist)" }
            let meta = try await intelligence.playlistMeta(forTrackTitles: titles)
            let name = meta.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { playlist.name = name }
            playlist.note = meta.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            aiError = error.localizedDescription
        }
    }
}

// MARK: - Create

struct CreatePlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.title) private var allSongs: [Song]

    @State private var name = ""
    @State private var selected: [Song] = []
    @State private var searchText = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return allSongs }
        return allSongs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
                || $0.album.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        PlaylistArtwork(songs: selected, cornerRadius: 16)
                            .frame(width: 150, height: 150)
                            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                        TextField("Playlist Name", text: $name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
                }

                Section {
                    if allSongs.isEmpty {
                        Text("Import music in the Library first.")
                            .foregroundStyle(.secondary)
                    } else if filteredSongs.isEmpty {
                        Text("No songs match \"\(searchText)\".")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredSongs) { song in
                            SelectableSongRow(
                                song: song,
                                isSelected: selected.contains { $0 === song }
                            ) {
                                toggle(song)
                            }
                        }
                    }
                } header: {
                    Text(selected.isEmpty ? "Add Songs" : "\(Playlist.songCount(selected.count)) selected")
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Find songs")
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { create() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func toggle(_ song: Song) {
        if let index = selected.firstIndex(where: { $0 === song }) {
            selected.remove(at: index)
        } else {
            selected.append(song)
        }
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        let playlist = Playlist(name: trimmedName)
        playlist.songs = selected
        context.insert(playlist)
        dismiss()
    }
}

// MARK: - Add songs

struct AddSongsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var playlist: Playlist
    @Query(sort: \Song.title) private var allSongs: [Song]

    @State private var searchText = ""

    private var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return allSongs }
        return allSongs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
                || $0.album.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filteredSongs) { song in
                        SelectableSongRow(
                            song: song,
                            isSelected: playlist.songs.contains { $0 === song }
                        ) {
                            toggle(song)
                        }
                    }
                } header: {
                    Text("\(Playlist.songCount(playlist.songs.count)) in playlist")
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Find songs")
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .overlay {
                if allSongs.isEmpty {
                    ContentUnavailableView(
                        "No Music",
                        systemImage: "music.note",
                        description: Text("Import audio in the Library first.")
                    )
                } else if filteredSongs.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private func toggle(_ song: Song) {
        if let index = playlist.songs.firstIndex(where: { $0 === song }) {
            playlist.songs.remove(at: index)
        } else {
            playlist.songs.append(song)
        }
    }
}

/// A library row with a leading-to-trailing selection toggle, shared by the
/// create and add-songs flows.
struct SelectableSongRow: View {
    let song: Song
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                SongRow(song: song)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
