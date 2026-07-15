import Foundation
import SwiftData

/// Builds a sendable media index for **Search → Media** off the main actor.
enum GlobalSearchMediaIndexSnapshotBuilder: Sendable {

    struct CaptureInput: Sendable {
        struct DiveRow: Sendable {
            let id: UUID
            let startTime: Date
            let siteName: String?
            let activityTagNames: [String]
            let tripTitles: [String]
            let mediaPhotos: [MediaPhotoRow]
        }

        struct MediaPhotoRow: Sendable {
            let id: UUID
            let diveActivityID: UUID
            let capturedAt: Date?
            let sortOrder: Int
            let mediaKind: DiveMediaKind
        }

        struct BuddyTagRow: Sendable {
            let mediaPhotoID: UUID
            let diveActivityID: UUID
            let buddyDisplayName: String
        }

        struct SightingRow: Sendable {
            let mediaPhotoID: UUID
            let diveActivityID: UUID
            let speciesName: String
        }

        let dives: [DiveRow]
        let buddyTags: [BuddyTagRow]
        let sightings: [SightingRow]
        let catalogTagNames: [String]
        let catalogBuddyNames: [String]
        let catalogTrips: [LogbookTripSearchCatalogEntry]
        let catalogSpeciesNames: [String]
    }

    @MainActor
    static func captureInput(
        activities: [DiveActivity],
        buddyMediaTags: [DiveMediaBuddyTag],
        sightings: [SightingInstance],
        ownerTrips: [DiveTrip],
        speciesCatalog: [MarineLife],
        ownerDiveActivityIDs: Set<UUID>
    ) -> CaptureInput {
        let tripTitleByID = Dictionary(uniqueKeysWithValues: ownerTrips.map { ($0.id, $0.displayTitle) })

        let dives = activities.map { dive in
            CaptureInput.DiveRow(
                id: dive.id,
                startTime: dive.startTime,
                siteName: dive.resolvedSiteName,
                activityTagNames: dive.activityTags.map(\.name),
                tripTitles: dive.tripActivityLinks.compactMap { link in
                    guard let tripID = link.trip?.id ?? link.tripID else { return nil }
                    return tripTitleByID[tripID]
                },
                mediaPhotos: DiveActivityMediaPresentation.sortedPhotos(on: dive).map {
                    CaptureInput.MediaPhotoRow(
                        id: $0.id,
                        diveActivityID: dive.id,
                        capturedAt: $0.capturedAt,
                        sortOrder: $0.sortOrder,
                        mediaKind: $0.resolvedMediaKind
                    )
                }
            )
        }

        let speciesNameByUUID = Dictionary(
            uniqueKeysWithValues: speciesCatalog.map { ($0.uuid, $0.commonName) }
        )

        let buddyTags = buddyMediaTags.compactMap { tag -> CaptureInput.BuddyTagRow? in
            guard let activityID = tag.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let mediaPhotoID = tag.mediaPhotoID,
                  let buddyName = tag.buddy?.displayName
            else { return nil }
            return CaptureInput.BuddyTagRow(
                mediaPhotoID: mediaPhotoID,
                diveActivityID: activityID,
                buddyDisplayName: buddyName
            )
        }

        let sightingRows = sightings.compactMap { sighting -> CaptureInput.SightingRow? in
            guard let activityID = sighting.diveActivityID,
                  ownerDiveActivityIDs.contains(activityID),
                  let mediaPhotoID = sighting.mediaPhotoID
            else { return nil }

            let speciesName: String
            if let catalogName = speciesNameByUUID[sighting.marineLifeUUID] {
                speciesName = catalogName
            } else if let linked = sighting.marineLife?.commonName {
                speciesName = linked
            } else {
                return nil
            }

            return CaptureInput.SightingRow(
                mediaPhotoID: mediaPhotoID,
                diveActivityID: activityID,
                speciesName: speciesName
            )
        }

        var seenTagNames = Set<String>()
        var catalogTagNames: [String] = []
        for dive in activities {
            for name in dive.activityTags.map(\.name) {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let normalized = ActivityTagStore.normalizedName(from: trimmed)
                guard seenTagNames.insert(normalized).inserted else { continue }
                catalogTagNames.append(trimmed)
            }
        }

        var seenBuddyNames = Set<String>()
        var catalogBuddyNames: [String] = []
        for tag in buddyTags {
            let trimmed = tag.buddyDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = DiveBuddyCatalog.normalizedNameKey(trimmed)
            guard seenBuddyNames.insert(normalized).inserted else { continue }
            catalogBuddyNames.append(trimmed)
        }

        let catalogTrips = ownerTrips.map {
            LogbookTripSearchCatalogEntry(tripID: $0.id, displayTitle: $0.displayTitle)
        }

        var seenSpecies = Set<String>()
        var catalogSpeciesNames: [String] = []
        for row in sightingRows {
            let trimmed = row.speciesName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = trimmed.lowercased()
            guard seenSpecies.insert(normalized).inserted else { continue }
            catalogSpeciesNames.append(trimmed)
        }

        return CaptureInput(
            dives: dives,
            buddyTags: buddyTags,
            sightings: sightingRows,
            catalogTagNames: catalogTagNames.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            },
            catalogBuddyNames: catalogBuddyNames.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            },
            catalogTrips: catalogTrips.sorted {
                $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
            },
            catalogSpeciesNames: catalogSpeciesNames.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        )
    }

    nonisolated static func build(from input: CaptureInput) -> GlobalSearchMediaBrowsePresentation.IndexSnapshot {
        var buddyNamesByMediaID: [UUID: [String]] = [:]
        for tag in input.buddyTags {
            buddyNamesByMediaID[tag.mediaPhotoID, default: []].append(tag.buddyDisplayName)
        }

        var speciesNamesByMediaID: [UUID: [String]] = [:]
        for sighting in input.sightings {
            speciesNamesByMediaID[sighting.mediaPhotoID, default: []].append(sighting.speciesName)
        }

        var entries: [GlobalSearchMediaBrowsePresentation.MediaEntry] = []
        let sortedDives = input.dives.sorted { lhs, rhs in
            if lhs.startTime != rhs.startTime { return lhs.startTime > rhs.startTime }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        for dive in sortedDives {
            let sortedPhotos = dive.mediaPhotos.sorted { lhs, rhs in
                switch (lhs.capturedAt, rhs.capturedAt) {
                case let (left?, right?):
                    if left != right { return left < right }
                case (nil, .some):
                    return false
                case (.some, nil):
                    return true
                case (nil, nil):
                    break
                }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            for photo in sortedPhotos {
                let buddyNames = buddyNamesByMediaID[photo.id] ?? []
                let speciesNames = speciesNamesByMediaID[photo.id] ?? []
                entries.append(
                    GlobalSearchMediaBrowsePresentation.MediaEntry(
                        mediaID: photo.id,
                        diveActivityID: photo.diveActivityID,
                        diveStartTime: dive.startTime,
                        capturedAt: photo.capturedAt,
                        sortOrder: photo.sortOrder,
                        mediaKind: photo.mediaKind,
                        siteName: dive.siteName,
                        activityTagNames: dive.activityTagNames,
                        mediaBuddyNames: buddyNames,
                        tripTitles: dive.tripTitles,
                        speciesNames: speciesNames,
                        hasMarineLifeTag: !speciesNames.isEmpty,
                        hasBuddyTag: !buddyNames.isEmpty
                    )
                )
            }
        }

        return GlobalSearchMediaBrowsePresentation.IndexSnapshot(
            entries: entries,
            catalogTagNames: input.catalogTagNames,
            catalogBuddyNames: input.catalogBuddyNames,
            catalogTrips: input.catalogTrips,
            catalogSpeciesNames: input.catalogSpeciesNames
        )
    }
}
