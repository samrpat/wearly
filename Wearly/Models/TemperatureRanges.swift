//
//  TemperatureRanges.swift
//  Wearly
//
//  User-tunable temperature thresholds. Six named zones cover the
//  full Fahrenheit range from "Freezing" to "Hot" with a Pleasant
//  zone sitting between Mild and Warm.
//

import Foundation

struct TemperatureRanges: Codable, Equatable {
    /// Below this value → Freezing.
    var freezingMax: Double
    /// Below this value (and ≥ freezingMax) → Cold.
    var coldMax: Double
    /// Below this value (and ≥ coldMax) → Mild.
    var mildMax: Double
    /// Below this value (and ≥ mildMax) → Pleasant.
    var pleasantMax: Double
    /// Below this value (and ≥ pleasantMax) → Warm. Above → Hot.
    var warmMax: Double

    static let `default` = TemperatureRanges(
        freezingMax: 36,
        coldMax: 43,
        mildMax: 51,
        pleasantMax: 61,
        warmMax: 85
    )

    func category(for temperatureF: Double) -> TempCategory {
        if temperatureF < freezingMax { return .freezing }
        if temperatureF < coldMax     { return .cold }
        if temperatureF < mildMax     { return .mild }
        if temperatureF < pleasantMax { return .pleasant }
        if temperatureF < warmMax     { return .warm }
        return .hot
    }
}

enum TempCategory: String, CaseIterable, Codable, Identifiable {
    case freezing, cold, mild, pleasant, warm, hot

    var id: String { rawValue }
    var display: String { rawValue.capitalized }

    /// One-letter badge used in compact wardrobe rows.
    /// Unique across all six categories: F, C, M, P, W, H.
    var letter: String { String(rawValue.prefix(1)).uppercased() }
}
