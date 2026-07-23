import Foundation

/// Duplicate detection for **`SnorkelActivity`** FIT re-imports.
enum SnorkelActivityDuplicateMatcher {

    struct Signature: Equatable, Sendable {
        let id: UUID
        let sourceActivityId: String?
        let startTime: Date
        let durationMinutes: Int
        let swimDistanceMeters: Double?
        let maxDepthMeters: Double?

        nonisolated init(
            id: UUID = UUID(),
            sourceActivityId: String? = nil,
            startTime: Date,
            durationMinutes: Int,
            swimDistanceMeters: Double? = nil,
            maxDepthMeters: Double? = nil
        ) {
            self.id = id
            let trimmed = sourceActivityId?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.sourceActivityId = (trimmed?.isEmpty == false) ? trimmed : nil
            self.startTime = startTime
            self.durationMinutes = durationMinutes
            self.swimDistanceMeters = swimDistanceMeters
            self.maxDepthMeters = maxDepthMeters
        }
    }

    enum MatchReason: Sendable {
        case sameSourceActivityId
        case matchingFingerprint
    }

    struct Match: Sendable {
        let existingId: UUID
        let reason: MatchReason
    }

    nonisolated static let startTimeToleranceSeconds: TimeInterval = 120
    nonisolated static let swimDistanceToleranceMeters = 5.0
    nonisolated static let maxDepthToleranceMeters = 0.6
    nonisolated static let durationMinutesTolerance: Int = 1

    @MainActor
    static func signature(for activity: SnorkelActivity) -> Signature {
        Signature(
            id: activity.id,
            sourceActivityId: activity.sourceActivityId,
            startTime: activity.startTime,
            durationMinutes: activity.durationMinutes,
            swimDistanceMeters: activity.swimDistanceMeters,
            maxDepthMeters: activity.maxDepthMeters
        )
    }

    nonisolated static func matchReason(candidate: Signature, existing: Signature) -> MatchReason? {
        guard candidate.id != existing.id else { return nil }

        if let cid = candidate.sourceActivityId,
           let eid = existing.sourceActivityId,
           cid == eid {
            return .sameSourceActivityId
        }

        guard abs(candidate.startTime.timeIntervalSince(existing.startTime)) <= startTimeToleranceSeconds else {
            return nil
        }
        guard abs(candidate.durationMinutes - existing.durationMinutes) <= durationMinutesTolerance else {
            return nil
        }

        let candidateDistance = candidate.swimDistanceMeters ?? 0
        let existingDistance = existing.swimDistanceMeters ?? 0
        guard abs(candidateDistance - existingDistance) <= swimDistanceToleranceMeters else {
            return nil
        }

        let candidateDepth = candidate.maxDepthMeters ?? 0
        let existingDepth = existing.maxDepthMeters ?? 0
        guard abs(candidateDepth - existingDepth) <= maxDepthToleranceMeters else {
            return nil
        }

        return .matchingFingerprint
    }

    nonisolated static func findDuplicate(for candidate: Signature, among existing: [Signature]) -> Match? {
        for row in existing {
            if let reason = matchReason(candidate: candidate, existing: row) {
                return Match(existingId: row.id, reason: reason)
            }
        }
        return nil
    }

    @MainActor
    static func importBlockedMessage(matching existing: SnorkelActivity) -> String {
        let when = existing.formattedStartDateTime()
        return "This snorkel session looks like one already in your log (starting \(when)). It was not imported again."
    }
}
