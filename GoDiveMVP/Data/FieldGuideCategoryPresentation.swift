import CoreGraphics

/// Layout policy for Field Guide category detail (legacy fixed hero; blue-sheet pages use pushed hero height).
enum FieldGuideCategoryImageLayout {
    /// Hero height before safe-area extension (shorter than species detail).
    static let detailHeroBaseHeight: CGFloat = 200
}

enum FieldGuideCategoryPresentation {
    static func detailHeroHeight(extraTopInset: CGFloat) -> CGFloat {
        FieldGuideCategoryImageLayout.detailHeroBaseHeight + extraTopInset
    }

    /// Square thumbnail on category browse subcategory rows.
    static let subcategoryRowThumbnailSize: CGFloat = 44

    nonisolated static func browseTitleAccessibilityIdentifier(categoryID: String) -> String {
        "FieldGuide.Category.\(categoryID).Title"
    }
}

/// Layout policy for Field Guide subcategory detail (legacy chrome helpers).
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

    nonisolated static func browseTitleAccessibilityIdentifier(
        categoryID: String,
        subcategoryID: String
    ) -> String {
        let normalizedSubcategoryID = FieldGuideTaxonomy.normalizedSubcategoryID(subcategoryID)
        if normalizedSubcategoryID.isEmpty {
            return "FieldGuide.Category.\(FieldGuideTaxonomy.normalizedCategoryID(categoryID)).Subcategory.all.Title"
        }
        return "FieldGuide.Category.\(FieldGuideTaxonomy.normalizedCategoryID(categoryID)).Subcategory.\(normalizedSubcategoryID).Title"
    }
}
