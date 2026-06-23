import SwiftData
import SwiftUI

/// Swipable buddy detail pages — dives together → trips together → tagged media.
struct DiveBuddyDetailContentPager: View {
    let diveRows: [DiveLogbookRowDisplayData]
    let tripRows: [DiveBuddyTripRowDisplayData]
    let taggedMediaItems: [DiveMediaPhoto]
    let taggedMediaTimeZoneOffsetByID: [UUID: Int?]
    let linkedMediaItems: [TripDetailLinkedMediaItem]
    let mediaSightings: [SightingInstance]
    let marineLifeCatalog: [MarineLife]
    let ownerProfileID: UUID?
    let featuredTaggedMediaPhotoID: UUID?
    @Binding var gallerySelectedMediaID: UUID?
    let bottomScrollInset: CGFloat
    let onToggleFeaturedTaggedMedia: (() -> Void)?

    @State private var selectedPage: DiveBuddyDetailContentPage = DiveBuddyDetailContentPagerPresentation.defaultPage
    @State private var mountedPages: Set<DiveBuddyDetailContentPage> = [
        DiveBuddyDetailContentPagerPresentation.defaultPage,
    ]

    private var pages: [DiveBuddyDetailContentPage] {
        DiveBuddyDetailContentPagerPresentation.pages
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
        .accessibilityIdentifier("DiveBuddyDetails.ContentPager")
        .onAppear {
            mountedPages.insert(selectedPage)
        }
        .onChange(of: selectedPage) { _, page in
            mountedPages.insert(page)
        }
    }

    @ViewBuilder
    private func pageScrollableContent(for page: DiveBuddyDetailContentPage) -> some View {
        if !mountedPages.contains(page) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        } else {
            mountedPageScrollableContent(for: page)
        }
    }

    @ViewBuilder
    private func mountedPageScrollableContent(for page: DiveBuddyDetailContentPage) -> some View {
        switch page {
        case .divesTogether:
            divesTogetherContent
        case .tripsTogether:
            tripsTogetherContent
        case .taggedMedia:
            taggedMediaContent
        }
    }

    @ViewBuilder
    private var divesTogetherContent: some View {
        if diveRows.isEmpty {
            emptyState(for: .divesTogether)
        } else {
            LinkedDiveLogbookListRows(
                rows: diveRows,
                listAccessibilityIdentifier: "DiveBuddyDetails.DiveList"
            )
            .accessibilityIdentifier("DiveBuddyDetails.DivesTogether")
        }
    }

    @ViewBuilder
    private var tripsTogetherContent: some View {
        if tripRows.isEmpty {
            emptyState(for: .tripsTogether)
        } else {
            DiveBuddyTripListRows(
                rows: tripRows,
                listAccessibilityIdentifier: "DiveBuddyDetails.TripList"
            )
            .accessibilityIdentifier("DiveBuddyDetails.TripsTogether")
        }
    }

    @ViewBuilder
    private var taggedMediaContent: some View {
        if taggedMediaItems.isEmpty {
            emptyState(for: .taggedMedia)
        } else {
            DiveBuddyTaggedMediaGridSection(
                mediaItems: taggedMediaItems,
                timeZoneOffsetByMediaID: taggedMediaTimeZoneOffsetByID,
                linkedMediaItems: linkedMediaItems,
                featuredMediaPhotoID: featuredTaggedMediaPhotoID,
                gallerySelectedMediaID: $gallerySelectedMediaID,
                onToggleFeaturedTaggedMedia: onToggleFeaturedTaggedMedia
            )
            .accessibilityIdentifier("DiveBuddyDetails.TaggedMedia")
        }
    }

    private func emptyState(for page: DiveBuddyDetailContentPage) -> some View {
        Text(DiveBuddyDetailContentPagerPresentation.emptyStateMessage(for: page))
            .font(.body)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(emptyStateAccessibilityIdentifier(for: page))
    }

    private func emptyStateAccessibilityIdentifier(for page: DiveBuddyDetailContentPage) -> String {
        switch page {
        case .divesTogether:
            return "DiveBuddyDetails.EmptyDives"
        case .tripsTogether:
            return "DiveBuddyDetails.EmptyTrips"
        case .taggedMedia:
            return "DiveBuddyDetails.EmptyTaggedMedia"
        }
    }

    @ViewBuilder
    private func pagerScrollPage(_ page: DiveBuddyDetailContentPage) -> some View {
        Group {
            if DiveBuddyDetailContentPagerPresentation.usesStaticPagerLayout(for: page) {
                let contentAlignment = DiveBuddyDetailContentPagerPresentation.staticPagerContentAlignment(for: page)
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
        .accessibilityLabel(DiveBuddyDetailContentPagerPresentation.pageTitle(for: page))
        .accessibilityIdentifier(DiveBuddyDetailContentPagerPresentation.accessibilityIdentifier(for: page))
    }
}
