//
//  ViewModel.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/11/24.
//

import SwiftUI
import Dexcom
import KeychainAccess

@Observable class ViewModel {
    enum State {
        case initial
        case loaded(GlucoseReading)
        case noRecentReading
        case error(Error)
    }

    var isLoggedIn: Bool {
        username != nil && password != nil
    }

    private(set) var reading: State = .initial
    private(set) var message: String?

    private(set) var username: String? = Keychain.standard[.usernameKey]
    private(set) var password: String? = Keychain.standard[.passwordKey]
    private var outsideUS: Bool = UserDefaults.standard.bool(forKey: .outsideUSKey)

    private var client: DexcomClient?
    private var timer: Timer?
    private let decoder = JSONDecoder()

    private var shouldRefreshReading: Bool {
        switch reading {
        case .initial, .error, .noRecentReading:
            return true
        case .loaded(let reading):
            return reading.date.timeIntervalSinceNow < -60 * 5
        }
    }

    init() {
        decoder.dateDecodingStrategy = .iso8601
        setUpClientAndBeginRefreshing()
    }

    func logIn(username: String, password: String, outsideUS: Bool) {
        self.username = username
        self.password = password
        self.outsideUS = outsideUS

        setUpClientAndBeginRefreshing()
    }

    private func setUpClientAndBeginRefreshing() {
        if let username, let password {
            client = DexcomClient(
                username: username,
                password: password,
                outsideUS: outsideUS
            )

            beginRefreshing()
        }
    }

    func beginRefreshing() {
        timer?.invalidate()

        guard client != nil else {
            return
        }

        timer = .scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] _ in
            Task { [weak self] in
                await self?.refresh()
            }
        })

        timer?.fire()
    }

    private func refresh() async {
        guard let client else { return }

        if shouldRefreshReading {
            do {
                if let current = try await client.getCurrentGlucoseReading() {
                    reading = .loaded(current)
                } else {
                    reading = .noRecentReading
                }
            } catch {
                reading = .error(error)
            }
        }

        updateMessage()
    }

    private func updateMessage() {
        switch reading {
        case .initial:
            message = "Loading..."
        case .loaded(let reading):
            message = reading.date.formatted(.relative(presentation: .numeric))
        case .noRecentReading:
            message = "No recent glucose readings"
        case .error(let error):
            message = "\(error)"
        }
    }
}
