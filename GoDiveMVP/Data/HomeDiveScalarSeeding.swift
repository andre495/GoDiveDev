import Foundation
import SwiftData

/// Home launch seeds — scalars / denormalized ids only (no media, buddy, tag, or site-resolve faults).
/// `nonisolated` — callers pass the `ModelContext` (main or background) that owns the rows.
enum HomeDiveScalarSeeding {

    /// Builds **`LogbookActivitySnapshotSeed`** rows for Home without walking logbook relationships.
    nonisolated static func activitySeeds(
        from activities: [DiveActivity],
        tripIDByActivityID: [UUID: UUID]
    ) -> [LogbookActivitySnapshotSeed] {
        activities.map { activity in
            let rawSite = activity.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let siteName = rawSite.isEmpty ? nil : DiveSiteFormValidation.sanitizedSiteName(rawSite) ?? rawSite
            let displayName = LogbookActivityRow.displayName(resolvedSiteName: siteName)
            return LogbookActivitySnapshotSeed(
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
                displayName: displayName,
                formattedStartDateOnly: activity.formattedStartDateOnly(),
                resolvedSiteNameLowercased: siteName?.lowercased(),
                activityTagNames: [],
                buddyDisplayNames: [],
                previewMediaPhotoID: activity.featuredMediaPhotoID,
                linkedTripID: tripIDByActivityID[activity.id],
                previewMediaIsSnorkel: false
            )
        }
    }

    /// Site id map + display names from denormalized **`siteName`** / **`diveSiteID`** only.
    nonisolated static func siteMaps(
        from activities: [DiveActivity]
    ) -> (diveSiteIDByActivityID: [UUID: UUID?], linkedSiteDisplayNameByID: [UUID: String]) {
        let diveSiteIDByActivityID = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0.diveSiteID) })
        var linkedSiteDisplayNameByID: [UUID: String] = [:]
        for activity in activities {
            guard let siteID = activity.diveSiteID else { continue }
            if linkedSiteDisplayNameByID[siteID] != nil { continue }
            let rawSite = activity.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !rawSite.isEmpty, let name = DiveSiteFormValidation.sanitizedSiteName(rawSite) {
                linkedSiteDisplayNameByID[siteID] = name
            }
        }
        return (diveSiteIDByActivityID, linkedSiteDisplayNameByID)
    }

    /// Denormalized trip links + trip title seeds (no **`link.trip`** relationship fault per dive).
    nonisolated static func tripMaps(
        activities: [DiveActivity],
        modelContext: ModelContext
    ) -> (tripIDByActivityID: [UUID: UUID], tripSeeds: [LogbookTripSnapshotSeed]) {
        let ownerDiveIDs = Set(activities.map(\.id))
        guard !ownerDiveIDs.isEmpty else { return ([:], []) }

        let diveIDList = Array(ownerDiveIDs)
        let linkDescriptor = FetchDescriptor<DiveTripActivityLink>(
            predicate: #Predicate<DiveTripActivityLink> { link in
                link.diveActivityID != nil && diveIDList.contains(link.diveActivityID!)
            }
        )
        let links = (try? modelContext.fetch(linkDescriptor)) ?? []

        var tripIDsByDive: [UUID: Set<UUID>] = [:]
        var allTripIDs: Set<UUID> = []
        for link in links {
            guard let diveID = link.diveActivityID, ownerDiveIDs.contains(diveID),
                  let tripID = link.tripID else { continue }
            tripIDsByDive[diveID, default: []].insert(tripID)
            allTripIDs.insert(tripID)
        }

        let tripIDList = Array(allTripIDs)
        var tripsByID: [UUID: DiveTrip] = [:]
        if !tripIDList.isEmpty {
            let tripDescriptor = FetchDescriptor<DiveTrip>(
                predicate: #Predicate<DiveTrip> { trip in
                    tripIDList.contains(trip.id)
                }
            )
            for trip in (try? modelContext.fetch(tripDescriptor)) ?? [] {
                tripsByID[trip.id] = trip
            }
        }

        var tripIDByActivityID: [UUID: UUID] = [:]
        for (diveID, tripIDs) in tripIDsByDive {
            let primary = tripIDs.compactMap { tripsByID[$0] }.max(by: { lhs, rhs in
                if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
                return lhs.createdAt < rhs.createdAt
            })
            if let primary {
                tripIDByActivityID[diveID] = primary.id
            } else if let any = tripIDs.first {
                tripIDByActivityID[diveID] = any
            }
        }

        let tripSeeds = tripsByID.values.map { trip in
            LogbookTripSnapshotSeed(
                tripID: trip.id,
                displayTitle: trip.displayTitle,
                startDate: trip.startDate,
                endDate: trip.endDate
            )
        }
        return (tripIDByActivityID, tripSeeds)
    }

    /// Buddy leaderboard inputs from denormalized **`DiveBuddyTag`** rows + roster (no per-dive **`buddies`** fault).
    /// Falls back to relationship walk when older / CloudKit rows omit **`diveActivityID`**.
    nonisolated static func buddyTagSeeds(
        ownerDiveIDs: Set<UUID>,
        activities: [DiveActivity],
        buddyRoster: [DiveBuddy],
        modelContext: ModelContext
    ) -> [HomeBuddyLeaderboardPresentation.TagInput] {
        guard !ownerDiveIDs.isEmpty else { return [] }
        let diveIDList = Array(ownerDiveIDs)
        let descriptor = FetchDescriptor<DiveBuddyTag>(
            predicate: #Predicate<DiveBuddyTag> { tag in
                tag.diveActivityID != nil && diveIDList.contains(tag.diveActivityID!)
            }
        )
        let tags = (try? modelContext.fetch(descriptor)) ?? []
        let buddyByID = Dictionary(uniqueKeysWithValues: buddyRoster.map { ($0.id, $0) })

        let fromDenormalized = tags.compactMap { tag -> HomeBuddyLeaderboardPresentation.TagInput? in
            guard let diveID = tag.diveActivityID, ownerDiveIDs.contains(diveID),
                  let buddyID = tag.buddyID ?? tag.buddy?.id else { return nil }
            let buddy = buddyByID[buddyID] ?? tag.buddy
            let legacy = tag.legacyDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name: String = {
                let fromBuddy = buddy?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !fromBuddy.isEmpty { return fromBuddy }
                if !legacy.isEmpty { return legacy }
                return "Buddy"
            }()
            return HomeBuddyLeaderboardPresentation.TagInput(
                buddyID: buddyID,
                displayName: name,
                profilePhoto: buddy?.profilePhoto,
                diveActivityID: diveID,
                showsGoDiveUserPin: buddy.map(DiveBuddyFriendLinkPresentation.isLinkedFriend) ?? false
            )
        }
        if !fromDenormalized.isEmpty {
            return fromDenormalized
        }

        // Legacy / CloudKit rows often omit denormalized diveActivityID — recover via relationship.
        return HomeBuddyLeaderboardSeeding.tagInputs(from: activities)
    }

    /// Lightweight media index — copies scalar fields only; does not retain **`DiveMediaPhoto`** (avoids holding JPEG blobs).
    /// Prefers denormalized **`diveActivityID`**; falls back to relationship walk when older rows lack that id.
    nonisolated static func mediaPhotoSeeds(
        ownerDiveIDs: Set<UUID>,
        activities: [DiveActivity],
        modelContext: ModelContext
    ) -> [HomeOverviewMediaPhotoSeed] {
        guard !ownerDiveIDs.isEmpty else { return [] }
        let diveIDList = Array(ownerDiveIDs)
        var descriptor = FetchDescriptor<DiveMediaPhoto>(
            predicate: #Predicate<DiveMediaPhoto> { photo in
                photo.diveActivityID != nil && diveIDList.contains(photo.diveActivityID!)
            },
            sortBy: [
                SortDescriptor(\.sortOrder),
                SortDescriptor(\.id),
            ]
        )
        // Index-only fetch — never load `previewJPEGData` blobs for the media index.
        descriptor.propertiesToFetch = [
            \.id, \.sortOrder, \.mediaKind, \.photosLocalIdentifier, \.diveActivityID,
        ]
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        var seedsByID: [UUID: HomeOverviewMediaPhotoSeed] = [:]
        for photo in rows {
            guard let diveID = photo.diveActivityID, ownerDiveIDs.contains(diveID) else { continue }
            seedsByID[photo.id] = mediaSeed(from: photo, diveActivityID: diveID)
        }

        // Legacy / CloudKit rows often omit denormalized diveActivityID — recover via relationship.
        if seedsByID.isEmpty {
            for activity in activities where ownerDiveIDs.contains(activity.id) {
                for photo in activity.mediaPhotos {
                    let diveID = photo.diveActivityID ?? activity.id
                    seedsByID[photo.id] = mediaSeed(from: photo, diveActivityID: diveID)
                }
            }
        }

        return seedsByID.values.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    nonisolated private static func mediaSeed(
        from photo: DiveMediaPhoto,
        diveActivityID: UUID
    ) -> HomeOverviewMediaPhotoSeed {
        let localID = photo.photosLocalIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return HomeOverviewMediaPhotoSeed(
            id: photo.id,
            diveActivityID: diveActivityID,
            sortOrder: photo.sortOrder,
            mediaKind: photo.mediaKind,
            photosLocalIdentifier: localID.isEmpty ? nil : localID
        )
    }

    /// Sighting seeds from denormalized **`SightingInstance`** rows (no per-dive relationship walk).
    nonisolated static func sightingSeeds(
        ownerDiveIDs: Set<UUID>,
        activities: [DiveActivity],
        commonNameByUUID: [String: String],
        modelContext: ModelContext
    ) -> [HomeOverviewSightingSeed] {
        fetchSightingInstances(
            ownerDiveIDs: ownerDiveIDs,
            activities: activities,
            modelContext: modelContext
        ).map { sighting in
            let uuid = sighting.marineLifeUUID
            let diveID = sighting.diveActivityID
                ?? activities.first(where: { activity in
                    activity.marineLifeSightings.contains(where: { $0.sightingUUID == sighting.sightingUUID })
                })?.id
            return HomeOverviewSightingSeed(
                mediaPhotoID: sighting.mediaPhotoID,
                diveActivityID: diveID,
                marineLifeUUID: uuid,
                commonName: commonNameByUUID[uuid] ?? uuid
            )
        }
    }

    /// Owner sighting models via denormalized fetch (relationship fallback when IDs missing).
    /// Prefer this over walking **`activity.marineLifeSightings`** after aggregate compute.
    nonisolated static func fetchSightingInstances(
        ownerDiveIDs: Set<UUID>,
        activities: [DiveActivity],
        modelContext: ModelContext
    ) -> [SightingInstance] {
        guard !ownerDiveIDs.isEmpty else { return [] }
        let diveIDList = Array(ownerDiveIDs)
        let descriptor = FetchDescriptor<SightingInstance>(
            predicate: #Predicate<SightingInstance> { sighting in
                sighting.diveActivityID != nil && diveIDList.contains(sighting.diveActivityID!)
            }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        let filtered = rows.filter { sighting in
            guard let diveID = sighting.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }
        if !filtered.isEmpty { return filtered }

        var fallback: [SightingInstance] = []
        for activity in activities where ownerDiveIDs.contains(activity.id) {
            fallback.append(contentsOf: activity.marineLifeSightings)
        }
        return fallback
    }

    /// Media buddy-tag seeds from denormalized rows (no per-dive **`mediaBuddyTags`** walk).
    nonisolated static func mediaBuddyTagSeeds(
        ownerDiveIDs: Set<UUID>,
        activities: [DiveActivity],
        modelContext: ModelContext
    ) -> [HomeMediaHighlightBuddyTagInput] {
        guard !ownerDiveIDs.isEmpty else { return [] }
        let diveIDList = Array(ownerDiveIDs)
        let descriptor = FetchDescriptor<DiveMediaBuddyTag>(
            predicate: #Predicate<DiveMediaBuddyTag> { tag in
                tag.diveActivityID != nil && diveIDList.contains(tag.diveActivityID!)
            }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        var seeds: [HomeMediaHighlightBuddyTagInput] = rows.compactMap { tag in
            guard let diveID = tag.diveActivityID, ownerDiveIDs.contains(diveID),
                  let buddyID = tag.buddyID ?? tag.buddy?.id else { return nil }
            return HomeMediaHighlightBuddyTagInput(
                mediaPhotoID: tag.mediaPhotoID,
                diveActivityID: diveID,
                buddyID: buddyID,
                displayName: tag.buddy?.displayName ?? "Buddy",
                profilePhoto: tag.buddy?.profilePhoto,
                showsGoDiveUserPin: tag.buddy.map(DiveBuddyFriendLinkPresentation.isLinkedFriend) ?? false
            )
        }
        if !seeds.isEmpty { return seeds }

        for activity in activities where ownerDiveIDs.contains(activity.id) {
            for tag in activity.mediaBuddyTags {
                guard let buddyID = tag.buddyID ?? tag.buddy?.id else { continue }
                seeds.append(
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
        return seeds.filter { tag in
            guard let diveID = tag.diveActivityID else { return false }
            return ownerDiveIDs.contains(diveID)
        }
    }

    /// Full-row fetch (includes **`previewJPEGData`**) — carousel picks only; keep id lists small.
    nonisolated static func fetchMediaPhotos(
        ids: [UUID],
        modelContext: ModelContext
    ) -> [DiveMediaPhoto] {
        guard !ids.isEmpty else { return [] }
        let idList = ids
        let descriptor = FetchDescriptor<DiveMediaPhoto>(
            predicate: #Predicate<DiveMediaPhoto> { photo in
                idList.contains(photo.id)
            }
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }
}
