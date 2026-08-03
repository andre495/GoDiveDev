import CryptoKit
import Foundation

struct GoDiveSharedMediaPublishedMediaRecord: Codable, Equatable, Sendable {
    var mediaID: String
    var kind: String
    var sourceFingerprint: String
    var exportFingerprint: String?
    var thumbnailURL: String
    var contentURL: String?
    var width: Int?
    var height: Int?
    var durationSeconds: Double?
    var contentBytes: Int?

    nonisolated func snapshot() -> GoDiveSharedDiveProjectionMapping.MediaItemSnapshot {
        GoDiveSharedDiveProjectionMapping.MediaItemSnapshot(
            mediaID: mediaID,
            kind: FriendSharedMediaKind(rawValue: kind) ?? .photo,
            thumbnailURL: thumbnailURL,
            contentURL: contentURL,
            width: width,
            height: height,
            durationSeconds: durationSeconds,
            contentBytes: contentBytes
        )
    }
}

struct GoDiveSharedMediaActivityRecord: Equatable, Sendable {
    var items: [GoDiveSharedMediaPublishedMediaRecord]
}

nonisolated private struct GoDiveSharedMediaActivityRecordPayload: Codable, Sendable {
    var items: [GoDiveSharedMediaPublishedMediaRecord]
}

/// Device-local publish cache for friend-shared media (fingerprints + Storage URLs).
enum GoDiveSharedMediaPublishState: Sendable {
    typealias PublishedMediaRecord = GoDiveSharedMediaPublishedMediaRecord
    typealias ActivityRecord = GoDiveSharedMediaActivityRecord

    nonisolated private static let storageKeyPrefix = "goDiveSharedMediaPublish.v1."

    nonisolated static func sourceFingerprint(
        mediaKind: String,
        photosLocalIdentifier: String,
        capturedAt: Date?,
        sortOrder: Int
    ) -> String {
        let localID = photosLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let captured = capturedAt?.timeIntervalSince1970 ?? -1
        let kind = DiveMediaKind(rawValue: mediaKind) ?? .image
        return "\(kind.rawValue)|\(localID)|\(captured)|\(sortOrder)"
    }

    /// Content-tier fingerprint (hash of the exported JPEG / MP4 bytes).
    nonisolated static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    @MainActor
    static func loadActivity(ownerUID: String, activityID: UUID) -> ActivityRecord {
        loadActivityRecord(ownerUID: ownerUID, activityID: activityID)
    }

    nonisolated static func loadActivityRecord(ownerUID: String, activityID: UUID) -> ActivityRecord {
        guard let data = UserDefaults.standard.data(forKey: storageKey(ownerUID: ownerUID, activityID: activityID)),
              let decoded = try? JSONDecoder().decode(GoDiveSharedMediaActivityRecordPayload.self, from: data)
        else { return ActivityRecord(items: []) }
        return ActivityRecord(items: decoded.items)
    }

    @MainActor
    static func saveActivity(
        ownerUID: String,
        activityID: UUID,
        record: ActivityRecord
    ) {
        saveActivityRecord(ownerUID: ownerUID, activityID: activityID, record: record)
    }

    nonisolated static func saveActivityRecord(
        ownerUID: String,
        activityID: UUID,
        record: ActivityRecord
    ) {
        let payload = GoDiveSharedMediaActivityRecordPayload(items: record.items)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey(ownerUID: ownerUID, activityID: activityID))
    }

    nonisolated static func clearActivity(ownerUID: String, activityID: UUID) {
        UserDefaults.standard.removeObject(forKey: storageKey(ownerUID: ownerUID, activityID: activityID))
    }

    nonisolated static func clearOwner(ownerUID: String) {
        let prefix = storageKeyPrefix + ownerUID + "."
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    nonisolated static func record(
        for mediaID: UUID,
        in activity: ActivityRecord
    ) -> PublishedMediaRecord? {
        let id = mediaID.uuidString
        return activity.items.first { $0.mediaID == id }
    }

    nonisolated static func removedMediaIDs(
        previous: ActivityRecord,
        currentMediaIDs: Set<String>
    ) -> [String] {
        previous.items
            .map(\.mediaID)
            .filter { !currentMediaIDs.contains($0) }
    }

    /// Activity IDs with a publish-state blob for this Firebase owner UID.
    nonisolated static func allActivityIDs(ownerUID: String) -> [UUID] {
        let prefix = storageKeyPrefix + ownerUID + "."
        return UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .compactMap { key in
                let suffix = key.dropFirst(prefix.count)
                return UUID(uuidString: String(suffix))
            }
    }

    nonisolated static func hasIncompleteContentItems(in record: ActivityRecord) -> Bool {
        record.items.contains { item in
            !item.thumbnailURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (item.contentURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Parses the Photos local identifier embedded in **`sourceFingerprint`**.
    nonisolated static func photosLocalIdentifier(fromSourceFingerprint fingerprint: String) -> String? {
        let parts = fingerprint.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let localID = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return localID.isEmpty ? nil : localID
    }

    nonisolated private static func storageKey(ownerUID: String, activityID: UUID) -> String {
        storageKeyPrefix + ownerUID + "." + activityID.uuidString
    }
}
