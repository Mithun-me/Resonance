//
//  ActivityView.swift
//  MithunMusicApp
//

import SwiftUI
import UIKit

/// Identifiable wrapper so a share target can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// SwiftUI bridge to `UIActivityViewController` (the system share sheet).
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
