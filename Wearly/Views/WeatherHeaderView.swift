//
//  WeatherHeaderView.swift
//  Wearly
//
//  Minimal top-of-screen info. Two horizontal strips:
//
//    📍 LOCATION                        ← the new top bar
//    ☁ 52° now  · Dressing for 58°       ← real temp + weatherly pill
//    H 62° L 48°  ·  Today · Mon, Apr 20
//
//  The "real" temperature is the actual outdoor reading from the
//  weather provider. "Dressing for X°" is Wearly's synthesized
//  Weatherly temp — the value the outfit engine targets.
//

import SwiftUI

struct WeatherHeaderView: View {
    let weather: Weather?
    let realTemp: Double?
    let effectiveTemp: Double?
    let usingFeelsLike: Bool
    let category: TempCategory
    let high: Double?
    let low: Double?
    let dayLabel: String
    let dateShort: String
    let lastUpdated: Date?
    let showsLastUpdated: Bool
    let locationName: String?

    var body: some View {
        VStack(spacing: 6) {
            locationBar
            primaryLine
            secondaryLine
        }
        .padding(.top, 2)
    }

    // MARK: - Location bar

    private var locationBar: some View {
        HStack(spacing: 5) {
            Image(systemName: "location.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            Text(locationName?.uppercased() ?? "LOCATING…")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.80))
                .lineLimit(1)
        }
    }

    // MARK: - Primary line: icon · real temp "now" · "Dressing for X°" pill

    @ViewBuilder
    private var primaryLine: some View {
        HStack(spacing: 10) {
            if let w = weather {
                Image(systemName: w.condition.symbol)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(CategoryPalette.bright(category))

                // Big real temperature — the actual outdoor reading.
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int((realTemp ?? w.temperature).rounded()))°")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.97))
                    Text("now")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.leading, 1)
                }

                if let effective = effectiveTemp,
                   abs(effective - (realTemp ?? w.temperature)) >= 1 {
                    Rectangle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 1, height: 14)

                    // "Dressing for" pill — the Weatherly temp the
                    // outfit engine is actually targeting.
                    HStack(spacing: 4) {
                        Text("Dressing for")
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                        Text("\(Int(effective.rounded()))°")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Secondary line: H/L · day · date

    @ViewBuilder
    private var secondaryLine: some View {
        HStack(spacing: 8) {
            if let high, let low {
                HStack(spacing: 6) {
                    Text("H \(Int(high.rounded()))°")
                    Text("L \(Int(low.rounded()))°")
                }
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.55))

                Text("·").foregroundStyle(.white.opacity(0.25))
            }

            Text(dayLabel)
                .font(.system(size: 12, weight: .medium, design: .rounded))
            Text("·")
                .foregroundStyle(.white.opacity(0.3))
            Text(dateShort)
                .font(.system(size: 12, weight: .regular, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.55))
    }
}
