import Foundation

/// Posted when **`NSPersistentCloudKitContainer`** finishes a successful private-database import.
extension Notification.Name {
    nonisolated static let goDiveCloudKitPrivateImportDidSucceed = Notification.Name(
        "GoDive.cloudKitPrivateImportDidSucceed"
    )
}

/// Wakes session sync loops immediately when CloudKit lands rows (instead of fixed polling only).
enum GoDiveCloudKitPrivateImportNotification: Sendable {

  nonisolated static let defaultPollIntervalMilliseconds = 150

    nonisolated static func postImportSucceeded() {
        NotificationCenter.default.post(name: .goDiveCloudKitPrivateImportDidSucceed, object: nil)
    }

    /// Returns as soon as an import notification arrives or **`timeoutMilliseconds`** elapses.
    @MainActor
    static func waitForImportOrTimeout(milliseconds: Int) async {
        guard milliseconds > 0 else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await Task.sleep(for: .milliseconds(milliseconds))
            }
            group.addTask {
                for await _ in NotificationCenter.default.notifications(
                    named: .goDiveCloudKitPrivateImportDidSucceed
                ) {
                    break
                }
            }
            _ = await group.next()
            group.cancelAll()
        }
    }
}
