//
//  SplashView.swift
//  MithunMusicApp
//

import SwiftUI

/// Brief branded launch overlay: the Resonance rings ripple in, the wordmark
/// fades up, then it dissolves into the app. (iOS's own launch screen is
/// intentionally minimal, so the brand moment lives here.)
struct SplashView: View {
    @State private var animate = false

    private let rings: [(size: CGFloat, width: CGFloat, opacity: Double)] = [
        (96, 16, 0.80),
        (168, 13, 0.50),
        (240, 11, 0.28),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.31, green: 0.17, blue: 0.84),
                    Color(red: 0.49, green: 0.23, blue: 0.93),
                    Color(red: 0.86, green: 0.15, blue: 0.47),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {
                ZStack {
                    ForEach(Array(rings.enumerated()), id: \.offset) { index, ring in
                        Circle()
                            .stroke(.white.opacity(ring.opacity), lineWidth: ring.width)
                            .frame(width: ring.size, height: ring.size)
                            .scaleEffect(animate ? 1 : 0.55)
                            .opacity(animate ? 1 : 0)
                            .animation(
                                .spring(duration: 0.7, bounce: 0.3).delay(Double(2 - index) * 0.1),
                                value: animate
                            )
                    }
                    Circle()
                        .fill(.white)
                        .frame(width: 30, height: 30)
                        .scaleEffect(animate ? 1 : 0.2)
                        .animation(.spring(duration: 0.6, bounce: 0.4), value: animate)
                }
                .frame(width: 240, height: 240)

                Text("Resonance")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 10)
                    .animation(.easeOut(duration: 0.5).delay(0.35), value: animate)
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    SplashView()
}
