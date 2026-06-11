//
//  EditSettings.swift
//  MithunMusicApp
//

import AVFoundation

nonisolated enum ReverbPreset: String, CaseIterable, Identifiable {
    case smallRoom, mediumRoom, largeHall, cathedral, plate

    var id: Self { self }

    var label: String {
        switch self {
        case .smallRoom: "Small Room"
        case .mediumRoom: "Medium Room"
        case .largeHall: "Large Hall"
        case .cathedral: "Cathedral"
        case .plate: "Plate"
        }
    }

    var avPreset: AVAudioUnitReverbPreset {
        switch self {
        case .smallRoom: .smallRoom
        case .mediumRoom: .mediumRoom
        case .largeHall: .largeHall
        case .cathedral: .cathedral
        case .plate: .plate
        }
    }
}

nonisolated enum DistortionPreset: String, CaseIterable, Identifiable {
    case bitBrush, loFi, distortedFunk, echo, brokenSpeaker

    var id: Self { self }

    var label: String {
        switch self {
        case .bitBrush: "Bit Brush"
        case .loFi: "Drums Lo-Fi"
        case .distortedFunk: "Distorted Funk"
        case .echo: "Multi Echo"
        case .brokenSpeaker: "Broken Speaker"
        }
    }

    var avPreset: AVAudioUnitDistortionPreset {
        switch self {
        case .bitBrush: .drumsBitBrush
        case .loFi: .drumsLoFi
        case .distortedFunk: .multiDistortedFunk
        case .echo: .multiEcho1
        case .brokenSpeaker: .multiBrokenSpeaker
        }
    }
}

/// Every adjustable parameter of a studio edit. Value type so the UI can
/// diff it cheaply and a copy can be handed to the offline export render.
nonisolated struct EditSettings: Equatable, Sendable {
    var trimStart: TimeInterval = 0
    var trimEnd: TimeInterval = 0

    var gain: Double = 1            // 0...2
    var fadeIn: TimeInterval = 0    // seconds
    var fadeOut: TimeInterval = 0

    var pitchSemitones: Double = 0  // -12...12
    var rate: Double = 1            // 0.5...2

    var eqLow: Double = 0           // dB, -12...12
    var eqMid: Double = 0
    var eqHigh: Double = 0

    var reverbPreset: ReverbPreset = .mediumRoom
    var reverbMix: Double = 0       // percent 0...100

    var delayTime: Double = 0.25    // seconds
    var delayFeedback: Double = 30  // percent
    var delayMix: Double = 0

    var distortionPreset: DistortionPreset = .loFi
    var distortionMix: Double = 0
}
