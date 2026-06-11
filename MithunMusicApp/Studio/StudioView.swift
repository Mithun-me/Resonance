//
//  StudioView.swift
//  MithunMusicApp
//

import SwiftData
import SwiftUI

/// Audio editor: trim, fades, pitch, speed, EQ, and effects with live
/// preview, exported as a new track in the library.
struct StudioView: View {
    @Environment(\.modelContext) private var context
    @Environment(PlayerManager.self) private var player
    @Environment(AppState.self) private var appState
    @Query(sort: \Song.dateAdded, order: .reverse) private var songs: [Song]

    @State private var engine = StudioEngine()
    @State private var settings = EditSettings()
    @State private var peaks: [Float] = []
    @State private var isShowingRecorder = false
    @State private var isExporting = false
    @State private var exportedTitle: String?
    @State private var didExportFail = false

    var body: some View {
        NavigationStack {
            Group {
                if let song = appState.studioSong {
                    editor(for: song)
                } else {
                    trackPicker
                }
            }
            .navigationTitle("Studio")
            .toolbar {
                if appState.studioSong != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { closeEditor() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        engine.stopPreview()
                        isShowingRecorder = true
                    } label: {
                        Label("Record", systemImage: "mic.fill")
                    }
                }
            }
            .sheet(isPresented: $isShowingRecorder) {
                RecorderView()
            }
            .alert(
                "Saved to Library",
                isPresented: Binding(
                    get: { exportedTitle != nil },
                    set: { if !$0 { exportedTitle = nil } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text("\"\(exportedTitle ?? "")\" is ready to play.")
            }
            .alert("Export Failed", isPresented: $didExportFail) {
                Button("OK") {}
            } message: {
                Text("The track could not be rendered. Try again.")
            }
        }
        .task(id: appState.studioSong?.persistentModelID) {
            loadSelection()
        }
        .onChange(of: settings) {
            engine.apply(settings)
        }
        .onDisappear {
            engine.stopPreview()
        }
    }

    // MARK: - Track picker

    private var trackPicker: some View {
        List {
            Section("Choose a track to edit") {
                ForEach(songs) { song in
                    Button {
                        appState.studioSong = song
                    } label: {
                        SongRow(song: song)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if songs.isEmpty {
                ContentUnavailableView(
                    "Nothing to Edit",
                    systemImage: "waveform",
                    description: Text("Import music in the Library, or record a track with the mic button.")
                )
            }
        }
    }

    // MARK: - Editor

    private func editor(for song: Song) -> some View {
        List {
            Section {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        ArtworkView(song: song, cornerRadius: 6)
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(song.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    WaveformView(
                        peaks: peaks,
                        duration: engine.duration,
                        trimStart: $settings.trimStart,
                        trimEnd: $settings.trimEnd,
                        playhead: engine.playhead
                    ) { time in
                        engine.scrub(to: time, settings: settings)
                    }
                    .frame(height: 110)
                    transport
                }
                .listRowSeparator(.hidden)
            }

            Section("Trim") {
                HStack {
                    labeledTime("Start", settings.trimStart)
                    Spacer()
                    labeledTime("End", settings.trimEnd)
                    Spacer()
                    labeledTime("Length", max(0, settings.trimEnd - settings.trimStart) / settings.rate)
                }
                Button("Reset Trim") {
                    settings.trimStart = 0
                    settings.trimEnd = engine.duration
                }
                .disabled(settings.trimStart == 0 && settings.trimEnd == engine.duration)
            }

            Section("Volume") {
                ParameterSlider(label: "Gain", value: $settings.gain, range: 0...2) {
                    String(format: "%.0f%%", $0 * 100)
                }
                ParameterSlider(label: "Fade In", value: $settings.fadeIn, range: 0...10, step: 0.5) {
                    String(format: "%.1fs", $0)
                }
                ParameterSlider(label: "Fade Out", value: $settings.fadeOut, range: 0...10, step: 0.5) {
                    String(format: "%.1fs", $0)
                }
            }

            Section("Pitch & Speed") {
                ParameterSlider(label: "Pitch", value: $settings.pitchSemitones, range: -12...12, step: 1) {
                    String(format: "%+.0f st", $0)
                }
                ParameterSlider(label: "Speed", value: $settings.rate, range: 0.5...2, step: 0.05) {
                    String(format: "%.2f×", $0)
                }
            }

            Section("Equalizer") {
                ParameterSlider(label: "Low", value: $settings.eqLow, range: -12...12, step: 1) {
                    String(format: "%+.0f dB", $0)
                }
                ParameterSlider(label: "Mid", value: $settings.eqMid, range: -12...12, step: 1) {
                    String(format: "%+.0f dB", $0)
                }
                ParameterSlider(label: "High", value: $settings.eqHigh, range: -12...12, step: 1) {
                    String(format: "%+.0f dB", $0)
                }
            }

            Section("Reverb") {
                Picker("Preset", selection: $settings.reverbPreset) {
                    ForEach(ReverbPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                ParameterSlider(label: "Mix", value: $settings.reverbMix, range: 0...100) {
                    String(format: "%.0f%%", $0)
                }
            }

            Section("Delay") {
                ParameterSlider(label: "Time", value: $settings.delayTime, range: 0.05...1, step: 0.05) {
                    String(format: "%.2fs", $0)
                }
                ParameterSlider(label: "Feedback", value: $settings.delayFeedback, range: 0...80) {
                    String(format: "%.0f%%", $0)
                }
                ParameterSlider(label: "Mix", value: $settings.delayMix, range: 0...100) {
                    String(format: "%.0f%%", $0)
                }
            }

            Section("Distortion") {
                Picker("Preset", selection: $settings.distortionPreset) {
                    ForEach(DistortionPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                ParameterSlider(label: "Mix", value: $settings.distortionMix, range: 0...100) {
                    String(format: "%.0f%%", $0)
                }
            }

            Section {
                Button {
                    Task { await exportEdit(of: song) }
                } label: {
                    HStack {
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .padding(.trailing, 6)
                        }
                        Text(isExporting ? "Exporting…" : "Export to Library")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(isExporting || engine.duration == 0)
            } footer: {
                Text("Renders the trim, fades, and effects into a new track in your Library.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Button {
                engine.scrub(to: settings.trimStart, settings: settings)
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.title3)
            }

            Button {
                togglePreview()
            } label: {
                Image(systemName: engine.isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 46))
            }

            Spacer()

            Text("\(timeString(engine.playhead)) / \(timeString(engine.duration))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .buttonStyle(.plain)
    }

    private func labeledTime(_ label: String, _ time: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(timeString(time))
                .font(.subheadline)
                .monospacedDigit()
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Actions

    private func loadSelection() {
        guard let song = appState.studioSong else {
            engine.unload()
            peaks = []
            return
        }
        do {
            try engine.load(url: song.fileURL)
            settings = EditSettings(trimStart: 0, trimEnd: engine.duration)
            peaks = try WaveformLoader.peaks(for: song.fileURL)
        } catch {
            appState.studioSong = nil
        }
    }

    private func togglePreview() {
        if engine.isPreviewing {
            engine.stopPreview()
        } else {
            if player.isPlaying {
                player.togglePlayPause()
            }
            engine.startPreview(settings: settings)
        }
    }

    private func closeEditor() {
        engine.unload()
        appState.studioSong = nil
    }

    private func exportEdit(of song: Song) async {
        engine.stopPreview()
        isExporting = true
        defer { isExporting = false }

        let fileName = "edit-\(UUID().uuidString).m4a"
        let outputURL = Song.musicDirectory.appendingPathComponent(fileName)
        let exportSettings = settings
        let sourceURL = song.fileURL
        do {
            let duration = try await Task.detached(priority: .userInitiated) {
                try StudioEngine.renderExport(sourceURL: sourceURL, settings: exportSettings, to: outputURL)
            }.value
            let edited = Song(
                title: "\(song.title) (Studio Edit)",
                artist: song.artist,
                album: "Studio Edits",
                duration: duration,
                fileName: fileName,
                artworkHue: song.artworkHue,
                artworkData: song.artworkData
            )
            context.insert(edited)
            exportedTitle = edited.title
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            didExportFail = true
        }
    }
}

/// Labeled slider row with a live value readout.
struct ParameterSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let display: (Double) -> String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(display(value))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
        .padding(.vertical, 2)
    }
}
