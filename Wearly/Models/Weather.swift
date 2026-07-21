//
//  Weather.swift
//  Wearly
//
//  Lightweight weather model, decoupled from any specific provider so
//  the app can swap backends easily. `feelsLike` is optional — when the
//  user's "Use feels like" setting is on, the WeatherViewModel surfaces
//  it as the primary temperature.
//

import Foundation

struct Weather: Equatable {
    /// Actual air temperature in Fahrenheit.
    let temperature: Double
    /// Apparent ("feels like") temperature in Fahrenheit, if available.
    let feelsLike: Double?
    let condition: Condition
    let isRaining: Bool

    init(temperature: Double,
         feelsLike: Double? = nil,
         condition: Condition,
         isRaining: Bool) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.condition = condition
        self.isRaining = isRaining
    }

    enum Condition: String, CaseIterable {
        case clear, cloudy, rain, snow, windy, foggy

        var symbol: String {
            switch self {
            case .clear:  return "sun.max"
            case .cloudy: return "cloud"
            case .rain:   return "cloud.rain"
            case .snow:   return "cloud.snow"
            case .windy:  return "wind"
            case .foggy:  return "cloud.fog"
            }
        }

        /// Filled, hero-sized variant used for the main screen visual.
        /// Chosen so SF Symbol's `.multicolor` rendering mode lights each
        /// one up with its natural palette (sun = yellow, rain = blue, etc.).
        var bigSymbol: String {
            switch self {
            case .clear:  return "sun.max.fill"
            case .cloudy: return "cloud.fill"
            case .rain:   return "cloud.heavyrain.fill"
            case .snow:   return "cloud.snow.fill"
            case .windy:  return "wind"
            case .foggy:  return "cloud.fog.fill"
            }
        }

        var description: String {
            switch self {
            case .clear:  return "Clear"
            case .cloudy: return "Cloudy"
            case .rain:   return "Rain"
            case .snow:   return "Snow"
            case .windy:  return "Windy"
            case .foggy:  return "Fog"
            }
        }
    }
}
