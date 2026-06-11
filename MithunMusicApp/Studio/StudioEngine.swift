//
//  StudioEngine.swift
//  MithunMusicApp
//

import AVFoundation
import Observation

/// Live-preview and offline-render engine for the Studio editor.
///
/// Signal chain: player → time/pitch → 3-band EQ → distortion → delay → reverb → mixer.
@MainActor
@Observable
final class StudioEngine {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let eq = AVAudioUnitEQ(numberOfBands: 3)
    private let distortion = AVAudioUnitDistortion()
    private let delay = AVAudioUnitDelay()
    private let reverb = AVAudioUnitReverb()

    private var file: AVAudioFile?
    private(set) var duration: TimeInterval = 0
    private(set) var isPreviewing = false
    private(set) var playhead: TimeInterval = 0

    private var previewStartTime: TimeInterval = 0
    private var previewTrimStart: TimeInterval = 0
    private var previewGeneration = 0
    private var displayTimer: Timer?
    private var loadedReverbPreset: ReverbPreset?
    private var loadedDistortionPreset: DistortionPreset?
    private var playbackObserver: NSObjectProtocol?

    init() {
        for node in [playerNode, timePitch, eq, distortion, delay, reverb] as [AVAudioNode] {
            engine.attach(node)
        }
        Self.configureEQBands(eq)
        reverb.wetDryMix = 0
        delay.wetDryMix = 0
        distortion.wetDryMix = 0

        // If the main player starts a song, give up the speakers.
        playbackObserver = NotificationCenter.default.addObserver(
            forName: .mainPlayerDidStartPlayback, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.stopPreview() }
        }
    }

    func load(url: URL) throws {
        stopPreview()
        let audioFile = try AVAudioFile(forReading: url)
        file = audioFile
        duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        playhead = 0
        engine.stop()
        // The effect units reject mono connections, so the graph always runs
        // in stereo; the player node up-mixes mono files automatically.
        guard let graphFormat = AVAudioFormat(
            standardFormatWithSampleRate: audioFile.processingFormat.sampleRate, channels: 2
        ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let chain: [AVAudioNode] = [playerNode, timePitch, eq, distortion, delay, reverb, engine.mainMixerNode]
        for i in 0..<(chain.count - 1) {
            engine.connect(chain[i], to: chain[i + 1], format: graphFormat)
        }
    }

    func unload() {
        stopPreview()
        file = nil
        duration = 0
        playhead = 0
    }

    // MARK: - Live preview

    func apply(_ settings: EditSettings) {
        Self.configureEffects(
            timePitch: timePitch, eq: eq, distortion: distortion,
            delay: delay, reverb: reverb, with: settings
        )
        if settings.reverbMix > 0, loadedReverbPreset != settings.reverbPreset {
            reverb.loadFactoryPreset(settings.reverbPreset.avPreset)
            loadedReverbPreset = settings.reverbPreset
        }
        if settings.distortionMix > 0, loadedDistortionPreset != settings.distortionPreset {
            distortion.loadFactoryPreset(settings.distortionPreset.avPreset)
            loadedDistortionPreset = settings.distortionPreset
        }
        engine.mainMixerNode.outputVolume = Float(settings.gain)
    }

    func startPreview(settings: EditSettings, from requestedStart: TimeInterval? = nil) {
        guard let file else { return }
        stopPreview()
        apply(settings)

        var start = requestedStart ?? playhead
        if start < settings.trimStart || start >= settings.trimEnd - 0.05 {
            start = settings.trimStart
        }
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(start * sampleRate)
        let endFrame = AVAudioFramePosition(min(settings.trimEnd, duration) * sampleRate)
        let frames = AVAudioFrameCount(max(1, endFrame - startFrame))

        previewStartTime = start
        previewTrimStart = settings.trimStart
        playhead = start
        previewGeneration += 1
        let generation = previewGeneration

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            engine.prepare()
            try engine.start()
        } catch {
            return
        }

        playerNode.scheduleSegment(
            file, startingFrame: startFrame, frameCount: frames, at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard generation == self.previewGeneration else { return }
                self.stopPreview()
                self.playhead = self.previewTrimStart
            }
        }
        playerNode.play()
        isPreviewing = true
        startDisplayTimer()
    }

    func stopPreview() {
        previewGeneration += 1
        displayTimer?.invalidate()
        displayTimer = nil
        guard isPreviewing else { return }
        playerNode.stop()
        engine.stop()
        isPreviewing = false
    }

    /// Tap or drag on the waveform: restart preview from there, or just move the playhead.
    func scrub(to time: TimeInterval, settings: EditSettings) {
        let clamped = min(max(time, settings.trimStart), settings.trimEnd)
        if isPreviewing {
            startPreview(settings: settings, from: clamped)
        } else {
            playhead = clamped
        }
    }

    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isPreviewing,
                      let nodeTime = self.playerNode.lastRenderTime,
                      let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) else { return }
                self.playhead = self.previewStartTime + Double(playerTime.sampleTime) / playerTime.sampleRate
            }
        }
    }

    // MARK: - Offline export

    /// Renders trim, gain, fades, and the full effect chain into a new AAC file.
    /// Runs the engine in manual rendering mode; safe to call off the main actor.
    nonisolated static func renderExport(
        sourceURL: URL, settings: EditSettings, to outputURL: URL
    ) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: sourceURL)
        let format = file.processingFormat
        let sampleRate = format.sampleRate

        let startFrame = AVAudioFramePosition(max(0, settings.trimStart) * sampleRate)
        let endFrame = AVAudioFramePosition(min(Double(file.length), settings.trimEnd * sampleRate))
        let sourceFrames = AVAudioFrameCount(max(1, endFrame - startFrame))

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        let eq = AVAudioUnitEQ(numberOfBands: 3)
        let distortion = AVAudioUnitDistortion()
        let delay = AVAudioUnitDelay()
        let reverb = AVAudioUnitReverb()
        for node in [player, timePitch, eq, distortion, delay, reverb] as [AVAudioNode] {
            engine.attach(node)
        }
        configureEQBands(eq)
        if settings.reverbMix > 0 { reverb.loadFactoryPreset(settings.reverbPreset.avPreset) }
        if settings.distortionMix > 0 { distortion.loadFactoryPreset(settings.distortionPreset.avPreset) }
        configureEffects(timePitch: timePitch, eq: eq, distortion: distortion,
                         delay: delay, reverb: reverb, with: settings)

        // Stereo graph: the effect units reject mono connections.
        guard let graphFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try engine.enableManualRenderingMode(.offline, format: graphFormat, maximumFrameCount: 4096)
        let chain: [AVAudioNode] = [player, timePitch, eq, distortion, delay, reverb, engine.mainMixerNode]
        for i in 0..<(chain.count - 1) {
            engine.connect(chain[i], to: chain[i + 1], format: graphFormat)
        }

        try engine.start()
        player.scheduleSegment(file, startingFrame: startFrame, frameCount: sourceFrames, at: nil)
        player.play()

        let outputFrames = AVAudioFramePosition(Double(sourceFrames) / settings.rate)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: graphFormat.channelCount,
            AVEncoderBitRateKey: 256_000,
        ]
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let fadeInFrames = AVAudioFramePosition(settings.fadeIn * sampleRate)
        let fadeOutFrames = AVAudioFramePosition(settings.fadeOut * sampleRate)

        while engine.manualRenderingSampleTime < outputFrames {
            let remaining = outputFrames - engine.manualRenderingSampleTime
            let framesToRender = AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity), remaining))
            let bufferStart = engine.manualRenderingSampleTime

            let status = try engine.renderOffline(framesToRender, to: buffer)
            switch status {
            case .success:
                applyEnvelope(
                    to: buffer, bufferStart: bufferStart, totalFrames: outputFrames,
                    gain: Float(settings.gain), fadeInFrames: fadeInFrames, fadeOutFrames: fadeOutFrames
                )
                try outputFile.write(from: buffer)
            case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
                continue
            case .error:
                throw CocoaError(.fileWriteUnknown)
            @unknown default:
                throw CocoaError(.fileWriteUnknown)
            }
        }

        player.stop()
        engine.stop()
        return Double(outputFrames) / sampleRate
    }

    /// Gain plus linear fade-in/out, applied per-sample in the output timeline.
    nonisolated private static func applyEnvelope(
        to buffer: AVAudioPCMBuffer, bufferStart: AVAudioFramePosition,
        totalFrames: AVAudioFramePosition, gain: Float,
        fadeInFrames: AVAudioFramePosition, fadeOutFrames: AVAudioFramePosition
    ) {
        guard gain != 1 || fadeInFrames > 0 || fadeOutFrames > 0,
              let channels = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        for frame in 0..<Int(buffer.frameLength) {
            let global = bufferStart + AVAudioFramePosition(frame)
            var envelope = gain
            if fadeInFrames > 0, global < fadeInFrames {
                envelope *= Float(Double(global) / Double(fadeInFrames))
            }
            let framesFromEnd = totalFrames - global
            if fadeOutFrames > 0, framesFromEnd < fadeOutFrames {
                envelope *= Float(max(0, Double(framesFromEnd) / Double(fadeOutFrames)))
            }
            if envelope != 1 {
                for channel in 0..<channelCount {
                    channels[channel][frame] *= envelope
                }
            }
        }
    }

    // MARK: - Shared node configuration

    nonisolated private static func configureEQBands(_ eq: AVAudioUnitEQ) {
        let low = eq.bands[0]
        low.filterType = .lowShelf
        low.frequency = 120
        low.bypass = false
        let mid = eq.bands[1]
        mid.filterType = .parametric
        mid.frequency = 1_000
        mid.bandwidth = 1
        mid.bypass = false
        let high = eq.bands[2]
        high.filterType = .highShelf
        high.frequency = 8_000
        high.bypass = false
    }

    nonisolated private static func configureEffects(
        timePitch: AVAudioUnitTimePitch, eq: AVAudioUnitEQ, distortion: AVAudioUnitDistortion,
        delay: AVAudioUnitDelay, reverb: AVAudioUnitReverb, with settings: EditSettings
    ) {
        timePitch.pitch = Float(settings.pitchSemitones * 100)
        timePitch.rate = Float(settings.rate)
        timePitch.bypass = settings.pitchSemitones == 0 && settings.rate == 1
        eq.bands[0].gain = Float(settings.eqLow)
        eq.bands[1].gain = Float(settings.eqMid)
        eq.bands[2].gain = Float(settings.eqHigh)
        reverb.wetDryMix = Float(settings.reverbMix)
        delay.delayTime = settings.delayTime
        delay.feedback = Float(settings.delayFeedback)
        delay.wetDryMix = Float(settings.delayMix)
        distortion.wetDryMix = Float(settings.distortionMix)
    }
}
