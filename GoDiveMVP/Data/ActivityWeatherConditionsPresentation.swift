import Foundation

/// User-facing copy + eligibility for activity **Weather** (WeatherKit).
enum ActivityWeatherConditionsPresentation: Sendable {
    nonisolated static let sectionTitle = "Weather"
    nonisolated static let sectionAccessibilityIdentifier = "ActivityOverview.WeatherSection"
    nonisolated static let loadingAccessibilityIdentifier = "ActivityOverview.WeatherLoading"

    /// WeatherKit historical data starts Aug 1, 2021 (Apple).
    nonisolated static let weatherKitEarliestHistoryInstant: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: DateComponents(year: 2021, month: 8, day: 1)) ?? Date(timeIntervalSince1970: 1_627_776_000)
    }()

    nonisolated static let forecastHorizonDays = 10

    enum UnavailableReason: Sendable, Equatable {
        case noMapCoordinate
        case beforeHistoryWindow
        case beyondForecastHorizon
    }

    nonisolated static func unavailableReason(
        mapCoordinate: DiveCoordinate?,
        activityStart: Date,
        referenceNow: Date = Date()
    ) -> UnavailableReason? {
        guard let mapCoordinate, isValidCoordinate(mapCoordinate) else { return .noMapCoordinate }
        guard activityStart >= weatherKitEarliestHistoryInstant else { return .beforeHistoryWindow }
        let horizonEnd = Calendar.current.date(byAdding: .day, value: forecastHorizonDays, to: referenceNow)
            ?? referenceNow.addingTimeInterval(Double(forecastHorizonDays) * 86_400)
        guard activityStart <= horizonEnd else { return .beyondForecastHorizon }
        return nil
    }

    nonisolated static func isValidCoordinate(_ coordinate: DiveCoordinate) -> Bool {
        guard coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return false }
        guard (-90 ... 90).contains(coordinate.latitude), (-180 ... 180).contains(coordinate.longitude) else {
            return false
        }
        guard abs(coordinate.latitude) > 0.0001 || abs(coordinate.longitude) > 0.0001 else { return false }
        return true
    }

    nonisolated static func unavailableMessage(for reason: UnavailableReason) -> String {
        switch reason {
        case .noMapCoordinate:
            "Add a dive site or GPS location to see weather for this activity."
        case .beforeHistoryWindow:
            "Weather history is available for activities from August 2021 onward."
        case .beyondForecastHorizon:
            "Weather is available through about ten days ahead."
        }
    }

    nonisolated static func loadFailedMessage(for reason: LoadFailureReason = .generic) -> String {
        switch reason {
        case .generic:
            "Weather couldn’t be loaded right now. Try again in a few minutes."
        case .network:
            "Weather couldn’t be loaded. Check your connection and try again."
        case .permissionDenied:
            "Apple Weather isn’t authorized for GoDive yet. In Apple Developer, open App ID PrimoSoftware.GoDiveMVP and enable WeatherKit under both Capabilities and App Services, then delete the app and reinstall from Xcode."
        case .noData:
            "No weather data is available for this date and location."
        }
    }

    enum LoadFailureReason: Sendable, Equatable {
        case generic
        case network
        case permissionDenied
        case noData
    }

    /// ±12 hours around entry — fits WeatherKit’s 10-day window and helps historical hourly lookup.
    nonisolated static func tightHourlyQueryRange(
        activityStart: Date,
        referenceNow: Date = Date()
    ) -> (start: Date, end: Date) {
        let start = max(
            activityStart.addingTimeInterval(-12 * 3_600),
            weatherKitEarliestHistoryInstant
        )
        let horizonEnd =
            referenceNow.addingTimeInterval(Double(forecastHorizonDays) * 86_400)
        let end = min(activityStart.addingTimeInterval(12 * 3_600), horizonEnd)
        let adjustedEnd = max(end, start.addingTimeInterval(3_600))
        return (start, adjustedEnd)
    }

    /// Inclusive start, exclusive end — up to three local calendar days around the activity (WeatherKit allows 10).
    nonisolated static func weatherQueryRange(
        activityStart: Date,
        timeZoneOffsetSeconds: Int?,
        referenceNow: Date = Date()
    ) -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DiveActivityTimePresentation.resolvedTimeZone(forOffsetSeconds: timeZoneOffsetSeconds)
        let dayStart = calendar.startOfDay(for: activityStart)
        let queryStart = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart.addingTimeInterval(-86_400)
        let queryEnd = calendar.date(byAdding: .day, value: 2, to: dayStart) ?? dayStart.addingTimeInterval(2 * 86_400)

        let clippedStart = max(queryStart, weatherKitEarliestHistoryInstant)
        let horizonEnd =
            calendar.date(byAdding: .day, value: forecastHorizonDays, to: referenceNow)
            ?? referenceNow.addingTimeInterval(Double(forecastHorizonDays) * 86_400)
        let clippedEnd = min(queryEnd, calendar.date(byAdding: .day, value: 1, to: horizonEnd) ?? horizonEnd)
        let end = max(clippedEnd, clippedStart.addingTimeInterval(3_600))
        return (clippedStart, end)
    }

    nonisolated static func activityDayRange(
        activityStart: Date,
        timeZoneOffsetSeconds: Int?
    ) -> (start: Date, end: Date) {
        weatherQueryRange(activityStart: activityStart, timeZoneOffsetSeconds: timeZoneOffsetSeconds)
    }

    nonisolated static func normalizedHumidityFraction(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        if value >= 0, value <= 1 { return value }
        if value > 1, value <= 100 { return value / 100 }
        return nil
    }

    nonisolated static func dayOfActivityLine(
        activityStart: Date,
        timeZoneOffsetSeconds: Int?
    ) -> String {
        let date = DiveActivityTimePresentation.formatLongDateOnly(
            activityStart,
            timeZoneOffsetSeconds: timeZoneOffsetSeconds
        )
        return "Weather for \(date)"
    }

    nonisolated static func closestHourDate(to instant: Date, candidates: [Date]) -> Date? {
        guard !candidates.isEmpty else { return nil }
        return candidates.min { lhs, rhs in
            abs(lhs.timeIntervalSince(instant)) < abs(rhs.timeIntervalSince(instant))
        }
    }

    nonisolated static func aroundEntryTimeLine(
        hourDate: Date,
        timeZoneOffsetSeconds: Int?
    ) -> String {
        let time = DiveActivityTimePresentation.formatTimeOnly(hourDate, timeZoneOffsetSeconds: timeZoneOffsetSeconds)
        return "Around \(time) near entry"
    }

    nonisolated static func humidityDisplay(fraction: Double) -> String {
        let percent = min(100, max(0, Int((fraction * 100).rounded())))
        return "\(percent)% humidity"
    }

    nonisolated static func windDisplay(
        metersPerSecond: Double,
        displayUnits: DiveDisplayUnitSystem
    ) -> String {
        guard metersPerSecond >= 0, metersPerSecond.isFinite else { return "—" }
        switch displayUnits {
        case .metric:
            let kmh = metersPerSecond * 3.6
            return String(format: "Wind %.0f km/h", kmh)
        case .imperial:
            let mph = metersPerSecond * 2.2369362921
            return String(format: "Wind %.0f mph", mph)
        }
    }

    nonisolated static func dailyHighLowDisplay(
        highCelsius: Double?,
        lowCelsius: Double?,
        displayUnits: DiveDisplayUnitSystem
    ) -> String? {
        guard let highCelsius, let lowCelsius else { return nil }
        let high = DiveQuantityFormatting.waterTemperature(celsius: highCelsius, system: displayUnits)
        let low = DiveQuantityFormatting.waterTemperature(celsius: lowCelsius, system: displayUnits)
        guard high != "—", low != "—" else { return nil }
        return "High \(high) · Low \(low)"
    }
}

struct ActivityWeatherConditionsSnapshot: Sendable, Equatable {
    let conditionDescription: String
    let symbolName: String
    let temperatureDisplay: String
    let humidityLine: String?
    let windLine: String?
    let dailyHighLowLine: String?
    let aroundEntryLine: String
}
