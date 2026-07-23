import Foundation
import os
import UserNotifications
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Registers FCM; stores tokens at `users/{uid}/private/fcm_{deviceId}` for server push.
enum GoDiveFirebaseCloudMessaging: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "FirebaseCloudMessaging"
    )

    nonisolated static let pushDeviceDocumentIDPrefix = "fcm_"
    nonisolated static let pushDeviceDocumentFieldToken = "fcmToken"
    nonisolated static let pushDeviceDocumentFieldUpdatedAt = "updatedAt"
    nonisolated static let pushDeviceDocumentFieldPlatform = "platform"

    /// Posts when user taps a friend-invite-accepted notification — open Friends list.
    nonisolated static let openFriendsListNotification = Notification.Name(
        "GoDive.openFriendsListFromPush"
    )

    @MainActor
    static func configureAtLaunch(application: UIApplication) {
        #if canImport(FirebaseMessaging)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        UNUserNotificationCenter.current().delegate = GoDivePushNotificationCenterDelegate.shared
        Messaging.messaging().delegate = GoDiveFirebaseMessagingDelegate.shared
        application.registerForRemoteNotifications()
        #endif
    }

    @MainActor
    static func setAPNSToken(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    @MainActor
    static func registerForFriendInvitePushesIfNeeded() async {
        #if canImport(FirebaseMessaging) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard Auth.auth().currentUser != nil else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = await requestAuthorization(center: center)
            guard granted else { return }
        case .authorized, .provisional, .ephemeral:
            break
        case .denied:
            return
        @unknown default:
            return
        }

        UIApplication.shared.registerForRemoteNotifications()
        await uploadCurrentFCMTokenIfAvailable()
        #endif
    }

    @MainActor
    static func uploadCurrentFCMTokenIfAvailable() async {
        #if canImport(FirebaseMessaging) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let token = try? await Messaging.messaging().token(), !token.isEmpty else { return }
        await persistFCMToken(token)
        #endif
    }

    @MainActor
    static func persistFCMToken(_ token: String) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let deviceID = installationDeviceID(), !deviceID.isEmpty else { return }

        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("private")
            .document(pushDeviceDocumentID(installationID: deviceID))

        do {
            try await ref.setData(
                [
                    pushDeviceDocumentFieldToken: trimmed,
                    pushDeviceDocumentFieldUpdatedAt: FieldValue.serverTimestamp(),
                    pushDeviceDocumentFieldPlatform: "ios",
                ],
                merge: true
            )
            log.notice("FCM token stored for push")
        } catch {
            log.error("FCM token store failed: \(String(describing: error), privacy: .private)")
        }
        #endif
    }

    @MainActor
    static func removeStoredTokenOnSignOut() async {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard let deviceID = installationDeviceID() else { return }
        let ref = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("private")
            .document(pushDeviceDocumentID(installationID: deviceID))
        try? await ref.delete()
        #endif
    }

    nonisolated static func pushDeviceDocumentID(installationID: String) -> String {
        let trimmed = installationID.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(pushDeviceDocumentIDPrefix)\(trimmed)"
    }

    nonisolated static func isPushDeviceDocumentID(_ documentID: String) -> Bool {
        documentID.hasPrefix(pushDeviceDocumentIDPrefix)
    }

    @MainActor
    private static func requestAuthorization(center: UNUserNotificationCenter) async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    @MainActor
    private static func installationDeviceID() -> String? {
        #if canImport(UIKit)
        UIDevice.current.identifierForVendor?.uuidString
        #else
        nil
        #endif
    }

    @MainActor
    static func handleNotificationResponse(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String,
              type == GoDiveFriendInvitePushPresentation.notificationType
        else { return }
        NotificationCenter.default.post(name: openFriendsListNotification, object: nil)
    }
}

#if canImport(FirebaseMessaging)
@MainActor
final class GoDiveFirebaseMessagingDelegate: NSObject, MessagingDelegate {
    static let shared = GoDiveFirebaseMessagingDelegate()

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        Task { @MainActor in
            await GoDiveFirebaseCloudMessaging.persistFCMToken(fcmToken)
        }
    }
}
#endif

#if canImport(UIKit)
@MainActor
final class GoDivePushNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = GoDivePushNotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        GoDiveFirebaseCloudMessaging.handleNotificationResponse(
            userInfo: response.notification.request.content.userInfo
        )
    }
}
#endif
