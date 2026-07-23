import Foundation
import SwiftData

/// Deprecated — account population runs from **`AccountSession.restoreSession`** via **`AccountRemoteDataPopulation`**.
enum AppLaunchDeferredSessionReconciliation: Sendable {
    static func scheduleAfterOverlayDismissed(container: ModelContainer) {
        // Kept for call-site compatibility; restore path already populates remote account data.
    }
}
