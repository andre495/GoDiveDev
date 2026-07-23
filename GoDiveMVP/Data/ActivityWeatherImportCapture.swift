import Foundation
import SwiftData

/// Fetches WeatherKit once at import and stores a frozen snapshot on the activity row.
enum ActivityWeatherImportCapture: Sendable {

    private nonisolated static let bulkYieldStride = 5

    @MainActor
    static func captureForDive(
        _ activity: DiveActivity,
        catalogSites: [DiveSite]
    ) async {
        guard activity.activityWeatherSnapshotData == nil else { return }
        guard let coordinate = activity.resolvedMapCoordinate(catalogSites: catalogSites) else { return }
        guard ActivityWeatherConditionsPresentation.unavailableReason(
            mapCoordinate: coordinate,
            activityStart: activity.startTime
        ) == nil else { return }

        if let snapshot = await ActivityWeatherKitService.fetchPersisted(
            mapCoordinate: coordinate,
            activityStart: activity.startTime,
            timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds
        ) {
            ActivityWeatherSnapshotStorage.write(snapshot, to: activity)
        }
    }

    @MainActor
    static func captureForDives(
        _ activities: [DiveActivity],
        catalogSites: [DiveSite]
    ) async {
        for (index, activity) in activities.enumerated() {
            await captureForDive(activity, catalogSites: catalogSites)
            if (index + 1) % bulkYieldStride == 0 {
                await Task.yield()
            }
        }
    }

    @MainActor
    static func captureForSnorkel(
        _ activity: SnorkelActivity,
        catalogSites: [DiveSite]
    ) async {
        guard activity.activityWeatherSnapshotData == nil else { return }
        guard let coordinate = activity.resolvedMapCoordinate(catalogSites: catalogSites) else { return }
        guard ActivityWeatherConditionsPresentation.unavailableReason(
            mapCoordinate: coordinate,
            activityStart: activity.startTime
        ) == nil else { return }

        if let snapshot = await ActivityWeatherKitService.fetchPersisted(
            mapCoordinate: coordinate,
            activityStart: activity.startTime,
            timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds
        ) {
            ActivityWeatherSnapshotStorage.write(snapshot, to: activity)
        }
    }
}
