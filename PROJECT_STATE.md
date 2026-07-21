# Wearly — Key Decisions & Current State

## Core product

- **iOS 17+ SwiftUI app** that tells you what to wear based on real-time weather. Single-focus main screen, gesture-driven, dark-mode first.
- **No paid Apple Developer account required.** Weather via Open-Meteo (free, keyless, no signup). Location via CoreLocation. No WeatherKit.
- **MVVM architecture.** `WeatherViewModel` + `SettingsViewModel` as `@MainActor ObservableObject`s; views observe them.

## Architecture decisions

- **`OutfitEngine`** = pure generator: `(weather, ranges, wardrobe) → Outfit`. One outfit per day (not multiple alternatives).
- **`DaypartAnalyzer`** owns the "which temperature to dress for" decision, independent of the engine.
- **Provider-agnostic weather** via `WearlyWeatherProviding`. `OpenMeteoProvider` is the concrete impl; `WeatherKitProvider` was removed when we dropped the paid-account requirement.
- **Outfit `id` = stable hash of item IDs** so SwiftUI doesn't re-animate the card when the outfit is unchanged.

## Weather algorithm (DaypartAnalyzer)

Simple recipe, in order:
1. **Baseline = (day.high + day.low) / 2** — midpoint of day's actual swing.
2. **Blend 50/50** with the average temperature at the user's enabled **key times**.
3. **Feels-like adjustment**, capped at ±4°F so solar boosts don't dominate cool days.
4. **Bias nudge**: ±4°F based on "How you dress" (warm/balanced/light).
5. **Rain gear** triggers if the day is rainy OR any key-time hour has precipitation > 0.1 mm.
6. Returns `DaypartSummary` with `weatherlyTemp` (the internal name — UI still says "Dressing for X°"), `minTemp`, `maxTemp`, `needsRainGear`, and per-key-time `samples`.

## Clothing system

- **6 temperature categories**: Freezing / Cold / Mild / Pleasant / Warm / Hot.
- **Each `ClothingItem`** has: name, category (tops/bottoms/extras), symbol, `isEnabled`, `applicableRanges: Set<TempCategory>`, `requiresRain`, `isOuterLayer`.
- **Layering rule**: when both a base top and an outer-layer top are applicable, the engine stacks them (outer renders over base). If no explicit outer exists, it infers from symbol/name (anything with "hoodie"/"cardigan"/"sweater"/"pullover" → outer).
- **Smart defaults** on item creation: auto-enable `isOuterLayer` if the chosen symbol or name suggests a hoodie/cardigan/sweater.
- **New items** inserted at the top of their category + default `applicableRanges` = all ranges, so they show up immediately.
- **One-time migration** promotes any existing hoodie-named item to `isOuterLayer = true`.
- **Per-garment tint palette** replaces an earlier vibe system: base top = cream, outer top = terracotta, bottom = denim, rain jacket = navy, winter jacket = light snowy gray, other extras = tan.

## User-configurable state (`SettingsViewModel`)

- Wardrobe (CRUD + reset to defaults)
- Temperature thresholds (cascading monotonic sliders; ≥5°F gap between adjacent zones)
- `useFeelsLike` toggle (default true)
- `outfitBias: OutfitBias` — `.warm` / `.balanced` / `.light`
- `keyTimes: [KeyTime]` — named moments of the day (8 AM "Morning", 6 PM "Evening") user can CRUD
- `notificationsEnabled` + `notificationHour` (default 6) + `notificationMinute` (default 40)
- `useCustomLocation` + `customLocationResolved: ResolvedLocation?` via `CLGeocoder`

All persisted to `UserDefaults`. Wardrobe stored as JSON under `wardrobe.v2` with backwards-compatible Codable decoder.

## Main screen (`MainView`)

- **Scenic background** (`TemperatureGradient`): sky gradient → sun/moon → three mountain layers (back/mid/front) → pine tree cluster → ground strip → weather particle overlay → readability darken. Palette shifts with category.
- **Weather particles**: rain (diagonal streaks via `Canvas`), snow (drifting flakes), wind streaks, fog bands. Density lowered for atmosphere not storm.
- **Header**: condition icon · weatherly temp · H/L chip · day label · "Updated X ago" (live-ticking).
- **Outfit card**:
  - No material/border/chrome — defined by shape + shadow.
  - **Mannequin scales by row count** (2 rows = 1.0 scale, 5+ rows = 0.6) instead of overlapping, so layout stays constant.
  - Each `GarmentPiece` has a colored halo background, volumetric gradient, soft shadow, intro stagger (delayed spring per piece), idle float, tap wiggle (+15° rotation + scale pulse + halo flash), and group-drag parallax sway.
  - Editorial headline ("Layer light.", "Bundle up.", etc.) from `OutfitTagline`.
  - **Narrative always leads with "Dressing for X°"** — no matter what's happening.
  - Item-name caption on one line, centered, auto-shrinks.
- **Day selector**: one uniform `regularMaterial` capsule holding 7 equal-width slots. Each slot shows day abbreviation + that day's **weatherly temp** colored in its category's primary color (persistent — always visible). Selected slot has a category-gradient capsule highlight that slides between positions via `matchedGeometryEffect`.
- **Gestures**: root-level `simultaneousGesture` so horizontal swipe anywhere changes days. Swipe threshold 45pt. Drag-down refreshes. Card does a 2D tilt (not 3D — SceneKit was tried and removed for weight). Tap = pulse + haptic.
- **Location permission / first-run empty states** covered.

## Custom icons

- **Seven pure-SwiftUI `Shape` silhouettes**: `TShirtShape`, `LongSleeveShape`, `HoodieShape`, `SweatpantsShape`, `ShortsShape`, `RainJacketShape`, `WinterJacketShape`. Plus matching seam-detail overlays (neckline, pocket, waistband, zipper, quilt lines) so filled variants show character.
- **`ClothingIcon`** dispatches: `wearly.*` prefix → custom shape; anything else → `Image(systemName:)` with `.symbolRenderingMode(.hierarchical)` so multi-layer SF symbols like `cloud.rain.fill` stay readable at small sizes.
- **Unified stroke weight** across all custom shapes (`size × 0.038`).
- **Curated `ClothingSymbols` picker** in the edit view groups by "Tops & jackets" / "Bottoms & feet" / "Accessories" / "Weather hints" — no free-text SF Symbol input.
- **1.2× layout frame** on each `GarmentPiece`, with the large halo circle rendered via `.background(...)` so it extends visually without affecting layout height.

## Widget (`WearlyWidget/`)

- Separate Widget Extension target created via Xcode UI. Uses `PBXFileSystemSynchronizedRootGroup` so any file in `WearlyWidget/` auto-builds into the widget.
- **Removed** Xcode's template `AppIntent.swift` (we use `StaticConfiguration`, not intent-based).
- `WearlyWidget.swift` is self-contained: duplicated the seven silhouette Shapes inline (can't share across targets without more pbxproj wiring). No person SF Symbols (`figure.stand`, `figure.walk`) — all garments render as real silhouettes.
- **Small widget**: condition + day on top, "WEATHERLY" cap above the big temp, tiny outfit row at bottom. Temp has `minimumScaleFactor(0.7)` so three-digit values fit.
- **Medium widget**: info column (day / temp / WEATHERLY) on left, **all garments in one horizontal line** on right in order `outer → base → bottom → rain → winter`. Icon size adapts to outfit count (32pt for 2 pieces, 20pt for 5+).
- **Zone-colored background gradient** per `categoryRaw` — vivid top stop, darker bottom stop for legibility.
- **Data sharing via App Group** `group.com.wearly.shared`. `WeatherViewModel.publishWidgetState()` writes JSON `{weatherlyTemp, categoryRaw, conditionSymbol, outfitSymbols, outfitLabel, dayLabel, updatedAt}` to shared `UserDefaults` on every successful fetch + calls `WidgetCenter.shared.reloadAllTimelines()`. Widget reads; falls back to a placeholder payload if App Group isn't configured.
- User still needs to enable the App Group capability on both targets in Signing & Capabilities.

## Naming

- **"Weatherly"** is the internal name for the dressing-as temperature: `DaypartSummary.weatherlyTemp`, `WeatherViewModel.weatherlyTemperature`. UI copy stays "Dressing for X°" on the main screen; widget prominently labels the temp as `WEATHERLY` to brand it as the app's creation.

## Project file layout

```
Wear/
├── README.md
├── project.yml                     ← XcodeGen config (alt build path)
├── Wearly.xcodeproj/
│   └── project.pbxproj
├── Wearly/                         ← main app target
│   ├── WearlyApp.swift
│   ├── ContentView.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Models/
│   │   ├── Weather.swift
│   │   ├── DailyWeather.swift      (+ KeyTime struct + hourly data)
│   │   ├── ClothingItem.swift
│   │   ├── Outfit.swift
│   │   └── TemperatureRanges.swift
│   ├── ViewModels/
│   │   ├── WeatherViewModel.swift  (+ publishWidgetState, WearlyAppGroup)
│   │   └── SettingsViewModel.swift (+ ResolvedLocation, geocoder)
│   ├── Views/
│   │   ├── MainView.swift
│   │   ├── OutfitCardView.swift    (+ GarmentTint, OutfitTagline)
│   │   ├── WeatherHeaderView.swift
│   │   ├── DaySelectorView.swift
│   │   ├── SettingsView.swift      (Preferences, Location, KeyTimes, Wardrobe, Temperature, Notifications sections)
│   │   ├── ClothingToggleSection.swift
│   │   ├── ClothingEditView.swift
│   │   └── TemperatureRangeSection.swift
│   ├── Services/
│   │   ├── LocationManager.swift
│   │   ├── WeatherService.swift    (OpenMeteoProvider with hourly temps/feels-like/precipitation)
│   │   └── NotificationManager.swift
│   └── Utilities/
│       ├── OutfitEngine.swift      (+ DaypartAnalyzer + DaypartSummary + OutfitBias)
│       ├── TemperatureGradient.swift (+ ScenicPalette + HorizonShape + PineTreeShape + rain/snow/wind/fog overlays)
│       ├── CategoryPalette.swift
│       ├── ClothingSymbols.swift
│       ├── CustomClothingIcons.swift (ClothingIcon + all 7 Shapes + detail overlays)
│       ├── MinimalSlider.swift
│       └── HapticsManager.swift
└── WearlyWidget/                   ← widget extension target (sync'd folder)
    ├── WearlyWidget.swift          (self-contained: @main bundle, provider, view, duplicated Shapes)
    ├── Info.plist
    └── Assets.xcassets/
```

## Open items / known limitations

- **App Group** still needs to be enabled manually in Xcode for both targets (`group.com.wearly.shared`) to light up the widget's real data.
- **SceneKit 3D mannequin** was built, tuned, then **removed** — user preferred 2D playful. `SceneKit.framework` is no longer linked.
- **Free developer team**: App Groups work for local testing but the app can't be archived/distributed on Personal Team.
- **No CloudKit / iCloud sync** — wardrobe + settings are device-local.
- Temperature thresholds have a 5°F minimum gap enforced via cascading `didSet` in `SettingsViewModel`.
