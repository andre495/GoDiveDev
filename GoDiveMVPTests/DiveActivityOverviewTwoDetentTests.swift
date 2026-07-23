import CoreGraphics
import Testing
@testable import GoDiveMVP

@Suite struct DiveActivityOverviewTwoDetentTests {

    @Test func overviewDetent_hasOnlyMinimizedAndLarge() {
        #expect(DiveActivityOverviewDetent.allCases == [.minimized, .large])
        #expect(DiveActivityOverviewDetent.defaultSelection == .large)
    }

    @Test func largeHeightFraction_matchesBlueSheetSeamOnReferenceLayout() {
        let context = DiveActivityOverviewSheetLayoutContext.presentationReference
        let heroHeight = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: context.layoutHeight,
            screenWidth: context.screenWidth,
            topSafeAreaInset: context.topSafeInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight
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
}
