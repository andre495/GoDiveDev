import Foundation
import SwiftUI

/// Horizontal pager pages on **`ProfileView`** (below the identity row).
enum ProfileDetailContentPage: Hashable, Sendable, Identifiable {
    case diverStats
    case details
    case taggedMedia

    var id: Self { self }
}

enum ProfileDetailContentPagerPresentation: Sendable {
    nonisolated static let pages: [ProfileDetailContentPage] = [
        .diverStats,
        .details,
        .taggedMedia,
    ]

    nonisolated static var pageCount: Int { pages.count }

    nonisolated static var defaultPage: ProfileDetailContentPage { .diverStats }

    nonisolated static let diverStatsPageTitle = "Diver stats"
    nonisolated static let detailsPageTitle = "Details"
    nonisolated static let danSectionTitle = "DAN insurance"
    nonisolated static let danMemberNumberLabel = "Member number"
    nonisolated static let danWebsiteLinkAccessibilityHint = "Opens DAN website"
    nonisolated static let certificationSectionTitle = "Certification"
    nonisolated static let certificationNameLabel = "Name"
    nonisolated static let certificationNumberLabel = "Number"
    nonisolated static let certificationDateAttainedLabel = "Date attained"
    nonisolated static let emptyDanMessage = "No DAN insurance number on file."
    nonisolated static let emptyCertificationMessage = "No certification cards yet."
    nonisolated static let viewAllCertificationsTitle = "View all certifications"

    /// Horizontal inset is applied once by **`BlueSheetDetailPage`** — pager page bodies must not add **`AppTheme.Spacing.lg`** again.
    nonisolated static let usesBlueSheetDetailHorizontalPaddingOnly = true

    /// Member-facing DAN site (fixed — not derived from the stored member number).
    nonisolated static let danWebsiteURL = URL(string: "https://dan.org/")!

    /// Display copy for the member number row — always includes a leading **`#`**.
    nonisolated static func formattedDanMemberNumberForDisplay(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "#" }
        if trimmed.hasPrefix("#") { return trimmed }
        return "#\(trimmed)"
    }

    nonisolated static func pageTitle(for page: ProfileDetailContentPage) -> String {
        switch page {
        case .diverStats:
            return diverStatsPageTitle
        case .details:
            return detailsPageTitle
        case .taggedMedia:
            return DiveBuddyTaggedMediaPresentation.sectionTitle
        }
    }

    nonisolated static func emptyStateMessage(for page: ProfileDetailContentPage) -> String {
        switch page {
        case .diverStats:
            return ""
        case .details:
            return ""
        case .taggedMedia:
            return "No photos or videos tagged with you yet."
        }
    }

    nonisolated static func accessibilityIdentifier(for page: ProfileDetailContentPage) -> String {
        switch page {
        case .diverStats:
            return "Profile.ContentPager.DiverStats"
        case .details:
            return "Profile.ContentPager.Details"
        case .taggedMedia:
            return "Profile.ContentPager.TaggedMedia"
        }
    }

    /// Extra clearance above the home indicator for the native page dots (**`TabView`**).
    nonisolated static let pageIndicatorClearance: CGFloat = 28

    nonisolated static func usesStaticPagerLayout(for page: ProfileDetailContentPage) -> Bool {
        switch page {
        case .diverStats, .taggedMedia:
            return false
        case .details:
            return true
        }
    }

    /// Profile pager omits visible page headers; titles remain for accessibility labels.
    nonisolated static let showsPinnedPageHeaders = false

    nonisolated static func staticPagerContentAlignment(for page: ProfileDetailContentPage) -> Alignment {
        .top
    }

    nonisolated static func pagerPageLayout(for page: ProfileDetailContentPage) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            accessibilityLabel: pageTitle(for: page),
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
