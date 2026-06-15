import SwiftUI

/// Opens a catalog **`DiveSite`** on the tab-root **`NavigationStack`** (Explore map pattern).
///
/// Inject on the **`NavigationStack`** (not only the root page) so pushed destinations like **`TripDetailView`** inherit it.
private struct OpenCatalogDiveSiteDetailKey: EnvironmentKey {
    static let defaultValue: ((UUID) -> Void)? = nil
}

extension EnvironmentValues {
    /// When set on a tab **`NavigationStack`**, trip map pins append a site-detail route on that stack.
    var openCatalogDiveSiteDetail: ((UUID) -> Void)? {
        get { self[OpenCatalogDiveSiteDetailKey.self] }
        set { self[OpenCatalogDiveSiteDetailKey.self] = newValue }
    }
}
