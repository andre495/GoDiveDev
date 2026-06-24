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
    @State private var speciesHeroMediaSource: FieldGuideSpeciesHeroMediaSource = .taggedUserMedia
    @State private var catalogHeroDisplay: FieldGuideSpeciesCatalogHeroDisplay = .image
    @State private var heroTaggedMediaID: UUID?

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

    private var heroTaggedMedia: DiveMediaPhoto? {
        FieldGuideSpeciesHeroPresentation.resolvedTaggedMedia(
            selectedID: heroTaggedMediaID,
            in: taggedMediaItems
        )
    }

    private var showsHeroSourceToggle: Bool {
        FieldGuideSpeciesHeroPresentation.showsSourceToggle(hasTaggedMedia: !taggedMediaItems.isEmpty)
    }

    private var catalogHeroAvailability: FieldGuideSpeciesCatalogHeroAvailability {
        FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
            featureModelResourceName: species.featureModelResourceName,
            featureImageResourceName: species.featureImageResourceName,
            featureImageURL: species.featureImageURL
        )
    }

    private var resolvedCatalogHeroDisplay: FieldGuideSpeciesCatalogHeroDisplay {
        FieldGuideSpeciesHeroPresentation.resolvedCatalogHeroDisplay(
            selection: catalogHeroDisplay,
            availability: catalogHeroAvailability
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
                speciesHeroChromeOverlay
            }
        )
        .onAppear {
            DiveMediaScopeCache.shared.activateScope(.marineLifeSpecies(species.uuid))
            syncSpeciesHeroPresentation(applyDefaultSource: true)
        }
        .onDisappear {
            DiveMediaScopeCache.shared.deactivateScope(.marineLifeSpecies(species.uuid))
        }
        .onChange(of: mapPins.count) { _, count in
            if count == 0, speciesHeroMode == .map {
                speciesHeroMode = .media
            }
        }
        .onChange(of: taggedMediaItems.map(\.id)) { _, _ in
            syncSpeciesHeroPresentation(applyDefaultSource: false)
        }
    }

    private var showsHeroSourceToggleInChrome: Bool {
        showsHeroSourceToggle && speciesHeroMode == .media
    }

    private var speciesHeroChromeOverlay: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if showsHeroSourceToggleInChrome, let previewContent = heroSourceTogglePreviewContent {
                FieldGuideSpeciesHeroSourceToggle(
                    diameter: FieldGuideSpeciesHeroPresentation.sourceToggleDiameter,
                    previewContent: previewContent,
                    accessibilityLabel: FieldGuideSpeciesHeroPresentation.sourceToggleAccessibilityLabel(
                        currentSource: speciesHeroMediaSource,
                        commonName: species.commonName
                    ),
                    accessibilityIdentifier: "FieldGuide.SpeciesDetail.Hero.SourceToggle"
                ) {
                    let nextSource = FieldGuideSpeciesHeroPresentation.toggledSource(
                        speciesHeroMediaSource
                    )
                    speciesHeroMediaSource = nextSource
                    if nextSource == .catalogReference {
                        resetCatalogHeroDisplay()
                    }
                }
                .padding(.leading, DiveBuddyDetailPresentation.avatarLeadingInset)
            }

            Spacer(minLength: 0)

            if showsHeroModeToggle {
                PushedDetailHeroModeToggle(
                    selectedMode: $speciesHeroMode,
                    accessibilityIdentifierPrefix: "FieldGuide.SpeciesDetail.Hero.ModeToggle"
                )
                .padding(.trailing, AppTheme.Spacing.md)
            }
        }
        .padding(.bottom, DiveBuddyDetailPresentation.heroModeToggleBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var heroSourceTogglePreviewContent: FieldGuideSpeciesHeroSourceToggle.PreviewContent? {
        switch speciesHeroMediaSource {
        case .taggedUserMedia:
            return .catalogReference(
                featureModelResourceName: species.featureModelResourceName,
                featureImageResourceName: species.featureImageResourceName,
                featureImageURL: species.featureImageURL
            )
        case .catalogReference:
            guard let heroTaggedMedia else { return nil }
            return .taggedUserMedia(heroTaggedMedia)
        }
    }

    private func syncSpeciesHeroPresentation(applyDefaultSource: Bool) {
        guard !taggedMediaItems.isEmpty else {
            heroTaggedMediaID = nil
            speciesHeroMediaSource = .catalogReference
            resetCatalogHeroDisplay()
            return
        }

        let hadTaggedMediaSelected = heroTaggedMediaID != nil
        syncHeroTaggedMediaSelection()

        if applyDefaultSource || !hadTaggedMediaSelected {
            speciesHeroMediaSource = FieldGuideSpeciesHeroPresentation.defaultMediaSource(
                hasTaggedMedia: true
            )
        }

        if speciesHeroMediaSource == .catalogReference {
            resetCatalogHeroDisplay()
        }
    }

    private func resetCatalogHeroDisplay() {
        catalogHeroDisplay = FieldGuideSpeciesHeroPresentation.defaultCatalogHeroDisplay(
            availability: catalogHeroAvailability
        )
    }

    private func toggleCatalogHeroDisplayIfNeeded() {
        guard speciesHeroMediaSource == .catalogReference,
              speciesHeroMode == .media,
              catalogHeroAvailability.supportsHeaderToggle
        else { return }

        catalogHeroDisplay = FieldGuideSpeciesHeroPresentation.toggledCatalogHeroDisplay(
            catalogHeroDisplay
        )
    }

    private func syncHeroTaggedMediaSelection() {
        guard !taggedMediaItems.isEmpty else {
            heroTaggedMediaID = nil
            return
        }
        if let heroTaggedMediaID,
           taggedMediaItems.contains(where: { $0.id == heroTaggedMediaID }) {
            return
        }
        heroTaggedMediaID = FieldGuideSpeciesHeroPresentation.initialTaggedMediaPhotoID(
            from: taggedMediaItems
        )
    }

    @ViewBuilder
    private func speciesHeroContent(context: BlueSheetHeaderPageLayoutContext) -> some View {
        Group {
            switch speciesHeroMode {
            case .media:
                speciesMediaHeroContent(height: context.heroHeight)
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
    private func speciesMediaHeroContent(height: CGFloat) -> some View {
        switch speciesHeroMediaSource {
        case .taggedUserMedia:
            taggedUserMediaHero(height: height)
        case .catalogReference:
            speciesCatalogHero(height: height)
        }
    }

    @ViewBuilder
    private func taggedUserMediaHero(height: CGFloat) -> some View {
        Group {
            if let media = heroTaggedMedia {
                DiveActivityMediaItemView(
                    media: media,
                    showsCaptureDateOverlay: false,
                    isVideoPlaybackActive: speciesHeroMode == .media
                        && DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: media),
                    loopsVideoPlayback: true
                )
                .id(media.id)
            } else if !taggedMediaItems.isEmpty {
                AppTheme.Colors.surfaceMuted.opacity(0.35)
                    .accessibilityLabel("Loading tagged media")
            } else {
                speciesCatalogHero(height: height)
            }
        }
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.Hero.TaggedMedia")
    }

    @ViewBuilder
    private func speciesCatalogHero(height: CGFloat) -> some View {
        let availability = catalogHeroAvailability
        let display = resolvedCatalogHeroDisplay

        Group {
            switch display {
            case .model3D:
                FieldGuideMarineLifeRealityHeroView(
                    configuration: FieldGuideMarineLifeHeroPresentation.sceneConfiguration(
                        forModelResourceName: species.featureModelResourceName
                    ),
                    height: height
                )
            case .image:
                FieldGuideMarineLifeCatalogImage(
                    imageURLString: species.featureImageURL,
                    bundleResourceName: species.featureImageResourceName,
                    placement: .detailHero(totalHeight: height)
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleCatalogHeroDisplayIfNeeded()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            FieldGuideSpeciesHeroPresentation.catalogHeroHeaderAccessibilityLabel(
                display: display,
                supportsToggle: availability.supportsHeaderToggle
            )
        )
        .accessibilityAddTraits(availability.supportsHeaderToggle ? .isButton : [])
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
