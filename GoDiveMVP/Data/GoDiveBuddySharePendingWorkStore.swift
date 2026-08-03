import Foundation

/// Disk-backed queue of buddy-share projection upserts that were scheduled but may not have finished
/// (app backgrounded or killed mid-flush).
enum GoDiveBuddySharePendingWorkStore: Sendable {
    nonisolated private static let upsertKeyPrefix = "goDiveBuddySharePendingUpsert.v1."
    nonisolated private static let fullRepublishKeyPrefix = "goDiveBuddySharePendingFullRepublish.v1."

    nonisolated static func addPendingUpserts(ownerProfileID: UUID, activityIDs: Set<UUID>) {
        guard !activityIDs.isEmpty else { return }
        var existing = pendingUpsertActivityIDs(ownerProfileID: ownerProfileID)
        existing.formUnion(activityIDs)
        writeUUIDSet(existing, key: upsertKey(ownerProfileID: ownerProfileID))
    }

    nonisolated static func pendingUpsertActivityIDs(ownerProfileID: UUID) -> Set<UUID> {
        readUUIDSet(key: upsertKey(ownerProfileID: ownerProfileID))
    }

    nonisolated static func clearPendingUpserts(ownerProfileID: UUID, activityIDs: Set<UUID>) {
        guard !activityIDs.isEmpty else { return }
        var existing = pendingUpsertActivityIDs(ownerProfileID: ownerProfileID)
        existing.subtract(activityIDs)
        if existing.isEmpty {
            UserDefaults.standard.removeObject(forKey: upsertKey(ownerProfileID: ownerProfileID))
        } else {
            writeUUIDSet(existing, key: upsertKey(ownerProfileID: ownerProfileID))
        }
    }

    nonisolated static func markFullRepublishPending(ownerProfileID: UUID) {
        UserDefaults.standard.set(true, forKey: fullRepublishKey(ownerProfileID: ownerProfileID))
    }

    nonisolated static func isFullRepublishPending(ownerProfileID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: fullRepublishKey(ownerProfileID: ownerProfileID))
    }

    nonisolated static func clearFullRepublishPending(ownerProfileID: UUID) {
        UserDefaults.standard.removeObject(forKey: fullRepublishKey(ownerProfileID: ownerProfileID))
    }

    nonisolated private static func upsertKey(ownerProfileID: UUID) -> String {
        upsertKeyPrefix + ownerProfileID.uuidString
    }

    nonisolated private static func fullRepublishKey(ownerProfileID: UUID) -> String {
        fullRepublishKeyPrefix + ownerProfileID.uuidString
    }

    nonisolated private static func readUUIDSet(key: String) -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }

    nonisolated private static func writeUUIDSet(_ ids: Set<UUID>, key: String) {
        let strings = ids.map(\.uuidString).sorted()
        guard let data = try? JSONEncoder().encode(strings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
