//
//  NavigationPresentationTests.swift
//  GoDiveMVPTests
//

import CloudKit
import Contacts
import AuthenticationServices
import CoreGraphics
import CoreLocation
import Foundation
import MapKit
import os
import SwiftUI
#if canImport(Photos)
import Photos
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
import SwiftData
import Testing
#if canImport(PencilKit)
import PencilKit
#endif
#if os(iOS)
import UIKit
#endif
@testable import GoDiveMVP


struct NavigationPresentationTests {
        @Test func pushedNavigationDeferralPresentation_afterPushDelay_matchesTripAutoLinkDeferral() {
            #expect(PushedNavigationDeferralPresentation.afterPushDelay == .milliseconds(300))
        }

        @Test func navigationStackPushCoalescing_append_blocksDuplicateTopRoute() {
            enum Route: Equatable {
                case dive(UUID)
                case profile
            }
            let diveID = UUID()
            var path: [Route] = []
            #expect(NavigationStackPushCoalescing.append(.dive(diveID), to: &path))
            #expect(path == [.dive(diveID)])
            #expect(!NavigationStackPushCoalescing.append(.dive(diveID), to: &path))
            #expect(path == [.dive(diveID)])
            #expect(NavigationStackPushCoalescing.append(.profile, to: &path))
            #expect(path == [.dive(diveID), .profile])
            #expect(NavigationStackPushCoalescing.append(.dive(diveID), to: &path))
            #expect(path == [.dive(diveID), .profile, .dive(diveID)])
        }

        @Test func navigationStackPushCoalescing_coalesce_removesConsecutiveDuplicates() {
            enum Route: Equatable {
                case a
                case b
            }
            #expect(
                NavigationStackPushCoalescing.coalescedByRemovingConsecutiveDuplicates([Route.a, .a, .b, .b, .a])
                    == [.a, .b, .a]
            )
            #expect(NavigationStackPushCoalescing.coalescedByRemovingConsecutiveDuplicates([Route.a]) == [.a])
            #expect(NavigationStackPushCoalescing.coalescedByRemovingConsecutiveDuplicates([Route]()) == [])
        }

        @Test func navigationStackPushCoalescing_assignIfNil_isNoOpWhenBusy() {
            var current: String? = "open"
            #expect(!NavigationStackPushCoalescing.assignIfNil("next", to: &current))
            #expect(current == "open")
            current = nil
            #expect(NavigationStackPushCoalescing.assignIfNil("next", to: &current))
            #expect(current == "next")
        }

        @Test func navigationStackPushCoalescing_assignUnlessDuplicate_allowsDifferentDestination() {
            var current: String? = "leaderboard"
            #expect(!NavigationStackPushCoalescing.assignUnlessDuplicate("leaderboard", to: &current))
            #expect(current == "leaderboard")
            #expect(NavigationStackPushCoalescing.assignUnlessDuplicate("dive", to: &current))
            #expect(current == "dive")
        }

        @Test func activityDeleteSuccessPresentation_overlayDuration_isOneSecond() {
            #expect(ActivityDeleteSuccessPresentation.overlayDuration == .seconds(1))
            #expect(!ActivityDeleteSuccessPresentation.checkmarkAccessibilityLabel.isEmpty)
        }

        @Test @MainActor func activityDeleteSuccessPresentation_logbookPathByRemovingActivity_dropsDetailAndMedia() {
            let keep = UUID()
            let remove = UUID()
            let path: [LogbookRoute] = [
                .tripPlanner,
                .diveDetail(remove),
                .snorkelDetail(keep),
                .diveMedia(remove, mediaID: UUID()),
                .snorkelMedia(remove, mediaID: UUID()),
                .friends,
            ]
            let filtered = ActivityDeleteSuccessPresentation.logbookPathByRemovingActivity(
                path,
                activityID: remove
            )
            #expect(filtered == [.tripPlanner, .snorkelDetail(keep), .friends])
        }

        @Test @MainActor func activityDeleteSuccessPresentation_homeAndExplorePathHelpers_dropDiveRoutes() {
            let remove = UUID()
            let keep = UUID()
            let mediaID = UUID()
            let home: [HomeRoute] = [
                .profile,
                .diveDetail(remove),
                .diveMedia(diveID: keep, mediaID: mediaID),
                .ownedSharedActivity(activityID: remove, activityKind: .scubaDive, opensComments: true),
                .ownedSharedActivity(activityID: keep, activityKind: .snorkel, opensComments: false),
            ]
            #expect(
                ActivityDeleteSuccessPresentation.homePathByRemovingActivity(home, activityID: remove)
                    == [
                        .profile,
                        .diveMedia(diveID: keep, mediaID: mediaID),
                        .ownedSharedActivity(activityID: keep, activityKind: .snorkel, opensComments: false),
                    ]
            )
            let explore: [ExploreRoute] = [.siteDetail(keep), .diveDetail(remove), .diveDetail(keep)]
            #expect(
                ActivityDeleteSuccessPresentation.explorePathByRemovingActivity(explore, activityID: remove)
                    == [.siteDetail(keep), .diveDetail(keep)]
            )
            let search: [GlobalSearchPresentation.Destination] = [
                .dive(remove),
                .snorkel(remove),
                .snorkel(keep),
                .buddy(keep),
            ]
            #expect(
                ActivityDeleteSuccessPresentation.searchPathByRemovingActivity(search, activityID: remove)
                    == [.snorkel(keep), .buddy(keep)]
            )
        }

        @Test func pushedNavigationDeferralPresentation_afterPushMapDeferral_matchesAfterPushDelay() {
            #expect(
                PushedNavigationDeferralPresentation.afterPushMapDeferral
                    == PushedNavigationDeferralPresentation.afterPushDelay
            )
        }

        @Test func blueSheetDetailPageConfiguration_standardDefaults() {
            let config = BlueSheetDetailPageConfiguration.standard(
                accessibilityRootIdentifier: "GoDive.TestDetail"
            )
            #expect(config.accessibilityRootIdentifier == "GoDive.TestDetail")
            #expect(config.presentation == .pushedDetail)
            #expect(config.showsHero)
            #expect(config.hidesTabBarWhenPushed)
            #expect(!config.usesProfileBubblePanelBackground)
        }

        @Test func blueSheetDetailPageConfiguration_pushedDetailWithStandardPanelBodySpacing() {
            let config = BlueSheetDetailPageConfiguration.pushedDetailWithStandardPanelBodySpacing(
                accessibilityRootIdentifier: "GoDive.CatalogDetail"
            )
            #expect(config.presentation == .pushedDetail)
            #expect(config.pinnedSummaryBottomPadding == BlueSheetDetailPagePinnedSummaryPresentation.pushedDetailPinnedSummaryBottomPadding)
        }

        @Test func blueSheetDetailPageConfiguration_tabRoot() {
            let config = BlueSheetDetailPageConfiguration.tabRoot(
                accessibilityRootIdentifier: "GoDive.Home"
            )
            #expect(config.presentation == .tabRoot)
            #expect(config.showsHero)
            #expect(!config.hidesTabBarWhenPushed)
            #expect(!config.usesProfileBubblePanelBackground)
        }

        @Test func blueSheetDetailPageConfiguration_profileBubblePanelBackground() {
            let config = BlueSheetDetailPageConfiguration.pushedDetail(
                accessibilityRootIdentifier: "Profile.Root",
                usesProfileBubblePanelBackground: true
            )
            #expect(config.usesProfileBubblePanelBackground)
        }

        @Test func blueSheetPagePresentation_pageLayoutKind() {
            #expect(BlueSheetPagePresentation.tabRoot.pageLayoutKind == .home)
            #expect(BlueSheetPagePresentation.pushedDetail.pageLayoutKind == .buddyDetail)
        }

        @Test func blueSheetPageProportions_reexportHomeOverviewLayoutTokens() {
            #expect(BlueSheetPageProportions.panelOverlap == HomeOverviewLayout.panelOverlap)
            #expect(BlueSheetPageProportions.blueSheetPanelScale == HomeOverviewLayout.blueSheetPanelScale)
            #expect(BlueSheetPageProportions.heroHeightToWidthRatio == HomeOverviewLayout.heroHeightToWidthRatio)
            #expect(BlueSheetPageProportions.heroBottomExtension == HomeOverviewLayout.heroBottomExtension)
            #expect(BlueSheetPageProportions.tabBarScrollInset == HomeOverviewLayout.tabBarScrollInset)
            #expect(BlueSheetPageProportions.rootTabBarLayoutHeight == HomeOverviewLayout.rootTabBarLayoutHeight)
        }

        @Test func blueSheetPageLayoutBuilder_tabRootMatchesPushedHeroHeightWhenViewportAligned() {
            let pushedGeometryHeight: CGFloat = 852
            let homeTabViewportHeight = HomeOverviewLayout.viewportHeightMatchingHomeTab(
                from: pushedGeometryHeight
            )
            let screenWidth: CGFloat = 393
            let topSafeAreaInset: CGFloat = 59
            let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
                statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
                showsBuddyLeaderboard: false
            )

            let tabRootHero = BlueSheetPageLayoutBuilder.heroHeight(
                geometryHeight: homeTabViewportHeight,
                screenWidth: screenWidth,
                rawGeometrySafeTop: topSafeAreaInset,
                layoutSafeAreaTopFloor: 0,
                seamInputs: seamInputs,
                mode: .tabRoot(isNavigationStackAtRoot: true, frozenRootViewportHeight: homeTabViewportHeight)
            )
            let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
                geometryHeight: pushedGeometryHeight,
                screenWidth: screenWidth,
                rawGeometrySafeTop: topSafeAreaInset,
                layoutSafeAreaTopFloor: 0,
                seamInputs: seamInputs,
                mode: .pushedDetail(transitionViewportHeightFloor: 0)
            )
            #expect(tabRootHero == pushedHero)
        }

        @Test func blueSheetPageLayoutBuilder_tabRootHeroHeightMatchesPushedDetail() {
            let tabContentGeometryHeight: CGFloat = 803
            let pushedGeometryHeight = tabContentGeometryHeight + HomeOverviewLayout.rootTabBarLayoutHeight
            let screenWidth: CGFloat = 393
            let topSafeAreaInset: CGFloat = 59
            let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
                statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
                showsBuddyLeaderboard: false
            )

            let tabRootHero = BlueSheetPageLayoutBuilder.heroHeight(
                geometryHeight: tabContentGeometryHeight,
                screenWidth: screenWidth,
                rawGeometrySafeTop: topSafeAreaInset,
                layoutSafeAreaTopFloor: 0,
                seamInputs: seamInputs,
                mode: .tabRoot(isNavigationStackAtRoot: true, frozenRootViewportHeight: nil)
            )
            let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
                geometryHeight: pushedGeometryHeight,
                screenWidth: screenWidth,
                rawGeometrySafeTop: topSafeAreaInset,
                layoutSafeAreaTopFloor: 0,
                seamInputs: seamInputs,
                mode: .pushedDetail(transitionViewportHeightFloor: 0)
            )
            #expect(tabRootHero == pushedHero)
        }

        @Test func rootTabBarLayoutMeasurement_estimatedClearanceAboveTabBar() {
            #expect(RootTabBarLayoutMeasurement.estimatedClearanceAboveTabBar(safeAreaBottom: 0) == 49)
            #expect(
                RootTabBarLayoutMeasurement.resolvedPanelBottomSafeAreaInset(
                    measuredTabBarClearance: 72,
                    safeAreaBottom: 0
                ) == 72
            )
        }

        @Test func blueSheetPageLayoutBuilder_tabRootStackUsesDetailFullScreenFrame() {
            let tabContentGeometryHeight: CGFloat = 803
            let pushedGeometryHeight = tabContentGeometryHeight + HomeOverviewLayout.rootTabBarLayoutHeight
            let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
                statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
                showsBuddyLeaderboard: false
            )

            let tabRootHero = BlueSheetPageLayoutBuilder.heroHeight(
                geometryHeight: tabContentGeometryHeight,
                screenWidth: 393,
                rawGeometrySafeTop: 59,
                layoutSafeAreaTopFloor: 0,
                seamInputs: seamInputs,
                mode: .tabRoot(isNavigationStackAtRoot: true, frozenRootViewportHeight: nil)
            )
            let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
                geometryHeight: pushedGeometryHeight,
                screenWidth: 393,
                rawGeometrySafeTop: 59,
                layoutSafeAreaTopFloor: 0,
                seamInputs: seamInputs,
                mode: .pushedDetail(transitionViewportHeightFloor: 0)
            )
            #expect(tabRootHero == pushedHero)

            let tabRootStack = HomeTabRootLayoutPresentation.stackFrameHeight(
                from: tabContentGeometryHeight
            )
            let pushedStack = HomeOverviewLayout.pushedPageLayoutHeight(from: pushedGeometryHeight)
            #expect(tabRootStack == pushedStack)
            #expect(tabRootStack == pushedGeometryHeight)
        }

        @Test @MainActor func blueSheetPageLayoutBuilder_pushedHeroUsesPublishedHomeAnchor() {
            HomeOverviewLayoutAnchor.resetForTesting()
            defer { HomeOverviewLayoutAnchor.resetForTesting() }

            let screenWidth: CGFloat = 393
            let topSafeAreaInset: CGFloat = 59
            let anchoredHeroHeight: CGFloat = 312
            let homeTabViewportHeight = HomeOverviewLayout.viewportHeightMatchingHomeTab(from: 852)
            let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
                statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
                showsBuddyLeaderboard: false
            )

            HomeOverviewLayoutAnchor.publish(
                HomeOverviewLayoutAnchor.RootSnapshot(
                    heroHeight: anchoredHeroHeight,
                    screenWidth: screenWidth,
                    topSafeAreaInset: topSafeAreaInset,
                    statsPanelContentHeight: seamInputs.statsPanelContentHeight,
                    showsBuddyLeaderboard: seamInputs.showsBuddyLeaderboard,
                    homeTabViewportHeight: homeTabViewportHeight
                )
            )

            let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
                geometryHeight: 852,
                screenWidth: screenWidth,
                rawGeometrySafeTop: topSafeAreaInset,
                layoutSafeAreaTopFloor: 0,
                seamInputs: seamInputs,
                mode: .pushedDetail(transitionViewportHeightFloor: 0)
            )
            #expect(pushedHero == anchoredHeroHeight)
        }

        @Test func blueSheetDetailPagePinnedSummaryPresentation_usesThemeSpacing() {
            let presentation = BlueSheetDetailPagePinnedSummaryPresentation.self
            #expect(presentation.horizontalPadding == AppTheme.Spacing.lg)
            #expect(presentation.seamTopPadding == AppTheme.Spacing.md)
            #expect(presentation.bodyBottomPadding == AppTheme.Spacing.md)
            #expect(presentation.panelBodyTopSpacingAdjustment == 30)
            #expect(presentation.panelContentTopDividerVerticalAdjustment == -21)
            #expect(presentation.panelContentTopPadding == AppTheme.Spacing.md)
            #expect(
                presentation.pushedDetailPinnedSummaryBottomPadding
                    == presentation.bodyBottomPadding
                    + presentation.panelBodyTopSpacingAdjustment
                    + presentation.panelContentTopDividerVerticalAdjustment
            )
            #expect(presentation.pinnedRowSpacing == AppTheme.Spacing.sm)
            #expect(presentation.topPadding == presentation.seamTopPadding)
            #expect(presentation.bottomPadding == presentation.bodyBottomPadding)
            #expect(presentation.pinnedSummaryAccessibilitySuffix == "PinnedSummary")
        }

        @Test func blueSheetDetailPanelContentTopDividerPresentation_usesHairlineHeight() {
            #expect(BlueSheetDetailPanelContentTopDividerPresentation.lineHeight == 1)
        }

        @Test func blueSheetTopChromePresentation_homeHeaderPassesHitsThroughEmptyChrome() {
            #expect(!BlueSheetTopChromePresentation.homeHeaderBlocksHitsInEmptyChrome)
        }

        @Test func blueSheetTopChromePresentation_homeHeroUsesLogbookScrimFeather() {
            #expect(BlueSheetTopChromePresentation.HomeHeroFade.usesBrandStatusBarScrim)
            #expect(BlueSheetTopChromePresentation.HomeHeroFade.logbookScrimFeather == 52)
        }

        @Test func blueSheetTopChromePresentation_detailTopUsesListFeather() {
            #expect(BlueSheetTopChromePresentation.DetailTopFade.usesListStatusBarScrim)
            #expect(BlueSheetTopChromePresentation.DetailTopFade.statusBarFeather == 22)
        }

        @Test func blueSheetTopChromePresentation_homeProfileAvatarDiameter_isTwentyPercentLarger() {
            #expect(BlueSheetTopChromePresentation.homeProfileAvatarDiameter == 48 * 1.2)
        }

        @Test func appHeaderBrandRowMetrics_wordmarkLineHeight_tracksLargeTitle() {
            #if os(iOS)
            let expected = ceil(UIFont.preferredFont(forTextStyle: .largeTitle).lineHeight)
            #expect(AppHeaderBrandRowMetrics.wordmarkLineHeight == expected)
            #endif
        }

        @Test func blueSheetPinnedSummaryPresentation_rowSpacingUsesTheme() {
            #expect(
                BlueSheetPinnedSummaryPresentation.rowSpacing
                    == BlueSheetDetailPagePinnedSummaryPresentation.pinnedRowSpacing
            )
            #expect(BlueSheetPinnedSummaryPresentation.rowSpacing == AppTheme.Spacing.sm)
        }

        @Test func blueSheetDetailPagePinnedSummaryPresentation_shellHorizontalPaddingMatchesPagerInset() {
            #expect(BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding == AppTheme.Spacing.lg)
        }

        @Test func blueSheetDetailHeroPresentation_placeholderTokens() {
            #expect(BlueSheetDetailHeroPresentation.placeholderFillOpacity == 0.12)
            #expect(BlueSheetDetailHeroPresentation.placeholderIconSize == 56)
            #expect(BlueSheetDetailHeroPresentation.loadingBandOpacity == 0.35)
        }

        @Test func blueSheetDetailPageConfiguration_pushedDetailDefaultsToShowsHero() {
            let config = BlueSheetDetailPageConfiguration.pushedDetail(
                accessibilityRootIdentifier: "Test.Hero"
            )
            #expect(config.showsHero)
        }

        @Test func blueSheetDetailPagerPresentation_tripScrollInsetExtraUsesThemeSpacing() {
            #expect(BlueSheetDetailPagerPresentation.tripScrollBottomInsetExtra == AppTheme.Spacing.lg)
            #expect(BlueSheetDetailPagerPresentation.scrollPageSpacing == AppTheme.Spacing.lg)
            #expect(BlueSheetDetailPagerPresentation.pinnedPageHeaderBottomSpacing == AppTheme.Spacing.md)
        }

        @Test func blueSheetHeaderPageLayoutBuilder_heroHeight_matchesPushedHeroLayoutMetrics() {
            let geometryHeight: CGFloat = 852
            let screenWidth: CGFloat = 390
            let topSafeAreaInset: CGFloat = 59
            let statsBand = HomeOverviewLayout.heroLayoutStatsPanelContentHeight
            let transitionFloor = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(from: 803)

            let viaBuilder = BlueSheetHeaderPageLayoutBuilder.heroHeight(
                geometryHeight: geometryHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset,
                statsPanelContentHeight: statsBand,
                showsBuddyLeaderboard: false,
                transitionViewportFloor: transitionFloor
            )
            let direct = HomeOverviewLayout.pushedHeroLayoutMetrics(
                geometryHeight: geometryHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset,
                statsPanelContentHeight: statsBand,
                showsBuddyLeaderboard: false,
                transitionViewportFloor: transitionFloor
            ).heroHeight
            #expect(viaBuilder == direct)
        }

        @Test func rootTabOwnerDiveQueryPresentation_mountsOnlyWhenSelectedOrDiveOnPath() {
            #expect(
                !RootTabOwnerDiveQueryPresentation.shouldMountLiveOwnerDiveQuery(
                    isTabSelected: false,
                    pathContainsDiveDetail: false
                )
            )
            #expect(
                RootTabOwnerDiveQueryPresentation.shouldMountLiveOwnerDiveQuery(
                    isTabSelected: true,
                    pathContainsDiveDetail: false
                )
            )
            #expect(
                RootTabOwnerDiveQueryPresentation.shouldMountLiveOwnerDiveQuery(
                    isTabSelected: false,
                    pathContainsDiveDetail: true
                )
            )
            #expect(
                !RootTabOwnerDiveQueryPresentation.shouldPublishOwnerDiveIndex(
                    isTabSelected: false,
                    activityCount: 12
                )
            )
            #expect(
                !RootTabOwnerDiveQueryPresentation.shouldPublishOwnerDiveIndex(
                    isTabSelected: true,
                    activityCount: 0
                )
            )
            #expect(
                RootTabOwnerDiveQueryPresentation.shouldPublishOwnerDiveIndex(
                    isTabSelected: true,
                    activityCount: 3
                )
            )
            #expect(
                RootTabOwnerDiveQueryPresentation.shouldScheduleSearchIndexMount(
                    isSearchTabSelected: true,
                    isSearchIndexMounted: false
                )
            )
            #expect(
                !RootTabOwnerDiveQueryPresentation.shouldScheduleSearchIndexMount(
                    isSearchTabSelected: false,
                    isSearchIndexMounted: false
                )
            )
            #expect(
                !RootTabOwnerDiveQueryPresentation.shouldScheduleSearchIndexMount(
                    isSearchTabSelected: true,
                    isSearchIndexMounted: true
                )
            )
        }

        @Test func rootTab_logbook_matchesContentViewTabOrder() {
            #expect(RootTabIndex.home == 0)
            #expect(RootTabIndex.logbook == 1)
            #expect(RootTabIndex.fieldGuide == 2)
            #expect(RootTabIndex.explore == 3)
        }

        @Test @MainActor func appHeaderStackedTitleChrome_usesCenteredPrimaryTextBelowBackRow() {
            #expect(AppHeaderStackedTitleChrome.titlePlacement == .belowBackRow)
            #expect(AppHeaderStackedTitleChrome.titleMultilineAlignment == .center)
        }

        @Test func rootTabBarMinimizeScrollPresentation_associatesOnlySelectedFeedScope() {
            #expect(
                RootTabBarMinimizeScrollPresentation.shouldAssociate(
                    pageScope: .myActivities,
                    selectedScope: .myActivities
                )
            )
            #expect(
                !RootTabBarMinimizeScrollPresentation.shouldAssociate(
                    pageScope: .buddyFeed,
                    selectedScope: .myActivities
                )
            )
            #expect(
                RootTabBarMinimizeScrollPresentation.shouldAssociate(
                    pageScope: .buddyFeed,
                    selectedScope: .buddyFeed
                )
            )
            #expect(
                RootTabBarMinimizeScrollPresentation.disablesContentInsetAdjustmentForScrollUnderTabBar
            )
        }

        @Test func rootTabBarMinimizeScrollPresentation_skipsHorizontalPagingScrollers() {
            #expect(
                RootTabBarMinimizeScrollPresentation.isEligibleVerticalContentScrollView(
                    isTableView: true,
                    isPagingEnabled: true,
                    contentWidth: 300,
                    boundsWidth: 100,
                    contentHeight: 100,
                    boundsHeight: 100
                )
            )
            #expect(
                !RootTabBarMinimizeScrollPresentation.isEligibleVerticalContentScrollView(
                    isTableView: false,
                    isPagingEnabled: true,
                    contentWidth: 300,
                    boundsWidth: 100,
                    contentHeight: 100,
                    boundsHeight: 100
                )
            )
            #expect(
                RootTabBarMinimizeScrollPresentation.isEligibleVerticalContentScrollView(
                    isTableView: false,
                    isPagingEnabled: false,
                    contentWidth: 100,
                    boundsWidth: 100,
                    contentHeight: 400,
                    boundsHeight: 100
                )
            )
            #expect(
                !RootTabBarMinimizeScrollPresentation.isEligibleVerticalContentScrollView(
                    isTableView: false,
                    isPagingEnabled: false,
                    contentWidth: 400,
                    boundsWidth: 100,
                    contentHeight: 100,
                    boundsHeight: 100
                )
            )
        }

        @MainActor
        @Test func rootTabBarMinimizeScrollAssociator_prefersNestedTableOverHorizontalPager() {
            let horizontal = UIScrollView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
            horizontal.isPagingEnabled = true
            horizontal.contentSize = CGSize(width: 300, height: 200)

            let table = UITableView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
            let probe = UIView(frame: .zero)
            table.addSubview(probe)
            horizontal.addSubview(table)

            let found = RootTabBarMinimizeScrollAssociator.findVerticalContentScrollView(startingFrom: probe)
            #expect(found === table)
        }

        @Test func rootTabSelection_bubblePause_followsLiveSelection() {
            #expect(RootTabSelectionPresentation.shouldPauseBubbles(for: .fieldGuide, selected: .home))
            #expect(!RootTabSelectionPresentation.shouldPauseBubbles(for: .fieldGuide, selected: .fieldGuide))
            #expect(RootTabSelectionPresentation.shouldPauseBubbles(for: .logbook, selected: .explore))
            #expect(!RootTabSelectionPresentation.shouldPauseBubbles(for: .logbook, selected: .logbook))
            #expect(RootTabSelectionPresentation.isSelected(.explore, selected: .explore))
            #expect(!RootTabSelectionPresentation.isSelected(.explore, selected: .search))
            #expect(
                RootTabSelectionPresentation.shouldPublishSelectionChange(
                    previous: .home,
                    next: .explore
                )
            )
            #expect(
                !RootTabSelectionPresentation.shouldPublishSelectionChange(
                    previous: .explore,
                    next: .explore
                )
            )
            #expect(
                RootTabSelectionPresentation.localSelectionAfterMount(
                    tab: .logbook,
                    storeSelected: .logbook
                )
            )
            #expect(
                !RootTabSelectionPresentation.localSelectionAfterMount(
                    tab: .logbook,
                    storeSelected: .home
                )
            )
            #expect(
                RootTabSelectionPresentation.localSelection(
                    tab: .explore,
                    from: Notification(
                        name: .rootTabSelectionDidChange,
                        object: nil,
                        userInfo: [RootTabBarSelectionSync.userInfoTabKey: RootTab.explore]
                    )
                ) == true
            )
            #expect(
                RootTabSelectionPresentation.localSelection(
                    tab: .explore,
                    from: Notification(
                        name: .rootTabSelectionDidChange,
                        object: nil,
                        userInfo: [RootTabBarSelectionSync.userInfoTabKey: RootTab.home]
                    )
                ) == false
            )
        }

        @Test func rootTabBarSelectionSync_selectionDidChangeNotification_carriesTab() {
            let expected = RootTab.fieldGuide
            let received = OSAllocatedUnfairLock<RootTab?>(initialState: nil)
            let token = NotificationCenter.default.addObserver(
                forName: .rootTabSelectionDidChange,
                object: nil,
                queue: nil
            ) { notification in
                received.withLock { $0 = RootTabBarSelectionSync.tab(from: notification) }
            }
            defer { NotificationCenter.default.removeObserver(token) }
            RootTabBarSelectionSync.postSelectionDidChange(expected)
            #expect(received.withLock { $0 } == expected)
        }

        @Test func appHeaderMetrics_heightKey_reduceUsesMax() {
            var value: CGFloat = 2
            AppHeaderMetrics.HeightKey.reduce(value: &value) { 5 }
            #expect(value == 5)
            AppHeaderMetrics.HeightKey.reduce(value: &value) { 3 }
            #expect(value == 5)
        }

        @Test func leadingEdgeSwipePopGate_commitsWhenHorizontalSwipeFromEdge() {
            #expect(
                GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                    startLocationX: 8,
                    translation: CGSize(width: 100, height: 20)
                )
            )
        }

        @Test func leadingEdgeSwipePopGate_rejectsWhenTooFarFromLeading() {
            #expect(
                !GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                    startLocationX: 200,
                    translation: CGSize(width: 100, height: 20)
                )
            )
        }

        @Test func leadingEdgeSwipePopGate_rejectsWhenHorizontalDragTooShort() {
            #expect(
                !GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                    startLocationX: 10,
                    translation: CGSize(width: 40, height: 10)
                )
            )
        }

        @Test func leadingEdgeSwipePopGate_rejectsWhenVerticalDominant() {
            #expect(
                !GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                    startLocationX: 10,
                    translation: CGSize(width: 100, height: 200)
                )
            )
        }
}
