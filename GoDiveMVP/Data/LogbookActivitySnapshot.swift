import Foundation

/// Sendable logbook row inputs captured on the main actor, then built off-thread.
struct LogbookActivitySnapshotSeed: Sendable, Equatable {
    let id: UUID
    let sourceDiveId: String?
    let startTime: Date
    let maxDepthMeters: Double
    let durationMinutes: Int
    let bottomTimeSeconds: Int?
    let diveNumber: Int?
    let diveNumberExplicitlyNone: Bool
    let displayName: String
    let formattedStartDateOnly: String
    let resolvedSiteNameLowercased: String?
    let activityTagNames: [String]
    let previewMediaPhotoID: UUID?

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
                sourceDiveId: activity.sourceDiveId,
                startTime: activity.startTime,
                maxDepthMeters: activity.maxDepthMeters,
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
                previewMediaPhotoID: DiveActivityMediaPresentation.featuredPhotoID(on: activity)
            )
        }
    }
}
