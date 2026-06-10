import CoreGraphics

/// Layout policy for Field Guide category detail (pushed from hub).
enum FieldGuideCategoryImageLayout {
    /// Hero height before safe-area extension (matches species detail base).
    static let detailHeroBaseHeight: CGFloat = 280
}

enum FieldGuideCategoryPresentation {
    static func detailHeroHeight(extraTopInset: CGFloat) -> CGFloat {
        FieldGuideCategoryImageLayout.detailHeroBaseHeight + extraTopInset
    }
}

/// Layout policy for Field Guide subcategory detail (nav title + fixed summary — mosaic scrolls alone).
enum FieldGuideSubcategoryPresentation {
    /// Top inset for the pinned hint + species-count block below **`AppHeader`**.
    static func fixedSummaryTopInset(safeAreaTop: CGFloat, headerClearance: CGFloat) -> CGFloat {
        safeAreaTop + headerClearance
    }
}
