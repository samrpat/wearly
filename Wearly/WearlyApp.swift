//
//  WearlyApp.swift
//  Wearly
//
//  Minimalist weather-based outfit recommender.
//

import SwiftUI

@main
struct WearlyApp: App {
    @StateObject private var settings = SettingsViewModel()
    @StateObject private var weather = WeatherViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(weather)
                .preferredColorScheme(.dark)
                .tint(.white)
                .onAppear {
                    // Bidirectional settings sync with the paired watch.
                    // Subscribes to local edits (so the watch mirrors
                    // iPhone changes) and installs the WCSessionDelegate
                    // that applies watch-initiated edits back onto
                    // `SettingsViewModel`.
                    PhoneWatchBridge.shared.start(settings: settings)
                }
        }
    }
}
