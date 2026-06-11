//
//  PlayerView.swift
//  MithunMusicApp
//

import SwiftUI

/// Full-screen now-playing view.
struct PlayerView: View {
    @Environment(PlayerManager.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var player = player
        VStack(spacing: 24) {
            Capsule()
                .fill(.tertiary)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Spacer()

            ArtworkView(song: player.currentSong, cornerRadius: 20)
                .frame(maxWidth: 320)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
                .scaleEffect(player.isPlaying ? 1 : 0.92)
                .animation(.spring(duration: 0.4), value: player.isPlaying)

            VStack(spacing: 6) {
                Text(player.currentSong?.title ?? "Not Playing")
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Text(player.currentSong?.artist ?? "")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal)

            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.currentTime = $0 }
                    ),
                    in: 0...max(player.duration, 1)
                ) { editing in
                    player.isScrubbing = editing
                    if !editing {
                        player.seek(to: player.currentTime)
                    }
                }
                HStack {
                    Text(formatted(player.currentTime))
                    Spacer()
                    Text("-" + formatted(max(0, player.duration - player.currentTime)))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .padding(.horizontal, 24)

            HStack(spacing: 48) {
                Button {
                    player.skipBackward()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                }

                Button {
                    player.skipForward()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            .buttonStyle(.plain)

            HStack {
                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundStyle(player.isShuffling ? Color.accentColor : .secondary)
                }

                Spacer()

                Button {
                    player.currentSong?.isFavorite.toggle()
                } label: {
                    Image(systemName: player.currentSong?.isFavorite == true ? "heart.fill" : "heart")
                        .foregroundStyle(player.currentSong?.isFavorite == true ? .pink : .secondary)
                }

                Spacer()

                Button {
                    player.cycleRepeatMode()
                } label: {
                    Image(systemName: player.repeatMode.systemImage)
                        .foregroundStyle(player.repeatMode == .off ? .secondary : Color.accentColor)
                }
            }
            .font(.title3)
            .padding(.horizontal, 48)

            Spacer()
        }
        .padding()
        .presentationDragIndicator(.hidden)
    }

    private func formatted(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
