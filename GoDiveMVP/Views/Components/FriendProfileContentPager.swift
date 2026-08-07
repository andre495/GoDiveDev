import SwiftUI

/// Friend profile sheet pager — diver stats → shared activities → shared media.
struct FriendProfileContentPager: View {
    let lifetimeStats: HomeLifetimeStats
    let unitSystem: DiveDisplayUnitSystem
    let sharedActivityRows: [DiveLogbookRowDisplayData]
    let sharedMediaItems: [FriendSharedMediaPresentation.DisplayItem]
    let sharedMediaDiveByMediaID: [String: GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    let isLoadingSharedContent: Bool
    @Binding var activityFilter: FriendProfileActivityListFilter
    @Binding var fullscreenSelectedMediaID: String?
    let bottomScrollInset: CGFloat
    let onOpenDive: (UUID) -> Void
    var onOpenActivityFromMedia: ((GoDiveSharedDiveProjectionMapping.FriendVisibleDive) -> Void)? = nil

    @State private var selectedPage: FriendProfileContentPage =
        FriendProfileContentPagerPresentation.defaultPage

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "FriendProfile.ContentPager",
            pages: FriendProfileContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            pageLayout: FriendProfileContentPagerPresentation.pagerPageLayout(for:),
            pageHeader: pageHeader(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageHeader(for page: FriendProfileContentPage) -> some View {
        switch page {
        case .diverStats:
            EmptyView()
        case .sharedActivities:
            BlueSheetDetailPinnedPageHeader(
                title: FriendProfileContentPagerPresentation.sharedActivitiesPageTitle,
                accessibilityIdentifier:
                    FriendProfileSharedDiveListPresentation.sectionSubtitleAccessibilityIdentifier
            ) {
                FriendProfileActivityFilterToggle(selection: $activityFilter)
            }
        case .sharedMedia:
            BlueSheetDetailPinnedPageHeader(
                title: FriendProfileContentPagerPresentation.sharedMediaPageTitle,
                accessibilityIdentifier: FriendProfileSharedMediaListPresentation.sectionAccessibilityIdentifier
                    + ".Title"
            )
        }
    }

    @ViewBuilder
    private func pageContent(for page: FriendProfileContentPage) -> some View {
        switch page {
        case .diverStats:
            diverStatsContent
        case .sharedActivities:
            FriendProfileSharedDivesPanel(
                rows: sharedActivityRows,
                isLoading: isLoadingSharedContent,
                filter: activityFilter,
                onOpenDive: onOpenDive
            )
        case .sharedMedia:
            FriendProfileSharedMediaPanel(
                items: sharedMediaItems,
                diveByMediaID: sharedMediaDiveByMediaID,
                isLoading: isLoadingSharedContent,
                fullscreenSelectedMediaID: $fullscreenSelectedMediaID,
                onOpenActivity: onOpenActivityFromMedia
            )
        }
    }

    private var diverStatsContent: some View {
        HomeLifetimeStatsSection(
            stats: lifetimeStats,
            myActivitiesSummary: .empty,
            buddyLeaderboard: [],
            unitSystem: unitSystem,
            onOpenLeaderboard: { _ in },
            onOpenBuddy: { _ in },
            includesBuddyLeaderboard: FriendProfileContentPagerPresentation.showsBuddyLeaderboardOnDiverStats,
            includesLifetimeSummaryHeader: FriendProfileContentPagerPresentation.showsLifetimeSummaryOnDiverStats,
            opensLeaderboards: FriendProfileContentPagerPresentation.opensLeaderboardsOnDiverStats,
            emptyFootnotes: .friendShared
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("FriendProfile.DiverStats")
    }
}
