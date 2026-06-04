import Foundation

/// Read-only labels for **Equipment Locker** detail UI.
enum EquipmentItemPresentation: Sendable {

    static func title(for item: EquipmentItem) -> String {
        let manufacturer = item.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = item.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if manufacturer.isEmpty { return model.isEmpty ? "Equipment" : model }
        if model.isEmpty { return manufacturer }
        return "\(manufacturer) \(model)"
    }

    static func gearTypeLabel(for item: EquipmentItem) -> String {
        EquipmentGearType.resolved(
            storedGearType: item.gearType,
            legacyType: item.type
        ).displayName
    }

    static func displayString(_ value: String?) -> String {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "—"
        }
        return raw
    }

    static func formattedDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func formattedPrice(_ price: Double?) -> String {
        guard let price else { return "—" }
        return String(format: "%.2f", price)
    }

    static func formattedRecurrence(days: Int?) -> String {
        guard let days, days > 0,
              let parts = EquipmentServiceSchedule.recurrenceIntervalAndUnit(forStoredDays: days)
        else { return "—" }
        let unitLabel = parts.unit.displayName.lowercased()
        return "Every \(parts.interval) \(unitLabel)"
    }

    static func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    static func divesUsedOnCount(for item: EquipmentItem) -> Int {
        item.divesUsedOn.count
    }

    static func divesUsedOnLabel(count: Int) -> String {
        switch count {
        case 0:
            return "Not used on any dives"
        case 1:
            return "1 dive"
        default:
            return "\(count) dives"
        }
    }
}
