import SwiftUI

/// User-selectable units for **presentation** only. Persisted dive data stays in **canonical** storage
/// (meters, °C, **psi**, etc.); importers and **`DiveActivity`** fields are unchanged.
enum DiveDisplayUnitSystem: String, Sendable, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
}

private struct DiveDisplayUnitSystemKey: EnvironmentKey {
    static var defaultValue: DiveDisplayUnitSystem = .metric
}

extension EnvironmentValues {
    var diveDisplayUnitSystem: DiveDisplayUnitSystem {
        get { self[DiveDisplayUnitSystemKey.self] }
        set { self[DiveDisplayUnitSystemKey.self] = newValue }
    }
}
