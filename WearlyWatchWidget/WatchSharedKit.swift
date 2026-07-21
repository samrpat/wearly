//
//  WatchSharedKit.swift
//  WearlyWatch · WearlyWatchWidget
//
//  Types and helpers shared between the watch app and the watch widget
//  extension. Mirrors the same data flow as the iOS widget: the iPhone
//  main app publishes a JSON payload into the App Group container, and
//  both the watch app and its complications read from there — no
//  network, no location, no fetch on the watch side.
//
//  HOW TO USE
//    • Add this file to BOTH the WearlyWatch and WearlyWatchWidget
//      targets (Target Membership in the File Inspector).
//    • Make sure both targets enable the `group.com.wearly.shared`
//      App Group in Signing & Capabilities.
//

import SwiftUI

// MARK: - App Group

enum WatchAppGroup {
    static let identifier = "group.com.wearly.shared"
    static let stateKey   = "wearly.widgetState"
}

// MARK: - Payload shape written by the main iPhone app

struct WatchWidgetPayload {
    let weatherlyTemp: Int
    let categoryRaw: String
    let conditionSymbol: String
    let outfitSymbols: [String]
    let outfitNames: [String]
    let outfitRoles: [String]
    let outfitLabel: String
    let dayLabel: String

    struct Piece: Identifiable {
        let id = UUID()
        let symbol: String
        let name: String
        let role: String
    }

    var pieces: [Piece] {
        outfitSymbols.enumerated().map { i, sym in
            Piece(
                symbol: sym,
                name: outfitNames.indices.contains(i) ? outfitNames[i] : "",
                role: outfitRoles.indices.contains(i) ? outfitRoles[i] : "extra"
            )
        }
    }

    static let placeholder = WatchWidgetPayload(
        weatherlyTemp: 58,
        categoryRaw: "pleasant",
        conditionSymbol: "cloud",
        outfitSymbols: ["wearly.hoodie.fill", "wearly.tshirt.fill", "wearly.sweatpants.fill"],
        outfitNames: ["Light Hoodie", "T-shirt", "Sweatpants"],
        outfitRoles: ["outer", "base", "bottom"],
        outfitLabel: "Light Hoodie + T-shirt + Sweatpants",
        dayLabel: "Today"
    )

    static func load() -> WatchWidgetPayload? {
        guard let defaults = UserDefaults(suiteName: WatchAppGroup.identifier),
              let data = defaults.data(forKey: WatchAppGroup.stateKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return WatchWidgetPayload(
            weatherlyTemp:   json["weatherlyTemp"]   as? Int    ?? 0,
            categoryRaw:     json["categoryRaw"]     as? String ?? "mild",
            conditionSymbol: json["conditionSymbol"] as? String ?? "cloud",
            outfitSymbols:   json["outfitSymbols"]   as? [String] ?? [],
            outfitNames:     json["outfitNames"]     as? [String] ?? [],
            outfitRoles:     json["outfitRoles"]     as? [String] ?? [],
            outfitLabel:     json["outfitLabel"]     as? String ?? "",
            dayLabel:        json["dayLabel"]        as? String ?? "Today"
        )
    }
}

// MARK: - Palette for container backgrounds

enum WatchPalette {
    /// Zone-colored gradient so the rectangular complication and the
    /// app screen reflect the current temperature category at a glance.
    /// The watch widget's tint environment can override these in some
    /// faces, so we also rely on role-tinted icons for differentiation.
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

// MARK: - Role tints (mirror of the iOS widget / main card)

enum WatchRoleTint {
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

// MARK: - Clothing icon renderer

/// Same dispatch logic the iOS widget uses — `wearly.*` symbols render
/// as custom silhouettes, anything else falls back to SF Symbols via
/// `Image(systemName:)`. Hierarchical rendering mode keeps SF Symbols
/// legible against the watch's hierarchical complication tinting.
struct WatchClothingIcon: View {
    let symbol: String
    let size: CGFloat
    let color: Color

    var body: some View {
        Group {
            switch symbol {
            case "wearly.tshirt", "wearly.tshirt.fill":
                WatchTShirtShape().fill(color)
                    .frame(width: size * 1.05, height: size * 1.15)
            case "wearly.longsleeve", "wearly.longsleeve.fill":
                WatchLongSleeveShape().fill(color)
                    .frame(width: size * 1.10, height: size * 1.15)
            case "wearly.hoodie", "wearly.hoodie.fill":
                WatchHoodieShape().fill(color)
                    .frame(width: size * 1.10, height: size * 1.20)
            case "wearly.sweatpants", "wearly.sweatpants.fill":
                WatchSweatpantsShape().fill(color)
                    .frame(width: size * 0.95, height: size * 1.20)
            case "wearly.shorts", "wearly.shorts.fill":
                WatchShortsShape().fill(color)
                    .frame(width: size * 0.95, height: size * 0.85)
            case "wearly.rainjacket", "wearly.rainjacket.fill":
                WatchRainJacketShape().fill(color)
                    .frame(width: size * 1.10, height: size * 1.30)
            case "wearly.winterjacket", "wearly.winterjacket.fill":
                WatchWinterJacketShape().fill(color)
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

// MARK: - Garment silhouettes
//
// Duplicated from the main app / iOS widget so the watch targets are
// self-contained and don't need cross-target file membership for the
// shape definitions. Prefix `Watch` to avoid collisions if the watch
// targets ever gain access to the main-app shapes.

private func wpt(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
}

struct WatchTShirtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: wpt(rect, 0.40, 0.20))
        p.addQuadCurve(to: wpt(rect, 0.60, 0.20), control: wpt(rect, 0.50, 0.32))
        p.addQuadCurve(to: wpt(rect, 0.74, 0.19), control: wpt(rect, 0.68, 0.18))
        p.addQuadCurve(to: wpt(rect, 0.94, 0.30), control: wpt(rect, 0.86, 0.22))
        p.addQuadCurve(to: wpt(rect, 0.78, 0.40), control: wpt(rect, 0.94, 0.40))
        p.addQuadCurve(to: wpt(rect, 0.74, 0.36), control: wpt(rect, 0.75, 0.38))
        p.addLine(to: wpt(rect, 0.72, 0.94))
        p.addLine(to: wpt(rect, 0.28, 0.94))
        p.addLine(to: wpt(rect, 0.26, 0.36))
        p.addQuadCurve(to: wpt(rect, 0.22, 0.40), control: wpt(rect, 0.25, 0.38))
        p.addQuadCurve(to: wpt(rect, 0.06, 0.30), control: wpt(rect, 0.06, 0.40))
        p.addQuadCurve(to: wpt(rect, 0.26, 0.19), control: wpt(rect, 0.14, 0.22))
        p.addQuadCurve(to: wpt(rect, 0.40, 0.20), control: wpt(rect, 0.32, 0.18))
        p.closeSubpath()
        return p
    }
}

struct WatchLongSleeveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: wpt(rect, 0.40, 0.20))
        p.addQuadCurve(to: wpt(rect, 0.60, 0.20), control: wpt(rect, 0.50, 0.32))
        p.addQuadCurve(to: wpt(rect, 0.74, 0.18), control: wpt(rect, 0.68, 0.18))
        p.addQuadCurve(to: wpt(rect, 0.94, 0.24), control: wpt(rect, 0.86, 0.20))
        p.addLine(to: wpt(rect, 0.92, 0.84))
        p.addQuadCurve(to: wpt(rect, 0.76, 0.90), control: wpt(rect, 0.94, 0.92))
        p.addLine(to: wpt(rect, 0.74, 0.38))
        p.addLine(to: wpt(rect, 0.72, 0.95))
        p.addLine(to: wpt(rect, 0.28, 0.95))
        p.addLine(to: wpt(rect, 0.26, 0.38))
        p.addLine(to: wpt(rect, 0.24, 0.90))
        p.addQuadCurve(to: wpt(rect, 0.08, 0.84), control: wpt(rect, 0.06, 0.92))
        p.addLine(to: wpt(rect, 0.06, 0.24))
        p.addQuadCurve(to: wpt(rect, 0.26, 0.18), control: wpt(rect, 0.14, 0.20))
        p.addQuadCurve(to: wpt(rect, 0.40, 0.20), control: wpt(rect, 0.32, 0.18))
        p.closeSubpath()
        return p
    }
}

struct WatchHoodieShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: wpt(rect, 0.04, 0.30))
        p.addLine(to: wpt(rect, 0.28, 0.28))
        p.addQuadCurve(to: wpt(rect, 0.36, 0.22), control: wpt(rect, 0.32, 0.26))
        p.addQuadCurve(to: wpt(rect, 0.50, 0.05), control: wpt(rect, 0.28, 0.06))
        p.addQuadCurve(to: wpt(rect, 0.64, 0.22), control: wpt(rect, 0.72, 0.06))
        p.addQuadCurve(to: wpt(rect, 0.72, 0.28), control: wpt(rect, 0.68, 0.26))
        p.addLine(to: wpt(rect, 0.96, 0.30))
        p.addLine(to: wpt(rect, 0.94, 0.84))
        p.addQuadCurve(to: wpt(rect, 0.76, 0.90), control: wpt(rect, 0.96, 0.92))
        p.addLine(to: wpt(rect, 0.74, 0.42))
        p.addLine(to: wpt(rect, 0.72, 0.95))
        p.addLine(to: wpt(rect, 0.28, 0.95))
        p.addLine(to: wpt(rect, 0.26, 0.42))
        p.addLine(to: wpt(rect, 0.24, 0.90))
        p.addQuadCurve(to: wpt(rect, 0.06, 0.84), control: wpt(rect, 0.04, 0.92))
        p.closeSubpath()
        return p
    }
}

struct WatchSweatpantsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: wpt(rect, 0.14, 0.04))
        p.addLine(to: wpt(rect, 0.86, 0.04))
        p.addLine(to: wpt(rect, 0.90, 0.88))
        p.addQuadCurve(to: wpt(rect, 0.66, 0.95), control: wpt(rect, 0.92, 0.96))
        p.addQuadCurve(to: wpt(rect, 0.54, 0.28), control: wpt(rect, 0.62, 0.62))
        p.addQuadCurve(to: wpt(rect, 0.46, 0.28), control: wpt(rect, 0.50, 0.22))
        p.addQuadCurve(to: wpt(rect, 0.34, 0.95), control: wpt(rect, 0.38, 0.62))
        p.addQuadCurve(to: wpt(rect, 0.10, 0.88), control: wpt(rect, 0.08, 0.96))
        p.closeSubpath()
        return p
    }
}

struct WatchShortsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: wpt(rect, 0.14, 0.18))
        p.addLine(to: wpt(rect, 0.86, 0.18))
        p.addQuadCurve(to: wpt(rect, 0.93, 0.70), control: wpt(rect, 0.94, 0.52))
        p.addQuadCurve(to: wpt(rect, 0.64, 0.74), control: wpt(rect, 0.78, 0.78))
        p.addQuadCurve(to: wpt(rect, 0.54, 0.40), control: wpt(rect, 0.60, 0.56))
        p.addQuadCurve(to: wpt(rect, 0.46, 0.40), control: wpt(rect, 0.50, 0.32))
        p.addQuadCurve(to: wpt(rect, 0.36, 0.74), control: wpt(rect, 0.40, 0.56))
        p.addQuadCurve(to: wpt(rect, 0.07, 0.70), control: wpt(rect, 0.22, 0.78))
        p.closeSubpath()
        return p
    }
}

struct WatchRainJacketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: wpt(rect, 0.06, 0.30))
        p.addLine(to: wpt(rect, 0.26, 0.26))
        p.addQuadCurve(to: wpt(rect, 0.36, 0.20), control: wpt(rect, 0.32, 0.24))
        p.addQuadCurve(to: wpt(rect, 0.50, 0.04), control: wpt(rect, 0.26, 0.04))
        p.addQuadCurve(to: wpt(rect, 0.64, 0.20), control: wpt(rect, 0.74, 0.04))
        p.addQuadCurve(to: wpt(rect, 0.74, 0.26), control: wpt(rect, 0.68, 0.24))
        p.addLine(to: wpt(rect, 0.94, 0.30))
        p.addLine(to: wpt(rect, 0.92, 0.82))
        p.addQuadCurve(to: wpt(rect, 0.76, 0.88), control: wpt(rect, 0.94, 0.90))
        p.addLine(to: wpt(rect, 0.74, 0.46))
        p.addQuadCurve(to: wpt(rect, 0.73, 0.98), control: wpt(rect, 0.76, 0.76))
        p.addLine(to: wpt(rect, 0.27, 0.98))
        p.addQuadCurve(to: wpt(rect, 0.26, 0.46), control: wpt(rect, 0.24, 0.76))
        p.addLine(to: wpt(rect, 0.24, 0.88))
        p.addQuadCurve(to: wpt(rect, 0.08, 0.82), control: wpt(rect, 0.06, 0.90))
        p.closeSubpath()
        return p
    }
}

struct WatchWinterJacketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: wpt(rect, 0.02, 0.32))
        p.addQuadCurve(to: wpt(rect, 0.22, 0.24), control: wpt(rect, 0.08, 0.26))
        p.addQuadCurve(to: wpt(rect, 0.38, 0.22), control: wpt(rect, 0.30, 0.18))
        p.addQuadCurve(to: wpt(rect, 0.50, 0.18), control: wpt(rect, 0.44, 0.28))
        p.addQuadCurve(to: wpt(rect, 0.62, 0.22), control: wpt(rect, 0.56, 0.28))
        p.addQuadCurve(to: wpt(rect, 0.78, 0.24), control: wpt(rect, 0.70, 0.18))
        p.addQuadCurve(to: wpt(rect, 0.98, 0.32), control: wpt(rect, 0.92, 0.26))
        p.addQuadCurve(to: wpt(rect, 0.94, 0.84), control: wpt(rect, 1.00, 0.58))
        p.addQuadCurve(to: wpt(rect, 0.76, 0.90), control: wpt(rect, 0.95, 0.94))
        p.addLine(to: wpt(rect, 0.74, 0.46))
        p.addQuadCurve(to: wpt(rect, 0.76, 0.96), control: wpt(rect, 0.82, 0.72))
        p.addLine(to: wpt(rect, 0.24, 0.96))
        p.addQuadCurve(to: wpt(rect, 0.26, 0.46), control: wpt(rect, 0.18, 0.72))
        p.addLine(to: wpt(rect, 0.24, 0.90))
        p.addQuadCurve(to: wpt(rect, 0.06, 0.84), control: wpt(rect, 0.00, 0.94))
        p.closeSubpath()
        return p
    }
}
