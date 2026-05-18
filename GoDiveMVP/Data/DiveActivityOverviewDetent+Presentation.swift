import SwiftUI

extension DiveActivityOverviewDetent {
    func presentationDetent(
        screenHeight: CGFloat,
        bottomSafeInset: CGFloat
    ) -> PresentationDetent {
        .height(
            Self.sheetHeight(
                for: self,
                layoutHeight: screenHeight,
                bottomSafeInset: bottomSafeInset
            )
        )
    }

    static func allPresentationDetents(
        screenHeight: CGFloat,
        bottomSafeInset: CGFloat
    ) -> Set<PresentationDetent> {
        Set(allCases.map { $0.presentationDetent(screenHeight: screenHeight, bottomSafeInset: bottomSafeInset) })
    }

    init?(
        presentationDetent: PresentationDetent,
        screenHeight: CGFloat,
        bottomSafeInset: CGFloat
    ) {
        guard
            let match = Self.allCases.first(where: {
                $0.presentationDetent(screenHeight: screenHeight, bottomSafeInset: bottomSafeInset)
                    == presentationDetent
            })
        else { return nil }
        self = match
    }

    /// Default reference layout — used by unit tests only.
    var presentationDetent: PresentationDetent {
        presentationDetent(
            screenHeight: Self.presentationReferenceScreenHeight,
            bottomSafeInset: Self.presentationReferenceBottomSafeInset
        )
    }

    static var allPresentationDetents: Set<PresentationDetent> {
        allPresentationDetents(
            screenHeight: presentationReferenceScreenHeight,
            bottomSafeInset: presentationReferenceBottomSafeInset
        )
    }

    init?(presentationDetent: PresentationDetent) {
        self.init(
            presentationDetent: presentationDetent,
            screenHeight: Self.presentationReferenceScreenHeight,
            bottomSafeInset: Self.presentationReferenceBottomSafeInset
        )
    }
}
