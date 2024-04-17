//
//  DexcomMenuApp.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/11/24.
//

import SwiftUI
import Dexcom
import KeychainAccess

@main
struct DexcomMenuApp: App {
    @AppStorage(.useMMOLKey) private var useMMOL = false
    @AppStorage(.outsideUSKey) private var outsideUS = false

    @State private var loginHelper = LoginItemHelper()
    @State private var model = ViewModel()
    
    @Environment(\.openWindow) private var openWindow
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Glimpse Mini", id: .settingsWindow) {
            SettingsView(didLogIn: model.logIn)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 0)

        MenuBarExtra {
            if let timestamp = model.message {
                Text(timestamp)
                Divider()
            }

            Toggle("Open at Login", isOn: $loginHelper.isEnabled)

            if model.isLoggedIn {
                Button("Manually Refresh") {
                    model.beginRefreshing()
                }
            }

            Button {
                openWindow(id: .settingsWindow)

                for window in NSApplication.shared.windows {
                    if window.identifier?.rawValue == .settingsWindow {
                        window.level = .floating
                    }
                }
            } label: {
                Text(model.isLoggedIn ? "Settings" : "Log In")
            }.keyboardShortcut(",")

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")

            #if DEBUG
            Divider()

            Button("Reset Keychain") {
                Keychain.standard[.usernameKey] = nil
                Keychain.standard[.passwordKey] = nil
            }
            #endif
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
                        reading.trend.image
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
    var image: Image? {
        switch self {
        case .none:
            nil
        case .doubleUp:
            Image("arrow.up.double")
        case .singleUp:
            Image(systemName: "arrow.up")
        case .fortyFiveUp:
            Image(systemName: "arrow.up.right")
        case .flat:
            Image(systemName: "arrow.right")
        case .fortyFiveDown:
            Image(systemName: "arrow.down.right")
        case .singleDown:
            Image(systemName: "arrow.down")
        case .doubleDown:
            Image("arrow.down.double")
        case .notComputable:
            Image(systemName: "questionmark")
        case .rateOutOfRange:
            Image(systemName: "exclamationmark")
        }
    }
}
