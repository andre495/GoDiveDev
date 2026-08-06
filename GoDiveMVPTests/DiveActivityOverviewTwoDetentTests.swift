import CoreGraphics
import Testing
@testable import GoDiveMVP

@Suite struct DiveActivityOverviewTwoDetentTests {

    @Test func overviewDetent_hasOnlyMinimizedAndLarge() {
        #expect(DiveActivityOverviewDetent.allCases == [.minimized, .large])
        #expect(DiveActivityOverviewDetent.defaultSelection == .large)
    }

    @Test @MainActor func largeHeightFraction_matchesBlueSheetSeamOnReferenceLayout() {
        HomeOverviewLayoutAnchor.resetForTesting()
        defer { HomeOverviewLayoutAnchor.resetForTesting() }

        let context = DiveActivityOverviewSheetLayoutContext.presentationReference
        let seam = HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
        #expect(seam.showsBuddyLeaderboard)
        let heroHeight = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: context.layoutHeight,
            screenWidth: context.screenWidth,
            topSafeAreaInset: context.topSafeInset,
            statsPanelContentHeight: seam.statsPanelContentHeight,
            showsBuddyLeaderboard: seam.showsBuddyLeaderboard
        ).heroHeight
        let expectedSeam = HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .buddyDetail,
            geometryHeight: context.layoutHeight,
            heroHeight: heroHeight
        )
        let sheetHeight = DiveActivityOverviewDetent.sheetHeight(
            for: .large,
            layoutHeight: context.layoutHeight,
            bottomSafeInset: context.bottomSafeInset,
            screenWidth: context.screenWidth,
            topSafeInset: context.topSafeInset
        )
        #expect(abs(sheetHeight - expectedSeam) < 0.5)

        // Regression: 2×2-only band left the activity panel shorter than Home / buddy / site sheets.
        let twoByTwoOnlyHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: context.layoutHeight,
            screenWidth: context.screenWidth,
            topSafeAreaInset: context.topSafeInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
            showsBuddyLeaderboard: false
        ).heroHeight
        let twoByTwoOnlySeam = HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .buddyDetail,
            geometryHeight: context.layoutHeight,
            heroHeight: twoByTwoOnlyHero
        )
        #expect(sheetHeight > twoByTwoOnlySeam + 1)

        #expect(DiveActivityOverviewPanelMetrics.minimizedHeightFraction == 0.20)
        #expect(
            DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
                > DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        )
    }

    @Test func detentSnap_isTwoStepOnly() {
        #expect(DiveActivityOverviewDetent.minimized.nextTaller() == .large)
        #expect(DiveActivityOverviewDetent.large.nextShorter() == .minimized)
        #expect(DiveActivityOverviewDetent.large.nextTaller() == nil)
    }

    @Test func panelMetrics_snappedHeightFractionAfterDrag_skipsHalfScreen() {
        let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
        #expect(
            DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                currentFraction: minimized,
                predictedFraction: large,
                verticalTranslation: -80
            ) == large
        )
        #expect(
            DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                currentFraction: large,
                predictedFraction: minimized,
                verticalTranslation: 80
            ) == minimized
        )
    }

    @Test func presentationDetent_roundTripsOnReferenceLayout() {
        for detent in DiveActivityOverviewDetent.allCases {
            let presentation = detent.presentationDetent
            #expect(DiveActivityOverviewDetent(presentationDetent: presentation) == detent)
        }
    }

    @Test @MainActor func overviewPanelModal_usesActivityLargeDetentHeight() {
        let context = DiveActivityOverviewSheetLayoutContext.presentationReference
        let modal = DiveActivityOverviewDetent.overviewPanelModalLargePresentationDetent(
            context: context
        )
        let activityLarge = DiveActivityOverviewDetent.large.presentationDetent(
            screenHeight: context.layoutHeight,
            screenWidth: context.screenWidth,
            topSafeInset: context.topSafeInset,
            bottomSafeInset: context.bottomSafeInset
        )
        #expect(modal == activityLarge)
        #expect(
            DiveActivityOverviewDetent(
                presentationDetent: modal,
                screenHeight: context.layoutHeight,
                screenWidth: context.screenWidth,
                topSafeInset: context.topSafeInset,
                bottomSafeInset: context.bottomSafeInset
            ) == .large
        )
    }
}
