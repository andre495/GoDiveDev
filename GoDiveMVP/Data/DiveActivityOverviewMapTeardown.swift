import Foundation

/// When the single-dive overview is popping, live **MapKit** is torn down early so navigation stays responsive.
enum DiveActivityOverviewMapTeardown {
    /// **`true`** while the dive screen should host a live **`DiveLocationMapView`**.
    static func showsLiveMap(teardownRequested: Bool) -> Bool {
        !teardownRequested
    }
}
