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
        VStack(alignment: .leading) {
            Picker("Units", selection: $mmol) {
                Text("mg/dl").tag(false)
                Text("mmol/L").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.bottom)

            Text("Log in using your Dexcom username and password. Dexcom share must be enabled with at least one follower.")
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    SettingsView(didLogIn: {_, _ in})
}
