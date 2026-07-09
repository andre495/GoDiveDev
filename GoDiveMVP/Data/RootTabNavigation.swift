import SwiftUI

/// Switch the root **`TabView`** selection from nested screens (e.g. Home empty hero → Logbook).
private struct OpenLogbookKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var openLogbook: (() -> Void)? {
        get { self[OpenLogbookKey.self] }
        set { self[OpenLogbookKey.self] = newValue }
    }
}
