import Foundation

/// One dive-media tile in the Home highlights carousel (Sendable snapshot — no **`DiveMediaPhoto`** model).
struct HomeMediaHighlight: Identifiable, Equatable, Sendable {
    let mediaID: UUID
    let diveActivityID: UUID
    let diveNumberLabel: String
    let siteDisplayName: String
    let diveSiteID: UUID?
    let taggedSpeciesCount: Int

    var id: UUID { mediaID }

    var hasTaggedSpecies: Bool { taggedSpeciesCount > 0 }

    var diveActionLabel: String {
        HomeMediaHighlightPresentation.diveActionLabel(
            diveNumberLabel: diveNumberLabel,
            siteDisplayName: siteDisplayName
        )
    }
}

/// Picks a daily-shuffled subset of dive media for the Home carousel.
enum HomeMediaHighlightPresentation {

    nonisolated static let carouselLimit = 5

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
        taggedSpeciesCountByMediaID: [UUID: Int] = [:]
    ) -> [HomeMediaHighlight] {
        let divesByID = Dictionary(uniqueKeysWithValues: dives.map { ($0.id, $0) })
        return mediaPhotos.compactMap { photo -> HomeMediaHighlight? in
            guard let diveID = photo.diveActivityID, let dive = divesByID[diveID] else { return nil }
            return HomeMediaHighlight(
                mediaID: photo.mediaID,
                diveActivityID: diveID,
                diveNumberLabel: dive.diveNumberLabel,
                siteDisplayName: dive.siteDisplayName,
                diveSiteID: dive.diveSiteID,
                taggedSpeciesCount: taggedSpeciesCountByMediaID[photo.mediaID] ?? 0
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
}

/// One sighting row for Home highlight species counts (no SwiftData models).
struct HomeMediaHighlightSightingInput: Sendable, Equatable {
    let mediaPhotoID: UUID?
    let diveActivityID: UUID?
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
