import Foundation

enum SnorkelActivityOverviewPresentation {

    nonisolated static let newSnorkelActivitySiteTitle = "New Snorkel Activity"

    nonisolated static func siteHeaderTitle(siteName: String?) -> String {
        DiveActivityOverviewPresentation.siteHeaderTitle(
            siteName: siteName,
            fallback: newSnorkelActivitySiteTitle
        )
    }

    nonisolated static func mapOverviewStatsLayout(
        durationMinutes: Int,
        swimDistanceMeters: Double?,
        maxDepthMeters: Double?,
        avgTemperatureCelsius: Double?,
        displayUnits: DiveDisplayUnitSystem
    ) -> DiveActivityOverviewPresentation.MapOverviewStatsLayout {
        let distanceDisplay = swimDistanceMeters.map {
            DiveQuantityFormatting.swimDistance(meters: $0, system: displayUnits)
        } ?? "—"
        let maxDepthDisplay = maxDepthMeters.map {
            DiveQuantityFormatting.depth(meters: $0, system: displayUnits)
        } ?? "—"
        let tempDisplay = avgTemperatureCelsius.map {
            DiveQuantityFormatting.waterTemperature(celsius: $0, system: displayUnits)
        } ?? "—"

        return DiveActivityOverviewPresentation.MapOverviewStatsLayout(
            leadingStats: [
                DiveActivityOverviewPresentation.statCell(
                    id: "duration",
                    titleLine1: "Session",
                    titleLine2: "Duration",
                    displayValue: DiveActivityOverviewPresentation.formattedDurationMinutes(durationMinutes),
                    icon: DiveActivityOverviewPresentation.MapOverviewStatIcon.clock
                ),
                DiveActivityOverviewPresentation.statCell(
                    id: "distance",
                    titleLine1: "Swim",
                    titleLine2: "Distance",
                    displayValue: distanceDisplay,
                    icon: nil
                ),
            ],
            depthStats: [
                DiveActivityOverviewPresentation.statCell(
                    id: "maxDepth",
                    titleLine1: "Max",
                    titleLine2: "Depth",
                    displayValue: maxDepthDisplay,
                    icon: nil
                ),
                DiveActivityOverviewPresentation.statCell(
                    id: "avgTemp",
                    titleLine1: "Avg",
                    titleLine2: "Temp",
                    displayValue: tempDisplay,
                    icon: nil
                ),
            ],
            depthGauge: DiveActivityOverviewPresentation.MapOverviewStatsLayout.DepthGauge(
                maxFillFraction: DiveActivityOverviewPresentation.depthGaugeFillFraction(
                    depthMeters: maxDepthMeters ?? 0,
                    referenceMaxMeters: 10
                ),
                avgLineFraction: 0,
                showsAverageLine: false
            )
        )
    }
}
