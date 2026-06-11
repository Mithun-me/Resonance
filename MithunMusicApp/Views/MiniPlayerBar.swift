//
//  MiniPlayerBar.swift
//  MithunMusicApp
//

import SwiftUI

struct MiniPlayerBar: View {
    @Environment(PlayerManager.self) private var player

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(song: player.currentSong, cornerRadius: 6)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 1) {
                Text(player.currentSong?.title ?? "Not Playing")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(player.currentSong?.artist ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Button {
                player.skipForward()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if player.currentSong != nil {
                player.isPresentingFullPlayer = true
            }
        }
    }
}
