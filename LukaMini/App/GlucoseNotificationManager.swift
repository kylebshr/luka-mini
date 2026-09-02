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

    private struct Observation {
        var readingDate: Date
        var classification: GlucoseRange.Classification
    }

    private var observations: [GlucoseProfile.ID: Observation] = [:]

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
        includeName: Bool,
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
        let previous = observations[model.id]
        observations[model.id] = Observation(readingDate: reading.date, classification: classification)

        // Re-evaluating the same reading (e.g. while editing thresholds) never
        // alerts; only a new reading can trigger a notification.
        if let previous, previous.readingDate == reading.date { return }

        // Track state even when disabled so that turning the setting on
        // doesn't immediately fire for a reading the user has already seen.
        guard enabled, classification != .inRange, previous?.classification != classification else {
            if classification == .inRange {
                UNUserNotificationCenter.current()
                    .removeDeliveredNotifications(withIdentifiers: [notificationID(for: model.id)])
            }
            return
        }

        let unit: GlucoseFormatter.Unit = useMMOL ? .mmolL : .mgdl
        let unitName = useMMOL ? "mmol/L" : "mg/dL"
        let value = reading.value.formatted(.glucose(unit, usesOutOfRangeText: false))
        let lower = lowerBound.formatted(.glucose(unit))
        let upper = upperBound.formatted(.glucose(unit))

        let content = UNMutableNotificationContent()
        let title = classification == .low ? "Low Glucose" : "High Glucose"
        content.title = includeName ? "\(model.displayName): \(title)" : title
        content.body = "\(value) \(unitName) is outside the target range of \(lower)–\(upper) \(unitName)"
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
