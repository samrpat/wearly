//
//  TemperatureRangeSection.swift
//  Wearly
//
//  Five boundary sliders defining six zones:
//  Freezing → Cold → Mild → Pleasant → Warm → Hot. Labels update live
//  in a monospaced font so the thresholds feel alive as you drag.
//

import SwiftUI

struct TemperatureRangeSection: View {
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Temperature")

            VStack(spacing: 20) {
                rangeRow(
                    label: "Freezing",
                    subtitle: "below \(int(settings.freezingMax))°F",
                    value: $settings.freezingMax,
                    range: 0...Swift.min(settings.coldMax - 5, 45)
                )

                rangeRow(
                    label: "Cold",
                    subtitle: "\(int(settings.freezingMax))°F – \(int(settings.coldMax))°F",
                    value: $settings.coldMax,
                    range: (settings.freezingMax + 5)...Swift.min(settings.mildMax - 5, 65)
                )

                rangeRow(
                    label: "Mild",
                    subtitle: "\(int(settings.coldMax))°F – \(int(settings.mildMax))°F",
                    value: $settings.mildMax,
                    range: (settings.coldMax + 5)...Swift.min(settings.pleasantMax - 5, 80)
                )

                rangeRow(
                    label: "Pleasant",
                    subtitle: "\(int(settings.mildMax))°F – \(int(settings.pleasantMax))°F",
                    value: $settings.pleasantMax,
                    range: (settings.mildMax + 5)...Swift.min(settings.warmMax - 5, 90)
                )

                rangeRow(
                    label: "Warm",
                    subtitle: "\(int(settings.pleasantMax))°F – \(int(settings.warmMax))°F",
                    value: $settings.warmMax,
                    range: (settings.pleasantMax + 5)...100
                )

                // Hot is derived: anything above warmMax.
                HStack(alignment: .firstTextBaseline) {
                    Text("Hot")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Text("above \(int(settings.warmMax))°F")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    private func rangeRow(label: String,
                          subtitle: String,
                          value: Binding<Double>,
                          range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
                    .animation(.none, value: value.wrappedValue)
            }
            MinimalSlider(value: value, range: range)
        }
    }

    private func int(_ d: Double) -> Int { Int(d.rounded()) }
}
