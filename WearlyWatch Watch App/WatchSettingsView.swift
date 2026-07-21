//
//  WatchSettingsView.swift
//  WearlyWatch
//
//  Swipe between two pages: Settings and Wardrobe.
//
//  Settings — feels-like, how-you-dress bias, rain threshold, range
//             sliders, key times, and the "Sync with iPhone" button.
//  Wardrobe — list of clothing items; tap one to edit its
//             applicable ranges, rain-only flag, and outer-layer flag
//             (full parity with the iOS edit screen).
//
//  Both pages share the same `WatchSettingsStore` so every edit flows
//  through `didEdit` → auto-sync to iPhone (if enabled).
//

import SwiftUI

/// Root three-page swipeable container for the watch app:
///
///     ◀︎ Settings   |   Weatherly (center)   |   Wardrobe ▶︎
///
/// Start page is the center so a fresh launch shows the current
/// Weatherly temp immediately. Swipe left → Settings, swipe right →
/// Wardrobe. Auto-sync confirmation dialog lives here so it can
/// appear regardless of which page the user is on when they first
/// edit a setting.
struct WatchMainTabs: View {
    @EnvironmentObject var settings: WatchSettingsStore
    @State private var page: Int = 1  // center

    var body: some View {
        TabView(selection: $page) {
            NavigationStack {
                SettingsPage()
                    .environmentObject(settings)
                    .navigationTitle("Settings")
            }
            .tag(0)

            WatchRootView()
                .tag(1)

            NavigationStack {
                WardrobePage()
                    .environmentObject(settings)
                    .navigationTitle("Wardrobe")
            }
            .tag(2)
        }
        .tabViewStyle(.page)
        .confirmationDialog(
            "Auto-sync settings with iPhone?",
            isPresented: $settings.showAutoSyncPrompt,
            titleVisibility: .visible
        ) {
            Button("Yes, auto-sync") { settings.setAutoSync(true) }
            Button("Only on demand") { settings.setAutoSync(false) }
        } message: {
            Text("Watch edits will push to the iPhone in the background. You can still tap Sync anytime.")
        }
    }
}

// MARK: - Settings page

struct SettingsPage: View {
    @EnvironmentObject var settings: WatchSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                syncButton

                section("Preferences") {
                    Toggle("Feels-like", isOn: $settings.useFeelsLike)
                    howYouDress
                    rainSlider
                }

                section("Ranges (°F)") {
                    rangeSlider("Freezing ≤", value: $settings.freezingMax, in: 0...50)
                    rangeSlider("Cold ≤",     value: $settings.coldMax,     in: 20...65)
                    rangeSlider("Mild ≤",     value: $settings.mildMax,     in: 35...75)
                    rangeSlider("Pleasant ≤", value: $settings.pleasantMax, in: 50...85)
                    rangeSlider("Warm ≤",     value: $settings.warmMax,     in: 65...100)
                }

                section("Key times") {
                    ForEach($settings.keyTimes) { $kt in
                        HStack(spacing: 6) {
                            Text(kt.name).font(.system(size: 13)).lineLimit(1)
                            Spacer()
                            Text(kt.formattedTime)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Toggle("", isOn: $kt.isEnabled).labelsHidden()
                        }
                    }
                }

                Text(autoSyncFooter)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }

    // MARK: Pieces

    private var syncButton: some View {
        Button {
            settings.syncNow()
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Sync with iPhone")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                if settings.autoSyncEnabled {
                    Text("AUTO")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.green.opacity(0.30)))
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    /// The "how you dress" bias picker — warm / balanced / light.
    private var howYouDress: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("How you dress")
                .font(.system(size: 13))
            Picker("", selection: $settings.outfitBias) {
                Text("Warm").tag("warm")
                Text("Balanced").tag("balanced")
                Text("Light").tag("light")
            }
            .labelsHidden()
            .pickerStyle(.navigationLink)
        }
    }

    private var rainSlider: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Rain sensitivity").font(.system(size: 13))
                Spacer()
                Text(String(format: "%.1f mm/h", settings.rainThreshold))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.rainThreshold, in: 0...2, step: 0.1)
        }
    }

    private func rangeSlider(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 12))
                Spacer()
                Text("\(Int(value.wrappedValue))°")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: 1)
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
        }
    }

    private var autoSyncFooter: String {
        settings.autoSyncEnabled
            ? "Auto-sync is on. Changes push to iPhone automatically."
            : "Auto-sync is off. Tap Sync to push changes."
    }
}

// MARK: - Wardrobe page

struct WardrobePage: View {
    @EnvironmentObject var settings: WatchSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tap an item to edit its ranges, rain, and outer layer.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                ForEach($settings.items) { $item in
                    NavigationLink {
                        WatchClothingItemEditor(item: $item)
                    } label: {
                        HStack(spacing: 8) {
                            WatchClothingIcon(
                                symbol: item.symbol,
                                size: 20,
                                color: WatchRoleTint.color(for: roleFor(item))
                            )
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(summary(for: item))
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Toggle("", isOn: $item.isEnabled)
                                .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
    }

    private func summary(for item: WatchClothingItem) -> String {
        var bits: [String] = []
        if !item.applicableRanges.isEmpty {
            bits.append(item.applicableRanges.map { $0.prefix(2).uppercased() }.joined(separator: "·"))
        }
        if item.isOuterLayer { bits.append("Outer") }
        if item.requiresRain { bits.append("Rain") }
        return bits.joined(separator: " · ")
    }

    private func roleFor(_ item: WatchClothingItem) -> String {
        let s = item.symbol.lowercased()
        let n = item.name.lowercased()
        if s.contains("rainjacket") || n.contains("rain") { return "rain" }
        if s.contains("winterjacket") || n.contains("winter") { return "winter" }
        switch item.category {
        case "tops":    return item.isOuterLayer ? "outer" : "base"
        case "bottoms": return "bottom"
        default:        return "extra"
        }
    }
}

// MARK: - Per-item editor

private let allZones: [(raw: String, label: String)] = [
    ("freezing", "Freezing"),
    ("cold",     "Cold"),
    ("mild",     "Mild"),
    ("pleasant", "Pleasant"),
    ("warm",     "Warm"),
    ("hot",      "Hot")
]

struct WatchClothingItemEditor: View {
    @Binding var item: WatchClothingItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Name + silhouette preview
                HStack(spacing: 10) {
                    WatchClothingIcon(
                        symbol: item.symbol,
                        size: 28,
                        color: .white.opacity(0.95)
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.name)
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.category.capitalized)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))

                section("Active ranges") {
                    ForEach(allZones, id: \.raw) { zone in
                        let isOn = item.applicableRanges.contains(zone.raw)
                        Toggle(zone.label, isOn: Binding(
                            get: { isOn },
                            set: { newVal in
                                if newVal {
                                    if !item.applicableRanges.contains(zone.raw) {
                                        item.applicableRanges.append(zone.raw)
                                    }
                                } else {
                                    item.applicableRanges.removeAll { $0 == zone.raw }
                                }
                            }
                        ))
                        .font(.system(size: 13))
                    }
                }

                section("Flags") {
                    Toggle("Requires rain", isOn: $item.requiresRain)
                        .font(.system(size: 13))
                    if item.category == "tops" {
                        Toggle("Outer layer", isOn: $item.isOuterLayer)
                            .font(.system(size: 13))
                    }
                    Toggle("Enabled", isOn: $item.isEnabled)
                        .font(.system(size: 13))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .navigationTitle(item.name)
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
        }
    }
}
