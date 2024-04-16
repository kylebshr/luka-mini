//
//  ContentView.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/11/24.
//

import SwiftUI
import KeychainAccess

struct SettingsView: View {
    @AppStorage(.useMMOLKey) private var mmol = false
    @AppStorage(.outsideUSKey) private var outsideUS = false

    @State private var username = Keychain.standard[.usernameKey] ?? ""
    @State private var password = Keychain.standard[.passwordKey] ?? ""

    @Environment(\.dismissWindow) private var dismissWindow

    var didLogIn: (String, String) -> Void

    var body: some View {
        VStack(alignment: .trailing) {
            Picker("Units", selection: $mmol) {
                Text("mg/dl").tag(false)
                Text("mmol/L").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.bottom)

            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Toggle("Outside US", isOn: $outsideUS)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Log In") {
                Keychain.standard[.usernameKey] = username
                Keychain.standard[.passwordKey] = password

                didLogIn(username, password)

                dismissWindow(id: .settingsWindow)
            }
            .disabled(username.isEmpty || password.isEmpty)
        }
        .padding()
        .frame(minWidth: 300)
    }
}

#Preview {
    SettingsView(didLogIn: {_, _ in})
}
