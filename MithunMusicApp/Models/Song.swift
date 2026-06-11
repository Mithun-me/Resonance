//
//  Song.swift
//  MithunMusicApp
//

import Foundation
import SwiftData

@Model
final class Song {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var fileName: String
    var dateAdded: Date
    var isFavorite: Bool
    var playCount: Int
    var artworkHue: Double
    @Attribute(.externalStorage) var artworkData: Data?
    var playlists: [Playlist]? = []

    init(
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        duration: TimeInterval = 0,
        fileName: String,
        dateAdded: Date = .now,
        isFavorite: Bool = false,
        playCount: Int = 0,
        artworkHue: Double = .random(in: 0...1),
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.fileName = fileName
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.artworkHue = artworkHue
        self.artworkData = artworkData
    }

    static var musicDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    var fileURL: URL {
        Self.musicDirectory.appendingPathComponent(fileName)
    }

    var formattedDuration: String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
