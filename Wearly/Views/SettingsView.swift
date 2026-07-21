//
//  SettingsView.swift
//  Wearly
//
//  Four quiet sections: Preferences (feels-like), Wardrobe, Temperature
//  ranges, and Notifications.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.05, blue: 0.09),
                        Color(red: 0.08, green: 0.09, blue: 0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        PreferencesSection()
                        LocationSection()
                        KeyTimesSection()
                        ClothingToggleSection()
                        TemperatureRangeSection()
                        NotificationsSection()
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preferences

private struct PreferencesSection: View {
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Preferences")

            VStack(spacing: 0) {
                // Feels-like
                HStack {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dress for feels-like")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                        Text("Use apparent temperature when picking outfits")
                            .font(.system(size: 11, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    Toggle("", isOn: $settings.useFeelsLike)
                        .labelsHidden()
                        .tint(CategoryPalette.brand)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(.white.opacity(0.06)).padding(.leading, 52)

                // Outfit bias (how to dress on big-swing days)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("How you dress")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.white.opacity(0.92))
                            Text(settings.outfitBias.blurb)
                                .font(.system(size: 11, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                    }

                    Picker("", selection: $settings.outfitBias) {
                        ForEach(OutfitBias.allCases) { bias in
                            Text(bias.display).tag(bias)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.leading, 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider().background(.white.opacity(0.06)).padding(.leading, 52)

                // Rain threshold — how much precipitation (mm/h) at a
                // key time before a rain jacket gets suggested.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        Image(systemName: "cloud.rain")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(.white.opacity(0.75))
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rain sensitivity")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.white.opacity(0.92))
                            Text(rainBlurb(settings.rainThreshold))
                                .font(.system(size: 11, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                        Text(String(format: "%.1f mm/h", settings.rainThreshold))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .monospacedDigit()
                    }

                    Slider(
                        value: $settings.rainThreshold,
                        in: 0.0...2.0,
                        step: 0.1
                    )
                    .tint(CategoryPalette.brand)
                    .padding(.leading, 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    /// Plain-English description of the current rain threshold.
    private func rainBlurb(_ value: Double) -> String {
        switch value {
        case ..<0.05:  return "Rain jacket for any detected drop."
        case ..<0.25:  return "Rain jacket for light rain or more."
        case ..<0.75:  return "Only for steady rain."
        default:       return "Only for heavy rain."
        }
    }
}

// MARK: - Key times

/// Lets the user name the moments of the day that matter — morning
/// walk, evening commute — and pin each to a specific hour. The outfit
/// algorithm samples weather at exactly those hours to decide what to
/// wear (dressing for the coldest moment, flagging rain gear if any
/// sample is wet).
private struct KeyTimesSection: View {
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Key times")

            Text("The outfit is chosen for the moments you actually go outside. Add the times you walk to school, leave work, or anything else.")
                .font(.system(size: 12, weight: .light, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach($settings.keyTimes) { $time in
                    KeyTimeRow(time: $time,
                               onDelete: { settings.deleteKeyTime(time) })
                    Divider().background(.white.opacity(0.04)).padding(.leading, 52)
                }

                Button {
                    HapticsManager.light()
                    settings.addKeyTime(name: "New", hour: 12)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 22)
                        Text("Add time")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }
}

/// A single editable key-time row. Tap the name to rename, tap the time
/// to pick an hour from a menu, toggle to disable, trailing chevron +
/// hold-to-delete via confirmation dialog.
private struct KeyTimeRow: View {
    @Binding var time: KeyTime
    let onDelete: () -> Void

    @State private var showingDelete = false
    @FocusState private var isEditingName: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: time.iconSymbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(time.isEnabled
                                 ? CategoryPalette.brand
                                 : .white.opacity(0.3))
                .frame(width: 22)
                .contentTransition(.symbolEffect(.replace))

            TextField("Name", text: $time.name)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(time.isEnabled ? 0.92 : 0.4))
                .focused($isEditingName)
                .submitLabel(.done)

            Spacer(minLength: 8)

            Menu {
                ForEach(0..<24) { h in
                    Button(Self.formatHour(h)) { time.hour = h }
                }
            } label: {
                Text(time.formattedTime)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(time.isEnabled ? 0.85 : 0.35))
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.06)))
            }

            Toggle("", isOn: $time.isEnabled)
                .labelsHidden()
                .tint(CategoryPalette.brand)
                .scaleEffect(0.85)

            Button {
                showingDelete = true
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .confirmationDialog("Delete \(time.name)?",
                            isPresented: $showingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                HapticsManager.medium()
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private static func formatHour(_ h: Int) -> String {
        let hour = max(0, min(23, h))
        let suffix = hour < 12 ? "AM" : "PM"
        let display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(display) \(suffix)"
    }
}

// MARK: - Notifications

private struct NotificationsSection: View {
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Notifications")

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "bell")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily outfit")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                        Text("\(Self.formatTime(settings.notificationHour, settings.notificationMinute)) reminder")
                            .font(.system(size: 12, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Toggle("", isOn: $settings.notificationsEnabled)
                        .labelsHidden()
                        .tint(CategoryPalette.brand)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if settings.notificationsEnabled {
                    Divider().background(.white.opacity(0.06)).padding(.leading, 52)

                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 22)

                        Text("Time")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.88))

                        Spacer()

                        DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .environment(\.colorScheme, .dark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = settings.notificationHour
                c.minute = settings.notificationMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings.notificationHour = c.hour ?? 6
                settings.notificationMinute = c.minute ?? 40
            }
        )
    }

    private static func formatTime(_ hour: Int, _ minute: Int) -> String {
        let h = max(0, min(23, hour))
        let m = max(0, min(59, minute))
        let suffix = h < 12 ? "AM" : "PM"
        let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", display, m, suffix)
    }
}

// MARK: - Location

/// Lets the user pick a custom city to fetch weather for (useful for
/// previewing another location) or fall back to the device's current
/// GPS. Uses `CLGeocoder` via `SettingsViewModel.resolveCustomLocation`.
private struct LocationSection: View {
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var query: String = ""
    @State private var status: Status = .idle

    enum Status: Equatable {
        case idle, searching, error(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Location")

            VStack(spacing: 0) {
                // Toggle row — device GPS vs. custom city.
                HStack {
                    Image(systemName: settings.useCustomLocation ? "mappin.and.ellipse" : "location")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom location")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                        Text(subtitle)
                            .font(.system(size: 11, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(2)
                    }

                    Spacer()

                    Toggle("", isOn: $settings.useCustomLocation)
                        .labelsHidden()
                        .tint(CategoryPalette.brand)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // Search row — only visible when custom mode is on.
                if settings.useCustomLocation {
                    Divider().background(.white.opacity(0.06)).padding(.leading, 52)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 22)

                        TextField("City, e.g. Tokyo", text: $query)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit { Task { await resolve() } }

                        if case .searching = status {
                            ProgressView().tint(CategoryPalette.brand)
                        } else {
                            Button("Set") { Task { await resolve() } }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(CategoryPalette.brand)
                                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if case .error(let msg) = status {
                        Text(msg)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.red.opacity(0.85))
                            .padding(.horizontal, 52)
                            .padding(.bottom, 10)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
        .onAppear {
            query = settings.customLocationResolved?.name ?? ""
        }
    }

    private var subtitle: String {
        if settings.useCustomLocation {
            if let resolved = settings.customLocationResolved {
                return "Using \(resolved.name)"
            }
            return "Enter a city below to start."
        }
        return "Using your device's current location."
    }

    @MainActor
    private func resolve() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        status = .searching
        HapticsManager.light()
        do {
            try await settings.resolveCustomLocation(query: trimmed)
            status = .idle
            HapticsManager.medium()
            if let resolved = settings.customLocationResolved {
                query = resolved.name
            }
        } catch {
            status = .error(error.localizedDescription)
            HapticsManager.light()
        }
    }
}

// MARK: - Reusable label

struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.4))
            .textCase(.uppercase)
            .tracking(1.2)
            .padding(.leading, 4)
    }
}
