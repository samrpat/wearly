//
//  DailyWeather.swift
//  Wearly
//
//  A per-day forecast entry. In addition to the full-day high/low it
//  carries hourly samples for temperature, apparent temperature, and
//  precipitation — the raw data the Daypart analyzer uses to decide
//  what to wear around the user's **key times** (morning walk, evening
//  commute, lunch break, whatever they care about).
//

import Foundation

struct DailyWeather: Identifiable, Equatable, Hashable {
    let date: Date
    let high: Double
    let low: Double
    let feelsHigh: Double?
    let feelsLow: Double?
    let condition: Weather.Condition
    let isRaining: Bool

    /// 24 entries indexed by local hour.
    let hourlyTemps: [Double]
    /// Same shape as `hourlyTemps`, or nil if provider doesn't expose it.
    let hourlyFeelsLike: [Double]?
    /// Precipitation (mm) per hour; length 24. 0 when dry.
    let hourlyPrecipitation: [Double]

    var id: Date { date }

    // MARK: - Full-day (unfiltered)

    var representativeTemp: Double {
        low + (high - low) * 0.66
    }

    var representativeFeelsLike: Double? {
        guard let fh = feelsHigh, let fl = feelsLow else { return nil }
        return fl + (fh - fl) * 0.66
    }

    var asWeather: Weather {
        Weather(
            temperature: representativeTemp,
            feelsLike: representativeFeelsLike,
            condition: condition,
            isRaining: isRaining
        )
    }

    // MARK: - Hourly samples

    func temp(at hour: Int) -> Double {
        hourlyTemps[safe: hour] ?? representativeTemp
    }

    func feelsLike(at hour: Int) -> Double {
        hourlyFeelsLike?[safe: hour] ?? temp(at: hour)
    }

    func precipitation(at hour: Int) -> Double {
        hourlyPrecipitation[safe: hour] ?? 0
    }

    func isRaining(at hour: Int) -> Bool {
        precipitation(at: hour) > 0.1
    }
}

/// What the weather provider returns: current conditions + a short daily forecast.
struct WeatherBundle: Equatable {
    let current: Weather
    let daily: [DailyWeather]
}

// MARK: - KeyTime

/// One moment in the day that the user cares about — e.g. the walk to
/// school, leaving work, a commute home. The outfit algorithm samples
/// hourly weather at each enabled key time and dresses for the worst
/// of them.
struct KeyTime: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var hour: Int                // 0–23 in local time
    var isEnabled: Bool

    init(id: UUID = UUID(),
         name: String,
         hour: Int,
         isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.hour = max(0, min(23, hour))
        self.isEnabled = isEnabled
    }

    /// "8 AM", "6 PM" — for compact UI labels.
    var formattedTime: String {
        let h = max(0, min(23, hour))
        let suffix = h < 12 ? "AM" : "PM"
        let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(display) \(suffix)"
    }

    /// A contextual SF Symbol used on the settings row — morning sun,
    /// midday, evening, night.
    var iconSymbol: String {
        switch hour {
        case 5..<10:   return "sunrise.fill"
        case 10..<16:  return "sun.max.fill"
        case 16..<20:  return "sunset.fill"
        default:       return "moon.fill"
        }
    }

    static let defaults: [KeyTime] = [
        KeyTime(name: "Morning",  hour: 8),
        KeyTime(name: "Evening",  hour: 18)
    ]
}

// MARK: - Small helper

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
