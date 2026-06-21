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
    @State private var showSplash = true

    var body: some View {
        @Bindable var player = player
        @Bindable var appState = appState
        ZStack {
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

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeInOut(duration: 0.45)) { showSplash = false }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Song.self, Playlist.self], inMemory: true)
        .environment(PlayerManager())
        .environment(AppState())
        .environment(IntelligenceService())
}
