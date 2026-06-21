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
        case mostPlayed = "Most Played"
        case leastPlayed = "Least Played"

        var id: String { rawValue }

        /// Maps a generated sort key (see `LibrarySearchPlan`) onto a case.
        static func from(planKey: String) -> SortMode {
            switch planKey {
            case "title": .title
            case "artist": .artist
            case "mostPlayed": .mostPlayed
            case "leastPlayed": .leastPlayed
            default: .recentlyAdded
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(PlayerManager.self) private var player
    @Environment(AppState.self) private var appState
    @Environment(IntelligenceService.self) private var intelligence
    @Query private var songs: [Song]
    @Query private var playlists: [Playlist]

    @State private var searchText = ""
    @State private var sortMode: SortMode = .recentlyAdded
    @State private var favoritesOnly = false
    @State private var isImporting = false
    @State private var editingSong: Song?
    @State private var shareItem: ShareItem?
    @State private var captionSong: Song?
    @State private var isAISearch = false
    @State private var aiQuery = ""
    @State private var aiError: String?

    private var visibleSongs: [Song] {
        var result = songs
        if favoritesOnly {
            result = result.filter(\.isFavorite)
        }
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
        case .mostPlayed:
            return result.sorted { $0.playCount > $1.playCount }
        case .leastPlayed:
            return result.sorted { $0.playCount < $1.playCount }
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
                        if intelligence.isAvailable {
                            Button {
                                captionSong = song
                            } label: {
                                Label("Promo Caption", systemImage: "sparkles")
                            }
                        }
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
                        Toggle(isOn: $favoritesOnly) {
                            Label("Favorites Only", systemImage: "heart")
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
                if intelligence.isAvailable {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            aiQuery = ""
                            isAISearch = true
                        } label: {
                            Label("Search with AI", systemImage: "sparkles")
                        }
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
                    let imported = await SongImporter.importSongs(from: urls, into: context)
                    await autoFillMetadata(for: imported)
                }
            }
            .sheet(item: $editingSong) { song in
                EditSongView(song: song)
            }
            .sheet(item: $shareItem) { item in
                ActivityView(activityItems: [item.url])
            }
            .sheet(item: $captionSong) { song in
                CaptionSheet(song: song)
            }
            .alert("Search with AI", isPresented: $isAISearch) {
                TextField("e.g. “upbeat songs I rarely play”", text: $aiQuery)
                Button("Search") {
                    Task { await applySearchPlan() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Describe what you want and the on-device model will set the filters.")
            }
            .alert(
                "Couldn’t Search",
                isPresented: Binding(get: { aiError != nil }, set: { if !$0 { aiError = nil } })
            ) {
                Button("OK") {}
            } message: {
                Text(aiError ?? "")
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

    /// After import, use the on-device model to tidy songs that arrived with weak
    /// metadata (no artist tag — usually just a filename as the title). Runs in the
    /// background, is conservative, and the user can still edit anything afterward.
    private func autoFillMetadata(for songs: [Song]) async {
        guard intelligence.isAvailable else { return }
        for song in songs where song.artist == "Unknown Artist" {
            guard let cleaned = try? await intelligence.cleanedMetadata(fromRawTitle: song.title) else {
                continue
            }
            let title = cleaned.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { song.title = title }
            let artist = cleaned.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !artist.isEmpty { song.artist = artist }
        }
    }

    private func applySearchPlan() async {
        let query = aiQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        do {
            let plan = try await intelligence.searchPlan(for: query)
            searchText = plan.keywords.trimmingCharacters(in: .whitespacesAndNewlines)
            favoritesOnly = plan.favoritesOnly
            sortMode = SortMode.from(planKey: plan.sort)
        } catch {
            aiError = "Couldn’t interpret that search. Try again."
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
