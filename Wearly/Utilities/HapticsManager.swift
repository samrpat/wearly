//
//  HapticsManager.swift
//  Wearly
//
//  Thin wrapper around UIKit haptics. Kept intentionally small —
//  haptics should be a whisper, not a drum.
//

import UIKit

enum HapticsManager {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
