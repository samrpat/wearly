//
//  WearlyWatchApp.swift
//  WearlyWatch
//
//  Owns both stores (weather + settings) and the WCSession bridge.
//  Settings flow bidirectionally: iPhone pushes on every forecast,
//  watch pushes on every edit (optionally silent via auto-sync).
//

import SwiftUI

@main
struct WearlyWatchApp: App {
    @StateObject private var weather  = WatchWeatherStore()
    @StateObject private var settings = WatchSettingsStore()

    var body: some Scene {
        WindowGroup {
            WatchMainTabs()
                .environmentObject(weather)
                .environmentObject(settings)
            .onAppear {
                // Wire up the WCSession bridge with references to both
                // stores, then activate.
                WatchConnectivitySync.shared.weather  = weather
                WatchConnectivitySync.shared.settings = settings
                WatchConnectivitySync.shared.activate()

                // Give the weather store access to settings so
                // standalone outfit picks honor the user's wardrobe
                // and ranges.
                weather.settings = settings

                settings.start()
                weather.bootstrap()
            }
        }
    }
}
