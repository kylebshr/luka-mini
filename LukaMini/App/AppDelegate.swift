//
//  AppDelegate.swift
//  LukaMini
//
//  Created by Kyle Bashour on 4/12/24.
//

import AppKit
import Dexcom
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let appModel = AppModel()
    let loginHelper = LoginItemHelper()

    private var statusItems: [NSStatusItem] = []
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        GlucoseNotificationManager.shared.configure()

        appModel.profileModelsDidChange = { [weak self] in
            self?.rebuildStatusItems()
        }
        rebuildStatusItems()
        observeModel()

        if !appModel.hasProfiles {
            DispatchQueue.main.async { [weak self] in
                self?.showSettings()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(defaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    // MARK: - Observation

    private func observeModel() {
        withObservationTracking {
            updateStatusBarButtons()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeModel()
            }
        }
    }

    @objc private func defaultsDidChange() {
        updateStatusBarButtons()
    }

    // MARK: - Status Items

    private var visibleProfileModels: [GlucoseProfileModel] {
        appModel.profileModels.filter { $0.profile.showsInMenuBar }
    }

    private var graphRange: GraphRange {
        UserDefaults.standard.string(forKey: .graphRangeKey)
            .flatMap(GraphRange.init(rawValue:)) ?? .threeHours
    }

    private var showNamesForMultipleUsers: Bool {
        UserDefaults.standard.object(forKey: .showNamesForMultipleUsersKey) as? Bool ?? true
    }

    private var colorMenuBarReading: Bool {
        UserDefaults.standard.bool(forKey: .colorMenuBarReadingKey)
    }

    private var lowerGlucoseThreshold: Int {
        UserDefaults.standard.object(forKey: .lowerGlucoseThresholdKey) as? Int
            ?? GlucoseRange.defaultLowerBound
    }

    private var upperGlucoseThreshold: Int {
        UserDefaults.standard.object(forKey: .upperGlucoseThresholdKey) as? Int
            ?? GlucoseRange.defaultUpperBound
    }

    private var outOfRangeNotifications: Bool {
        UserDefaults.standard.bool(forKey: .outOfRangeNotificationsKey)
    }

    private func rebuildStatusItems() {
        for item in statusItems {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()

        let visible = visibleProfileModels
        if visible.isEmpty {
            statusItems.append(makeStatusItem(profileID: nil))
        } else {
            for model in visible {
                statusItems.append(makeStatusItem(profileID: model.id))
            }
        }

        updateStatusBarButtons()
    }

    private func makeStatusItem(profileID: GlucoseProfile.ID?) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imagePosition = .imageLeading
        let menu = ProfileMenu(profileID: profileID)
        menu.delegate = self
        item.menu = menu
        return item
    }

    private func updateStatusBarButtons() {
        let visible = visibleProfileModels
        let includeName = visible.count > 1 && showNamesForMultipleUsers

        for item in statusItems {
            guard let button = item.button else { continue }
            let menu = item.menu as? ProfileMenu

            if let id = menu?.profileID, let model = appModel.model(for: id) {
                let title = statusTitle(for: model, includeName: includeName)
                let color = statusColor(for: model, appearance: button.effectiveAppearance)
                button.title = title
                if let color {
                    button.attributedTitle = NSAttributedString(
                        string: title,
                        attributes: [
                            .font: button.font ?? NSFont.menuBarFont(ofSize: 0),
                            .foregroundColor: color,
                        ]
                    )
                }
                button.image = statusImage(for: model, color: color)
                button.toolTip = model.message.map { "\(model.displayName): \($0)" } ?? model.displayName

                GlucoseNotificationManager.shared.evaluate(
                    model: model,
                    enabled: outOfRangeNotifications,
                    lowerBound: lowerGlucoseThreshold,
                    upperBound: upperGlucoseThreshold,
                    useMMOL: UserDefaults.standard.bool(forKey: .useMMOLKey)
                )
            } else {
                button.title = "Luka"
                button.image = nil
                button.toolTip = "Luka Mini"
            }
        }
    }

    private func statusColor(for model: GlucoseProfileModel, appearance: NSAppearance) -> NSColor? {
        guard colorMenuBarReading, case .loaded(let reading) = model.reading else {
            return nil
        }

        return GlucoseRange.nsColor(
            for: reading.value,
            lowerBound: lowerGlucoseThreshold,
            upperBound: upperGlucoseThreshold
        )
        .resolved(for: appearance)
    }

    private func statusTitle(for model: GlucoseProfileModel, includeName: Bool) -> String {
        let useMMOL = UserDefaults.standard.bool(forKey: .useMMOLKey)
        let value: String = switch model.reading {
        case .initial: "--"
        case .loaded(let reading): reading.value.formatted(.glucose(useMMOL ? .mmolL : .mgdl))
        case .noRecentReading, .error: ""
        }

        if includeName {
            return value.isEmpty ? model.displayName : "\(model.displayName) \(value)"
        }
        return value
    }

    private func statusImage(for model: GlucoseProfileModel, color: NSColor?) -> NSImage? {
        if !model.isConfigured {
            return NSImage(systemSymbolName: "person.crop.circle.badge.exclamationmark", accessibilityDescription: "Not Signed In")
        }
        switch model.reading {
        case .initial:
            return nil
        case .loaded(let reading):
            return reading.trend.nsImage(color: color)
        case .noRecentReading, .error:
            return NSImage(systemSymbolName: "icloud.slash", accessibilityDescription: "Error")
        }
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let menu = menu as? ProfileMenu else { return }
        menu.removeAllItems()

        if let id = menu.profileID, let model = appModel.model(for: id) {
            buildProfileMenu(menu, for: model)
        } else {
            buildAppMenu(menu)
        }

        addGlobalMenuItems(to: menu)
    }

    private func buildAppMenu(_ menu: NSMenu) {
        let title = appModel.hasProfiles ? "No users shown in menu bar" : "No users"
        menu.addItem(disabledItem(title: title))
        menu.addItem(.separator())
        menu.addItem(settingsItem())
    }

    private func buildProfileMenu(_ menu: NSMenu, for model: GlucoseProfileModel) {
        if visibleProfileModels.count > 1 {
            menu.addItem(disabledItem(title: model.displayName))
        }

        let graphItem = NSMenuItem()
        let hosting = NSHostingView(rootView: MenuGraphView(model: model, range: graphRange))
        hosting.frame.size = hosting.fittingSize
        graphItem.view = hosting
        menu.addItem(graphItem)
        menu.addItem(.separator())

        if let message = model.message {
            menu.addItem(disabledItem(title: message))
            menu.addItem(.separator())
        }

        if model.isConfigured {
            let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refresh(_:)), keyEquivalent: "")
            refreshItem.target = self
            refreshItem.representedObject = model.id.uuidString
            refreshItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
            menu.addItem(refreshItem)
        }

        let rangeItem = NSMenuItem(title: "Range", action: nil, keyEquivalent: "")
        rangeItem.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        let rangeMenu = NSMenu()
        let selected = graphRange
        for range in GraphRange.allCases {
            let item = NSMenuItem(title: range.abbreviatedName, action: #selector(selectGraphRange(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = range.rawValue
            item.state = range == selected ? .on : .off
            rangeMenu.addItem(item)
        }
        rangeItem.submenu = rangeMenu
        menu.addItem(rangeItem)

        menu.addItem(settingsItem())
    }

    private func addGlobalMenuItems(to menu: NSMenu) {
        menu.addItem(.separator())

        let loginToggle = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginToggle.target = self
        loginToggle.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        loginToggle.state = loginHelper.isEnabled ? .on : .off
        menu.addItem(loginToggle)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "xmark.rectangle", accessibilityDescription: nil)
        menu.addItem(quitItem)
    }

    private func settingsItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        item.target = self
        item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        return item
    }

    private func disabledItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Actions

    @objc private func didWake() {
        appModel.refreshAll()
    }

    @objc private func refresh(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = UUID(uuidString: raw) else { return }
        appModel.model(for: id)?.beginRefreshing()
    }

    @objc private func toggleLaunchAtLogin() {
        loginHelper.isEnabled.toggle()
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(appModel: appModel, loginHelper: loginHelper)
            let controller = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: controller)
            window.title = "Luka Mini"
            window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
            window.titlebarSeparatorStyle = .none
            window.toolbarStyle = .unified
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 600, height: 340)
            settingsWindow = window
        }

        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }

    @objc private func selectGraphRange(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let range = GraphRange(rawValue: raw) else { return }
        UserDefaults.standard.set(range.rawValue, forKey: .graphRangeKey)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private final class ProfileMenu: NSMenu {
    let profileID: GlucoseProfile.ID?

    init(profileID: GlucoseProfile.ID?) {
        self.profileID = profileID
        super.init(title: "")
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct MenuGraphView: View {
    var model: GlucoseProfileModel
    var range: GraphRange

    var body: some View {
        LineChart(
            range: range,
            style: .dots,
            readings: model.readings,
            lineWidth: 1.5,
            showAxisLabels: true,
            useFullYRange: true
        )
        .frame(width: 280, height: 130)
        .padding([.horizontal, .top])
    }
}

extension TrendDirection {
    func nsImage(color: NSColor?) -> NSImage? {
        let image: NSImage? = switch self {
        case .none:
            nil
        case .doubleUp:
            NSImage(named: "arrow.up.double")
        case .singleUp:
            NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)
        case .fortyFiveUp:
            NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil)
        case .flat:
            NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)
        case .fortyFiveDown:
            NSImage(systemSymbolName: "arrow.down.right", accessibilityDescription: nil)
        case .singleDown:
            NSImage(systemSymbolName: "arrow.down", accessibilityDescription: nil)
        case .doubleDown:
            NSImage(named: "arrow.down.double")
        case .notComputable:
            NSImage(systemSymbolName: "questionmark", accessibilityDescription: nil)
        case .rateOutOfRange:
            NSImage(systemSymbolName: "exclamationmark", accessibilityDescription: nil)
        }

        guard let image else { return nil }

        if let color,
           let coloredImage = image.withSymbolConfiguration(
               NSImage.SymbolConfiguration(paletteColors: [color])
            ) {
            coloredImage.isTemplate = false
            return coloredImage
        }

        image.isTemplate = true
        return image
    }
}
