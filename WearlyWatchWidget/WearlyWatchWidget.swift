//
//  WearlyWatchWidget.swift
//  WearlyWatchWidgetExtension · watchOS widget extension
//
//  Two watch-face complications:
//
//    • `.accessoryCircular`     — smallest round face slot. Shows the
//                                  Weatherly temp as a big number so
//                                  the user can glance at their wrist
//                                  and know what to dress for.
//
//    • `.accessoryRectangular`  — medium face slot. Shows the same
//                                  outfit silhouettes as the iOS
//                                  medium widget (outer | base | bottom
//                                  + optional rain/winter extras),
//                                  tinted by role, so the user can see
//                                  at a glance what to throw on.
//
//  Both complications read the shared App Group payload that the
//  iPhone app publishes — no independent network / location access.
//
//  `WatchSharedKit.swift` (in this same folder) supplies the payload
//  loader, role tint table, clothing-icon renderer, and garment shapes.
//

import WidgetKit
import SwiftUI

// MARK: - Entry + Provider

struct WatchEntry: TimelineEntry {
    let date: Date
    let payload: WatchWidgetPayload
}

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: .now, payload: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: .now, payload: WatchWidgetPayload.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let payload = WatchWidgetPayload.load() ?? .placeholder
        let entry = WatchEntry(date: .now, payload: payload)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Complication view

struct WearlyWatchWidgetView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:    circularTemp
        case .accessoryRectangular: rectangularOutfit
        case .accessoryInline:      inlineSummary
        default:                    circularTemp
        }
    }

    // MARK: Circular — Weatherly temp

    /// The smallest round complication. The circular slot is tiny —
    /// "WEATHERLY" doesn't fit with any tracking, and the big temp eats
    /// most of the vertical space anyway. So we drop the cap label and
    /// use a short prefix ("W") + degree symbol underneath the number,
    /// which still distinguishes this from Apple's built-in temp
    /// complication while letting the number breathe.
    private var circularTemp: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Text("\(entry.payload.weatherlyTemp)°")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .kerning(-0.5)
                Text("WEARLY")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(2)
        }
    }

    // MARK: Rectangular — visual outfit

    /// Medium rectangular complication. Left: day + big Weatherly temp.
    /// Right: outfit silhouettes drawn in the same role tints as the
    /// iOS widget so the outer / base / bottom / extras read at a glance.
    private var rectangularOutfit: some View {
        let pieces = entry.payload.pieces
        let outer  = pieces.filter { $0.role == "outer" }
        let base   = pieces.filter { $0.role == "base" }
        let bottom = pieces.filter { $0.role == "bottom" }
        let extras = pieces.filter { $0.role == "rain" || $0.role == "winter" || $0.role == "extra" }

        return HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.payload.dayLabel.uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(entry.payload.weatherlyTemp)°")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .kerning(-0.5)
            }
            .frame(width: 54, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 2)

            // Outfit silhouettes — three fixed slots + extras column.
            // Sized to fit the tiny rectangular tile; any empty slot
            // renders an invisible spacer so the grid stays aligned.
            HStack(alignment: .center, spacing: 5) {
                rectSlot(pieces: outer,  size: 20)
                rectSlot(pieces: base,   size: 20)
                rectSlot(pieces: bottom, size: 20)
                if !extras.isEmpty {
                    VStack(spacing: 2) {
                        ForEach(extras.prefix(2)) { p in
                            WatchClothingIcon(
                                symbol: p.symbol,
                                size: 14,
                                color: WatchRoleTint.color(for: p.role)
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func rectSlot(pieces: [WatchWidgetPayload.Piece], size: CGFloat) -> some View {
        if pieces.isEmpty {
            Color.clear.frame(width: size * 1.1, height: size * 1.2)
        } else if let p = pieces.first {
            WatchClothingIcon(
                symbol: p.symbol,
                size: size,
                color: WatchRoleTint.color(for: p.role)
            )
        }
    }

    // MARK: Inline — single-line text fallback

    /// Some faces only host an inline slot. Keep it compact so it reads
    /// on a status line: "58° · Light Hoodie + T-shirt + Sweatpants".
    private var inlineSummary: some View {
        Text("\(entry.payload.weatherlyTemp)° · \(entry.payload.outfitLabel)")
    }
}

// MARK: - Widget configuration

struct WearlyWatchWidget: Widget {
    let kind: String = "WearlyWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            WearlyWatchWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: WatchPalette.background(for: entry.payload.categoryRaw),
                        startPoint: .top, endPoint: .bottom
                    )
                }
        }
        .configurationDisplayName("Wearly")
        .description("Weatherly temp and today's outfit.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Bundle entry

@main
struct WearlyWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WearlyWatchWidget()
    }
}
