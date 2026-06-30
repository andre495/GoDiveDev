import Foundation
import SwiftUI

/// Horizontal pager pages on **`TripDetailView`** (below the static title block).
enum TripDetailContentPage: Hashable, Sendable, Identifiable {
    case plannedSites
    case buddies
    case stats
    case marineLife
    case activities
    case media

    var id: Self { self }
}

enum TripDetailContentPagerPresentation: Sendable {

    /// **`false`** before the trip start day — planned sites + buddies only.
    nonisolated static func pages(hasStarted: Bool) -> [TripDetailContentPage] {
        if hasStarted {
            [.stats, .activities, .marineLife, .buddies, .media]
        } else {
            [.plannedSites, .buddies]
        }
    }

    nonisolated static func pageCount(hasStarted: Bool) -> Int {
        pages(hasStarted: hasStarted).count
    }

    nonisolated static func defaultPage(hasStarted: Bool) -> TripDetailContentPage {
        pages(hasStarted: hasStarted).first ?? .stats
    }

    nonisolated static func resolvedInitialPage(
        hasStarted: Bool,
        requested: TripDetailContentPage?
    ) -> TripDetailContentPage {
        let available = pages(hasStarted: hasStarted)
        if let requested, available.contains(requested) {
            return requested
        }
        return defaultPage(hasStarted: hasStarted)
    }

    nonisolated static func accessibilityIdentifier(for page: TripDetailContentPage) -> String {
        switch page {
        case .plannedSites: "TripDetail.ContentPager.PlannedSites"
        case .buddies: "TripDetail.ContentPager.Buddies"
        case .stats: "TripDetail.ContentPager.Stats"
        case .marineLife: "TripDetail.ContentPager.MarineLife"
        case .activities: "TripDetail.ContentPager.Activities"
        case .media: "TripDetail.ContentPager.Media"
        }
    }

    /// Pages that fit without a vertical **`ScrollView`** wrapper (fixed-height or full-bleed content).
    nonisolated static func usesStaticPagerLayout(for page: TripDetailContentPage) -> Bool {
        switch page {
        case .stats:
            true
        case .plannedSites, .buddies, .marineLife, .activities, .media:
            false
        }
    }

    /// Vertical placement of static pager content within the area above **`bottomScrollInset`**.
    nonisolated static func staticPagerContentAlignment(for page: TripDetailContentPage) -> Alignment {
        switch page {
        case .stats:
            return .center
        case .media, .plannedSites, .buddies, .marineLife, .activities:
            return .top
        }
    }

    nonisolated static func pagerPageLayout(for page: TripDetailContentPage) -> BlueSheetDetailPagerPageLayout {
        BlueSheetDetailPagerPageLayout(
            usesStaticLayout: usesStaticPagerLayout(for: page),
            staticContentAlignment: staticPagerContentAlignment(for: page),
            scrollBottomInsetExtra: usesStaticPagerLayout(for: page)
                ? 0
                : BlueSheetDetailPagerPresentation.tripScrollBottomInsetExtra,
            accessibilityIdentifier: accessibilityIdentifier(for: page)
        )
    }
}
