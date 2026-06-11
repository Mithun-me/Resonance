//
//  AppState.swift
//  MithunMusicApp
//

import Observation
import SwiftUI

enum AppTab: Hashable {
    case library, favorites, playlists, studio
}

/// Cross-tab navigation state, e.g. "Edit in Studio" from the Library.
@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .library
    var studioSong: Song?
}
