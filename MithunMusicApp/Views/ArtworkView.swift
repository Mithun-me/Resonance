//
//  ArtworkView.swift
//  MithunMusicApp
//

import SwiftUI

/// Shows a song's embedded artwork, or a colorful gradient placeholder.
struct ArtworkView: View {
    let song: Song?
    var cornerRadius: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let data = song?.artworkData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    let hue = song?.artworkHue ?? 0.6
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.65, brightness: 0.9),
                            Color(hue: (hue + 0.07).truncatingRemainder(dividingBy: 1), saturation: 0.8, brightness: 0.4),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: geometry.size.width * 0.42, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
