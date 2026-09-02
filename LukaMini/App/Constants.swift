//
//  Constants.swift
//  LukaMini
//
//  Created by Kyle Bashour on 4/12/24.
//

import Foundation

extension String {
    static let usernameKey = "username"
    static let passwordKey = "password"
    static let locationKey = "location"
    static let useMMOLKey = "mmol"
    static let graphRangeKey = "graphRange"
    static let showNamesForMultipleUsersKey = "showNamesForMultipleUsers"
    static let colorMenuBarReadingKey = "colorMenuBarReading"
    static let lowerGlucoseThresholdKey = "lowerGlucoseThreshold"
    static let upperGlucoseThresholdKey = "upperGlucoseThreshold"
    static let outOfRangeNotificationsKey = "outOfRangeNotifications"
    static let useServerForReadingsKey = "useServerForReadings"
    static let profilesKey = "profiles"
}

extension Double {
    static let mmolConversionFactor: Double = 0.0555
}
