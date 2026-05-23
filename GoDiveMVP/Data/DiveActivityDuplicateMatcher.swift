import Foundation
import SwiftData

/// Lightweight duplicate detection for **`DiveActivity`** rows (import guard + logbook hints).
///
/// **Same file / same exporter id:** equal non-empty **`sourceDiveId`** (re-import **`.fit`** or same UDDF **`<dive id>`**).
///
/// **Cross-format (e.g. Garmin `.fit` vs MacDive `.uddf`):** matching **fingerprint** when **`sourceDiveId`** differs — start within **2 min**, max depth within **0.6 m**, and in-water time within tolerance (prefers **`bottomTimeSeconds`**, else **`durationMinutes`**).
enum DiveActivityDuplicateMatcher {

    struct Signature: Equatable {
        let id: UUID
        let sourceDiveId: String?
        let startTime: Date
        let maxDepthMeters: Double
        let durationMinutes: Int
        let bottomTimeSeconds: Int?

        /// Value initializer for tests and non–**`DiveActivity`** callers (no **Main actor**).
        init(
            id: UUID = UUID(),
            sourceDiveId: String? = nil,
            startTime: Date,
            maxDepthMeters: Double,
            durationMinutes: Int,
            bottomTimeSeconds: Int? = nil
        ) {
            self.id = id
            let trimmed = sourceDiveId?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.sourceDiveId = (trimmed?.isEmpty == false) ? trimmed : nil
            self.startTime = startTime
            self.maxDepthMeters = maxDepthMeters
            self.durationMinutes = durationMinutes
            self.bottomTimeSeconds = bottomTimeSeconds
        }

        @MainActor
        init(_ activity: DiveActivity) {
            self.init(
                id: activity.id,
                sourceDiveId: activity.sourceDiveId,
                startTime: activity.startTime,
                maxDepthMeters: activity.maxDepthMeters,
                durationMinutes: activity.durationMinutes,
                bottomTimeSeconds: activity.bottomTimeSeconds
            )
        }

        /// **`DiveActivity`** is **Main actor**; explicit **nonisolated** **`Equatable`** keeps **`#expect`** usable in Swift 6.
        nonisolated static func == (lhs: Signature, rhs: Signature) -> Bool {
            lhs.id == rhs.id
                && lhs.sourceDiveId == rhs.sourceDiveId
                && lhs.startTime == rhs.startTime
                && lhs.maxDepthMeters == rhs.maxDepthMeters
                && lhs.durationMinutes == rhs.durationMinutes
                && lhs.bottomTimeSeconds == rhs.bottomTimeSeconds
        }
    }

    enum MatchReason: Sendable {
        case sameSourceDiveId
        case matchingFingerprint
    }

    struct Match: Sendable {
        let existingId: UUID
        let reason: MatchReason
    }

    /// Start times may differ slightly between exporters (timezone / rounding).
    static let startTimeToleranceSeconds: TimeInterval = 120
    static let maxDepthToleranceMeters = 0.6
    static let bottomTimeToleranceSeconds: Int = 5
    static let durationMinutesTolerance: Int = 1

    @MainActor
    static func allSignatures(modelContext: ModelContext) throws -> [Signature] {
        try modelContext.fetch(FetchDescriptor<DiveActivity>()).map(Signature.init)
    }

    static func matchReason(candidate: Signature, existing: Signature) -> MatchReason? {
        guard candidate.id != existing.id else { return nil }

        if let cid = candidate.sourceDiveId, let eid = existing.sourceDiveId, cid == eid {
            return .sameSourceDiveId
        }

        guard abs(candidate.startTime.timeIntervalSince(existing.startTime)) <= startTimeToleranceSeconds else {
            return nil
        }
        guard abs(candidate.maxDepthMeters - existing.maxDepthMeters) <= maxDepthToleranceMeters else {
            return nil
        }
        guard durationOrBottomTimeMatches(candidate, existing) else {
            return nil
        }

        return .matchingFingerprint
    }

    static func findDuplicate(for candidate: Signature, among existing: [Signature]) -> Match? {
        for row in existing {
            if let reason = matchReason(candidate: candidate, existing: row) {
                return Match(existingId: row.id, reason: reason)
            }
        }
        return nil
    }

    /// Activity ids that have at least one other row in **`signatures`** that **`matchReason`** considers a duplicate.
    static func idsWithDuplicates(in signatures: [Signature]) -> Set<UUID> {
        guard signatures.count > 1 else { return [] }
        var result = Set<UUID>()
        for i in signatures.indices {
            for j in (i + 1) ..< signatures.count {
                if matchReason(candidate: signatures[i], existing: signatures[j]) != nil {
                    result.insert(signatures[i].id)
                    result.insert(signatures[j].id)
                }
            }
        }
        return result
    }

    static func importBlockedMessage(matching existing: DiveActivity) -> String {
        let when = DiveActivityTimePresentation.formatDateTime(
            existing.startTime,
            timeZoneOffsetSeconds: existing.timeZoneOffsetSeconds
        )
        return "This dive is already in your log (\(when))."
    }

    /// Seconds used for fingerprint compare; prefers explicit bottom time from FIT summary or UDDF **`diveduration`**.
    static func effectiveInWaterSeconds(_ signature: Signature) -> Int {
        if let bottom = signature.bottomTimeSeconds {
            return bottom
        }
        return signature.durationMinutes * 60
    }

    private static func durationOrBottomTimeMatches(_ a: Signature, _ b: Signature) -> Bool {
        let aSeconds = effectiveInWaterSeconds(a)
        let bSeconds = effectiveInWaterSeconds(b)
        let delta = abs(aSeconds - bSeconds)

        if a.bottomTimeSeconds != nil, b.bottomTimeSeconds != nil {
            return delta <= bottomTimeToleranceSeconds
        }
        if a.bottomTimeSeconds != nil || b.bottomTimeSeconds != nil {
            // Mixed FIT/UDDF: one side may only have session **`durationMinutes`** while the other has **`bottomTimeSeconds`**.
            return delta <= durationMinutesTolerance * 60
        }
        return abs(a.durationMinutes - b.durationMinutes) <= durationMinutesTolerance
    }
}
