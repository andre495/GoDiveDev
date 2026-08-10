import SwiftUI

extension DiveActivityOverviewDetent {
    func presentationDetent(
        screenHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeInset: CGFloat,
        bottomSafeInset: CGFloat
    ) -> PresentationDetent {
        .height(
            Self.sheetHeight(
                for: self,
                layoutHeight: screenHeight,
                bottomSafeInset: bottomSafeInset,
                screenWidth: screenWidth,
                topSafeInset: topSafeInset
            )
        )
    }

    static func allPresentationDetents(
        screenHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeInset: CGFloat,
        bottomSafeInset: CGFloat
    ) -> Set<PresentationDetent> {
        Set(
            allCases.map {
                $0.presentationDetent(
                    screenHeight: screenHeight,
                    screenWidth: screenWidth,
                    topSafeInset: topSafeInset,
                    bottomSafeInset: bottomSafeInset
                )
            }
        )
    }

    init?(
        presentationDetent: PresentationDetent,
        screenHeight: CGFloat,
        screenWidth: CGFloat,
        topSafeInset: CGFloat,
        bottomSafeInset: CGFloat
    ) {
        guard
            let match = Self.allCases.first(where: {
                $0.presentationDetent(
                    screenHeight: screenHeight,
                    screenWidth: screenWidth,
                    topSafeInset: topSafeInset,
                    bottomSafeInset: bottomSafeInset
                ) == presentationDetent
            })
        else { return nil }
        self = match
    }

    /// Default reference layout — used by unit tests only.
    var presentationDetent: PresentationDetent {
        presentationDetent(
            screenHeight: Self.presentationReferenceScreenHeight,
            screenWidth: Self.presentationReferenceScreenWidth,
            topSafeInset: DiveActivityOverviewSheetLayoutContext.presentationReference.topSafeInset,
            bottomSafeInset: Self.presentationReferenceBottomSafeInset
        )
    }

    static var allPresentationDetents: Set<PresentationDetent> {
        allPresentationDetents(
            screenHeight: presentationReferenceScreenHeight,
            screenWidth: presentationReferenceScreenWidth,
            topSafeInset: DiveActivityOverviewSheetLayoutContext.presentationReference.topSafeInset,
            bottomSafeInset: presentationReferenceBottomSafeInset
        )
    }

    init?(presentationDetent: PresentationDetent) {
        self.init(
            presentationDetent: presentationDetent,
            screenHeight: Self.presentationReferenceScreenHeight,
            screenWidth: Self.presentationReferenceScreenWidth,
            topSafeInset: DiveActivityOverviewSheetLayoutContext.presentationReference.topSafeInset,
            bottomSafeInset: Self.presentationReferenceBottomSafeInset
        )
    }
}
