//
//  SampleLibrary.swift
//  MithunMusicApp
//

import AVFoundation
import Foundation
import SwiftData

/// Synthesizes a few short instrumental tracks on first launch so the
/// library has playable music before the user imports anything.
enum SampleLibrary {
    private static let seededKey = "didSeedSampleLibrary"

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        for spec in specs {
            guard let duration = try? render(spec) else { continue }
            context.insert(Song(
                title: spec.title,
                artist: spec.artist,
                album: spec.album,
                duration: duration,
                fileName: spec.fileName,
                artworkHue: spec.hue
            ))
        }
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    // MARK: - Track definitions

    private struct TrackSpec {
        let title: String
        let artist: String
        let album: String
        let hue: Double
        let tempo: Double
        /// MIDI note numbers, looped as eighth notes.
        let pattern: [Int]
        let decay: Double
        let wave: (_ frequency: Double, _ time: Double) -> Double
        let fileName: String
    }

    private nonisolated static func sine(_ frequency: Double, _ time: Double) -> Double {
        sin(2 * .pi * frequency * time)
    }

    private nonisolated static func triangle(_ frequency: Double, _ time: Double) -> Double {
        let phase = (frequency * time).truncatingRemainder(dividingBy: 1)
        return 4 * abs(phase - 0.5) - 1
    }

    private nonisolated static func softSquare(_ frequency: Double, _ time: Double) -> Double {
        tanh(3 * sin(2 * .pi * frequency * time))
    }

    private nonisolated static func pluck(_ frequency: Double, _ time: Double) -> Double {
        sin(2 * .pi * frequency * time) + 0.4 * sin(4 * .pi * frequency * time)
    }

    private static let specs: [TrackSpec] = [
        TrackSpec(
            title: "Midnight Drive", artist: "Mithun", album: "Neon Sketches",
            hue: 0.62, tempo: 100,
            pattern: [57, 60, 64, 67, 64, 60, 57, 52, 55, 59, 62, 59, 55, 52, 57, 60],
            decay: 4, wave: sine, fileName: "sample-midnight-drive.caf"
        ),
        TrackSpec(
            title: "Sunrise Patterns", artist: "Mithun", album: "Neon Sketches",
            hue: 0.08, tempo: 124,
            pattern: [60, 64, 67, 71, 72, 71, 67, 64, 62, 65, 69, 72, 74, 72, 69, 65],
            decay: 5, wave: triangle, fileName: "sample-sunrise-patterns.caf"
        ),
        TrackSpec(
            title: "Rainy Window", artist: "Mithun", album: "Slow Hours",
            hue: 0.5, tempo: 72,
            pattern: [55, 58, 62, 65, 62, 58, 53, 56, 60, 63, 60, 56],
            decay: 2.5, wave: softSquare, fileName: "sample-rainy-window.caf"
        ),
        TrackSpec(
            title: "Synth Garden", artist: "Mithun", album: "Slow Hours",
            hue: 0.78, tempo: 132,
            pattern: [62, 66, 69, 74, 73, 69, 66, 64, 67, 71, 76, 74, 71, 67, 66, 62],
            decay: 6, wave: pluck, fileName: "sample-synth-garden.caf"
        ),
    ]

    // MARK: - Synthesis

    private static func render(_ spec: TrackSpec) throws -> TimeInterval {
        let sampleRate = 44_100.0
        let length: TimeInterval = 28
        let stepDuration = 60.0 / spec.tempo / 2
        let frameCount = AVAudioFrameCount(length * sampleRate)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        let totalSteps = Int(length / stepDuration)
        for step in 0..<totalSteps {
            let midi = spec.pattern[step % spec.pattern.count]
            renderNote(midi: midi, into: samples,
                       startFrame: Int(Double(step) * stepDuration * sampleRate),
                       noteDuration: stepDuration * 1.8, totalFrames: Int(frameCount),
                       sampleRate: sampleRate, gain: 0.3, decay: spec.decay, wave: spec.wave)
            // Bass note on every fourth step, an octave below the melody.
            if step % 4 == 0 {
                renderNote(midi: midi - 12, into: samples,
                           startFrame: Int(Double(step) * stepDuration * sampleRate),
                           noteDuration: stepDuration * 4, totalFrames: Int(frameCount),
                           sampleRate: sampleRate, gain: 0.18, decay: 1.5, wave: sine)
            }
        }

        // Fade out the last two seconds.
        let fadeFrames = Int(2 * sampleRate)
        for i in 0..<fadeFrames {
            let index = Int(frameCount) - fadeFrames + i
            samples[index] *= Float(1 - Double(i) / Double(fadeFrames))
        }

        let url = Song.musicDirectory.appendingPathComponent(spec.fileName)
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return length
    }

    private static func renderNote(
        midi: Int, into samples: UnsafeMutablePointer<Float>,
        startFrame: Int, noteDuration: TimeInterval, totalFrames: Int,
        sampleRate: Double, gain: Double, decay: Double,
        wave: (_ frequency: Double, _ time: Double) -> Double
    ) {
        let frequency = 440 * pow(2, (Double(midi) - 69) / 12)
        let noteFrames = Int(noteDuration * sampleRate)
        for i in 0..<noteFrames {
            let index = startFrame + i
            guard index < totalFrames else { break }
            let t = Double(i) / sampleRate
            let envelope = min(1, t / 0.012) * exp(-t * decay)
            samples[index] += Float(wave(frequency, t) * envelope * gain)
        }
    }
}
