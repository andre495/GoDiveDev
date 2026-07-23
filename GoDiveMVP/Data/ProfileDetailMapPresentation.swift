import Foundation

/// Map pins for the owner **Profile** hero — dives with a resolvable coordinate.
enum ProfileDetailMapPresentation: Sendable {

    nonisolated static func pins(
        from activities: [DiveActivity],
        catalogSites: [DiveSite]
    ) -> [TripDetailMapPin] {
        DiveBuddyDetailMapPresentation.pins(from: activities, catalogSites: catalogSites)
    }
}
