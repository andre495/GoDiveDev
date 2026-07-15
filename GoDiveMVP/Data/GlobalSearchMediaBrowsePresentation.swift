import Foundation

/// Cross-log media browse opened from **Search → Media** — filters like every other search category: the typed query
/// matches media across all of its fields (site name, tagged buddies, activity tags, trip titles, tagged species).
enum GlobalSearchMediaBrowsePresentation: Sendable {

    nonisolated static let loadingPageTitle = "Media"
    nonisolated static let emptyLibraryMessage = "No photos or videos in your log yet."
    nonisolated static let emptyFilterMessage = "No media matches your search."
    nonisolated static let rootAccessibilityIdentifier = "GlobalSearch.MediaBrowse.Root"
    nonisolated static let searchFieldAccessibilityIdentifier = "GlobalSearch.MediaBrowse.SearchField"
    /// Month/year headers use a **`List`** **`Section`** so they pin under the count-title chrome
    /// (**`scrollContentTopMarginBelowChrome`**), matching scoped search content clearance.
    nonisolated static let pinsMonthSectionHeaders = true

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
        /// Dive start — fallback for month/year grouping when **`capturedAt`** is missing.
        let diveStartTime: Date
        let capturedAt: Date?
        let sortOrder: Int
        let mediaKind: DiveMediaKind
        let siteName: String?
        let activityTagNames: [String]
        let mediaBuddyNames: [String]
        let tripTitles: [String]
        let speciesNames: [String]
        let hasMarineLifeTag: Bool
        let hasBuddyTag: Bool

        var id: UUID { mediaID }

        /// Calendar day used for month/year section dividers.
        nonisolated var sectionDate: Date {
            capturedAt ?? diveStartTime
        }
    }

    /// Month/year divider for **Search → Media** (titles like **March 2026**).
    struct MonthSection: Sendable, Equatable, Identifiable {
        let year: Int
        let month: Int
        let title: String
        let mediaIDs: [UUID]

        var id: String { "\(year)-\(month)" }
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
        let monthSections: [MonthSection]
        /// Precomputed so grid cells do O(1) badge lookups (not O(sightings) per cell).
        let marineLifeTaggedMediaIDs: Set<UUID>
        let buddyTaggedMediaIDs: Set<UUID>
        /// Tag counts for Home-style corner count capsules (**> 1**).
        let marineLifeTagCountByMediaID: [UUID: Int]
        let buddyTagCountByMediaID: [UUID: Int]
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
        return displayCache(filteredEntries: filteredEntries, snapshot: snapshot, filter: filter)
    }

    nonisolated static func displayCache(
        from input: GlobalSearchMediaIndexSnapshotBuilder.CaptureInput,
        filter: ResolvedFilter
    ) -> DisplayCache {
        let snapshot = GlobalSearchMediaIndexSnapshotBuilder.build(from: input)
        return displayCache(snapshot: snapshot, filter: filter)
    }

    nonisolated static func displayCache(
        filteredEntries: [MediaEntry],
        snapshot: IndexSnapshot,
        filter: ResolvedFilter
    ) -> DisplayCache {
        var marineLifeTaggedMediaIDs = Set<UUID>()
        var buddyTaggedMediaIDs = Set<UUID>()
        var marineLifeTagCountByMediaID: [UUID: Int] = [:]
        var buddyTagCountByMediaID: [UUID: Int] = [:]
        for entry in filteredEntries {
            let marineCount = entry.speciesNames.count
            let buddyCount = entry.mediaBuddyNames.count
            if marineCount > 0 {
                marineLifeTaggedMediaIDs.insert(entry.mediaID)
                marineLifeTagCountByMediaID[entry.mediaID] = marineCount
            }
            if buddyCount > 0 {
                buddyTaggedMediaIDs.insert(entry.mediaID)
                buddyTagCountByMediaID[entry.mediaID] = buddyCount
            }
        }
        return DisplayCache(
            snapshot: snapshot,
            filteredMediaIDs: filteredEntries.map(\.mediaID),
            monthSections: monthSections(from: filteredEntries),
            marineLifeTaggedMediaIDs: marineLifeTaggedMediaIDs,
            buddyTaggedMediaIDs: buddyTaggedMediaIDs,
            marineLifeTagCountByMediaID: marineLifeTagCountByMediaID,
            buddyTagCountByMediaID: buddyTagCountByMediaID,
            filterFingerprint: filterFingerprint(filter),
            mediaKindCounts: mediaKindCounts(from: filteredEntries)
        )
    }

    /// Groups filtered media into newest-month-first sections (**March 2026**).
    nonisolated static func monthSections(
        from entries: [MediaEntry],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [MonthSection] {
        guard !entries.isEmpty else { return [] }

        struct YearMonthKey: Hashable {
            let year: Int
            let month: Int
        }

        var mediaIDsByKey: [YearMonthKey: [UUID]] = [:]
        for entry in entries {
            let components = calendar.dateComponents([.year, .month], from: entry.sectionDate)
            guard let year = components.year, let month = components.month else { continue }
            let key = YearMonthKey(year: year, month: month)
            mediaIDsByKey[key, default: []].append(entry.mediaID)
        }

        let monthSymbols = GlobalSearchDiveIndexing.monthSymbols(locale: locale)
        return mediaIDsByKey.keys
            .sorted { lhs, rhs in
                if lhs.year != rhs.year { return lhs.year > rhs.year }
                return lhs.month > rhs.month
            }
            .map { key in
                MonthSection(
                    year: key.year,
                    month: key.month,
                    title: monthYearTitle(year: key.year, month: key.month, monthSymbols: monthSymbols),
                    mediaIDs: mediaIDsByKey[key] ?? []
                )
            }
    }

    nonisolated static func monthYearTitle(
        year: Int,
        month: Int,
        monthSymbols: [String]
    ) -> String {
        let monthName: String
        if month >= 1, month <= monthSymbols.count {
            monthName = monthSymbols[month - 1]
        } else {
            monthName = String(month)
        }
        return "\(monthName) \(year)"
    }

    nonisolated static func filterFingerprint(_ filter: ResolvedFilter) -> String {
        filter.query
    }

    /// Media data-change tokens have the shape `activities|buddyTags|sightings|trips|speciesCount`.
    /// The species component only enriches tag names, so this strips it — letting a prewarmed
    /// snapshot (built with the species catalog loaded) satisfy a browse whose own species catalog
    /// hasn't finished loading yet, instead of forcing a redundant main-actor rebuild.
    nonisolated static func coreDataToken(fromRefreshToken token: String) -> String {
        token.split(separator: "|", omittingEmptySubsequences: false)
            .dropLast()
            .joined(separator: "|")
    }

    /// Whether a browse can paint from the prewarmed snapshot instead of re-capturing every
    /// dive/photo/tag on the main actor. Exact token match reuses outright; while the browse's own
    /// species catalog is still loading, a matching core token (all counts except species) is enough —
    /// the warmer built its snapshot with the species catalog already loaded, so it is a superset.
    nonisolated static func canReusePrewarmedSnapshot(
        storeToken: String,
        currentToken: String,
        isSpeciesCatalogLoaded: Bool
    ) -> Bool {
        guard !storeToken.isEmpty else { return false }
        if storeToken == currentToken { return true }
        guard !isSpeciesCatalogLoaded else { return false }
        return coreDataToken(fromRefreshToken: storeToken)
            == coreDataToken(fromRefreshToken: currentToken)
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
