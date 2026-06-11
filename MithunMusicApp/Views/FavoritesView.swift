//
//  FavoritesView.swift
//  MithunMusicApp
//

import SwiftData
import SwiftUI

struct FavoritesView: View {
    @Environment(PlayerManager.self) private var player
    @Query(filter: #Predicate<Song> { $0.isFavorite }, sort: \Song.title)
    private var favorites: [Song]

    var body: some View {
        NavigationStack {
            List {
                ForEach(favorites) { song in
                    Button {
                        player.play(song, in: favorites)
                    } label: {
                        SongRow(song: song, isCurrent: player.currentSong === song)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button {
                            song.isFavorite = false
                        } label: {
                            Label("Remove", systemImage: "heart.slash")
                        }
                        .tint(.pink)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Favorites")
            .overlay {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "No Favorites",
                        systemImage: "heart",
                        description: Text("Swipe right on a song in your library to favorite it.")
                    )
                }
            }
        }
    }
}
