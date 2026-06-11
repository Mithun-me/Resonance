//
//  ContentView.swift
//  MithunMusicApp
//
//  Created by Mithun Samy on 11/06/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var player = player
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            Tab("Library", systemImage: "music.note.list", value: AppTab.library) {
                LibraryView()
            }
            Tab("Favorites", systemImage: "heart.fill", value: AppTab.favorites) {
                FavoritesView()
            }
            Tab("Playlists", systemImage: "music.note.square.stack", value: AppTab.playlists) {
                PlaylistsView()
            }
            Tab("Studio", systemImage: "waveform", value: AppTab.studio) {
                StudioView()
            }
        }
        .tabViewBottomAccessory {
            MiniPlayerBar()
        }
        .sheet(isPresented: $player.isPresentingFullPlayer) {
            PlayerView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Song.self, Playlist.self], inMemory: true)
        .environment(PlayerManager())
        .environment(AppState())
}
