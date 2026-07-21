//
//  ContentView.swift
//  Wearly
//
//  The root view. A single-focus main screen with a subtle
//  gateway to settings via a sheet presentation.
//

import SwiftUI

struct ContentView: View {
    @State private var showingSettings = false

    var body: some View {
        MainView(showingSettings: $showingSettings)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.black.opacity(0.9))
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsViewModel())
        .environmentObject(WeatherViewModel())
}
