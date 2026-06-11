import CoreGraphics

/// Layout policy for Field Guide category detail (pushed from hub).
enum FieldGuideCategoryImageLayout {
    /// Hero height before safe-area extension (shorter than species detail).
    static let detailHeroBaseHeight: CGFloat = 200
}

enum FieldGuideCategoryPresentation {
    static func detailHeroHeight(extraTopInset: CGFloat) -> CGFloat {
        FieldGuideCategoryImageLayout.detailHeroBaseHeight + extraTopInset
    }
}

/// Layout policy for Field Guide subcategory detail (same hero + floating back chrome as category detail).
enum FieldGuideSubcategoryPresentation {
    static func detailHeroHeight(extraTopInset: CGFloat) -> CGFloat {
        FieldGuideCategoryPresentation.detailHeroHeight(extraTopInset: extraTopInset)
    }

    /// Top obstruction for **`LogbookTopChromeScrim`** (floating back-only **`AppHeader`**).
    static func chromeTopInset(safeAreaTop: CGFloat, headerClearance: CGFloat) -> CGFloat {
        AppScrollUnderHeaderListLayout.listTopInset(
            safeAreaTop: safeAreaTop,
            headerClearance: headerClearance
        )
    }
}
