import SwiftData
import SwiftUI

/// Swipable dive-site detail pages — dive details → dives here → marine life → tagged media.
struct ExploreDiveSiteDetailContentPager: View {
    let displayRecord: DiveSiteDisplayRecord
    let siteDiveRows: [DiveLogbookRowDisplayData]
    let sightedSpeciesLinks: [DiveSiteMarineLifePresentation.SightedSpeciesLinkData]
    let taggedMediaItems: [DiveMediaPhoto]
    let taggedMediaTimeZoneOffsetByID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let mediaSightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    @Binding var gallerySelectedMediaID: UUID?
    let bottomScrollInset: CGFloat
    let onOpenDive: (UUID) -> Void
    var onPageFirstMounted: ((ExploreDiveSiteDetailContentPage) -> Void)? = nil

    @State private var selectedPage: ExploreDiveSiteDetailContentPage =
        ExploreDiveSiteDetailContentPagerPresentation.defaultPage

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "Explore.DiveSiteDetail.ContentPager",
            pages: ExploreDiveSiteDetailContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            onPageFirstMounted: onPageFirstMounted,
            pageLayout: ExploreDiveSiteDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageContent(for page: ExploreDiveSiteDetailContentPage) -> some View {
        switch page {
        case .diveDetails:
            diveDetailsContent
        case .divesHere:
            divesHereContent
        case .marineLifeHere:
            marineLifeHereContent
        case .taggedMedia:
            taggedMediaContent
        }
    }

    @ViewBuilder
    private var diveDetailsContent: some View {
        ExploreDiveSiteDetailMetadataView(
            record: displayRecord,
            hiddenDetailLabels: ["Rating"]
        )
        .accessibilityIdentifier("Explore.DiveSiteDetail.DiveDetails")
    }

    @ViewBuilder
    private var divesHereContent: some View {
        if siteDiveRows.isEmpty {
            emptyState(for: .divesHere)
        } else {
            LinkedDiveLogbookListRows(
                rows: siteDiveRows,
                listAccessibilityIdentifier: "Explore.DiveSiteDetail.DivesHere.List",
                onOpenDive: onOpenDive
            )
            .accessibilityIdentifier("Explore.DiveSiteDetail.DivesHere")
        }
    }

    @ViewBuilder
    private var marineLifeHereContent: some View {
        if sightedSpeciesLinks.isEmpty {
            emptyState(for: .marineLifeHere)
        } else {
            ExploreDiveSiteMarineLifeListSection(
                speciesLinks: sightedSpeciesLinks,
                listAccessibilityIdentifier: "Explore.DiveSiteDetail.MarineLifeHere.List"
            )
            .accessibilityIdentifier("Explore.DiveSiteDetail.MarineLifeHere")
        }
    }

    @ViewBuilder
    private var taggedMediaContent: some View {
        if taggedMediaItems.isEmpty {
            emptyState(for: .taggedMedia)
        } else {
            ExploreDiveSiteTaggedMediaGridSection(
                mediaItems: taggedMediaItems,
                timeZoneOffsetByMediaID: taggedMediaTimeZoneOffsetByID,
                linkedMediaItems: linkedMediaItems,
                sightings: mediaSightings,
                marineLifeCatalog: marineLifeCatalog,
                ownerProfileID: ownerProfileID,
                gallerySelectedMediaID: $gallerySelectedMediaID,
                onOpenDive: onOpenDive
            )
        }
    }

    private func emptyState(for page: ExploreDiveSiteDetailContentPage) -> some View {
        Text(ExploreDiveSiteDetailContentPagerPresentation.emptyStateMessage(for: page))
            .font(.body)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(emptyStateAccessibilityIdentifier(for: page))
    }

    private func emptyStateAccessibilityIdentifier(for page: ExploreDiveSiteDetailContentPage) -> String {
        switch page {
        case .diveDetails:
            return "Explore.DiveSiteDetail.DiveDetails.Empty"
        case .divesHere:
            return "Explore.DiveSiteDetail.DivesHere.Empty"
        case .marineLifeHere:
            return "Explore.DiveSiteDetail.MarineLifeHere.Empty"
        case .taggedMedia:
            return "Explore.DiveSiteDetail.TaggedMedia.Empty"
        }
    }
}
