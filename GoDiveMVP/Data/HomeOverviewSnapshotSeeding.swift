import Foundation
import SwiftData

/// Sendable media fields for off-main Home aggregate work.
struct HomeOverviewMediaPhotoSeed: Sendable, Equatable {
    let id: UUID
    let diveActivityID: UUID?
    let sortOrder: Int
    let mediaKind: String
    let photosLocalIdentifier: String?
}

/// Sendable sighting fields for lifetime stats + carousel fingerprints.
struct HomeOverviewSightingSeed: Sendable, Equatable {
    let mediaPhotoID: UUID?
    let diveActivityID: UUID?
    let marineLifeUUID: String
    let commonName: String
}

/// Inputs captured on the main actor, then computed off-thread.
struct HomeOverviewBuildInput: Sendable {
    let activitySeeds: [LogbookActivitySnapshotSeed]
    let tripSeeds: [LogbookTripSnapshotSeed]
    let diveSiteIDByActivityID: [UUID: UUID?]
    /// Linked catalog / user site titles by **`diveSiteID`** (so Top Sites stats don’t fall back to **“New Dive”**).
    let linkedSiteDisplayNameByID: [UUID: String]
    let buddyTagSeeds: [HomeBuddyLeaderboardPresentation.TagInput]
    let mediaPhotoSeeds: [HomeOverviewMediaPhotoSeed]
    let sightingSeeds: [HomeOverviewSightingSeed]
    let mediaBuddyTagSeeds: [HomeMediaHighlightBuddyTagInput]
    let automaticallyRenumberDives: Bool
    let displayUnits: DiveDisplayUnitSystem
    let ownerProfileID: UUID?
    let selfBuddyID: UUID?
    let referenceDate: Date
}

/// Result of the ms-scale Home launch capture (stats + media index seeds; no JPEG objects).
struct HomeOverviewLaunchCapture: Sendable {
    let input: HomeOverviewBuildInput
    let mediaPhotoSeeds: [HomeOverviewMediaPhotoSeed]
}

/// Main-actor capture of owner dive relationships into Sendable Home build inputs.
enum HomeOverviewSnapshotSeeding {
    /// Cold-launch capture — scalar dives + denormalized buddy tags + sightings for lifetime stats
    /// (no media JPEG retain / media-buddy walks — those stay on the enrich path).
    @MainActor
    static func captureLaunch(
        activities: [DiveActivity],
        buddyRoster: [DiveBuddy],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile?,
        modelContext: ModelContext,
        commonNameByUUID: [String: String] = [:],
        referenceDate: Date = .now
    ) -> HomeOverviewLaunchCapture {
        let selfBuddyID = resolveSelfBuddyID(ownerProfile: ownerProfile, modelContext: modelContext)
        let ownerDiveIDs = Set(activities.map(\.id))
        let tripMaps = HomeDiveScalarSeeding.tripMaps(activities: activities, modelContext: modelContext)
        let siteMaps = HomeDiveScalarSeeding.siteMaps(from: activities)
        let activitySeeds = HomeDiveScalarSeeding.activitySeeds(
            from: activities,
            tripIDByActivityID: tripMaps.tripIDByActivityID
        )
        let buddyTagSeeds = HomeDiveScalarSeeding.buddyTagSeeds(
            ownerDiveIDs: ownerDiveIDs,
            activities: activities,
            buddyRoster: buddyRoster,
            modelContext: modelContext
        )
        var names = commonNameByUUID
        let sightingUUIDs = Set(
            HomeDiveScalarSeeding.fetchSightingInstances(
                ownerDiveIDs: ownerDiveIDs,
                activities: activities,
                modelContext: modelContext
            ).map(\.marineLifeUUID)
        )
        let missingNameUUIDs = sightingUUIDs.filter { uuid in
            let existing = names[uuid]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return existing.isEmpty
        }
        if !missingNameUUIDs.isEmpty {
            let resolved = MarineLifeCatalogLoader.commonNameByUUID(
                uuids: Set(missingNameUUIDs),
                modelContext: modelContext
            )
            names.merge(resolved) { _, new in new }
        }
        let sightingSeeds = HomeDiveScalarSeeding.sightingSeeds(
            ownerDiveIDs: ownerDiveIDs,
            activities: activities,
            commonNameByUUID: names,
            modelContext: modelContext
        )

        // Media index is loaded after stats paint (see **`buildLaunchAsync`**) so JPEG/relationship
        // fallback never blocks lifetime stats / Top Species / Top Buddies.
        let input = HomeOverviewBuildInput(
            activitySeeds: activitySeeds,
            tripSeeds: tripMaps.tripSeeds,
            diveSiteIDByActivityID: siteMaps.diveSiteIDByActivityID,
            linkedSiteDisplayNameByID: siteMaps.linkedSiteDisplayNameByID,
            buddyTagSeeds: buddyTagSeeds,
            mediaPhotoSeeds: [],
            sightingSeeds: sightingSeeds,
            mediaBuddyTagSeeds: [],
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            selfBuddyID: selfBuddyID,
            referenceDate: referenceDate
        )
        return HomeOverviewLaunchCapture(input: input, mediaPhotoSeeds: [])
    }

    /// Full capture on an explicit context — safe on a background **`ModelContext`** (Home enrich)
    /// or the main context. Pass a pre-resolved **`selfBuddyID`**; do not resolve profiles here.
    nonisolated static func capture(
        activities: [DiveActivity],
        commonNameByUUID: [String: String],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem,
        ownerProfileID: UUID?,
        selfBuddyID: UUID?,
        modelContext: ModelContext,
        referenceDate: Date = .now,
        buddyRoster: [DiveBuddy] = []
    ) -> HomeOverviewBuildInput {
        let ownerDiveIDs = Set(activities.map(\.id))

        // Denormalized fetches — avoid faulting every dive’s sightings / media buddy tags.
        let mediaPhotoSeeds = HomeDiveScalarSeeding.mediaPhotoSeeds(
            ownerDiveIDs: ownerDiveIDs,
            activities: activities,
            modelContext: modelContext
        )
        let sightingSeeds = HomeDiveScalarSeeding.sightingSeeds(
            ownerDiveIDs: ownerDiveIDs,
            activities: activities,
            commonNameByUUID: commonNameByUUID,
            modelContext: modelContext
        )
        let mediaBuddyTagSeeds = HomeDiveScalarSeeding.mediaBuddyTagSeeds(
            ownerDiveIDs: ownerDiveIDs,
            activities: activities,
            modelContext: modelContext
        )
        let tripMaps = HomeDiveScalarSeeding.tripMaps(activities: activities, modelContext: modelContext)
        let siteMaps = HomeDiveScalarSeeding.siteMaps(from: activities)
        let activitySeeds = HomeDiveScalarSeeding.activitySeeds(
            from: activities,
            tripIDByActivityID: tripMaps.tripIDByActivityID
        )
        let buddyTagSeeds = HomeDiveScalarSeeding.buddyTagSeeds(
            ownerDiveIDs: ownerDiveIDs,
            activities: activities,
            buddyRoster: buddyRoster,
            modelContext: modelContext
        )

        return HomeOverviewBuildInput(
            activitySeeds: activitySeeds,
            tripSeeds: tripMaps.tripSeeds,
            diveSiteIDByActivityID: siteMaps.diveSiteIDByActivityID,
            linkedSiteDisplayNameByID: siteMaps.linkedSiteDisplayNameByID,
            buddyTagSeeds: buddyTagSeeds,
            mediaPhotoSeeds: mediaPhotoSeeds,
            sightingSeeds: sightingSeeds,
            mediaBuddyTagSeeds: mediaBuddyTagSeeds,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            selfBuddyID: selfBuddyID,
            referenceDate: referenceDate
        )
    }

    /// Full capture including media / sightings / media buddy tags (tests / previews; main actor).
    @MainActor
    static func capture(
        activities: [DiveActivity],
        commonNameByUUID: [String: String],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile?,
        modelContext: ModelContext?,
        referenceDate: Date = .now,
        buddyRoster: [DiveBuddy] = []
    ) -> HomeOverviewBuildInput {
        let selfBuddyID = resolveSelfBuddyID(ownerProfile: ownerProfile, modelContext: modelContext)
        if let modelContext {
            return capture(
                activities: activities,
                commonNameByUUID: commonNameByUUID,
                automaticallyRenumberDives: automaticallyRenumberDives,
                displayUnits: displayUnits,
                ownerProfileID: ownerProfileID,
                selfBuddyID: selfBuddyID,
                modelContext: modelContext,
                referenceDate: referenceDate,
                buddyRoster: buddyRoster
            )
        }
        let ownerDiveIDs = Set(activities.map(\.id))

        var mediaSeeds: [HomeOverviewMediaPhotoSeed] = []
        var sightings: [HomeOverviewSightingSeed] = []
        var mediaBuddyTags: [HomeMediaHighlightBuddyTagInput] = []
        for activity in activities {
            for photo in activity.mediaPhotos {
                mediaSeeds.append(
                    HomeOverviewMediaPhotoSeed(
                        id: photo.id,
                        diveActivityID: photo.diveActivityID ?? activity.id,
                        sortOrder: photo.sortOrder,
                        mediaKind: photo.mediaKind,
                        photosLocalIdentifier: photo.photosLocalIdentifier
                    )
                )
            }
            for sighting in activity.marineLifeSightings {
                let uuid = sighting.marineLifeUUID
                sightings.append(
                    HomeOverviewSightingSeed(
                        mediaPhotoID: sighting.mediaPhotoID,
                        diveActivityID: sighting.diveActivityID ?? activity.id,
                        marineLifeUUID: uuid,
                        commonName: commonNameByUUID[uuid] ?? uuid
                    )
                )
            }
            for tag in activity.mediaBuddyTags {
                guard let buddyID = tag.buddyID ?? tag.buddy?.id else { continue }
                mediaBuddyTags.append(
                    HomeMediaHighlightBuddyTagInput(
                        mediaPhotoID: tag.mediaPhotoID,
                        diveActivityID: tag.diveActivityID ?? activity.id,
                        buddyID: buddyID,
                        displayName: tag.buddy?.displayName ?? "Buddy",
                        profilePhoto: tag.buddy?.profilePhoto,
                        showsGoDiveUserPin: tag.buddy.map(DiveBuddyFriendLinkPresentation.isLinkedFriend) ?? false
                    )
                )
            }
        }
        mediaSeeds.sort { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let mediaPhotoSeeds = mediaSeeds
        let sightingSeeds = sightings
        let mediaBuddyTagSeeds = mediaBuddyTags.filter { tag in
            guard let diveID = tag.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }

        // Tests / previews without a live context — fall back to legacy relationship capture.
        let tripMaps: (tripIDByActivityID: [UUID: UUID], tripSeeds: [LogbookTripSnapshotSeed]) =
            ([:], LogbookTripSnapshotSeeding.tripSeeds(from: activities))
        let siteMaps = HomeDiveScalarSeeding.siteMaps(from: activities)
        let activitySeeds = LogbookActivitySnapshotSeeding.seeds(from: activities)
        let buddyTagSeeds = HomeBuddyLeaderboardSeeding.tagInputs(from: activities)

        return HomeOverviewBuildInput(
            activitySeeds: activitySeeds,
            tripSeeds: tripMaps.tripSeeds,
            diveSiteIDByActivityID: siteMaps.diveSiteIDByActivityID,
            linkedSiteDisplayNameByID: siteMaps.linkedSiteDisplayNameByID,
            buddyTagSeeds: buddyTagSeeds,
            mediaPhotoSeeds: mediaPhotoSeeds,
            sightingSeeds: sightingSeeds,
            mediaBuddyTagSeeds: mediaBuddyTagSeeds,
            automaticallyRenumberDives: automaticallyRenumberDives,
            displayUnits: displayUnits,
            ownerProfileID: ownerProfileID,
            selfBuddyID: selfBuddyID,
            referenceDate: referenceDate
        )
    }

    @MainActor
    private static func resolveSelfBuddyID(
        ownerProfile: UserProfile?,
        modelContext: ModelContext?
    ) -> UUID? {
        guard let ownerProfile, let modelContext else { return nil }
        return DiveBuddySelfRepresentation.resolveSelfBuddyID(
            owner: ownerProfile,
            modelContext: modelContext
        )
    }
}
