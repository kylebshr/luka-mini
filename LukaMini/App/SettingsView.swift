//
//  SettingsView.swift
//  LukaMini
//
//  Created by Kyle Bashour on 4/11/24.
//

import AppKit
import Dexcom
import SwiftUI

struct SettingsView: View {
    var appModel: AppModel
    @Bindable var loginHelper: LoginItemHelper

    @AppStorage(.useMMOLKey) private var useMMOL = false
    @AppStorage(.graphRangeKey) private var graphRange: GraphRange = .threeHours
    @AppStorage(.showNamesForMultipleUsersKey) private var showNamesForMultipleUsers = true
    @AppStorage(.colorMenuBarReadingKey) private var colorMenuBarReading = false
    @AppStorage(.lowerGlucoseThresholdKey) private var lowerGlucoseThreshold = GlucoseRange.defaultLowerBound
    @AppStorage(.upperGlucoseThresholdKey) private var upperGlucoseThreshold = GlucoseRange.defaultUpperBound
    @AppStorage(.outOfRangeNotificationsKey) private var outOfRangeNotifications = false
    @AppStorage(.useServerForReadingsKey) private var useServerForReadings = true

    @State private var selection: SettingsSelection = .general
    @State private var editor = ProfileEditorState()
    @State private var original = ProfileEditorState()
    @State private var isShowingDeleteAlert = false
    @State private var isShowingNotificationPermissionAlert = false

    var body: some View {
        Group {
            if appModel.profileModels.isEmpty {
                OnboardingView(appModel: appModel)
                    .frame(minWidth: 460, idealWidth: 520, minHeight: 460, idealHeight: 500)
            } else {
                mainContent
                    .frame(minWidth: 650, idealWidth: 650, minHeight: 450, idealHeight: 450)
            }
        }
    }

    private var mainContent: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.leading")
                }
                .help("Toggle Sidebar")
            }
        }
        .onAppear { selectInitial() }
        .onChange(of: selection) { _, new in loadEditor(for: new) }
        .onChange(of: appModel.profileModels.map(\.id)) { _, ids in reconcileSelection(with: ids) }
        .alert("Delete User?", isPresented: $isShowingDeleteAlert) {
            Button("Delete", role: .destructive, action: deleteSelectedProfile)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(deleteAlertProfileName) from Luka Mini and deletes the saved Dexcom credentials for this user.")
        }
        .alert("Notifications Are Disabled", isPresented: $isShowingNotificationPermissionAlert) {
            Button("Open Notification Settings", action: openNotificationSettings)
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow notifications for Luka Mini in System Settings, then try again.")
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Text("General").tag(SettingsSelection.general)

                Section("Users") {
                    if appModel.profileModels.isEmpty && selection != .newProfile {
                        Text("No Users").foregroundStyle(.secondary)
                    }

                    ForEach(appModel.profileModels) { model in
                        ProfileListRow(model: model)
                            .tag(SettingsSelection.profile(model.id))
                    }

                    if selection == .newProfile {
                        Text("New User")
                            .fontWeight(.medium)
                            .padding(.vertical, 4)
                            .tag(SettingsSelection.newProfile)
                    }
                }
            }
            .listStyle(.sidebar)

            HStack(spacing: 0) {
                SidebarAddRemoveControl(canRemove: selection.isProfile) {
                    selection = .newProfile
                } remove: {
                    if selection == .newProfile {
                        selection = appModel.profileModels.first.map { .profile($0.id) } ?? .general
                    } else {
                        isShowingDeleteAlert = true
                    }
                }
                .frame(width: 68, height: 24, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(8)
            .background(.bar)
        }
        .background(.bar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .general:
            generalDetail
        case .newProfile, .profile:
            profileDetail.id(selection)
        }
    }

    private var generalDetail: some View {
        Form {
            Section("Menu Bar") {
                Picker("Graph range", selection: $graphRange) {
                    ForEach(GraphRange.allCases) { Text($0.abbreviatedName).tag($0) }
                }

                Picker("Units", selection: $useMMOL) {
                    Text("mg/dL").tag(false)
                    Text("mmol/L").tag(true)
                }
                .pickerStyle(.segmented)

                if appModel.profileModels.count > 1 {
                    Toggle("Show names", isOn: $showNamesForMultipleUsers)
                }

                Toggle("Color glucose reading", isOn: $colorMenuBarReading)

                LabeledContent("Target range") {
                    HStack(spacing: 6) {
                        TextField(
                            "",
                            value: displayedLowerGlucoseThreshold,
                            format: thresholdFormat
                        )
                        .accessibilityLabel("Low glucose threshold")
                        .frame(width: 48)
                        .multilineTextAlignment(.trailing)

                        Text("to")
                            .foregroundStyle(.secondary)

                        TextField(
                            "",
                            value: displayedUpperGlucoseThreshold,
                            format: thresholdFormat
                        )
                        .accessibilityLabel("High glucose threshold")
                        .frame(width: 48)
                        .multilineTextAlignment(.trailing)

                        Text(useMMOL ? "mmol/L" : "mg/dL")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("App") {
                Toggle("Launch at login", isOn: $loginHelper.isEnabled)
            }

            Section {
                Toggle("Fetch from Luka servers", isOn: $useServerForReadings)
            } footer: {
                Text("Fetch readings from the Luka server, which caches them while the Luka iOS app runs a Live Activity. This reduces direct requests to Dexcom. Falls back to Dexcom automatically when no cached readings are available.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            Section("Notifications") {
                Toggle(
                    "Notify outside target range",
                    isOn: outOfRangeNotificationsBinding
                )
            }
        }
        .formStyle(.grouped)
        .onChange(of: lowerGlucoseThreshold) { _, newValue in
            lowerGlucoseThreshold = max(1, min(newValue, upperGlucoseThreshold - 1))
        }
        .onChange(of: upperGlucoseThreshold) { _, newValue in
            upperGlucoseThreshold = max(lowerGlucoseThreshold + 1, min(newValue, 1_000))
        }
    }

    private var profileDetail: some View {
        Form {
            Section("User") {
                TextField("Name", text: $editor.displayName, prompt: Text(editor.namePlaceholder))
                    .textFieldStyle(.roundedBorder)

                Toggle("Show in menu bar", isOn: showsInMenuBarBinding)
            }

            Section("Dexcom") {
                Picker("Account location", selection: $editor.accountLocation) {
                    ForEach(AccountLocation.allCases) { Text($0.displayName).tag($0) }
                }

                TextField("Username", text: $editor.username)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $editor.password)
                    .textFieldStyle(.roundedBorder)

                if editor.id == nil {
                    Text("Enter the Dexcom username and password of the person whose readings you want to see — not a follower’s. Their account must have Dexcom Share turned on with at least one follower. If the username is a phone number, include a country code (e.g. +12223334444).")
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button(selection == .newProfile ? "Add User" : "Save Changes") {
                    saveProfile()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding()
        }
        .background(.bar)
    }

    // MARK: - Derived

    private var canSave: Bool {
        editor.canSave && editor != original
    }

    private var displayedLowerGlucoseThreshold: Binding<Double> {
        glucoseThresholdBinding(for: $lowerGlucoseThreshold)
    }

    private var outOfRangeNotificationsBinding: Binding<Bool> {
        Binding {
            outOfRangeNotifications
        } set: { isEnabled in
            if isEnabled {
                Task {
                    let authorized = await GlucoseNotificationManager.shared.requestAuthorization()
                    if authorized {
                        outOfRangeNotifications = true
                    } else {
                        isShowingNotificationPermissionAlert = true
                    }
                }
            } else {
                outOfRangeNotifications = false
            }
        }
    }

    private var displayedUpperGlucoseThreshold: Binding<Double> {
        glucoseThresholdBinding(for: $upperGlucoseThreshold)
    }

    private var thresholdFormat: FloatingPointFormatStyle<Double> {
        .number
            .grouping(.never)
            .precision(.fractionLength(useMMOL ? 1 : 0))
    }

    private func glucoseThresholdBinding(for threshold: Binding<Int>) -> Binding<Double> {
        Binding {
            let value = Double(threshold.wrappedValue)
            return useMMOL ? value * .mmolConversionFactor : value
        } set: { value in
            let mgdl = useMMOL ? value / .mmolConversionFactor : value
            threshold.wrappedValue = Int(mgdl.rounded())
        }
    }

    private var deleteAlertProfileName: String {
        editor.resolvedDisplayName.isEmpty ? "this user" : editor.resolvedDisplayName
    }

    /// Toggling menu-bar visibility on an existing profile auto-saves so the
    /// menu bar updates immediately without requiring the user to hit Save.
    private var showsInMenuBarBinding: Binding<Bool> {
        Binding {
            editor.showsInMenuBar
        } set: { value in
            editor.showsInMenuBar = value
            original.showsInMenuBar = value
            if let id = editor.id {
                appModel.setShowsInMenuBar(id: id, showsInMenuBar: value)
            }
        }
    }

    // MARK: - Actions

    private func selectInitial() {
        selection = appModel.profileModels.isEmpty ? .newProfile : .general
        loadEditor(for: selection)
    }

    private func loadEditor(for selection: SettingsSelection) {
        switch selection {
        case .general:
            break
        case .newProfile:
            editor = ProfileEditorState()
            original = editor
        case .profile(let id):
            if let model = appModel.model(for: id) {
                editor = ProfileEditorState(profile: model.profile, credentials: appModel.credentials(for: id))
                original = editor
            }
        }
    }

    private func reconcileSelection(with profileIDs: [GlucoseProfile.ID]) {
        guard case .profile(let id) = selection else { return }
        if profileIDs.contains(id) {
            loadEditor(for: selection)
        } else if let firstID = profileIDs.first {
            selection = .profile(firstID)
        } else {
            selection = .general
        }
    }

    private func saveProfile() {
        if let id = editor.id {
            appModel.updateProfile(
                id: id,
                displayName: editor.displayName,
                username: editor.username,
                password: editor.password,
                accountLocation: editor.accountLocation,
                showsInMenuBar: editor.showsInMenuBar
            )
            loadEditor(for: selection)
        } else {
            let id = appModel.addProfile(
                displayName: editor.displayName,
                username: editor.username,
                password: editor.password,
                accountLocation: editor.accountLocation,
                showsInMenuBar: editor.showsInMenuBar
            )
            selection = .profile(id)
        }
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(
            #selector(NSSplitViewController.toggleSidebar(_:)),
            with: nil
        )
    }

    private func openNotificationSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let destination = "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)"
        if let url = URL(string: destination) {
            NSWorkspace.shared.open(url)
        }
    }

    private func deleteSelectedProfile() {
        guard case .profile(let id) = selection else { return }
        appModel.removeProfile(id: id)
        selection = appModel.profileModels.first.map { .profile($0.id) } ?? .general
    }
}

// MARK: - Onboarding

private struct OnboardingView: View {
    var appModel: AppModel

    @State private var accountLocation: AccountLocation = .usa
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    private var canSignIn: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
            && !isSigningIn
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 72, height: 72)
                    }
                    Text("Welcome to Luka Mini")
                        .font(.title2.weight(.semibold))
                    Text("Sign in with Dexcom to show glucose readings in your menu bar.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .username)
                        .onSubmit { focusedField = .password }

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .password)
                        .onSubmit { Task { await signIn() } }

                    Picker("Region", selection: $accountLocation) {
                        ForEach(AccountLocation.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                }

                Text("Enter the Dexcom username and password of the person whose readings you want to see — not a follower’s. Their account must have Dexcom Share turned on with at least one follower. If the username is a phone number, include a country code (e.g. +12223334444).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(32)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .onAppear { focusedField = .username }
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    Task { await signIn() }
                } label: {
                    if isSigningIn {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 80)
                    } else {
                        Text("Sign In").frame(minWidth: 80)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSignIn)
            }
            .padding()
        }
        .background(.bar)
    }

    @MainActor
    private func signIn() async {
        guard canSignIn else { return }
        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let client = DexcomClient(
            username: trimmedUsername,
            password: password,
            accountLocation: accountLocation
        )

        do {
            _ = try await client.getGlucoseReadings(duration: .init(value: 24, unit: .hours))
        } catch let error as DexcomError {
            switch error.code {
            case .accountPasswordInvalid, .authenticateMaxAttemptsExceeed:
                errorMessage = "Incorrect username or password."
            case .invalidArgument:
                errorMessage = "That username doesn’t look right. If it’s a phone number, format it like +12223334444."
            case .sessionIdNotFound, .sessionNotValid, .none:
                errorMessage = error.message ?? "Dexcom rejected the sign-in. Double-check your credentials and region."
            }
            return
        } catch {
            errorMessage = "Couldn’t reach Dexcom. Check your internet connection and try again."
            return
        }

        appModel.addProfile(
            displayName: "",
            username: trimmedUsername,
            password: password,
            accountLocation: accountLocation,
            showsInMenuBar: true
        )
    }
}

// MARK: - Selection

private enum SettingsSelection: Hashable {
    case general
    case newProfile
    case profile(GlucoseProfile.ID)

    var isProfile: Bool {
        switch self {
        case .profile, .newProfile: true
        case .general: false
        }
    }
}

// MARK: - Editor State

private struct ProfileEditorState: Equatable {
    var id: GlucoseProfile.ID?
    var displayName: String = ""
    var username: String = ""
    var password: String = ""
    var accountLocation: AccountLocation = .usa
    var showsInMenuBar: Bool = true

    var canSave: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var resolvedDisplayName: String {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { return trimmedName }
        return username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var namePlaceholder: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Optional" : trimmed
    }

    init() {}

    init(profile: GlucoseProfile, credentials: ProfileCredentials?) {
        self.id = profile.id
        self.displayName = profile.displayName
        self.username = credentials?.username ?? ""
        self.password = credentials?.password ?? ""
        self.accountLocation = profile.accountLocation
        self.showsInMenuBar = profile.showsInMenuBar
    }
}

// MARK: - Rows

private struct ProfileListRow: View {
    var model: GlucoseProfileModel

    var body: some View {
        Text(model.displayName)
            .fontWeight(.medium)
            .lineLimit(1)
            .padding(.vertical, 4)
    }
}

// MARK: - Sidebar segmented control

private struct SidebarAddRemoveControl: NSViewRepresentable {
    var canRemove: Bool
    var add: () -> Void
    var remove: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(add: add, remove: remove)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl()
        control.segmentCount = 2
        control.trackingMode = .momentary
        control.segmentStyle = .smallSquare
        control.controlSize = .small
        control.target = context.coordinator
        control.action = #selector(Coordinator.performAction(_:))

        control.setImage(NSImage(systemSymbolName: "plus", accessibilityDescription: "Add User"), forSegment: 0)
        control.setImage(NSImage(systemSymbolName: "minus", accessibilityDescription: "Delete User"), forSegment: 1)
        control.setToolTip("Add User", forSegment: 0)
        control.setToolTip("Delete User", forSegment: 1)
        control.setWidth(32, forSegment: 0)
        control.setWidth(32, forSegment: 1)

        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.add = add
        context.coordinator.remove = remove
        control.setEnabled(canRemove, forSegment: 1)
    }

    final class Coordinator: NSObject {
        var add: () -> Void
        var remove: () -> Void

        init(add: @escaping () -> Void, remove: @escaping () -> Void) {
            self.add = add
            self.remove = remove
        }

        @objc func performAction(_ sender: NSSegmentedControl) {
            switch sender.selectedSegment {
            case 0: add()
            case 1: remove()
            default: break
            }
            sender.selectedSegment = -1
        }
    }
}

extension AccountLocation: @retroactive Identifiable, @retroactive CaseIterable {
    public static var allCases: [AccountLocation] { [.usa, .worldwide, .apac] }
    public var id: Self { self }

    var displayName: String {
        switch self {
        case .usa: "United States"
        case .apac: "Japan"
        case .worldwide: "Anywhere Else"
        }
    }
}
