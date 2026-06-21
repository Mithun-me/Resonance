//
//  CaptionSheet.swift
//  MithunMusicApp
//

import SwiftUI
import UIKit

/// Generates a short, shareable promo caption for a track using the on-device
/// model — handy for an artist posting about a release.
struct CaptionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(IntelligenceService.self) private var intelligence
    let song: Song

    @State private var caption = ""
    @State private var isGenerating = false
    @State private var error: String?
    @State private var isSharing = false
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ArtworkView(song: song, cornerRadius: 8)
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title).font(.headline).lineLimit(1)
                            Text(song.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }

                    if let error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if caption.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Writing a caption…").foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                    } else {
                        Text(caption)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Promo Caption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !caption.isEmpty {
                    HStack(spacing: 12) {
                        Button {
                            Task { await generate() }
                        } label: {
                            Label("Regenerate", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isGenerating)

                        Button {
                            UIPasteboard.general.string = caption
                            didCopy = true
                        } label: {
                            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            isSharing = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.bar)
                }
            }
            .sheet(isPresented: $isSharing) {
                ActivityView(activityItems: [caption])
            }
        }
        .task { await generate() }
    }

    private func generate() async {
        isGenerating = true
        didCopy = false
        error = nil
        caption = ""
        defer { isGenerating = false }
        do {
            caption = try await intelligence.promoCaption(title: song.title, artist: song.artist)
        } catch {
            self.error = "Couldn’t write a caption right now. Try again."
        }
    }
}
