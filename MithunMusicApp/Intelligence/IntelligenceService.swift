//
//  IntelligenceService.swift
//  MithunMusicApp
//

import FoundationModels
import Observation

// MARK: - Generated content types

/// Effect settings produced from a natural-language description of a sound.
@Generable(description: "Concrete audio effect settings for a music track")
struct EffectRecipe {
    @Guide(description: "Output gain as a percent where 100 means unchanged; 0 to 200")
    var gainPercent: Int
    @Guide(description: "Low shelf EQ gain in dB, from -12 to 12")
    var eqLowDB: Int
    @Guide(description: "Mid EQ gain in dB, from -12 to 12")
    var eqMidDB: Int
    @Guide(description: "High shelf EQ gain in dB, from -12 to 12")
    var eqHighDB: Int
    @Guide(description: "Reverb space", .anyOf(["smallRoom", "mediumRoom", "largeHall", "cathedral", "plate"]))
    var reverbPreset: String
    @Guide(description: "Reverb amount as a percent, 0 to 100")
    var reverbMix: Int
    @Guide(description: "Echo/delay amount as a percent, 0 to 100")
    var delayMix: Int
    @Guide(description: "Distortion amount as a percent, 0 to 100; use sparingly")
    var distortionMix: Int
    @Guide(description: "Pitch shift in semitones, from -12 to 12")
    var pitchSemitones: Int
    @Guide(description: "Playback speed multiplier from 0.5 to 2.0 where 1.0 is normal")
    var speed: Double
}

extension EffectRecipe {
    /// Maps the generated values onto an existing `EditSettings`, keeping its trim
    /// and clamping every value into its valid range (the model is only a suggester).
    func applied(to base: EditSettings) -> EditSettings {
        func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
            min(max(value, low), high)
        }
        var settings = base
        settings.gain = clamp(Double(gainPercent) / 100, 0, 2)
        settings.eqLow = clamp(Double(eqLowDB), -12, 12)
        settings.eqMid = clamp(Double(eqMidDB), -12, 12)
        settings.eqHigh = clamp(Double(eqHighDB), -12, 12)
        settings.reverbPreset = ReverbPreset(rawValue: reverbPreset) ?? .mediumRoom
        settings.reverbMix = clamp(Double(reverbMix), 0, 100)
        settings.delayMix = clamp(Double(delayMix), 0, 100)
        settings.distortionMix = clamp(Double(distortionMix), 0, 100)
        settings.pitchSemitones = clamp(Double(pitchSemitones), -12, 12)
        settings.rate = clamp(speed, 0.5, 2)
        return settings
    }
}

/// A generated playlist: a name plus the chosen tracks, referenced by their
/// 1-based number in the candidate list (safer than titles, which can drift).
@Generable(description: "A curated playlist selection")
struct PlaylistPlan {
    @Guide(description: "Short, evocative playlist name of at most four words")
    var name: String
    @Guide(description: "Track numbers to include, taken from the provided list, in play order")
    var trackNumbers: [Int]
}

/// A suggested name and blurb for an existing set of tracks.
@Generable(description: "Suggested playlist name and description")
struct PlaylistMeta {
    @Guide(description: "Short, catchy name of at most four words")
    var name: String
    @Guide(description: "One-sentence description of the playlist's mood")
    var summary: String
}

/// Cleaned-up metadata parsed from a messy track title / filename.
@Generable(description: "Tidied track metadata parsed from a raw title")
struct TrackMetadata {
    @Guide(description: "Clean song title in Title Case")
    var title: String
    @Guide(description: "Artist name if clearly present in the input, otherwise an empty string")
    var artist: String
}

/// A natural-language library search resolved to structured filters.
@Generable(description: "Structured music-library search")
struct LibrarySearchPlan {
    @Guide(description: "Words to match against title, artist, or album; empty for none")
    var keywords: String
    @Guide(description: "Limit results to favorited songs only")
    var favoritesOnly: Bool
    @Guide(description: "Sort order", .anyOf(["recentlyAdded", "title", "artist", "mostPlayed", "leastPlayed"]))
    var sort: String
}

// MARK: - Service

/// Thin wrapper over the on-device system language model. Each method runs a
/// short, self-contained session; results are always validated by the caller.
@MainActor
@Observable
final class IntelligenceService {
    var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    /// A user-facing explanation when the model can't be used, or nil when it can.
    var unavailableMessage: String? {
        switch availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn’t support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to use this feature."
        case .unavailable(.modelNotReady):
            return "The on-device model is still preparing. Try again in a little while."
        case .unavailable:
            return "On-device intelligence isn’t available right now."
        }
    }

    // MARK: Studio — describe a sound (#1)

    func effectRecipe(for description: String) async throws -> EffectRecipe {
        let session = LanguageModelSession(instructions: """
            You are a tasteful audio engineer inside a music-making app. Translate a \
            description of a desired sound into concrete effect settings. Prefer subtle, \
            musical values unless the user explicitly asks for an extreme or experimental \
            effect. Reach for distortion only when clearly warranted.
            """)
        return try await session.respond(to: description, generating: EffectRecipe.self).content
    }

    // MARK: Smart playlist (#2)

    func playlistPlan(prompt: String, candidates: [String]) async throws -> PlaylistPlan {
        let numbered = candidates.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
            You are a music curator. From a numbered list of available tracks, choose the \
            songs that best fit the user's request and arrange them in a pleasing order. \
            Only use numbers that appear in the list. Give the playlist a short, evocative name.
            """)
        let prompt = """
            Request: \(prompt)

            Available tracks:
            \(numbered)
            """
        return try await session.respond(to: prompt, generating: PlaylistPlan.self).content
    }

    // MARK: Playlist name + description (#3)

    func playlistMeta(forTrackTitles titles: [String]) async throws -> PlaylistMeta {
        let list = titles.prefix(40).joined(separator: ", ")
        let session = LanguageModelSession(instructions: """
            You name music playlists. Given a set of tracks, suggest a short, catchy name \
            (at most four words) and a single-sentence description of the overall vibe.
            """)
        return try await session.respond(to: "Tracks: \(list)", generating: PlaylistMeta.self).content
    }

    // MARK: Tidy metadata from a messy title (#4)

    func cleanedMetadata(fromRawTitle rawTitle: String) async throws -> TrackMetadata {
        let session = LanguageModelSession(instructions: """
            You tidy up messy song titles that often come from filenames. Extract a clean \
            song title and, only if it is clearly present in the input, the artist. Never \
            invent information that isn't in the input. Use Title Case. Remove separators, \
            track numbers, and tags like "final" or "v2".
            """)
        return try await session.respond(to: rawTitle, generating: TrackMetadata.self).content
    }

    // MARK: Promo caption (#5)

    func promoCaption(title: String, artist: String) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You write short, upbeat social-media captions for independent musicians \
            announcing one of their tracks. Keep it to one or two sentences. You may add a \
            couple of fitting hashtags. Avoid tired hype clichés.
            """)
        return try await session.respond(to: "Track: \"\(title)\" by \(artist)").content
    }

    // MARK: Natural-language search (#6)

    func searchPlan(for query: String) async throws -> LibrarySearchPlan {
        let session = LanguageModelSession(instructions: """
            You convert a natural-language music search into structured filters for a local \
            library. Pull out keywords (artist or title words), whether to limit to \
            favorites, and a sort order that matches the intent (for example, "songs I \
            rarely play" means leastPlayed).
            """)
        return try await session.respond(to: query, generating: LibrarySearchPlan.self).content
    }
}
