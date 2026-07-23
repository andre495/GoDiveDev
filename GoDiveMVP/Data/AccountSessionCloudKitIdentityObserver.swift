import CoreData
import Foundation
import SwiftData
import os

/// Watches CloudKit import events and merges duplicate Apple-ID profiles into the signed-in session.
///
/// Sign-in can mint a local **Diver** profile before CloudKit downloads the existing account. Import
/// notifications are easy to miss or fire before the second profile is visible on the main context,
/// so this observer debounces and retries reconciliation.
enum AccountSessionCloudKitIdentityObserver {
    @MainActor
    private static var isStarted = false
    @MainActor
    private static var pendingReconcileTask: Task<Void, Never>?
    @MainActor
    private static weak var observedContainer: ModelContainer?

    private nonisolated static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "CloudKitIdentity"
    )

    @MainActor
    static func setActiveContainer(_ container: ModelContainer) {
        observedContainer = container
    }

    @MainActor
    static func startIfNeeded(container: ModelContainer) {
        observedContainer = container
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
                guard let container = observedContainer else { return }
                GoDiveCloudKitPrivateImportNotification.postImportSucceeded()
                scheduleReconcileAfterCloudKitImport(container: container)
            }
        }
    }

    /// Call after Sign in with Apple when the local store may still be empty — CloudKit often lands
    /// the real profile a few seconds later.
    @MainActor
    static func schedulePostSignInReconcileRetries(container: ModelContainer) {
        observedContainer = container
        pendingReconcileTask?.cancel()
        pendingReconcileTask = Task { @MainActor in
            await reconcileNow(container: container, reason: "postSignInRetry-immediate")
            for delayMs in [400, 1_500, 4_000, 10_000] {
                try? await Task.sleep(for: .milliseconds(delayMs))
                guard !Task.isCancelled else { return }
                await reconcileNow(container: container, reason: "postSignInRetry-\(delayMs)ms")
            }
        }
    }

    @MainActor
    static func reconcileOnForegroundIfNeeded(container: ModelContainer) {
        Task { @MainActor in
            await reconcileNow(container: container, reason: "sceneActive")
        }
    }

    @MainActor
    private static func scheduleReconcileAfterCloudKitImport(container: ModelContainer) {
        pendingReconcileTask?.cancel()
        pendingReconcileTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            await reconcileNow(container: container, reason: "cloudKitImport")
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await reconcileNow(container: container, reason: "cloudKitImport-followUp")
        }
    }

    @MainActor
    private static func reconcileNow(container: ModelContainer, reason: String) async {
        let context = container.mainContext
        context.processPendingChanges()
        do {
            let outcome = try AccountSession.shared.reconcileCloudKitIdentityIfNeeded(modelContext: context)
            if let outcome, outcome.mergedDuplicateCount > 0 || outcome.didChangeCanonicalID {
                log.notice(
                    "identity_merge reason=\(reason, privacy: .public) merged=\(outcome.mergedDuplicateCount) switched=\(outcome.didChangeCanonicalID) reassigned=\(outcome.reassignedOwnedRowCount)"
                )
            }
            if let profile = AccountSession.shared.currentProfile {
                let appleID = profile.appleUserIdentifier
                let total = AccountSessionProfileResolution.totalOwnedActivityCount(
                    appleUserIdentifier: appleID,
                    modelContext: context
                )
                if total > 0 {
                    _ = try? await AccountSession.shared.attachSessionProfile(
                        preferredProfileID: profile.id,
                        appleUserIdentifier: appleID,
                        fallbackContext: context,
                        waitForCloudKitImport: false
                    )
                }
            }
            if let owner = AccountSession.shared.currentProfile {
                try? UserPreferencesSync.syncForSignedInOwner(owner, modelContext: context)
            }
            #if canImport(Photos)
            _ = DiveMediaReferencePruning.pruneMissingLibraryAssets(modelContext: context)
            #endif
        } catch {
            log.error(
                "identity_merge_failed reason=\(reason, privacy: .public) error=\(String(describing: error), privacy: .private)"
            )
        }
    }
}
