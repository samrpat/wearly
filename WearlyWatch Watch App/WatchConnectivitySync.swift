//
//  WatchConnectivitySync.swift
//  WearlyWatch
//
//  Bidirectional WCSession bridge.
//
//  INCOMING (iPhone → watch)
//    • Payload dicts (the same shape the iOS widget reads) — piped into
//      `WatchWeatherStore.apply(payloadDict:)`.
//    • Settings dicts (`kind == "settings"`) — piped into
//      `WatchSettingsStore.applyRemote(_:)`.
//
//  OUTGOING (watch → iPhone)
//    • Settings dicts via `sendSettings(_:)`, which uses
//      `updateApplicationContext` (persists through sleep, replaces
//      older queued contexts) plus a live `sendMessage` if the iPhone
//      is reachable.
//

import Foundation
import WatchConnectivity

final class WatchConnectivitySync: NSObject, WCSessionDelegate {

    static let shared = WatchConnectivitySync()

    /// Set on startup by `WearlyWatchApp`.
    weak var weather:  WatchWeatherStore?
    weak var settings: WatchSettingsStore?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Outgoing

    /// Push the watch's settings to the iPhone. Best-effort.
    func sendSettings(_ dict: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        try? session.updateApplicationContext(dict)
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) { }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    // MARK: - Dispatch

    private func handle(_ dict: [String: Any]) {
        if (dict["kind"] as? String) == "settings" {
            Task { @MainActor in self.settings?.applyRemote(dict) }
            return
        }
        // Payload dicts have `weatherlyTemp` as their discriminator.
        if dict["weatherlyTemp"] != nil {
            Task { @MainActor in self.weather?.apply(payloadDict: dict) }
        }
    }
}
