//
//  WaveformView.swift
//  MithunMusicApp
//

import AVFoundation
import SwiftUI

/// Downsamples an audio file into peak values for waveform drawing.
enum WaveformLoader {
    static func peaks(for url: URL, count: Int = 220) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let totalFrames = Int(file.length)
        guard totalFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 131_072) else {
            return []
        }
        let framesPerBin = max(1, totalFrames / count)
        var result = [Float](repeating: 0, count: count)
        var frameIndex = 0
        while file.framePosition < file.length {
            try file.read(into: buffer)
            guard buffer.frameLength > 0, let data = buffer.floatChannelData else { break }
            for i in 0..<Int(buffer.frameLength) {
                let bin = min(count - 1, (frameIndex + i) / framesPerBin)
                let value = abs(data[0][i])
                if value > result[bin] { result[bin] = value }
            }
            frameIndex += Int(buffer.frameLength)
        }
        if let maximum = result.max(), maximum > 0 {
            for i in 0..<count { result[i] /= maximum }
        }
        return result
    }
}

/// Waveform with draggable trim handles and a playhead. Tap to scrub.
struct WaveformView: View {
    let peaks: [Float]
    let duration: TimeInterval
    @Binding var trimStart: TimeInterval
    @Binding var trimEnd: TimeInterval
    let playhead: TimeInterval
    var onScrub: ((TimeInterval) -> Void)?

    private let minimumSelection: TimeInterval = 0.5

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    guard !peaks.isEmpty, duration > 0 else { return }
                    let barWidth = size.width / CGFloat(peaks.count)
                    for (index, peak) in peaks.enumerated() {
                        let time = (Double(index) + 0.5) / Double(peaks.count) * duration
                        let barHeight = max(3, CGFloat(peak) * size.height * 0.9)
                        let rect = CGRect(
                            x: CGFloat(index) * barWidth + barWidth * 0.15,
                            y: (size.height - barHeight) / 2,
                            width: barWidth * 0.7,
                            height: barHeight
                        )
                        let inSelection = time >= trimStart && time <= trimEnd
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: barWidth * 0.3),
                            with: .color(inSelection ? Color.accentColor : Color.gray.opacity(0.35))
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    guard duration > 0 else { return }
                    onScrub?(Double(location.x / width) * duration)
                }

                if duration > 0 {
                    Rectangle()
                        .fill(.red)
                        .frame(width: 2, height: height)
                        .offset(x: CGFloat(playhead / duration) * width - 1)
                }

                trimHandle(isStart: true, width: width, height: height)
                trimHandle(isStart: false, width: width, height: height)
            }
            .coordinateSpace(name: "waveform")
        }
    }

    private func trimHandle(isStart: Bool, width: CGFloat, height: CGFloat) -> some View {
        let time = isStart ? trimStart : trimEnd
        let x = duration > 0 ? CGFloat(time / duration) * width : 0
        return ZStack {
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 5, height: height)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 15, height: 15)
                .offset(y: isStart ? -height / 2 + 4 : height / 2 - 4)
        }
        .frame(width: 30, height: height)
        .contentShape(Rectangle())
        .position(x: x, y: height / 2)
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named("waveform"))
                .onChanged { value in
                    guard duration > 0 else { return }
                    let newTime = Double(value.location.x / width) * duration
                    if isStart {
                        trimStart = min(max(0, newTime), trimEnd - minimumSelection)
                    } else {
                        trimEnd = max(min(duration, newTime), trimStart + minimumSelection)
                    }
                }
        )
    }
}
