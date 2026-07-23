import CoreGraphics
import Foundation
import SwiftData

/// Map overview stat icons — top-level for **nonisolated** **`Equatable`** (Swift 6).
enum DiveActivityMapOverviewStatIcon: Sendable, Equatable {
    case clock
    case palmTree

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.clock, .clock), (.palmTree, .palmTree):
            return true
        default:
            return false
        }
    }
}

/// Copy and labels for the dive overview embedded panel (map / tank sheet).
enum DiveActivityOverviewPresentation: Sendable {
    /// Overview sheet title when **`siteName`** is missing (matches Logbook add-activity copy).
    nonisolated static let newDiveActivitySiteTitle = "New Dive Activity"

    /// Primary sheet header — trimmed **`siteName`**, otherwise import-source fallback.
    nonisolated static func siteHeaderTitle(siteName: String?, fallback: String) -> String {
        let trimmed = siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    /// **`true`** when the overview title should open **`ExploreDiveSiteDetailView`** (linked catalog site only).
    nonisolated static func siteTitleLinksToCatalogOverview(linkedCatalogSiteID: UUID?) -> Bool {
        linkedCatalogSiteID != nil
    }

    /// Logbook-style **`#n`** for the map header chip; **`nil`** when dive number is hidden or unset.
    nonisolated static func diveNumberChipLabel(
        diveNumber: Int?,
        diveNumberExplicitlyNone: Bool
    ) -> String? {
        guard !diveNumberExplicitlyNone, let diveNumber else { return nil }
        return "#\(diveNumber)"
    }

    /// **Region, Country** (or whichever side is present), with a leading country-flag emoji when known.
    nonisolated static func regionCountryLine(region: String, country: String) -> String? {
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonicalCountry = DiveSiteCountryPresentation.canonicalDisplayName(for: trimmedCountry)

        let base: String?
        switch (trimmedRegion.isEmpty, trimmedCountry.isEmpty) {
        case (false, false):
            base = "\(trimmedRegion), \(trimmedCountry)"
        case (false, true):
            base = trimmedRegion
        case (true, false):
            base = trimmedCountry
        case (true, true):
            base = nil
        }
        guard let base else { return nil }
        guard !canonicalCountry.isEmpty else { return base }
        return DiveSiteCountryPresentation.prefixedWithFlagEmoji(base, countryName: canonicalCountry)
    }

    nonisolated static func regionCountryLine(diveSite: DiveLinkedSiteResolver.ResolvedSite?) -> String? {
        guard let diveSite else { return nil }
        return regionCountryLine(region: diveSite.region, country: diveSite.country)
    }

    nonisolated static func regionCountryLine(locationName: String?) -> String? {
        let fields = DiveImportedLocationParsing.placeFields(fromLocationName: locationName)
        return regionCountryLine(region: fields.region, country: fields.country)
    }

    /// Linked catalog site first, then import **`locationName`**.
    nonisolated static func mapHeaderRegionCountryLine(
        diveSite: DiveLinkedSiteResolver.ResolvedSite?,
        locationName: String?
    ) -> String? {
        regionCountryLine(diveSite: diveSite) ?? regionCountryLine(locationName: locationName)
    }

    /// **January 5, 2026 - 10:45 AM** in the dive (or device) timezone.
    nonisolated static func startDateDashTimeLine(
        startTime: Date,
        timeZoneOffsetSeconds: Int?
    ) -> String {
        let date = DiveActivityTimePresentation.formatLongDateOnly(
            startTime,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        )
        let time = DiveActivityTimePresentation.formatTimeOnly(
            startTime,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        )
        return "\(date) - \(time)"
    }

    struct MapOverviewStatsLayout: Sendable {
        struct StatCell: Sendable, Identifiable {
            let id: String
            let titleLine1: String
            let titleLine2: String
            let valueNumber: String
            let valueUnit: String
            let icon: MapOverviewStatIcon?
        }

        struct DepthGauge: Sendable, Equatable {
            let maxFillFraction: Double
            let avgLineFraction: Double
            let showsAverageLine: Bool
        }

        let leadingStats: [StatCell]
        let depthStats: [StatCell]
        let depthGauge: DepthGauge
    }

    typealias MapOverviewStatIcon = DiveActivityMapOverviewStatIcon

    /// Normalizes depth against a recreational reference span for the shared depth gauge.
    nonisolated static func depthGaugeFillFraction(
        depthMeters: Double,
        referenceMaxMeters: Double = 40
    ) -> Double {
        guard depthMeters > 0, referenceMaxMeters > 0 else { return 0 }
        return min(depthMeters / referenceMaxMeters, 1)
    }

    /// Splits a display string like **`60.0 ft`** or **`42 min`** into number + unit.
    nonisolated static func splitDisplayValue(_ value: String) -> (number: String, unit: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != "—", !trimmed.isEmpty else { return ("—", "") }
        guard let space = trimmed.firstIndex(of: " ") else { return (trimmed, "") }
        let number = String(trimmed[..<space])
        let unit = String(trimmed[trimmed.index(after: space)...])
        return (number, unit)
    }

    nonisolated static func statCell(
        id: String,
        titleLine1: String,
        titleLine2: String,
        displayValue: String,
        icon: MapOverviewStatIcon?
    ) -> MapOverviewStatsLayout.StatCell {
        let parts = splitDisplayValue(displayValue)
        return MapOverviewStatsLayout.StatCell(
            id: id,
            titleLine1: titleLine1,
            titleLine2: titleLine2,
            valueNumber: parts.number,
            valueUnit: parts.unit,
            icon: icon
        )
    }

    /// Quick-read dive metrics for the map overview stats box.
    nonisolated static func mapOverviewStatsLayout(
        durationMinutes: Int,
        maxDepthMeters: Double,
        averageDepthMeters: Double?,
        surfaceIntervalSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) -> MapOverviewStatsLayout {
        let avgDepthDisplay = averageDepthMeters.map {
            DiveQuantityFormatting.depth(meters: $0, system: displayUnits)
        } ?? "—"
        let showsAverageLine = (averageDepthMeters ?? 0) > 0

        return MapOverviewStatsLayout(
            leadingStats: [
                statCell(
                    id: "duration",
                    titleLine1: "Dive",
                    titleLine2: "Duration",
                    displayValue: formattedDurationMinutes(durationMinutes),
                    icon: MapOverviewStatIcon.clock
                ),
                mapSurfaceIntervalStatCell(surfaceIntervalSeconds: surfaceIntervalSeconds),
            ],
            depthStats: [
                statCell(
                    id: "avgDepth",
                    titleLine1: "Avg",
                    titleLine2: "Depth",
                    displayValue: avgDepthDisplay,
                    icon: nil
                ),
                statCell(
                    id: "maxDepth",
                    titleLine1: "Max",
                    titleLine2: "Depth",
                    displayValue: DiveQuantityFormatting.depth(meters: maxDepthMeters, system: displayUnits),
                    icon: nil
                ),
            ],
            depthGauge: MapOverviewStatsLayout.DepthGauge(
                maxFillFraction: depthGaugeFillFraction(depthMeters: maxDepthMeters),
                avgLineFraction: averageDepthMeters.map { depthGaugeFillFraction(depthMeters: $0) } ?? 0,
                showsAverageLine: showsAverageLine
            )
        )
    }

    nonisolated static func formattedDurationMinutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        return "\(minutes) min"
    }

    /// Map stats box — **> 60 min** → **`N Hr(s)`** / **`M Min(s)`**; otherwise minutes (or seconds) like **`formattedDurationSeconds`**.
    nonisolated static func formattedMapSurfaceIntervalParts(_ seconds: Int?) -> (number: String, unit: String) {
        guard let seconds, seconds > 0 else { return ("—", "") }
        let totalMinutes = seconds / 60
        if totalMinutes > 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return (
                "\(hours) \(mapSurfaceIntervalHourUnit(hours))",
                "\(minutes) \(mapSurfaceIntervalMinuteUnit(minutes))"
            )
        }
        let parts = splitDisplayValue(formattedDurationSeconds(seconds))
        return (parts.number, parts.unit)
    }

    nonisolated static func mapSurfaceIntervalHourUnit(_ hours: Int) -> String {
        hours == 1 ? "Hr" : "Hrs"
    }

    nonisolated static func mapSurfaceIntervalMinuteUnit(_ minutes: Int) -> String {
        minutes == 1 ? "Min" : "Mins"
    }

    private nonisolated static func mapSurfaceIntervalStatCell(
        surfaceIntervalSeconds: Int?
    ) -> MapOverviewStatsLayout.StatCell {
        let parts = formattedMapSurfaceIntervalParts(surfaceIntervalSeconds)
        return MapOverviewStatsLayout.StatCell(
            id: "surfaceInterval",
            titleLine1: "Surface",
            titleLine2: "Interval",
            valueNumber: parts.number,
            valueUnit: parts.unit,
            icon: MapOverviewStatIcon.palmTree
        )
    }

    nonisolated static func formattedDurationSeconds(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        if seconds < 60 {
            return "\(seconds) s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return "\(minutes) min"
        }
        return "\(minutes) min \(remainder) s"
    }

    /// Scuba / snorkel SF Symbol on dive & snorkel overview headers (**`DiveActivityMapOverviewHeader`**).
    /// Roughly **2×** logbook row **`.caption`** (~12 pt → 24 pt).
    nonisolated static let activityIdentitySymbolPointSize: CGFloat = 24
}
