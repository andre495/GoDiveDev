import SwiftUI

/// Switch the root **`TabView`** selection and open Logbook destinations from nested screens.
private struct OpenDiveImportKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Home empty hero **Log Your First Dive** → Logbook import picker (**`ActivityUploadView`**).
    var openDiveImport: (() -> Void)? {
        get { self[OpenDiveImportKey.self] }
        set { self[OpenDiveImportKey.self] = newValue }
    }
}
