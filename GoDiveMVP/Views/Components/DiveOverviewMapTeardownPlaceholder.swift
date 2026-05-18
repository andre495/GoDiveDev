import SwiftUI

/// Lightweight hero stand-in after **`DiveLocationMapView`** is removed during pop (avoids MapKit teardown on the transition).
struct DiveOverviewMapTeardownPlaceholder: View {
    var body: some View {
        AppTheme.Colors.screenBackgroundGradient
            .ignoresSafeArea()
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("DiveActivity.MapHeroTeardownPlaceholder")
    }
}
