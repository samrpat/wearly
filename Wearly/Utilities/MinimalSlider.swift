//
//  MinimalSlider.swift
//  Wearly
//
//  A very quiet slider built on top of a DragGesture. Matches the
//  calm aesthetic of the settings screen and emits a subtle haptic
//  tick when the user lifts their finger.
//

import SwiftUI

struct MinimalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let span = max(range.upperBound - range.lowerBound, 0.0001)
            let clampedValue = min(max(value, range.lowerBound), range.upperBound)
            let ratio = (clampedValue - range.lowerBound) / span

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.white.opacity(0.08))
                    .frame(height: 4)

                // Filled track (brand-tinted)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [CategoryPalette.brandBright, CategoryPalette.brand],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, width * ratio), height: 4)

                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle().stroke(CategoryPalette.brand.opacity(0.5), lineWidth: 0.8)
                    )
                    .shadow(color: CategoryPalette.brand.opacity(0.35), radius: 8, y: 2)
                    .offset(x: width * ratio - 11)
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let r = min(max(0, v.location.x / max(width, 1)), 1)
                        let raw = range.lowerBound + r * span
                        let stepped = (raw / step).rounded() * step
                        if abs(stepped - value) >= step {
                            HapticsManager.selection()
                        }
                        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.85)) {
                            value = stepped
                        }
                    }
                    .onEnded { _ in HapticsManager.light() }
            )
        }
        .frame(height: 28)
    }
}
