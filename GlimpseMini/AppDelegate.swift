//
//  AppDelegate.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/12/24.
//

import AppKit
import KeychainAccess

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Keychain.standard[.usernameKey] != nil, let window = NSApplication.shared.windows.first {
            window.close()
        }
    }
}
