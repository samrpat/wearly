//
//  MainView.swift
//  Wearly
//
//  Single-focus main screen. The weather lives in the animated
//  background. The clothing lives at the center. Everything else is
//  orientation only: a tiny info pill on top and a thin 7-day
//  timeline on the bottom.
//
//  Motion style is deliberately slow + eased — nothing here springs or
//  pops. Calm → effortless decision.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject private var weatherVM: WeatherViewModel
    @EnvironmentObject private var settings: SettingsViewModel
    @Binding var showingSettings: Bool

    @State private var dragOffset: CGSize = .zero
    @State private var cardScale: CGFloat = 1.0
    @State private var refreshIndicatorOpacity: Double = 0
    @State private var gearRotation: Double = 0
    /// Bumps whenever the mannequin should re-assemble (day/outfit change).
    @State private var assemblyToken: UUID = UUID()

    var body: some View {
        ZStack {
            TemperatureGradient(
                category: currentCategory,
                condition: weatherVM.displayWeather?.condition ?? .cloudy,
                isRaining: weatherVM.displayWeather?.isRaining ?? false
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.6), value: currentCategory)
            .animation(.easeInOut(duration: 1.0), value: weatherVM.displayWeather?.condition)

            VStack(spacing: 0) {
                WeatherHeaderView(
                    weather: weatherVM.displayWeather,
                    realTemp: weatherVM.currentWeather?.temperature,
                    effectiveTemp: weatherVM.weatherlyTemperature,
                    usingFeelsLike: settings.useFeelsLike && (weatherVM.displayWeather?.feelsLike != nil),
                    category: currentCategory,
                    high: weatherVM.selectedHigh,
                    low: weatherVM.selectedLow,
                    dayLabel: weatherVM.selectedDayLabel,
                    dateShort: weatherVM.selectedDateShort,
                    lastUpdated: weatherVM.lastUpdated,
                    showsLastUpdated: weatherVM.shouldShowLastUpdated,
                    locationName: weatherVM.locationName
                )
                .padding(.top, 16)
                .opacity(weatherVM.isLoading ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.4), value: weatherVM.isLoading)

                Spacer()

                cardArea

                Spacer()

                if !weatherVM.forecast.isEmpty {
                    DaySelectorView(
                        days: weatherVM.forecast,
                        selectedIndex: $weatherVM.selectedDayOffset
                    )
                    .padding(.bottom, 10)
                }
            }

            // Pull-down refresh hint.
            VStack {
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 70)
                    .opacity(refreshIndicatorOpacity)
                Spacer()
            }
            .allowsHitTesting(false)

            // Settings gear — small, monochrome, quiet.
            VStack {
                HStack {
                    Spacer()
                    Button {
                        HapticsManager.light()
                        withAnimation(.easeInOut(duration: 0.6)) {
                            gearRotation += 90
                        }
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(.white.opacity(0.35))
                            .rotationEffect(.degrees(gearRotation))
                            .padding(16)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Settings")
                }
                Spacer()
            }
        }
        // `simultaneousGesture` at the root means horizontal swipes work
        // anywhere on the screen (on the card, on empty space, even over
        // the day markers) without clobbering taps on inner buttons.
        .simultaneousGesture(gesture)
        .onAppear {
            weatherVM.bootstrap(settings: settings)
        }
        // Re-assemble the mannequin whenever the outfit or day changes.
        .onChange(of: weatherVM.selectedDayOffset) { _, _ in assemblyToken = UUID() }
        .onChange(of: weatherVM.currentOutfit?.id) { _, _ in assemblyToken = UUID() }
        .onChange(of: settings.items)           { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.freezingMax)     { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.coldMax)         { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.mildMax)         { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.pleasantMax)     { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.warmMax)         { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.useFeelsLike) { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.outfitBias)   { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.keyTimes)     { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.rainThreshold) { _, _ in weatherVM.recomputeOutfits() }
        .onChange(of: settings.useCustomLocation)      { _, _ in Task { await weatherVM.refresh() } }
        .onChange(of: settings.customLocationResolved) { _, _ in Task { await weatherVM.refresh() } }
    }

    // MARK: - Card area

    @ViewBuilder
    private var cardArea: some View {
        if let outfit = weatherVM.currentOutfit {
            OutfitCardView(
                outfit: outfit,
                accent: CategoryPalette.primary(currentCategory),
                headline: OutfitTagline.headline(weather: weatherVM.displayWeather,
                                                 category: currentCategory),
                contextLine: contextLineForCard,
                assemblyToken: assemblyToken,
                dragDelta: dragOffset.width
            )
            .scaleEffect(cardScale)
            // A small 2D card tilt reinforces direction during a day swipe.
            .rotationEffect(.degrees(Double(dragOffset.width) * 0.03))
            .offset(y: max(0, dragOffset.height) * 0.2)
            .onTapGesture { tapPulse() }
        } else if weatherVM.isLoading {
            ProgressView().tint(.white.opacity(0.6))
        } else {
            emptyState
        }
    }

    // MARK: - Narrative context line

    /// Preferred: narrative from `DaypartAnalyzer` (e.g., "Dressing for morning · 42°"
    /// or "Rain at Evening · 6 PM"). Phrasing reflects the user's bias.
    private var contextLineForCard: String? {
        if let summary = weatherVM.daypartSummary,
           let narrative = DaypartAnalyzer.narrative(for: summary,
                                                     bias: settings.outfitBias) {
            return narrative
        }
        return OutfitTagline.contextLine(weather: weatherVM.displayWeather,
                                         usingFeelsLike: settings.useFeelsLike)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateSymbol)
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.35))
            Text(emptyStateMessage)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
    }

    private var emptyStateSymbol: String {
        if weatherVM.authorizationStatus == .denied { return "location.slash" }
        if weatherVM.displayWeather != nil && weatherVM.alternatives.isEmpty { return "tshirt" }
        return "cloud"
    }

    private var emptyStateMessage: String {
        if let err = weatherVM.errorMessage { return err }
        if weatherVM.authorizationStatus == .denied {
            return "Enable location in Settings"
        }
        if weatherVM.displayWeather != nil && weatherVM.alternatives.isEmpty {
            return "Nothing in your wardrobe fits \(currentCategory.display.lowercased()) weather yet."
        }
        return "Getting the weather…"
    }

    // MARK: - Gestures

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                dragOffset = v.translation
                refreshIndicatorOpacity = min(Double(max(0, v.translation.height)) / 160, 1)
            }
            .onEnded { v in
                let horizontal = v.translation.width
                let vertical = v.translation.height
                let horizontalSwipe = abs(horizontal) > 45 && abs(horizontal) > abs(vertical)
                let downwardPull = vertical > 110 && vertical > abs(horizontal)

                if downwardPull {
                    HapticsManager.medium()
                    Task { await weatherVM.refresh() }
                } else if horizontalSwipe {
                    changeDay(by: horizontal < 0 ? +1 : -1)
                }

                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    dragOffset = .zero
                    refreshIndicatorOpacity = 0
                }
            }
    }

    private func changeDay(by delta: Int) {
        let maxIndex = max(0, weatherVM.forecast.count - 1)
        let target = weatherVM.selectedDayOffset + delta
        if target < 0 || target > maxIndex {
            HapticsManager.light()
            // Bounce the card back against the boundary.
            let wiggle: CGFloat = delta > 0 ? -14 : 14
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                dragOffset.width = wiggle
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.1)) {
                dragOffset.width = 0
            }
            return
        }
        HapticsManager.soft()
        withAnimation(.easeInOut(duration: 0.55)) {
            weatherVM.selectedDayOffset = target
        }
    }

    private func tapPulse() {
        HapticsManager.light()
        withAnimation(.easeInOut(duration: 0.22)) { cardScale = 0.97 }
        withAnimation(.easeInOut(duration: 0.45).delay(0.12)) { cardScale = 1.0 }
    }

    // MARK: - Derived

    private var currentCategory: TempCategory {
        guard let temp = weatherVM.weatherlyTemperature else { return .mild }
        return settings.ranges.category(for: temp)
    }
}

// MARK: - Helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
