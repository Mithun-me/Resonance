//
//  Recorder.swift
//  MithunMusicApp
//

import AVFoundation
import Observation

/// Microphone recorder that writes AAC files into the library's music folder.
@MainActor
@Observable
final class Recorder {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var level: Double = 0
    private(set) var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var fileName: String?

    func start() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            permissionDenied = true
            return
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let name = "recording-\(UUID().uuidString).m4a"
        let url = Song.musicDirectory.appendingPathComponent(name)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let newRecorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        newRecorder.isMeteringEnabled = true
        newRecorder.record()

        recorder = newRecorder
        fileName = name
        elapsed = 0
        level = 0
        isRecording = true
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
    }

    func stop() -> (fileName: String, duration: TimeInterval)? {
        guard let recorder, let fileName else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        meterTimer?.invalidate()
        meterTimer = nil
        self.recorder = nil
        self.fileName = nil
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        return (fileName, duration)
    }

    private func tick() {
        guard let recorder else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime
        let decibels = Double(recorder.averagePower(forChannel: 0))
        level = max(0, min(1, (decibels + 50) / 50))
    }
}
