//
//  TemperatureGradient.swift
//  Wearly
//
//  A stylized scenic backdrop — sky gradient, distant mountains,
//  pine silhouettes, ground plane, and a soft sun disc — whose
//  entire palette shifts with the temperature category. Weather
//  particles (rain streaks, snow flakes, wind, fog) layer on top.
//
//  Inspired by Louie Mantia / NZ-style illustrated weather apps:
//  the landscape *is* the background. Typography sits over it with
//  a subtle top/bottom readability darken.
//

import SwiftUI

struct TemperatureGradient: View {
    let category: TempCategory
    var condition: Weather.Condition = .cloudy
    var isRaining: Bool = false

    private var palette: ScenicPalette { .palette(for: category) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // --- Sky ---
                LinearGradient(
                    colors: palette.sky,
                    startPoint: .top,
                    endPoint: .bottom
                )

                // --- Sun / moon ---
                // Hidden in rain + fog where the sky is occluded.
                if condition != .rain && condition != .foggy {
                    sunElements(size: geo.size)
                }

                // --- Mountains: distant → front, increasingly dark ---
                HorizonShape(
                    baseFactor: 0.55,
                    amplitudeFactor: 0.08,
                    frequency: 2.2,
                    phase: 0.15
                )
                .fill(palette.mountainBack)

                HorizonShape(
                    baseFactor: 0.66,
                    amplitudeFactor: 0.06,
                    frequency: 3.1,
                    phase: 0.42
                )
                .fill(palette.mountainMid)

                HorizonShape(
                    baseFactor: 0.76,
                    amplitudeFactor: 0.05,
                    frequency: 4.3,
                    phase: 0.71
                )
                .fill(palette.mountainFront)

                // --- Foreground pine trees ---
                treeCluster(size: geo.size)

                // --- Ground strip ---
                Rectangle()
                    .fill(palette.ground)
                    .frame(height: geo.size.height * 0.08)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // --- Weather particles layer on top of the scene ---
                conditionOverlay
                    .allowsHitTesting(false)

                // --- Readability darken (for header + day bar text) ---
                LinearGradient(
                    colors: [
                        .black.opacity(0.16),
                        .clear,
                        .clear,
                        .black.opacity(0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Scene elements

    @ViewBuilder
    private func sunElements(size: CGSize) -> some View {
        // Warm radial glow behind the sun disc.
        RadialGradient(
            colors: [palette.sunGlow, palette.sunGlow.opacity(0)],
            center: .center,
            startRadius: 10,
            endRadius: min(size.width, size.height) * 0.42
        )
        .frame(width: size.width * 1.2, height: size.width * 1.2)
        .position(x: size.width * 0.70, y: size.height * 0.32)
        .blendMode(.plusLighter)

        Circle()
            .fill(palette.sun)
            .frame(width: 56, height: 56)
            .blur(radius: 6)
            .opacity(0.85)
            .position(x: size.width * 0.70, y: size.height * 0.32)
    }

    private func treeCluster(size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            PineTreeShape()
                .fill(palette.tree.opacity(0.9))
                .frame(width: 30, height: 92)
                .offset(x: -48, y: 0)
            PineTreeShape()
                .fill(palette.tree)
                .frame(width: 46, height: 130)
                .offset(x: 0, y: 0)
            PineTreeShape()
                .fill(palette.tree.opacity(0.88))
                .frame(width: 26, height: 80)
                .offset(x: 38, y: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, size.width * 0.20)
        .padding(.bottom, size.height * 0.07)
    }

    // MARK: - Condition overlay

    @ViewBuilder
    private var conditionOverlay: some View {
        switch condition {
        case .rain:  RainOverlay(density: isRaining ? 0.55 : 0.25)
        case .snow:  SnowOverlay()
        case .foggy: FogOverlay()
        case .windy: WindOverlay()
        default:     EmptyView()
        }
    }
}

// MARK: - Scenic palette

struct ScenicPalette {
    let sky: [Color]
    let mountainBack: Color
    let mountainMid: Color
    let mountainFront: Color
    let tree: Color
    let ground: Color
    let sun: Color
    let sunGlow: Color

    static func palette(for category: TempCategory) -> ScenicPalette {
        switch category {
        case .freezing:
            return ScenicPalette(
                sky: [
                    Color(red: 0.70, green: 0.84, blue: 0.98),
                    Color(red: 0.42, green: 0.62, blue: 0.88)
                ],
                mountainBack: Color(red: 0.66, green: 0.78, blue: 0.92),
                mountainMid:  Color(red: 0.46, green: 0.58, blue: 0.78),
                mountainFront: Color(red: 0.26, green: 0.38, blue: 0.56),
                tree: Color(red: 0.16, green: 0.26, blue: 0.36),
                ground: Color(red: 0.88, green: 0.94, blue: 1.00),
                sun: Color(red: 1.00, green: 0.95, blue: 0.82),
                sunGlow: Color(red: 0.90, green: 0.96, blue: 1.00).opacity(0.40)
            )
        case .cold:
            return ScenicPalette(
                sky: [
                    Color(red: 0.64, green: 0.80, blue: 0.95),
                    Color(red: 0.38, green: 0.56, blue: 0.82)
                ],
                mountainBack: Color(red: 0.58, green: 0.72, blue: 0.88),
                mountainMid:  Color(red: 0.40, green: 0.52, blue: 0.72),
                mountainFront: Color(red: 0.22, green: 0.32, blue: 0.48),
                tree: Color(red: 0.12, green: 0.22, blue: 0.30),
                ground: Color(red: 0.78, green: 0.88, blue: 0.96),
                sun: Color(red: 1.00, green: 0.92, blue: 0.76),
                sunGlow: Color(red: 0.82, green: 0.92, blue: 1.00).opacity(0.35)
            )
        case .mild:
            return ScenicPalette(
                sky: [
                    Color(red: 0.72, green: 0.80, blue: 0.95),
                    Color(red: 0.62, green: 0.60, blue: 0.86)
                ],
                mountainBack: Color(red: 0.62, green: 0.58, blue: 0.80),
                mountainMid:  Color(red: 0.42, green: 0.40, blue: 0.62),
                mountainFront: Color(red: 0.22, green: 0.24, blue: 0.40),
                tree: Color(red: 0.14, green: 0.22, blue: 0.20),
                ground: Color(red: 0.46, green: 0.60, blue: 0.40),
                sun: Color(red: 1.00, green: 0.88, blue: 0.72),
                sunGlow: Color(red: 0.95, green: 0.82, blue: 0.82).opacity(0.40)
            )
        case .pleasant:
            return ScenicPalette(
                sky: [
                    Color(red: 0.86, green: 0.70, blue: 0.92),
                    Color(red: 0.66, green: 0.50, blue: 0.84)
                ],
                mountainBack: Color(red: 0.60, green: 0.48, blue: 0.72),
                mountainMid:  Color(red: 0.42, green: 0.36, blue: 0.60),
                mountainFront: Color(red: 0.22, green: 0.20, blue: 0.34),
                tree: Color(red: 0.18, green: 0.26, blue: 0.22),
                ground: Color(red: 0.50, green: 0.64, blue: 0.38),
                sun: Color(red: 1.00, green: 0.78, blue: 0.64),
                sunGlow: Color(red: 1.00, green: 0.78, blue: 0.84).opacity(0.50)
            )
        case .warm:
            return ScenicPalette(
                sky: [
                    Color(red: 1.00, green: 0.74, blue: 0.62),
                    Color(red: 0.92, green: 0.46, blue: 0.50)
                ],
                mountainBack: Color(red: 0.78, green: 0.58, blue: 0.72),
                mountainMid:  Color(red: 0.44, green: 0.30, blue: 0.52),
                mountainFront: Color(red: 0.22, green: 0.18, blue: 0.32),
                tree: Color(red: 0.28, green: 0.35, blue: 0.22),
                ground: Color(red: 0.86, green: 0.76, blue: 0.42),
                sun: Color(red: 1.00, green: 0.78, blue: 0.48),
                sunGlow: Color(red: 1.00, green: 0.68, blue: 0.55).opacity(0.55)
            )
        case .hot:
            return ScenicPalette(
                sky: [
                    Color(red: 1.00, green: 0.62, blue: 0.42),
                    Color(red: 0.84, green: 0.30, blue: 0.32)
                ],
                mountainBack: Color(red: 0.64, green: 0.44, blue: 0.52),
                mountainMid:  Color(red: 0.32, green: 0.22, blue: 0.34),
                mountainFront: Color(red: 0.16, green: 0.10, blue: 0.22),
                tree: Color(red: 0.22, green: 0.28, blue: 0.16),
                ground: Color(red: 0.82, green: 0.58, blue: 0.32),
                sun: Color(red: 1.00, green: 0.58, blue: 0.36),
                sunGlow: Color(red: 1.00, green: 0.50, blue: 0.38).opacity(0.60)
            )
        }
    }
}

// MARK: - Mountain silhouette shape

/// A horizon built from three superimposed sine waves — gives mountains
/// more character than a single sine without needing to list peaks.
struct HorizonShape: Shape {
    let baseFactor: CGFloat
    let amplitudeFactor: CGFloat
    let frequency: Double
    let phase: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseY = rect.height * baseFactor
        let amplitude = rect.height * amplitudeFactor

        path.move(to: CGPoint(x: 0, y: rect.height))

        let step: CGFloat = 5
        var x: CGFloat = 0
        while x <= rect.width {
            let norm = Double(x / rect.width)
            let a = sin((norm + phase) * .pi * 2 * frequency)
            let b = cos((norm + phase) * .pi * 2 * frequency * 1.7 + 1.3) * 0.35
            let c = sin((norm + phase) * .pi * 2 * frequency * 3.2 + 0.7) * 0.15
            // Clamp downward dips so the mountains don't bite below the baseline.
            let combined = max(a + b + c, -0.25)
            let y = baseY - CGFloat(combined) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Pine tree shape

struct PineTreeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Trunk
        let trunkW = w * 0.18
        let trunkH = h * 0.12
        path.addRect(CGRect(
            x: w / 2 - trunkW / 2,
            y: h - trunkH,
            width: trunkW,
            height: trunkH
        ))

        // Foliage — single tall triangle. Reads as a pine at any size.
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h - trunkH))
        path.addLine(to: CGPoint(x: w, y: h - trunkH))
        path.closeSubpath()

        return path
    }
}

// MARK: - Condition particle overlays
// (Sun and clouds are rendered directly by the scene above.)

private struct FogOverlay: View {
    @State private var shift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(.white.opacity(0.04))
                        .frame(width: geo.size.width * 1.4, height: 40)
                        .blur(radius: 20)
                        .offset(
                            x: shift * (i.isMultiple(of: 2) ? 1 : -1),
                            y: CGFloat(i) * 110 - geo.size.height * 0.25
                        )
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 28).repeatForever(autoreverses: true)) {
                    shift = 40
                }
            }
        }
    }
}

/// Diagonal rain streaks — the only condition layer that animates fast,
/// because that's physically what rain looks like.
private struct RainOverlay: View {
    var density: Double = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let count = Int(55 * density)
                for i in 0..<count {
                    let seed = Double(i) * 13.37
                    let xBase = fmod(seed * 97, 1) * size.width
                    let speed = 280.0 + fmod(seed * 31, 140)
                    let yLoop = fmod((t * speed + seed * 40).truncatingRemainder(dividingBy: 1400),
                                     size.height + 80)
                    let x = xBase - yLoop * 0.12
                    let y = yLoop - 40
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x - 3, y: y + 26))
                    ctx.stroke(path,
                               with: .color(.white.opacity(0.30)),
                               lineWidth: 1.1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Slowly drifting snowflakes.
private struct SnowOverlay: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for i in 0..<25 {                   // less dense
                    let seed = Double(i) * 7.77
                    let xBase = fmod(seed * 97, 1) * size.width
                    let sway = sin(t * 0.7 + seed) * 26
                    let speed = 22.0 + fmod(seed * 13, 16)
                    let yLoop = fmod((t * speed + seed * 20).truncatingRemainder(dividingBy: 1600),
                                     size.height + 40)
                    let x = xBase + sway
                    let y = yLoop - 20
                    let r = 1.6 + CGFloat(fmod(seed, 2))
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(.white.opacity(0.40)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WindOverlay: View {
    @State private var shift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(.white.opacity(0.05))
                        .frame(width: geo.size.width * 0.45, height: 2)
                        .rotationEffect(.degrees(-10))
                        .offset(
                            x: shift + CGFloat(i) * 70 - geo.size.width * 0.1,
                            y: CGFloat(i) * 110 - geo.size.height * 0.2
                        )
                }
            }
            .onAppear {
                withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                    shift = 80
                }
            }
        }
    }
}
