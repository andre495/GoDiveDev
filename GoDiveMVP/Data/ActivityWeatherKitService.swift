import CoreLocation
import Foundation
import os
import WeatherKit

/// Fetches WeatherKit data for a logged activity time + map coordinate.
enum ActivityWeatherKitService: Sendable {
    private nonisolated static let logger = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "ActivityWeather")

    enum Outcome: Sendable {
        case loaded(ActivityWeatherConditionsSnapshot)
        case unavailable(ActivityWeatherConditionsPresentation.UnavailableReason)
        case failed(ActivityWeatherConditionsPresentation.LoadFailureReason)
    }

    nonisolated static func fetch(
        mapCoordinate: DiveCoordinate?,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) async -> Outcome {
        if let reason = ActivityWeatherConditionsPresentation.unavailableReason(
            mapCoordinate: mapCoordinate,
            activityStart: activityStart
        ) {
            return .unavailable(reason)
        }
        guard let mapCoordinate else { return .unavailable(.noMapCoordinate) }

        let location = CLLocation(latitude: mapCoordinate.latitude, longitude: mapCoordinate.longitude)
        let wideRange = ActivityWeatherConditionsPresentation.weatherQueryRange(
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        )
        let tightRange = ActivityWeatherConditionsPresentation.tightHourlyQueryRange(activityStart: activityStart)

        var lastFailure: ActivityWeatherConditionsPresentation.LoadFailureReason?

        for range in [tightRange, wideRange] {
            switch await loadFromHourlyAndDaily(
                location: location,
                queryRange: range,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds,
                displayUnits: displayUnits
            ) {
            case .loaded(let snapshot):
                return .loaded(snapshot)
            case .failed(let reason):
                lastFailure = reason
            case .noMatchingData:
                break
            }
        }

        switch await loadFromFullWeather(
            location: location,
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds,
            displayUnits: displayUnits
        ) {
        case .loaded(let snapshot):
            return .loaded(snapshot)
        case .failed(let reason):
            lastFailure = reason
        case .noMatchingData:
            break
        }

        if let lastFailure {
            return .failed(lastFailure)
        }
        return .failed(.noData)
    }

    /// Import-time capture — returns **`nil`** when coordinates/history are unavailable or WeatherKit fails.
    nonisolated static func fetchPersisted(
        mapCoordinate: DiveCoordinate?,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?
    ) async -> ActivityWeatherPersistedSnapshot? {
        if ActivityWeatherConditionsPresentation.unavailableReason(
            mapCoordinate: mapCoordinate,
            activityStart: activityStart
        ) != nil {
            return nil
        }
        guard let mapCoordinate else { return nil }

        let location = CLLocation(latitude: mapCoordinate.latitude, longitude: mapCoordinate.longitude)
        let wideRange = ActivityWeatherConditionsPresentation.weatherQueryRange(
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        )
        let tightRange = ActivityWeatherConditionsPresentation.tightHourlyQueryRange(activityStart: activityStart)

        for range in [tightRange, wideRange] {
            if let snapshot = await loadPersistedFromHourlyAndDaily(
                location: location,
                queryRange: range,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            ) {
                return snapshot
            }
        }

        return await loadPersistedFromFullWeather(
            location: location,
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        )
    }

    private nonisolated static func loadPersistedFromHourlyAndDaily(
        location: CLLocation,
        queryRange: (start: Date, end: Date),
        activityStart: Date,
        timeZoneOffsetSeconds: Int?
    ) async -> ActivityWeatherPersistedSnapshot? {
        do {
            let (hourlyForecast, dailyForecast) = try await WeatherService.shared.weather(
                for: location,
                including: .hourly(startDate: queryRange.start, endDate: queryRange.end),
                .daily(startDate: queryRange.start, endDate: queryRange.end)
            )
            if let snapshot = makePersistedSnapshot(
                hourlyForecast: hourlyForecast,
                dailyForecast: dailyForecast,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            ) {
                return snapshot
            }
            if let snapshot = makePersistedDailyFallbackSnapshot(
                dailyForecast: dailyForecast,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            ) {
                return snapshot
            }
            return nil
        } catch {
            let nsError = error as NSError
            logger.error(
                "WeatherKit import capture failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            return nil
        }
    }

    private nonisolated static func loadPersistedFromFullWeather(
        location: CLLocation,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?
    ) async -> ActivityWeatherPersistedSnapshot? {
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            if let snapshot = makePersistedSnapshot(
                hourlyForecast: weather.hourlyForecast,
                dailyForecast: weather.dailyForecast,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            ) {
                return snapshot
            }
            return makePersistedDailyFallbackSnapshot(
                dailyForecast: weather.dailyForecast,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            )
        } catch {
            let nsError = error as NSError
            logger.error(
                "WeatherKit import capture (full) failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            return nil
        }
    }

    private nonisolated static func makePersistedSnapshot(
        hourlyForecast: Forecast<HourWeather>,
        dailyForecast: Forecast<DayWeather>,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?
    ) -> ActivityWeatherPersistedSnapshot? {
        guard let hour = hourlyForecast.forecast.min(by: {
            abs($0.date.timeIntervalSince(activityStart)) < abs($1.date.timeIntervalSince(activityStart))
        }) else {
            return nil
        }

        let dayWeather = matchingDayWeather(
            in: dailyForecast,
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        )

        return ActivityWeatherPersistedSnapshot(
            conditionDescription: hour.condition.description,
            symbolName: hour.symbolName,
            temperatureCelsius: hour.temperature.converted(to: .celsius).value,
            humidityFraction: ActivityWeatherConditionsPresentation.normalizedHumidityFraction(hour.humidity),
            windMetersPerSecond: hour.wind.speed.converted(to: .metersPerSecond).value,
            dailyHighCelsius: dayWeather.map { $0.highTemperature.converted(to: .celsius).value },
            dailyLowCelsius: dayWeather.map { $0.lowTemperature.converted(to: .celsius).value },
            referenceHour: hour.date,
            usesDailyFallback: false,
            capturedAt: Date()
        )
    }

    private nonisolated static func makePersistedDailyFallbackSnapshot(
        dailyForecast: Forecast<DayWeather>,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?
    ) -> ActivityWeatherPersistedSnapshot? {
        guard let day = matchingDayWeather(
            in: dailyForecast,
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        ) ?? dailyForecast.forecast.first else {
            return nil
        }

        let highC = day.highTemperature.converted(to: .celsius).value
        let lowC = day.lowTemperature.converted(to: .celsius).value

        return ActivityWeatherPersistedSnapshot(
            conditionDescription: day.condition.description,
            symbolName: day.symbolName,
            temperatureCelsius: (highC + lowC) / 2,
            humidityFraction: nil,
            windMetersPerSecond: nil,
            dailyHighCelsius: highC,
            dailyLowCelsius: lowC,
            referenceHour: nil,
            usesDailyFallback: true,
            capturedAt: Date()
        )
    }

    private enum LoadAttempt: Sendable {
        case loaded(ActivityWeatherConditionsSnapshot)
        case failed(ActivityWeatherConditionsPresentation.LoadFailureReason)
        case noMatchingData
    }

    private nonisolated static func loadFromHourlyAndDaily(
        location: CLLocation,
        queryRange: (start: Date, end: Date),
        activityStart: Date,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) async -> LoadAttempt {
        do {
            let (hourlyForecast, dailyForecast) = try await WeatherService.shared.weather(
                for: location,
                including: .hourly(startDate: queryRange.start, endDate: queryRange.end),
                .daily(startDate: queryRange.start, endDate: queryRange.end)
            )
            if let snapshot = makeSnapshot(
                hourlyForecast: hourlyForecast,
                dailyForecast: dailyForecast,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds,
                displayUnits: displayUnits
            ) {
                return .loaded(snapshot)
            }
            if let snapshot = makeDailyFallbackSnapshot(
                dailyForecast: dailyForecast,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds,
                displayUnits: displayUnits
            ) {
                return .loaded(snapshot)
            }
            logger.debug(
                "WeatherKit empty for range (hours=\(hourlyForecast.forecast.count, privacy: .public), days=\(dailyForecast.forecast.count, privacy: .public))"
            )
            return .noMatchingData
        } catch {
            let reason = ActivityWeatherKitErrorMapping.failureReason(for: error)
            let nsError = error as NSError
            logger.error(
                "WeatherKit hourly/daily failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            return .failed(reason)
        }
    }

    private nonisolated static func loadFromFullWeather(
        location: CLLocation,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) async -> LoadAttempt {
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            if let snapshot = makeSnapshot(
                hourlyForecast: weather.hourlyForecast,
                dailyForecast: weather.dailyForecast,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds,
                displayUnits: displayUnits
            ) {
                return .loaded(snapshot)
            }
            if let snapshot = makeDailyFallbackSnapshot(
                dailyForecast: weather.dailyForecast,
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds,
                displayUnits: displayUnits
            ) {
                return .loaded(snapshot)
            }
            return .noMatchingData
        } catch {
            let reason = ActivityWeatherKitErrorMapping.failureReason(for: error)
            let nsError = error as NSError
            logger.error(
                "WeatherKit full weather failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            return .failed(reason)
        }
    }

    private nonisolated static func makeSnapshot(
        hourlyForecast: Forecast<HourWeather>,
        dailyForecast: Forecast<DayWeather>,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) -> ActivityWeatherConditionsSnapshot? {
        guard let hour = hourlyForecast.forecast.min(by: {
            abs($0.date.timeIntervalSince(activityStart)) < abs($1.date.timeIntervalSince(activityStart))
        }) else {
            return nil
        }

        let tempCelsius = hour.temperature.converted(to: .celsius).value
        let temperatureDisplay = DiveQuantityFormatting.waterTemperature(
            celsius: tempCelsius,
            system: displayUnits
        )

        let humidityLine: String? = ActivityWeatherConditionsPresentation
            .normalizedHumidityFraction(hour.humidity)
            .map { ActivityWeatherConditionsPresentation.humidityDisplay(fraction: $0) }

        let windMPS = hour.wind.speed.converted(to: .metersPerSecond).value
        let windLine = ActivityWeatherConditionsPresentation.windDisplay(
            metersPerSecond: windMPS,
            displayUnits: displayUnits
        )

        let dayWeather = matchingDayWeather(
            in: dailyForecast,
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        )
        let dailyHighLowLine = ActivityWeatherConditionsPresentation.dailyHighLowDisplay(
            highCelsius: dayWeather.map { $0.highTemperature.converted(to: .celsius).value },
            lowCelsius: dayWeather.map { $0.lowTemperature.converted(to: .celsius).value },
            displayUnits: displayUnits
        )

        return ActivityWeatherConditionsSnapshot(
            conditionDescription: hour.condition.description,
            symbolName: hour.symbolName,
            temperatureDisplay: temperatureDisplay,
            humidityLine: humidityLine,
            windLine: windLine,
            dailyHighLowLine: dailyHighLowLine,
            aroundEntryLine: ActivityWeatherConditionsPresentation.aroundEntryTimeLine(
                hourDate: hour.date,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            )
        )
    }

    private nonisolated static func makeDailyFallbackSnapshot(
        dailyForecast: Forecast<DayWeather>,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?,
        displayUnits: DiveDisplayUnitSystem
    ) -> ActivityWeatherConditionsSnapshot? {
        guard let day = matchingDayWeather(
            in: dailyForecast,
            activityStart: activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        ) ?? dailyForecast.forecast.first else {
            return nil
        }

        let highC = day.highTemperature.converted(to: .celsius).value
        let lowC = day.lowTemperature.converted(to: .celsius).value
        let midC = (highC + lowC) / 2
        let temperatureDisplay = DiveQuantityFormatting.waterTemperature(
            celsius: midC,
            system: displayUnits
        )
        let dailyHighLowLine = ActivityWeatherConditionsPresentation.dailyHighLowDisplay(
            highCelsius: highC,
            lowCelsius: lowC,
            displayUnits: displayUnits
        )

        return ActivityWeatherConditionsSnapshot(
            conditionDescription: day.condition.description,
            symbolName: day.symbolName,
            temperatureDisplay: temperatureDisplay,
            humidityLine: nil,
            windLine: nil,
            dailyHighLowLine: dailyHighLowLine,
            aroundEntryLine: ActivityWeatherConditionsPresentation.dayOfActivityLine(
                activityStart: activityStart,
                timeZoneOffsetSeconds: timeZoneOffsetSeconds
            )
        )
    }

    private nonisolated static func matchingDayWeather(
        in dailyForecast: Forecast<DayWeather>,
        activityStart: Date,
        timeZoneOffsetSeconds: Int?
    ) -> DayWeather? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DiveActivityTimePresentation.resolvedTimeZone(forOffsetSeconds: timeZoneOffsetSeconds)
        return dailyForecast.forecast.first { day in
            calendar.isDate(day.date, inSameDayAs: activityStart)
        }
    }
}
