//
//  SmartPlaylistSheet.swift
//  MithunMusicApp
//

import SwiftData
import SwiftUI

/// Builds a playlist from a natural-language prompt, choosing from the library
/// with the on-device model. The model's picks are resolved by index and
/// validated, so it can never invent a track that isn't really there.
struct SmartPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(IntelligenceService.self) private var intelligence
    @Query(sort: \Song.dateAdded, order: .reverse) private var songs: [Song]

    @State private var prompt = ""
    @State private var isGenerating = false
    @State private var error: String?

    /// The on-device context window is small, so cap how many tracks we offer.
    private let candidateLimit = 60

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Describe the playlist — e.g. “late-night focus” or “high-energy gym mix”",
                              text: $prompt, axis: .vertical)
                        .lineLimit(2...5)
                } footer: {
                    Text("On-device AI picks from up to \(candidateLimit) of your tracks and orders them. Nothing leaves your iPhone.")
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Smart Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await generate() }
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Create").fontWeight(.semibold)
                        }
                    }
                    .disabled(isGenerating
                              || prompt.trimmingCharacters(in: .whitespaces).isEmpty
                              || songs.isEmpty)
                }
            }
            .overlay {
                if songs.isEmpty {
                    ContentUnavailableView(
                        "No Music",
                        systemImage: "music.note",
                        description: Text("Import songs in the Library first.")
                    )
                }
            }
        }
    }

    private func generate() async {
        let request = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !request.isEmpty else { return }
        let candidates = Array(songs.prefix(candidateLimit))
        isGenerating = true
        error = nil
        defer { isGenerating = false }
        do {
            let labels = candidates.map { "\($0.title) — \($0.artist)" }
            let plan = try await intelligence.playlistPlan(prompt: request, candidates: labels)

            // Resolve 1-based indices back to real songs, dropping anything
            // out of range or duplicated.
            var chosen: [Song] = []
            var seen = Set<Int>()
            for number in plan.trackNumbers {
                let index = number - 1
                guard candidates.indices.contains(index), !seen.contains(index) else { continue }
                seen.insert(index)
                chosen.append(candidates[index])
            }

            guard !chosen.isEmpty else {
                error = "The model didn’t pick any tracks. Try rephrasing your request."
                return
            }

            let name = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let playlist = Playlist(name: name.isEmpty ? request.capitalized : name)
            playlist.songs = chosen
            context.insert(playlist)
            dismiss()
        } catch {
            self.error = "Couldn’t generate a playlist right now. Try again."
        }
    }
}
