//
//  ViewModel.swift
//  DexcomMenu
//
//  Created by Kyle Bashour on 4/11/24.
//

import SwiftUI
import Dexcom

@Observable class ViewModel {
    enum State {
        case loading
        case loaded(GlucoseReading?)
    }

    var reading: State = .loading
    var timestamp: String?

    @ObservationIgnored var url: URL? = UserDefaults.standard.url(forKey: .urlKey) {
        didSet { beginRefreshing() }
    }

    private var timer: Timer?
    private let decoder = JSONDecoder()

    private var shouldRefreshReading: Bool {
        switch reading {
        case .loading:
            return true
        case .loaded(let reading):
            if let reading {
                return reading.date.timeIntervalSinceNow < -60 * 5
            } else {
                return true
            }
        }
    }

    init() {
        decoder.dateDecodingStrategy = .iso8601
        beginRefreshing()
    }

    func beginRefreshing() {
        guard url != nil else { return }

        timer?.invalidate()

        timer = .scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] _ in
            Task { [weak self] in
                await self?.refresh()
            }
        })

        timer?.fire()
    }

    private func refresh() async {
        guard let url else { return }

        if shouldRefreshReading {
            let currentURL = url.appending(path: "current")
            guard let (data, _) = try? await URLSession.shared.data(from: currentURL) else {
                reading = .loaded(nil)
                timestamp = "No recent readings"
                return
            }

            reading = .loaded(try? decoder.decode(GlucoseReading.self, from: data))
        }

        updateTimestamp()
    }

    private func updateTimestamp() {
        if case .loaded(let reading) = reading {
            timestamp = reading?.date.formatted(.relative(presentation: .numeric))
        }
    }
}
