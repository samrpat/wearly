//
//  DaySelectorView.swift
//  Wearly
//
//  One uniform capsule with 7 evenly-spaced day slots inside. Every
//  day's dressing temperature is always rendered in *that day's*
//  category color — so the whole week's weather pattern reads at a
//  glance without needing to tap or slide anywhere. Tapping a slot
//  glides the selection highlight along the bar via matched geometry.
//

import SwiftUI

struct DaySelectorView: View {
    let days: [DailyWeather]
    @EnvironmentObject private var settings: SettingsViewModel
    @Binding var selectedIndex: Int

    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                let summary = DaypartAnalyzer.summarize(
                    day: day,
                    keyTimes: settings.keyTimes,
                    useFeelsLike: settings.useFeelsLike,
                    bias: settings.outfitBias
                )
                let dressingTemp = summary.weatherlyTemp
                let category = settings.ranges.category(for: dressingTemp)

                daySlot(
                    idx: idx,
                    day: day,
                    dressingTemp: dressingTemp,
                    category: category
                )
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.6)
        )
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func daySlot(
        idx: Int,
        day: DailyWeather,
        dressingTemp: Double,
        category: TempCategory
    ) -> some View {
        let isSelected = idx == selectedIndex
        let isToday = idx == 0

        Button {
            HapticsManager.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                selectedIndex = idx
            }
        } label: {
            VStack(spacing: 3) {
                Text(isToday ? "Today" : Self.weekdayAbbrev(day.date))
                    .font(.system(size: 10,
                                  weight: isSelected ? .semibold : .medium,
                                  design: .rounded))
                    .foregroundStyle(
                        isSelected
                        ? Color.white
                        : Color.white.opacity(0.55)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("\(Int(dressingTemp.rounded()))°")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected
                        ? Color.white
                        : CategoryPalette.primary(category).opacity(0.95)
                    )
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    CategoryPalette.primary(category).opacity(0.92),
                                    CategoryPalette.primary(category).opacity(0.55)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: CategoryPalette.primary(category).opacity(0.45),
                                radius: 10, y: 4)
                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private static func weekdayAbbrev(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}
