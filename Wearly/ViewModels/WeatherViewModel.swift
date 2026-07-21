//
//  WeatherViewModel.swift
//  Wearly
//
//  Coordinates LocationManager + weather provider + OutfitEngine. Views
//  observe this object for the single source of truth: what's the
//  weather, when was it fetched, the 7-day forecast, which day the user
//  has selected, and the outfit alternatives for that day.
//

import SwiftUI
import Combine
import CoreLocation
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class WeatherViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var currentWeather: Weather?
    @Published private(set) var forecast: [DailyWeather] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    /// 0 = today, 1..6 = future days.
    @Published var selectedDayOffset: Int = 0 {
        didSet { recomputeOutfits() }
    }

    @Published private(set) var alternatives: [Outfit] = []
    @Published var currentIndex: Int = 0

    /// Human-readable city name for the current device location.
    /// Mirrored from `LocationManager.locationName` so views can read
    /// it off the WeatherViewModel without touching CoreLocation.
    @Published private(set) var locationName: String?

    // MARK: - Dependencies

    private let locationManager = LocationManager()
    private let provider: WearlyWeatherProviding
    private var cancellables: Set<AnyCancellable> = []

    weak var settings: SettingsViewModel?

    init(provider: WearlyWeatherProviding = OpenMeteoProvider()) {
        self.provider = provider

        locationManager.$location
            .compactMap { $0 }
            .removeDuplicates { $0.coordinate.latitude == $1.coordinate.latitude
                                && $0.coordinate.longitude == $1.coordinate.longitude }
            .sink { [weak self] location in
                guard let self else { return }
                // Ignore device-location updates while the user has a
                // custom city override active in Settings.
                if self.settings?.useCustomLocation == true,
                   self.settings?.customLocationResolved != nil {
                    return
                }
                Task { await self.fetch(for: location) }
            }
            .store(in: &cancellables)

        locationManager.$errorMessage
            .compactMap { $0 }
            .assign(to: &$errorMessage)

        locationManager.$locationName
            .assign(to: &$locationName)
    }

    // MARK: - API

    func bootstrap(settings: SettingsViewModel) {
        self.settings = settings
        // Always initialize GPS; its updates are ignored while a
        // custom location is active (see sink above).
        locationManager.requestPermissionAndLocation()
        // If the user has a custom city set, fetch its weather
        // immediately — we won't get a device-location update to trigger it.
        if settings.useCustomLocation,
           let r = settings.customLocationResolved {
            Task { await fetch(for: CLLocation(latitude: r.latitude, longitude: r.longitude)) }
        }
    }

    func refresh() async {
        // Custom location wins when enabled + resolved.
        if let s = settings,
           s.useCustomLocation,
           let r = s.customLocationResolved {
            await fetch(for: CLLocation(latitude: r.latitude, longitude: r.longitude))
            return
        }
        locationManager.refreshLocation()
        if let location = locationManager.location {
            await fetch(for: location)
        }
    }

    // MARK: - Derived

    /// Daypart summary computed from the user's key times — drives
    /// effective temp, H/L, rain-gear decision, and narrative copy.
    var daypartSummary: DaypartSummary? {
        guard let day = forecast[safe: selectedDayOffset],
              let settings else { return nil }
        return DaypartAnalyzer.summarize(
            day: day,
            keyTimes: settings.keyTimes,
            useFeelsLike: settings.useFeelsLike,
            bias: settings.outfitBias,
            rainThreshold: settings.rainThreshold
        )
    }

    /// Weather the outfit engine dresses for — temperature is the
    /// *effective* value from the daypart summary, and isRaining
    /// reflects the `needsRainGear` decision.
    var selectedWeather: Weather? {
        guard let day = forecast[safe: selectedDayOffset],
              let summary = daypartSummary else { return nil }
        return Weather(
            temperature: summary.weatherlyTemp,
            feelsLike: nil,           // already baked into weatherlyTemp
            condition: day.condition,
            isRaining: summary.needsRainGear
        )
    }

    /// High/low for the currently selected day across the user's key times.
    var selectedHigh: Double? { daypartSummary?.maxTemp }
    var selectedLow: Double? { daypartSummary?.minTemp }

    /// The temperature the outfit engine targets.
    var weatherlyTemperature: Double? { daypartSummary?.weatherlyTemp }

    /// Convenient date for the header.
    var selectedDate: Date {
        if let day = forecast[safe: selectedDayOffset] { return day.date }
        return Calendar.current.startOfDay(for: Date())
    }

    /// "Today" for offset 0, "Tomorrow" for offset 1, otherwise the weekday name.
    var selectedDayLabel: String {
        switch selectedDayOffset {
        case 0:  return "Today"
        case 1:  return "Tomorrow"
        default:
            let date = selectedDate
            return date.formatted(.dateTime.weekday(.wide))
        }
    }

    /// "Apr 16" style short date.
    var selectedDateShort: String {
        selectedDate.formatted(.dateTime.month(.abbreviated).day())
    }

    /// The header should only show "Updated X ago" when viewing live data.
    var shouldShowLastUpdated: Bool {
        selectedDayOffset == 0
    }

    /// Weather + condition line, resolved for the currently-selected day.
    var displayWeather: Weather? { selectedWeather }

    var currentOutfit: Outfit? {
        guard !alternatives.isEmpty else { return nil }
        let idx = ((currentIndex % alternatives.count) + alternatives.count) % alternatives.count
        return alternatives[idx]
    }

    func cycleNext() {
        guard !alternatives.isEmpty else { return }
        currentIndex = (currentIndex + 1) % alternatives.count
    }

    func cyclePrevious() {
        guard !alternatives.isEmpty else { return }
        currentIndex = (currentIndex - 1 + alternatives.count) % alternatives.count
    }

    func recomputeOutfits() {
        guard let weather = selectedWeather, let settings else {
            alternatives = []
            return
        }
        // `selectedWeather` already has `.temperature` set to the
        // coldest effective key-time reading and `.isRaining` set to
        // reflect `needsRainGear`, so the engine stays agnostic.
        alternatives = OutfitEngine.generate(
            weather: weather,
            ranges: settings.ranges,
            items: settings.items
        )
        currentIndex = 0
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    // MARK: - Private

    private func fetch(for location: CLLocation) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let bundle = try await provider.fetch(for: location)
            self.currentWeather = bundle.current
            self.forecast = bundle.daily
            self.lastUpdated = Date()
            self.errorMessage = nil
            // Clamp selection if forecast shrank for any reason.
            if selectedDayOffset >= bundle.daily.count {
                selectedDayOffset = 0
            }
            recomputeOutfits()
            publishWidgetState()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Widget state

    /// Writes the currently-selected day's weatherly temp + outfit into
    /// the shared App Group container so the home-screen widget can
    /// render without doing its own weather fetch. Silently no-ops if
    /// the App Group isn't set up (e.g. during early development).
    private func publishWidgetState() {
        guard let summary = daypartSummary,
              let outfit  = currentOutfit,
              let settings = settings else { return }

        let category = settings.ranges.category(for: summary.weatherlyTemp)
        let payload: [String: Any] = [
            "weatherlyTemp":   Int(summary.weatherlyTemp.rounded()),
            "categoryRaw":     category.rawValue,
            "conditionSymbol": displayWeather?.condition.symbol ?? "cloud",
            "outfitSymbols":   outfit.items.map(\.symbol),
            // Parallel to outfitSymbols — used by the widget to draw a
            // small caption under each icon so two hoodies with the same
            // symbol (e.g. "Light Hoodie" vs "Hoodie") stay distinguishable.
            "outfitNames":     outfit.items.map(\.name),
            // Parallel role hint so the widget can apply the same role
            // tints the main card uses (outer=terracotta, base=cream,
            // bottom=denim, rain=navy, winter=snowy).
            "outfitRoles":     outfit.items.map(Self.widgetRole(for:)),
            "outfitLabel":     outfit.label,
            "dayLabel":        selectedDayLabel,
            "updatedAt":       Date().timeIntervalSince1970
        ]

        guard let shared = UserDefaults(suiteName: WearlyAppGroup.identifier),
              let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        shared.set(data, forKey: WearlyAppGroup.widgetStateKey)

        // Mirror the same dictionary to the paired watch so its root
        // view + complications reflect the user's real wardrobe and
        // key-time algorithm. No-ops if no watch is paired.
        PhoneWatchSender.send(payload: payload)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        // The daily reminder's body is frozen at schedule time, so we
        // re-schedule here — right after the fresh payload has been
        // written — to make sure tomorrow morning's alert quotes the
        // current outfit ("Wear: Light Hoodie + T-shirt + Sweatpants")
        // instead of a stale one.
        if settings.notificationsEnabled {
            NotificationManager.scheduleDaily(
                hour: settings.notificationHour,
                minute: settings.notificationMinute
            )
        }
    }

    /// Maps a `ClothingItem` to a short role string the widget uses to
    /// pick a tint. Mirrors the same specific-override-then-category
    /// logic as `ClothingItem.tint` in `OutfitCardView.swift` so the
    /// widget colors match the main card.
    private static func widgetRole(for item: ClothingItem) -> String {
        let s = item.symbol.lowercased()
        let n = item.name.lowercased()

        if s.contains("rainjacket") || s.contains("umbrella")
            || n.contains("rain jacket") || n.contains("rain")
            || (item.requiresRain && item.category == .extras) {
            return "rain"
        }
        if s.contains("winterjacket") || s.contains("snowflake")
            || n.contains("winter jacket") || n.contains("winter") {
            return "winter"
        }

        switch item.category {
        case .tops:    return item.isOuterLayer ? "outer" : "base"
        case .bottoms: return "bottom"
        case .extras:  return "extra"
        }
    }
}

// MARK: - App Group identifiers

/// The identifier used for the App Group container that the main app
/// and the widget both read/write. Set up in Xcode's Signing &
/// Capabilities tab on both targets.
enum WearlyAppGroup {
    static let identifier = "group.com.wearly.shared"
    static let widgetStateKey = "wearly.widgetState"
}

