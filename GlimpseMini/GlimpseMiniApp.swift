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
    @AppStorage(.useMMOLKey) private var useMMOL = false
    @AppStorage(.outsideUSKey) private var outsideUS = false

    @State private var model = ViewModel()
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Glimpse Mini", id: .settingsWindow) {
            SettingsView(didLogIn: model.logIn)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 200, height: 0)

        MenuBarExtra {
            if let timestamp = model.message {
                Text(timestamp)
                Divider()
            }

            Button {
                openWindow(id: .settingsWindow)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
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
                    let value = useMMOL
                    ? (Double(reading.value) * .mmolConversionFactor).formatted(.number.precision(.fractionLength(1)))
                    : reading.value.formatted()

                    HStack {
                        Image(systemName: reading.trend.image)
                        Text(value)
                    }
                case .noRecentReading:
                    Image(systemName: "icloud.slash")
                case .error:
                    Image(systemName: "person.crop.circle.badge.xmark")
                }
            } else {
                Text("Glimpse")
            }
        }
        .onChange(of: outsideUS) { _, newValue in
            model.outsideUS = newValue
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
