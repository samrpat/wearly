//
//  ClothingItem.swift
//  Wearly
//
//  User-editable clothing item. Every item declares (a) its category,
//  (b) the temperature categories it's appropriate for, (c) whether
//  it should only appear while it's raining, and (d) whether it's an
//  "outer layer" — a top that the outfit engine will try to stack on
//  top of a base top (e.g., a hoodie worn over a t-shirt in mild
//  weather).
//
//  The default wardrobe marks the Hoodie as `isOuterLayer`. Any custom
//  top can be flipped via the Outer Layer toggle in the edit screen.
//

import Foundation

struct ClothingItem: Identifiable, Codable, Equatable, Hashable {

    var id: UUID
    var name: String
    var category: Category
    var symbol: String
    var isEnabled: Bool
    var applicableRanges: Set<TempCategory>
    var requiresRain: Bool
    /// Tops only: when true, the outfit engine stacks this item on top
    /// of another applicable top rather than using it as the standalone top.
    var isOuterLayer: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: Category,
        symbol: String,
        isEnabled: Bool = true,
        applicableRanges: Set<TempCategory> = [],
        requiresRain: Bool = false,
        isOuterLayer: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.symbol = symbol
        self.isEnabled = isEnabled
        self.applicableRanges = applicableRanges
        self.requiresRain = requiresRain
        self.isOuterLayer = isOuterLayer
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case tops     = "Tops"
        case bottoms  = "Bottoms"
        case extras   = "Extras"

        var id: String { rawValue }
    }

    // MARK: - Codable (backwards-compatible)

    private enum CodingKeys: String, CodingKey {
        case id, name, category, symbol, isEnabled
        case applicableRanges, requiresRain, isOuterLayer
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(Category.self, forKey: .category)
        symbol = try c.decode(String.self, forKey: .symbol)
        isEnabled = try c.decode(Bool.self, forKey: .isEnabled)
        applicableRanges = try c.decode(Set<TempCategory>.self, forKey: .applicableRanges)
        requiresRain = try c.decode(Bool.self, forKey: .requiresRain)
        // New field — default false when loading older saved data.
        isOuterLayer = try c.decodeIfPresent(Bool.self, forKey: .isOuterLayer) ?? false
    }

    // MARK: - Heuristics

    /// True when this item's name or symbol mentions a typical outer
    /// garment (hoodie, cardigan, sweater, pullover). Used as a fallback
    /// inference by both the edit screen and the outfit engine so users
    /// get layering even when they never flipped the Outer Layer toggle.
    var looksLikeOuterLayer: Bool {
        Self.symbolOrNameSuggestsOuterLayer(symbol: symbol, name: name)
    }

    /// Same heuristic, usable mid-edit where we only have partial field values.
    static func symbolOrNameSuggestsOuterLayer(symbol: String = "",
                                               name: String = "") -> Bool {
        let blob = (symbol + " " + name).lowercased()
        return ["hoodie", "cardigan", "sweater", "pullover"]
            .contains { blob.contains($0) }
    }

    // MARK: - Default seed wardrobe

    static var defaults: [ClothingItem] {
        [
            ClothingItem(name: "Longsleeve",
                         category: .tops,
                         symbol: "wearly.longsleeve.fill",
                         applicableRanges: [.freezing, .cold]),

            ClothingItem(name: "T-shirt",
                         category: .tops,
                         symbol: "wearly.tshirt.fill",
                         applicableRanges: [.mild, .pleasant, .warm, .hot]),

            ClothingItem(name: "Light Hoodie",
                         category: .tops,
                         symbol: "wearly.hoodie.fill",
                         applicableRanges: [.pleasant],
                         isOuterLayer: true),

            ClothingItem(name: "Sweatshirt",
                         category: .tops,
                         symbol: "wearly.hoodie.fill",
                         applicableRanges: [.cold, .mild],
                         isOuterLayer: true),

            ClothingItem(name: "Hoodie",
                         category: .tops,
                         symbol: "wearly.hoodie.fill",
                         applicableRanges: [.freezing, .cold, .mild],
                         isOuterLayer: true),

            ClothingItem(name: "Shorts",
                         category: .bottoms,
                         symbol: "wearly.shorts.fill",
                         applicableRanges: [.warm, .hot]),

            ClothingItem(name: "Sweatpants",
                         category: .bottoms,
                         symbol: "wearly.sweatpants.fill",
                         applicableRanges: [.freezing, .cold, .mild, .pleasant]),

            ClothingItem(name: "Rain jacket",
                         category: .extras,
                         symbol: "wearly.rainjacket.fill",
                         applicableRanges: [.freezing, .cold, .mild, .pleasant, .warm, .hot],
                         requiresRain: true),

            ClothingItem(name: "Winter jacket",
                         category: .extras,
                         symbol: "wearly.winterjacket.fill",
                         applicableRanges: [.freezing, .cold]),
        ]
    }
}
