import Foundation

/// User-facing preferences stored in **`UserDefaults.standard`** (not SwiftData).
enum AppUserSettings: Sendable {
    /// When **`true`**, import/seed may run **`renumberAllChronologically`**; **delete** uses partial tail renumber on a background context (**`DiveActivityPostDeleteRenumbering`**).
    nonisolated static let automaticallyRenumberDivesKey = "goDiveAutomaticallyRenumberDives"

    /// When **`true`**, **`EnvironmentValues.diveDisplayUnitSystem`** is **`.imperial`** (depth in **ft**, temps in **°F**, cylinder pressure in **psi**, tank volume in **cu ft**). **`false`** → **`.metric`**. Stored **`DiveActivity`** values stay canonical (m, °C, psi).
    nonisolated static let useImperialDisplayUnitsKey = "goDiveUseImperialDisplayUnits"

    /// **`DefaultTankSize.rawValue`** — default rated size + material for new imports (**AL80**, **AL63**, **ST100**, **ST120**).
    nonisolated static let defaultTankSizeKey = "goDiveDefaultTankSize"

    /// Canonical **kg** for **Settings → Default Diver Weights → Salt water**; absent key = no default.
    nonisolated static let defaultSaltwaterWeightKilogramsKey = "goDiveDefaultSaltwaterWeightKilograms"

    /// Canonical **kg** for **Settings → Default Diver Weights → Fresh water**; absent key = no default.
    nonisolated static let defaultFreshwaterWeightKilogramsKey = "goDiveDefaultFreshwaterWeightKilograms"

    /// Bulk **UDDF** import: insert catalog **`DiveSite`** rows for unmatched site names in the file.
    nonisolated static let bulkUddfCreateDiveSitesKey = "goDiveBulkUddfCreateDiveSites"

    /// When **`true`**, attach Photos library items whose capture time falls within each dive window after dive import.
    nonisolated static let autoUploadMediaToActivitiesKey = "goDiveAutoUploadMediaToActivities"

    /// When **`true`**, Home / buddy / trip pages show layout region guides and a copyable geometry report.
    nonisolated static let showPageLayoutGeometryOverlayKey = "goDiveShowPageLayoutGeometryOverlay"

    static var automaticallyRenumberDives: Bool {
        UserDefaults.standard.bool(forKey: automaticallyRenumberDivesKey)
    }

    static var useImperialDisplayUnits: Bool {
        UserDefaults.standard.bool(forKey: useImperialDisplayUnitsKey)
    }

    nonisolated static func diveDisplayUnitSystem(userDefaults: UserDefaults = .standard) -> DiveDisplayUnitSystem {
        userDefaults.bool(forKey: useImperialDisplayUnitsKey) ? .imperial : .metric
    }

    static var defaultTankSize: DefaultTankSize {
        let raw = UserDefaults.standard.string(forKey: defaultTankSizeKey)
        return raw.flatMap(DefaultTankSize.init(rawValue:)) ?? DiveActivityTankDefaults.defaultSize
    }

    nonisolated static func defaultSaltwaterWeightKilograms(userDefaults: UserDefaults = .standard) -> Double? {
        optionalPositiveWeightKilograms(forKey: defaultSaltwaterWeightKilogramsKey, userDefaults: userDefaults)
    }

    nonisolated static func defaultFreshwaterWeightKilograms(userDefaults: UserDefaults = .standard) -> Double? {
        optionalPositiveWeightKilograms(forKey: defaultFreshwaterWeightKilogramsKey, userDefaults: userDefaults)
    }

    nonisolated static func setDefaultSaltwaterWeightKilograms(_ kilograms: Double?, userDefaults: UserDefaults = .standard) {
        setOptionalPositiveWeightKilograms(kilograms, forKey: defaultSaltwaterWeightKilogramsKey, userDefaults: userDefaults)
    }

    nonisolated static func setDefaultFreshwaterWeightKilograms(_ kilograms: Double?, userDefaults: UserDefaults = .standard) {
        setOptionalPositiveWeightKilograms(kilograms, forKey: defaultFreshwaterWeightKilogramsKey, userDefaults: userDefaults)
    }

    static var autoUploadMediaToActivities: Bool {
        UserDefaults.standard.bool(forKey: autoUploadMediaToActivitiesKey)
    }

    /// Toggle defaults applied when the user has never changed them (call once at launch).
    /// **`register(defaults:)`** only fills keys that are not already set, so it never overrides a saved choice.
    nonisolated static func registerDefaultValues(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            automaticallyRenumberDivesKey: true,
            useImperialDisplayUnitsKey: true,
            autoUploadMediaToActivitiesKey: true,
        ])
    }

    private nonisolated static func optionalPositiveWeightKilograms(
        forKey key: String,
        userDefaults: UserDefaults
    ) -> Double? {
        guard userDefaults.object(forKey: key) != nil else { return nil }
        let value = userDefaults.double(forKey: key)
        return value > 0 ? value : nil
    }

    private nonisolated static func setOptionalPositiveWeightKilograms(
        _ kilograms: Double?,
        forKey key: String,
        userDefaults: UserDefaults
    ) {
        guard let kilograms, kilograms > 0 else {
            userDefaults.removeObject(forKey: key)
            return
        }
        userDefaults.set(kilograms, forKey: key)
    }
}
