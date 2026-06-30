import Foundation
import SwiftUI

/// Single-tab pager page on **`ViewEquipmentDetails`**.
enum EquipmentDetailContentPage: Hashable, Sendable, Identifiable {
    case details

    var id: Self { self }
}

enum EquipmentDetailContentPagerPresentation: Sendable {
    nonisolated static let pages: [EquipmentDetailContentPage] = [.details]

    nonisolated static var pageCount: Int { pages.count }

    nonisolated static var defaultPage: EquipmentDetailContentPage { .details }

    nonisolated static let detailsSectionTitle = "Details"

    nonisolated static func pageTitle(for page: EquipmentDetailContentPage) -> String {
        switch page {
        case .details:
            return detailsSectionTitle
        }
    }

    nonisolated static func accessibilityIdentifier(for page: EquipmentDetailContentPage) -> String {
        switch page {
        case .details:
            return "EquipmentDetails.ContentPager.Details"
        }
    }

    nonisolated static func usesStaticPagerLayout(for page: EquipmentDetailContentPage) -> Bool {
        false
    }

    nonisolated static func staticPagerContentAlignment(
        for page: EquipmentDetailContentPage
    ) -> Alignment {
        .top
    }

    nonisolated static func pagerPageLayout(
        for page: EquipmentDetailContentPage
    ) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            accessibilityLabel: pageTitle(for: page),
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
