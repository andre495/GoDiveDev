import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Shared local-notification permission helper (equipment service + trip reminders).
enum GoDiveLocalNotificationAuthorization: Sendable {

    /// Requests alert/sound/badge permission when undetermined. Does not require Firebase.
    @MainActor
    static func ensureAuthorized() async -> Bool {
        #if canImport(UIKit)
        let center = UNUserNotificationCenter.current()
        if center.delegate == nil {
            center.delegate = GoDivePushNotificationCenterDelegate.shared
        }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        @unknown default:
            return false
        }
        #else
        return false
        #endif
    }
}
