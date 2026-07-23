import Foundation
import SwiftData

/// Keeps the app process warm briefly while private CloudKit import is still catching up.
@MainActor
enum GoDiveCloudKitForegroundImportWindow {
    private static var activeTask: Task<Void, Never>?

    /// Runs only when private sync is on and the signed-in profile still has zero owned activities.
    static func runIfNeeded(
        container: ModelContainer,
        ownerProfileID: UUID?,
        appleUserIdentifier: String?,
        seconds: TimeInterval = 8
    ) {
        guard seconds > 0 else { return }
        guard GoDiveCloudKitDiveLogLocalStatus.readPrivateSyncState() == .enabled else { return }
        guard let ownerProfileID, let appleUserIdentifier else { return }

        let context = container.mainContext
        let owned = ownedActivityCount(
            ownerProfileID: ownerProfileID,
            appleUserIdentifier: appleUserIdentifier,
            modelContext: context
        )
        guard owned == 0 else { return }

        activeTask?.cancel()
        activeTask = Task { @MainActor in
            let deadline = ContinuousClock.now + .seconds(Int(seconds.rounded()))
            while ContinuousClock.now < deadline {
                guard !Task.isCancelled else { return }
                GoDiveCloudKitDiveLogSyncKickstart.kick(container: container)
                context.processPendingChanges()
                _ = try? AccountSession.shared.reconcileCloudKitIdentityIfNeeded(modelContext: context)
                let total = AccountSessionProfileResolution.totalOwnedActivityCount(
                    appleUserIdentifier: appleUserIdentifier,
                    modelContext: context
                )
                if total > 0 {
                    await AccountSession.shared.syncCloudKitDiveLogIntoSession(
                        preferredProfileID: ownerProfileID,
                        appleUserIdentifier: appleUserIdentifier,
                        modelContext: context,
                        waitForActivitiesSeconds: 1
                    )
                    return
                }
                await GoDiveCloudKitPrivateImportNotification.waitForImportOrTimeout(
                    milliseconds: GoDiveCloudKitPrivateImportNotification.defaultPollIntervalMilliseconds
                )
            }
        }
    }

    @MainActor
    private static func ownedActivityCount(
        ownerProfileID: UUID,
        appleUserIdentifier: String,
        modelContext: ModelContext
    ) -> Int {
        let sessionID = ownerProfileID
        let sessionOwned = (try? modelContext.fetchCount(
            FetchDescriptor<DiveActivity>(predicate: #Predicate { $0.ownerProfileID == sessionID })
        )) ?? 0
        let sessionSnorkels = (try? modelContext.fetchCount(
            FetchDescriptor<SnorkelActivity>(predicate: #Predicate { $0.ownerProfileID == sessionID })
        )) ?? 0
        if sessionOwned + sessionSnorkels > 0 { return sessionOwned + sessionSnorkels }
        return AccountSessionProfileResolution.totalOwnedActivityCount(
            appleUserIdentifier: appleUserIdentifier,
            modelContext: modelContext
        )
    }
}
