import Foundation

/// Sendable logbook row inputs captured on the main actor, then built off-thread.
struct LogbookActivitySnapshotSeed: Sendable, Equatable {
    let id: UUID
    let kind: LogbookActivitySnapshotKind
    let sourceDiveId: String?
    let sourceActivityId: String?
    let startTime: Date
    let maxDepthMeters: Double
    let swimDistanceMeters: Double?
    let durationMinutes: Int
    let bottomTimeSeconds: Int?
    let diveNumber: Int?
    let diveNumberExplicitlyNone: Bool
    let displayName: String
    let formattedStartDateOnly: String
    let resolvedSiteNameLowercased: String?
    let activityTagNames: [String]
    let buddyDisplayNames: [String]
    let previewMediaPhotoID: UUID?
    let linkedTripID: UUID?
    /// When **`true`**, row thumbnail is **`SnorkelMediaPhoto`** (not **`DiveMediaPhoto`**).
    let previewMediaIsSnorkel: Bool

    nonisolated var duplicateSignature: DiveActivityDuplicateMatcher.Signature {
        DiveActivityDuplicateMatcher.Signature(
            id: id,
            sourceDiveId: sourceDiveId,
            startTime: startTime,
            maxDepthMeters: maxDepthMeters,
            durationMinutes: durationMinutes,
            bottomTimeSeconds: bottomTimeSeconds
        )
    }

    nonisolated var snorkelDuplicateSignature: SnorkelActivityDuplicateMatcher.Signature {
        SnorkelActivityDuplicateMatcher.Signature(
            id: id,
            sourceActivityId: sourceActivityId,
            startTime: startTime,
            durationMinutes: durationMinutes,
            swimDistanceMeters: swimDistanceMeters,
            maxDepthMeters: maxDepthMeters > 0 ? maxDepthMeters : nil
        )
    }

    nonisolated func matchesSiteSearch(query: String) -> Bool {
        DiveLogbookSiteSearch.matchesSite(
            resolvedSiteName: resolvedSiteNameLowercased,
            query: query
        )
    }

    nonisolated var numberingRow: DiveActivityDiveNumbering.NumberingRow {
        DiveActivityDiveNumbering.NumberingRow(
            id: id,
            startTime: startTime,
            diveNumberExplicitlyNone: diveNumberExplicitlyNone
        )
    }
}

/// Main-actor capture of **`DiveActivity`** fields into **`LogbookActivitySnapshotSeed`**.
enum LogbookActivitySnapshotSeeding {
    @MainActor
    static func seeds(from activities: [DiveActivity]) -> [LogbookActivitySnapshotSeed] {
        activities.map { activity in
            LogbookActivitySnapshotSeed(
                id: activity.id,
                kind: .scubaDive,
                sourceDiveId: activity.sourceDiveId,
                sourceActivityId: nil,
                startTime: activity.startTime,
                maxDepthMeters: activity.maxDepthMeters,
                swimDistanceMeters: nil,
                durationMinutes: activity.durationMinutes,
                bottomTimeSeconds: activity.bottomTimeSeconds,
                diveNumber: activity.diveNumber,
                diveNumberExplicitlyNone: activity.diveNumberExplicitlyNone,
                displayName: LogbookActivityRow.displayName(for: activity),
                formattedStartDateOnly: activity.formattedStartDateOnly(),
                resolvedSiteNameLowercased: activity.resolvedSiteName?.lowercased(),
                activityTagNames: activity.activityTags
                    .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
                buddyDisplayNames: activity.buddies
                    .map(\.displayName)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
                previewMediaPhotoID: DiveActivityMediaPresentation.featuredPhotoID(on: activity),
                linkedTripID: LogbookTripSnapshotSeeding.primaryLinkedTripID(for: activity),
                previewMediaIsSnorkel: false
            )
        }
    }

    @MainActor
    static func snorkelSeeds(from activities: [SnorkelActivity]) -> [LogbookActivitySnapshotSeed] {
        activities.map { activity in
            LogbookActivitySnapshotSeed(
                id: activity.id,
                kind: .snorkel,
                sourceDiveId: nil,
                sourceActivityId: activity.sourceActivityId,
                startTime: activity.startTime,
                maxDepthMeters: activity.maxDepthMeters ?? 0,
                swimDistanceMeters: activity.swimDistanceMeters,
                durationMinutes: activity.durationMinutes,
                bottomTimeSeconds: nil,
                diveNumber: nil,
                diveNumberExplicitlyNone: true,
                displayName: LogbookActivityRow.displayName(for: activity),
                formattedStartDateOnly: activity.formattedStartDateOnly(),
                resolvedSiteNameLowercased: activity.resolvedSiteName?.lowercased(),
                activityTagNames: [],
                buddyDisplayNames: activity.buddies
                    .map(\.displayName)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
                previewMediaPhotoID: SnorkelActivityMediaPresentation.featuredPhotoID(on: activity),
                linkedTripID: nil,
                previewMediaIsSnorkel: true
            )
        }
    }

    /// Newest-first merged feed for the logbook list (dives + snorkels).
    @MainActor
    static func mergedActivitySeeds(
        dives: [DiveActivity],
        snorkels: [SnorkelActivity]
    ) -> [LogbookActivitySnapshotSeed] {
        let combined = seeds(from: dives) + snorkelSeeds(from: snorkels)
        return combined.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime {
                return lhs.startTime > rhs.startTime
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
