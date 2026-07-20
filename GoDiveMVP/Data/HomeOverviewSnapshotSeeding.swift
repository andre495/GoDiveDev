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

/// Main-actor capture of owner dive relationships into Sendable Home build inputs.
enum HomeOverviewSnapshotSeeding {
    @MainActor
    static func capture(
        activities: [DiveActivity],
        marineLifeCatalog: [MarineLife],
        automaticallyRenumberDives: Bool,
        displayUnits: DiveDisplayUnitSystem,
        ownerProfileID: UUID?,
        ownerProfile: UserProfile?,
        modelContext: ModelContext?,
        referenceDate: Date = .now
    ) -> HomeOverviewBuildInput {
        let selfBuddyID: UUID?
        if let ownerProfile, let modelContext {
            selfBuddyID = DiveBuddySelfRepresentation.resolveSelfBuddyID(
                owner: ownerProfile,
                modelContext: modelContext
            )
        } else {
            selfBuddyID = nil
        }

        let ownerDiveIDs = Set(activities.map(\.id))
        var mediaPhotoSeeds: [HomeOverviewMediaPhotoSeed] = []
        var sightingSeeds: [HomeOverviewSightingSeed] = []
        var mediaBuddyTagSeeds: [HomeMediaHighlightBuddyTagInput] = []

        for activity in activities {
            for photo in activity.mediaPhotos {
                mediaPhotoSeeds.append(
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
                let commonName = marineLifeCatalog.first(where: { $0.uuid == sighting.marineLifeUUID })?.commonName
                    ?? sighting.marineLifeUUID
                sightingSeeds.append(
                    HomeOverviewSightingSeed(
                        mediaPhotoID: sighting.mediaPhotoID,
                        diveActivityID: sighting.diveActivityID ?? activity.id,
                        marineLifeUUID: sighting.marineLifeUUID,
                        commonName: commonName
                    )
                )
            }

            for tag in activity.mediaBuddyTags {
                guard let buddyID = tag.buddyID ?? tag.buddy?.id else { continue }
                mediaBuddyTagSeeds.append(
                    HomeMediaHighlightBuddyTagInput(
                        mediaPhotoID: tag.mediaPhotoID,
                        diveActivityID: tag.diveActivityID ?? activity.id,
                        buddyID: buddyID,
                        displayName: tag.buddy?.displayName ?? "Buddy",
                        profilePhoto: tag.buddy?.profilePhoto
                    )
                )
            }
        }

        mediaPhotoSeeds.sort { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        mediaBuddyTagSeeds = mediaBuddyTagSeeds.filter { tag in
            guard let diveID = tag.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }

        let diveSiteIDByActivityID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0.diveSiteID) })
        var linkedSiteDisplayNameByID: [UUID: String] = [:]
        for activity in activities {
            guard let siteID = activity.diveSiteID else { continue }
            if linkedSiteDisplayNameByID[siteID] != nil { continue }
            if let resolved = activity.resolvedLinkedSite,
               let name = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: resolved)
                ?? DiveSiteFormValidation.sanitizedSiteName(resolved.siteName)
            {
                linkedSiteDisplayNameByID[siteID] = name
                continue
            }
            if let imported = activity.siteName.flatMap(DiveSiteFormValidation.sanitizedSiteName)
                ?? activity.resolvedSiteName.flatMap(DiveSiteFormValidation.sanitizedSiteName)
            {
                linkedSiteDisplayNameByID[siteID] = imported
            }
        }

        return HomeOverviewBuildInput(
            activitySeeds: LogbookActivitySnapshotSeeding.seeds(from: activities),
            tripSeeds: LogbookTripSnapshotSeeding.tripSeeds(from: activities),
            diveSiteIDByActivityID: diveSiteIDByActivityID,
            linkedSiteDisplayNameByID: linkedSiteDisplayNameByID,
            buddyTagSeeds: HomeBuddyLeaderboardSeeding.tagInputs(from: activities),
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
}
