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

    @ObservationIgnored var url: URL? = UserDefaults.standard.url(forKey: .urlKey) {
        didSet { beginRefreshing() }
    }

    private var timer: Timer?
    private let decoder = JSONDecoder()

    init() {
        decoder.dateDecodingStrategy = .iso8601
        beginRefreshing()
    }

    func beginRefreshing() {
        guard url != nil else { return }

        timer?.invalidate()
        
        timer = .scheduledTimer(withTimeInterval: 60, repeats: true, block: { [weak self] _ in
            Task { [weak self] in
                await self?.refresh()
            }
        })

        timer?.fire()
    }

    private func refresh() async {
        guard let url else { return }

        let currentURL = url.appending(path: "current")

        guard let (data, _) = try? await URLSession.shared.data(from: currentURL) else {
            return reading = .loaded(nil)
        }

        reading = .loaded(try? decoder.decode(GlucoseReading.self, from: data))
    }
}
