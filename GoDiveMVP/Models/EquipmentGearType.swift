import Foundation

/// Locker gear category — persisted on **`EquipmentItem.gearType`**.
enum EquipmentGearType: String, CaseIterable, Identifiable, Sendable {
    case bcd = "BCD"
    case mask = "Mask"
    case snorkel = "Snorkel"
    case fins = "Fins"
    case wetsuit = "Wetsuit"
    case camera = "Camera"
    case regulator = "Regulator"
    case octopus = "Octopus"
    case other = "Other"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String { rawValue }

    /// Resolves stored **`gearType`** or legacy free-text **`type`**.
    nonisolated static func resolved(
        storedGearType: String?,
        legacyType: String? = nil
    ) -> EquipmentGearType {
        if let stored = storedGearType?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty,
           let match = EquipmentGearType(rawValue: stored) {
            return match
        }
        if let legacy = legacyType?.trimmingCharacters(in: .whitespacesAndNewlines),
           !legacy.isEmpty,
           let match = matchLegacyLabel(legacy) {
            return match
        }
        return .other
    }

    nonisolated private static func matchLegacyLabel(_ label: String) -> EquipmentGearType? {
        let normalized = label.lowercased()
        return allCases.first { $0.displayName.lowercased() == normalized }
    }
}
