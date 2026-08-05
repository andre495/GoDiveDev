import SwiftUI

/// Opens a catalog / user **`MarineLife`** species on the tab-root **`NavigationStack`**.
///
/// Inject on the **`NavigationStack`** (not only the root page) so pushed destinations like
/// **`FieldGuideMarineLifeDetailView`** inherit it for Similar species taps.
private struct OpenCatalogMarineLifeDetailKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

extension EnvironmentValues {
    /// When set on a tab **`NavigationStack`**, Similar species rows append a species-detail route.
    var openCatalogMarineLifeDetail: ((String) -> Void)? {
        get { self[OpenCatalogMarineLifeDetailKey.self] }
        set { self[OpenCatalogMarineLifeDetailKey.self] = newValue }
    }
}
