import Foundation
import SwiftData

/// Configures persistence + opt-in CloudKit share for **`GoDiveSecurityEvent`**.
enum GoDiveSecurityEventJournal: Sendable {

    /// Set once when the production **`ModelContainer`** attaches.
    nonisolated(unsafe) static var container: ModelContainer?

    @MainActor
    static func configure(container: ModelContainer) {
        self.container = container
        Task.detached(priority: .utility) {
            await uploadPendingIfSharingEnabled(container: container)
        }
    }

    @MainActor
    static func uploadBacklogNow(container: ModelContainer) {
        Task.detached(priority: .utility) {
            await uploadPendingIfSharingEnabled(container: container)
        }
    }

    nonisolated static func uploadPendingIfSharingEnabled(container: ModelContainer) async {
        guard AppUserSettings.shareSecurityEvents() else { return }
        let store = SecurityEventStore(container: container)
        let ownerID = AppLaunchSessionRestorePresentation.loadPersistedProfileID()
        await SecurityEventCloudUploader.uploadPendingEvents(store: store, ownerProfileID: ownerID)
    }

    nonisolated static func persistIfPossible(
        kind: GoDiveSecurityEvent.Kind,
        detail: String?,
        ownerProfileID: UUID?
    ) {
        guard let container else { return }
        // Prefer explicit owner; fall back to Keychain session id.
        let owner = ownerProfileID ?? AppLaunchSessionRestorePresentation.loadPersistedProfileID()
        guard let owner else { return }

        let event = SecurityEvent(
            kindRaw: kind.rawValue,
            detail: detail,
            appVersion: currentAppVersion,
            osVersion: currentOSVersion,
            ownerProfileID: owner
        )
        let store = SecurityEventStore(container: container)
        try? store.save(event)

        if AppUserSettings.shareSecurityEvents() {
            Task.detached(priority: .utility) {
                await SecurityEventCloudUploader.uploadPendingEvents(
                    store: store,
                    ownerProfileID: owner
                )
            }
        }
    }

    nonisolated private static var currentAppVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    nonisolated private static var currentOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "iOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
