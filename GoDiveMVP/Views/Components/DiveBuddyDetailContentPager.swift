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
    let onOpenDive: (UUID) -> Void
    var onPageFirstMounted: ((DiveBuddyDetailContentPage) -> Void)? = nil

    @State private var selectedPage: DiveBuddyDetailContentPage =
        DiveBuddyDetailContentPagerPresentation.defaultPage

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "DiveBuddyDetails.ContentPager",
            pages: DiveBuddyDetailContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            onPageFirstMounted: onPageFirstMounted,
            pageLayout: DiveBuddyDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageContent(for page: DiveBuddyDetailContentPage) -> some View {
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
                listAccessibilityIdentifier: "DiveBuddyDetails.DiveList",
                onOpenDive: onOpenDive
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
}
