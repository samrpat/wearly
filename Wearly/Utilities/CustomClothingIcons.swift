//
//  CustomClothingIcons.swift
//  Wearly
//
//  Custom clothing glyphs drawn in the SF Symbol idiom. Every garment
//  has:
//    • a **silhouette** shape (used for both the 2D icon and the
//      SceneKit extrusion in the 3D view)
//    • a **seam detail** shape drawn inside — a neckline, waistband,
//      or pocket line — so filled variants read with visible character
//
//  Plus a few extra "overlay" shapes (pocket, zipper, quilt, drawstring)
//  that the 3D scene layers in front of the body as real extruded
//  geometry to give each garment physical detail.
//
//  Symbol naming:
//    `wearly.<name>`          → outlined
//    `wearly.<name>.fill`     → filled + subtle seam drawn on top
//
//  Current set (all rendered in 3D):
//    tshirt / tshirt.fill
//    longsleeve / longsleeve.fill
//    hoodie / hoodie.fill
//    shorts / shorts.fill
//    sweatpants / sweatpants.fill
//    rainjacket / rainjacket.fill
//    winterjacket / winterjacket.fill
//

import SwiftUI

// MARK: - Unified icon view

struct ClothingIcon: View {
    let symbol: String
    let size: CGFloat
    var weight: Font.Weight = .ultraLight

    var body: some View {
        if CustomClothingIcons.isCustom(symbol) {
            CustomClothingIcons.view(for: symbol, size: size)
        } else {
            Image(systemName: SymbolUtil.validOrFallback(symbol))
                .font(.system(size: size, weight: weight))
                // Hierarchical rendering lets multi-layer SF symbols
                // (cloud.rain, cloud.snow, etc.) stay legible at small
                // sizes — primary layer full-opacity, secondary faded.
                .symbolRenderingMode(.hierarchical)
        }
    }
}

// MARK: - Registry + dispatch

enum CustomClothingIcons {

    static func isCustom(_ name: String) -> Bool {
        name.hasPrefix("wearly.")
    }

    static let all: [String] = [
        "wearly.tshirt", "wearly.tshirt.fill",
        "wearly.longsleeve", "wearly.longsleeve.fill",
        "wearly.hoodie", "wearly.hoodie.fill",
        "wearly.shorts", "wearly.shorts.fill",
        "wearly.sweatpants", "wearly.sweatpants.fill",
        "wearly.rainjacket", "wearly.rainjacket.fill",
        "wearly.winterjacket", "wearly.winterjacket.fill"
    ]

    private static func strokeWidth(for size: CGFloat) -> CGFloat {
        max(1.0, size * 0.038)
    }
    private static let canvasScale: CGFloat = 1.15
    private static let seamTint = Color.black.opacity(0.22)

    @ViewBuilder
    static func view(for name: String, size: CGFloat) -> some View {
        let stroke = strokeWidth(for: size)
        let thin = stroke * 0.75
        let dim = size * canvasScale

        switch name {

        case "wearly.tshirt":
            ZStack {
                TShirtShape().stroke(lineWidth: stroke)
                TShirtNeckline().stroke(lineWidth: thin)
            }
            .frame(width: dim, height: dim)

        case "wearly.tshirt.fill":
            TShirtShape()
                .overlay(
                    TShirtNeckline()
                        .stroke(lineWidth: thin)
                        .foregroundStyle(seamTint)
                )
                .frame(width: dim, height: dim)

        case "wearly.longsleeve":
            ZStack {
                LongSleeveShape().stroke(lineWidth: stroke)
                LongSleeveNeckline().stroke(lineWidth: thin)
            }
            .frame(width: dim, height: dim)

        case "wearly.longsleeve.fill":
            LongSleeveShape()
                .overlay(
                    LongSleeveNeckline()
                        .stroke(lineWidth: thin)
                        .foregroundStyle(seamTint)
                )
                .frame(width: dim, height: dim)

        case "wearly.hoodie":
            ZStack {
                HoodieShape().stroke(lineWidth: stroke)
                HoodieNeckline().stroke(lineWidth: thin)
                HoodiePocket().stroke(lineWidth: thin)
            }
            .frame(width: dim, height: dim)

        case "wearly.hoodie.fill":
            HoodieShape()
                .overlay(
                    ZStack {
                        HoodieNeckline().stroke(lineWidth: thin)
                        HoodiePocket().stroke(lineWidth: thin)
                    }
                    .foregroundStyle(seamTint)
                )
                .frame(width: dim, height: dim)

        case "wearly.sweatpants":
            ZStack {
                SweatpantsShape().stroke(lineWidth: stroke)
                WaistbandDetail().stroke(lineWidth: thin)
            }
            .frame(width: dim, height: dim)

        case "wearly.sweatpants.fill":
            SweatpantsShape()
                .overlay(
                    WaistbandDetail()
                        .stroke(lineWidth: thin)
                        .foregroundStyle(seamTint)
                )
                .frame(width: dim, height: dim)

        case "wearly.shorts":
            ZStack {
                ShortsShape().stroke(lineWidth: stroke)
                ShortsWaistband().stroke(lineWidth: thin)
            }
            .frame(width: dim, height: dim)

        case "wearly.shorts.fill":
            ShortsShape()
                .overlay(
                    ShortsWaistband()
                        .stroke(lineWidth: thin)
                        .foregroundStyle(seamTint)
                )
                .frame(width: dim, height: dim)

        case "wearly.rainjacket":
            ZStack {
                RainJacketShape().stroke(lineWidth: stroke)
                RainJacketZipper().stroke(lineWidth: thin)
                RainJacketCollar().stroke(lineWidth: thin)
            }
            .frame(width: dim, height: dim)

        case "wearly.rainjacket.fill":
            RainJacketShape()
                .overlay(
                    ZStack {
                        RainJacketZipper().stroke(lineWidth: thin)
                        RainJacketCollar().stroke(lineWidth: thin)
                    }
                    .foregroundStyle(seamTint)
                )
                .frame(width: dim, height: dim)

        case "wearly.winterjacket":
            ZStack {
                WinterJacketShape().stroke(lineWidth: stroke)
                WinterJacketQuilts().stroke(lineWidth: thin)
            }
            .frame(width: dim, height: dim)

        case "wearly.winterjacket.fill":
            WinterJacketShape()
                .overlay(
                    WinterJacketQuilts()
                        .stroke(lineWidth: thin)
                        .foregroundStyle(seamTint)
                )
                .frame(width: dim, height: dim)

        default:
            Image(systemName: "questionmark.circle")
                .font(.system(size: size, weight: .ultraLight))
        }
    }
}

// MARK: - Path helpers

private func pt(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
}

// MARK: - T-shirt

/// Short-sleeve tee. Soft rounded shoulders, clear armpit notch, clean
/// crewneck dip. Proportions match SF's `tshirt`.
struct TShirtShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.40, 0.20))
        p.addQuadCurve(to: pt(rect, 0.60, 0.20),
                       control: pt(rect, 0.50, 0.32))                // neckline dip
        p.addQuadCurve(to: pt(rect, 0.74, 0.19),
                       control: pt(rect, 0.68, 0.18))                // right shoulder
        p.addQuadCurve(to: pt(rect, 0.94, 0.30),
                       control: pt(rect, 0.86, 0.22))                // sleeve top
        p.addQuadCurve(to: pt(rect, 0.78, 0.40),
                       control: pt(rect, 0.94, 0.40))                // sleeve cuff
        p.addQuadCurve(to: pt(rect, 0.74, 0.36),
                       control: pt(rect, 0.75, 0.38))                // inside sleeve
        p.addLine(to: pt(rect, 0.72, 0.94))                          // body right
        p.addLine(to: pt(rect, 0.28, 0.94))                          // hem
        p.addLine(to: pt(rect, 0.26, 0.36))                          // body left
        p.addQuadCurve(to: pt(rect, 0.22, 0.40),
                       control: pt(rect, 0.25, 0.38))
        p.addQuadCurve(to: pt(rect, 0.06, 0.30),
                       control: pt(rect, 0.06, 0.40))
        p.addQuadCurve(to: pt(rect, 0.26, 0.19),
                       control: pt(rect, 0.14, 0.22))                // left shoulder
        p.addQuadCurve(to: pt(rect, 0.40, 0.20),
                       control: pt(rect, 0.32, 0.18))                // back to neck
        p.closeSubpath()
        return p
    }
}

struct TShirtNeckline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.38, 0.24))
        p.addQuadCurve(to: pt(rect, 0.62, 0.24),
                       control: pt(rect, 0.50, 0.36))
        return p
    }
}

// MARK: - Long-sleeve

struct LongSleeveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.40, 0.20))
        p.addQuadCurve(to: pt(rect, 0.60, 0.20),
                       control: pt(rect, 0.50, 0.32))                // neckline
        p.addQuadCurve(to: pt(rect, 0.74, 0.18),
                       control: pt(rect, 0.68, 0.18))                // shoulder curve
        p.addQuadCurve(to: pt(rect, 0.94, 0.24),
                       control: pt(rect, 0.86, 0.20))
        p.addLine(to: pt(rect, 0.92, 0.84))                          // outer sleeve (slight taper)
        p.addQuadCurve(to: pt(rect, 0.76, 0.90),                     // cuff rounded
                       control: pt(rect, 0.94, 0.92))
        p.addLine(to: pt(rect, 0.74, 0.38))                          // underarm
        p.addLine(to: pt(rect, 0.72, 0.95))                          // body right
        p.addLine(to: pt(rect, 0.28, 0.95))                          // hem
        p.addLine(to: pt(rect, 0.26, 0.38))                          // body left
        p.addLine(to: pt(rect, 0.24, 0.90))                          // inner sleeve
        p.addQuadCurve(to: pt(rect, 0.08, 0.84),                     // left cuff
                       control: pt(rect, 0.06, 0.92))
        p.addLine(to: pt(rect, 0.06, 0.24))
        p.addQuadCurve(to: pt(rect, 0.26, 0.18),
                       control: pt(rect, 0.14, 0.20))
        p.addQuadCurve(to: pt(rect, 0.40, 0.20),
                       control: pt(rect, 0.32, 0.18))
        p.closeSubpath()
        return p
    }
}

struct LongSleeveNeckline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.38, 0.24))
        p.addQuadCurve(to: pt(rect, 0.62, 0.24),
                       control: pt(rect, 0.50, 0.36))
        return p
    }
}

// MARK: - Hoodie

struct HoodieShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.04, 0.30))
        p.addLine(to: pt(rect, 0.28, 0.28))
        p.addQuadCurve(to: pt(rect, 0.36, 0.22),                     // shoulder to hood seam
                       control: pt(rect, 0.32, 0.26))
        p.addQuadCurve(to: pt(rect, 0.50, 0.05),                     // hood left curve
                       control: pt(rect, 0.28, 0.06))
        p.addQuadCurve(to: pt(rect, 0.64, 0.22),                     // hood right curve
                       control: pt(rect, 0.72, 0.06))
        p.addQuadCurve(to: pt(rect, 0.72, 0.28),                     // shoulder to body
                       control: pt(rect, 0.68, 0.26))
        p.addLine(to: pt(rect, 0.96, 0.30))
        p.addLine(to: pt(rect, 0.94, 0.84))                          // outer sleeve
        p.addQuadCurve(to: pt(rect, 0.76, 0.90),
                       control: pt(rect, 0.96, 0.92))
        p.addLine(to: pt(rect, 0.74, 0.42))
        p.addLine(to: pt(rect, 0.72, 0.95))                          // body right
        p.addLine(to: pt(rect, 0.28, 0.95))                          // hem
        p.addLine(to: pt(rect, 0.26, 0.42))                          // body left
        p.addLine(to: pt(rect, 0.24, 0.90))
        p.addQuadCurve(to: pt(rect, 0.06, 0.84),
                       control: pt(rect, 0.04, 0.92))
        p.closeSubpath()
        return p
    }
}

/// Curve tracing the front of the hood opening.
struct HoodieNeckline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.34, 0.28))
        p.addQuadCurve(to: pt(rect, 0.66, 0.28),
                       control: pt(rect, 0.50, 0.42))
        return p
    }
}

/// Kangaroo pocket across the front of the body.
struct HoodiePocket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // rounded trapezoid near the hem
        p.move(to: pt(rect, 0.30, 0.72))
        p.addQuadCurve(to: pt(rect, 0.50, 0.82),
                       control: pt(rect, 0.34, 0.84))
        p.addQuadCurve(to: pt(rect, 0.70, 0.72),
                       control: pt(rect, 0.66, 0.84))
        return p
    }
}

// MARK: - Sweatpants

struct SweatpantsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.14, 0.04))
        p.addLine(to: pt(rect, 0.86, 0.04))                          // waistband top
        p.addLine(to: pt(rect, 0.90, 0.88))                          // right leg outer
        p.addQuadCurve(to: pt(rect, 0.66, 0.95),                     // elastic cuff curve
                       control: pt(rect, 0.92, 0.96))
        p.addQuadCurve(to: pt(rect, 0.54, 0.28),                     // right inseam
                       control: pt(rect, 0.62, 0.62))
        p.addQuadCurve(to: pt(rect, 0.46, 0.28),                     // V crotch
                       control: pt(rect, 0.50, 0.22))
        p.addQuadCurve(to: pt(rect, 0.34, 0.95),                     // left inseam
                       control: pt(rect, 0.38, 0.62))
        p.addQuadCurve(to: pt(rect, 0.10, 0.88),                     // left cuff
                       control: pt(rect, 0.08, 0.96))
        p.closeSubpath()
        return p
    }
}

struct WaistbandDetail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.15, 0.14))
        p.addLine(to: pt(rect, 0.85, 0.14))
        return p
    }
}

// MARK: - Shorts

struct ShortsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.14, 0.18))
        p.addLine(to: pt(rect, 0.86, 0.18))                          // waistband
        p.addQuadCurve(to: pt(rect, 0.93, 0.70),                     // outer right flared leg
                       control: pt(rect, 0.94, 0.52))
        p.addQuadCurve(to: pt(rect, 0.64, 0.74),                     // right hem rounded
                       control: pt(rect, 0.78, 0.78))
        p.addQuadCurve(to: pt(rect, 0.54, 0.40),
                       control: pt(rect, 0.60, 0.56))
        p.addQuadCurve(to: pt(rect, 0.46, 0.40),
                       control: pt(rect, 0.50, 0.32))
        p.addQuadCurve(to: pt(rect, 0.36, 0.74),
                       control: pt(rect, 0.40, 0.56))
        p.addQuadCurve(to: pt(rect, 0.07, 0.70),
                       control: pt(rect, 0.22, 0.78))
        p.closeSubpath()
        return p
    }
}

struct ShortsWaistband: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.15, 0.26))
        p.addLine(to: pt(rect, 0.85, 0.26))
        return p
    }
}

// MARK: - Rain jacket (long, sleek, hooded)

struct RainJacketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.06, 0.30))
        p.addLine(to: pt(rect, 0.26, 0.26))
        p.addQuadCurve(to: pt(rect, 0.36, 0.20),                     // shoulder-hood seam
                       control: pt(rect, 0.32, 0.24))
        p.addQuadCurve(to: pt(rect, 0.50, 0.04),                     // hood
                       control: pt(rect, 0.26, 0.04))
        p.addQuadCurve(to: pt(rect, 0.64, 0.20),
                       control: pt(rect, 0.74, 0.04))
        p.addQuadCurve(to: pt(rect, 0.74, 0.26),
                       control: pt(rect, 0.68, 0.24))
        p.addLine(to: pt(rect, 0.94, 0.30))
        p.addLine(to: pt(rect, 0.92, 0.82))                          // outer sleeve
        p.addQuadCurve(to: pt(rect, 0.76, 0.88),
                       control: pt(rect, 0.94, 0.90))
        p.addLine(to: pt(rect, 0.74, 0.46))
        p.addQuadCurve(to: pt(rect, 0.73, 0.98),                     // long body right
                       control: pt(rect, 0.76, 0.76))
        p.addLine(to: pt(rect, 0.27, 0.98))                          // long hem
        p.addQuadCurve(to: pt(rect, 0.26, 0.46),
                       control: pt(rect, 0.24, 0.76))
        p.addLine(to: pt(rect, 0.24, 0.88))
        p.addQuadCurve(to: pt(rect, 0.08, 0.82),
                       control: pt(rect, 0.06, 0.90))
        p.closeSubpath()
        return p
    }
}

struct RainJacketCollar: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.35, 0.26))
        p.addQuadCurve(to: pt(rect, 0.65, 0.26),
                       control: pt(rect, 0.50, 0.38))
        return p
    }
}

/// Central zipper running top-to-bottom.
struct RainJacketZipper: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.50, 0.26))
        p.addLine(to: pt(rect, 0.50, 0.96))
        return p
    }
}

// MARK: - Winter jacket (bulky, quilted)

struct WinterJacketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(rect, 0.02, 0.32))
        p.addQuadCurve(to: pt(rect, 0.22, 0.24),                     // puffy shoulder
                       control: pt(rect, 0.08, 0.26))
        p.addQuadCurve(to: pt(rect, 0.38, 0.22),                     // collar
                       control: pt(rect, 0.30, 0.18))
        p.addQuadCurve(to: pt(rect, 0.50, 0.18),                     // collar dip
                       control: pt(rect, 0.44, 0.28))
        p.addQuadCurve(to: pt(rect, 0.62, 0.22),
                       control: pt(rect, 0.56, 0.28))
        p.addQuadCurve(to: pt(rect, 0.78, 0.24),
                       control: pt(rect, 0.70, 0.18))
        p.addQuadCurve(to: pt(rect, 0.98, 0.32),
                       control: pt(rect, 0.92, 0.26))
        p.addQuadCurve(to: pt(rect, 0.94, 0.84),                     // puffy outer sleeve
                       control: pt(rect, 1.00, 0.58))
        p.addQuadCurve(to: pt(rect, 0.76, 0.90),
                       control: pt(rect, 0.95, 0.94))
        p.addLine(to: pt(rect, 0.74, 0.46))
        p.addQuadCurve(to: pt(rect, 0.76, 0.96),                     // bulk body right
                       control: pt(rect, 0.82, 0.72))
        p.addLine(to: pt(rect, 0.24, 0.96))
        p.addQuadCurve(to: pt(rect, 0.26, 0.46),
                       control: pt(rect, 0.18, 0.72))
        p.addLine(to: pt(rect, 0.24, 0.90))
        p.addQuadCurve(to: pt(rect, 0.06, 0.84),
                       control: pt(rect, 0.00, 0.94))
        p.closeSubpath()
        return p
    }
}

/// Horizontal quilt seams across the body — three bands.
struct WinterJacketQuilts: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Band 1
        p.move(to: pt(rect, 0.28, 0.42))
        p.addQuadCurve(to: pt(rect, 0.72, 0.42),
                       control: pt(rect, 0.50, 0.46))
        // Band 2
        p.move(to: pt(rect, 0.27, 0.58))
        p.addQuadCurve(to: pt(rect, 0.73, 0.58),
                       control: pt(rect, 0.50, 0.62))
        // Band 3
        p.move(to: pt(rect, 0.27, 0.74))
        p.addQuadCurve(to: pt(rect, 0.73, 0.74),
                       control: pt(rect, 0.50, 0.78))
        return p
    }
}
