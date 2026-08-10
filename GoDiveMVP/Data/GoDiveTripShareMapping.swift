import FirebaseFirestore
import Foundation

/// Firestore mapping for trip-share invites + owner-synced shared trip details.
enum GoDiveTripShareMapping: Sendable {
    nonisolated static let sharedTripsSubcollection = "sharedTrips"
    nonisolated static let tripShareInvitesSubcollection = "tripShareInvites"
    nonisolated static let schemaVersion = 1

    enum InviteStatus: String, Sendable, Equatable {
        case pending
        case accepted
        case declined
        case revoked
    }

    /// Canonical shared-trip payload under `users/{sharerUid}/sharedTrips/{tripId}`.
    struct SharedTripSnapshot: Equatable, Sendable {
        var tripID: String
        var title: String?
        var startDate: Date
        var endDate: Date
        var countries: [String]
        var plannedSiteIDs: [String]
        var updatedAt: Date
        var createdAt: Date
        var schemaVersion: Int
    }

    /// Incoming invite under `users/{recipientUid}/tripShareInvites/{inviteId}`.
    struct InviteSnapshot: Equatable, Sendable {
        var inviteID: String
        var sharerUID: String
        var tripID: String
        var status: InviteStatus
        var title: String?
        var sharerDisplayName: String?
        var createdAt: Date
        var updatedAt: Date?
        var schemaVersion: Int
    }

    nonisolated static func inviteDocumentID(sharerUID: String, tripID: String) -> String {
        let sharer = sharerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trip = tripID.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(sharer)_\(trip)"
    }

    nonisolated static func firestoreData(for snapshot: SharedTripSnapshot) -> [String: Any] {
        var data: [String: Any] = [
            "schemaVersion": schemaVersion,
            "startDate": Timestamp(date: snapshot.startDate),
            "endDate": Timestamp(date: snapshot.endDate),
            "countries": snapshot.countries,
            "plannedSiteIDs": snapshot.plannedSiteIDs,
            "updatedAt": Timestamp(date: snapshot.updatedAt),
            "createdAt": Timestamp(date: snapshot.createdAt),
        ]
        if let title = snapshot.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            data["title"] = title
        }
        return data
    }

    nonisolated static func sharedTripSnapshot(
        tripID: String,
        data: [String: Any]
    ) -> SharedTripSnapshot? {
        let start = date(from: data["startDate"])
        let end = date(from: data["endDate"])
        guard let start, let end else { return nil }
        let countries = stringList(from: data["countries"])
        let plannedSiteIDs = stringList(from: data["plannedSiteIDs"])
        let createdAt = date(from: data["createdAt"]) ?? start
        let updatedAt = date(from: data["updatedAt"]) ?? createdAt
        let title = trimmedNonEmpty(data["title"] as? String)
        let version = (data["schemaVersion"] as? Int) ?? schemaVersion
        return SharedTripSnapshot(
            tripID: tripID,
            title: title,
            startDate: start,
            endDate: end,
            countries: countries,
            plannedSiteIDs: plannedSiteIDs,
            updatedAt: updatedAt,
            createdAt: createdAt,
            schemaVersion: version
        )
    }

    nonisolated static func firestoreData(
        for invite: InviteSnapshot,
        includeCreatedAt: Bool
    ) -> [String: Any] {
        var data: [String: Any] = [
            "schemaVersion": schemaVersion,
            "sharerUid": invite.sharerUID,
            "tripId": invite.tripID,
            "status": invite.status.rawValue,
        ]
        if let title = invite.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            data["title"] = title
        }
        if let name = invite.sharerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            data["sharerDisplayName"] = name
        }
        if includeCreatedAt {
            // Rules require `createdAt == request.time` (same as buddySharePushSignals).
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        if let updatedAt = invite.updatedAt {
            data["updatedAt"] = Timestamp(date: updatedAt)
        }
        return data
    }

    nonisolated static func inviteSnapshot(
        inviteID: String,
        data: [String: Any]
    ) -> InviteSnapshot? {
        guard let sharerUID = trimmedNonEmpty(data["sharerUid"] as? String),
              let tripID = trimmedNonEmpty(data["tripId"] as? String),
              let statusRaw = trimmedNonEmpty(data["status"] as? String),
              let status = InviteStatus(rawValue: statusRaw),
              let createdAt = date(from: data["createdAt"])
        else { return nil }
        return InviteSnapshot(
            inviteID: inviteID,
            sharerUID: sharerUID,
            tripID: tripID,
            status: status,
            title: trimmedNonEmpty(data["title"] as? String),
            sharerDisplayName: trimmedNonEmpty(data["sharerDisplayName"] as? String),
            createdAt: createdAt,
            updatedAt: date(from: data["updatedAt"]),
            schemaVersion: (data["schemaVersion"] as? Int) ?? schemaVersion
        )
    }

    nonisolated static func snapshot(from trip: DiveTrip, now: Date = .now) -> SharedTripSnapshot {
        SharedTripSnapshot(
            tripID: trip.id.uuidString,
            title: trip.title,
            startDate: trip.startDate,
            endDate: trip.endDate,
            countries: trip.countries,
            plannedSiteIDs: trip.plannedSiteIDs.map(\.uuidString),
            updatedAt: now,
            createdAt: trip.createdAt,
            schemaVersion: schemaVersion
        )
    }

    /// Fingerprint of owner-synced fields (skip no-op recipient applies).
    nonisolated static func syncedFieldsFingerprint(_ snapshot: SharedTripSnapshot) -> String {
        let title = snapshot.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let countries = snapshot.countries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
        let sites = snapshot.plannedSiteIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: ",")
        return [
            title,
            String(snapshot.startDate.timeIntervalSince1970),
            String(snapshot.endDate.timeIntervalSince1970),
            countries,
            sites,
            String(snapshot.updatedAt.timeIntervalSince1970),
        ].joined(separator: "\u{1e}")
    }

    nonisolated private static func date(from value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = value as? Date {
            return date
        }
        return nil
    }

    nonisolated private static func stringList(from value: Any?) -> [String] {
        guard let list = value as? [Any] else { return [] }
        return list.compactMap { item in
            trimmedNonEmpty(item as? String)
        }
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
