//
//  ClothingToggleSection.swift
//  Wearly
//
//  The wardrobe editor. For every category (Tops, Bottoms, Extras) you
//  see a grouped list of items with:
//      • inline enable/disable toggle
//      • the temperature categories the item applies to (compact badges)
//      • tap a row → push ClothingEditView to rename, re-symbol,
//        reassign ranges, or delete
//      • "+ Add item" row at the end of each category
//
//  The file name is kept as ClothingToggleSection.swift to avoid a
//  project-file churn, but conceptually this is the Wardrobe section.
//

import SwiftUI

struct ClothingToggleSection: View {
    @EnvironmentObject private var settings: SettingsViewModel

    @State private var showingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel("Wardrobe")
                Spacer()
                Button {
                    showingReset = true
                } label: {
                    Text("Reset")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            VStack(spacing: 18) {
                ForEach(ClothingItem.Category.allCases) { category in
                    categoryCard(category)
                }
            }
        }
        .confirmationDialog("Reset wardrobe to defaults?",
                            isPresented: $showingReset,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                HapticsManager.medium()
                settings.resetWardrobe()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will replace your custom items with the default wardrobe.")
        }
    }

    @ViewBuilder
    private func categoryCard(_ category: ClothingItem.Category) -> some View {
        let rows = settings.items(in: category)

        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, item in
                    NavigationLink {
                        ClothingEditView(mode: .edit(item))
                    } label: {
                        ClothingRow(item: item)
                    }
                    .buttonStyle(.plain)

                    if idx < rows.count - 1 {
                        Divider()
                            .background(.white.opacity(0.04))
                            .padding(.leading, 52)
                    }
                }

                if !rows.isEmpty {
                    Divider().background(.white.opacity(0.04)).padding(.leading, 52)
                }

                NavigationLink {
                    ClothingEditView(mode: .new(category))
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 22)

                        Text("Add item")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }
}

// MARK: - Row

private struct ClothingRow: View {
    @EnvironmentObject private var settings: SettingsViewModel
    let item: ClothingItem

    var body: some View {
        HStack(spacing: 14) {
            ClothingIcon(symbol: item.symbol, size: 20)
                .foregroundStyle(.white.opacity(item.isEnabled ? 0.95 : 0.3))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(item.isEnabled ? 0.92 : 0.4))

                HStack(spacing: 4) {
                    ForEach(TempCategory.allCases) { cat in
                        RangeBadge(category: cat,
                                   filled: item.applicableRanges.contains(cat))
                    }

                    if item.requiresRain {
                        Image(systemName: "umbrella.fill")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.leading, 2)
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { new in
                    HapticsManager.selection()
                    settings.setEnabled(item, enabled: new)
                }
            ))
            .labelsHidden()
            .tint(CategoryPalette.brand)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Small range badge

struct RangeBadge: View {
    let category: TempCategory
    let filled: Bool

    var body: some View {
        Text(category.letter)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(filled ? .black.opacity(0.88) : .white.opacity(0.35))
            .frame(width: 14, height: 14)
            .background(
                Circle().fill(filled
                              ? AnyShapeStyle(CategoryPalette.primary(category))
                              : AnyShapeStyle(Color.white.opacity(0.06)))
            )
    }
}

// MARK: - Symbol helper

enum SymbolUtil {
    /// A name is valid if it's one of our custom Wearly shapes OR a real SF Symbol.
    static func isValid(_ name: String) -> Bool {
        CustomClothingIcons.isCustom(name) || UIImage(systemName: name) != nil
    }

    static func validOrFallback(_ name: String,
                                fallback: String = "questionmark.circle") -> String {
        isValid(name) ? name : fallback
    }
}
