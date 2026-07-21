//
//  WatchRootView.swift
//  WearlyWatch
//
//  Single-face layout — no scrolling, no custom top chrome. The watch
//  system draws the clock at the top-right; we let it sit there
//  undisturbed and start our own content flush beneath it inside the
//  normal safe area. Only the background gradient bleeds past the
//  safe area so the zone color fills the full face.
//
//    ┌─────────────────────────────────┐
//    │                        10:09 ←   │  (system clock)
//    │                                  │
//    │            58°                   │
//    │       WEATHERLY · TODAY          │
//    │                                  │
//    │     🧥   👕   👖   🌧             │
//    │                                  │
//    │     Light Hoodie + T-shirt…      │
//    └─────────────────────────────────┘
//
//  Tap the big temperature to force a refresh; the previous top
//  source-pill row was removed since it competed with the watch
//  system clock for space.
//

import SwiftUI
import WidgetKit

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchWeatherStore

    var body: some View {
        let payload = store.payload

        ZStack {
            // Zone-colored background fills the entire face, behind
            // the system clock too.
            LinearGradient(
                colors: WatchPalette.background(for: payload.categoryRaw),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 4) {
                Spacer(minLength: 0)

                // Big Weatherly temp — doubles as the tap-to-refresh
                // control so nothing crowds the system clock strip.
                Button {
                    store.manualRefresh()
                } label: {
                    Group {
                        if store.source == .placeholder {
                            Text("—°")
                        } else {
                            Text("\(payload.weatherlyTemp)°")
                        }
                    }
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                }
                .buttonStyle(.plain)

                Text(captionLine(for: payload))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(1)

                Spacer(minLength: 2)

                // Outfit silhouettes — single row, capped at 5.
                HStack(spacing: 6) {
                    ForEach(payload.pieces.prefix(5)) { piece in
                        WatchClothingIcon(
                            symbol: piece.symbol,
                            size: 18,
                            color: WatchRoleTint.color(for: piece.role)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    }
                }

                // Outfit label — 2 lines max, auto-shrinks.
                Text(payload.outfitLabel)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)

                Spacer(minLength: 0)

                if let err = store.lastError {
                    Text(err)
                        .font(.system(size: 8, design: .rounded))
                        .foregroundStyle(.red.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
    }

    /// Second-line caption. When still connecting we say so plainly
    /// here instead of pinning a pill at the top — keeps the top of
    /// the face clean next to the system clock.
    private func captionLine(for payload: WatchWidgetPayload) -> String {
        switch store.source {
        case .placeholder: return "CONNECTING…"
        case .standalone:  return "WEATHERLY · \(payload.dayLabel.uppercased())"
        case .fromPhone:   return "WEATHERLY · \(payload.dayLabel.uppercased())"
        }
    }
}
