//
//  SettingsViewModel.swift
//  Wearly
//
//  Owns the full wardrobe (add / edit / delete / reset), temperature
//  thresholds (now six-way: Freezing → Cold → Mild → Pleasant → Warm
//  → Hot), the "use feels-like" preference, and the daily-notification
//  toggle. All state is persisted to UserDefaults.
//

import SwiftUI
import Foundation
import CoreLocation

/// A resolved custom location — city name + coordinates — set when the
/// user types a place into Settings and it's successfully geocoded.
struct ResolvedLocation: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
}

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published state

    @Published var items: [ClothingItem] {
        didSet { persistItems() }
    }

    @Published var freezingMax: Double {
        didSet {
            UserDefaults.standard.set(freezingMax, forKey: Keys.freezingMax)
            if coldMax < freezingMax + 5 { coldMax = freezingMax + 5 }
        }
    }

    @Published var coldMax: Double {
        didSet {
            UserDefaults.standard.set(coldMax, forKey: Keys.coldMax)
            if mildMax < coldMax + 5 { mildMax = coldMax + 5 }
        }
    }

    @Published var mildMax: Double {
        didSet {
            UserDefaults.standard.set(mildMax, forKey: Keys.mildMax)
            if pleasantMax < mildMax + 5 { pleasantMax = mildMax + 5 }
        }
    }

    @Published var pleasantMax: Double {
        didSet {
            UserDefaults.standard.set(pleasantMax, forKey: Keys.pleasantMax)
            if warmMax < pleasantMax + 5 { warmMax = pleasantMax + 5 }
        }
    }

    @Published var warmMax: Double {
        didSet { UserDefaults.standard.set(warmMax, forKey: Keys.warmMax) }
    }

    @Published var useFeelsLike: Bool {
        didSet { UserDefaults.standard.set(useFeelsLike, forKey: Keys.useFeelsLike) }
    }

    /// Minimum precipitation (mm/h) at any sampled key time before the
    /// algorithm suggests a rain jacket. Keeps a rain jacket from showing
    /// up for trace drizzle. Default 0.1 mm/h.
    @Published var rainThreshold: Double {
        didSet { UserDefaults.standard.set(rainThreshold, forKey: Keys.rainThreshold) }
    }

    /// How the algorithm leans on big-swing days. Default: balanced.
    @Published var outfitBias: OutfitBias {
        didSet { UserDefaults.standard.set(outfitBias.rawValue, forKey: Keys.outfitBias) }
    }

    /// The user's key moments of the day — "Morning walk", "Lunch run",
    /// "Evening commute". The outfit algorithm dresses for the coldest
    /// of these and flags rain gear if any of them lands in precipitation.
    @Published var keyTimes: [KeyTime] {
        didSet { persistKeyTimes() }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notifications)
            handleNotificationsToggle()
        }
    }

    /// Hour of the daily reminder (0–23). Default 6.
    @Published var notificationHour: Int {
        didSet {
            UserDefaults.standard.set(notificationHour, forKey: Keys.notificationHour)
            rescheduleNotificationIfNeeded()
        }
    }

    /// Minute of the daily reminder (0–59). Default 40.
    @Published var notificationMinute: Int {
        didSet {
            UserDefaults.standard.set(notificationMinute, forKey: Keys.notificationMinute)
            rescheduleNotificationIfNeeded()
        }
    }

    // MARK: - Location override

    /// When true, weather fetches use `customLocationResolved` instead of
    /// the device's GPS coordinate.
    @Published var useCustomLocation: Bool {
        didSet { UserDefaults.standard.set(useCustomLocation, forKey: Keys.useCustomLocation) }
    }

    /// The last successfully geocoded custom location (city + coords).
    @Published private(set) var customLocationResolved: ResolvedLocation? {
        didSet { persistCustomLocation() }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        // Wardrobe — load into a local, migrate the local, then assign.
        // (We can't mutate `self.items` as inout until every stored
        // property on `self` has been initialized.)
        var loadedItems: [ClothingItem]
        if let data = defaults.data(forKey: Keys.items),
           let decoded = try? JSONDecoder().decode([ClothingItem].self, from: data) {
            loadedItems = decoded
        } else {
            loadedItems = ClothingItem.defaults
        }
        Self.migrateHoodiesToOuterLayer(&loadedItems, defaults: defaults)
        items = loadedItems

        freezingMax = defaults.object(forKey: Keys.freezingMax) as? Double ?? 32
        coldMax     = defaults.object(forKey: Keys.coldMax)     as? Double ?? 50
        mildMax     = defaults.object(forKey: Keys.mildMax)     as? Double ?? 65
        pleasantMax = defaults.object(forKey: Keys.pleasantMax) as? Double ?? 75
        warmMax     = defaults.object(forKey: Keys.warmMax)     as? Double ?? 85

        useFeelsLike = (defaults.object(forKey: Keys.useFeelsLike) as? Bool) ?? true
        rainThreshold = defaults.object(forKey: Keys.rainThreshold) as? Double ?? 0.1
        if let raw = defaults.string(forKey: Keys.outfitBias),
           let value = OutfitBias(rawValue: raw) {
            outfitBias = value
        } else {
            outfitBias = .balanced
        }
        if let data = defaults.data(forKey: Keys.keyTimes),
           let decoded = try? JSONDecoder().decode([KeyTime].self, from: data) {
            keyTimes = decoded
        } else {
            keyTimes = KeyTime.defaults
        }
        notificationsEnabled = defaults.bool(forKey: Keys.notifications)
        notificationHour     = defaults.object(forKey: Keys.notificationHour) as? Int ?? 6
        notificationMinute   = defaults.object(forKey: Keys.notificationMinute) as? Int ?? 40

        // Custom-location override: restored. When on, weather fetches
        // use `customLocationResolved` instead of the device's GPS —
        // handy for checking a forecast in another city.
        useCustomLocation = defaults.bool(forKey: Keys.useCustomLocation)
        if let data = defaults.data(forKey: Keys.customLocationResolved),
           let decoded = try? JSONDecoder().decode(ResolvedLocation.self, from: data) {
            customLocationResolved = decoded
        } else {
            customLocationResolved = nil
        }
    }

    // MARK: - Wardrobe CRUD

    /// Inserts a newly added item at the **top of its category** rather
    /// than at the end of the whole wardrobe. The outfit engine picks
    /// the first applicable top/bottom, so top-of-category means "your
    /// most recently added item wins" — which matches what users expect
    /// when they add something new and look for it on the main screen.
    func add(_ item: ClothingItem) {
        if let idx = items.firstIndex(where: { $0.category == item.category }) {
            items.insert(item, at: idx)
        } else {
            items.append(item)
        }
    }

    func update(_ item: ClothingItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx] = item
    }

    func delete(_ item: ClothingItem) {
        items.removeAll { $0.id == item.id }
    }

    func delete(at offsets: IndexSet, in category: ClothingItem.Category) {
        let categoryItems = items.filter { $0.category == category }
        let toRemove = offsets.map { categoryItems[$0].id }
        items.removeAll { toRemove.contains($0.id) }
    }

    func setEnabled(_ item: ClothingItem, enabled: Bool) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isEnabled = enabled
    }

    func resetWardrobe() {
        items = ClothingItem.defaults
    }

    func items(in category: ClothingItem.Category) -> [ClothingItem] {
        items.filter { $0.category == category }
    }

    // MARK: - Derived

    var ranges: TemperatureRanges {
        TemperatureRanges(
            freezingMax: freezingMax,
            coldMax: coldMax,
            mildMax: mildMax,
            pleasantMax: pleasantMax,
            warmMax: warmMax
        )
    }

    // MARK: - Private

    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Keys.items)
        }
    }

    /// One-time migration: any top with "hoodie" in its name or symbol
    /// gets promoted to `isOuterLayer = true` so existing wardrobes pick
    /// up the new layering behaviour without losing customizations.
    private static func migrateHoodiesToOuterLayer(
        _ items: inout [ClothingItem],
        defaults: UserDefaults
    ) {
        let migrationKey = "didMigrate.hoodieOuterLayer.v1"
        guard !defaults.bool(forKey: migrationKey) else { return }

        var changed = false
        for i in items.indices where items[i].category == .tops {
            let looksLikeHoodie =
                items[i].symbol.lowercased().contains("hoodie") ||
                items[i].name.lowercased().contains("hoodie")
            if looksLikeHoodie && !items[i].isOuterLayer {
                items[i].isOuterLayer = true
                changed = true
            }
        }
        if changed, let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Keys.items)
        }
        defaults.set(true, forKey: migrationKey)
    }

    private func handleNotificationsToggle() {
        if notificationsEnabled {
            Task {
                if await NotificationManager.requestAuthorization() {
                    NotificationManager.scheduleDaily(hour: notificationHour,
                                                      minute: notificationMinute)
                } else {
                    await MainActor.run { self.notificationsEnabled = false }
                }
            }
        } else {
            NotificationManager.cancel()
        }
    }

    private func rescheduleNotificationIfNeeded() {
        guard notificationsEnabled else { return }
        NotificationManager.scheduleDaily(hour: notificationHour, minute: notificationMinute)
    }

    // MARK: - Location resolution

    enum GeocodeError: LocalizedError {
        case empty, notFound
        var errorDescription: String? {
            switch self {
            case .empty:    return "Enter a city name."
            case .notFound: return "Couldn't find that place."
            }
        }
    }

    /// Geocodes a user-typed city name and stores the result in
    /// `customLocationResolved`. Throws on failure so the UI can surface it.
    func resolveCustomLocation(query: String) async throws {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw GeocodeError.empty }

        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(trimmed)
        guard let p = placemarks.first, let loc = p.location else {
            throw GeocodeError.notFound
        }
        let parts = [p.locality, p.administrativeArea, p.country].compactMap { $0 }
        let name = parts.isEmpty ? trimmed : parts.joined(separator: ", ")
        customLocationResolved = ResolvedLocation(
            name: name,
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude
        )
    }

    private func persistCustomLocation() {
        if let loc = customLocationResolved,
           let data = try? JSONEncoder().encode(loc) {
            UserDefaults.standard.set(data, forKey: Keys.customLocationResolved)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.customLocationResolved)
        }
    }

    private enum Keys {
        static let items         = "wardrobe.v2"
        static let freezingMax   = "freezingMax"
        static let coldMax       = "coldMax"
        static let mildMax       = "mildMax"
        static let pleasantMax   = "pleasantMax"
        static let warmMax       = "warmMax"
        static let useFeelsLike       = "useFeelsLike"
        static let rainThreshold      = "rainThreshold"
        static let outfitBias         = "outfitBias"
        static let keyTimes           = "keyTimes.v1"
        static let notifications      = "notificationsEnabled"
        static let notificationHour   = "notificationHour"
        static let notificationMinute = "notificationMinute"
        static let useCustomLocation  = "useCustomLocation"
        static let customLocationResolved = "customLocationResolved"
    }

    // MARK: - Key times CRUD

    func addKeyTime(_ time: KeyTime) {
        keyTimes.append(time)
    }

    func addKeyTime(name: String = "New", hour: Int = 12) {
        keyTimes.append(KeyTime(name: name, hour: hour))
    }

    func updateKeyTime(_ time: KeyTime) {
        guard let idx = keyTimes.firstIndex(where: { $0.id == time.id }) else { return }
        keyTimes[idx] = time
    }

    func deleteKeyTime(_ time: KeyTime) {
        keyTimes.removeAll { $0.id == time.id }
    }

    private func persistKeyTimes() {
        if let data = try? JSONEncoder().encode(keyTimes) {
            UserDefaults.standard.set(data, forKey: Keys.keyTimes)
        }
    }
}
