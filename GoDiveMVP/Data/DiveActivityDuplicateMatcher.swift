import Foundation
import SwiftData

/// Lightweight duplicate detection for **`DiveActivity`** rows (import guard + logbook hints).
///
/// **Same file / same exporter id:** equal non-empty **`sourceDiveId`** (re-import **`.fit`** or same UDDF **`<dive id>`**).
///
/// **Cross-format (e.g. Garmin `.fit` vs MacDive `.uddf`):** matching **fingerprint** — start within **2 min**, max depth within **0.6 m**, and bottom time within **5 s** when both sides have it, else **durationMinutes** within **1 min**.
enum DiveActivityDuplicateMatcher {

    struct Signature: Equatable {
        let id: UUID
        let sourceDiveId: String?
        let startTime: Date
        let maxDepthMeters: Double
        let durationMinutes: Int
        let bottomTimeSeconds: Int?

        @MainActor
        init(_ activity: DiveActivity) {
            id = activity.id
            let trimmed = activity.sourceDiveId?.trimmingCharacters(in: .whitespacesAndNewlines)
            sourceDiveId = (trimmed?.isEmpty == false) ? trimmed : nil
            startTime = activity.startTime
            maxDepthMeters = activity.maxDepthMeters
            durationMinutes = activity.durationMinutes
            bottomTimeSeconds = activity.bottomTimeSeconds
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
    static let bottomTimeToleranceSeconds = 5
    static let durationMinutesTolerance = 1

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
        let when = existing.startTime.formatted(date: .abbreviated, time: .shortened)
        return "This dive is already in your log (\(when))."
    }

    private static func durationOrBottomTimeMatches(_ a: Signature, _ b: Signature) -> Bool {
        if let aBottom = a.bottomTimeSeconds, let bBottom = b.bottomTimeSeconds {
            return abs(aBottom - bBottom) <= bottomTimeToleranceSeconds
        }
        return abs(a.durationMinutes - b.durationMinutes) <= durationMinutesTolerance
    }
}
