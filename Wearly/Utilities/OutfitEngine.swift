//
//  OutfitEngine.swift
//  Wearly
//
//  Two concerns live in this file:
//
//  1. `OutfitEngine` — pure generator that turns `(weather, ranges,
//     wardrobe)` into a single outfit, using each item's declared
//     `applicableRanges` and `requiresRain` flags.
//
//  2. `DaypartAnalyzer` — decides *which* weather to feed the engine
//     by sampling the hourly forecast at the user's "key times" (the
//     moments they care about — walk to school, commute home, etc.).
//     It leans toward the coldest sample so the outfit always fits
//     the worst case, and flags rain gear if ANY sample is rainy.
//

import Foundation

enum OutfitEngine {

    static func generate(
        weather: Weather,
        ranges: TemperatureRanges,
        items: [ClothingItem]
    ) -> [Outfit] {
        let category = ranges.category(for: weather.temperature)

        let applicable = items.filter { item in
            guard item.isEnabled else { return false }
            guard item.applicableRanges.contains(category) else { return false }
            if item.requiresRain && !weather.isRaining { return false }
            return true
        }

        let allTops = applicable.filter { $0.category == .tops }
        let bottoms = applicable.filter { $0.category == .bottoms }
        let extras  = applicable.filter { $0.category == .extras }

        // Split tops into base layers (t-shirt, long-sleeve) and outer
        // layers (hoodie, cardigan …). When both a base and an outer are
        // applicable for the current category, we stack them — the outer
        // on top of the base. Otherwise whichever is available stands alone.
        var baseTops  = allTops.filter { !$0.isOuterLayer }
        var outerTops = allTops.filter { $0.isOuterLayer }

        // Fallback inference: if the user hasn't explicitly marked any
        // top as outer but has multiple applicable tops and one of them
        // is a hoodie / cardigan / sweater, treat it as the outer layer.
        // This is what makes "Light Hoodie + T-shirt" work even for an
        // existing Light Hoodie whose Outer Layer toggle was never flipped.
        if outerTops.isEmpty && baseTops.count > 1 {
            let inferredOuter = baseTops.filter(\.looksLikeOuterLayer)
            let inferredBase  = baseTops.filter { !$0.looksLikeOuterLayer }
            if !inferredOuter.isEmpty && !inferredBase.isEmpty {
                outerTops = inferredOuter
                baseTops = inferredBase
            }
        }

        var tops: [ClothingItem] = []
        if let base = baseTops.first, let outer = outerTops.first {
            // Outer first so it renders visually on top of the base.
            tops = [outer, base]
        } else if let base = baseTops.first {
            tops = [base]
        } else if let outer = outerTops.first {
            tops = [outer]
        }

        guard !tops.isEmpty, let bottom = bottoms.first else { return [] }

        let pieces: [ClothingItem] = tops + [bottom] + extras
        let label = pieces.map(\.name).joined(separator: " + ")
        return [Outfit(items: pieces, label: label)]
    }
}

// MARK: - Outfit bias

/// How aggressively the algorithm should commit to one outfit when
/// the sampled temperatures have a wide spread. On a 40°→70° day:
///   • `warm`     → dress for 40° (coldest key time). Never chilly.
///   • `balanced` → dress for the median (~55°). Middle ground.
///   • `light`    → dress for 70° (warmest key time). Peak comfort.
///
/// `balanced` is the default. Users who want "t-shirt and shorts on a
/// 40/70 day" pick `light`; users who run cold pick `warm`.
enum OutfitBias: String, Codable, CaseIterable, Identifiable {
    case warm, balanced, light

    var id: String { rawValue }

    var display: String {
        switch self {
        case .warm:     return "Warm"
        case .balanced: return "Balanced"
        case .light:    return "Light"
        }
    }

    var blurb: String {
        switch self {
        case .warm:     return "Dresses for the coldest moment."
        case .balanced: return "Picks a middle of the day."
        case .light:    return "Dresses for the warmest moment."
        }
    }
}

// MARK: - Daypart Summary

/// The decision output that feeds both the outfit engine and the UI.
/// Built from a `DailyWeather` + a set of user-defined `KeyTime`s.
struct DaypartSummary: Equatable {
    /// "Weatherly temp" — the single temperature the outfit engine
    /// dresses for. Derived from the day's high/low midpoint blended
    /// with the user's key-time samples, nudged by feels-like and bias.
    /// The UI surfaces this as "Dressing for X°" but internally we
    /// call it `weatherlyTemp`.
    let weatherlyTemp: Double
    /// Min and max across the sampled key times (drives the H/L chip).
    let minTemp: Double
    let maxTemp: Double
    /// True if precipitation is expected during ANY enabled key time.
    let needsRainGear: Bool
    /// The sampled readings — used by the UI to explain the decision
    /// ("Coldest at Morning · 51°", "Rain at 5 PM").
    let samples: [Sample]

    struct Sample: Equatable {
        let time: KeyTime
        let temp: Double
        let feelsLike: Double?
        let precipitation: Double
        var isRaining: Bool { precipitation > 0.1 }
    }
}

// MARK: - Daypart Analyzer

enum DaypartAnalyzer {

    /// Fallback precipitation threshold (mm/h) when the caller doesn't
    /// supply one — the user-configurable value lives in Settings.
    static let defaultRainThreshold: Double = 0.1

    /// Produces a DaypartSummary for the given day + key times.
    ///
    /// Simple recipe:
    ///   1. **Baseline = (day high + day low) / 2** — the midpoint of
    ///      the whole day's temperature swing.
    ///   2. **Blend in the user's key-time average** 50/50 — if their
    ///      active hours are warmer or colder than the day's midpoint,
    ///      the estimate shifts that way.
    ///   3. Apply a capped feels-like adjustment (±4°F).
    ///   4. Apply bias as a gentle ±2°F nudge.
    ///   5. Rain gear if any key-time hour exceeds `rainThreshold`, or
    ///      the day's peak hourly precipitation does.
    static func summarize(
        day: DailyWeather,
        keyTimes: [KeyTime],
        useFeelsLike: Bool,
        bias: OutfitBias,
        rainThreshold: Double = defaultRainThreshold
    ) -> DaypartSummary {
        let active = keyTimes.filter(\.isEnabled)

        // 1. Day midpoint — anchors everything.
        let dayMid = (day.high + day.low) / 2

        // 2. Key-time average, used as a pull toward the hours the user
        //    is actually outside.
        let keyTemps = active.map { day.temp(at: $0.hour) }
        let keyAvg   = keyTemps.isEmpty
            ? dayMid
            : keyTemps.reduce(0, +) / Double(keyTemps.count)

        var effective = (dayMid + keyAvg) / 2

        // 3. Optional feels-like adjustment — capped so solar boosts
        //    don't dominate a cool day.
        if useFeelsLike {
            let keyFeels = active.map { day.feelsLike(at: $0.hour) }
            let feelsAvg: Double = {
                if !keyFeels.isEmpty {
                    return keyFeels.reduce(0, +) / Double(keyFeels.count)
                }
                if let fh = day.feelsHigh, let fl = day.feelsLow {
                    return (fh + fl) / 2
                }
                return dayMid
            }()
            let rawDelta = feelsAvg - (keyTemps.isEmpty ? dayMid : keyAvg)
            effective += max(-4, min(4, rawDelta))
        }

        // 4. Bias — a ±4°F shift. Big enough to cross a narrow category
        //    boundary, so "How you dress" actually moves the needle.
        switch bias {
        case .warm:     effective -= 4
        case .balanced: break
        case .light:    effective += 4
        }

        // 5. Per-key-time samples for the narrative.
        let samples: [DaypartSummary.Sample] = active.map { kt in
            DaypartSummary.Sample(
                time: kt,
                temp: day.temp(at: kt.hour),
                feelsLike: day.hourlyFeelsLike?[safe: kt.hour],
                precipitation: day.precipitation(at: kt.hour)
            )
        }

        // Rain gear is driven by the user-configurable threshold — any
        // key-time hour above it, or the day's peak hourly precip above
        // it, flips the flag. We deliberately DON'T honor `day.isRaining`
        // on its own, since that flag uses a fixed 0.1 mm/h cutoff and
        // would override a higher user threshold.
        let peakDayPrecip = day.hourlyPrecipitation.max() ?? 0
        let rainAtKeyTime = samples.contains { $0.precipitation > rainThreshold }
        let needsRain = rainAtKeyTime || peakDayPrecip > rainThreshold

        return DaypartSummary(
            weatherlyTemp: effective,
            minTemp: day.low,
            maxTemp: day.high,
            needsRainGear: needsRain,
            samples: samples
        )
    }

    /// Human-readable narrative for the card's supporting line.
    /// **Always** leads with "Dressing for X°" so the user can see what
    /// the algorithm is targeting no matter what else is going on.
    static func narrative(for summary: DaypartSummary, bias: OutfitBias) -> String? {
        let effI   = Int(summary.weatherlyTemp.rounded())
        let prefix = "Dressing for \(effI)°"

        // Only call out rain in the narrative if the summary actually
        // decided rain gear is needed — that respects the user's
        // configured threshold instead of the sample's hardcoded 0.1.
        if summary.needsRainGear,
           let wettest = summary.samples.max(by: { $0.precipitation < $1.precipitation }),
           wettest.precipitation > 0 {
            return "\(prefix) · rain at \(wettest.time.formattedTime)"
        }

        let samplesByHour = summary.samples.sorted { $0.time.hour < $1.time.hour }
        if samplesByHour.count >= 2 {
            let firstT = samplesByHour.first!.temp
            let lastT  = samplesByHour.last!.temp
            let delta = lastT - firstT
            if delta > 5 {
                return "\(prefix) · warming \(Int(firstT.rounded()))°→\(Int(lastT.rounded()))°"
            }
            if delta < -5 {
                return "\(prefix) · cooling \(Int(firstT.rounded()))°→\(Int(lastT.rounded()))°"
            }
        }

        let minI = Int(summary.minTemp.rounded())
        let maxI = Int(summary.maxTemp.rounded())
        if maxI - minI < 5 {
            return "\(prefix) · steady today"
        }
        return "\(prefix) · \(minI)°–\(maxI)° today"
    }
}
