//
//  LogInHelper.swift
//  Glimpse
//
//  Created by Kyle Bashour on 4/16/24.
//

import SwiftUI
import ServiceManagement

@Observable class LoginItemHelper {
    var isEnabled = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if isEnabled {
                    if SMAppService.mainApp.status == .enabled {
                        try? SMAppService.mainApp.unregister()
                    }

                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle menu bar item.")
            }
        }
    }
}
