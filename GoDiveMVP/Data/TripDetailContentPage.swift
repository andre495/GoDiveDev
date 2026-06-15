import Foundation

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
            [.stats, .marineLife, .activities, .buddies, .media]
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
        case .stats, .media:
            true
        case .plannedSites, .buddies, .marineLife, .activities:
            false
        }
    }
}
