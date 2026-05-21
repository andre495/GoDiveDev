import SwiftUI

extension View {
    /// Frosted tab bar so scroll content (e.g. **Logbook**) can show through underneath.
    func goDiveRootTabBarChrome() -> some View {
        toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}
