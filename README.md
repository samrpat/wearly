# Wearly

A minimalist iOS app that tells you what to wear based on real-time weather.
Open → glance → know → close. No clutter, no decisions.

## Philosophy

* **Single focus.** One weather line. One outfit. Nothing else.
* **Gesture-driven.** Swipe down to refresh, swipe left/right to cycle
  alternative outfits, tap for a subtle pulse. The only visible button is
  a low-opacity gear that opens Settings.
* **Calm.** Dark-mode-first, glassmorphic outfit card, soft colorful
  background that shifts with the temperature.

## Architecture

```
Wearly/
├── WearlyApp.swift              — entry point, wires up environment objects
├── ContentView.swift            — root, presents MainView + Settings sheet
├── Info.plist                   — only extra key: NSLocationWhenInUseUsageDescription
├── Assets.xcassets
│
├── Models/
│   ├── Weather.swift            — provider-agnostic weather model
│   ├── ClothingItem.swift       — enum of items + category + SF Symbol
│   ├── Outfit.swift             — named set of ClothingItems
│   └── TemperatureRanges.swift  — user-tunable thresholds
│
├── ViewModels/                  — MVVM, @MainActor ObservableObjects
│   ├── SettingsViewModel.swift  — persistence + notifications glue
│   └── WeatherViewModel.swift   — location + weather + outfit state
│
├── Views/
│   ├── MainView.swift           — single-focus screen & gestures
│   ├── OutfitCardView.swift     — glassmorphic hero card w/ float
│   ├── WeatherHeaderView.swift  — temp + condition pill
│   ├── SettingsView.swift       — sheet container
│   ├── ClothingToggleSection.swift
│   └── TemperatureRangeSection.swift
│
├── Services/
│   ├── LocationManager.swift    — CoreLocation wrapper
│   ├── WeatherService.swift     — Open-Meteo HTTP adapter (protocol-based)
│   └── NotificationManager.swift — daily outfit reminder
│
└── Utilities/
    ├── OutfitEngine.swift       — pure outfit rules
    ├── TemperatureGradient.swift— dark gradient per TempCategory
    ├── MinimalSlider.swift      — quiet custom slider
    └── HapticsManager.swift     — tiny UIKit haptic wrapper
```

## Requirements

* **Xcode 15+** and **iOS 17+** (uses `onChange(of:_:)` two-param form
  and `.presentationDetents`).
* **No paid Apple Developer account required.** Weather comes from
  [Open-Meteo](https://open-meteo.com) — free, keyless, no signup,
  non-commercial use. Signing the app with a free "Personal Team"
  (your Apple ID in Xcode → Settings → Accounts) is enough to run
  it on your own iPhone or the Simulator.

## Building

### Option A — XcodeGen (recommended)

```bash
brew install xcodegen     # once
cd /path/to/Wear
xcodegen generate         # produces Wearly.xcodeproj
open Wearly.xcodeproj
```

Then in Xcode:
1. Select the **Wearly** target → **Signing & Capabilities**.
2. Set **Team** to your free Personal Team (sign in with your Apple ID
   under *Xcode → Settings → Accounts* if you haven't already).
3. Run on the Simulator, or on an iPhone running iOS 17+.

No capabilities to enable. No API keys to paste.

### Option B — Create an Xcode project manually

1. In Xcode: **File → New → Project → iOS App**, named `Wearly`,
   interface `SwiftUI`, language `Swift`, min deployment `iOS 17.0`.
2. Delete the Xcode-generated `ContentView.swift` and `WearlyApp.swift`.
3. Drag the `Wearly/Models`, `ViewModels`, `Views`, `Services`,
   `Utilities` folders **and** the two root files (`WearlyApp.swift`,
   `ContentView.swift`) into the project, choosing "Create groups".
4. Open *Target → Info* and add **Privacy - Location When In Use Usage
   Description** with the text:
   `Wearly uses your location to fetch accurate local weather for outfit suggestions.`
   (Or replace the generated Info.plist with the one in this repo.)
5. Under *Signing & Capabilities*, pick your free Personal Team.
6. Build & run.

## Interactions

| Gesture              | Effect                                     |
|----------------------|--------------------------------------------|
| Swipe down           | Refresh weather (subtle arrow indicator)   |
| Swipe left           | Cycle to next alternative outfit           |
| Swipe right          | Cycle to previous alternative outfit       |
| Tap card             | Scale + 3-axis tilt pulse                  |
| Tap gear (top-right) | Open Settings sheet                        |

## Outfit rules (pure, in `OutfitEngine.swift`)

* **Cold** (`< coldMax`)  → hoodie + sweatpants (+ winter jacket)
* **Mild** (`coldMax..<mildMax`) → hoodie or t-shirt + sweatpants (or shorts)
* **Warm** (`mildMax..<warmMax`) → t-shirt + shorts (or sweatpants)
* **Hot**  (`≥ warmMax`) → t-shirt + shorts
* **Raining** → append rain jacket if enabled
* Only **enabled** items can ever appear.

Thresholds are user-tunable in Settings with monotonic constraints
(≥5°F gap between adjacent thresholds).

## Visual design

* Dark mode first.
* SF Pro Rounded for all text.
* `.ultraThinMaterial` outfit card with a soft gradient stroke.
* Background gradient changes with temperature category.
* All transitions: fade + scale, no hard cuts.
* Haptics: `light`/`soft` on swipes, `medium` on refresh, `selection` on toggles.

## Notes on the weather backend

Weather is fetched from [Open-Meteo](https://open-meteo.com) — free,
no API key, no signup — through a single `URLSession` call in
`OpenMeteoProvider`. The provider conforms to `WearlyWeatherProviding`,
so swapping in OpenWeather, Apple WeatherKit, or a mock for tests only
requires implementing the protocol and passing the new provider to
`WeatherViewModel(provider:)`.

Open-Meteo's terms are permissive for non-commercial use. If you plan
to distribute commercially, read their attribution / commercial-tier
policy first.
