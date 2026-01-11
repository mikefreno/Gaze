//
//  ViewExtensions.swift
//  Gaze
//
//  Created by Mike Freno on 1/11/26.
//

import SwiftUI

extension View {
    @ViewBuilder
    func glassEffectIfAvailable<S: InsettableShape>(
        _ style: GlassStyle,
        in shape: S
    ) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(style.toGlass(), in: shape)
        } else {
            self.background {
                ZStack {
                    if let tintColor = style.getTintColor() {
                        shape
                            .fill(tintColor.opacity(0.8))
                    } else {
                        shape
                            .fill(.ultraThinMaterial)
                    }

                    // Border with tint color mixed with white
                    if let tintColor = style.getTintColor() {
                        shape
                            .strokeBorder(
                                Color(
                                    red: (tintColor.cgColor?.components?[0] ?? 1.0) * 0.7 + 0.3,
                                    green: (tintColor.cgColor?.components?[1] ?? 1.0) * 0.7 + 0.3,
                                    blue: (tintColor.cgColor?.components?[2] ?? 1.0) * 0.7 + 0.3
                                ).opacity(0.6),
                                lineWidth: 1.5
                            )
                    }
                }
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
    }
}

struct GlassStyle {
    private let tintColor: Color?
    private let isInteractive: Bool

    static let regular = GlassStyle(tintColor: nil, isInteractive: false)

    private init(tintColor: Color?, isInteractive: Bool) {
        self.tintColor = tintColor
        self.isInteractive = isInteractive
    }

    func tint(_ color: Color) -> GlassStyle {
        GlassStyle(tintColor: color, isInteractive: isInteractive)
    }

    func interactive() -> GlassStyle {
        GlassStyle(tintColor: tintColor, isInteractive: true)
    }

    func getTintColor() -> Color? {
        return tintColor
    }

    @available(macOS 26.0, *)
    func toGlass() -> Glass {
        var glass = Glass.regular
        if let tintColor = tintColor {
            glass = glass.tint(tintColor)
        }
        if isInteractive {
            glass = glass.interactive()
        }
        return glass
    }
}
