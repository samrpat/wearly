//
//  ClothingSymbols.swift
//  Wearly
//
//  A curated list of SF Symbols that are either directly clothing-related
//  or useful iconography for a wardrobe app. Everything here exists in
//  iOS 17 and renders cleanly at the 26pt weight the outfit card uses.
//
//  The editor uses this list exclusively — the user no longer has to
//  know any SF Symbol names.
//

import Foundation
import UIKit

enum ClothingSymbols {

    /// Grouped for a tidy picker. Order inside a group is deliberate —
    /// the most-common options come first.
    static let groups: [(title: String, symbols: [String])] = [
        ("Tops & jackets", [
            "wearly.tshirt", "wearly.tshirt.fill",
            "wearly.longsleeve", "wearly.longsleeve.fill",
            "wearly.hoodie", "wearly.hoodie.fill",
            "wearly.rainjacket", "wearly.rainjacket.fill",
            "wearly.winterjacket", "wearly.winterjacket.fill",
            "tshirt", "tshirt.fill",
            "jacket", "jacket.fill",
            "coat", "coat.fill"
        ]),
        ("Bottoms & feet", [
            "wearly.shorts", "wearly.shorts.fill",
            "wearly.sweatpants", "wearly.sweatpants.fill",
            "figure.stand", "figure.walk", "figure.run", "figure",
            "shoe", "shoe.fill", "shoe.2.fill"
        ]),
        ("Accessories", [
            "sunglasses", "sunglasses.fill",
            "eyeglasses",
            "umbrella", "umbrella.fill",
            "hanger",
            "backpack", "backpack.fill",
            "handbag", "handbag.fill",
            "briefcase", "briefcase.fill"
        ]),
        ("Weather hints", [
            "snowflake",
            "sun.max", "sun.max.fill",
            "cloud", "cloud.fill",
            "cloud.rain", "cloud.rain.fill",
            "cloud.snow", "cloud.snow.fill",
            "wind",
            "flame", "flame.fill",
            "drop", "drop.fill",
            "sparkles"
        ])
    ]

    /// Flat list for things like "is this symbol in our curated set?".
    static var all: [String] {
        groups.flatMap(\.symbols).filter(isAvailable)
    }

    static func groupsFilteredByAvailability() -> [(title: String, symbols: [String])] {
        groups.map { group in
            (title: group.title,
             symbols: group.symbols.filter(isAvailable))
        }
        .filter { !$0.symbols.isEmpty }
    }

    /// Custom Wearly shapes always render; SF Symbol availability depends on OS.
    private static func isAvailable(_ name: String) -> Bool {
        CustomClothingIcons.isCustom(name) || UIImage(systemName: name) != nil
    }
}
