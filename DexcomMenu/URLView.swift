//
//  ContentView.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/11/24.
//

import SwiftUI

struct URLView: View {
    @State private var text = UserDefaults.standard.url(forKey: .urlKey)?.absoluteString ?? ""
    @Environment(\.dismissWindow) private var dismissWindow
    private var url: URL? { URL(string: text) }

    var didEnterURL: (URL) -> Void

    var body: some View {
        HStack {
            TextField("Enter a dexcom-vapor URL", text: $text)
                .textFieldStyle(.roundedBorder)

            Button("Save") {
                UserDefaults.standard.set(url, forKey: .urlKey)
                if let url { didEnterURL(url) }
                dismissWindow(id: .settingsWindow)
            }
            .disabled(url == nil)
        }
        .padding()
    }
}

#Preview {
    URLView { _ in }
}
