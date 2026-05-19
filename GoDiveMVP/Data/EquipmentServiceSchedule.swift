import Foundation

/// Recurrence unit for the equipment service **Every …** form control.
enum EquipmentRecurrenceUnit: String, CaseIterable, Identifiable, Sendable {
    case days
    case weeks
    case years

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .days: return "Days"
        case .weeks: return "Weeks"
        case .years: return "Years"
        }
    }

    /// Calendar days represented by one interval of this unit (years use **365**).
    var daysPerInterval: Int {
        switch self {
        case .days: return 1
        case .weeks: return 7
        case .years: return 365
        }
    }
}

/// Maps **next service date** + recurrence to persisted **`EquipmentItem`** service fields.
enum EquipmentServiceSchedule: Sendable {

    static func recurrenceDays(interval: Int, unit: EquipmentRecurrenceUnit) -> Int? {
        guard interval > 0 else { return nil }
        return interval * unit.daysPerInterval
    }

    /// **`serviceDate`** (last service) from **next** minus **`recurrenceDays`**.
    static func lastServiceDate(nextServiceDate: Date, recurrenceDays: Int) -> Date? {
        guard recurrenceDays > 0 else { return nil }
        return Calendar(identifier: .gregorian).date(byAdding: .day, value: -recurrenceDays, to: nextServiceDate)
    }

    /// Infers **next** from stored **last** + recurrence (legacy rows / edit preload).
    static func nextServiceDate(lastServiceDate: Date, recurrenceDays: Int) -> Date? {
        guard recurrenceDays > 0 else { return nil }
        return Calendar(identifier: .gregorian).date(byAdding: .day, value: recurrenceDays, to: lastServiceDate)
    }

    /// Best-effort split of stored **`serviceRecurrenceDays`** into form interval + unit (prefers years, then weeks).
    static func recurrenceIntervalAndUnit(forStoredDays days: Int) -> (interval: Int, unit: EquipmentRecurrenceUnit)? {
        guard days > 0 else { return nil }
        if days % 365 == 0 { return (days / 365, .years) }
        if days % 7 == 0 { return (days / 7, .weeks) }
        return (days, .days)
    }
}
