import CoreGraphics

/// Layout inputs for resolving dive / snorkel overview sheet height (large detent matches blue sheet pages).
struct DiveActivityOverviewSheetLayoutContext: Sendable, Equatable {
    var layoutHeight: CGFloat
    var screenWidth: CGFloat
    var topSafeInset: CGFloat
    var bottomSafeInset: CGFloat

    nonisolated static let presentationReference = Self(
        layoutHeight: DiveActivityOverviewDetent.presentationReferenceScreenHeight,
        screenWidth: DiveActivityOverviewDetent.presentationReferenceScreenWidth,
        topSafeInset: 59,
        bottomSafeInset: DiveActivityOverviewDetent.presentationReferenceBottomSafeInset
    )
}
