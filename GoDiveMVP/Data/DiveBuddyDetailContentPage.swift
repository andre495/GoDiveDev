import Foundation
import SwiftUI

/// Horizontal pager pages on **`ViewDiveBuddyDetails`** (below the identity row).
enum DiveBuddyDetailContentPage: Hashable, Sendable, Identifiable {
    case divesTogether
    case tripsTogether
    case taggedMedia

    var id: Self { self }
}

enum DiveBuddyDetailContentPagerPresentation: Sendable {

    nonisolated static let pages: [DiveBuddyDetailContentPage] = [
        .divesTogether,
        .tripsTogether,
        .taggedMedia,
    ]

    nonisolated static var pageCount: Int {
        pages.count
    }

    nonisolated static var defaultPage: DiveBuddyDetailContentPage {
        .divesTogether
    }

    nonisolated static func pageTitle(for page: DiveBuddyDetailContentPage) -> String {
        switch page {
        case .divesTogether:
            return "Dives together"
        case .tripsTogether:
            return DiveBuddyTripPresentation.sectionTitle
        case .taggedMedia:
            return DiveBuddyTaggedMediaPresentation.sectionTitle
        }
    }

    nonisolated static func emptyStateMessage(for page: DiveBuddyDetailContentPage) -> String {
        switch page {
        case .divesTogether:
            return "No dives tagged with this buddy yet."
        case .tripsTogether:
            return "No trips with this buddy yet."
        case .taggedMedia:
            return "No photos or videos tagged with this buddy yet."
        }
    }

    nonisolated static func accessibilityIdentifier(for page: DiveBuddyDetailContentPage) -> String {
        switch page {
        case .divesTogether:
            return "DiveBuddyDetails.ContentPager.DivesTogether"
        case .tripsTogether:
            return "DiveBuddyDetails.ContentPager.TripsTogether"
        case .taggedMedia:
            return "DiveBuddyDetails.ContentPager.TaggedMedia"
        }
    }

    /// Extra clearance above the home indicator for the native page dots (**`TabView`**).
    nonisolated static let pageIndicatorClearance: CGFloat = 28

    /// Tagged-media page scrolls a still preview grid; tap opens full-screen playback.
    nonisolated static func usesStaticPagerLayout(for page: DiveBuddyDetailContentPage) -> Bool {
        false
    }

    nonisolated static func staticPagerContentAlignment(for page: DiveBuddyDetailContentPage) -> Alignment {
        .top
    }

    /// Pinned page titles sit above scrollable body content on every pager page.
    nonisolated static let pinnedPageHeaderBottomSpacing: CGFloat = AppTheme.Spacing.md

    /// Buddy pager omits visible page headers; titles remain for accessibility labels.
    nonisolated static let showsPinnedPageHeaders = false

    nonisolated static func pagerPageLayout(for page: DiveBuddyDetailContentPage) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            accessibilityLabel: pageTitle(for: page),
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
