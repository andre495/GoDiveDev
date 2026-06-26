import Foundation

/// One dive-media tile in the Home highlights carousel (Sendable snapshot — no **`DiveMediaPhoto`** model).
struct HomeMediaHighlight: Identifiable, Equatable, Sendable {
    let mediaID: UUID
    let diveActivityID: UUID
    let diveNumberLabel: String
    let siteDisplayName: String
    let diveSiteID: UUID?
    let linkedTripTitle: String?
    let linkedTripAccentColorIndex: Int?
    let taggedSpeciesCount: Int
    let taggedBuddyCount: Int

    var id: UUID { mediaID }

    var hasTaggedSpecies: Bool { taggedSpeciesCount > 0 }

    var hasTaggedBuddies: Bool { taggedBuddyCount > 0 }

    var showsLinkedTrip: Bool {
        guard let linkedTripTitle else { return false }
        return !linkedTripTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var diveActionLabel: String {
        HomeMediaHighlightPresentation.diveActionLabel(
            diveNumberLabel: diveNumberLabel,
            siteDisplayName: siteDisplayName
        )
    }

    init(
        mediaID: UUID,
        diveActivityID: UUID,
        diveNumberLabel: String,
        siteDisplayName: String,
        diveSiteID: UUID?,
        linkedTripTitle: String? = nil,
        linkedTripAccentColorIndex: Int? = nil,
        taggedSpeciesCount: Int,
        taggedBuddyCount: Int
    ) {
        self.mediaID = mediaID
        self.diveActivityID = diveActivityID
        self.diveNumberLabel = diveNumberLabel
        self.siteDisplayName = siteDisplayName
        self.diveSiteID = diveSiteID
        self.linkedTripTitle = linkedTripTitle
        self.linkedTripAccentColorIndex = linkedTripAccentColorIndex
        self.taggedSpeciesCount = taggedSpeciesCount
        self.taggedBuddyCount = taggedBuddyCount
    }
}

/// Picks a daily-shuffled subset of dive media for the Home carousel.
enum HomeMediaHighlightPresentation {

    nonisolated static let carouselLimit = 3

    /// Videos longer than this are excluded from the daily carousel shuffle (startup + playback cost).
    nonisolated static let carouselVideoMaxDurationSeconds: Double = 30

    nonisolated static func isEligibleCarouselSource(_ source: HomeMediaHighlightSource) -> Bool {
        guard source.mediaKind == .video else { return true }
        guard let duration = source.videoDurationSeconds, duration > 0 else { return true }
        return duration <= carouselVideoMaxDurationSeconds
    }

    nonisolated static func dailySeed(ownerProfileID: UUID, referenceDate: Date = .now) -> UInt64 {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.ordinality(of: .day, in: .year, for: referenceDate) ?? 0
        let year = calendar.component(.year, from: referenceDate)
        var hasher = Hasher()
        hasher.combine(ownerProfileID)
        hasher.combine(year)
        hasher.combine(day)
        return UInt64(bitPattern: Int64(truncatingIfNeeded: hasher.finalize()))
    }

    nonisolated static func randomizedHighlights(
        from candidates: [HomeMediaHighlight],
        limit: Int = carouselLimit,
        seed: UInt64
    ) -> [HomeMediaHighlight] {
        guard !candidates.isEmpty else { return [] }
        var generator = HomeSeededRandomNumberGenerator(seed: seed == 0 ? 0xDEAD_BEEF : seed)
        return Array(candidates.shuffled(using: &generator).prefix(limit))
    }

    /// Builds carousel candidates from owned media + dive labels (testable without SwiftData).
    nonisolated static func buildCandidates(
        mediaPhotos: [HomeMediaHighlightSource],
        dives: [HomeDiveStatsInput],
        taggedSpeciesCountByMediaID: [UUID: Int] = [:],
        taggedBuddyCountByMediaID: [UUID: Int] = [:]
    ) -> [HomeMediaHighlight] {
        let divesByID = Dictionary(uniqueKeysWithValues: dives.map { ($0.id, $0) })
        return mediaPhotos
            .filter(isEligibleCarouselSource)
            .compactMap { photo -> HomeMediaHighlight? in
            guard let diveID = photo.diveActivityID, let dive = divesByID[diveID] else { return nil }
            return HomeMediaHighlight(
                mediaID: photo.mediaID,
                diveActivityID: diveID,
                diveNumberLabel: dive.diveNumberLabel,
                siteDisplayName: dive.siteDisplayName,
                diveSiteID: dive.diveSiteID,
                linkedTripTitle: dive.linkedTripTitle,
                linkedTripAccentColorIndex: dive.linkedTripAccentColorIndex,
                taggedSpeciesCount: taggedSpeciesCountByMediaID[photo.mediaID] ?? 0,
                taggedBuddyCount: taggedBuddyCountByMediaID[photo.mediaID] ?? 0
            )
        }
    }

    /// Refreshes tag counts on an existing carousel pick without reshuffling slides.
    nonisolated static func highlightsByRefreshingTagCounts(
        _ highlights: [HomeMediaHighlight],
        taggedSpeciesCountByMediaID: [UUID: Int],
        taggedBuddyCountByMediaID: [UUID: Int]
    ) -> [HomeMediaHighlight] {
        highlights.map { highlight in
            HomeMediaHighlight(
                mediaID: highlight.mediaID,
                diveActivityID: highlight.diveActivityID,
                diveNumberLabel: highlight.diveNumberLabel,
                siteDisplayName: highlight.siteDisplayName,
                diveSiteID: highlight.diveSiteID,
                linkedTripTitle: highlight.linkedTripTitle,
                linkedTripAccentColorIndex: highlight.linkedTripAccentColorIndex,
                taggedSpeciesCount: taggedSpeciesCountByMediaID[highlight.mediaID] ?? 0,
                taggedBuddyCount: taggedBuddyCountByMediaID[highlight.mediaID] ?? 0
            )
        }
    }

    /// Counts sighting rows per media photo for owned dives (supports multiple tags on one photo).
    nonisolated static func taggedSpeciesCountByMediaID(
        sightings: [HomeMediaHighlightSightingInput],
        ownerDiveIDs: Set<UUID>
    ) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for sighting in sightings {
            guard let mediaID = sighting.mediaPhotoID,
                  let diveID = sighting.diveActivityID,
                  ownerDiveIDs.contains(diveID) else { continue }
            counts[mediaID, default: 0] += 1
        }
        return counts
    }

    /// Counts media buddy-tag rows per photo for owned dives.
    nonisolated static func taggedBuddyCountByMediaID(
        buddyTags: [HomeMediaHighlightBuddyTagInput],
        ownerDiveIDs: Set<UUID>
    ) -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for tag in buddyTags {
            guard let mediaID = tag.mediaPhotoID,
                  let diveID = tag.diveActivityID,
                  ownerDiveIDs.contains(diveID) else { continue }
            counts[mediaID, default: 0] += 1
        }
        return counts
    }

    /// Unique tagged buddies per carousel photo (sorted by display name).
    nonisolated static func taggedBuddyRowsByMediaID(
        buddyTags: [HomeMediaHighlightBuddyTagInput],
        ownerDiveIDs: Set<UUID>
    ) -> [UUID: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]] {
        var rowsByMediaID: [UUID: [DiveMediaBuddyTagPresentation.TaggedBuddyRow]] = [:]
        var seenBuddyIDsByMediaID: [UUID: Set<UUID>] = [:]

        for tag in buddyTags {
            guard let mediaID = tag.mediaPhotoID,
                  let diveID = tag.diveActivityID,
                  ownerDiveIDs.contains(diveID),
                  let buddyID = tag.buddyID else { continue }
            guard seenBuddyIDsByMediaID[mediaID, default: []].insert(buddyID).inserted else { continue }
            rowsByMediaID[mediaID, default: []].append(
                DiveMediaBuddyTagPresentation.TaggedBuddyRow(
                    buddyID: buddyID,
                    displayName: tag.displayName,
                    profilePhoto: tag.profilePhoto
                )
            )
        }

        for mediaID in rowsByMediaID.keys {
            rowsByMediaID[mediaID]?.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
        return rowsByMediaID
    }

    /// Logbook-style **#** label for carousel chips (matches **`DiveLogbookDisplay`** rules).
    nonisolated static func diveNumberLabel(
        diveNumber: Int?,
        diveNumberExplicitlyNone: Bool,
        chronologicalIndex: Int?,
        useChronologicalNumbers: Bool
    ) -> String {
        if diveNumberExplicitlyNone { return "-" }
        if useChronologicalNumbers, let chronologicalIndex {
            return "#\(chronologicalIndex)"
        }
        if let diveNumber {
            return "#\(diveNumber)"
        }
        return "-"
    }

    /// Action chip copy: **`<dive number> <site name>`** (e.g. **`#12 Salt Pier`**).
    nonisolated static func diveActionLabel(diveNumberLabel: String, siteDisplayName: String) -> String {
        let number = diveNumberLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let site = siteDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSite = site.isEmpty ? "New Dive" : site
        guard !number.isEmpty, number != "-" else { return resolvedSite }
        return "\(number) \(resolvedSite)"
    }

    nonisolated static func highlightsForOwner(
        ownerProfileID: UUID,
        candidates: [HomeMediaHighlight],
        referenceDate: Date = .now
    ) -> [HomeMediaHighlight] {
        let seed = dailySeed(ownerProfileID: ownerProfileID, referenceDate: referenceDate)
        return randomizedHighlights(from: candidates, seed: seed)
    }
}

/// One owned media row for highlight building (no **`DiveMediaPhoto`** model).
struct HomeMediaHighlightSource: Sendable, Equatable {
    let mediaID: UUID
    let diveActivityID: UUID?
    var mediaKind: DiveMediaKind = .image
    /// Photos **`PHAsset.duration`** when **`mediaKind == .video`**; **`nil`** for photos / unknown.
    var videoDurationSeconds: Double? = nil
}

/// One sighting row for Home highlight species counts (no SwiftData models).
struct HomeMediaHighlightSightingInput: Sendable, Equatable {
    let mediaPhotoID: UUID?
    let diveActivityID: UUID?
}

/// One media buddy-tag row for Home highlight buddy counts (no SwiftData models).
struct HomeMediaHighlightBuddyTagInput: Sendable, Equatable {
    let mediaPhotoID: UUID?
    let diveActivityID: UUID?
    var buddyID: UUID? = nil
    var displayName: String = "Buddy"
    var profilePhoto: Data? = nil
}

/// Deterministic shuffle for carousel picks (stable for a given seed / day).
struct HomeSeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    nonisolated init(seed: UInt64) {
        state = seed
    }

    nonisolated mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
