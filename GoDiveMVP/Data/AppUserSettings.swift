import Foundation

/// User-facing preferences stored in **`UserDefaults.standard`** (not SwiftData).
enum AppUserSettings {
    /// When **`true`**, **`DiveActivityDiveNumbering.renumberAllChronologically`** runs after dive **insert** (import) and **delete** so **`diveNumber`** is **1…n** by **`startTime`** ( **`id`** tie-break).
    static let automaticallyRenumberDivesKey = "goDiveAutomaticallyRenumberDives"

    /// When **`true`**, **`EnvironmentValues.diveDisplayUnitSystem`** is **`.imperial`** (depth in **ft**, temps in **°F**, cylinder pressure in **psi**, tank volume in **cu ft** when parsable). **`false`** → **`.metric`**. Stored **`DiveActivity`** values stay canonical (m, °C, psi).
    static let useImperialDisplayUnitsKey = "goDiveUseImperialDisplayUnits"

    static var automaticallyRenumberDives: Bool {
        UserDefaults.standard.bool(forKey: automaticallyRenumberDivesKey)
    }

    static var useImperialDisplayUnits: Bool {
        UserDefaults.standard.bool(forKey: useImperialDisplayUnitsKey)
    }
}
