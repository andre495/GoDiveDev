import Foundation
import SwiftData

/// Cached Home tab aggregates — built once per data change, not on every SwiftUI body pass.
struct HomeOverviewAggregate: Sendable {
    static let empty = HomeOverviewAggregate(
        contentFingerprint: 0,
        carouselFingerprint: 0,
        carouselTagFingerprint: 0,
        diveStatsInputs: [],
        sightingCountInputs: [],
        lifetimeStats: HomeLifetimeStatsPresentation.build(dives: [], sightings: []),
        myActivitiesSummary: .empty,
        buddyLeaderboard: [],
        ownerMediaPhotos: [],
        mediaByID: [:],
        mediaPhotoSeeds: [],
        divesByID: [:],
        ownerDiveIDs: [],
        ownerSightings: [],
        mediaHighlightSightings: [],
        mediaHighlightBuddyTags: [],
        taggedBuddyRowsByMediaID: [:]
    )

    let contentFingerprint: Int
    let carouselFingerprint: Int
    let carouselTagFingerprint: Int
    let diveStatsInputs: [HomeDiveStatsInput]
    let sightingCountInputs: [HomeLifetimeStatsPresentation.SightingCountInput]
    let lifetimeStats: HomeLifetimeStats
    let myActivitiesSummary: LogbookMyActivitiesSummary
    let buddyLeaderboard: [HomeBuddyLeaderboardEntry]
    /// Bound media rows for the current carousel picks only (full rows incl. stored preview).
    let ownerMediaPhotos: [DiveMediaPhoto]
    let mediaByID: [UUID: DiveMediaPhoto]
    /// Sendable media **index** for candidate building — no bound rows, no JPEG blobs.
    let mediaPhotoSeeds: [HomeOverviewMediaPhotoSeed]
    let divesByID: [UUID: DiveActivity]
    let ownerDiveIDs: Set<UUID>
    let ownerSightings: [SightingInstance]
    let mediaHighlightSightings: [HomeMediaHighlightSightingInput]
    let mediaHighlightBuddyTags: [HomeMediaHighlightBuddyTagInput]
    let taggedBuddyRowsByMediaID: [UUID: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]]

    /// Returns a copy with carousel media objects attached (stats / fingerprints unchanged).
    func withCarouselMedia(
        _ photos: [DiveMediaPhoto],
        mediaPhotoSeeds: [HomeOverviewMediaPhotoSeed]? = nil
    ) -> HomeOverviewAggregate {
        let mediaByID = Dictionary(godiveUniquingKeysWithValues: photos.map { ($0.id, $0) })
        return HomeOverviewAggregate(
            contentFingerprint: contentFingerprint,
            carouselFingerprint: carouselFingerprint,
            carouselTagFingerprint: carouselTagFingerprint,
            diveStatsInputs: diveStatsInputs,
            sightingCountInputs: sightingCountInputs,
            lifetimeStats: lifetimeStats,
            myActivitiesSummary: myActivitiesSummary,
            buddyLeaderboard: buddyLeaderboard,
            ownerMediaPhotos: photos,
            mediaByID: mediaByID,
            mediaPhotoSeeds: mediaPhotoSeeds ?? self.mediaPhotoSeeds,
            divesByID: divesByID,
            ownerDiveIDs: ownerDiveIDs,
            ownerSightings: ownerSightings,
            mediaHighlightSightings: mediaHighlightSightings,
            mediaHighlightBuddyTags: mediaHighlightBuddyTags,
            taggedBuddyRowsByMediaID: taggedBuddyRowsByMediaID
        )
    }
}

/// Launch-path build: stats aggregate + media index seeds (no JPEG objects yet).
struct HomeOverviewLaunchBuild: Sendable {
    let aggregate: HomeOverviewAggregate
    let mediaPhotoSeeds: [HomeOverviewMediaPhotoSeed]
    /// Thin common-name map resolved for owner-tagged species during launch (may be partial).
    let commonNameByUUID: [String: String]
}

/// Builds **`HomeOverviewAggregate`** from SwiftData models.
@MainActor
enum HomeOverviewAggregateBuilder {

    /// Millisecond-scale Home launch — scalars + sightings/buddies for stats; caller loads pick JPEG rows.
    static func buildLaunchAsync(
        activities: [DiveActivity],
        buddyRoster: [DiveBuddy],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem = .metric,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile? = nil,
        modelContext: ModelContext,
        commonNameByUUID: [String: String] = [:],
        referenceDate: Date = .now
    ) async -> HomeOverviewLaunchBuild {
        let capture = HomeOverviewSnapshotSeeding.captureLaunch(
            activities: activities,
            buddyRoster: buddyRoster,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            ownerProfile: ownerProfile,
            modelContext: modelContext,
            commonNameByUUID: commonNameByUUID,
            referenceDate: referenceDate
        )
        // Sighting seeds can repeat the same marineLifeUUID across dives — uniqueKeys traps.
        let resolvedNames = Dictionary(
            godiveUniquingKeysWithValues: capture.input.sightingSeeds.map { ($0.marineLifeUUID, $0.commonName) }
        ).merging(commonNameByUUID) { seedName, existing in
            let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? seedName : existing
        }

        let computed = await Task.detached(priority: .userInitiated) {
            HomeOverviewAggregateComputer.build(from: capture.input)
        }.value

        let aggregate = assemble(
            computed: computed,
            activities: activities,
            carouselMedia: [],
            ownerSightings: []
        )
        // Media index is loaded by the caller after stats paint.
        return HomeOverviewLaunchBuild(
            aggregate: aggregate,
            mediaPhotoSeeds: [],
            commonNameByUUID: resolvedNames
        )
    }

    static func buildAsync(
        activities: [DiveActivity],
        commonNameByUUID: [String: String],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem = .metric,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile? = nil,
        modelContext: ModelContext? = nil,
        buddyRoster: [DiveBuddy] = [],
        referenceDate: Date = .now
    ) async -> HomeOverviewAggregate {
        let rebuildSignpost = AppPerformanceSignpost.begin(.homeOverviewRebuild)
        defer { AppPerformanceSignpost.end(.homeOverviewRebuild, signpostID: rebuildSignpost) }

        let input: HomeOverviewBuildInput
        let computed: HomeOverviewComputedResult
        if let modelContext {
            // Capture + compute on a background context — no main-actor SQLite / JPEG-blob I/O
            // while the user interacts with the first Home frame.
            let container = modelContext.container
            let activityIDs = activities.map(\.id)
            let rosterIDs = buddyRoster.map(\.id)
            let selfBuddyID = ownerProfile.flatMap {
                DiveBuddySelfRepresentation.resolveSelfBuddyID(owner: $0, modelContext: modelContext)
            }
            let names = commonNameByUUID
            let renumber = automaticallyRenumberDives
            let units = displayUnits
            let ownerID = ownerProfileID
            let reference = referenceDate
            (input, computed) = await Task.detached(priority: .userInitiated) {
                let context = ModelContext(container)
                let backgroundActivities = fetchActivities(ids: activityIDs, context: context)
                let backgroundRoster = fetchBuddies(ids: rosterIDs, context: context)
                let capturedInput = HomeOverviewSnapshotSeeding.capture(
                    activities: backgroundActivities,
                    commonNameByUUID: names,
                    automaticallyRenumberDives: renumber,
                    displayUnits: units,
                    ownerProfileID: ownerID,
                    selfBuddyID: selfBuddyID,
                    modelContext: context,
                    referenceDate: reference,
                    buddyRoster: backgroundRoster
                )
                let computeSignpost = AppPerformanceSignpost.begin(.homeOverviewCompute)
                defer { AppPerformanceSignpost.end(.homeOverviewCompute, signpostID: computeSignpost) }
                return (capturedInput, HomeOverviewAggregateComputer.build(from: capturedInput))
            }.value
        } else {
            // Tests / previews without a live context.
            input = HomeOverviewSnapshotSeeding.capture(
                activities: activities,
                commonNameByUUID: commonNameByUUID,
                automaticallyRenumberDives: automaticallyRenumberDives,
                displayUnits: displayUnits,
                ownerProfileID: ownerProfileID,
                ownerProfile: ownerProfile,
                modelContext: nil,
                referenceDate: referenceDate,
                buddyRoster: buddyRoster
            )
            computed = HomeOverviewAggregateComputer.build(from: input)
        }

        let ownerSightings = resolveOwnerSightings(
            ownerDiveIDs: computed.ownerDiveIDs,
            activities: activities,
            modelContext: modelContext
        )

        // Bind full media rows for today's carousel picks only — everything else stays a seed.
        let carouselMedia: [DiveMediaPhoto]
        if let modelContext, let ownerProfileID {
            let pickIDs = carouselPickMediaIDs(
                input: input,
                computed: computed,
                ownerProfileID: ownerProfileID,
                referenceDate: referenceDate
            )
            carouselMedia = HomeDiveScalarSeeding.fetchMediaPhotos(
                ids: pickIDs,
                modelContext: modelContext
            )
        } else {
            carouselMedia = []
        }

        return assemble(
            computed: computed,
            activities: activities,
            carouselMedia: carouselMedia,
            ownerSightings: ownerSightings,
            mediaPhotoSeeds: input.mediaPhotoSeeds
        )
    }

    /// Same candidates + daily shuffle as **`buildCarouselHighlights`** — deterministic within a
    /// session (**`carouselShuffleSeed`**), so the rows bound here match the picks Home renders.
    nonisolated private static func carouselPickMediaIDs(
        input: HomeOverviewBuildInput,
        computed: HomeOverviewComputedResult,
        ownerProfileID: UUID,
        referenceDate: Date
    ) -> [UUID] {
        let candidates = HomeMediaHighlightPresentation.buildCandidates(
            mediaPhotos: HomeMediaHighlightWarmup.highlightSources(from: input.mediaPhotoSeeds),
            dives: computed.diveStatsInputs,
            taggedSpeciesCountByMediaID: HomeMediaHighlightPresentation.taggedSpeciesCountByMediaID(
                sightings: computed.mediaHighlightSightings,
                ownerDiveIDs: computed.ownerDiveIDs
            ),
            taggedBuddyCountByMediaID: HomeMediaHighlightPresentation.taggedBuddyCountByMediaID(
                buddyTags: computed.mediaHighlightBuddyTags,
                ownerDiveIDs: computed.ownerDiveIDs
            )
        )
        return HomeMediaHighlightPresentation.highlightsForOwner(
            ownerProfileID: ownerProfileID,
            candidates: candidates,
            referenceDate: referenceDate
        ).map(\.mediaID)
    }

    /// Re-fetches owner dives on a background context, preserving the caller's row order.
    nonisolated private static func fetchActivities(
        ids: [UUID],
        context: ModelContext
    ) -> [DiveActivity] {
        guard !ids.isEmpty else { return [] }
        let idList = ids
        let descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate<DiveActivity> { idList.contains($0.id) }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        let byID = Dictionary(godiveUniquingKeysWithValues: rows.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    /// Re-fetches the buddy roster on a background context, preserving the caller's row order.
    nonisolated private static func fetchBuddies(
        ids: [UUID],
        context: ModelContext
    ) -> [DiveBuddy] {
        guard !ids.isEmpty else { return [] }
        let idList = ids
        let descriptor = FetchDescriptor<DiveBuddy>(
            predicate: #Predicate<DiveBuddy> { idList.contains($0.id) }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        let byID = Dictionary(godiveUniquingKeysWithValues: rows.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    /// Convenience when the caller already has bound **`MarineLife`** rows (e.g. Profile).
    static func buildAsync(
        activities: [DiveActivity],
        marineLifeCatalog: [MarineLife],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem = .metric,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile? = nil,
        modelContext: ModelContext? = nil,
        buddyRoster: [DiveBuddy] = [],
        referenceDate: Date = .now
    ) async -> HomeOverviewAggregate {
        await buildAsync(
            activities: activities,
            commonNameByUUID: MarineLifeCatalogLoader.commonNameByUUID(from: marineLifeCatalog),
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            ownerProfile: ownerProfile,
            modelContext: modelContext,
            buddyRoster: buddyRoster,
            referenceDate: referenceDate
        )
    }

    /// Synchronous build — tests and previews only; prefer **`buildAsync`** on device.
    static func build(
        activities: [DiveActivity],
        commonNameByUUID: [String: String] = [:],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem = .metric,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile? = nil,
        modelContext: ModelContext? = nil,
        buddyRoster: [DiveBuddy] = [],
        referenceDate: Date = .now
    ) -> HomeOverviewAggregate {
        let input = HomeOverviewSnapshotSeeding.capture(
            activities: activities,
            commonNameByUUID: commonNameByUUID,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            ownerProfile: ownerProfile,
            modelContext: modelContext,
            referenceDate: referenceDate,
            buddyRoster: buddyRoster
        )
        let computed = HomeOverviewAggregateComputer.build(from: input)
        return assemble(
            computed: computed,
            activities: activities,
            carouselMedia: [],
            ownerSightings: resolveOwnerSightings(
                ownerDiveIDs: computed.ownerDiveIDs,
                activities: activities,
                modelContext: modelContext
            ),
            mediaPhotoSeeds: input.mediaPhotoSeeds
        )
    }

    /// Synchronous launch-style build for tests (requires model context).
    static func buildLaunch(
        activities: [DiveActivity],
        buddyRoster: [DiveBuddy],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem = .metric,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile? = nil,
        modelContext: ModelContext,
        commonNameByUUID: [String: String] = [:],
        referenceDate: Date = .now
    ) -> HomeOverviewLaunchBuild {
        let capture = HomeOverviewSnapshotSeeding.captureLaunch(
            activities: activities,
            buddyRoster: buddyRoster,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            ownerProfile: ownerProfile,
            modelContext: modelContext,
            commonNameByUUID: commonNameByUUID,
            referenceDate: referenceDate
        )
        let resolvedNames = Dictionary(
            godiveUniquingKeysWithValues: capture.input.sightingSeeds.map { ($0.marineLifeUUID, $0.commonName) }
        ).merging(commonNameByUUID) { seedName, existing in
            let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? seedName : existing
        }
        let computed = HomeOverviewAggregateComputer.build(from: capture.input)
        let aggregate = assemble(
            computed: computed,
            activities: activities,
            carouselMedia: [],
            ownerSightings: []
        )
        return HomeOverviewLaunchBuild(
            aggregate: aggregate,
            mediaPhotoSeeds: capture.mediaPhotoSeeds,
            commonNameByUUID: resolvedNames
        )
    }

    private static func resolveOwnerSightings(
        ownerDiveIDs: Set<UUID>,
        activities: [DiveActivity],
        modelContext: ModelContext?
    ) -> [SightingInstance] {
        if let modelContext {
            return HomeDiveScalarSeeding.fetchSightingInstances(
                ownerDiveIDs: ownerDiveIDs,
                activities: activities,
                modelContext: modelContext
            )
        }
        var sightings: [SightingInstance] = []
        for activity in activities where ownerDiveIDs.contains(activity.id) {
            sightings.append(contentsOf: activity.marineLifeSightings)
        }
        return sightings
    }

    private static func assemble(
        computed: HomeOverviewComputedResult,
        activities: [DiveActivity],
        carouselMedia: [DiveMediaPhoto],
        ownerSightings: [SightingInstance],
        mediaPhotoSeeds: [HomeOverviewMediaPhotoSeed] = []
    ) -> HomeOverviewAggregate {
        let divesByID = Dictionary(godiveUniquingKeysWithValues: activities.map { ($0.id, $0) })
        let mediaByID = Dictionary(godiveUniquingKeysWithValues: carouselMedia.map { ($0.id, $0) })

        return HomeOverviewAggregate(
            contentFingerprint: computed.contentFingerprint,
            carouselFingerprint: computed.carouselFingerprint,
            carouselTagFingerprint: computed.carouselTagFingerprint,
            diveStatsInputs: computed.diveStatsInputs,
            sightingCountInputs: computed.sightingCountInputs,
            lifetimeStats: computed.lifetimeStats,
            myActivitiesSummary: computed.myActivitiesSummary,
            buddyLeaderboard: computed.buddyLeaderboard,
            ownerMediaPhotos: carouselMedia,
            mediaByID: mediaByID,
            mediaPhotoSeeds: mediaPhotoSeeds,
            divesByID: divesByID,
            ownerDiveIDs: computed.ownerDiveIDs,
            ownerSightings: ownerSightings,
            mediaHighlightSightings: computed.mediaHighlightSightings,
            mediaHighlightBuddyTags: computed.mediaHighlightBuddyTags,
            taggedBuddyRowsByMediaID: computed.taggedBuddyRowsByMediaID
        )
    }
}
