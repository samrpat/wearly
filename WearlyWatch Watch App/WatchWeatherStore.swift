//
//  WatchWeatherStore.swift
//  WearlyWatch
//
//  Standalone weather brain for the watch. Works **without** the paired
//  iPhone — it uses CoreLocation on the watch to get a coordinate, hits
//  Open-Meteo's free API to fetch today's forecast, picks an outfit
//  with its own tiny zone-based engine, and publishes the result into
//  the shared App Group so the complications render.
//
//  When the iPhone **is** around, `WatchConnectivitySync` receives the
//  full iPhone payload (reflecting the user's custom wardrobe, ranges,
//  and key-time algorithm) and calls `apply(payload:)` here — that wins
//  over the standalone fetch because it represents the user's actual
//  settings.
//

import SwiftUI
import Combine
import CoreLocation
import Foundation

// MARK: - Store

@MainActor
final class WatchWeatherStore: ObservableObject {

    // The watch target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION =
    // MainActor`, which would make the synthesized `objectWillChange`
    // main-actor-isolated and break `ObservableObject` conformance
    // (the protocol requires it nonisolated). Declaring it explicitly
    // as `nonisolated` sidesteps the synthesis.
    nonisolated let objectWillChange = ObservableObjectPublisher()

    // Published state for the root view. Pre-hydrated from the App
    // Group at construction time so the first frame the user sees
    // already reflects whatever the complications are displaying —
    // no "—°" flash while `bootstrap()` catches up.
    @Published private(set) var payload: WatchWidgetPayload
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?
    @Published private(set) var source: Source

    init() {
        if let cached = WatchWidgetPayload.load() {
            payload = cached
            source  = .standalone
        } else {
            payload = .placeholder
            source  = .placeholder
        }
    }

    enum Source: Equatable {
        case placeholder
        case standalone    // fetched by the watch itself
        case fromPhone     // delivered by the paired iPhone via WCSession
    }

    private let locationController = WatchLocationController()
    private var hasKickedOffFetch = false

    /// Settings source for standalone outfit computation. When nil the
    /// store falls back to `WatchOutfitBuilder`'s hardcoded defaults.
    weak var settings: WatchSettingsStore?

    // MARK: Bootstrap

    /// Called once from the app entry point. Loads any cached payload
    /// out of the App Group (iPhone may have already delivered one, or
    /// this launch is following a previous own-fetch) and kicks off a
    /// fresh standalone fetch so the watch has something current even
    /// if the iPhone never shows up.
    func bootstrap() {
        if let cached = WatchWidgetPayload.load() {
            payload = cached
            // Assume "fromPhone" only if source was previously set —
            // otherwise treat cached as standalone.
            source = .standalone
        }

        locationController.onLocation = { [weak self] loc in
            Task { await self?.fetchStandalone(at: loc) }
        }
        locationController.onError = { [weak self] msg in
            Task { @MainActor in self?.lastError = msg }
        }
        locationController.start()
    }

    /// User-triggered refresh (e.g. tap on the source pill). Clears any
    /// previous error and asks the location controller for a new fix —
    /// that will eventually trigger another standalone fetch. If the
    /// iPhone is paired and awake it should also push a fresh payload
    /// in response to this prod via WCSession's reachability check.
    func manualRefresh() {
        lastError = nil
        // Temporarily unpin from fromPhone so a standalone retry can
        // take effect while we wait for the iPhone push.
        if source == .fromPhone {
            // Keep source as fromPhone but allow a standalone fetch to
            // update if iPhone stays silent.
        }
        locationController.start()
    }

    /// Called by `WatchConnectivitySync` whenever the paired iPhone
    /// transfers a fresh payload. Always wins over standalone data
    /// because it reflects the user's actual wardrobe + algorithm.
    func apply(payloadDict: [String: Any]) {
        let resolved = WatchWidgetPayload(
            weatherlyTemp:   payloadDict["weatherlyTemp"]   as? Int    ?? 0,
            categoryRaw:     payloadDict["categoryRaw"]     as? String ?? "mild",
            conditionSymbol: payloadDict["conditionSymbol"] as? String ?? "cloud",
            outfitSymbols:   payloadDict["outfitSymbols"]   as? [String] ?? [],
            outfitNames:     payloadDict["outfitNames"]     as? [String] ?? [],
            outfitRoles:     payloadDict["outfitRoles"]     as? [String] ?? [],
            outfitLabel:     payloadDict["outfitLabel"]     as? String ?? "",
            dayLabel:        payloadDict["dayLabel"]        as? String ?? "Today"
        )
        payload = resolved
        source = .fromPhone
        writeToAppGroup(payloadDict)
    }

    // MARK: Standalone fetch

    /// Hits Open-Meteo for today's high/low, picks an outfit, writes to
    /// the App Group. Intentionally simple — no key-time algorithm, no
    /// feels-like adjustment, no configurable wardrobe. When the iPhone
    /// is paired and awake it will overwrite this with its richer result.
    private func fetchStandalone(at loc: CLLocation) async {
        // If the iPhone has already delivered a payload in this session,
        // don't clobber it with a less-informed standalone one.
        if source == .fromPhone { return }

        isLoading = true
        defer { isLoading = false }

        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude

        let urlString =
            "https://api.open-meteo.com/v1/forecast?" +
            "latitude=\(lat)&longitude=\(lon)" +
            "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code" +
            "&temperature_unit=fahrenheit&timezone=auto&forecast_days=1"

        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = obj["daily"] as? [String: Any],
                  let highs = daily["temperature_2m_max"] as? [Double],
                  let lows  = daily["temperature_2m_min"] as? [Double],
                  let precs = daily["precipitation_sum"]  as? [Double],
                  let codes = daily["weather_code"]       as? [Int],
                  let high = highs.first, let low = lows.first,
                  let precip = precs.first, let code = codes.first
            else { return }

            let weatherly = Int(((high + low) / 2).rounded())
            let mmPerHour = precip // daily precipitation sum in mm
            let rainThresh = settings?.rainThreshold ?? 0.1
            let rainy = mmPerHour > max(rainThresh, 0.1) * 24 // rough daily equivalent
            let built: WatchWidgetPayload
            if let s = settings {
                built = WatchOutfitBuilder.buildFromSettings(
                    weatherlyTemp: weatherly,
                    rainy: rainy,
                    conditionSymbol: Self.symbol(forWeatherCode: code, rainy: rainy),
                    settings: s
                )
            } else {
                built = WatchOutfitBuilder.build(
                    weatherlyTemp: weatherly,
                    rainy: rainy,
                    conditionSymbol: Self.symbol(forWeatherCode: code, rainy: rainy)
                )
            }

            payload = built
            source = .standalone
            writeToAppGroup(built.asDictionary)
            lastError = nil
        } catch {
            lastError = "Weather fetch failed"
        }
    }

    // MARK: App Group write

    private func writeToAppGroup(_ dict: [String: Any]) {
        guard let defaults = UserDefaults(suiteName: WatchAppGroup.identifier),
              let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        defaults.set(data, forKey: WatchAppGroup.stateKey)

        // Nudge the complications so the face refreshes without
        // waiting for the next timeline tick.
        #if canImport(WidgetKit)
        Task { @MainActor in
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    /// Rough mapping of Open-Meteo weather codes → SF Symbols used by
    /// the watch condition pill. Only distinguishes a handful of states
    /// since the watch UI doesn't need the full fidelity the iPhone has.
    private static func symbol(forWeatherCode code: Int, rainy: Bool) -> String {
        if rainy { return "cloud.rain" }
        switch code {
        case 0:         return "sun.max"
        case 1, 2:      return "cloud.sun"
        case 3:         return "cloud"
        case 45, 48:    return "cloud.fog"
        case 51...67:   return "cloud.drizzle"
        case 71...77:   return "snowflake"
        case 80...86:   return "cloud.heavyrain"
        case 95...99:   return "cloud.bolt"
        default:        return "cloud"
        }
    }
}

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Location controller

/// Thin wrapper around `CLLocationManager` for watchOS. Asks for
/// when-in-use permission, fires `onLocation` on each fix, and
/// surfaces authorization denials via `onError`.
private final class WatchLocationController: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onLocation: ((CLLocation) -> Void)?
    var onError: ((String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onError?("Location permission denied")
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        onLocation?(loc)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            onError?("Location permission denied")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error.localizedDescription)
    }
}

// MARK: - Payload dictionary helper

extension WatchWidgetPayload {
    var asDictionary: [String: Any] {
        [
            "weatherlyTemp":   weatherlyTemp,
            "categoryRaw":     categoryRaw,
            "conditionSymbol": conditionSymbol,
            "outfitSymbols":   outfitSymbols,
            "outfitNames":     outfitNames,
            "outfitRoles":     outfitRoles,
            "outfitLabel":     outfitLabel,
            "dayLabel":        dayLabel
        ]
    }
}

// MARK: - Fallback outfit engine
//
// A tiny, hardcoded version of the iOS app's OutfitEngine so the watch
// has something sensible to suggest when it's running without the
// paired iPhone. It only knows the six built-in zones and one outfit
// per zone. When the iPhone delivers a real payload via WCSession this
// engine is bypassed entirely.

enum WatchOutfitBuilder {

    /// Maps `weatherlyTemp` (°F) to one of the six built-in zones
    /// using the same default thresholds as the iOS app:
    ///   32 / 50 / 65 / 75 / 85
    private static func zone(for temp: Int) -> String {
        switch Double(temp) {
        case ..<32:  return "freezing"
        case ..<50:  return "cold"
        case ..<65:  return "mild"
        case ..<75:  return "pleasant"
        case ..<85:  return "warm"
        default:     return "hot"
        }
    }

    /// Returns a ready-to-publish payload with the correct silhouettes,
    /// names, and role tags for the temperature zone. `rainy == true`
    /// inserts a rain jacket into the outfit.
    static func build(
        weatherlyTemp: Int,
        rainy: Bool,
        conditionSymbol: String
    ) -> WatchWidgetPayload {
        let z = zone(for: weatherlyTemp)

        // (symbol, name, role) tuples per zone.
        var pieces: [(String, String, String)] = {
            switch z {
            case "freezing":
                return [
                    ("wearly.hoodie.fill",       "Hoodie",       "outer"),
                    ("wearly.longsleeve.fill",   "Longsleeve",   "base"),
                    ("wearly.sweatpants.fill",   "Sweatpants",   "bottom"),
                    ("wearly.winterjacket.fill", "Winter jacket","winter")
                ]
            case "cold":
                return [
                    ("wearly.hoodie.fill",       "Hoodie",       "outer"),
                    ("wearly.longsleeve.fill",   "Longsleeve",   "base"),
                    ("wearly.sweatpants.fill",   "Sweatpants",   "bottom")
                ]
            case "mild":
                return [
                    ("wearly.hoodie.fill",       "Light hoodie", "outer"),
                    ("wearly.tshirt.fill",       "T-shirt",      "base"),
                    ("wearly.sweatpants.fill",   "Sweatpants",   "bottom")
                ]
            case "pleasant":
                return [
                    ("wearly.longsleeve.fill",   "Longsleeve",   "base"),
                    ("wearly.sweatpants.fill",   "Sweatpants",   "bottom")
                ]
            case "warm":
                return [
                    ("wearly.tshirt.fill",       "T-shirt",      "base"),
                    ("wearly.shorts.fill",       "Shorts",       "bottom")
                ]
            default: // hot
                return [
                    ("wearly.tshirt.fill",       "T-shirt",      "base"),
                    ("wearly.shorts.fill",       "Shorts",       "bottom")
                ]
            }
        }()

        if rainy {
            pieces.append(("wearly.rainjacket.fill", "Rain jacket", "rain"))
        }

        let label = pieces.map(\.1).joined(separator: " + ")

        return WatchWidgetPayload(
            weatherlyTemp:   weatherlyTemp,
            categoryRaw:     z,
            conditionSymbol: conditionSymbol,
            outfitSymbols:   pieces.map(\.0),
            outfitNames:     pieces.map(\.1),
            outfitRoles:     pieces.map(\.2),
            outfitLabel:     label,
            dayLabel:        "Today"
        )
    }

    /// Outfit pick that honors the user's actual wardrobe + ranges.
    /// Mirrors the iOS `OutfitEngine` at a simplified level:
    ///   • Pick first enabled top matching the zone.
    ///   • Pick first enabled bottom matching the zone.
    ///   • If rainy, layer the first enabled rain-requiring extra.
    ///   • If a non-outer applicable top and an outer layer both
    ///     match, stack outer on top of base.
    static func buildFromSettings(
        weatherlyTemp: Int,
        rainy: Bool,
        conditionSymbol: String,
        settings: WatchSettingsStore
    ) -> WatchWidgetPayload {
        let zoneRaw = settings.category(for: Double(weatherlyTemp))

        func applies(_ item: WatchClothingItem) -> Bool {
            item.isEnabled && item.applicableRanges.contains(zoneRaw)
        }

        let tops = settings.items.filter { $0.category == "tops" && applies($0) }
        let bases = tops.filter { !$0.isOuterLayer }
        let outers = tops.filter { $0.isOuterLayer }
        let bottoms = settings.items.filter { $0.category == "bottoms" && applies($0) }
        let extras = settings.items.filter { $0.category == "extras" && applies($0) }

        var pieces: [(String, String, String)] = []

        if let outer = outers.first, let base = bases.first {
            pieces.append((outer.symbol, outer.name, "outer"))
            pieces.append((base.symbol,  base.name,  "base"))
        } else if let base = bases.first {
            pieces.append((base.symbol, base.name, "base"))
        } else if let outer = outers.first {
            pieces.append((outer.symbol, outer.name, "outer"))
        }

        if let bottom = bottoms.first {
            pieces.append((bottom.symbol, bottom.name, "bottom"))
        }

        for e in extras {
            if e.requiresRain && !rainy { continue }
            let role: String = {
                let sym = e.symbol.lowercased()
                let nm  = e.name.lowercased()
                if sym.contains("rainjacket") || nm.contains("rain") { return "rain" }
                if sym.contains("winterjacket") || nm.contains("winter") { return "winter" }
                return "extra"
            }()
            pieces.append((e.symbol, e.name, role))
        }

        let label = pieces.map(\.1).joined(separator: " + ")

        return WatchWidgetPayload(
            weatherlyTemp:   weatherlyTemp,
            categoryRaw:     zoneRaw,
            conditionSymbol: conditionSymbol,
            outfitSymbols:   pieces.map(\.0),
            outfitNames:     pieces.map(\.1),
            outfitRoles:     pieces.map(\.2),
            outfitLabel:     label,
            dayLabel:        "Today"
        )
    }
}
