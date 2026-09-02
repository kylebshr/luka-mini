//
//  Color+Extensions.swift
//  LukaMini
//

import AppKit
import SwiftUI

extension NSColor {
    static let lowColor = glucoseColor(mixing: .systemPink, with: .systemRed)
    static let inRangeColor = glucoseColor(mixing: .systemMint, with: .systemGreen)
    static let highColor = glucoseColor(mixing: .systemYellow, with: .systemOrange)

    /// Glucose colors are darkened in light appearances and lightened slightly
    /// in dark ones so they hold contrast against both the menu bar and charts.
    private static func glucoseColor(mixing first: NSColor, with second: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            var color = first
            appearance.performAsCurrentDrawingAppearance {
                let base = first.blended(withFraction: 0.5, of: second) ?? first
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let adjusted = isDark
                    ? base.blended(withFraction: 0.12, of: .white)
                    : base.blended(withFraction: 0.35, of: .black)
                color = adjusted ?? base
            }
            return color
        }
    }

    /// Resolves a dynamic color to a fixed color for the given appearance.
    func resolved(for appearance: NSAppearance) -> NSColor {
        var color = self
        appearance.performAsCurrentDrawingAppearance {
            color = usingColorSpace(.sRGB) ?? self
        }
        return color
    }
}

extension Color {
    static var lowColor: Color { Color(nsColor: .lowColor) }
    static var inRangeColor: Color { Color(nsColor: .inRangeColor) }
    static var highColor: Color { Color(nsColor: .highColor) }
}
