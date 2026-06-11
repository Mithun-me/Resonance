//
//  SongImporter.swift
//  MithunMusicApp
//

import AVFoundation
import Foundation
import SwiftData

/// Copies audio files picked from the Files app into the library and reads their metadata.
enum SongImporter {
    @MainActor
    static func importSongs(from urls: [URL], into context: ModelContext) async -> Int {
        var imported = 0
        for url in urls {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let song = try await importSong(at: url)
                context.insert(song)
                imported += 1
            } catch {
                continue
            }
        }
        return imported
    }

    private static func importSong(at sourceURL: URL) async throws -> Song {
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let fileName = UUID().uuidString + "." + ext
        let destination = Song.musicDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let asset = AVURLAsset(url: destination)
        let duration = try await asset.load(.duration).seconds
        let metadata = (try? await asset.load(.commonMetadata)) ?? []

        async let title = stringValue(for: .commonKeyTitle, in: metadata)
        async let artist = stringValue(for: .commonKeyArtist, in: metadata)
        async let album = stringValue(for: .commonKeyAlbumName, in: metadata)
        async let artwork = dataValue(for: .commonKeyArtwork, in: metadata)

        let fallbackTitle = sourceURL.deletingPathExtension().lastPathComponent
        return Song(
            title: await title ?? fallbackTitle,
            artist: await artist ?? "Unknown Artist",
            album: await album ?? "Unknown Album",
            duration: duration,
            fileName: fileName,
            artworkData: await artwork
        )
    }

    private static func stringValue(for key: AVMetadataKey, in metadata: [AVMetadataItem]) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: metadata, withKey: key, keySpace: .common).first else {
            return nil
        }
        return try? await item.load(.stringValue)
    }

    private static func dataValue(for key: AVMetadataKey, in metadata: [AVMetadataItem]) async -> Data? {
        guard let item = AVMetadataItem.metadataItems(from: metadata, withKey: key, keySpace: .common).first else {
            return nil
        }
        return try? await item.load(.dataValue)
    }
}
