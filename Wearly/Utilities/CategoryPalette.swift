//
//  CategoryPalette.swift
//  Wearly
//
//  One source of truth for all the color tinting in the app. Every
//  temperature category gets three shades (primary / bright / deep)
//  plus a two-stop background gradient. There's also a single brand
//  accent used by toggles, sliders, and the Save button so controls
//  feel consistent regardless of the weather.
//
//  Picking colors from here — rather than sprinkling hex literals
//  through views — is what makes the app read as coherent rather than
//  busy.
//

import SwiftUI

enum CategoryPalette {

    // MARK: - Per-category shades

    /// Core tint for icons, figure silhouette, filled badges.
    static func primary(_ c: TempCategory) -> Color {
        switch c {
        case .freezing: return Color(red: 0.62, green: 0.86, blue: 1.00)
        case .cold:     return Color(red: 0.45, green: 0.67, blue: 1.00)
        case .mild:     return Color(red: 0.38, green: 0.85, blue: 0.80)
        case .pleasant: return Color(red: 0.75, green: 0.92, blue: 0.50)
        case .warm:     return Color(red: 1.00, green: 0.72, blue: 0.32)
        case .hot:      return Color(red: 1.00, green: 0.44, blue: 0.38)
        }
    }

    /// Brighter highlight — used for the temperature numeral and selected states.
    static func bright(_ c: TempCategory) -> Color {
        switch c {
        case .freezing: return Color(red: 0.80, green: 0.94, blue: 1.00)
        case .cold:     return Color(red: 0.60, green: 0.82, blue: 1.00)
        case .mild:     return Color(red: 0.54, green: 0.97, blue: 0.90)
        case .pleasant: return Color(red: 0.88, green: 0.99, blue: 0.62)
        case .warm:     return Color(red: 1.00, green: 0.85, blue: 0.48)
        case .hot:      return Color(red: 1.00, green: 0.58, blue: 0.50)
        }
    }

    /// Darker shade for vignettes and shadowed overlays.
    static func deep(_ c: TempCategory) -> Color {
        switch c {
        case .freezing: return Color(red: 0.06, green: 0.14, blue: 0.28)
        case .cold:     return Color(red: 0.06, green: 0.18, blue: 0.42)
        case .mild:     return Color(red: 0.04, green: 0.26, blue: 0.30)
        case .pleasant: return Color(red: 0.12, green: 0.28, blue: 0.16)
        case .warm:     return Color(red: 0.34, green: 0.18, blue: 0.10)
        case .hot:      return Color(red: 0.40, green: 0.10, blue: 0.12)
        }
    }

    /// Two-stop gradient colors for the main screen background.
    /// Kept dark at the top-left for legibility of the hero text, and
    /// saturated in the bottom-right so the weather has presence.
    static func backgroundPair(_ c: TempCategory) -> [Color] {
        // Deep near-black top, muted category-tinted bottom. The goal is
        // atmospheric mood — temperature as *tint*, not as billboard.
        switch c {
        case .freezing:
            return [
                Color(red: 0.04, green: 0.07, blue: 0.14),
                Color(red: 0.16, green: 0.32, blue: 0.52)
            ]
        case .cold:
            return [
                Color(red: 0.05, green: 0.09, blue: 0.18),
                Color(red: 0.18, green: 0.34, blue: 0.58)
            ]
        case .mild:
            return [
                Color(red: 0.05, green: 0.12, blue: 0.18),
                Color(red: 0.20, green: 0.42, blue: 0.42)
            ]
        case .pleasant:
            return [
                Color(red: 0.06, green: 0.14, blue: 0.14),
                Color(red: 0.32, green: 0.50, blue: 0.30)
            ]
        case .warm:
            return [
                Color(red: 0.14, green: 0.08, blue: 0.12),
                Color(red: 0.66, green: 0.42, blue: 0.22)
            ]
        case .hot:
            return [
                Color(red: 0.18, green: 0.06, blue: 0.10),
                Color(red: 0.74, green: 0.32, blue: 0.22)
            ]
        }
    }

    // MARK: - Brand accent

    /// Single warm-coral tint reused by all neutral controls (toggles,
    /// slider fill, Save button). Doesn't shift with temperature — this
    /// is Wearly's identity color.
    static let brand = Color(red: 1.00, green: 0.52, blue: 0.58)

    static let brandBright = Color(red: 1.00, green: 0.68, blue: 0.72)
}
