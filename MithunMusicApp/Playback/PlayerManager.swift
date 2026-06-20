//
//  PlayerManager.swift
//  MithunMusicApp
//

import AVFoundation
import MediaPlayer
import Observation
import UIKit

extension Notification.Name {
    /// Posted when the main player starts or resumes a song, so the
    /// Studio preview engine can stop and free the speakers.
    static let mainPlayerDidStartPlayback = Notification.Name("mainPlayerDidStartPlayback")
}

@MainActor
@Observable
final class PlayerManager: NSObject {
    enum RepeatMode {
        case off, all, one

        var next: RepeatMode {
            switch self {
            case .off: .all
            case .all: .one
            case .one: .off
            }
        }

        var systemImage: String {
            self == .one ? "repeat.1" : "repeat"
        }
    }

    private(set) var queue: [Song] = []
    private(set) var currentIndex = 0
    private(set) var isPlaying = false
    private(set) var duration: TimeInterval = 0
    var currentTime: TimeInterval = 0
    var repeatMode: RepeatMode = .off
    var isPresentingFullPlayer = false
    var isScrubbing = false

    private(set) var isShuffling = false
    private var orderedContext: [Song] = []

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var didConfigureRemoteCommands = false

    var currentSong: Song? {
        queue.indices.contains(currentIndex) ? queue[currentIndex] : nil
    }

    // Note: deliberately no work in init. Touching MediaPlayer/AVAudioSession
    // (both XPC-backed) is deferred until the first playback, so nothing
    // reaches a system daemon during app bootstrap.

    // MARK: - Playback

    func play(_ song: Song, in songs: [Song]) {
        orderedContext = songs
        if isShuffling {
            queue = [song] + songs.filter { $0 !== song }.shuffled()
            currentIndex = 0
        } else {
            queue = songs
            currentIndex = songs.firstIndex { $0 === song } ?? 0
        }
        startCurrentSong()
    }

    /// Plays a collection from the top, or shuffled — used by the Play and
    /// Shuffle buttons on a playlist. Sets the shuffle state to match the intent.
    func play(_ songs: [Song], shuffled: Bool) {
        guard !songs.isEmpty else { return }
        isShuffling = shuffled
        let start = shuffled ? (songs.randomElement() ?? songs[0]) : songs[0]
        play(start, in: songs)
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            activateAudioSession()
            NotificationCenter.default.post(name: .mainPlayerDidStartPlayback, object: nil)
            player.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    func skipForward() {
        guard !queue.isEmpty else { return }
        if currentIndex + 1 < queue.count {
            currentIndex += 1
            startCurrentSong()
        } else if repeatMode == .all {
            currentIndex = 0
            startCurrentSong()
        } else {
            stop()
        }
    }

    func skipBackward() {
        guard let player else { return }
        if player.currentTime > 3 || currentIndex == 0 {
            seek(to: 0)
        } else {
            currentIndex -= 1
            startCurrentSong()
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, time), duration)
        currentTime = player.currentTime
        updateNowPlayingInfo()
    }

    func toggleShuffle() {
        isShuffling.toggle()
        guard let current = currentSong else { return }
        if isShuffling {
            queue = [current] + queue.filter { $0 !== current }.shuffled()
            currentIndex = 0
        } else {
            queue = orderedContext.isEmpty ? queue : orderedContext
            currentIndex = queue.firstIndex { $0 === current } ?? 0
        }
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        progressTimer?.invalidate()
        progressTimer = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Removes a song that is being deleted from the library.
    func handleDeletion(of song: Song) {
        if currentSong === song {
            stop()
            queue.removeAll { $0 === song }
            currentIndex = 0
            isPresentingFullPlayer = false
        } else {
            if let index = queue.firstIndex(where: { $0 === song }), index < currentIndex {
                currentIndex -= 1
            }
            queue.removeAll { $0 === song }
        }
        orderedContext.removeAll { $0 === song }
    }

    // MARK: - Internals

    private func startCurrentSong() {
        guard let song = currentSong else { return }
        do {
            activateAudioSession()
            NotificationCenter.default.post(name: .mainPlayerDidStartPlayback, object: nil)
            let newPlayer = try AVAudioPlayer(contentsOf: song.fileURL)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            duration = newPlayer.duration
            currentTime = 0
            isPlaying = true
            song.playCount += 1
            startProgressTimer()
            updateNowPlayingInfo()
        } catch {
            isPlaying = false
        }
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        configureRemoteCommandsIfNeeded()
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
    }

    private func tick() {
        guard let player, isPlaying, !isScrubbing else { return }
        currentTime = player.currentTime
    }

    private func handleTrackEnd() {
        if repeatMode == .one {
            startCurrentSong()
        } else {
            skipForward()
        }
    }

    // MARK: - Now Playing / Remote Commands

    private func configureRemoteCommandsIfNeeded() {
        guard !didConfigureRemoteCommands else { return }
        didConfigureRemoteCommands = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                if !self.isPlaying { self.togglePlayPause() }
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in
                if self.isPlaying { self.togglePlayPause() }
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.skipForward() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.skipBackward() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor in self.seek(to: position) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let data = song.artworkData, let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension PlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.handleTrackEnd()
        }
    }
}
