//
//  WatchSettingsStore.swift
//  WearlyWatch
//
//  The watch's own copy of user settings — ranges, wardrobe, feels-like,
//  outfit bias, key times, rain threshold. Persisted to UserDefaults
//  and kept in sync with the paired iPhone via `WCSession` using a
//  last-writer-wins strategy based on `modifiedAt`.
//
//  The watch mirrors the iPhone's `SettingsViewModel` 1:1 so users get
//  full parity: you can change ranges, toggle wardrobe items, flip
//  feels-like, adjust rain sensitivity, etc. — from either device and
//  either device pushes to the other.
//
//  Sync rules
//    • Any local change bumps `modifiedAt` and immediately pushes to
//      the iPhone via `WCSession.updateApplicationContext` (background,
//      best-effort, survives sleep).
//    • On receive, the store compares timestamps and only applies the
//      incoming dict if it's newer than the local `modifiedAt`.
//    • A "Sync now" button forces a push regardless.
//    • First-time user is asked whether to auto-sync every change;
//      the answer is persisted in `autoSyncEnabled`.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Mirrored model types

/// A watch-side copy of the iPhone's ClothingItem. Kept dict-friendly
/// for WCSession serialization.
struct WatchClothingItem: Identifiable, Hashable, Codable {
    var id: String            // UUID string so it round-trips with iPhone
    var name: String
    var category: String      // "tops" / "bottoms" / "extras"
    var symbol: String
    var isEnabled: Bool
    var applicableRanges: [String]  // "freezing" / "cold" / ...
    var requiresRain: Bool
    var isOuterLayer: Bool

    var asDictionary: [String: Any] {
        [
            "id": id, "name": name, "category": category, "symbol": symbol,
            "isEnabled": isEnabled, "applicableRanges": applicableRanges,
            "requiresRain": requiresRain, "isOuterLayer": isOuterLayer
        ]
    }

    static func fromDict(_ d: [String: Any]) -> WatchClothingItem? {
        guard let id = d["id"] as? String,
              let name = d["name"] as? String,
              let category = d["category"] as? String,
              let symbol = d["symbol"] as? String,
              let isEnabled = d["isEnabled"] as? Bool,
              let applicableRanges = d["applicableRanges"] as? [String],
              let requiresRain = d["requiresRain"] as? Bool
        else { return nil }
        return WatchClothingItem(
            id: id, name: name, category: category, symbol: symbol,
            isEnabled: isEnabled, applicableRanges: applicableRanges,
            requiresRain: requiresRain,
            isOuterLayer: (d["isOuterLayer"] as? Bool) ?? false
        )
    }
}

struct WatchKeyTime: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var hour: Int
    var isEnabled: Bool

    var asDictionary: [String: Any] {
        ["id": id, "name": name, "hour": hour, "isEnabled": isEnabled]
    }

    static func fromDict(_ d: [String: Any]) -> WatchKeyTime? {
        guard let id = d["id"] as? String,
              let name = d["name"] as? String,
              let hour = d["hour"] as? Int,
              let isEnabled = d["isEnabled"] as? Bool
        else { return nil }
        return WatchKeyTime(id: id, name: name, hour: hour, isEnabled: isEnabled)
    }

    var formattedTime: String {
        let h = max(0, min(23, hour))
        let suffix = h < 12 ? "AM" : "PM"
        let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "\(display) \(suffix)"
    }
}

// MARK: - Store

@MainActor
final class WatchSettingsStore: ObservableObject {

    // See WatchWeatherStore for why this is declared explicitly.
    nonisolated let objectWillChange = ObservableObjectPublisher()

    // MARK: Published state

    @Published var freezingMax: Double  { didSet { didEdit() } }
    @Published var coldMax:     Double  { didSet { didEdit() } }
    @Published var mildMax:     Double  { didSet { didEdit() } }
    @Published var pleasantMax: Double  { didSet { didEdit() } }
    @Published var warmMax:     Double  { didSet { didEdit() } }

    @Published var useFeelsLike:  Bool    { didSet { didEdit() } }
    @Published var outfitBias:    String  { didSet { didEdit() } } // "warm"/"balanced"/"light"
    @Published var rainThreshold: Double  { didSet { didEdit() } }

    @Published var items:    [WatchClothingItem] { didSet { didEdit() } }
    @Published var keyTimes: [WatchKeyTime]      { didSet { didEdit() } }

    /// Local monotonic stamp; iPhone applies only if this is newer.
    @Published private(set) var modifiedAt: TimeInterval

    // MARK: Sync policy

    /// Whether every edit silently pushes to the iPhone. Toggled via
    /// the auto-sync confirmation dialog on first edit (see
    /// `promptedForAutoSync` below).
    @Published var autoSyncEnabled: Bool {
        didSet { defaults.set(autoSyncEnabled, forKey: K.autoSync) }
    }

    /// Whether the first-edit prompt has already been shown.
    @Published var promptedForAutoSync: Bool {
        didSet { defaults.set(promptedForAutoSync, forKey: K.prompted) }
    }

    /// UI state: `true` when a setting change happened but we haven't
    /// asked the user yet about auto-sync.
    @Published var showAutoSyncPrompt: Bool = false

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private var isApplyingRemote = false   // suppress re-push when receiver writes state
    private var syncTimer: Timer?

    // MARK: - Init

    init() {
        freezingMax = defaults.object(forKey: K.freezingMax) as? Double ?? 32
        coldMax     = defaults.object(forKey: K.coldMax)     as? Double ?? 50
        mildMax     = defaults.object(forKey: K.mildMax)     as? Double ?? 65
        pleasantMax = defaults.object(forKey: K.pleasantMax) as? Double ?? 75
        warmMax     = defaults.object(forKey: K.warmMax)     as? Double ?? 85

        useFeelsLike  = (defaults.object(forKey: K.useFeelsLike) as? Bool) ?? true
        outfitBias    = defaults.string(forKey: K.outfitBias) ?? "balanced"
        rainThreshold = defaults.object(forKey: K.rainThreshold) as? Double ?? 0.1

        if let data = defaults.data(forKey: K.items),
           let decoded = try? JSONDecoder().decode([WatchClothingItem].self, from: data) {
            items = decoded
        } else {
            items = Self.defaultItems
        }

        if let data = defaults.data(forKey: K.keyTimes),
           let decoded = try? JSONDecoder().decode([WatchKeyTime].self, from: data) {
            keyTimes = decoded
        } else {
            keyTimes = Self.defaultKeyTimes
        }

        modifiedAt         = defaults.object(forKey: K.modifiedAt) as? TimeInterval ?? 0
        autoSyncEnabled    = (defaults.object(forKey: K.autoSync) as? Bool) ?? false
        promptedForAutoSync = (defaults.object(forKey: K.prompted) as? Bool) ?? false
    }

    func start() {
        // Periodic safety-net push every 10 minutes, so if anything got
        // lost due to an asleep watch the iPhone still eventually gets
        // the latest state.
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                WatchConnectivitySync.shared.sendSettings(self.asDictionary)
            }
        }
    }

    // MARK: - Derived

    /// Whichever category a temperature falls into. Mirrors the iOS
    /// `TemperatureRanges.category(for:)` algorithm.
    func category(for temp: Double) -> String {
        if temp <= freezingMax { return "freezing" }
        if temp <= coldMax     { return "cold" }
        if temp <= mildMax     { return "mild" }
        if temp <= pleasantMax { return "pleasant" }
        if temp <= warmMax     { return "warm" }
        return "hot"
    }

    // MARK: - Edit hooks

    /// Called after every mutation. Persists, bumps modifiedAt, and
    /// fires sync (either automatic, or queued behind a confirmation
    /// prompt on first-ever edit).
    private func didEdit() {
        guard !isApplyingRemote else { return }
        persist()
        modifiedAt = Date().timeIntervalSince1970
        defaults.set(modifiedAt, forKey: K.modifiedAt)

        if autoSyncEnabled {
            WatchConnectivitySync.shared.sendSettings(asDictionary)
        } else if !promptedForAutoSync {
            // First-ever edit — ask the user whether to auto-sync.
            showAutoSyncPrompt = true
        }
    }

    // MARK: - Sync API

    /// Force-push the current settings. Called from the "Sync with
    /// iPhone" button.
    func syncNow() {
        WatchConnectivitySync.shared.sendSettings(asDictionary)
    }

    /// Answer to the first-edit auto-sync prompt.
    func setAutoSync(_ enabled: Bool) {
        autoSyncEnabled = enabled
        promptedForAutoSync = true
        if enabled { syncNow() }
    }

    /// Applies an incoming settings dict from the iPhone. Only wins if
    /// `modifiedAt` in the dict is newer than what we already have.
    func applyRemote(_ dict: [String: Any]) {
        guard let incoming = dict["modifiedAt"] as? TimeInterval else { return }
        // Within 1s we assume it's an echo of our own push and ignore.
        if incoming <= modifiedAt + 0.5 { return }

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        if let v = dict["freezingMax"]  as? Double { freezingMax  = v }
        if let v = dict["coldMax"]      as? Double { coldMax      = v }
        if let v = dict["mildMax"]      as? Double { mildMax      = v }
        if let v = dict["pleasantMax"]  as? Double { pleasantMax  = v }
        if let v = dict["warmMax"]      as? Double { warmMax      = v }
        if let v = dict["useFeelsLike"] as? Bool   { useFeelsLike = v }
        if let v = dict["outfitBias"]   as? String { outfitBias   = v }
        if let v = dict["rainThreshold"] as? Double { rainThreshold = v }

        if let rawItems = dict["items"] as? [[String: Any]] {
            items = rawItems.compactMap(WatchClothingItem.fromDict(_:))
        }
        if let rawKT = dict["keyTimes"] as? [[String: Any]] {
            keyTimes = rawKT.compactMap(WatchKeyTime.fromDict(_:))
        }

        modifiedAt = incoming
        persist()
        defaults.set(modifiedAt, forKey: K.modifiedAt)
    }

    // MARK: - Serialization

    /// Dictionary the iPhone (and our own sync button) pushes via
    /// `WCSession`. Keep keys stable between platforms.
    var asDictionary: [String: Any] {
        [
            "kind":          "settings",
            "modifiedAt":    modifiedAt,
            "freezingMax":   freezingMax,
            "coldMax":       coldMax,
            "mildMax":       mildMax,
            "pleasantMax":   pleasantMax,
            "warmMax":       warmMax,
            "useFeelsLike":  useFeelsLike,
            "outfitBias":    outfitBias,
            "rainThreshold": rainThreshold,
            "items":         items.map(\.asDictionary),
            "keyTimes":      keyTimes.map(\.asDictionary)
        ]
    }

    // MARK: - Persistence

    private func persist() {
        defaults.set(freezingMax,   forKey: K.freezingMax)
        defaults.set(coldMax,       forKey: K.coldMax)
        defaults.set(mildMax,       forKey: K.mildMax)
        defaults.set(pleasantMax,   forKey: K.pleasantMax)
        defaults.set(warmMax,       forKey: K.warmMax)
        defaults.set(useFeelsLike,  forKey: K.useFeelsLike)
        defaults.set(outfitBias,    forKey: K.outfitBias)
        defaults.set(rainThreshold, forKey: K.rainThreshold)
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: K.items)
        }
        if let data = try? JSONEncoder().encode(keyTimes) {
            defaults.set(data, forKey: K.keyTimes)
        }
    }

    private enum K {
        static let freezingMax   = "watch.freezingMax"
        static let coldMax       = "watch.coldMax"
        static let mildMax       = "watch.mildMax"
        static let pleasantMax   = "watch.pleasantMax"
        static let warmMax       = "watch.warmMax"
        static let useFeelsLike  = "watch.useFeelsLike"
        static let outfitBias    = "watch.outfitBias"
        static let rainThreshold = "watch.rainThreshold"
        static let items         = "watch.items"
        static let keyTimes      = "watch.keyTimes"
        static let modifiedAt    = "watch.modifiedAt"
        static let autoSync      = "watch.autoSync"
        static let prompted      = "watch.promptedForAutoSync"
    }

    // MARK: - Defaults

    private static let defaultItems: [WatchClothingItem] = [
        WatchClothingItem(id: UUID().uuidString, name: "Longsleeve",
                          category: "tops", symbol: "wearly.longsleeve.fill",
                          isEnabled: true, applicableRanges: ["freezing","cold"],
                          requiresRain: false, isOuterLayer: false),
        WatchClothingItem(id: UUID().uuidString, name: "T-shirt",
                          category: "tops", symbol: "wearly.tshirt.fill",
                          isEnabled: true, applicableRanges: ["mild","pleasant","warm","hot"],
                          requiresRain: false, isOuterLayer: false),
        WatchClothingItem(id: UUID().uuidString, name: "Light Hoodie",
                          category: "tops", symbol: "wearly.hoodie.fill",
                          isEnabled: true, applicableRanges: ["pleasant"],
                          requiresRain: false, isOuterLayer: true),
        WatchClothingItem(id: UUID().uuidString, name: "Sweatshirt",
                          category: "tops", symbol: "wearly.hoodie.fill",
                          isEnabled: true, applicableRanges: ["cold","mild"],
                          requiresRain: false, isOuterLayer: true),
        WatchClothingItem(id: UUID().uuidString, name: "Hoodie",
                          category: "tops", symbol: "wearly.hoodie.fill",
                          isEnabled: true, applicableRanges: ["freezing","cold","mild"],
                          requiresRain: false, isOuterLayer: true),
        WatchClothingItem(id: UUID().uuidString, name: "Shorts",
                          category: "bottoms", symbol: "wearly.shorts.fill",
                          isEnabled: true, applicableRanges: ["warm","hot"],
                          requiresRain: false, isOuterLayer: false),
        WatchClothingItem(id: UUID().uuidString, name: "Sweatpants",
                          category: "bottoms", symbol: "wearly.sweatpants.fill",
                          isEnabled: true, applicableRanges: ["freezing","cold","mild","pleasant"],
                          requiresRain: false, isOuterLayer: false),
        WatchClothingItem(id: UUID().uuidString, name: "Rain jacket",
                          category: "extras", symbol: "wearly.rainjacket.fill",
                          isEnabled: true,
                          applicableRanges: ["freezing","cold","mild","pleasant","warm","hot"],
                          requiresRain: true, isOuterLayer: false),
        WatchClothingItem(id: UUID().uuidString, name: "Winter jacket",
                          category: "extras", symbol: "wearly.winterjacket.fill",
                          isEnabled: true, applicableRanges: ["freezing","cold"],
                          requiresRain: false, isOuterLayer: false),
    ]

    private static let defaultKeyTimes: [WatchKeyTime] = [
        WatchKeyTime(id: UUID().uuidString, name: "Morning", hour: 8,  isEnabled: true),
        WatchKeyTime(id: UUID().uuidString, name: "Evening", hour: 18, isEnabled: true),
    ]
}
