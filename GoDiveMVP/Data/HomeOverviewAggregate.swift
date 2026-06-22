import Foundation
import SwiftData

/// Cached Home tab aggregates — built once per data change, not on every SwiftUI body pass.
struct HomeOverviewAggregate: Sendable {
    static let empty = HomeOverviewAggregate(
        contentFingerprint: 0,
        carouselFingerprint: 0,
        carouselTagFingerprint: 0,
        diveStatsInputs: [],
        lifetimeStats: HomeLifetimeStatsPresentation.build(dives: [], sightings: []),
        buddyLeaderboard: [],
        ownerMediaPhotos: [],
        mediaByID: [:],
        divesByID: [:],
        ownerDiveIDs: [],
        mediaHighlightSightings: [],
        mediaHighlightBuddyTags: [],
        taggedBuddyRowsByMediaID: [:]
    )

    let contentFingerprint: Int
    let carouselFingerprint: Int
    let carouselTagFingerprint: Int
    let diveStatsInputs: [HomeDiveStatsInput]
    let lifetimeStats: HomeLifetimeStats
    let buddyLeaderboard: [HomeBuddyLeaderboardEntry]
    let ownerMediaPhotos: [DiveMediaPhoto]
    let mediaByID: [UUID: DiveMediaPhoto]
    let divesByID: [UUID: DiveActivity]
    let ownerDiveIDs: Set<UUID>
    let mediaHighlightSightings: [HomeMediaHighlightSightingInput]
    let mediaHighlightBuddyTags: [HomeMediaHighlightBuddyTagInput]
    let taggedBuddyRowsByMediaID: [UUID: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]]
}

/// Builds **`HomeOverviewAggregate`** from SwiftData models (main actor — touches relationships once).
@MainActor
enum HomeOverviewAggregateBuilder {

    static func build(
        activities: [DiveActivity],
        allMediaPhotos: [DiveMediaPhoto],
        allSightings: [SightingInstance],
        marineLifeCatalog: [MarineLife],
        automaticallyRenumberDives: Bool,
        ownerProfileID: UUID?,
        referenceDate: Date = .now
    ) -> HomeOverviewAggregate {
        let ownerDiveIDs = Set(activities.map(\.id))
        let buddyTags = HomeBuddyLeaderboardSeeding.tagInputs(from: activities)

        let chronologicalNumbers = automaticallyRenumberDives
            ? DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: activities)
            : [:]

        let diveStatsInputs = activities.map { activity in
            HomeDiveStatsInput(
                id: activity.id,
                maxDepthMeters: activity.maxDepthMeters,
                durationMinutes: activity.durationMinutes,
                diveSiteID: activity.diveSiteID,
                diveNumberLabel: HomeMediaHighlightPresentation.diveNumberLabel(
                    diveNumber: activity.diveNumber,
                    diveNumberExplicitlyNone: activity.diveNumberExplicitlyNone,
                    chronologicalIndex: chronologicalNumbers[activity.id],
                    useChronologicalNumbers: automaticallyRenumberDives
                ),
                siteDisplayName: LogbookActivityRow.displayName(for: activity)
            )
        }

        let sightingInputs = sightingCountInputs(
            allSightings: allSightings,
            ownerDiveIDs: ownerDiveIDs,
            marineLifeCatalog: marineLifeCatalog
        )

        let ownerMedia = ownerMediaPhotos(allMediaPhotos: allMediaPhotos, ownerDiveIDs: ownerDiveIDs)
        let mediaByID = Dictionary(uniqueKeysWithValues: ownerMedia.map { ($0.id, $0) })
        let divesByID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

        let lifetimeStats = HomeLifetimeStatsPresentation.build(
            dives: diveStatsInputs,
            sightings: sightingInputs
        )
        let buddyLeaderboard = HomeBuddyLeaderboardPresentation.topEntries(from: buddyTags)

        let mediaHighlightSightings = allSightings.map {
            HomeMediaHighlightSightingInput(
                mediaPhotoID: $0.mediaPhotoID,
                diveActivityID: $0.diveActivityID
            )
        }
        .filter { sighting in
            guard let diveID = sighting.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }

        let mediaHighlightBuddyTags = activities.flatMap { activity in
            activity.mediaBuddyTags.map { tag in
                HomeMediaHighlightBuddyTagInput(
                    mediaPhotoID: tag.mediaPhotoID,
                    diveActivityID: tag.diveActivityID ?? activity.id,
                    buddyID: tag.buddyID,
                    displayName: tag.buddy?.displayName ?? "Buddy",
                    profilePhoto: tag.buddy?.profilePhoto
                )
            }
        }
        .filter { tag in
            guard let diveID = tag.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }

        let taggedBuddyRowsByMediaID = HomeMediaHighlightPresentation.taggedBuddyRowsByMediaID(
            buddyTags: mediaHighlightBuddyTags,
            ownerDiveIDs: ownerDiveIDs
        )

        let contentFingerprint = HomeOverviewRefreshToken.contentFingerprint(
            dives: diveStatsInputs,
            buddyTags: buddyTags,
            sightingCount: sightingInputs.count,
            mediaCount: ownerMedia.count
        )

        let carouselFingerprint = carouselContentFingerprint(
            ownerProfileID: ownerProfileID,
            diveStatsInputs: diveStatsInputs,
            ownerMedia: ownerMedia,
            referenceDate: referenceDate
        )

        let carouselTagFingerprint = HomeOverviewRefreshToken.carouselTagFingerprint(
            sightings: mediaHighlightSightings,
            buddyTags: mediaHighlightBuddyTags,
            ownerDiveIDs: ownerDiveIDs
        )

        return HomeOverviewAggregate(
            contentFingerprint: contentFingerprint,
            carouselFingerprint: carouselFingerprint,
            carouselTagFingerprint: carouselTagFingerprint,
            diveStatsInputs: diveStatsInputs,
            lifetimeStats: lifetimeStats,
            buddyLeaderboard: buddyLeaderboard,
            ownerMediaPhotos: ownerMedia,
            mediaByID: mediaByID,
            divesByID: divesByID,
            ownerDiveIDs: ownerDiveIDs,
            mediaHighlightSightings: mediaHighlightSightings,
            mediaHighlightBuddyTags: mediaHighlightBuddyTags,
            taggedBuddyRowsByMediaID: taggedBuddyRowsByMediaID
        )
    }

    private static func ownerMediaPhotos(
        allMediaPhotos: [DiveMediaPhoto],
        ownerDiveIDs: Set<UUID>
    ) -> [DiveMediaPhoto] {
        allMediaPhotos.filter { photo in
            guard let diveID = photo.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }
    }

    private static func sightingCountInputs(
        allSightings: [SightingInstance],
        ownerDiveIDs: Set<UUID>,
        marineLifeCatalog: [MarineLife]
    ) -> [HomeLifetimeStatsPresentation.SightingCountInput] {
        let catalogByUUID = Dictionary(uniqueKeysWithValues: marineLifeCatalog.map { ($0.uuid, $0) })
        return allSightings.compactMap { sighting in
            guard let diveID = sighting.diveActivityID, ownerDiveIDs.contains(diveID) else { return nil }
            let name = sighting.marineLife?.commonName
                ?? catalogByUUID[sighting.marineLifeUUID]?.commonName
                ?? sighting.marineLifeUUID
            return HomeLifetimeStatsPresentation.SightingCountInput(
                marineLifeUUID: sighting.marineLifeUUID,
                commonName: name
            )
        }
    }

    private static func carouselContentFingerprint(
        ownerProfileID: UUID?,
        diveStatsInputs: [HomeDiveStatsInput],
        ownerMedia: [DiveMediaPhoto],
        referenceDate: Date
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(ownerProfileID)
        hasher.combine(HomeMediaHighlightPresentation.dailySeed(
            ownerProfileID: ownerProfileID ?? UUID(),
            referenceDate: referenceDate
        ))
        for dive in diveStatsInputs.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(dive.id)
            hasher.combine(dive.diveNumberLabel)
            hasher.combine(dive.siteDisplayName)
        }
        for photo in ownerMedia.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(photo.id)
            hasher.combine(photo.diveActivityID)
            hasher.combine(photo.mediaKind)
            hasher.combine(photo.photosLocalIdentifier)
        }
        return hasher.finalize()
    }
}
