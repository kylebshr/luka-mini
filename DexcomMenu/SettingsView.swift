//
//  ContentView.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/11/24.
//

import SwiftUI
import KeychainAccess

struct SettingsView: View {
    @State private var username = Keychain.standard[.usernameKey] ?? ""
    @State private var password = Keychain.standard[.passwordKey] ?? ""
    @State private var outsideUS = UserDefaults.standard.bool(forKey: .outsideUSKey)

    @Environment(\.dismissWindow) private var dismissWindow

    var didLogIn: (String, String, Bool) -> Void

    var body: some View {
        VStack(alignment: .trailing) {
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Toggle("Outside US", isOn: $outsideUS)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Log In") {
                Keychain.standard[.usernameKey] = username
                Keychain.standard[.passwordKey] = password

                didLogIn(username, password, outsideUS)

                dismissWindow(id: .settingsWindow)
            }
            .disabled(username.isEmpty || password.isEmpty)
        }
        .padding()
    }
}
