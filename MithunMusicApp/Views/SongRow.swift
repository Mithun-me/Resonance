//
//  SongRow.swift
//  MithunMusicApp
//

import SwiftUI

struct SongRow: View {
    let song: Song
    var isCurrent = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(song: song)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    .lineLimit(1)
                Text("\(song.artist) · \(song.formattedDuration)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isCurrent {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.subheadline)
            }
            if song.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.subheadline)
            }
        }
        .contentShape(Rectangle())
    }
}
