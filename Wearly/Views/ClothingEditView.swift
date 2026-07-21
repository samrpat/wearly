//
//  ClothingEditView.swift
//  Wearly
//
//  Pushed from the wardrobe row (or "Add item"). Lets the user edit
//  every field of a `ClothingItem`:
//      • name
//      • category (segmented)
//      • SF Symbol (free-text with live preview & validation hint)
//      • enabled / disabled
//      • applicable temperature ranges (4 tappable chips)
//      • "only when raining" toggle
//      • delete (for existing items)
//

import SwiftUI

struct ClothingEditView: View {

    enum Mode: Equatable {
        case new(ClothingItem.Category)
        case edit(ClothingItem)

        var isNew: Bool { if case .new = self { return true } else { return false } }
    }

    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ClothingItem
    @State private var showingDeleteConfirm = false

    private let mode: Mode

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .new(let category):
            _draft = State(initialValue: ClothingItem(
                name: "",
                category: category,
                symbol: Self.defaultSymbol(for: category),
                applicableRanges: Self.defaultRanges(for: category)
            ))
        case .edit(let existing):
            _draft = State(initialValue: existing)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.09),
                    Color(red: 0.08, green: 0.09, blue: 0.14)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    symbolPreview
                    detailsCard
                    symbolPickerCard
                    rangesCard
                    optionsCard
                    if !mode.isNew { deleteButton }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 80)
            }
        }
        .navigationTitle(mode.isNew ? "New Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? .white : .white.opacity(0.3))
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Delete \(draft.name)?",
                            isPresented: $showingDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                HapticsManager.medium()
                settings.delete(draft)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Cards

    private var symbolPreview: some View {
        VStack(spacing: 10) {
            ClothingIcon(symbol: draft.symbol, size: 38)
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 92, height: 92)
                .background(Circle().fill(.white.opacity(0.05)))
                .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 0.5))
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: draft.symbol)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Details")

            VStack(spacing: 0) {
                // Name
                HStack {
                    Text("Name")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 96, alignment: .leading)
                    TextField("e.g. Wool sweater", text: $draft.name)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(.white.opacity(0.06)).padding(.leading, 16)

                // Category
                HStack {
                    Text("Category")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 96, alignment: .leading)

                    Picker("", selection: $draft.category) {
                        ForEach(ClothingItem.Category.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    private var symbolPickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Icon")

            VStack(alignment: .leading, spacing: 18) {
                ForEach(ClothingSymbols.groupsFilteredByAvailability(), id: \.title) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.title)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                            spacing: 10
                        ) {
                            ForEach(group.symbols, id: \.self) { name in
                                SymbolCell(
                                    name: name,
                                    selected: draft.symbol == name
                                ) {
                                    HapticsManager.selection()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        draft.symbol = name
                                        // Smart default: picking a hoodie-family symbol
                                        // on a top flips Outer Layer on. User can still
                                        // turn it off manually in the toggle below.
                                        if draft.category == .tops,
                                           Self.looksLikeOuterLayer(symbol: name) {
                                            draft.isOuterLayer = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    private var rangesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Appears in")

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(TempCategory.allCases) { cat in
                        RangeChip(
                            label: cat.display,
                            category: cat,
                            selected: draft.applicableRanges.contains(cat)
                        ) {
                            HapticsManager.selection()
                            if draft.applicableRanges.contains(cat) {
                                draft.applicableRanges.remove(cat)
                            } else {
                                draft.applicableRanges.insert(cat)
                            }
                        }
                    }
                }

                Text("Tap the temperature categories where this item should appear in suggestions.")
                    .font(.system(size: 11, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Options")

            VStack(spacing: 0) {
                Toggle(isOn: $draft.isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enabled")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Disabled items never appear.")
                            .font(.system(size: 11, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .tint(CategoryPalette.brand)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(.white.opacity(0.06)).padding(.leading, 16)

                Toggle(isOn: $draft.requiresRain) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Only when raining")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Only suggest this item if it's raining.")
                            .font(.system(size: 11, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .tint(CategoryPalette.brand)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Outer-layer toggle only makes sense for tops.
                if draft.category == .tops {
                    Divider().background(.white.opacity(0.06)).padding(.leading, 16)

                    Toggle(isOn: $draft.isOuterLayer) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Outer layer")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("Stacks this on top of a base top (e.g. hoodie over a t-shirt).")
                                .font(.system(size: 11, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .tint(CategoryPalette.brand)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
        }
    }

    private var deleteButton: some View {
        Button {
            showingDeleteConfirm = true
        } label: {
            HStack {
                Spacer()
                Text("Delete Item")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.red.opacity(0.85))
                Spacer()
            }
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.red.opacity(0.18), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        HapticsManager.light()
        var clean = draft
        clean.name = clean.name.trimmingCharacters(in: .whitespaces)
        clean.symbol = clean.symbol.trimmingCharacters(in: .whitespaces)
        if clean.symbol.isEmpty {
            clean.symbol = Self.defaultSymbol(for: clean.category)
        }

        // Smart default for brand-new tops: anything named "Hoodie",
        // "Cardigan", "Sweater", etc. (or using a hoodie symbol) should
        // layer over a base top. Respects any choice the user made
        // manually — we only flip it *on* if it's still at default `false`.
        if case .new = mode,
           clean.category == .tops,
           !clean.isOuterLayer,
           Self.looksLikeOuterLayer(symbol: clean.symbol, name: clean.name) {
            clean.isOuterLayer = true
        }

        switch mode {
        case .new:  settings.add(clean)
        case .edit: settings.update(clean)
        }
        dismiss()
    }

    private static func looksLikeOuterLayer(symbol: String = "", name: String = "") -> Bool {
        ClothingItem.symbolOrNameSuggestsOuterLayer(symbol: symbol, name: name)
    }

    // MARK: - Defaults for new items

    private static func defaultSymbol(for category: ClothingItem.Category) -> String {
        switch category {
        case .tops:    return "tshirt"
        case .bottoms: return "figure.walk"
        case .extras:  return "sparkles"
        }
    }

    /// Newly added items default to **every** temperature range so they
    /// show up immediately in whatever weather the user is viewing. Users
    /// can then narrow the ranges in the "Appears in" section for items
    /// that shouldn't be worn in every climate (e.g. uncheck Hot on a
    /// wool sweater).
    private static func defaultRanges(for category: ClothingItem.Category) -> Set<TempCategory> {
        Set(TempCategory.allCases)
    }
}

// MARK: - Symbol cell

private struct SymbolCell: View {
    let name: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ClothingIcon(symbol: name, size: 18)
                .foregroundStyle(selected ? .black.opacity(0.9) : .white.opacity(0.75))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(selected ? .white.opacity(0.9) : .white.opacity(0.05))
                )
                .overlay(
                    Circle().stroke(.white.opacity(selected ? 0 : 0.1), lineWidth: 0.5)
                )
                .scaleEffect(selected ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Range chip

struct RangeChip: View {
    let label: String
    let category: TempCategory
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? .black.opacity(0.88) : CategoryPalette.primary(category))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        selected
                        ? AnyShapeStyle(CategoryPalette.primary(category))
                        : AnyShapeStyle(Color.white.opacity(0.05))
                    )
                )
                .overlay(
                    Capsule().stroke(
                        selected
                        ? Color.clear
                        : CategoryPalette.primary(category).opacity(0.35),
                        lineWidth: 0.8
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
