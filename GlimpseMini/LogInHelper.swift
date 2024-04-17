//
//  LogInHelper.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import ServiceManagement

@Observable class LoginItemHelper {
    private static let item = SMAppService.loginItem(identifier: Bundle.main.bundleIdentifier!)

    var isEnabled = LoginItemHelper.item.status == .enabled {
        didSet {
            do {
                if isEnabled {
                    if Self.item.status == .enabled {
                        try? Self.item.unregister()
                    }

                    try Self.item.register()
                } else {
                    try Self.item.unregister()
                }
            } catch {
                print("Failed to toggle menu bar item.")
            }
        }
    }
}
