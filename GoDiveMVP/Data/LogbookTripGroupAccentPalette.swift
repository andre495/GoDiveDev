import Foundation
import SwiftUI

/// Saturated trip accent colors for logbook rails + trip detail — readable in light mode.
enum LogbookTripGroupAccentPalette: Sendable {

    struct RGB: Sendable, Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    /// Distinct mid-to-deep hues (no light cyan, sky blue, or pastel yellow).
    nonisolated static let palette: [RGB] = [
        RGB(red: 0.00, green: 0.52, blue: 0.56),   // teal
        RGB(red: 0.86, green: 0.38, blue: 0.06),   // orange
        RGB(red: 0.48, green: 0.18, blue: 0.58),   // purple
        RGB(red: 0.06, green: 0.54, blue: 0.36),   // emerald
        RGB(red: 0.80, green: 0.16, blue: 0.40),   // rose
        RGB(red: 0.70, green: 0.46, blue: 0.04),   // amber
        RGB(red: 0.80, green: 0.26, blue: 0.20),   // coral
        RGB(red: 0.22, green: 0.18, blue: 0.55),   // indigo
    ]

    nonisolated static func rgb(at index: Int) -> RGB {
        guard !palette.isEmpty else { return RGB(red: 0.22, green: 0.18, blue: 0.55) }
        let normalized = ((index % palette.count) + palette.count) % palette.count
        return palette[normalized]
    }

    nonisolated static func color(at index: Int) -> Color {
        let rgb = rgb(at: index)
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// Picks the next palette slot — always differs from **`previousIndex`** when the palette has 2+ colors.
    nonisolated static func nextIndex(after previousIndex: Int?) -> Int {
        guard let previousIndex, palette.count > 1 else { return 0 }
        return (previousIndex + 1) % palette.count
    }

    /// Stable color when a trip is not yet grouped on the logbook (fewer than two linked dives).
    nonisolated static func stableFallbackIndex(for tripID: UUID) -> Int {
        var hasher = Hasher()
        hasher.combine(tripID)
        let hash = abs(hasher.finalize())
        guard !palette.isEmpty else { return 0 }
        return hash % palette.count
    }
}

/// Resolves the same accent index/color the logbook trip rail uses for a **`DiveTrip`**.
enum LogbookTripGroupAccentPresentation {

    nonisolated static func accentColorIndex(
        for tripID: UUID,
        in items: [LogbookListDisplayItem]
    ) -> Int? {
        for item in items {
            guard case .tripGroup(let group) = item, group.tripID == tripID else { continue }
            return group.accentColorIndex
        }
        return nil
    }

    @MainActor
    static func accentColorIndex(
        for tripID: UUID,
        ownerActivities: [DiveActivity],
        ownerTrips: [DiveTrip],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool
    ) -> Int {
        let seeds = LogbookActivitySnapshotSeeding.seeds(from: ownerActivities)
        let tripSeeds = LogbookTripSnapshotSeeding.tripSeeds(
            from: ownerActivities,
            ownerTrips: ownerTrips
        )
        let items = LogbookDisplayCacheBuilder.build(
            visibleSeeds: seeds,
            tripSeeds: tripSeeds,
            siteSearchQuery: "",
            unitSystem: unitSystem,
            useChronologicalNumbers: useChronologicalNumbers,
            includeDuplicateScan: false
        ).items

        if let index = accentColorIndex(for: tripID, in: items) {
            return index
        }
        return LogbookTripGroupAccentPalette.stableFallbackIndex(for: tripID)
    }

    @MainActor
    static func accentColor(
        for tripID: UUID,
        ownerActivities: [DiveActivity],
        ownerTrips: [DiveTrip],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool
    ) -> Color {
        LogbookTripGroupAccentPalette.color(
            at: accentColorIndex(
                for: tripID,
                ownerActivities: ownerActivities,
                ownerTrips: ownerTrips,
                unitSystem: unitSystem,
                useChronologicalNumbers: useChronologicalNumbers
            )
        )
    }
}
