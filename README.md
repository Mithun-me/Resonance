# 🎵 Resonance

**Your music library and your studio — in one pocket-sized app.**

Resonance is a music player *and* audio editor built for independent
artists. Play and organize your tracks, then record, shape, and export your
own sound — all on-device. No accounts, no subscriptions, no cloud.

---

## Features

### 🎵 Library & Playback
- Import audio from the Files app; organize by song, artist, or album
- Instant search across your whole library
- Favorites and custom playlists
- Full-screen player with shuffle, repeat, and scrubbing
- Lock-screen / Control Center controls and background playback
- Sample tracks seeded on first launch so there's music to play right away

### 🎚️ Studio — edit and create
- Visual waveform editor with draggable trim handles, playhead, and tap-to-scrub
- Live-previewed effects rack: gain, fade in/out, pitch shift (±12 semitones),
  speed (0.5–2×), 3-band EQ, reverb, delay, and distortion
- **Non-destructive** — your originals are never overwritten
- Offline export bounces your edit to a new AAC track in a "Studio Edits" album

### 🎙️ Record
- Capture vocals or instruments from the mic with a live level meter
- Recordings save straight to your library and open in the Studio

---

## Tech

- **SwiftUI** + **SwiftData** for the UI and persistence
- **AVFoundation** for playback, recording, and the real-time effect graph
  (`AVAudioEngine`), plus offline rendering for export
- **MediaPlayer** for lock-screen / remote controls
- Pure on-device processing — no third-party dependencies

## Requirements

- Xcode 26.5+
- iOS 26.5+

## Getting started

```bash
open MithunMusicApp.xcodeproj
```

Select the **MithunMusicApp** scheme and run on a simulator or device — the
app installs to the home screen as **Resonance**. Recording requires
microphone permission (requested on first use).

## Project structure

```
MithunMusicApp/
├── Models/        Song, Playlist, AppState
├── Playback/      PlayerManager (AVAudioPlayer engine)
├── Services/      SongImporter, SampleLibrary
├── Studio/        StudioEngine, editor, waveform, recorder
└── Views/         Library, Favorites, Playlists, Player, shared UI
```
