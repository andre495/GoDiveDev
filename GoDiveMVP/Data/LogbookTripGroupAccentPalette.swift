import Foundation
import SwiftUI

/// Trip accent colors for logbook rails + trip detail — contrasty in light mode, pastel in dark mode.
enum LogbookTripGroupAccentPalette: Sendable {

    typealias RGB = AdaptiveAccentColor.RGB

    /// Darker saturated hues for light mode (readable on pale sheet backgrounds).
    nonisolated static let lightModePalette: [RGB] = [
        RGB(red: 0.00, green: 0.42, blue: 0.46),   // teal
        RGB(red: 0.72, green: 0.30, blue: 0.02),   // orange
        RGB(red: 0.38, green: 0.10, blue: 0.48),   // purple
        RGB(red: 0.02, green: 0.42, blue: 0.26),   // emerald
        RGB(red: 0.62, green: 0.08, blue: 0.30),   // rose
        RGB(red: 0.55, green: 0.34, blue: 0.02),   // amber
        RGB(red: 0.65, green: 0.18, blue: 0.12),   // coral
        RGB(red: 0.14, green: 0.10, blue: 0.42),   // indigo
    ]

    /// Soft pastels for dark mode.
    nonisolated static let darkModePalette: [RGB] = [
        RGB(red: 0.45, green: 0.86, blue: 0.90),   // teal
        RGB(red: 1.00, green: 0.72, blue: 0.48),   // orange
        RGB(red: 0.82, green: 0.62, blue: 0.94),   // purple
        RGB(red: 0.55, green: 0.92, blue: 0.74),   // emerald
        RGB(red: 0.98, green: 0.62, blue: 0.76),   // rose
        RGB(red: 0.96, green: 0.82, blue: 0.45),   // amber
        RGB(red: 0.98, green: 0.68, blue: 0.62),   // coral
        RGB(red: 0.68, green: 0.62, blue: 0.96),   // indigo
    ]

    /// Back-compat — tests and index math use light-mode slot count.
    nonisolated static let palette: [RGB] = lightModePalette

    nonisolated static func rgb(at index: Int, colorScheme: ColorScheme) -> RGB {
        let source = colorScheme == .dark ? darkModePalette : lightModePalette
        guard !source.isEmpty else {
            return RGB(red: 0.14, green: 0.10, blue: 0.42)
        }
        let normalized = ((index % source.count) + source.count) % source.count
        return source[normalized]
    }

    nonisolated static func rgb(at index: Int) -> RGB {
        rgb(at: index, colorScheme: .light)
    }

    nonisolated static func color(at index: Int) -> Color {
        let light = rgb(at: index, colorScheme: .light)
        let dark = rgb(at: index, colorScheme: .dark)
        return AdaptiveAccentColor.color(light: light, dark: dark)
    }

    /// Picks the next palette slot — always differs from **`previousIndex`** when the palette has 2+ colors.
    nonisolated static func nextIndex(after previousIndex: Int?) -> Int {
        guard let previousIndex, lightModePalette.count > 1 else { return 0 }
        return (previousIndex + 1) % lightModePalette.count
    }

    /// Stable color when a trip is not yet grouped on the logbook (fewer than two linked dives).
    nonisolated static func stableFallbackIndex(for tripID: UUID) -> Int {
        var hasher = Hasher()
        hasher.combine(tripID)
        let hash = abs(hasher.finalize())
        guard !lightModePalette.isEmpty else { return 0 }
        return hash % lightModePalette.count
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

    /// Same accent indices as logbook trip rails — including stable fallback for single-dive links.
    nonisolated static func accentColorIndexByTripID(
        seeds: [LogbookActivitySnapshotSeed],
        tripSeeds: [LogbookTripSnapshotSeed],
        unitSystem: DiveDisplayUnitSystem,
        useChronologicalNumbers: Bool
    ) -> [UUID: Int] {
        let items = LogbookDisplayCacheBuilder.build(
            visibleSeeds: seeds,
            tripSeeds: tripSeeds,
            siteSearchQuery: "",
            unitSystem: unitSystem,
            useChronologicalNumbers: useChronologicalNumbers,
            includeDuplicateScan: false
        ).items

        var map: [UUID: Int] = [:]
        for item in items {
            guard case .tripGroup(let group) = item else { continue }
            map[group.tripID] = group.accentColorIndex
        }
        for trip in tripSeeds {
            if map[trip.tripID] == nil {
                map[trip.tripID] = LogbookTripGroupAccentPalette.stableFallbackIndex(for: trip.tripID)
            }
        }
        return map
    }
}
