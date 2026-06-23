import SwiftData
import SwiftUI

/// Pushed species detail from **Field Guide** (replaces sheet presentation).
struct FieldGuideMarineLifeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.openCatalogDiveSiteDetail) private var openCatalogDiveSiteDetail
    @Environment(AccountSession.self) private var accountSession

    @Query private var userRecords: [MarineLifeUserRecord]
    @Query private var ownerDiveActivities: [DiveActivity]
    @Query private var taggedSightings: [SightingInstance]
    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]

    let species: MarineLife
    let onOpenDive: (UUID) -> Void

    @State private var speciesHeroMode: PushedDetailHeroHeaderView.Mode = .media

    init(
        species: MarineLife,
        ownerProfileID: UUID?,
        onOpenDive: @escaping (UUID) -> Void
    ) {
        self.species = species
        self.onOpenDive = onOpenDive
        let marineLifeUUID = species.uuid
        let ownerFilterID = ownerProfileID ?? Self.noOwnerQueryToken
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == ownerFilterID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _taggedSightings = Query(
            filter: #Predicate<SightingInstance> { $0.marineLifeUUID == marineLifeUUID },
            sort: [SortDescriptor(\.sightingDateTime, order: .reverse)]
        )
    }

    private var ownerDiveActivityIDs: Set<UUID> {
        Set(ownerDiveActivities.map(\.id))
    }

    private var taggedMediaItems: [DiveMediaPhoto] {
        FieldGuideTaggedMediaPresentation.resolvedTaggedMediaPhotos(
            sightings: taggedSightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            modelContext: modelContext
        )
    }

    private var taggedMediaTimeZoneOffsetByID: [UUID: Int?] {
        let offsetByActivityID = Dictionary(
            uniqueKeysWithValues: ownerDiveActivities.map { ($0.id, $0.timeZoneOffsetSeconds) }
        )
        return FieldGuideTaggedMediaPresentation.timeZoneOffsetByMediaID(
            sightings: taggedSightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            timeZoneOffsetByActivityID: offsetByActivityID
        )
    }

    private var linkedMediaItems: [TripDetailLinkedMediaItem] {
        FieldGuideTaggedMediaPresentation.linkedMediaItems(
            sightings: taggedSightings,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            mediaItems: taggedMediaItems
        )
    }

    private var sightedActivityIDs: [UUID] {
        guard let ownerID = accountSession.currentProfile?.id,
              let record = MarineLifeUserRecordOwnership.userRecord(
                  marineLifeUUID: species.uuid,
                  ownerProfileID: ownerID,
                  in: userRecords
              )
        else { return [] }
        return record.activitiesSightedOn
    }

    private var sightedDives: [DiveActivity] {
        let idSet = Set(sightedActivityIDs)
        return ownerDiveActivities.filter { idSet.contains($0.id) }
    }

    private var mapPins: [TripDetailMapPin] {
        FieldGuideSpeciesDetailMapPresentation.pins(
            from: sightedDives,
            catalogSites: diveSites
        )
    }

    private var showsHeroModeToggle: Bool {
        !mapPins.isEmpty
    }

    private var taggedDiveRows: [DiveLogbookRowDisplayData] {
        FieldGuidePresentation.sightedDiveRowDisplayData(
            activityIDs: sightedActivityIDs,
            activities: ownerDiveActivities,
            unitSystem: diveDisplayUnitSystem
        )
    }

    private var categoryAccentColor: Color {
        FieldGuideCategoryAccent.gradientTop(
            FieldGuideTaxonomy.resolvedCategoryID(for: species.fieldGuideCatalogSnapshot)
        )
    }

    var body: some View {
        FieldGuideBlueSheetPage(
            accessibilityRootIdentifier: "FieldGuide.SpeciesDetail.Root",
            scrollAccessibilityIdentifier: nil,
            hero: { context in
                speciesHeroContent(context: context)
            },
            pinnedContent: {
                titleBlock
            },
            panelContent: { bottomScrollInset in
                FieldGuideSpeciesDetailContentPager(
                    aboutText: species.aboutText,
                    typicalSizeLine: FieldGuidePresentation.sizeRangeLine(
                        minMeters: species.minSizeMeters,
                        maxMeters: species.maxSizeMeters,
                        unitSystem: diveDisplayUnitSystem
                    ),
                    depthLine: FieldGuidePresentation.depthLine(
                        minMeters: species.minDepthMeters,
                        maxMeters: species.maxDepthMeters,
                        avgMeters: species.avgDepthMeters,
                        unitSystem: diveDisplayUnitSystem
                    ),
                    depthRowTitle: depthRowTitle,
                    distinctiveFeatures: species.distinctiveFeatures,
                    taggedDiveRows: taggedDiveRows,
                    taggedMediaItems: taggedMediaItems,
                    taggedMediaTimeZoneOffsetByID: taggedMediaTimeZoneOffsetByID,
                    linkedMediaItems: linkedMediaItems,
                    mediaSightings: taggedSightings,
                    marineLifeCatalog: [species],
                    ownerProfileID: accountSession.currentProfile?.id,
                    bottomScrollInset: bottomScrollInset,
                    onOpenDive: onOpenDive
                )
                .padding(.horizontal, AppTheme.Spacing.md)
            },
            heroOverlay: { _ in
                if showsHeroModeToggle {
                    PushedDetailHeroModeToggle(
                        selectedMode: $speciesHeroMode,
                        accessibilityIdentifierPrefix: "FieldGuide.SpeciesDetail.Hero.ModeToggle"
                    )
                    .padding(.trailing, AppTheme.Spacing.md)
                    .padding(.bottom, DiveBuddyDetailPresentation.heroModeToggleBottomPadding)
                }
            }
        )
        .onAppear {
            DiveMediaScopeCache.shared.activateScope(.marineLifeSpecies(species.uuid))
        }
        .onDisappear {
            DiveMediaScopeCache.shared.deactivateScope(.marineLifeSpecies(species.uuid))
        }
        .onChange(of: mapPins.count) { _, count in
            if count == 0, speciesHeroMode == .map {
                speciesHeroMode = .media
            }
        }
    }

    @ViewBuilder
    private func speciesHeroContent(context: BlueSheetHeaderPageLayoutContext) -> some View {
        Group {
            switch speciesHeroMode {
            case .media:
                speciesCatalogHero(height: context.heroHeight)
            case .map:
                TripDetailMapView(
                    pins: mapPins,
                    fitLayout: context.mapFitLayout(),
                    onSiteSelected: openDiveSiteFromMap
                )
                .accessibilityIdentifier("FieldGuide.SpeciesDetail.Hero.Map")
            }
        }
        .frame(height: context.heroHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.Hero")
    }

    @ViewBuilder
    private func speciesCatalogHero(height: CGFloat) -> some View {
        Group {
            switch FieldGuideMarineLifeHeroPresentation.heroKind(
                featureModelResourceName: species.featureModelResourceName,
                featureImageResourceName: species.featureImageResourceName,
                featureImageURL: species.featureImageURL
            ) {
            case .model3D(let configuration):
                FieldGuideMarineLifeRealityHeroView(
                    configuration: configuration,
                    height: height
                )
            case .bundledPhoto, .remoteImage:
                FieldGuideMarineLifeCatalogImage(
                    imageURLString: species.featureImageURL,
                    bundleResourceName: species.featureImageResourceName,
                    placement: .detailHero(totalHeight: height)
                )
            case .placeholder:
                FieldGuideMarineLifeCatalogImage(
                    imageURLString: "",
                    placement: .detailHero(totalHeight: height)
                )
            }
        }
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.Hero.Catalog")
    }

    private func openDiveSiteFromMap(_ siteID: UUID) {
        if let openCatalogDiveSiteDetail {
            openCatalogDiveSiteDetail(siteID)
        }
    }

    private var taxonomyLabel: String {
        let snapshot = species.fieldGuideCatalogSnapshot
        let category = FieldGuideTaxonomy.categoryTitle(for: snapshot)
        let subcategory = FieldGuideTaxonomy.subcategoryTitle(for: snapshot)
        if subcategory != "—" {
            return "\(category) · \(subcategory)"
        }
        return category == "—" ? "" : category
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if !taxonomyLabel.isEmpty {
                Text(taxonomyLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(categoryAccentColor)
            }

            Text(species.commonName)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if !species.scientificName.isEmpty {
                Text(species.scientificName)
                    .font(.title3.italic())
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var depthRowTitle: String {
        species.minDepthMeters > 0 && species.maxDepthMeters > 0 ? "Depth range" : "Avg depth"
    }

    /// Sentinel **`ownerProfileID`** so **`@Query`** returns no dives when signed out.
    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}
