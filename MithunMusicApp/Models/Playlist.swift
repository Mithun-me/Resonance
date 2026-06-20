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

    /// "12 songs · 41 min", or "No songs" / "1 song" for the small cases.
    var summary: String {
        guard !songs.isEmpty else { return "No songs" }
        return "\(Self.songCount(songs.count)) · \(formattedTotalDuration)"
    }

    /// Pluralizes a count of songs, e.g. "1 song" / "7 songs".
    static func songCount(_ count: Int) -> String {
        "\(count) song\(count == 1 ? "" : "s")"
    }
}
