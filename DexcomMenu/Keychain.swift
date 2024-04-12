//
//  Keychain.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/12/24.
//

import KeychainAccess

extension Keychain {
    static let standard = Keychain(service: "com.kylebashour.DexcomMenu")
}
