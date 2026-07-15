import Foundation

/// Dive identity for the fullscreen Home-matching dive link capsule.
enum LinkedMediaFullscreenDiveLinkPresentation: Sendable {

    @MainActor
    static func siteDisplayName(for dive: DiveActivity?) -> String {
        guard let dive else { return "New Dive" }
        return LogbookActivityRow.displayName(for: dive)
    }

    /// Logbook-style **#** for the selected dive (chronological when automatic renumber is on).
    nonisolated static func diveNumberLabel(
        for dive: DiveActivity?,
        useChronologicalNumbers: Bool,
        chronologicalIndexByDiveID: [UUID: Int]
    ) -> String {
        guard let dive else { return "-" }
        return HomeMediaHighlightPresentation.diveNumberLabel(
            diveNumber: dive.diveNumber,
            diveNumberExplicitlyNone: dive.diveNumberExplicitlyNone,
            chronologicalIndex: chronologicalIndexByDiveID[dive.id],
            useChronologicalNumbers: useChronologicalNumbers
        )
    }

    @MainActor
    static func linkedTripTitle(for dive: DiveActivity?) -> String? {
        guard let dive else { return nil }
        guard let trip = dive.tripActivityLinks
            .compactMap(\.trip)
            .max(by: { lhs, rhs in
                if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
                return lhs.createdAt < rhs.createdAt
            })
        else { return nil }
        let title = trip.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
}
