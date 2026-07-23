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
    let ownerMediaPhotos: [DiveMediaPhoto]
    let mediaByID: [UUID: DiveMediaPhoto]
    let divesByID: [UUID: DiveActivity]
    let ownerDiveIDs: Set<UUID>
    let ownerSightings: [SightingInstance]
    let mediaHighlightSightings: [HomeMediaHighlightSightingInput]
    let mediaHighlightBuddyTags: [HomeMediaHighlightBuddyTagInput]
    let taggedBuddyRowsByMediaID: [UUID: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]]
}

/// Builds **`HomeOverviewAggregate`** from SwiftData models.
@MainActor
enum HomeOverviewAggregateBuilder {

    static func buildAsync(
        activities: [DiveActivity],
        marineLifeCatalog: [MarineLife],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem = .metric,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile? = nil,
        modelContext: ModelContext? = nil,
        referenceDate: Date = .now
    ) async -> HomeOverviewAggregate {
        let rebuildSignpost = AppPerformanceSignpost.begin(.homeOverviewRebuild)
        defer { AppPerformanceSignpost.end(.homeOverviewRebuild, signpostID: rebuildSignpost) }

        let input = HomeOverviewSnapshotSeeding.capture(
            activities: activities,
            marineLifeCatalog: marineLifeCatalog,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            ownerProfile: ownerProfile,
            modelContext: modelContext,
            referenceDate: referenceDate
        )

        let computed = await Task.detached(priority: .userInitiated) {
            let computeSignpost = AppPerformanceSignpost.begin(.homeOverviewCompute)
            defer { AppPerformanceSignpost.end(.homeOverviewCompute, signpostID: computeSignpost) }
            return HomeOverviewAggregateComputer.build(from: input)
        }.value

        return assemble(computed: computed, activities: activities)
    }

    /// Synchronous build — tests and previews only; prefer **`buildAsync`** on device.
    static func build(
        activities: [DiveActivity],
        marineLifeCatalog: [MarineLife],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem = .metric,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile? = nil,
        modelContext: ModelContext? = nil,
        referenceDate: Date = .now
    ) -> HomeOverviewAggregate {
        let input = HomeOverviewSnapshotSeeding.capture(
            activities: activities,
            marineLifeCatalog: marineLifeCatalog,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            ownerProfile: ownerProfile,
            modelContext: modelContext,
            referenceDate: referenceDate
        )
        let computed = HomeOverviewAggregateComputer.build(from: input)
        return assemble(computed: computed, activities: activities)
    }

    private static func assemble(
        computed: HomeOverviewComputedResult,
        activities: [DiveActivity]
    ) -> HomeOverviewAggregate {
        var mediaByID: [UUID: DiveMediaPhoto] = [:]
        var ownerSightings: [SightingInstance] = []
        for activity in activities {
            for photo in activity.mediaPhotos {
                mediaByID[photo.id] = photo
            }
            ownerSightings.append(contentsOf: activity.marineLifeSightings)
        }

        let ownerMedia = computed.ownerMediaPhotoIDs.compactMap { mediaByID[$0] }
        let divesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

        return HomeOverviewAggregate(
            contentFingerprint: computed.contentFingerprint,
            carouselFingerprint: computed.carouselFingerprint,
            carouselTagFingerprint: computed.carouselTagFingerprint,
            diveStatsInputs: computed.diveStatsInputs,
            sightingCountInputs: computed.sightingCountInputs,
            lifetimeStats: computed.lifetimeStats,
            myActivitiesSummary: computed.myActivitiesSummary,
            buddyLeaderboard: computed.buddyLeaderboard,
            ownerMediaPhotos: ownerMedia,
            mediaByID: mediaByID,
            divesByID: divesByID,
            ownerDiveIDs: computed.ownerDiveIDs,
            ownerSightings: ownerSightings,
            mediaHighlightSightings: computed.mediaHighlightSightings,
            mediaHighlightBuddyTags: computed.mediaHighlightBuddyTags,
            taggedBuddyRowsByMediaID: computed.taggedBuddyRowsByMediaID
        )
    }
}
