//
//  WeatherService.swift
//  Wearly
//
//  Thin adapter around the Open-Meteo public API, which returns our
//  own `WeatherBundle` (current + 7-day daily forecast). Open-Meteo is
//  free, keyless, and signup-free for non-commercial use — no Apple
//  Developer account required.
//
//  Swapping in any other backend (OpenWeather, Apple WeatherKit, a
//  mock for tests) only requires conforming to `WearlyWeatherProviding`
//  and passing the new provider into `WeatherViewModel(provider:)`.
//

import Foundation
import CoreLocation

protocol WearlyWeatherProviding {
    func fetch(for location: CLLocation) async throws -> WeatherBundle
}

// MARK: - Open-Meteo implementation

struct OpenMeteoProvider: WearlyWeatherProviding {

    private let session: URLSession
    private let baseURL = "https://api.open-meteo.com/v1/forecast"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(for location: CLLocation) async throws -> WeatherBundle {
        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            URLQueryItem(name: "latitude",         value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude",        value: String(location.coordinate.longitude)),
            URLQueryItem(name: "current",          value: "temperature_2m,apparent_temperature,weather_code,precipitation"),
            URLQueryItem(name: "hourly",           value: "temperature_2m,apparent_temperature,precipitation"),
            URLQueryItem(name: "daily",            value: "temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,weather_code,precipitation_sum"),
            URLQueryItem(name: "forecast_days",    value: "7"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone",         value: "auto")
        ]

        guard let url = comps.url else { throw WeatherError.badURL }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw WeatherError.badResponse
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        // --- Current ---
        let currentCode = decoded.current.weather_code
        let currentTemp = decoded.current.temperature_2m
        let currentPrecip = decoded.current.precipitation ?? 0
        let current = Weather(
            temperature: currentTemp,
            feelsLike: decoded.current.apparent_temperature,
            condition: Self.mapCondition(code: currentCode),
            isRaining: Self.isRain(code: currentCode) || currentPrecip > 0.1
        )

        // --- Daily forecast (with hourly arrays attached per day) ---
        let daily = try Self.parseDaily(decoded.daily,
                                        hourly: decoded.hourly,
                                        timezone: decoded.timezone)

        return WeatherBundle(current: current, daily: daily)
    }

    // MARK: - Parsing helpers

    private static func parseDaily(_ payload: OpenMeteoResponse.Daily,
                                   hourly: OpenMeteoResponse.Hourly,
                                   timezone: String?) throws -> [DailyWeather] {
        // Open-Meteo returns ISO-8601 local dates like "2024-04-16".
        let tz = (timezone.flatMap { TimeZone(identifier: $0) }) ?? .current

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = tz

        let hourFormatter = DateFormatter()
        hourFormatter.calendar = Calendar(identifier: .gregorian)
        hourFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        hourFormatter.locale = Locale(identifier: "en_US_POSIX")
        hourFormatter.timeZone = tz

        let count = payload.time.count
        guard payload.temperature_2m_max.count == count,
              payload.temperature_2m_min.count == count,
              payload.weather_code.count == count else {
            throw WeatherError.badResponse
        }

        // Group hourly readings by day-of-year (in the response timezone).
        // Key: "yyyy-MM-dd". Value: 24-slot arrays indexed by local hour.
        var tempsByDay: [String: [Double?]] = [:]
        var feelsByDay: [String: [Double?]] = [:]
        var precipByDay: [String: [Double?]] = [:]

        for (idx, ts) in hourly.time.enumerated() {
            guard let date = hourFormatter.date(from: ts) else { continue }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = tz
            let hour = cal.component(.hour, from: date)
            let key = dayFormatter.string(from: date)
            if tempsByDay[key] == nil {
                tempsByDay[key]  = Array(repeating: nil, count: 24)
                feelsByDay[key]  = Array(repeating: nil, count: 24)
                precipByDay[key] = Array(repeating: nil, count: 24)
            }
            if idx < hourly.temperature_2m.count {
                tempsByDay[key]?[hour] = hourly.temperature_2m[idx]
            }
            if let feels = hourly.apparent_temperature, idx < feels.count {
                feelsByDay[key]?[hour] = feels[idx]
            }
            if let precip = hourly.precipitation, idx < precip.count {
                precipByDay[key]?[hour] = precip[idx]
            }
        }

        var result: [DailyWeather] = []
        for i in 0..<count {
            let dayKey = payload.time[i]
            guard let date = dayFormatter.date(from: dayKey) else { continue }
            let code = payload.weather_code[i]
            let precip = payload.precipitation_sum?[i] ?? 0

            let dayHigh = payload.temperature_2m_max[i]
            let dayLow = payload.temperature_2m_min[i]
            let hourlyTemps = fillMissing(tempsByDay[dayKey] ?? [],
                                          fallbackHigh: dayHigh,
                                          fallbackLow: dayLow)
            let hourlyFeels: [Double]? = {
                let raw = feelsByDay[dayKey] ?? []
                guard raw.contains(where: { $0 != nil }) else { return nil }
                return fillMissing(raw,
                                   fallbackHigh: payload.apparent_temperature_max?[safe: i] ?? dayHigh,
                                   fallbackLow: payload.apparent_temperature_min?[safe: i] ?? dayLow)
            }()
            let hourlyPrecip = fillMissing(
                precipByDay[dayKey] ?? [],
                fallbackHigh: 0,
                fallbackLow: 0
            )

            result.append(DailyWeather(
                date: date,
                high: dayHigh,
                low: dayLow,
                feelsHigh: payload.apparent_temperature_max?[safe: i],
                feelsLow: payload.apparent_temperature_min?[safe: i],
                condition: mapCondition(code: code),
                isRaining: isRain(code: code) || precip > 1.0,
                hourlyTemps: hourlyTemps,
                hourlyFeelsLike: hourlyFeels,
                hourlyPrecipitation: hourlyPrecip
            ))
        }
        return result
    }

    /// Open-Meteo occasionally drops hours (especially at DST boundaries).
    /// We forward-fill from the previous known value, then back-fill any
    /// leading nils from the daily high/low midpoint.
    private static func fillMissing(_ raw: [Double?],
                                    fallbackHigh: Double,
                                    fallbackLow: Double) -> [Double] {
        let fallback = (fallbackHigh + fallbackLow) / 2
        var out: [Double] = []
        var last: Double? = nil
        for v in raw {
            if let v { out.append(v); last = v }
            else if let last { out.append(last) }
            else { out.append(fallback) }
        }
        while out.count < 24 { out.append(last ?? fallback) }
        return out
    }

    // WMO weather interpretation codes → our simpler Condition enum.
    // Reference: https://open-meteo.com/en/docs
    private static func mapCondition(code: Int) -> Weather.Condition {
        switch code {
        case 0:                 return .clear              // Clear sky
        case 1, 2, 3:           return .cloudy             // Mainly clear → Overcast
        case 45, 48:            return .foggy              // Fog / depositing rime
        case 51, 53, 55,                                     // Drizzle
             56, 57,                                         // Freezing drizzle
             61, 63, 65,                                     // Rain
             66, 67,                                         // Freezing rain
             80, 81, 82,                                     // Rain showers
             95, 96, 99:        return .rain                // Thunderstorms
        case 71, 73, 75, 77,                                 // Snow / grains
             85, 86:            return .snow                // Snow showers
        default:                return .cloudy
        }
    }

    private static func isRain(code: Int) -> Bool {
        switch code {
        case 51...57, 61...67, 80...82, 95, 96, 99: return true
        default: return false
        }
    }
}

// MARK: - Errors & wire model

enum WeatherError: LocalizedError {
    case badURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badURL:       return "Invalid weather URL."
        case .badResponse:  return "Weather service unavailable."
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double?
        let weather_code: Int
        let precipitation: Double?
    }
    struct Daily: Decodable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let apparent_temperature_max: [Double]?
        let apparent_temperature_min: [Double]?
        let weather_code: [Int]
        let precipitation_sum: [Double]?
    }
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let apparent_temperature: [Double]?
        let precipitation: [Double]?
    }
    let current: Current
    let hourly: Hourly
    let daily: Daily
    let timezone: String?
}

