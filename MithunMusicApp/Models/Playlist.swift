//
//  Playlist.swift
//  MithunMusicApp
//

import Foundation
import SwiftData

@Model
final class Playlist {
    var name: String
    var dateCreated: Date
    @Relationship(inverse: \Song.playlists) var songs: [Song] = []

    init(name: String, dateCreated: Date = .now) {
        self.name = name
        self.dateCreated = dateCreated
    }

    var sortedSongs: [Song] {
        songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var formattedTotalDuration: String {
        let total = Int(songs.reduce(0) { $0 + $1.duration }.rounded())
        let minutes = total / 60
        return minutes > 0 ? "\(minutes) min" : "\(total) sec"
    }
}
