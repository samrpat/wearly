//
//  WearlyWidget.swift
//  WearlyWidget
//
//  Home-screen widget that renders today's **Weatherly** — the single
//  dressing temperature the main app's DaypartAnalyzer targets — plus
//  a miniature mannequin showing the recommended outfit.
//
//  Reads a snapshot written by the main app into the shared App Group
//  container. No network or location access happens here.
//
//  SETUP
//    • App Group `group.com.wearly.shared` must be enabled on BOTH
//      the Wearly target and this WearlyWidgetExtension target
//      (Signing & Capabilities).
//    • Build & run Wearly once so it publishes state.
//

import WidgetKit
import SwiftUI

// MARK: - App Group

private enum WidgetAppGroup {
    static let identifier = "group.com.wearly.shared"
    static let stateKey   = "wearly.widgetState"
}

// MARK: - Payload shape written by the main app

struct WidgetPayload {
    let weatherlyTemp: Int
    let categoryRaw: String
    let conditionSymbol: String
    let outfitSymbols: [String]
    let outfitNames: [String]
    let outfitRoles: [String]
    let outfitLabel: String
    let dayLabel: String

    /// One displayable garment — symbol art + item name + role tint.
    struct Piece: Identifiable {
        let id = UUID()
        let symbol: String
        let name: String
        let role: String
    }

    /// Zips the three parallel arrays into one list the widget can
    /// iterate. Falls back gracefully if the main app wrote a shorter
    /// names / roles array (older build).
    var pieces: [Piece] {
        outfitSymbols.enumerated().map { i, sym in
            Piece(
                symbol: sym,
                name: outfitNames.indices.contains(i) ? outfitNames[i] : "",
                role: outfitRoles.indices.contains(i) ? outfitRoles[i] : "extra"
            )
        }
    }

    static let placeholder = WidgetPayload(
        weatherlyTemp: 58,
        categoryRaw: "pleasant",
        conditionSymbol: "cloud",
        outfitSymbols: ["wearly.hoodie.fill", "wearly.tshirt.fill", "wearly.sweatpants.fill"],
        outfitNames: ["Light Hoodie", "T-shirt", "Sweatpants"],
        outfitRoles: ["outer", "base", "bottom"],
        outfitLabel: "Light Hoodie + T-shirt + Sweatpants",
        dayLabel: "Today"
    )

    static func load() -> WidgetPayload? {
        guard let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier),
              let data = defaults.data(forKey: WidgetAppGroup.stateKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return WidgetPayload(
            weatherlyTemp: json["weatherlyTemp"] as? Int ?? 0,
            categoryRaw: json["categoryRaw"] as? String ?? "mild",
            conditionSymbol: json["conditionSymbol"] as? String ?? "cloud",
            outfitSymbols: json["outfitSymbols"] as? [String] ?? [],
            outfitNames:   json["outfitNames"]   as? [String] ?? [],
            outfitRoles:   json["outfitRoles"]   as? [String] ?? [],
            outfitLabel: json["outfitLabel"] as? String ?? "",
            dayLabel: json["dayLabel"] as? String ?? "Today"
        )
    }
}

// MARK: - Entry + Provider

struct WearlyEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
}

struct WearlyProvider: TimelineProvider {
    func placeholder(in context: Context) -> WearlyEntry {
        WearlyEntry(date: .now, payload: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WearlyEntry) -> Void) {
        let payload = WidgetPayload.load() ?? .placeholder
        completion(WearlyEntry(date: .now, payload: payload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WearlyEntry>) -> Void) {
        let payload = WidgetPayload.load() ?? .placeholder
        let entry = WearlyEntry(date: .now, payload: payload)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Palette

private enum WidgetPalette {
    /// Vivid, clearly-distinct gradient per zone so the widget tile
    /// reads as the current temperature category at a glance. Top stop
    /// is the saturated zone color; bottom stop is a deeper shade of
    /// the same hue so white text stays legible.
    static func background(for categoryRaw: String) -> [Color] {
        switch categoryRaw {
        case "freezing":
            return [Color(red: 0.56, green: 0.80, blue: 1.00),
                    Color(red: 0.14, green: 0.32, blue: 0.58)]
        case "cold":
            return [Color(red: 0.35, green: 0.58, blue: 1.00),
                    Color(red: 0.10, green: 0.24, blue: 0.58)]
        case "mild":
            return [Color(red: 0.32, green: 0.82, blue: 0.75),
                    Color(red: 0.06, green: 0.32, blue: 0.40)]
        case "pleasant":
            return [Color(red: 0.72, green: 0.90, blue: 0.42),
                    Color(red: 0.18, green: 0.38, blue: 0.14)]
        case "warm":
            return [Color(red: 1.00, green: 0.72, blue: 0.32),
                    Color(red: 0.52, green: 0.22, blue: 0.08)]
        case "hot":
            return [Color(red: 1.00, green: 0.44, blue: 0.38),
                    Color(red: 0.48, green: 0.08, blue: 0.10)]
        default:
            return [Color.gray, Color.gray.opacity(0.85)]
        }
    }
}

// MARK: - Role tints (mirror of GarmentTint in OutfitCardView.swift)

private enum WidgetRoleTint {
    static func color(for role: String) -> Color {
        switch role {
        case "outer":  return Color(red: 0.98, green: 0.64, blue: 0.48)
        case "base":   return Color(red: 0.96, green: 0.96, blue: 0.99)
        case "bottom": return Color(red: 0.70, green: 0.80, blue: 0.96)
        case "rain":   return Color(red: 0.55, green: 0.72, blue: 1.00)
        case "winter": return Color(red: 0.92, green: 0.96, blue: 1.00)
        default:       return .white.opacity(0.95)
        }
    }
}

// MARK: - Clothing icon renderer (no person silhouettes)

private struct WidgetClothingIcon: View {
    let symbol: String
    let size: CGFloat
    let color: Color

    var body: some View {
        Group {
            switch symbol {
            case "wearly.tshirt", "wearly.tshirt.fill":
                TShirtShape().fill(color)
                    .frame(width: size * 1.05, height: size * 1.15)
            case "wearly.longsleeve", "wearly.longsleeve.fill":
                LongSleeveShape().fill(color)
                    .frame(width: size * 1.10, height: size * 1.15)
            case "wearly.hoodie", "wearly.hoodie.fill":
                HoodieShape().fill(color)
                    .frame(width: size * 1.10, height: size * 1.20)
            case "wearly.sweatpants", "wearly.sweatpants.fill":
                SweatpantsShape().fill(color)
                    .frame(width: size * 0.95, height: size * 1.20)
            case "wearly.shorts", "wearly.shorts.fill":
                ShortsShape().fill(color)
                    .frame(width: size * 0.95, height: size * 0.85)
            case "wearly.rainjacket", "wearly.rainjacket.fill":
                RainJacketShape().fill(color)
                    .frame(width: size * 1.10, height: size * 1.30)
            case "wearly.winterjacket", "wearly.winterjacket.fill":
                WinterJacketShape().fill(color)
                    .frame(width: size * 1.20, height: size * 1.15)
            default:
                Image(systemName: symbol)
                    .font(.system(size: size, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
            }
        }
    }
}

// MARK: - Widget view

struct WearlyWidgetView: View {
    let entry: WearlyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  smallLayout
        case .systemMedium: mediumLayout
        default:            smallLayout
        }
    }

    // Small: WEATHERLY cap label, big temp, tiny outfit row at the bottom.
    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: entry.payload.conditionSymbol)
                    .font(.system(size: 13, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                Text(entry.payload.dayLabel)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
            }

            Spacer(minLength: 2)

            Text("WEATHERLY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.80))
                .tracking(1.6)

            Text("\(entry.payload.weatherlyTemp)°")
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .kerning(-1)

            Spacer(minLength: 2)

            HStack(spacing: 10) {
                ForEach(Array(entry.payload.pieces.prefix(3))) { piece in
                    WidgetClothingIcon(
                        symbol: piece.symbol,
                        size: 20,
                        color: WidgetRoleTint.color(for: piece.role)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                }
            }
        }
        .padding(14)
        .foregroundStyle(.white)
    }

    // Medium: info on the left, three fixed slots on the right —
    //   OUTER (left)  |  BASE TOP (middle)  |  BOTTOM (right)
    // Rain / winter jacket extras, if any, render as small icons tucked
    // on the far right so the three main slots stay anchored.
    private var mediumLayout: some View {
        let pieces = entry.payload.pieces
        let outer  = pieces.filter { $0.role == "outer" }
        let base   = pieces.filter { $0.role == "base" }
        let bottom = pieces.filter { $0.role == "bottom" }
        let extras = pieces.filter { $0.role == "rain" || $0.role == "winter" || $0.role == "extra" }

        return HStack(alignment: .center, spacing: 10) {
            // Info column — pinned width + layout priority so the right-
            // hand icons can't clip "Today", the big temp, or WEATHERLY.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: entry.payload.conditionSymbol)
                        .font(.system(size: 13, weight: .light))
                        .symbolRenderingMode(.hierarchical)
                    Text(entry.payload.dayLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Text("\(entry.payload.weatherlyTemp)°")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .kerning(-1)
                    .fixedSize(horizontal: true, vertical: false)

                Text("WEATHERLY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.80))
                    .tracking(1.6)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 0)
            }
            .frame(width: 108, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 4)

            // Three fixed slots — icons scaled to fill the empty space,
            // no captions. Extras column for rain/winter jacket.
            let mainSize = mediumIconSize(
                outer: outer, base: base, bottom: bottom, hasExtras: !extras.isEmpty
            )
            HStack(alignment: .center, spacing: 12) {
                slotColumn(pieces: outer,  size: mainSize)
                slotColumn(pieces: base,   size: mainSize)
                slotColumn(pieces: bottom, size: mainSize)
            }

            if !extras.isEmpty {
                VStack(spacing: 6) {
                    ForEach(extras) { piece in
                        WidgetClothingIcon(
                            symbol: piece.symbol,
                            size: mainSize * 0.82,
                            color: WidgetRoleTint.color(for: piece.role)
                        )
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                    }
                }
            }
        }
        .padding(14)
    }

    /// Picks the main icon size for the medium layout so the garments
    /// fill the empty space on the right while staying within the
    /// reserved 108pt info column on the left.
    private func mediumIconSize(
        outer: [WidgetPayload.Piece],
        base: [WidgetPayload.Piece],
        bottom: [WidgetPayload.Piece],
        hasExtras: Bool
    ) -> CGFloat {
        let filledSlots = [outer, base, bottom].filter { !$0.isEmpty }.count
        switch (filledSlots, hasExtras) {
        case (3, true):   return 32
        case (3, false):  return 38
        case (2, true):   return 38
        case (2, false):  return 44
        case (1, true):   return 42
        default:          return 48
        }
    }

    /// A single outfit slot — no caption, just the silhouette centered
    /// in its column. Empty slots render an invisible spacer of the
    /// same footprint so the three main columns stay aligned.
    @ViewBuilder
    private func slotColumn(pieces: [WidgetPayload.Piece], size: CGFloat) -> some View {
        if pieces.isEmpty {
            Color.clear.frame(width: size * 1.2, height: size * 1.3)
        } else {
            VStack(spacing: 2) {
                ForEach(pieces) { piece in
                    WidgetClothingIcon(
                        symbol: piece.symbol,
                        size: size,
                        color: WidgetRoleTint.color(for: piece.role)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
                }
            }
        }
    }
}

// MARK: - Widget configuration

struct WearlyWidget: Widget {
    let kind: String = "WearlyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WearlyProvider()) { entry in
            if #available(iOS 17.0, *) {
                WearlyWidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: WidgetPalette.background(for: entry.payload.categoryRaw),
                            startPoint: .top, endPoint: .bottom
                        )
                    }
            } else {
                WearlyWidgetView(entry: entry)
                    .background(
                        LinearGradient(
                            colors: WidgetPalette.background(for: entry.payload.categoryRaw),
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
        }
        .configurationDisplayName("Wearly")
        .description("Today's Weatherly temp and outfit.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget bundle entry

@main
struct WearlyWidgetBundle: WidgetBundle {
    var body: some Widget {
        WearlyWidget()
    }
}

// MARK: - Garment silhouettes
//
// Duplicated from the main app's `CustomClothingIcons.swift` so the
// widget target doesn't need cross-target file membership.

private func pt(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
}

struct TShirtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.40, 0.20))
        p.addQuadCurve(to: pt(rect, 0.60, 0.20), control: pt(rect, 0.50, 0.32))
        p.addQuadCurve(to: pt(rect, 0.74, 0.19), control: pt(rect, 0.68, 0.18))
        p.addQuadCurve(to: pt(rect, 0.94, 0.30), control: pt(rect, 0.86, 0.22))
        p.addQuadCurve(to: pt(rect, 0.78, 0.40), control: pt(rect, 0.94, 0.40))
        p.addQuadCurve(to: pt(rect, 0.74, 0.36), control: pt(rect, 0.75, 0.38))
        p.addLine(to: pt(rect, 0.72, 0.94))
        p.addLine(to: pt(rect, 0.28, 0.94))
        p.addLine(to: pt(rect, 0.26, 0.36))
        p.addQuadCurve(to: pt(rect, 0.22, 0.40), control: pt(rect, 0.25, 0.38))
        p.addQuadCurve(to: pt(rect, 0.06, 0.30), control: pt(rect, 0.06, 0.40))
        p.addQuadCurve(to: pt(rect, 0.26, 0.19), control: pt(rect, 0.14, 0.22))
        p.addQuadCurve(to: pt(rect, 0.40, 0.20), control: pt(rect, 0.32, 0.18))
        p.closeSubpath()
        return p
    }
}

struct LongSleeveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.40, 0.20))
        p.addQuadCurve(to: pt(rect, 0.60, 0.20), control: pt(rect, 0.50, 0.32))
        p.addQuadCurve(to: pt(rect, 0.74, 0.18), control: pt(rect, 0.68, 0.18))
        p.addQuadCurve(to: pt(rect, 0.94, 0.24), control: pt(rect, 0.86, 0.20))
        p.addLine(to: pt(rect, 0.92, 0.84))
        p.addQuadCurve(to: pt(rect, 0.76, 0.90), control: pt(rect, 0.94, 0.92))
        p.addLine(to: pt(rect, 0.74, 0.38))
        p.addLine(to: pt(rect, 0.72, 0.95))
        p.addLine(to: pt(rect, 0.28, 0.95))
        p.addLine(to: pt(rect, 0.26, 0.38))
        p.addLine(to: pt(rect, 0.24, 0.90))
        p.addQuadCurve(to: pt(rect, 0.08, 0.84), control: pt(rect, 0.06, 0.92))
        p.addLine(to: pt(rect, 0.06, 0.24))
        p.addQuadCurve(to: pt(rect, 0.26, 0.18), control: pt(rect, 0.14, 0.20))
        p.addQuadCurve(to: pt(rect, 0.40, 0.20), control: pt(rect, 0.32, 0.18))
        p.closeSubpath()
        return p
    }
}

struct HoodieShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.04, 0.30))
        p.addLine(to: pt(rect, 0.28, 0.28))
        p.addQuadCurve(to: pt(rect, 0.36, 0.22), control: pt(rect, 0.32, 0.26))
        p.addQuadCurve(to: pt(rect, 0.50, 0.05), control: pt(rect, 0.28, 0.06))
        p.addQuadCurve(to: pt(rect, 0.64, 0.22), control: pt(rect, 0.72, 0.06))
        p.addQuadCurve(to: pt(rect, 0.72, 0.28), control: pt(rect, 0.68, 0.26))
        p.addLine(to: pt(rect, 0.96, 0.30))
        p.addLine(to: pt(rect, 0.94, 0.84))
        p.addQuadCurve(to: pt(rect, 0.76, 0.90), control: pt(rect, 0.96, 0.92))
        p.addLine(to: pt(rect, 0.74, 0.42))
        p.addLine(to: pt(rect, 0.72, 0.95))
        p.addLine(to: pt(rect, 0.28, 0.95))
        p.addLine(to: pt(rect, 0.26, 0.42))
        p.addLine(to: pt(rect, 0.24, 0.90))
        p.addQuadCurve(to: pt(rect, 0.06, 0.84), control: pt(rect, 0.04, 0.92))
        p.closeSubpath()
        return p
    }
}

struct SweatpantsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.14, 0.04))
        p.addLine(to: pt(rect, 0.86, 0.04))
        p.addLine(to: pt(rect, 0.90, 0.88))
        p.addQuadCurve(to: pt(rect, 0.66, 0.95), control: pt(rect, 0.92, 0.96))
        p.addQuadCurve(to: pt(rect, 0.54, 0.28), control: pt(rect, 0.62, 0.62))
        p.addQuadCurve(to: pt(rect, 0.46, 0.28), control: pt(rect, 0.50, 0.22))
        p.addQuadCurve(to: pt(rect, 0.34, 0.95), control: pt(rect, 0.38, 0.62))
        p.addQuadCurve(to: pt(rect, 0.10, 0.88), control: pt(rect, 0.08, 0.96))
        p.closeSubpath()
        return p
    }
}

struct ShortsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.14, 0.18))
        p.addLine(to: pt(rect, 0.86, 0.18))
        p.addQuadCurve(to: pt(rect, 0.93, 0.70), control: pt(rect, 0.94, 0.52))
        p.addQuadCurve(to: pt(rect, 0.64, 0.74), control: pt(rect, 0.78, 0.78))
        p.addQuadCurve(to: pt(rect, 0.54, 0.40), control: pt(rect, 0.60, 0.56))
        p.addQuadCurve(to: pt(rect, 0.46, 0.40), control: pt(rect, 0.50, 0.32))
        p.addQuadCurve(to: pt(rect, 0.36, 0.74), control: pt(rect, 0.40, 0.56))
        p.addQuadCurve(to: pt(rect, 0.07, 0.70), control: pt(rect, 0.22, 0.78))
        p.closeSubpath()
        return p
    }
}

struct RainJacketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.06, 0.30))
        p.addLine(to: pt(rect, 0.26, 0.26))
        p.addQuadCurve(to: pt(rect, 0.36, 0.20), control: pt(rect, 0.32, 0.24))
        p.addQuadCurve(to: pt(rect, 0.50, 0.04), control: pt(rect, 0.26, 0.04))
        p.addQuadCurve(to: pt(rect, 0.64, 0.20), control: pt(rect, 0.74, 0.04))
        p.addQuadCurve(to: pt(rect, 0.74, 0.26), control: pt(rect, 0.68, 0.24))
        p.addLine(to: pt(rect, 0.94, 0.30))
        p.addLine(to: pt(rect, 0.92, 0.82))
        p.addQuadCurve(to: pt(rect, 0.76, 0.88), control: pt(rect, 0.94, 0.90))
        p.addLine(to: pt(rect, 0.74, 0.46))
        p.addQuadCurve(to: pt(rect, 0.73, 0.98), control: pt(rect, 0.76, 0.76))
        p.addLine(to: pt(rect, 0.27, 0.98))
        p.addQuadCurve(to: pt(rect, 0.26, 0.46), control: pt(rect, 0.24, 0.76))
        p.addLine(to: pt(rect, 0.24, 0.88))
        p.addQuadCurve(to: pt(rect, 0.08, 0.82), control: pt(rect, 0.06, 0.90))
        p.closeSubpath()
        return p
    }
}

struct WinterJacketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.02, 0.32))
        p.addQuadCurve(to: pt(rect, 0.22, 0.24), control: pt(rect, 0.08, 0.26))
        p.addQuadCurve(to: pt(rect, 0.38, 0.22), control: pt(rect, 0.30, 0.18))
        p.addQuadCurve(to: pt(rect, 0.50, 0.18), control: pt(rect, 0.44, 0.28))
        p.addQuadCurve(to: pt(rect, 0.62, 0.22), control: pt(rect, 0.56, 0.28))
        p.addQuadCurve(to: pt(rect, 0.78, 0.24), control: pt(rect, 0.70, 0.18))
        p.addQuadCurve(to: pt(rect, 0.98, 0.32), control: pt(rect, 0.92, 0.26))
        p.addQuadCurve(to: pt(rect, 0.94, 0.84), control: pt(rect, 1.00, 0.58))
        p.addQuadCurve(to: pt(rect, 0.76, 0.90), control: pt(rect, 0.95, 0.94))
        p.addLine(to: pt(rect, 0.74, 0.46))
        p.addQuadCurve(to: pt(rect, 0.76, 0.96), control: pt(rect, 0.82, 0.72))
        p.addLine(to: pt(rect, 0.24, 0.96))
        p.addQuadCurve(to: pt(rect, 0.26, 0.46), control: pt(rect, 0.18, 0.72))
        p.addLine(to: pt(rect, 0.24, 0.90))
        p.addQuadCurve(to: pt(rect, 0.06, 0.84), control: pt(rect, 0.00, 0.94))
        p.closeSubpath()
        return p
    }
}
