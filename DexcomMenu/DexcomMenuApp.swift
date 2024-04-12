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
    @AppStorage(.urlKey) private var url: URL?
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Settings", id: .settingsWindow) {
            URLView { url in
                model.url = url
            }
        }
        .defaultSize(width: 400, height: 0)

        MenuBarExtra {
            if case .loaded(let reading) = model.reading, let reading {
                Text(reading.date.formatted(.relative(presentation: .numeric)))
            }

            Divider()

            Button {
                openWindow(id: .settingsWindow)

                DispatchQueue.main.async {
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                        window.setIsVisible(true)
                    }
                }
            } label: {
                if url == nil {
                    Text("Enter URL")
                } else {
                    Text("Settings")
                }
            }.keyboardShortcut(",")

            Button("Refresh") {
                model.beginRefreshing()
            }.keyboardShortcut("r")

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        } label: {
            if url == nil {
                Text("Dexcom Menu")
            } else {
                switch model.reading {
                case .loading:
                    Text("--")
                case .loaded(let reading):
                    if let reading {
                        HStack {
                            Image(systemName: reading.trend.image)
                            Text("\(reading.value)")
                        }
                    } else {
                        Image(systemName: "icloud.slash")
                    }
                }
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
