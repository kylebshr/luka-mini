//
//  DexcomMenuApp.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/11/24.
//

import SwiftUI
import Dexcom

@main
struct DexcomMenuApp: App {
    @State private var model = ViewModel()
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("DexcomMenu", id: .settingsWindow) {
            SettingsView(didLogIn: model.logIn)
        }
        .defaultSize(width: 200, height: 0)

        MenuBarExtra {
            if let timestamp = model.message {
                Text(timestamp)
                Divider()
            }

            Button {
                openWindow(id: .settingsWindow)

                DispatchQueue.main.async {
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                        window.setIsVisible(true)
                    }
                }
            } label: {
                Text(model.isLoggedIn ? "Settings" : "Log In")
            }.keyboardShortcut(",")

            if model.isLoggedIn {
                Button("Refresh") {
                    model.beginRefreshing()
                }.keyboardShortcut("r")
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        } label: {
            if model.isLoggedIn {
                switch model.reading {
                case .initial:
                    Text("--")
                case .loaded(let reading):
                    HStack {
                        Image(systemName: reading.trend.image)
                        Text("\(reading.value)")
                    }
                case .noRecentReading:
                    Image(systemName: "icloud.slash")
                case .error:
                    Image(systemName: "person.crop.circle.badge.xmark")
                }
            } else {
                Text("DexcomMenu")
            }
        }
    }
}

extension TrendDirection {
    var image: String {
        switch self {
        case .none:
            "minus"
        case .doubleUp:
            "arrow.up.to.line"
        case .singleUp:
            "arrow.up"
        case .fortyFiveUp:
            "arrow.up.right"
        case .flat:
            "arrow.right"
        case .fortyFiveDown:
            "arrow.down.right"
        case .singleDown:
            "arrow.down"
        case .doubleDown:
            "arrow.down.to.line"
        case .notComputable:
            "questionmark"
        case .rateOutOfRange:
            "exclamationmark"
        }
    }
}
