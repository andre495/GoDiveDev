import Foundation

/// Off-main Home aggregate computation — no SwiftData models.
struct HomeOverviewComputedResult: Sendable {
    let contentFingerprint: Int
    let carouselFingerprint: Int
    let carouselTagFingerprint: Int
    let diveStatsInputs: [HomeDiveStatsInput]
    let sightingCountInputs: [HomeLifetimeStatsPresentation.SightingCountInput]
    let lifetimeStats: HomeLifetimeStats
    let buddyLeaderboard: [HomeBuddyLeaderboardEntry]
    let ownerMediaPhotoIDs: [UUID]
    let ownerDiveIDs: Set<UUID>
    let mediaHighlightSightings: [HomeMediaHighlightSightingInput]
    let mediaHighlightBuddyTags: [HomeMediaHighlightBuddyTagInput]
    let taggedBuddyRowsByMediaID: [UUID: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]]
}

enum HomeOverviewAggregateComputer {
    nonisolated static func build(from input: HomeOverviewBuildInput) -> HomeOverviewComputedResult {
        let ownerDiveIDs = Set(input.activitySeeds.map(\.id))
        let tripTitleByID = Dictionary(uniqueKeysWithValues: input.tripSeeds.map { ($0.tripID, $0.displayTitle) })
        let tripAccentIndexByID = LogbookTripGroupAccentPresentation.accentColorIndexByTripID(
            seeds: input.activitySeeds,
            tripSeeds: input.tripSeeds,
            unitSystem: input.displayUnits,
            useChronologicalNumbers: input.automaticallyRenumberDives
        )

        let chronologicalNumbers: [UUID: Int] = input.automaticallyRenumberDives
            ? DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(
                for: input.activitySeeds.map(\.numberingRow)
            )
            : [:]

        let diveStatsInputs = input.activitySeeds.map { seed in
            let linkedTripID = seed.linkedTripID
            return HomeDiveStatsInput(
                id: seed.id,
                maxDepthMeters: seed.maxDepthMeters,
                durationMinutes: seed.durationMinutes,
                diveSiteID: input.diveSiteIDByActivityID[seed.id] ?? nil,
                diveNumberLabel: homeDiveNumberLabel(
                    for: seed,
                    chronologicalNumbers: chronologicalNumbers,
                    useChronologicalNumbers: input.automaticallyRenumberDives
                ),
                siteDisplayName: seed.displayName,
                linkedTripID: linkedTripID,
                linkedTripTitle: linkedTripID.flatMap { tripTitleByID[$0] },
                linkedTripAccentColorIndex: linkedTripID.flatMap { tripAccentIndexByID[$0] }
            )
        }

        let sightingCountInputs = input.sightingSeeds.compactMap { sighting -> HomeLifetimeStatsPresentation.SightingCountInput? in
            guard let diveID = sighting.diveActivityID, ownerDiveIDs.contains(diveID) else { return nil }
            return HomeLifetimeStatsPresentation.SightingCountInput(
                marineLifeUUID: sighting.marineLifeUUID,
                commonName: sighting.commonName
            )
        }

        let ownerMediaPhotoIDs = input.mediaPhotoSeeds
            .filter { seed in
                guard let diveID = seed.diveActivityID else { return false }
                return ownerDiveIDs.contains(diveID)
            }
            .map(\.id)

        let lifetimeStats = HomeLifetimeStatsPresentation.build(
            dives: diveStatsInputs,
            sightings: sightingCountInputs
        )

        let buddyLeaderboard = HomeBuddyLeaderboardPresentation.topEntries(
            from: input.buddyTagSeeds,
            excludingBuddyID: input.selfBuddyID
        )

        let mediaHighlightSightings = input.sightingSeeds.compactMap { sighting -> HomeMediaHighlightSightingInput? in
            guard let diveID = sighting.diveActivityID, ownerDiveIDs.contains(diveID) else { return nil }
            return HomeMediaHighlightSightingInput(
                mediaPhotoID: sighting.mediaPhotoID,
                diveActivityID: diveID
            )
        }

        let mediaHighlightBuddyTags = input.mediaBuddyTagSeeds.filter { tag in
            guard let diveID = tag.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }

        let taggedBuddyRowsByMediaID = HomeMediaHighlightPresentation.taggedBuddyRowsByMediaID(
            buddyTags: mediaHighlightBuddyTags,
            ownerDiveIDs: ownerDiveIDs
        )

        let contentFingerprint = HomeOverviewRefreshToken.contentFingerprint(
            dives: diveStatsInputs,
            buddyTags: input.buddyTagSeeds,
            sightingCount: sightingCountInputs.count,
            mediaCount: ownerMediaPhotoIDs.count
        )

        let carouselFingerprint = carouselContentFingerprint(
            ownerProfileID: input.ownerProfileID,
            diveStatsInputs: diveStatsInputs,
            mediaPhotoSeeds: input.mediaPhotoSeeds.filter { seed in
                guard let diveID = seed.diveActivityID else { return false }
                return ownerDiveIDs.contains(diveID)
            },
            referenceDate: input.referenceDate
        )

        let carouselTagFingerprint = HomeOverviewRefreshToken.carouselTagFingerprint(
            sightings: mediaHighlightSightings,
            buddyTags: mediaHighlightBuddyTags,
            ownerDiveIDs: ownerDiveIDs
        )

        return HomeOverviewComputedResult(
            contentFingerprint: contentFingerprint,
            carouselFingerprint: carouselFingerprint,
            carouselTagFingerprint: carouselTagFingerprint,
            diveStatsInputs: diveStatsInputs,
            sightingCountInputs: sightingCountInputs,
            lifetimeStats: lifetimeStats,
            buddyLeaderboard: buddyLeaderboard,
            ownerMediaPhotoIDs: ownerMediaPhotoIDs,
            ownerDiveIDs: ownerDiveIDs,
            mediaHighlightSightings: mediaHighlightSightings,
            mediaHighlightBuddyTags: mediaHighlightBuddyTags,
            taggedBuddyRowsByMediaID: taggedBuddyRowsByMediaID
        )
    }

    nonisolated private static func homeDiveNumberLabel(
        for seed: LogbookActivitySnapshotSeed,
        chronologicalNumbers: [UUID: Int],
        useChronologicalNumbers: Bool
    ) -> String {
        HomeMediaHighlightPresentation.diveNumberLabel(
            diveNumber: seed.diveNumber,
            diveNumberExplicitlyNone: seed.diveNumberExplicitlyNone,
            chronologicalIndex: chronologicalNumbers[seed.id],
            useChronologicalNumbers: useChronologicalNumbers
        )
    }

    nonisolated private static func carouselContentFingerprint(
        ownerProfileID: UUID?,
        diveStatsInputs: [HomeDiveStatsInput],
        mediaPhotoSeeds: [HomeOverviewMediaPhotoSeed],
        referenceDate: Date
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(ownerProfileID)
        hasher.combine(HomeMediaHighlightPresentation.carouselShuffleSeed(
            ownerProfileID: ownerProfileID ?? UUID(),
            referenceDate: referenceDate
        ))
        for dive in diveStatsInputs.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(dive.id)
            hasher.combine(dive.diveNumberLabel)
            hasher.combine(dive.siteDisplayName)
            hasher.combine(dive.linkedTripID)
            hasher.combine(dive.linkedTripTitle)
            hasher.combine(dive.linkedTripAccentColorIndex)
        }
        for photo in mediaPhotoSeeds.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(photo.id)
            hasher.combine(photo.diveActivityID)
            hasher.combine(photo.mediaKind)
            hasher.combine(photo.photosLocalIdentifier)
        }
        return hasher.finalize()
    }
}
