//
//  GlucoseNotificationManager.swift
//  LukaMini
//

import Dexcom
import Foundation
import UserNotifications

/// Posts a local notification when a profile's reading crosses out of the
/// configured target range. Notifies on transitions only (in range → low/high,
/// or low ↔ high), so re-evaluating the same reading never re-alerts.
@MainActor
final class GlucoseNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = GlucoseNotificationManager()

    private var lastClassification: [GlucoseProfile.ID: GlucoseRange.Classification] = [:]

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        case .notDetermined, .ephemeral:
            break
        @unknown default:
            break
        }

        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func evaluate(
        model: GlucoseProfileModel,
        enabled: Bool,
        lowerBound: Int,
        upperBound: Int,
        useMMOL: Bool
    ) {
        guard case .loaded(let reading) = model.reading else { return }

        let classification = GlucoseRange.classification(
            for: reading.value,
            lowerBound: lowerBound,
            upperBound: upperBound
        )
        let previous = lastClassification[model.id]
        lastClassification[model.id] = classification

        // Track state even when disabled so that turning the setting on
        // doesn't immediately fire for a reading the user has already seen.
        guard enabled, classification != .inRange, previous != classification else {
            if classification == .inRange {
                UNUserNotificationCenter.current()
                    .removeDeliveredNotifications(withIdentifiers: [notificationID(for: model.id)])
            }
            return
        }

        let value = reading.value.formatted(.glucose(useMMOL ? .mmolL : .mgdl))
        let unit = useMMOL ? "mmol/L" : "mg/dL"

        let content = UNMutableNotificationContent()
        content.title = classification == .low ? "Low Glucose" : "High Glucose"
        content.body = "\(model.displayName) is \(value) \(unit)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // Reusing the identifier replaces any earlier alert for this profile.
        let request = UNNotificationRequest(
            identifier: notificationID(for: model.id),
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func notificationID(for profileID: GlucoseProfile.ID) -> String {
        "glucose-out-of-range-\(profileID)"
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Menu bar apps are frequently the "foreground" app; still show banners.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
