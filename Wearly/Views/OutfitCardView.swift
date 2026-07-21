//
//  OutfitCardView.swift
//  Wearly
//
//  A playful 2D mannequin. Each garment is a glowing object that:
//    • floats gently on its own, slightly desynced phase per piece
//    • pulses its vibe halo
//    • staggers in when the outfit reassembles (day change)
//    • **wiggles + bounces** on tap — the playful "Not Boring" touch
//    • sways as a group when the user drags the scene horizontally
//
//  No SceneKit here anymore. Just SwiftUI, springs, and haptics.
//

import SwiftUI

struct OutfitCardView: View {
    let outfit: Outfit
    var accent: Color = .white
    var headline: String = ""
    var contextLine: String? = nil
    /// Bumps whenever the scene should "re-assemble" (day change).
    var assemblyToken: UUID = UUID()
    /// Horizontal drag delta — used for a subtle group-sway.
    var dragDelta: CGFloat = 0

    var body: some View {
        VStack(spacing: 22) {
            mannequin
            textStack
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Mannequin

    private var mannequin: some View {
        let tops    = outfit.items.filter { $0.category == .tops }
        let bottoms = outfit.items.filter { $0.category == .bottoms }
        let extras  = outfit.items.filter { $0.category == .extras }

        // Rows in the mannequin stack: one per top, one per bottom, and
        // a single row for extras (they sit in an HStack). Scale every
        // piece down proportionally so the overall card height stays
        // roughly constant as the outfit grows — no overlap required.
        let rowCount = tops.count + bottoms.count + (extras.isEmpty ? 0 : 1)
        let scale: CGFloat = max(0.60, 1.0 - max(0, CGFloat(rowCount) - 2) * 0.13)
        let mainSize = 92 * scale
        let extraSize = 40 * scale
        let rowSpacing = 8 * scale

        return VStack(spacing: rowSpacing) {
            ForEach(Array(tops.enumerated()), id: \.element.id) { idx, item in
                GarmentPiece(
                    item: item,
                    size: mainSize,
                    introDelay: Double(idx) * 0.10,
                    parallax: 0.22 - CGFloat(idx) * 0.04,
                    assemblyToken: assemblyToken,
                    groupDrag: dragDelta
                )
            }

            ForEach(Array(bottoms.enumerated()), id: \.element.id) { idx, item in
                GarmentPiece(
                    item: item,
                    size: mainSize,
                    introDelay: 0.18 + Double(idx) * 0.10,
                    parallax: 0.14,
                    assemblyToken: assemblyToken,
                    groupDrag: dragDelta
                )
            }

            if !extras.isEmpty {
                HStack(spacing: 22 * scale) {
                    ForEach(Array(extras.enumerated()), id: \.element.id) { idx, item in
                        GarmentPiece(
                            item: item,
                            size: extraSize,
                            introDelay: 0.32 + Double(idx) * 0.08,
                            parallax: 0.06,
                            assemblyToken: assemblyToken,
                            groupDrag: dragDelta
                        )
                    }
                }
                .padding(.top, 8 * scale)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: rowCount)
    }

    // MARK: - Text

    private var textStack: some View {
        VStack(spacing: 10) {
            Text(headline)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .kerning(-0.6)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let contextLine {
                Text(contextLine)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Text(outfit.items.map(\.name).joined(separator: " · "))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.top, 2)
        }
    }
}

// MARK: - Individual garment piece

private struct GarmentPiece: View {
    let item: ClothingItem
    let size: CGFloat
    let introDelay: Double
    /// Per-piece parallax factor — higher means this piece sways more with
    /// the group drag, giving the mannequin a little depth.
    let parallax: CGFloat
    let assemblyToken: UUID
    let groupDrag: CGFloat

    // Idle motion
    @State private var float: CGFloat = 0
    @State private var glowBreath: CGFloat = 0.88

    // Assembly intro
    @State private var visibility: Double = 0
    @State private var enterOffset: CGFloat = 26
    @State private var lastToken: UUID = UUID()

    // Playful tap response
    @State private var tapScale: CGFloat = 1.0
    @State private var tapRotation: Double = 0
    @State private var tapHalo: Double = 0       // brief burst on tap

    var body: some View {
        // The garment glyph defines the layout size of this piece. The
        // larger blurred halo is rendered behind via `.background`, so it
        // stays visually prominent but doesn't push the mannequin around.
        ClothingIcon(symbol: item.symbol, size: size)
            .foregroundStyle(item.tint.gradient)
            .shadow(color: item.tint.glow.opacity(0.42), radius: 14, y: 6)
            .shadow(color: .black.opacity(0.32), radius: 6, y: 6)
            .offset(y: float)
            .rotationEffect(.degrees(tapRotation))
            .scaleEffect(tapScale)
            // Fixed layout footprint — glow halo lives behind via background.
            .frame(width: size * 1.2, height: size * 1.2)
            .background(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                item.tint.glow.opacity(0.55 + tapHalo * 0.3),
                                item.tint.glow.opacity(0.18),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: size * 1.25
                        )
                    )
                    .frame(width: size * 2.2, height: size * 2.2)
                    .blur(radius: 22)
                    .scaleEffect(glowBreath + CGFloat(tapHalo) * 0.12)
                    .opacity(visibility * 0.9)
                    .allowsHitTesting(false)
            )
            .offset(x: groupDrag * parallax)
            .rotationEffect(.degrees(Double(groupDrag) * 0.04))
            .opacity(visibility)
            .scaleEffect(0.86 + visibility * 0.14, anchor: .center)
            .offset(y: enterOffset)
            .contentShape(Rectangle())
            .onTapGesture { playTap() }
        .onAppear {
            lastToken = assemblyToken
            assemble()
            loopSubtleMotion()
        }
        .onChange(of: assemblyToken) { _, new in
            guard new != lastToken else { return }
            lastToken = new
            resetForAssembly()
            assemble()
        }
    }

    // MARK: - Animations

    private func assemble() {
        withAnimation(.spring(response: 0.65, dampingFraction: 0.80).delay(introDelay)) {
            visibility = 1
            enterOffset = 0
        }
    }

    private func resetForAssembly() {
        visibility = 0
        enterOffset = 26
    }

    private func loopSubtleMotion() {
        withAnimation(
            .easeInOut(duration: 3.2 + Double.random(in: -0.4...0.6))
                .repeatForever(autoreverses: true)
                .delay(introDelay)
        ) {
            float = -5
        }
        withAnimation(
            .easeInOut(duration: 2.6)
                .repeatForever(autoreverses: true)
                .delay(introDelay)
        ) {
            glowBreath = 1.10
        }
    }

    /// The core "Not Boring" moment — a bouncy wiggle with a halo flash.
    private func playTap() {
        HapticsManager.light()

        // Wiggle: right, then left overshoot, then settle.
        withAnimation(.spring(response: 0.18, dampingFraction: 0.40)) {
            tapRotation = 14
            tapScale = 1.16
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.40).delay(0.10)) {
            tapRotation = -10
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.45).delay(0.18)) {
            tapRotation = 6
        }
        withAnimation(.spring(response: 0.50, dampingFraction: 0.60).delay(0.25)) {
            tapRotation = 0
            tapScale = 1.0
        }

        // Halo flash — glow intensifies, then fades.
        withAnimation(.easeOut(duration: 0.18)) { tapHalo = 1 }
        withAnimation(.easeOut(duration: 0.45).delay(0.2)) { tapHalo = 0 }
    }
}

// MARK: - Garment tint (per-role color palette)

/// A three-stop color palette used to render a garment. Different
/// "roles" in the outfit (base top, outer layer, bottom, rain jacket,
/// winter jacket, other extras) get distinct palettes so you can read
/// the outfit at a glance as a coherent color story.
struct GarmentTint {
    let highlight: Color   // top-left, lightest
    let base: Color        // middle
    let shadow: Color      // bottom-right, darkest
    let glow: Color        // halo color behind the garment

    var gradient: LinearGradient {
        LinearGradient(
            colors: [highlight, base, shadow],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension GarmentTint {
    // Base top: cream/white — a neutral underlayer.
    static let baseTop = GarmentTint(
        highlight: Color(red: 0.99, green: 0.99, blue: 1.00),
        base:      Color(red: 0.90, green: 0.92, blue: 0.96),
        shadow:    Color(red: 0.68, green: 0.74, blue: 0.84),
        glow:      Color(red: 0.90, green: 0.94, blue: 1.00)
    )

    // Outer top: warm terracotta — hoodie/cardigan/sweater family.
    static let outerTop = GarmentTint(
        highlight: Color(red: 1.00, green: 0.78, blue: 0.62),
        base:      Color(red: 0.90, green: 0.52, blue: 0.40),
        shadow:    Color(red: 0.56, green: 0.26, blue: 0.20),
        glow:      Color(red: 1.00, green: 0.58, blue: 0.32)
    )

    // Bottoms (pants / shorts): denim blue-gray.
    static let bottom = GarmentTint(
        highlight: Color(red: 0.72, green: 0.78, blue: 0.88),
        base:      Color(red: 0.44, green: 0.54, blue: 0.72),
        shadow:    Color(red: 0.26, green: 0.34, blue: 0.50),
        glow:      Color(red: 0.55, green: 0.72, blue: 0.94)
    )

    // Rain jacket: dark navy blue (per user spec).
    static let rainJacket = GarmentTint(
        highlight: Color(red: 0.40, green: 0.54, blue: 0.80),
        base:      Color(red: 0.16, green: 0.28, blue: 0.56),
        shadow:    Color(red: 0.06, green: 0.14, blue: 0.34),
        glow:      Color(red: 0.45, green: 0.68, blue: 1.00)
    )

    // Winter jacket: light snowy gray (per user spec).
    static let winterJacket = GarmentTint(
        highlight: Color(red: 0.98, green: 0.99, blue: 1.00),
        base:      Color(red: 0.84, green: 0.88, blue: 0.93),
        shadow:    Color(red: 0.62, green: 0.68, blue: 0.76),
        glow:      Color(red: 0.86, green: 0.94, blue: 1.00)
    )

    // Fallback for other extras (umbrellas, bags, etc.).
    static let neutralExtra = GarmentTint(
        highlight: Color(red: 0.96, green: 0.88, blue: 0.72),
        base:      Color(red: 0.78, green: 0.66, blue: 0.50),
        shadow:    Color(red: 0.48, green: 0.38, blue: 0.26),
        glow:      Color(red: 0.95, green: 0.80, blue: 0.58)
    )
}

extension ClothingItem {
    /// Maps an item to its visual role → color palette. Specific-symbol
    /// matches win over category defaults so the rain jacket always
    /// renders navy and the winter jacket always renders snowy gray.
    var tint: GarmentTint {
        let s = symbol.lowercased()
        let n = name.lowercased()

        // Specific garment overrides first.
        if s.contains("rainjacket") || s.contains("umbrella")
           || n.contains("rain jacket") || n.contains("rain")
           || (requiresRain && category == .extras) {
            return .rainJacket
        }
        if s.contains("winterjacket") || s.contains("snowflake")
           || n.contains("winter jacket") || n.contains("winter") {
            return .winterJacket
        }

        // Otherwise by category.
        switch category {
        case .tops:    return isOuterLayer ? .outerTop : .baseTop
        case .bottoms: return .bottom
        case .extras:  return .neutralExtra
        }
    }
}

// MARK: - Editorial tagline generator

enum OutfitTagline {
    /// One-line bold editorial headline — short, confident, no period except
    /// the deliberate full stops that match the fashion-caption voice.
    static func headline(weather: Weather?, category: TempCategory) -> String {
        guard let weather else { return "…" }

        if weather.isRaining {
            switch category {
            case .freezing, .cold:       return "Armor up."
            case .mild:                  return "Stay dry."
            case .pleasant, .warm:       return "Light cover."
            case .hot:                   return "Cool rain."
            }
        }
        switch weather.condition {
        case .snow:  return "Bundle warm."
        case .windy: return "Hold steady."
        case .foggy: return "Soft edges."
        default:     break
        }
        switch category {
        case .freezing: return "Full armor."
        case .cold:     return "Bundle up."
        case .mild:     return "Layer light."
        case .pleasant: return "Easy does it."
        case .warm:     return "Keep it breezy."
        case .hot:      return "Stay cool."
        }
    }

    static func contextLine(weather: Weather?, usingFeelsLike: Bool) -> String? {
        guard let w = weather else { return nil }
        let actual = Int(w.temperature.rounded())
        let feels = w.feelsLike.map { Int($0.rounded()) }
        let cond = w.condition.description.lowercased()
        if usingFeelsLike, let feels {
            return "Feels \(feels)° · \(cond)"
        }
        if let feels, abs(feels - actual) >= 2 {
            return "\(actual)° · feels \(feels)°"
        }
        return "\(actual)° · \(cond)"
    }
}
