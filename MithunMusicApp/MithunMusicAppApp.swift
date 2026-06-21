//
//  MithunMusicAppApp.swift
//  MithunMusicApp
//
//  Created by Mithun Samy on 11/06/26.
//

import SwiftData
import SwiftUI

@main
struct MithunMusicAppApp: App {
    @State private var playerManager = PlayerManager()
    @State private var appState = AppState()
    @State private var intelligence = IntelligenceService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Song.self,
            Playlist.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerManager)
                .environment(appState)
                .environment(intelligence)
                .task {
                    SampleLibrary.seedIfNeeded(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
