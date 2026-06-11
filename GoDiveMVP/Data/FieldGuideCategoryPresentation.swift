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

/// Layout policy for Field Guide subcategory detail (pinned nav title — summary + mosaic scroll underneath).
enum FieldGuideSubcategoryPresentation {
    /// **`AppHeaderTitlePlacement.leadingAfterBack`** — title spans the row after back (not the 1/3 leading column).
    static let headerTitleLineLimit = 2

    /// Top spacer so hint, species count, and mosaic scroll under **`AppHeader`** + scrim.
    static func scrollContentTopInset(safeAreaTop: CGFloat, headerClearance: CGFloat) -> CGFloat {
        AppScrollUnderHeaderListLayout.listTopInset(
            safeAreaTop: safeAreaTop,
            headerClearance: headerClearance
        )
    }
}
