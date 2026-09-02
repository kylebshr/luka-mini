//
//  GlucoseRange.swift
//  LukaMini
//

import AppKit
import SwiftUI

enum GlucoseRange {
    enum Classification {
        case low
        case inRange
        case high
    }

    static let defaultLowerBound = 70
    static let defaultUpperBound = 180

    static func classification(
        for value: Int,
        lowerBound: Int = defaultLowerBound,
        upperBound: Int = defaultUpperBound
    ) -> Classification {
        if value < lowerBound {
            return .low
        } else if value > upperBound {
            return .high
        } else {
            return .inRange
        }
    }

    static func color(
        for value: Int,
        lowerBound: Int = defaultLowerBound,
        upperBound: Int = defaultUpperBound
    ) -> Color {
        Color(nsColor: nsColor(for: value, lowerBound: lowerBound, upperBound: upperBound))
    }

    static func nsColor(
        for value: Int,
        lowerBound: Int = defaultLowerBound,
        upperBound: Int = defaultUpperBound
    ) -> NSColor {
        switch classification(for: value, lowerBound: lowerBound, upperBound: upperBound) {
        case .low:
            .lowColor
        case .inRange:
            .inRangeColor
        case .high:
            .highColor
        }
    }
}
