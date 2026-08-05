import Foundation

/// Reminder lead times for equipment recurring-service notifications (local, owner-only).
enum EquipmentServiceReminderOffset: String, CaseIterable, Identifiable, Sendable, Codable {
    case oneMonthPrior
    case oneWeekPrior
    case oneDayPrior
    case dayOfService

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String {
        switch self {
        case .oneMonthPrior: return "1 month prior"
        case .oneWeekPrior: return "1 week prior"
        case .oneDayPrior: return "1 day prior"
        case .dayOfService: return "Day of service"
        }
    }

    /// Stable sort: soonest relative lead time last (month → day-of).
    nonisolated var sortIndex: Int {
        switch self {
        case .oneMonthPrior: return 0
        case .oneWeekPrior: return 1
        case .oneDayPrior: return 2
        case .dayOfService: return 3
        }
    }
}

/// Encode / decode reminder offsets and compute local fire dates for equipment service.
enum EquipmentServiceReminderSchedule: Sendable {
    /// Persisted token when the user opts out of reminders while recurring service is on.
    nonisolated static let nonePersistedToken = "none"

    /// Default selection when Settings → Gear servicing is **on**.
    nonisolated static let enabledDefaultOffsets: Set<EquipmentServiceReminderOffset> = [.oneWeekPrior]

    /// New-gear / empty-selection default from the global gear-servicing setting.
    nonisolated static func defaultOffsets(
        userDefaults: UserDefaults = .standard
    ) -> Set<EquipmentServiceReminderOffset> {
        AppUserSettings.notifyGearServiceReminders(userDefaults: userDefaults)
            ? enabledDefaultOffsets
            : []
    }

    /// Local delivery hour for service reminders (device calendar).
    nonisolated static let deliveryHour = 9
    nonisolated static let deliveryMinute = 0

    nonisolated static let notificationIdentifierPrefix = "equipment-service-"
    nonisolated static let userInfoTypeKey = "type"
    nonisolated static let userInfoTypeValue = "equipment_service_reminder"
    nonisolated static let userInfoEquipmentIDKey = "equipmentID"
    nonisolated static let userInfoOffsetKey = "offset"

    /// Posts when the user taps an equipment service reminder — open that gear on Home.
    nonisolated static let openEquipmentDetailNotification = Notification.Name(
        "GoDive.openEquipmentDetailFromServiceReminder"
    )

    /// Persist selection. Empty set → **`none`**.
    nonisolated static func encode(_ offsets: Set<EquipmentServiceReminderOffset>) -> String {
        guard !offsets.isEmpty else { return nonePersistedToken }
        return offsets
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(\.rawValue)
            .joined(separator: ",")
    }

    /// Decode persisted raw. Unknown tokens ignored. **`nil`** / blank → no reminders (legacy rows).
    nonisolated static func decode(_ raw: String?) -> Set<EquipmentServiceReminderOffset> {
        guard let raw else { return [] }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != nonePersistedToken else { return [] }
        var result = Set<EquipmentServiceReminderOffset>()
        for part in trimmed.split(separator: ",") {
            let token = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if let offset = EquipmentServiceReminderOffset(rawValue: token) {
                result.insert(offset)
            }
        }
        return result
    }

    /// Fire date at **`deliveryHour`:`deliveryMinute`** on the reminder calendar day, or **`nil`** if invalid.
    nonisolated static func fireDate(
        nextServiceDate: Date,
        offset: EquipmentServiceReminderOffset,
        calendar: Calendar = Calendar(identifier: .gregorian),
        now: Date = .now
    ) -> Date? {
        let serviceDay = calendar.startOfDay(for: nextServiceDate)
        let reminderDay: Date?
        switch offset {
        case .oneMonthPrior:
            reminderDay = calendar.date(byAdding: .month, value: -1, to: serviceDay)
        case .oneWeekPrior:
            reminderDay = calendar.date(byAdding: .day, value: -7, to: serviceDay)
        case .oneDayPrior:
            reminderDay = calendar.date(byAdding: .day, value: -1, to: serviceDay)
        case .dayOfService:
            reminderDay = serviceDay
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
        equipmentID: UUID,
        offset: EquipmentServiceReminderOffset
    ) -> String {
        "\(notificationIdentifierPrefix)\(equipmentID.uuidString.lowercased())-\(offset.rawValue)"
    }

    nonisolated static func allNotificationIdentifiers(for equipmentID: UUID) -> [String] {
        EquipmentServiceReminderOffset.allCases.map {
            notificationIdentifier(equipmentID: equipmentID, offset: $0)
        }
    }

    nonisolated static func sortedOffsets(_ offsets: Set<EquipmentServiceReminderOffset>) -> [EquipmentServiceReminderOffset] {
        offsets.sorted { $0.sortIndex < $1.sortIndex }
    }

    nonisolated static func formattedSummary(_ offsets: Set<EquipmentServiceReminderOffset>) -> String {
        let sorted = sortedOffsets(offsets)
        guard !sorted.isEmpty else { return "None" }
        return sorted.map(\.displayName).joined(separator: ", ")
    }

    nonisolated static func notificationTitle() -> String {
        "Service reminder"
    }

    /// e.g. **"Your Apeks XTX50 needs service in 1 week"** / **"... today"**.
    nonisolated static func notificationBody(
        equipmentTitle: String,
        offset: EquipmentServiceReminderOffset
    ) -> String {
        let trimmed = equipmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "gear" : trimmed
        return "Your \(name) needs service \(serviceTimingPhrase(for: offset))"
    }

    nonisolated static func serviceTimingPhrase(for offset: EquipmentServiceReminderOffset) -> String {
        switch offset {
        case .oneMonthPrior: return "in 1 month"
        case .oneWeekPrior: return "in 1 week"
        case .oneDayPrior: return "in 1 day"
        case .dayOfService: return "today"
        }
    }

    nonisolated static func equipmentID(fromUserInfo userInfo: [AnyHashable: Any]) -> UUID? {
        guard (userInfo[userInfoTypeKey] as? String) == userInfoTypeValue else { return nil }
        guard let raw = userInfo[userInfoEquipmentIDKey] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return UUID(uuidString: trimmed)
    }
}

/// Holds a tapped equipment-service reminder target until Home can push detail.
@MainActor
final class EquipmentServiceReminderNavigationStore {
    static let shared = EquipmentServiceReminderNavigationStore()

    private(set) var pendingEquipmentID: UUID?

    private init() {}

    func setPending(equipmentID: UUID) {
        pendingEquipmentID = equipmentID
    }

    func consumePendingEquipmentID() -> UUID? {
        let id = pendingEquipmentID
        pendingEquipmentID = nil
        return id
    }

    func clear() {
        pendingEquipmentID = nil
    }
}
