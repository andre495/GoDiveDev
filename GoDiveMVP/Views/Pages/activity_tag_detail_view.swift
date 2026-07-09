import SwiftData
import SwiftUI

/// Owner activity tag detail — blue sheet with trip-style stats, dives, marine life, buddies, and media.
struct ActivityTagDetailView: View {
    @Bindable var tag: ActivityTag

    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(\.openCatalogDiveSiteDetail) private var openCatalogDiveSiteDetail
    @Environment(AccountSession.self) private var accountSession

    @AppStorage(AppUserSettings.automaticallyRenumberDivesKey) private var automaticallyRenumberDives = true

    @Query private var ownerDiveActivities: [DiveActivity]
    @Query(sort: \DiveBuddy.displayName) private var rosterBuddies: [DiveBuddy]

    @State private var contentSnapshot = ActivityTagDetailContentSnapshot.empty
    @State private var showsDeferredMap = false
    @State private var tagHeroMode: PushedDetailHeroHeaderView.Mode = .media
    @State private var heroTagMediaID: UUID?
    @State private var gallerySelectedMediaID: UUID?
    @State private var tagDiveNavigationID: TagDiveNavigationID?
    @State private var tagSiteNavigationID: UUID?

    private struct TagDiveNavigationID: Identifiable, Hashable {
        let id: UUID
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init(tag: ActivityTag) {
        self.tag = tag
        let ownerID = tag.ownerProfileID ?? AccountSession.shared.currentProfile?.id ?? Self.noOwnerQueryToken
        _ownerDiveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == ownerID },
            sort: [
                SortDescriptor(\.startTime, order: .reverse),
                SortDescriptor(\.id, order: .forward),
            ]
        )
        _rosterBuddies = Query(
            filter: #Predicate<DiveBuddy> { $0.ownerProfileID == ownerID },
            sort: [SortDescriptor(\.displayName)]
        )
    }

    private var taggedDives: [DiveActivity] {
        ActivityTagDetailPresentation.taggedDives(on: tag)
    }

    private var ownerProfileID: UUID? {
        accountSession.currentProfile?.id ?? tag.ownerProfileID
    }

    private var ownedDiveActivities: [DiveActivity] {
        guard accountSession.currentProfile != nil else { return [] }
        return ownerDiveActivities
    }

    private var tagContentToken: String {
        [
            tag.id.uuidString,
            tag.name,
            "\(taggedDives.count)",
            diveDisplayUnitSystem.rawValue,
            automaticallyRenumberDives ? "1" : "0",
        ].joined(separator: "|")
    }

    var body: some View {
        BlueSheetDetailPage(
            configuration: .pushedDetail(
                accessibilityRootIdentifier: "ActivityTagDetails.Root"
            ),
            hero: { context in
                tagHeroBandContent(context: context)
            },
            heroOverlay: { _ in
                if !contentSnapshot.mapPins.isEmpty {
                    PushedDetailHeroModeToggle(
                        selectedMode: $tagHeroMode,
                        accessibilityIdentifierPrefix: "ActivityTagDetails.Hero.ModeToggle"
                    )
                    .padding(.trailing, AppTheme.Spacing.md)
                    .padding(.bottom, ActivityTagDetailPresentation.heroModeToggleBottomPadding)
                }
            },
            panelOverlay: { EmptyView() },
            pinnedContent: {
                tagPinnedSummary
            },
            panelContent: { bottomScrollInset, _ in
                ActivityTagDetailContentPager(
                    statTiles: DiveTripStatsPresentation.highlightTiles(
                        from: contentSnapshot.aggregate,
                        unitSystem: diveDisplayUnitSystem
                    ),
                    aggregate: contentSnapshot.aggregate,
                    linkedDiveRows: contentSnapshot.linkedDiveRows,
                    marineLifeItems: contentSnapshot.marineLifeItems,
                    marineLifeCatalog: contentSnapshot.marineLifeCatalog,
                    unitSystem: diveDisplayUnitSystem,
                    ownerProfileID: ownerProfileID,
                    ownerProfile: accountSession.currentProfile,
                    rosterBuddiesByID: contentSnapshot.rosterBuddiesByID,
                    mediaItems: contentSnapshot.mediaPhotos,
                    mediaTimeZoneOffsets: contentSnapshot.mediaTimeZoneOffsets,
                    linkedMediaItems: contentSnapshot.linkedMediaItems,
                    mediaSightings: contentSnapshot.mediaSightings,
                    gallerySelectedMediaID: $gallerySelectedMediaID,
                    bottomScrollInset: bottomScrollInset,
                    onOpenDive: openTaggedDive
                )
            },
            topChrome: { safeTop, topInset, _ in
                BlueSheetDetailTopChrome(
                    safeTop: safeTop,
                    topInset: topInset,
                    isEditEnabled: false,
                    onEdit: {},
                    editAccessibilityIdentifier: "ActivityTagDetails.Edit"
                )
            }
        )
        .navigationDestination(item: $tagDiveNavigationID) { target in
            if let activity = taggedDives.first(where: { $0.id == target.id }) {
                ViewSingleActivity(activity: activity)
            }
        }
        .navigationDestination(item: $tagSiteNavigationID) { siteID in
            if let site = TripDetailDiveSiteNavigation.resolvedSite(
                siteID: siteID,
                plannedSites: [],
                catalogSites: contentSnapshot.catalogSites
            ) {
                ExploreDiveSiteDetailView(
                    site: site,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: openTaggedDive
                )
            }
        }
        .task(id: tagContentToken) {
            await Task.yield()
            rebuildTagDetailContent()
            showsDeferredMap = true
            await enrichTagDetailMarineLife()
            await warmTagHeroHeaderMediaPreviewIfNeeded()
        }
    }

    @ViewBuilder
    private var tagPinnedSummary: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Image(systemName: ActivityTagDetailPresentation.headerSystemImage)
                .font(ActivityTagDetailPresentation.pinnedHeaderIconFont)
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)

            Text(tag.name)
                .font(BlueSheetPinnedSummaryPresentation.titleFont)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ActivityTagDetails.Title")

            Text(
                ActivityTagDetailPresentation.diveCountLabel(
                    count: contentSnapshot.aggregate.diveCount
                )
            )
            .font(BlueSheetPinnedSummaryPresentation.accentFont)
            .foregroundStyle(AppTheme.Colors.accent)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .layoutPriority(1)
            .accessibilityIdentifier("ActivityTagDetails.DiveCount")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            ActivityTagDetailPresentation.pinnedHeaderAccessibilityLabel(
                tagName: tag.name,
                diveCount: contentSnapshot.aggregate.diveCount
            )
        )
        .accessibilityIdentifier("ActivityTagDetails.TitleBlock")
    }

    @ViewBuilder
    private func tagHeroBandContent(context: BlueSheetHeaderPageLayoutContext) -> some View {
        let heroFitLayout = context.mapFitLayout()
        let heroModeBinding: Binding<PushedDetailHeroHeaderView.Mode> = contentSnapshot.mapPins.isEmpty
            ? .constant(.media)
            : $tagHeroMode

        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "ActivityTagDetails.HeroBand") {
            PushedDetailHeroHeaderView(
                media: displayHeroTagMedia,
                mapPins: showsDeferredMap ? contentSnapshot.mapPins : [],
                mapFitLayout: heroFitLayout,
                height: context.heroHeight,
                isMapContentReady: showsDeferredMap,
                shouldAutoPlaySelectedVideo: ActivityTagDetailPresentation.shouldAutoPlaySelectedVideo(
                    for: displayHeroTagMedia
                ),
                style: .tag,
                onSiteSelected: openDiveSiteFromMap,
                selectedMode: heroModeBinding
            )
        }
    }

    private var displayHeroTagMedia: DiveMediaPhoto? {
        guard let heroTagMediaID,
              let media = contentSnapshot.mediaPhotos.first(where: { $0.id == heroTagMediaID })
        else { return nil }
        return media
    }

    private func rebuildTagDetailContent() {
        contentSnapshot = ActivityTagDetailContentSnapshotBuilder.buildLight(
            tag: tag,
            ownedDiveActivities: ownedDiveActivities,
            rosterBuddies: rosterBuddies,
            unitSystem: diveDisplayUnitSystem,
            useChronologicalNumbers: automaticallyRenumberDives,
            ownerProfileID: ownerProfileID
        )
        heroTagMediaID = ActivityTagDetailPresentation.initialHeroMediaPhotoID(
            tagID: tag.id,
            photos: contentSnapshot.mediaPhotos
        )
        if contentSnapshot.mediaPhotos.isEmpty, !contentSnapshot.mapPins.isEmpty {
            tagHeroMode = .map
        }
    }

    private func enrichTagDetailMarineLife() async {
        let enriched = ActivityTagDetailContentSnapshotBuilder.enrichMarineLife(
            snapshot: contentSnapshot,
            taggedDives: taggedDives,
            unitSystem: diveDisplayUnitSystem,
            modelContext: modelContext
        )
        contentSnapshot = enriched
    }

    private func warmTagHeroHeaderMediaPreviewIfNeeded() async {
        guard let hero = displayHeroTagMedia else { return }
        DiveMediaPreviewStorage.seedSessionCacheIfNeeded(for: hero)
        await DiveMediaPreviewStorage.ensureStoredPreviews(for: [hero], modelContext: modelContext)
    }

    private func openTaggedDive(_ diveID: UUID) {
        tagDiveNavigationID = TagDiveNavigationID(id: diveID)
    }

    private func openDiveSiteFromMap(_ siteID: UUID) {
        if let openCatalogDiveSiteDetail {
            openCatalogDiveSiteDetail(siteID)
        } else {
            tagSiteNavigationID = siteID
        }
    }
}
