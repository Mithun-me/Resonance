//
//  RecorderView.swift
//  MithunMusicApp
//

import SwiftData
import SwiftUI

struct RecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(PlayerManager.self) private var player

    @State private var recorder = Recorder()
    @State private var pendingFileName: String?
    @State private var pendingDuration: TimeInterval = 0
    @State private var trackName = ""
    @State private var isNaming = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 36) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(.red.opacity(0.12))
                        .frame(width: 190, height: 190)
                        .scaleEffect(1 + recorder.level * 0.5)
                        .animation(.easeOut(duration: 0.12), value: recorder.level)
                    Circle()
                        .fill(.red.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .scaleEffect(1 + recorder.level * 0.25)
                        .animation(.easeOut(duration: 0.12), value: recorder.level)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.red)
                }

                Text(timeString)
                    .font(.system(size: 46, weight: .light))
                    .monospacedDigit()

                if recorder.permissionDenied {
                    Text("Microphone access is required. Enable it for MithunMusicApp in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    toggleRecording()
                } label: {
                    Label(
                        recorder.isRecording ? "Stop" : "Record",
                        systemImage: recorder.isRecording ? "stop.fill" : "record.circle"
                    )
                    .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)

                Spacer()
            }
            .padding()
            .navigationTitle("Record a Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { cancel() }
                }
            }
            .alert("Name Your Track", isPresented: $isNaming) {
                TextField("Title", text: $trackName)
                Button("Save") { savePending() }
                Button("Discard", role: .destructive) { discardPending() }
            } message: {
                Text("The recording will be added to your Library.")
            }
            .interactiveDismissDisabled(recorder.isRecording || pendingFileName != nil)
        }
    }

    private var timeString: String {
        let total = Int(recorder.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func toggleRecording() {
        if recorder.isRecording {
            guard let result = recorder.stop() else { return }
            pendingFileName = result.fileName
            pendingDuration = result.duration
            trackName = "My Recording"
            isNaming = true
        } else {
            if player.isPlaying {
                player.togglePlayPause()
            }
            Task { await recorder.start() }
        }
    }

    private func savePending() {
        guard let fileName = pendingFileName else { return }
        let name = trackName.trimmingCharacters(in: .whitespaces)
        context.insert(Song(
            title: name.isEmpty ? "My Recording" : name,
            artist: "Me",
            album: "Recordings",
            duration: pendingDuration,
            fileName: fileName
        ))
        pendingFileName = nil
        dismiss()
    }

    private func discardPending() {
        if let fileName = pendingFileName {
            try? FileManager.default.removeItem(at: Song.musicDirectory.appendingPathComponent(fileName))
        }
        pendingFileName = nil
    }

    private func cancel() {
        if recorder.isRecording, let result = recorder.stop() {
            try? FileManager.default.removeItem(at: Song.musicDirectory.appendingPathComponent(result.fileName))
        }
        dismiss()
    }
}
