//
//  Keychain.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/12/24.
//

import Security
import KeychainAccess

extension Keychain {
    static var standard: Keychain {
        Keychain().synchronizable(true)
    }
}
