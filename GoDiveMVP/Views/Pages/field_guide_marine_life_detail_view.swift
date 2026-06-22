import SwiftData
import SwiftUI

/// Pushed species detail from **Field Guide** (replaces sheet presentation).
struct FieldGuideMarineLifeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(AccountSession.self) private var accountSession

    @Query private var userRecords: [MarineLifeUserRecord]
    @Query private var ownerDiveActivities: [DiveActivity]
    @Query private var taggedSightings: [SightingInstance]

    let species: MarineLife
    let onOpenDive: (UUID) -> Void

    @State private var headerClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

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

    private var sightedActivityLinks: [FieldGuidePresentation.SightedActivityLinkData] {
        guard let ownerID = accountSession.currentProfile?.id,
              let record = MarineLifeUserRecordOwnership.userRecord(
                  marineLifeUUID: species.uuid,
                  ownerProfileID: ownerID,
                  in: userRecords
              ),
              !record.activitiesSightedOn.isEmpty
        else { return [] }

        let snapshots = ownerDiveActivities.map {
            DiveActivitySightingLinkSnapshot(
                id: $0.id,
                diveSiteID: $0.diveSiteID,
                resolvedSiteName: $0.resolvedSiteName,
                startTime: $0.startTime,
                timeZoneOffsetSeconds: $0.timeZoneOffsetSeconds
            )
        }
        return FieldGuidePresentation.sightedActivityLinks(
            activityIDs: record.activitiesSightedOn,
            activities: snapshots
        )
    }

    var body: some View {
        AppHeaderlessPage {
            GeometryReader { proxy in
                let safeTop = AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(proxy.safeAreaInsets.top)
                let topInset = AppScrollUnderHeaderListLayout.listTopInset(
                    safeAreaTop: safeTop,
                    headerClearance: headerClearance
                )

                ZStack(alignment: .top) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            heroImage(extraTopInset: safeTop)

                            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                                titleBlock
                                statsBlock
                                naturalHistorySections
                                if !species.aboutText.isEmpty {
                                    aboutBlock
                                }
                                if !taggedMediaItems.isEmpty {
                                    FieldGuideTaggedMediaGalleryView(
                                        mediaItems: taggedMediaItems,
                                        timeZoneOffsetByMediaID: taggedMediaTimeZoneOffsetByID
                                    )
                                }
                                if !sightedActivityLinks.isEmpty {
                                    activitiesSightedOnSection
                                }
                            }
                            .padding(AppTheme.Spacing.md)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .ignoresSafeArea(edges: .top)

                    LogbookTopChromeScrim(topObstructionHeight: topInset)
                        .padding(.top, -safeTop)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                        .zIndex(0.5)

                    Color.clear
                        .frame(height: topInset)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .contentShape(Rectangle())
                        .accessibilityHidden(true)
                        .zIndex(0.75)

                    AppHeader(
                        title: "",
                        showsBackButton: true,
                        showsBrandWordmark: false,
                        statusBarSafeAreaTop: safeTop
                    ) {
                        EmptyView()
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .zIndex(1)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    if height > 0 { headerClearance = height }
                }
            }
        }
        .hidesBottomTabBarWhenPushed()
        .onAppear {
            DiveMediaScopeCache.shared.activateScope(.marineLifeSpecies(species.uuid))
        }
        .onDisappear {
            DiveMediaScopeCache.shared.deactivateScope(.marineLifeSpecies(species.uuid))
        }
        .accessibilityIdentifier("FieldGuide.SpeciesDetail.Root")
    }

    @ViewBuilder
    private func heroImage(extraTopInset: CGFloat) -> some View {
        let height = FieldGuideMarineLifeImageLayout.detailHeroBaseHeight + extraTopInset
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
                heroPlaceholder
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    private var heroPlaceholder: some View {
        FieldGuideMarineLifeCatalogImage(
            imageURLString: "",
            placement: .detailHero(totalHeight: FieldGuideMarineLifeImageLayout.detailHeroBaseHeight)
        )
    }

    private var taxonomyLabel: some View {
        let snapshot = species.fieldGuideCatalogSnapshot
        let category = FieldGuideTaxonomy.categoryTitle(for: snapshot)
        let subcategory = FieldGuideTaxonomy.subcategoryTitle(for: snapshot)
        let label = subcategory != "—" ? "\(category) · \(subcategory)" : category
        return Group {
            if label != "—" {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(species.commonName)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            if !species.scientificName.isEmpty {
                Text(species.scientificName)
                    .font(.title3.italic())
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            taxonomyLabel
            if !species.familyName.isEmpty {
                Text(species.familyName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            detailRow(
                title: "Typical size",
                value: FieldGuidePresentation.sizeRangeLine(
                    minMeters: species.minSizeMeters,
                    maxMeters: species.maxSizeMeters,
                    unitSystem: diveDisplayUnitSystem
                )
            )
            detailRow(
                title: depthRowTitle,
                value: FieldGuidePresentation.depthLine(
                    minMeters: species.minDepthMeters,
                    maxMeters: species.maxDepthMeters,
                    avgMeters: species.avgDepthMeters,
                    unitSystem: diveDisplayUnitSystem
                )
            )
        }
    }

    private var depthRowTitle: String {
        species.minDepthMeters > 0 && species.maxDepthMeters > 0 ? "Depth range" : "Avg depth"
    }

    @ViewBuilder
    private var naturalHistorySections: some View {
        if !species.distinctiveFeatures.isEmpty {
            textSection(title: "Distinctive features", body: species.distinctiveFeatures)
        }
        if !species.abundance.isEmpty {
            textSection(title: "Abundance", body: species.abundance)
        }
        if !species.habitatBehavior.isEmpty {
            textSection(title: "Habitat & behavior", body: species.habitatBehavior)
        }
        if !species.diverReaction.isEmpty {
            textSection(title: "Diver reaction", body: species.diverReaction)
        }
    }

    private func textSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(body)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activitiesSightedOnSection: some View {
        ExpandableDetailSection(
            title: "Activities sighted on",
            itemCount: sightedActivityLinks.count,
            accessibilityIdentifier: "FieldGuide.SpeciesDetail.ActivitiesSightedOn"
        ) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(sightedActivityLinks) { link in
                    Button {
                        onOpenDive(link.id)
                    } label: {
                        sightedActivityRow(link)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("FieldGuide.SpeciesDetail.DiveLink.\(link.id.uuidString)")
                }
            }
        }
    }

    private func sightedActivityRow(_ link: FieldGuidePresentation.SightedActivityLinkData) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(link.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(link.dateText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(link.title), \(link.dateText)")
        .accessibilityHint("Opens this dive")
    }

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("About")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(species.aboutText)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer(minLength: AppTheme.Spacing.sm)
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    /// Sentinel **`ownerProfileID`** so **`@Query`** returns no dives when signed out.
    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}
