//
//  LibraryView.swift
//  MithunMusicApp
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    enum SortMode: String, CaseIterable, Identifiable {
        case recentlyAdded = "Recently Added"
        case title = "Title"
        case artist = "Artist"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(PlayerManager.self) private var player
    @Environment(AppState.self) private var appState
    @Query private var songs: [Song]
    @Query private var playlists: [Playlist]

    @State private var searchText = ""
    @State private var sortMode: SortMode = .recentlyAdded
    @State private var isImporting = false
    @State private var editingSong: Song?
    @State private var shareItem: ShareItem?

    private var visibleSongs: [Song] {
        var result = songs
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.artist.localizedCaseInsensitiveContains(searchText)
                    || $0.album.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch sortMode {
        case .recentlyAdded:
            return result.sorted { $0.dateAdded > $1.dateAdded }
        case .title:
            return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return result.sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleSongs) { song in
                    Button {
                        player.play(song, in: visibleSongs)
                    } label: {
                        SongRow(song: song, isCurrent: player.currentSong === song)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            song.isFavorite.toggle()
                        } label: {
                            Label("Favorite", systemImage: song.isFavorite ? "heart.slash" : "heart")
                        }
                        .tint(.pink)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(song)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            editingSong = song
                        } label: {
                            Label("Edit Info", systemImage: "pencil")
                        }
                        Button {
                            appState.studioSong = song
                            appState.selectedTab = .studio
                        } label: {
                            Label("Edit in Studio", systemImage: "waveform")
                        }
                        addToPlaylistMenu(for: song)
                        Divider()
                        Button {
                            if let url = TrackSharing.shareURL(for: song) {
                                shareItem = ShareItem(url: url)
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Songs, artists, albums")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sort By", selection: $sortMode) {
                            ForEach(SortMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Import", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                guard case .success(let urls) = result else { return }
                Task {
                    _ = await SongImporter.importSongs(from: urls, into: context)
                }
            }
            .sheet(item: $editingSong) { song in
                EditSongView(song: song)
            }
            .sheet(item: $shareItem) { item in
                ActivityView(activityItems: [item.url])
            }
            .overlay {
                if songs.isEmpty {
                    ContentUnavailableView(
                        "No Music Yet",
                        systemImage: "music.note.list",
                        description: Text("Tap + to import audio files from the Files app.")
                    )
                } else if visibleSongs.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            #if DEBUG
            // Dev shortcut: SIMCTL_CHILD_DEMO_STUDIO=1 opens the Studio editor on launch.
            .task {
                if ProcessInfo.processInfo.environment["DEMO_STUDIO"] == "1", let first = songs.first {
                    appState.studioSong = first
                    appState.selectedTab = .studio
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func addToPlaylistMenu(for song: Song) -> some View {
        if playlists.isEmpty {
            Button("No Playlists Yet") {}.disabled(true)
        } else {
            Menu("Add to Playlist") {
                ForEach(playlists) { playlist in
                    Button {
                        if !playlist.songs.contains(where: { $0 === song }) {
                            playlist.songs.append(song)
                        }
                    } label: {
                        Label(playlist.name, systemImage: "music.note.list")
                    }
                }
            }
        }
    }

    private func delete(_ song: Song) {
        player.handleDeletion(of: song)
        if appState.studioSong === song {
            appState.studioSong = nil
        }
        try? FileManager.default.removeItem(at: song.fileURL)
        context.delete(song)
    }
}
