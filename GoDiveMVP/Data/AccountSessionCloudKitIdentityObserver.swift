import CoreData
import Foundation
import SwiftData

/// Watches CloudKit import events and merges duplicate Apple-ID profiles into the signed-in session.
enum AccountSessionCloudKitIdentityObserver {
    @MainActor
    private static var isStarted = false

    @MainActor
    static func startIfNeeded(container: ModelContainer) {
        guard !isStarted else { return }
        isStarted = true

        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard
                let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                event.type == .import,
                event.endDate != nil,
                event.succeeded
            else {
                return
            }
            Task { @MainActor in
                _ = try? AccountSession.shared.reconcileCloudKitIdentityIfNeeded(
                    modelContext: container.mainContext
                )
                if let owner = AccountSession.shared.currentProfile {
                    try? UserPreferencesSync.syncForSignedInOwner(
                        owner,
                        modelContext: container.mainContext
                    )
                }
            }
        }
    }
}
