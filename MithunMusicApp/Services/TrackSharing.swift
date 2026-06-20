//
//  TrackSharing.swift
//  MithunMusicApp
//

import Foundation

/// Prepares a temporary, nicely-named copy of a track's audio file for sharing,
/// so the system share sheet shows e.g. "My Song.m4a" instead of a UUID filename.
enum TrackSharing {
    static func shareURL(for song: Song) -> URL? {
        let sourceURL = song.fileURL
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return nil }

        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines)
        let cleaned = song.title
            .components(separatedBy: illegal)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = cleaned.isEmpty ? "track" : cleaned

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(base)
            .appendingPathExtension(ext)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
