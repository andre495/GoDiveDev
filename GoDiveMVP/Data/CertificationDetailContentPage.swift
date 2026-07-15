import Foundation
import SwiftUI

/// Two-tab pager pages on **`ViewCertificationDetails`**.
nonisolated enum CertificationDetailContentPage: Hashable, Sendable, Identifiable {
    case details
    case instructorAndShop

    var id: Self { self }
}

enum CertificationDetailContentPagerPresentation: Sendable {
    nonisolated static let pages: [CertificationDetailContentPage] = [
        .details,
        .instructorAndShop,
    ]

    nonisolated static var pageCount: Int { pages.count }

    nonisolated static var defaultPage: CertificationDetailContentPage { .details }

    nonisolated static let detailsSectionTitle = "Details"
    nonisolated static let instructorAndShopSectionTitle = "Instructor & shop"

    nonisolated static func pageTitle(for page: CertificationDetailContentPage) -> String {
        switch page {
        case .details:
            return detailsSectionTitle
        case .instructorAndShop:
            return instructorAndShopSectionTitle
        }
    }

    nonisolated static func accessibilityIdentifier(for page: CertificationDetailContentPage) -> String {
        switch page {
        case .details:
            return "CertificationDetails.ContentPager.Details"
        case .instructorAndShop:
            return "CertificationDetails.ContentPager.InstructorAndShop"
        }
    }

    nonisolated static func usesStaticPagerLayout(for page: CertificationDetailContentPage) -> Bool {
        false
    }

    nonisolated static func staticPagerContentAlignment(
        for page: CertificationDetailContentPage
    ) -> Alignment {
        .top
    }

    nonisolated static func pagerPageLayout(
        for page: CertificationDetailContentPage
    ) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            accessibilityLabel: pageTitle(for: page),
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
