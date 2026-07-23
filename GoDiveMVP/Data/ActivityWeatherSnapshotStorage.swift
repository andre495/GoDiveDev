import Foundation

/// Reads / writes frozen import weather on **`DiveActivity`** / **`SnorkelActivity`**.
enum ActivityWeatherSnapshotStorage: Sendable {

    nonisolated static func read(from activity: DiveActivity) -> ActivityWeatherPersistedSnapshot? {
        read(data: activity.activityWeatherSnapshotData)
    }

    nonisolated static func read(from activity: SnorkelActivity) -> ActivityWeatherPersistedSnapshot? {
        read(data: activity.activityWeatherSnapshotData)
    }

    nonisolated static func write(
        _ snapshot: ActivityWeatherPersistedSnapshot,
        to activity: DiveActivity
    ) {
        activity.activityWeatherSnapshotData = try? ActivityWeatherPersistedSnapshotCodec.encode(snapshot)
    }

    nonisolated static func write(
        _ snapshot: ActivityWeatherPersistedSnapshot,
        to activity: SnorkelActivity
    ) {
        activity.activityWeatherSnapshotData = try? ActivityWeatherPersistedSnapshotCodec.encode(snapshot)
    }

    nonisolated static func displaySnapshot(
        from data: Data?,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) -> ActivityWeatherConditionsSnapshot? {
        guard let data, let persisted = read(data: data) else { return nil }
        return displaySnapshot(
            from: persisted,
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds,
            displayUnits: displayUnits
        )
    }

    nonisolated static func displaySnapshot(
        from persisted: ActivityWeatherPersistedSnapshot,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) -> ActivityWeatherConditionsSnapshot {
        let humidityLine = persisted.humidityFraction
            .map { ActivityWeatherConditionsPresentation.humidityDisplay(fraction: $0) }
        let windLine = persisted.windMetersPerSecond
            .map { ActivityWeatherConditionsPresentation.windDisplay(metersPerSecond: $0, displayUnits: displayUnits) }
        let dailyHighLowLine = ActivityWeatherConditionsPresentation.dailyHighLowDisplay(
            highCelsius: persisted.dailyHighCelsius,
            lowCelsius: persisted.dailyLowCelsius,
            displayUnits: displayUnits
        )
        let aroundEntryLine: String
        if persisted.usesDailyFallback {
            aroundEntryLine = ActivityWeatherConditionsPresentation.dayOfActivityLine(
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            )
        } else if let referenceHour = persisted.referenceHour {
            aroundEntryLine = ActivityWeatherConditionsPresentation.aroundEntryTimeLine(
                hourDate: referenceHour,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            )
        } else {
            aroundEntryLine = ActivityWeatherConditionsPresentation.dayOfActivityLine(
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            )
        }
        return ActivityWeatherConditionsSnapshot(
            conditionDescription: persisted.conditionDescription,
            symbolName: persisted.symbolName,
            temperatureDisplay: DiveQuantityFormatting.waterTemperature(
                celsius: persisted.temperatureCelsius,
                system: displayUnits
            ),
            humidityLine: humidityLine,
            windLine: windLine,
            dailyHighLowLine: dailyHighLowLine,
            aroundEntryLine: aroundEntryLine
        )
    }

    private nonisolated static func read(data: Data?) -> ActivityWeatherPersistedSnapshot? {
        guard let data else { return nil }
        return try? ActivityWeatherPersistedSnapshotCodec.decode(data)
    }
}
