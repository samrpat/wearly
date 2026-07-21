//
//  PhoneWatchSender.swift
//  Wearly
//
//  Bidirectional WCSession bridge on the iPhone.
//
//  OUTGOING
//    • `send(payload:)` — pushes the widget/outfit payload (called
//      from `WeatherViewModel.publishWidgetState`).
//    • `sendSettings()` — pushes the current `SettingsViewModel` state
//      (called when the user edits anything on the iPhone side).
//
//  INCOMING
//    • The watch pushes its own settings dicts back. The delegate
//      applies them to `SettingsViewModel` only if the incoming
//      `modifiedAt` is newer than what the iPhone already has.
//

import Foundation
import Combine
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class PhoneWatchBridge: NSObject, WCSessionDelegate {

    static let shared = PhoneWatchBridge()

    weak var settings: SettingsViewModel?

    private var didActivate = false
    /// Monotonic stamp of the most recently applied settings state on
    /// this device (local edit OR remote received).
    private var lastSettingsModifiedAt: TimeInterval = 0
    /// While true, outgoing settings pushes are suppressed — used
    /// during `applyRemoteSettings` so the echo doesn't race back to
    /// the watch and flap.
    private var isApplyingRemote = false

    private override init() { super.init() }

    // MARK: - Lifecycle

    /// Call once at app launch with the shared SettingsViewModel.
    @MainActor
    func start(settings: SettingsViewModel) {
        self.settings = settings
        ensureActivated()

        // Subscribe to local edits so the watch immediately mirrors any
        // iPhone change. We piggy-back on `objectWillChange` via a
        // debounced send at the next runloop tick.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self, let s = self.settings else { return }
                    if self.isApplyingRemote { return }
                    // Stamp the outgoing dict NOW so the watch can compare.
                    self.lastSettingsModifiedAt = Date().timeIntervalSince1970
                    self.sendSettings(from: s, stamp: self.lastSettingsModifiedAt)
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables: Set<AnyCancellable> = []

    private func ensureActivated() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported(), !didActivate else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        didActivate = true
        #endif
    }

    // MARK: - Outgoing — payload

    static func send(payload: [String: Any]) {
        Task { @MainActor in shared.sendPayload(payload) }
    }

    func sendPayload(_ payload: [String: Any]) {
        #if canImport(WatchConnectivity)
        ensureActivated()
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        try? session.updateApplicationContext(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        #endif
    }

    // MARK: - Outgoing — settings

    @MainActor
    func sendSettings(from settings: SettingsViewModel, stamp: TimeInterval) {
        #if canImport(WatchConnectivity)
        ensureActivated()
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let dict = Self.dictFromSettings(settings, modifiedAt: stamp)
        try? session.updateApplicationContext(dict)
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        }
        #endif
    }

    // MARK: - Incoming

    #if canImport(WatchConnectivity)
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) { }

    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }
    func session(_ session: WCSession, didReceiveApplicationContext ctx: [String: Any]) {
        handle(ctx)
    }
    #endif

    private func handle(_ dict: [String: Any]) {
        guard (dict["kind"] as? String) == "settings" else { return }
        guard let incoming = dict["modifiedAt"] as? TimeInterval else { return }
        guard incoming > lastSettingsModifiedAt + 0.5 else { return }

        Task { @MainActor in
            guard let s = self.settings else { return }
            self.applyRemoteSettings(dict, to: s)
            self.lastSettingsModifiedAt = incoming
        }
    }

    // MARK: - Serialization

    @MainActor
    static func dictFromSettings(_ s: SettingsViewModel, modifiedAt: TimeInterval) -> [String: Any] {
        let itemDicts: [[String: Any]] = s.items.map { item in
            [
                "id": item.id.uuidString,
                "name": item.name,
                "category": item.category.rawValue.lowercased(),
                "symbol": item.symbol,
                "isEnabled": item.isEnabled,
                "applicableRanges": item.applicableRanges.map { $0.rawValue },
                "requiresRain": item.requiresRain,
                "isOuterLayer": item.isOuterLayer
            ]
        }
        let keyTimeDicts: [[String: Any]] = s.keyTimes.map { kt in
            [
                "id": kt.id.uuidString,
                "name": kt.name,
                "hour": kt.hour,
                "isEnabled": kt.isEnabled
            ]
        }
        return [
            "kind": "settings",
            "modifiedAt": modifiedAt,
            "freezingMax": s.freezingMax,
            "coldMax": s.coldMax,
            "mildMax": s.mildMax,
            "pleasantMax": s.pleasantMax,
            "warmMax": s.warmMax,
            "useFeelsLike": s.useFeelsLike,
            "outfitBias": s.outfitBias.rawValue,
            "rainThreshold": s.rainThreshold,
            "items": itemDicts,
            "keyTimes": keyTimeDicts
        ]
    }

    @MainActor
    private func applyRemoteSettings(_ dict: [String: Any], to s: SettingsViewModel) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        if let v = dict["freezingMax"]  as? Double { s.freezingMax  = v }
        if let v = dict["coldMax"]      as? Double { s.coldMax      = v }
        if let v = dict["mildMax"]      as? Double { s.mildMax      = v }
        if let v = dict["pleasantMax"]  as? Double { s.pleasantMax  = v }
        if let v = dict["warmMax"]      as? Double { s.warmMax      = v }
        if let v = dict["useFeelsLike"] as? Bool   { s.useFeelsLike = v }
        if let v = dict["rainThreshold"] as? Double { s.rainThreshold = v }
        if let raw = dict["outfitBias"] as? String,
           let bias = OutfitBias(rawValue: raw) { s.outfitBias = bias }

        if let rawItems = dict["items"] as? [[String: Any]] {
            let decoded: [ClothingItem] = rawItems.compactMap { d in
                guard let idStr = d["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let name = d["name"] as? String,
                      let catRaw = d["category"] as? String,
                      let category = ClothingItem.Category(rawValue: catRaw.capitalized),
                      let symbol = d["symbol"] as? String,
                      let isEnabled = d["isEnabled"] as? Bool,
                      let rangesRaw = d["applicableRanges"] as? [String],
                      let requiresRain = d["requiresRain"] as? Bool
                else { return nil }
                let ranges = Set(rangesRaw.compactMap(TempCategory.init(rawValue:)))
                return ClothingItem(
                    id: id,
                    name: name,
                    category: category,
                    symbol: symbol,
                    isEnabled: isEnabled,
                    applicableRanges: ranges,
                    requiresRain: requiresRain,
                    isOuterLayer: (d["isOuterLayer"] as? Bool) ?? false
                )
            }
            s.items = decoded
        }

        if let rawKT = dict["keyTimes"] as? [[String: Any]] {
            let decoded: [KeyTime] = rawKT.compactMap { d in
                guard let idStr = d["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      let name = d["name"] as? String,
                      let hour = d["hour"] as? Int,
                      let isEnabled = d["isEnabled"] as? Bool
                else { return nil }
                return KeyTime(id: id, name: name, hour: hour, isEnabled: isEnabled)
            }
            s.keyTimes = decoded
        }
    }
}

// Small shim so existing WeatherViewModel call-site keeps working.
enum PhoneWatchSender {
    static func send(payload: [String: Any]) {
        PhoneWatchBridge.send(payload: payload)
    }
}
