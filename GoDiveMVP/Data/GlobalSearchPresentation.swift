import Foundation

/// Unified app-wide search — indexes dives, sites, species, people, trips, gear, and certs.
enum GlobalSearchPresentation: Sendable {

    nonisolated static let searchPrompt = "Search GoDive"
    nonisolated static let rootAccessibilityIdentifier = "GlobalSearch.Root"
    nonisolated static let resultsListAccessibilityIdentifier = "GlobalSearch.ResultsList"
    nonisolated static let resultsBackButtonAccessibilityIdentifier = "GlobalSearch.ResultsBack"
    nonisolated static let maxHitsPerSection = 12
    /// When a context token is active with no typed query, list up to this many matches in that category.
    nonisolated static let maxScopedBrowseHits = 500
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
            }
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
            case .certifications: return "crustaceans"
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

        /// Bottom inset so the **2×4** grid ends just above the morphed tab search field.
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

        nonisolated static func backButtonReservedWidth(
            horizontalPadding: CGFloat = ResultsSectionHeaderPresentation.horizontalPadding,
            backButtonTapWidth: CGFloat = ResultsSectionHeaderPresentation.backButtonTapWidth
        ) -> CGFloat {
            horizontalPadding + backButtonTapWidth
        }

        /// Top scroll margin so pinned headers sit on the back-button row. The sectioned **`List`** already
        /// respects the status-bar safe area — do not add **`safeAreaTop`** again here.
        nonisolated static func scrollContentTopMargin(chromeHeight: CGFloat) -> CGFloat {
            max(chromeHeight, 0)
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

    enum SectionKind: String, Sendable, CaseIterable, Identifiable {
        case dives
        case diveSites
        case species
        case buddies
        case tags
        case trips
        case equipment
        case certifications

        var id: String { rawValue }

        /// Multi-category search results — highest priority first.
        nonisolated static let resultSectionDisplayOrder: [SectionKind] = [
            .buddies,
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

    struct Hit: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let subtitle: String?
        let systemImage: String
        let destination: Destination
        let accessibilityIdentifier: String
    }

    struct Section: Identifiable, Sendable {
        let kind: SectionKind
        let hits: [Hit]

        var id: SectionKind { kind }
        var title: String { kind.title }
    }

    struct Results: Sendable {
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

        let maxHits = appliesTextFilter || contextTokens.isEmpty
            ? maxHitsPerSection
            : maxScopedBrowseHits

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
                        accessibilityIdentifier: "GlobalSearch.Hit.Dive.\(entry.id.uuidString)"
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

    nonisolated static func commitDismissOffset(containerWidth: CGFloat) -> CGFloat {
        max(containerWidth, 1)
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

    /// While the interactive slide-back is active (or settling), block row taps and list scroll.
    nonisolated static func blocksResultsInteraction(
        isDismissDragActive: Bool,
        dragOffset: CGFloat
    ) -> Bool {
        isDismissDragActive || dragOffset > 0.5
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
    /// Keep **`.searchable`** on the stack only at root so pushed pages match tab-stack safe area (no navigation search drawer inset).
    nonisolated static func attachesStackSearch(pathCount: Int) -> Bool {
        pathCount == 0
    }

    /// Clear navigation-layer search chrome when opening a result — not when popping back to results/category browse.
    nonisolated static func shouldDismissNavigationSearchOnPathChange(
        previousDepth: Int,
        newDepth: Int
    ) -> Bool {
        newDepth > previousDepth
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
        let diveEntries = LogbookActivitySnapshotSeeding.seeds(from: dives).map { seed in
            GlobalSearchPresentation.DiveIndexEntry(
                id: seed.id,
                title: seed.displayName,
                subtitle: seed.resolvedSiteNameLowercased?.capitalized,
                searchHaystack: CatalogSearchPresentation.joinedLowercasedHaystacks([
                    seed.displayName,
                    seed.resolvedSiteNameLowercased ?? "",
                    seed.diveNumber.map { "#\($0)" } ?? "",
                    seed.activityTagNames.joined(separator: " "),
                    seed.buddyDisplayNames.joined(separator: " "),
                ])
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
