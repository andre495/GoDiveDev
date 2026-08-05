import Foundation

/// Fixed lead times for upcoming-trip local notifications (owner-only; no day-of).
enum DiveTripReminderOffset: String, CaseIterable, Identifiable, Sendable {
    case oneMonthPrior
    case oneWeekPrior
    case oneDayPrior

    nonisolated var id: String { rawValue }

    nonisolated var sortIndex: Int {
        switch self {
        case .oneMonthPrior: return 0
        case .oneWeekPrior: return 1
        case .oneDayPrior: return 2
        }
    }
}

/// Fire dates, copy, and tap payload for upcoming trip reminders.
enum DiveTripReminderSchedule: Sendable {
    /// Always scheduled for upcoming trips (when fire dates are still in the future).
    nonisolated static let fixedOffsets: [DiveTripReminderOffset] = [
        .oneMonthPrior,
        .oneWeekPrior,
        .oneDayPrior,
    ]

    nonisolated static let deliveryHour = 9
    nonisolated static let deliveryMinute = 0

    nonisolated static let notificationIdentifierPrefix = "trip-reminder-"
    nonisolated static let userInfoTypeKey = "type"
    nonisolated static let userInfoTypeValue = "trip_reminder"
    nonisolated static let userInfoTripIDKey = "tripID"
    nonisolated static let userInfoOffsetKey = "offset"

    nonisolated static let openTripDetailNotification = Notification.Name(
        "GoDive.openTripDetailFromReminder"
    )

    /// Countries joined with commas, else trip title, else **`nil`**.
    nonisolated static func destinationLabel(countries: [String], title: String?) -> String? {
        if let countriesLine = TripPlannerPresentation.formattedCountries(from: countries) {
            return countriesLine
        }
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? nil : trimmedTitle
    }

    nonisolated static func fireDate(
        tripStartDate: Date,
        offset: DiveTripReminderOffset,
        calendar: Calendar = Calendar(identifier: .gregorian),
        now: Date = .now
    ) -> Date? {
        let startDay = calendar.startOfDay(for: tripStartDate)
        let reminderDay: Date?
        switch offset {
        case .oneMonthPrior:
            reminderDay = calendar.date(byAdding: .month, value: -1, to: startDay)
        case .oneWeekPrior:
            reminderDay = calendar.date(byAdding: .day, value: -7, to: startDay)
        case .oneDayPrior:
            reminderDay = calendar.date(byAdding: .day, value: -1, to: startDay)
        }
        guard let reminderDay else { return nil }
        guard let fire = calendar.date(
            bySettingHour: deliveryHour,
            minute: deliveryMinute,
            second: 0,
            of: reminderDay
        ) else {
            return nil
        }
        guard fire > now else { return nil }
        return fire
    }

    nonisolated static func notificationIdentifier(
        tripID: UUID,
        offset: DiveTripReminderOffset
    ) -> String {
        "\(notificationIdentifierPrefix)\(tripID.uuidString.lowercased())-\(offset.rawValue)"
    }

    nonisolated static func allNotificationIdentifiers(for tripID: UUID) -> [String] {
        fixedOffsets.map { notificationIdentifier(tripID: tripID, offset: $0) }
    }

    nonisolated static func notificationTitle() -> String {
        "Trip reminder"
    }

    /// e.g. **"Your trip to Bonaire is in 1 week. Pack your bags!"**
    nonisolated static func notificationBody(
        destinationLabel: String?,
        offset: DiveTripReminderOffset
    ) -> String {
        let trimmed = destinationLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subject = trimmed.isEmpty ? "Your trip" : "Your trip to \(trimmed)"
        switch offset {
        case .oneMonthPrior:
            return "\(subject) is in 1 month. Almost there!"
        case .oneWeekPrior:
            return "\(subject) is in 1 week. Pack your bags!"
        case .oneDayPrior:
            return "\(subject) is tomorrow!"
        }
    }

    nonisolated static func tripID(fromUserInfo userInfo: [AnyHashable: Any]) -> UUID? {
        guard (userInfo[userInfoTypeKey] as? String) == userInfoTypeValue else { return nil }
        guard let raw = userInfo[userInfoTripIDKey] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }
}

/// Holds a tapped trip-reminder target until Home can push trip detail.
@MainActor
final class DiveTripReminderNavigationStore {
    static let shared = DiveTripReminderNavigationStore()

    private(set) var pendingTripID: UUID?

    private init() {}

    func setPending(tripID: UUID) {
        pendingTripID = tripID
    }

    func consumePendingTripID() -> UUID? {
        let id = pendingTripID
        pendingTripID = nil
        return id
    }

    func clear() {
        pendingTripID = nil
    }
}
