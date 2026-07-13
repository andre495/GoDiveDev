import Foundation

/// Unified app-wide search — indexes dives, sites, species, people, trips, gear, and certs.
enum GlobalSearchPresentation: Sendable {

    nonisolated static let searchPrompt = "Search GoDive"
    nonisolated static let rootAccessibilityIdentifier = "GlobalSearch.Root"
    nonisolated static let resultsListAccessibilityIdentifier = "GlobalSearch.ResultsList"
    nonisolated static let resultsBackButtonAccessibilityIdentifier = "GlobalSearch.ResultsBack"
    /// Maximum matches listed per section. Applies to both scoped browse (a category tile) and typed queries so
    /// cross-category results are never silently truncated (typed searches previously capped each section at 12).
    nonisolated static let maxHitsPerSection = 500
    nonisolated static let contextTokensAccessibilityIdentifier = "GlobalSearch.ContextTokens"
    /// Brief delay after returning from a pushed result so **`.searchable`** can reattach before presenting the field.
    nonisolated static let stackSearchRestoreDelayNanoseconds: UInt64 = 80_000_000
    /// Idle bubble motion resumes after the tab morph gets its first frame.
    nonisolated static let idleBubbleResumeDelayNanoseconds: UInt64 = 180_000_000

    /// Search scope chips shown on the idle search page before the user types or selects a token.
    enum ContextToken: String, Sendable, CaseIterable, Identifiable {
        case dives
        case buddies
        case sites
        case marineLife
        case tags
        case gear
        case trips
        case certifications
        case media

        var id: String { rawValue }

        nonisolated var title: String {
            switch self {
            case .dives: return "Dives"
            case .buddies: return "Buddies"
            case .sites: return "Sites"
            case .marineLife: return "Marine life"
            case .tags: return "Tags"
            case .gear: return "Gear"
            case .trips: return "Trips"
            case .certifications: return "Certifications"
            case .media: return "Media"
            }
        }

        /// Singular / plural noun for the scoped-results count header (e.g. "Buddy" / "Buddies").
        nonisolated var scopedCountNoun: (singular: String, plural: String) {
            switch self {
            case .dives: return ("Dive", "Dives")
            case .buddies: return ("Buddy", "Buddies")
            case .sites: return ("Site", "Sites")
            case .marineLife: return ("Species", "Species")
            case .tags: return ("Tag", "Tags")
            case .gear: return ("Gear item", "Gear items")
            case .trips: return ("Trip", "Trips")
            case .certifications: return ("Certification", "Certifications")
            // Media uses its own video/photo split title (`GlobalSearchMediaBrowsePresentation.pageTitle`).
            case .media: return ("Media item", "Media items")
            }
        }

        /// Back-row count header for a scoped category, e.g. "12 Buddies" / "1 Dive".
        nonisolated func scopedResultsCountTitle(_ count: Int) -> String {
            let noun = scopedCountNoun
            return "\(count) \(count == 1 ? noun.singular : noun.plural)"
        }

        nonisolated var systemImage: String {
            switch self {
            case .dives: return "water.waves"
            case .buddies: return "person.2.fill"
            case .sites: return "mappin.and.ellipse"
            case .marineLife: return "leaf.fill"
            case .tags: return "tag.fill"
            case .gear: return "archivebox.fill"
            case .trips: return "airplane"
            case .certifications: return "checkmark.seal.fill"
            case .media: return "photo.on.rectangle.angled"
            }
        }

        nonisolated var accessibilityIdentifier: String {
            "GlobalSearch.ContextToken.\(rawValue)"
        }

        nonisolated var sectionKind: SectionKind {
            switch self {
            case .dives: return .dives
            case .buddies: return .buddies
            case .sites: return .diveSites
            case .marineLife: return .species
            case .tags: return .tags
            case .gear: return .equipment
            case .trips: return .trips
            case .certifications: return .certifications
            case .media: return .media
            }
        }

        /// **`FieldGuideCategoryAccent`** lookup — same palette as Field Guide hub tiles.
        nonisolated var fieldGuideAccentCategoryID: String {
            switch self {
            case .dives: return "marine_mammals"
            case .buddies: return "corals"
            case .sites: return "plants"
            case .marineLife: return "fishes"
            case .tags: return "sponges"
            case .gear: return "invertebrates"
            case .trips: return "sea_turtles"
            case .certifications: return "sea_turtles"
            case .media: return "global_search_media"
            }
        }
    }

    enum ContextTokenPresentation: Sendable {
        nonisolated static let idleHeaderAccessibilityIdentifier = "GlobalSearch.IdleHeader"
        nonisolated static let idleHeaderTitle = "Search"
        nonisolated static let gridColumnCount = HomeLifetimeStatsTilesLayout.gridColumnCount
        nonisolated static let gridSpacing: CGFloat = HomeLifetimeStatsTilesLayout.gridSpacing
        nonisolated static let iconPointSize: CGFloat = ProfileDestinationTilePresentation.iconPointSize
        /// Single-line cap height for **`AppTheme.Typography.headerTitle.weight(.bold)`** (matches **`AppHeaderStackedTitleChrome`**).
        nonisolated static let idleHeaderEstimatedHeight: CGFloat = 34
        /// Tab **`role: .search`** morph field above the home indicator / keyboard.
        nonisolated static let tabSearchChromeHeight: CGFloat = 56
        /// Small gap between the bottom tile row and the morphed search field when the keyboard is open.
        nonisolated static let keyboardOpenGridExtraBottomSpacing: CGFloat = AppTheme.Spacing.sm
        /// Mirrors **`AppTheme.Layout.appHeaderTopPadding`** / **`appHeaderBottomPadding`** for nonisolated layout math.
        nonisolated static let idleHeaderTitleTopPadding: CGFloat = 8
        nonisolated static let idleHeaderTitleBottomPadding: CGFloat = 16
        nonisolated static let cornerRadius: CGFloat = ProfileDestinationTilePresentation.cornerRadius
        nonisolated static let contentHorizontalPadding: CGFloat = AppTheme.Spacing.lg
        nonisolated static let headerToGridSpacing: CGFloat = AppTheme.Spacing.sm

        /// Title-only band — **`AppHeader`** vertical padding + one **`.title.bold`** line (no back row).
        nonisolated static func idleHeaderTitleBandHeight() -> CGFloat {
            idleHeaderTitleTopPadding
                + idleHeaderEstimatedHeight
                + idleHeaderTitleBottomPadding
        }

        /// Bottom inset so category tiles end just above the morphed tab search field.
        nonisolated static func categoryGridBottomInset(
            resolvedSafeAreaBottom: CGFloat,
            keyboardOverlapHeight: CGFloat = 0,
            isKeyboardVisible: Bool = false
        ) -> CGFloat {
            if isKeyboardVisible {
                return max(keyboardOverlapHeight, resolvedSafeAreaBottom)
                    + tabSearchChromeHeight
                    + keyboardOpenGridExtraBottomSpacing
            }
            return resolvedSafeAreaBottom + tabSearchChromeHeight
        }

        nonisolated static func resultsListTopInset(
            safeAreaTop: CGFloat,
            chromeHeight: CGFloat
        ) -> CGFloat {
            safeAreaTop + chromeHeight
        }

        nonisolated static func gridRowCount(tokenCount: Int, columnCount: Int) -> Int {
            guard tokenCount > 0, columnCount > 0 else { return 0 }
            return (tokenCount + columnCount - 1) / columnCount
        }
    }

    /// Section headers on multi-category search results — right-aligned, transparent, pin with back row.
    enum ResultsSectionHeaderPresentation: Sendable {
        nonisolated static let horizontalPadding = AppTheme.Spacing.lg
        /// Matches **`SecondaryDestinationBackButton`** tap width (**44** pt).
        nonisolated static let backButtonTapWidth: CGFloat = 44
        /// Slightly larger than **`.headline`** for scanability while scrolling.
        nonisolated static let titleFontSize: CGFloat = 20
        nonisolated static let verticalPadding = AppTheme.Spacing.sm
        /// Mirrors **`AppTheme.Layout.appHeaderTopPadding`** (**`Spacing.sm`**) as a nonisolated stored value.
        nonisolated static let backButtonRowTopPadding = AppTheme.Spacing.sm

        nonisolated static func backButtonReservedWidth(
            horizontalPadding: CGFloat = ResultsSectionHeaderPresentation.horizontalPadding,
            backButtonTapWidth: CGFloat = ResultsSectionHeaderPresentation.backButtonTapWidth
        ) -> CGFloat {
            horizontalPadding + backButtonTapWidth
        }

        /// Top scroll margin that pins each sticky section header **on** the floating back-button row (vertically
        /// centered on the back button), so the first section label is even with the back arrow instead of sitting
        /// below the whole chrome band. The sectioned **`List`** already respects the status-bar safe area, so this
        /// margin is measured from the top of the safe area — do not add **`safeAreaTop`** again here.
        nonisolated static func scrollContentTopMargin() -> CGFloat {
            // `backButtonTapWidth` mirrors `AppTheme.Layout.glassChromeControlHeight` (both 44); stored constants keep
            // this `nonisolated` (main-actor `AppTheme.Layout` / `Spacing` can't be read from a nonisolated body).
            let backButtonCenterY = backButtonRowTopPadding + backButtonTapWidth / 2
            let headerHalfHeight = verticalPadding + titleFontSize / 2
            return max(backButtonCenterY - headerHalfHeight, 0)
        }
    }

    /// Floating back row + top fade over scrolling results (matches logbook / field guide stacking).
    enum ResultsChromePresentation: Sendable {
        /// **`LogbookTopChromeScrim`** — above transparent list rows, below back button.
        nonisolated static let topScrimZIndex = 0.5
        nonisolated static let topChromeZIndex = 1.0

        nonisolated static func topScrimObstructionHeight(
            safeAreaTop: CGFloat,
            chromeHeight: CGFloat
        ) -> CGFloat {
            ContextTokenPresentation.resultsListTopInset(
                safeAreaTop: safeAreaTop,
                chromeHeight: chromeHeight
            )
        }
    }

    /// Fade behavior for the back-row count header ("12 Buddies", "3 videos, 12 photos") as results scroll.
    enum ResultsCountTitlePresentation: Sendable {
        /// Scroll distance (pt) over which the count title fades from visible to hidden while scrolling down.
        nonisolated static let fadeDistance: CGFloat = 44

        /// Opacity for the count title given how far the results list has scrolled from its resting top
        /// (`contentOffset.y + contentInsets.top`). Fully visible at rest (offset ≤ 0), fully hidden past
        /// `fadeDistance`, so the title animates away as the user scrolls into the list.
        nonisolated static func titleOpacity(scrollOffset: CGFloat) -> Double {
            guard scrollOffset > 0 else { return 1 }
            let progress = min(scrollOffset / fadeDistance, 1)
            return Double(1 - progress)
        }
    }

    enum SectionKind: String, Sendable, CaseIterable, Identifiable {
        case dives
        case diveSites
        case species
        case buddies
        case tags
        case trips
        case equipment
        case certifications
        case media

        var id: String { rawValue }

        /// Multi-category search results — highest priority first.
        ///
        /// `.media` renders second (after buddies) in the general results surface. It produces no
        /// text `Hit`s from `search()`; the results view injects a matching-media thumbnail strip at
        /// this position (see `GlobalSearchSearchIndexLayer`).
        nonisolated static let resultSectionDisplayOrder: [SectionKind] = [
            .buddies,
            .media,
            .diveSites,
            .tags,
            .trips,
            .species,
            .equipment,
            .certifications,
            .dives,
        ]

        nonisolated var title: String {
            switch self {
            case .dives: return "Dives"
            case .diveSites: return "Dive sites"
            case .species: return "Marine life"
            case .buddies: return "Buddies"
            case .tags: return "Tags"
            case .trips: return "Trips"
            case .equipment: return "Equipment"
            case .certifications: return "Certifications"
            case .media: return "Media"
            }
        }
    }

    enum Destination: Hashable, Sendable {
        case dive(UUID)
        case diveSite(UUID)
        case referenceSite(String)
        case species(String)
        case buddy(UUID)
        case tag(UUID)
        case trip(UUID)
        case equipment(UUID)
        case certification(UUID)
    }

    /// Why a result matched the typed query — rendered as an italic "Label: text" line under the row.
    struct MatchReason: Hashable, Sendable {
        let label: String
        let text: String

        nonisolated static func == (lhs: MatchReason, rhs: MatchReason) -> Bool {
            lhs.label == rhs.label && lhs.text == rhs.text
        }

        nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(label)
            hasher.combine(text)
        }
    }

    /// A labeled, searchable value on an index entry used to explain *why* the entry matched.
    /// `value` is matched against the query (may bundle aliases); `display` is what the user sees
    /// (defaults to `value`). `isSnippet` windows the match with a few words of surrounding context.
    struct SearchField: Hashable, Sendable {
        let label: String
        let value: String
        var display: String? = nil
        var isSnippet: Bool = false

        nonisolated var displayText: String { display ?? value }
    }

    struct Hit: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let subtitle: String?
        let systemImage: String
        let destination: Destination
        let accessibilityIdentifier: String
        var matchReasons: [MatchReason] = []
    }

    struct Section: Identifiable, Equatable, Sendable {
        let kind: SectionKind
        let hits: [Hit]

        var id: SectionKind { kind }
        var title: String { kind.title }
    }

    struct Results: Equatable, Sendable {
        let query: String
        let sections: [Section]

        nonisolated var isEmpty: Bool {
            sections.allSatisfy { $0.hits.isEmpty }
        }
    }

    struct DiveIndexEntry: Sendable {
        let id: UUID
        let title: String
        let subtitle: String?
        let searchHaystack: String
        var matchFields: [SearchField] = []
    }

    struct DiveSiteIndexEntry: Sendable {
        let title: String
        let subtitle: String?
        let searchHaystacks: [String]
        let destination: Destination
    }

    struct SpeciesIndexEntry: Sendable {
        let uuid: String
        let title: String
        let subtitle: String?
        let searchText: String
    }

    struct BuddyIndexEntry: Sendable {
        let id: UUID
        let displayName: String
    }

    struct TripIndexEntry: Sendable {
        let id: UUID
        let displayTitle: String
        let subtitle: String?
    }

    struct EquipmentIndexEntry: Sendable {
        let id: UUID
        let title: String
        let gearTypeLabel: String
        let searchHaystacks: [String]
    }

    struct CertificationIndexEntry: Sendable {
        let id: UUID
        let title: String
        let subtitle: String?
        let searchHaystacks: [String]
    }

    struct TagIndexEntry: Sendable {
        let id: UUID
        let name: String
        let appliedDiveCount: Int
        let searchHaystack: String

        nonisolated var diveCountLabel: String {
            appliedDiveCount == 1 ? "1 dive" : "\(appliedDiveCount) dives"
        }
    }

    struct Catalog: Sendable {
        let dives: [DiveIndexEntry]
        let diveSites: [DiveSiteIndexEntry]
        let species: [SpeciesIndexEntry]
        let buddies: [BuddyIndexEntry]
        let tags: [TagIndexEntry]
        let trips: [TripIndexEntry]
        let equipment: [EquipmentIndexEntry]
        let certifications: [CertificationIndexEntry]
    }

    nonisolated static func isFiltering(query: String) -> Bool {
        CatalogSubstringSearch.isFiltering(query: query)
    }

    nonisolated static func isActive(query: String, contextTokens: [ContextToken]) -> Bool {
        isFiltering(query: query) || !contextTokens.isEmpty
    }

    /// **`true`** when the only active scope is **Media** — the results panel renders the media grid
    /// (filtered by any additional query terms) instead of the text-search results list.
    nonisolated static func isMediaScope(_ contextTokens: [ContextToken]) -> Bool {
        contextTokens == [.media]
    }

    /// Clears query + scope tokens so the idle category grid returns (search results back affordance).
    nonisolated static func applyReturnToCategoryBrowse(
        query: inout String,
        contextTokens: inout [ContextToken]
    ) {
        query = ""
        contextTokens = []
    }

    nonisolated static func search(
        catalog: Catalog,
        query: String,
        contextTokens: [ContextToken] = []
    ) -> Results {
        let appliesTextFilter = isFiltering(query: query)
        guard appliesTextFilter || !contextTokens.isEmpty else {
            return Results(query: query, sections: [])
        }

        let sectionKinds: [SectionKind] = {
            guard !contextTokens.isEmpty else { return SectionKind.resultSectionDisplayOrder }
            let scoped = Set(contextTokens.map(\.sectionKind))
            return SectionKind.resultSectionDisplayOrder.filter { scoped.contains($0) }
        }()

        let maxHits = maxHitsPerSection

        let sections = sectionKinds.compactMap { kind -> Section? in
            let hits = hits(
                for: kind,
                catalog: catalog,
                query: query,
                appliesTextFilter: appliesTextFilter,
                maxHits: maxHits
            )
            guard !hits.isEmpty else { return nil }
            return Section(kind: kind, hits: hits)
        }
        return Results(query: query, sections: sections)
    }

    nonisolated private static func hits(
        for kind: SectionKind,
        catalog: Catalog,
        query: String,
        appliesTextFilter: Bool,
        maxHits: Int
    ) -> [Hit] {
        switch kind {
        case .dives:
            return catalog.dives
                .filter { entry in
                    !appliesTextFilter
                        || CatalogSubstringSearch.matches(in: entry.searchHaystack, query: query)
                }
                .prefix(maxHits)
                .map { entry in
                    Hit(
                        id: "dive-\(entry.id.uuidString)",
                        title: entry.title,
                        subtitle: entry.subtitle,
                        systemImage: "water.waves",
                        destination: .dive(entry.id),
                        accessibilityIdentifier: "GlobalSearch.Hit.Dive.\(entry.id.uuidString)",
                        matchReasons: appliesTextFilter
                            ? GlobalSearchMatchReasoning.reasons(query: query, fields: entry.matchFields)
                            : []
                    )
                }
        case .diveSites:
            return catalog.diveSites
                .filter { entry in
                    !appliesTextFilter
                        || CatalogSubstringSearch.matchesAny(in: entry.searchHaystacks, query: query)
                }
                .prefix(maxHits)
                .map { entry in
                    Hit(
                        id: diveSiteHitID(for: entry.destination),
                        title: entry.title,
                        subtitle: entry.subtitle,
                        systemImage: "mappin.and.ellipse",
                        destination: entry.destination,
                        accessibilityIdentifier: diveSiteHitAccessibilityIdentifier(for: entry.destination)
                    )
                }
        case .species:
            return catalog.species
                .filter { entry in
                    !appliesTextFilter
                        || CatalogSubstringSearch.matches(in: entry.searchText, query: query)
                }
                .prefix(maxHits)
                .map { entry in
                    Hit(
                        id: "species-\(entry.uuid)",
                        title: entry.title,
                        subtitle: entry.subtitle,
                        systemImage: "leaf",
                        destination: .species(entry.uuid),
                        accessibilityIdentifier: "GlobalSearch.Hit.Species.\(entry.uuid)"
                    )
                }
        case .buddies:
            return catalog.buddies
                .filter { entry in
                    !appliesTextFilter
                        || CatalogSubstringSearch.matches(in: entry.displayName, query: query)
                }
                .prefix(maxHits)
                .map { entry in
                    Hit(
                        id: "buddy-\(entry.id.uuidString)",
                        title: entry.displayName,
                        subtitle: nil,
                        systemImage: "person.2",
                        destination: .buddy(entry.id),
                        accessibilityIdentifier: "GlobalSearch.Hit.Buddy.\(entry.id.uuidString)"
                    )
                }
        case .tags:
            return catalog.tags
                .filter { entry in
                    !appliesTextFilter
                        || CatalogSubstringSearch.matches(in: entry.searchHaystack, query: query)
                }
                .prefix(maxHits)
                .map { entry in
                    Hit(
                        id: "tag-\(entry.id.uuidString)",
                        title: entry.name,
                        subtitle: entry.diveCountLabel,
                        systemImage: "tag.fill",
                        destination: .tag(entry.id),
                        accessibilityIdentifier: "GlobalSearch.Hit.Tag.\(entry.id.uuidString)"
                    )
                }
        case .trips:
            return catalog.trips
                .filter { entry in
                    !appliesTextFilter
                        || CatalogSubstringSearch.matchesAny(
                            in: [entry.displayTitle, entry.subtitle ?? ""],
                            query: query
                        )
                }
                .prefix(maxHits)
                .map { entry in
                    Hit(
                        id: "trip-\(entry.id.uuidString)",
                        title: entry.displayTitle,
                        subtitle: entry.subtitle,
                        systemImage: "airplane",
                        destination: .trip(entry.id),
                        accessibilityIdentifier: "GlobalSearch.Hit.Trip.\(entry.id.uuidString)"
                    )
                }
        case .equipment:
            return catalog.equipment
                .filter { entry in
                    !appliesTextFilter
                        || CatalogSubstringSearch.matchesAny(in: entry.searchHaystacks, query: query)
                }
                .prefix(maxHits)
                .map { entry in
                    Hit(
                        id: "equipment-\(entry.id.uuidString)",
                        title: entry.title,
                        subtitle: entry.gearTypeLabel,
                        systemImage: "archivebox",
                        destination: .equipment(entry.id),
                        accessibilityIdentifier: "GlobalSearch.Hit.Equipment.\(entry.id.uuidString)"
                    )
                }
        case .certifications:
            return catalog.certifications
                .filter { entry in
                    !appliesTextFilter
                        || CatalogSubstringSearch.matchesAny(in: entry.searchHaystacks, query: query)
                }
                .prefix(maxHits)
                .map { entry in
                    Hit(
                        id: "cert-\(entry.id.uuidString)",
                        title: entry.title,
                        subtitle: entry.subtitle,
                        systemImage: "checkmark.seal",
                        destination: .certification(entry.id),
                        accessibilityIdentifier: "GlobalSearch.Hit.Certification.\(entry.id.uuidString)"
                    )
                }
        case .media:
            return []
        }
    }

    nonisolated private static func diveSiteHitID(for destination: Destination) -> String {
        switch destination {
        case .diveSite(let siteID):
            return "site-\(siteID.uuidString)"
        case .referenceSite(let referenceID):
            return "reference-site-\(referenceID)"
        default:
            return "site-unknown"
        }
    }

    nonisolated private static func diveSiteHitAccessibilityIdentifier(for destination: Destination) -> String {
        switch destination {
        case .diveSite(let siteID):
            return "GlobalSearch.Hit.Site.\(siteID.uuidString)"
        case .referenceSite(let referenceID):
            return "GlobalSearch.Hit.ReferenceSite.\(referenceID)"
        default:
            return "GlobalSearch.Hit.Site.Unknown"
        }
    }
}

/// Tab open — keep the morph path light, then mount the SwiftData search index.
enum GlobalSearchTabLaunchPresentation: Sendable {
    nonisolated static func shouldMountSearchIndexImmediately(
        isSearchActive: Bool,
        pathDepth: Int
    ) -> Bool {
        isSearchActive || pathDepth > 0
    }

    nonisolated static func shouldBuildSearchCatalog(isSearchActive: Bool) -> Bool {
        isSearchActive
    }
}

/// Interactive slide-back from search results → category browse (mirrors **`NavigationStack`** pop timing).
enum GlobalSearchResultsDismissPresentation: Sendable {
    nonisolated static let springResponse: Double = 0.38
    nonisolated static let springDamping: Double = 0.86
    nonisolated static let settleNanoseconds: UInt64 = 320_000_000
    /// Matches **`GoDiveLeadingEdgeSwipePopMetrics.maxStartXFromScreenLeading`** — duplicated here so
    /// **`shouldEngageDismissDrag`** stays **`nonisolated`** without referencing UIKit-adjacent metrics.
    nonisolated static let dismissDragMaxStartXFromScreenLeading: CGFloat = 72

    nonisolated static func commitDismissOffset(containerWidth: CGFloat) -> CGFloat {
        max(containerWidth, 1)
    }

    /// Results appear instantly when search activates — slide motion is reserved for dismiss (results → category browse).
    nonisolated static func initialResultsPanelDragOffsetOnReveal(containerWidth: CGFloat) -> CGFloat {
        _ = containerWidth
        return 0
    }

    /// Generic category browse (bubbles + tiles) slides in from the leading edge while results slide out.
    nonisolated static func genericBrowseSlideOffset(
        dragOffset: CGFloat,
        containerWidth: CGFloat,
        isResultsPanelVisible: Bool
    ) -> CGFloat {
        guard isResultsPanelVisible else { return 0 }
        return dragOffset - commitDismissOffset(containerWidth: containerWidth)
    }

    nonisolated static func revealsCategoryTiles(
        isResultsPanelVisible: Bool,
        dragOffset: CGFloat
    ) -> Bool {
        !isResultsPanelVisible || dragOffset > 0.5
    }

    /// The interactive slide-back should only engage for a clearly horizontal, rightward swipe that begins near the
    /// leading edge. A vertical scroll that starts near the edge must pass through to the results list — otherwise the
    /// list scroll is locked mid-gesture and scrolling appears frozen.
    nonisolated static func shouldEngageDismissDrag(
        startLocationX: CGFloat,
        translation: CGSize,
        maxStartXFromScreenLeading: CGFloat = GlobalSearchResultsDismissPresentation.dismissDragMaxStartXFromScreenLeading
    ) -> Bool {
        guard startLocationX <= maxStartXFromScreenLeading else { return false }
        guard translation.width > 0 else { return false }
        return translation.width > abs(translation.height)
    }

    /// While the interactive slide-back is active, settling, or the panel has moved, block row taps and list scroll.
    nonisolated static func blocksResultsRowSelection(
        isDismissDragActive: Bool,
        dragOffset: CGFloat
    ) -> Bool {
        isDismissDragActive || dragOffset > 0
    }

    nonisolated static func blocksResultsInteraction(
        isDismissDragActive: Bool,
        dragOffset: CGFloat
    ) -> Bool {
        blocksResultsRowSelection(
            isDismissDragActive: isDismissDragActive,
            dragOffset: dragOffset
        )
    }

    /// While the interactive slide-back is active, the results **`List`** must not scroll vertically.
    nonisolated static func locksResultsListScroll(
        isDismissDragActive: Bool,
        dragOffset: CGFloat
    ) -> Bool {
        blocksResultsInteraction(
            isDismissDragActive: isDismissDragActive,
            dragOffset: dragOffset
        )
    }
}

/// Search stack presentation while pushing catalog detail pages from results.
enum GlobalSearchPushedDestinationPresentation: Sendable {
    /// **`.searchable`** stays on the stack only at the root — pushed detail pages hide it.
    nonisolated static func attachesStackSearch(path: [GlobalSearchPresentation.Destination]) -> Bool {
        path.isEmpty
    }

    /// Clear navigation-layer search chrome when opening a result (any push dismisses the field).
    nonisolated static func shouldDismissNavigationSearchOnPathChange(
        previousDepth: Int,
        newDepth: Int
    ) -> Bool {
        newDepth > previousDepth
    }

    /// **`dismissSearch()`** before append for detail pushes.
    nonisolated static func shouldDismissSearchBeforePathAppend(
        destination: GlobalSearchPresentation.Destination,
        currentPathDepth: Int
    ) -> Bool {
        _ = destination
        _ = currentPathDepth
        return true
    }

    /// Restore interactive pop on the stack while a detail is pushed (root stack must stay free of UIKit anchors for morph).
    nonisolated static func attachesStackInteractivePop(pathCount: Int) -> Bool {
        pathCount > 0
    }

    /// Re-present the tab-bar search field after popping back from a result (keyboard stays dismissed).
    nonisolated static func shouldRestoreStackSearchOnPathChange(
        previousDepth: Int,
        newDepth: Int,
        isSearchActive: Bool
    ) -> Bool {
        newDepth == 0 && previousDepth > 0 && isSearchActive
    }

    /// Pop from a pushed result should land on the results list, not the idle category grid.
    nonisolated static func shouldForceResultsPanelOnPopFromDetail(
        previousDepth: Int,
        newDepth: Int,
        preservedSessionIsActive: Bool
    ) -> Bool {
        newDepth == 0 && previousDepth > 0 && preservedSessionIsActive
    }
}

/// Main-actor capture of SwiftData models into **`GlobalSearchPresentation.Catalog`**.
enum GlobalSearchCatalogSeeding {
    @MainActor
    static func catalog(
        dives: [DiveActivity],
        diveSites: [DiveSite],
        speciesCatalog: [MarineLife],
        buddies: [DiveBuddy],
        tags: [ActivityTag],
        trips: [DiveTrip],
        equipment: [EquipmentItem],
        certifications: [Certification],
        unitSystem: DiveDisplayUnitSystem
    ) -> GlobalSearchPresentation.Catalog {
        let divesByID = Dictionary(dives.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let diveSpeciesNameByUUID = Dictionary(
            speciesCatalog.map { ($0.uuid, $0.commonName) },
            uniquingKeysWith: { first, _ in first }
        )
        let diveTripTitleByID = Dictionary(
            trips.map { ($0.id, $0.displayTitle) },
            uniquingKeysWith: { first, _ in first }
        )
        let diveIndexMonthSymbols = GlobalSearchDiveIndexing.monthSymbols()

        let diveEntries = LogbookActivitySnapshotSeeding.seeds(from: dives).map { seed in
            let matchFields = diveMatchFields(
                seed: seed,
                activity: divesByID[seed.id],
                speciesNameByUUID: diveSpeciesNameByUUID,
                tripTitleByID: diveTripTitleByID,
                monthSymbols: diveIndexMonthSymbols
            )
            // Site name (row title) matches but needs no reason line; all other terms live in matchFields.
            let haystack = CatalogSearchPresentation.joinedLowercasedHaystacks(
                [seed.displayName, seed.resolvedSiteNameLowercased ?? ""] + matchFields.map(\.value)
            )
            return GlobalSearchPresentation.DiveIndexEntry(
                id: seed.id,
                title: seed.displayName,
                subtitle: seed.resolvedSiteNameLowercased?.capitalized,
                searchHaystack: haystack,
                matchFields: matchFields
            )
        }

        let ownerProfileID = dives.first?.ownerProfileID ?? buddies.first?.ownerProfileID
        let siteEntries = GlobalSearchSiteIndexSeeding.entries(
            diveSites: diveSites,
            ownerActivities: dives,
            ownerProfileID: ownerProfileID
        )

        let speciesEntries = speciesCatalog.map { species in
            let snapshot = species.fieldGuideCatalogSnapshot
            return GlobalSearchPresentation.SpeciesIndexEntry(
                uuid: species.uuid,
                title: species.commonName,
                subtitle: species.scientificName,
                searchText: FieldGuideMarineLifeSearch.precomputedSearchText(for: snapshot)
            )
        }

        let buddyEntries = buddies.map {
            GlobalSearchPresentation.BuddyIndexEntry(id: $0.id, displayName: $0.displayName)
        }

        let tagEntries = tags.map { tag in
            let appliedDiveCount: Int
            if let ownerProfileID {
                appliedDiveCount = tag.dives.filter { $0.ownerProfileID == ownerProfileID }.count
            } else {
                appliedDiveCount = tag.dives.count
            }
            return GlobalSearchPresentation.TagIndexEntry(
                id: tag.id,
                name: tag.name,
                appliedDiveCount: appliedDiveCount,
                searchHaystack: CatalogSearchPresentation.joinedLowercasedHaystacks([
                    tag.name,
                    tag.normalizedName,
                ])
            )
        }

        let tripEntries = trips.map { trip in
            GlobalSearchPresentation.TripIndexEntry(
                id: trip.id,
                displayTitle: trip.displayTitle,
                subtitle: DiveTripPresentation.formattedDateRange(
                    start: trip.startDate,
                    end: trip.endDate
                )
            )
        }

        let equipmentEntries = equipment.map { item in
            GlobalSearchPresentation.EquipmentIndexEntry(
                id: item.id,
                title: EquipmentItemPresentation.title(for: item),
                gearTypeLabel: EquipmentItemPresentation.gearTypeLabel(for: item),
                searchHaystacks: [
                    EquipmentItemPresentation.title(for: item),
                    EquipmentItemPresentation.gearTypeLabel(for: item),
                    item.manufacturer,
                    item.model,
                    item.type,
                    item.notes ?? "",
                ]
            )
        }

        let certificationEntries = certifications.map { cert in
            GlobalSearchPresentation.CertificationIndexEntry(
                id: cert.id,
                title: CertificationPresentation.title(for: cert),
                subtitle: CertificationPresentation.subtitle(for: cert),
                searchHaystacks: [
                    CertificationPresentation.title(for: cert),
                    CertificationPresentation.subtitle(for: cert),
                    cert.agency,
                    cert.certNumber,
                    cert.instructor,
                    cert.diveShop ?? "",
                ]
            )
        }

        _ = unitSystem
        return GlobalSearchPresentation.Catalog(
            dives: diveEntries,
            diveSites: siteEntries,
            species: speciesEntries,
            buddies: buddyEntries,
            tags: tagEntries,
            trips: tripEntries,
            equipment: equipmentEntries,
            certifications: certificationEntries
        )
    }

    /// Labeled searchable fields for one dive — powers both the search haystack and the per-result
    /// "why it matched" reason lines. Order here is the reason-priority order (buddies/marine life
    /// first, notes/dive number last); the site name (row title) is intentionally excluded.
    @MainActor
    private static func diveMatchFields(
        seed: LogbookActivitySnapshotSeed,
        activity: DiveActivity?,
        speciesNameByUUID: [String: String],
        tripTitleByID: [UUID: String],
        monthSymbols: [String]
    ) -> [GlobalSearchPresentation.SearchField] {
        var fields: [GlobalSearchPresentation.SearchField] = []

        for buddy in seed.buddyDisplayNames {
            fields.append(.init(label: "Buddy", value: buddy))
        }
        if let activity {
            for name in diveSightingCommonNames(for: activity, speciesNameByUUID: speciesNameByUUID) {
                fields.append(.init(label: "Marine life", value: name))
            }
        }
        for tag in seed.activityTagNames {
            fields.append(.init(label: "Tag", value: tag))
        }
        if let activity {
            for title in diveLinkedTripTitles(for: activity, tripTitleByID: tripTitleByID) {
                fields.append(.init(label: "Trip", value: title))
            }
        }
        if let site = activity?.diveSite {
            let countryTerms = DiveSiteCountryPresentation.searchTerms(for: site.country)
            if !countryTerms.isEmpty {
                let canonical = DiveSiteCountryPresentation.canonicalDisplayName(for: site.country)
                fields.append(.init(
                    label: "Country",
                    value: countryTerms.joined(separator: " "),
                    display: canonical
                ))
            }
            let region = site.region.trimmingCharacters(in: .whitespacesAndNewlines)
            if !region.isEmpty {
                fields.append(.init(label: "Region", value: region))
            }
        }
        if let month = GlobalSearchDiveIndexing.monthName(for: seed.startTime, monthSymbols: monthSymbols) {
            fields.append(.init(label: "Dive month", value: month))
        }
        if let year = GlobalSearchDiveIndexing.yearString(for: seed.startTime) {
            fields.append(.init(label: "Dive year", value: year))
        }
        if let notes = activity?.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            fields.append(.init(label: "Notes", value: notes, isSnippet: true))
        }
        if let number = seed.diveNumber {
            fields.append(.init(label: "Dive number", value: "#\(number)"))
        }

        return fields
    }

    /// Common names of species tagged on this dive; prefers the linked catalog row, else resolves the
    /// denormalized `marineLifeUUID` against the loaded species catalog.
    @MainActor
    private static func diveSightingCommonNames(
        for activity: DiveActivity,
        speciesNameByUUID: [String: String]
    ) -> [String] {
        activity.marineLifeSightings.compactMap { sighting in
            if let name = sighting.marineLife?.commonName,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
            return speciesNameByUUID[sighting.marineLifeUUID]
        }
    }

    /// Display titles of trips this dive is linked to (resolved by relationship or denormalized id).
    @MainActor
    private static func diveLinkedTripTitles(
        for activity: DiveActivity,
        tripTitleByID: [UUID: String]
    ) -> [String] {
        activity.tripActivityLinks.compactMap { link in
            if let title = link.trip?.displayTitle,
               !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return title
            }
            guard let tripID = link.tripID else { return nil }
            return tripTitleByID[tripID]
        }
    }
}

/// Builds the unified dive-site search index — OpenDiveMap reference rows plus SwiftData catalog sites
/// (same coverage as **Explore → All Sites**, including logbook-linked supplemental sites).
enum GlobalSearchSiteIndexSeeding: Sendable {
    nonisolated static func entries(
        diveSites: [DiveSite],
        ownerActivities: [DiveActivity],
        ownerProfileID: UUID?,
        reference: [DiveSiteReferenceSnapshot] = DiveSiteReferenceCatalog.bundledReference()
    ) -> [GlobalSearchPresentation.DiveSiteIndexEntry] {
        let catalogByReferenceID = ExploreSiteScopePresentation.catalogSiteByOpenDiveMapID(diveSites)
        let logbookSiteIDs = ExploreSiteScopePresentation.logbookSiteIDs(
            ownerActivities: ownerActivities,
            ownerProfileID: ownerProfileID
        )
        var entries: [GlobalSearchPresentation.DiveSiteIndexEntry] = []
        var indexedCatalogIDs = Set<UUID>()

        for snapshot in reference {
            if let catalogSite = catalogByReferenceID[snapshot.id] {
                entries.append(catalogSiteEntry(for: catalogSite))
                indexedCatalogIDs.insert(catalogSite.id)
            } else {
                entries.append(referenceSiteEntry(for: snapshot))
            }
        }

        let supplementalSites = ExploreSiteScopePresentation.supplementalLogbookCatalogSites(
            catalog: diveSites,
            logbookSiteIDs: logbookSiteIDs,
            reference: reference
        )
        for site in supplementalSites where !indexedCatalogIDs.contains(site.id) {
            entries.append(catalogSiteEntry(for: site))
            indexedCatalogIDs.insert(site.id)
        }

        for site in diveSites where !indexedCatalogIDs.contains(site.id) {
            entries.append(catalogSiteEntry(for: site))
            indexedCatalogIDs.insert(site.id)
        }

        return entries
    }

    nonisolated private static func catalogSiteEntry(for site: DiveSite) -> GlobalSearchPresentation.DiveSiteIndexEntry {
        let displayName = DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site) ?? site.siteName
        let canonicalCountry = DiveSiteCountryPresentation.canonicalDisplayName(for: site.country)
        return GlobalSearchPresentation.DiveSiteIndexEntry(
            title: displayName,
            subtitle: ExploreDiveSiteListDisplay.placeSummary(
                country: canonicalCountry,
                region: site.region,
                bodyOfWater: site.bodyOfWater
            ),
            searchHaystacks: ExploreDiveSiteListSearch.searchHaystacks(for: site),
            destination: .diveSite(site.id)
        )
    }

    nonisolated private static func referenceSiteEntry(
        for snapshot: DiveSiteReferenceSnapshot
    ) -> GlobalSearchPresentation.DiveSiteIndexEntry {
        let displayName = DiveSiteCatalogMatcher.sanitizedReferenceDisplayName(snapshot.name) ?? snapshot.name
        let canonicalCountry = DiveSiteCountryPresentation.canonicalDisplayName(for: snapshot.country)
        return GlobalSearchPresentation.DiveSiteIndexEntry(
            title: displayName,
            subtitle: ExploreDiveSiteListDisplay.placeSummary(
                country: canonicalCountry,
                region: snapshot.seaName,
                bodyOfWater: snapshot.seaName
            ),
            searchHaystacks: ExploreReferenceSiteListSearch.searchHaystacks(for: snapshot),
            destination: .referenceSite(snapshot.id)
        )
    }
}
