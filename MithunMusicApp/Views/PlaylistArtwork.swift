//
//  PlaylistArtwork.swift
//  MithunMusicApp
//

import SwiftUI

/// Cover art for a playlist: a single track's artwork, a 2×2 mosaic of the
/// first few tracks, or a gradient placeholder when the playlist is empty.
struct PlaylistArtwork: View {
    let songs: [Song]
    var cornerRadius: CGFloat = 10

    private var tiles: [Song] { Array(songs.prefix(4)) }

    var body: some View {
        Group {
            switch tiles.count {
            case 0:
                placeholder
            case 1:
                ArtworkTile(song: tiles[0])
            default:
                mosaic
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Pads the available tiles up to four by cycling, so the grid is always full.
    private var mosaic: some View {
        let four = (0..<4).map { tiles[$0 % tiles.count] }
        return VStack(spacing: 1.5) {
            HStack(spacing: 1.5) {
                ArtworkTile(song: four[0])
                ArtworkTile(song: four[1])
            }
            HStack(spacing: 1.5) {
                ArtworkTile(song: four[2])
                ArtworkTile(song: four[3])
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.62, saturation: 0.5, brightness: 0.85),
                    Color(hue: 0.72, saturation: 0.7, brightness: 0.45),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { geometry in
                Image(systemName: "music.note.list")
                    .font(.system(size: geometry.size.width * 0.36, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

/// A single square cell of artwork — image or gradient — that fills its space
/// without rounding, so it can tile cleanly inside a mosaic.
private struct ArtworkTile: View {
    let song: Song

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let data = song.artworkData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            Color(hue: song.artworkHue, saturation: 0.65, brightness: 0.9),
                            Color(hue: (song.artworkHue + 0.07).truncatingRemainder(dividingBy: 1),
                                  saturation: 0.8, brightness: 0.4),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}
