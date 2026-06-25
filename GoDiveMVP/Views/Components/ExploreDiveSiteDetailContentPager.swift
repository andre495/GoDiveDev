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
    @State private var mountedPages: Set<ExploreDiveSiteDetailContentPage> = [
        ExploreDiveSiteDetailContentPagerPresentation.defaultPage,
    ]

    private var pages: [ExploreDiveSiteDetailContentPage] {
        ExploreDiveSiteDetailContentPagerPresentation.pages
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(pages) { page in
                PushedDetailContentPagerLayout.tabPage {
                    pagerScrollPage(page)
                }
                .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .bottom)
        .accessibilityIdentifier("Explore.DiveSiteDetail.ContentPager")
        .onAppear {
            notePageFirstMounted(selectedPage)
        }
        .onChange(of: selectedPage) { _, page in
            notePageFirstMounted(page)
        }
    }

    private func notePageFirstMounted(_ page: ExploreDiveSiteDetailContentPage) {
        let inserted = mountedPages.insert(page).inserted
        guard inserted else { return }
        onPageFirstMounted?(page)
    }

    @ViewBuilder
    private func pageScrollableContent(for page: ExploreDiveSiteDetailContentPage) -> some View {
        if !mountedPages.contains(page) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        } else {
            mountedPageScrollableContent(for: page)
        }
    }

    @ViewBuilder
    private func mountedPageScrollableContent(for page: ExploreDiveSiteDetailContentPage) -> some View {
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

    @ViewBuilder
    private func pagerScrollPage(_ page: ExploreDiveSiteDetailContentPage) -> some View {
        Group {
            if ExploreDiveSiteDetailContentPagerPresentation.usesStaticPagerLayout(for: page) {
                let contentAlignment = ExploreDiveSiteDetailContentPagerPresentation
                    .staticPagerContentAlignment(for: page)
                pageScrollableContent(for: page)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)

                Color.clear
                    .frame(height: bottomScrollInset)
                    .accessibilityHidden(true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        pageScrollableContent(for: page)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Color.clear
                            .frame(height: bottomScrollInset)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollClipDisabled(false)
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .homeSheetPanelBottomScrollFade()
        .accessibilityLabel(ExploreDiveSiteDetailContentPagerPresentation.pageTitle(for: page))
        .accessibilityIdentifier(ExploreDiveSiteDetailContentPagerPresentation.accessibilityIdentifier(for: page))
    }
}
