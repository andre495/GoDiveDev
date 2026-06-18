import Foundation

/// User default diver ballast from **Settings → Default Diver Weights**; applied on new imports.
enum DiveActivityDiverWeightDefaults: Sendable {
    nonisolated static let defaultWaterType: DiveWaterType = .saltwater

    nonisolated static func resolvedDefaultKilograms(
        for waterType: DiveWaterType,
        userDefaults: UserDefaults = .standard
    ) -> Double? {
        switch waterType {
        case .saltwater:
            return AppUserSettings.defaultSaltwaterWeightKilograms(userDefaults: userDefaults)
        case .freshwater:
            return AppUserSettings.defaultFreshwaterWeightKilograms(userDefaults: userDefaults)
        }
    }

    /// Resolves water type from linked **`DiveSite`**, else activity value, else salt water.
    nonisolated static func resolvedWaterType(for activity: DiveActivity) -> DiveWaterType {
        activity.diveSite?.resolvedWaterType
            ?? activity.diveWaterType
            ?? defaultWaterType
    }

    /// Sets **`diveWaterType`** from the linked catalog site (or salt default) and fills **`diverWeightKilograms`** when still empty.
    nonisolated static func applyInheritedDefaults(
        to activity: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) {
        let waterType = resolvedWaterType(for: activity)
        activity.diveWaterType = waterType
        guard activity.diverWeightKilograms == nil else { return }
        activity.diverWeightKilograms = resolvedDefaultKilograms(for: waterType, userDefaults: userDefaults)
    }

    /// Backward-compatible name for import / manual-create callers.
    nonisolated static func applyImportDefaults(
        to activity: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) {
        applyInheritedDefaults(to: activity, userDefaults: userDefaults)
    }
}
