//
//  Outfit.swift
//  Wearly
//

import Foundation

struct Outfit: Identifiable, Equatable, Hashable {
    let items: [ClothingItem]
    let label: String

    /// Stable identity built from item IDs so SwiftUI only re-animates the
    /// card when the actual set of garments changes.
    var id: String {
        items.map(\.id.uuidString).sorted().joined(separator: "|")
    }
}
