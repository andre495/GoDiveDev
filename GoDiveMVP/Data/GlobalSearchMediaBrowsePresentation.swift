import Foundation

/// Cross-log media browse opened from **Search → Media** — filters like every other search category: the typed query
/// matches media across all of its fields (site name, tagged buddies, activity tags, trip titles, tagged species).
enum GlobalSearchMediaBrowsePresentation: Sendable {

    nonisolated static let loadingPageTitle = "Media"
    nonisolated static let emptyLibraryMessage = "No photos or videos in your log yet."
    nonisolated static let emptyFilterMessage = "No media matches your search."
    nonisolated static let rootAccessibilityIdentifier = "GlobalSearch.MediaBrowse.Root"
    nonisolated static let searchFieldAccessibilityIdentifier = "GlobalSearch.MediaBrowse.SearchField"

    /// Collapsed layout for the **Media** section inside general search results — a 3-wide grid capped
    /// at two rows; anything beyond is revealed with an **Expand** chevron (grid grows in place).
    enum ResultsSectionGrid {
        nonisolated static let columnCount = 3
        nonisolated static let collapsedRowLimit = 2
        nonisolated static let collapsedItemLimit = columnCount * collapsedRowLimit

        /// How many thumbnails to render given the total match count and expand state.
        nonisolated static func visibleCount(total: Int, isExpanded: Bool) -> Int {
            guard total > 0 else { return 0 }
            if isExpanded { return total }
            return min(total, collapsedItemLimit)
        }

        /// The **Expand / Collapse** control only appears when there are more matches than fit in the
        /// two-row collapsed grid.
        nonisolated static func showsExpandControl(total: Int) -> Bool {
            total > collapsedItemLimit
        }

        /// Number of matches hidden while collapsed (for the "Expand (N more)" affordance).
        nonisolated static func hiddenCount(total: Int) -> Int {
            max(total - collapsedItemLimit, 0)
        }
    }

    struct ResolvedFilter: Equatable, Sendable {
        var query: String = ""

        nonisolated var isActive: Bool {
            DiveLogbookSiteSearch.isFiltering(query: query)
        }
    }

    struct MediaEntry: Sendable, Equatable, Identifiable {
        let mediaID: UUID
        let diveActivityID: UUID
        let capturedAt: Date?
        let sortOrder: Int
        let mediaKind: DiveMediaKind
        let siteName: String?
        let activityTagNames: [String]
        let mediaBuddyNames: [String]
        let tripTitles: [String]
        let speciesNames: [String]

        var id: UUID { mediaID }
    }

    struct MediaKindCounts: Equatable, Sendable {
        let videoCount: Int
        let photoCount: Int

        nonisolated static let zero = MediaKindCounts(videoCount: 0, photoCount: 0)

        nonisolated static func == (lhs: MediaKindCounts, rhs: MediaKindCounts) -> Bool {
            lhs.videoCount == rhs.videoCount && lhs.photoCount == rhs.photoCount
        }
    }

    struct IndexSnapshot: Sendable, Equatable {
        let entries: [MediaEntry]
        let catalogTagNames: [String]
        let catalogBuddyNames: [String]
        let catalogTrips: [LogbookTripSearchCatalogEntry]
        let catalogSpeciesNames: [String]

        nonisolated var refreshToken: String {
            "\(entries.count)|\(entries.first?.mediaID.uuidString ?? "")|\(entries.last?.mediaID.uuidString ?? "")"
        }
    }

    struct DisplayCache: Equatable, Sendable {
        let snapshot: IndexSnapshot
        let filteredMediaIDs: [UUID]
        let filterFingerprint: String
        let mediaKindCounts: MediaKindCounts
    }

    nonisolated static func pageTitle(for counts: MediaKindCounts) -> String {
        let videoLabel = counts.videoCount == 1 ? "1 video" : "\(counts.videoCount) videos"
        let photoLabel = counts.photoCount == 1 ? "1 photo" : "\(counts.photoCount) photos"
        return "\(videoLabel), \(photoLabel)"
    }

    nonisolated static func mediaKindCounts(from entries: [MediaEntry]) -> MediaKindCounts {
        var videoCount = 0
        var photoCount = 0
        for entry in entries {
            switch entry.mediaKind {
            case .video:
                videoCount += 1
            case .image:
                photoCount += 1
            }
        }
        return MediaKindCounts(videoCount: videoCount, photoCount: photoCount)
    }

    nonisolated static func displayCache(
        snapshot: IndexSnapshot,
        filter: ResolvedFilter
    ) -> DisplayCache {
        let filteredEntries = filteredEntries(from: snapshot, filter: filter)
        return DisplayCache(
            snapshot: snapshot,
            filteredMediaIDs: filteredEntries.map(\.mediaID),
            filterFingerprint: filterFingerprint(filter),
            mediaKindCounts: mediaKindCounts(from: filteredEntries)
        )
    }

    nonisolated static func displayCache(
        from input: GlobalSearchMediaIndexSnapshotBuilder.CaptureInput,
        filter: ResolvedFilter
    ) -> DisplayCache {
        let snapshot = GlobalSearchMediaIndexSnapshotBuilder.build(from: input)
        return displayCache(snapshot: snapshot, filter: filter)
    }

    nonisolated static func filterFingerprint(_ filter: ResolvedFilter) -> String {
        filter.query
    }

    nonisolated static func resolveFilter(from rawQuery: String) -> ResolvedFilter {
        ResolvedFilter(query: rawQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    nonisolated static func filteredEntries(
        from snapshot: IndexSnapshot,
        filter: ResolvedFilter
    ) -> [MediaEntry] {
        guard DiveLogbookSiteSearch.isFiltering(query: filter.query) else {
            return snapshot.entries
        }
        return snapshot.entries.filter { matchesFreeText($0, query: filter.query) }
    }

    nonisolated static func matchesFreeText(_ entry: MediaEntry, query: String) -> Bool {
        if let siteName = entry.siteName,
           CatalogSubstringSearch.matches(in: siteName, query: query) {
            return true
        }
        if entry.mediaBuddyNames.contains(where: { CatalogSubstringSearch.matches(in: $0, query: query) }) {
            return true
        }
        if entry.activityTagNames.contains(where: { CatalogSubstringSearch.matches(in: $0, query: query) }) {
            return true
        }
        if entry.tripTitles.contains(where: { CatalogSubstringSearch.matches(in: $0, query: query) }) {
            return true
        }
        if entry.speciesNames.contains(where: { CatalogSubstringSearch.matches(in: $0, query: query) }) {
            return true
        }
        return false
    }
}
