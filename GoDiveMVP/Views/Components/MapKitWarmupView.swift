import MapKit
import SwiftUI

/// Invisible **SwiftUI** `Map` mounted at launch — same stack as **`DiveLocationMapView`**.
struct MapKitWarmupView: View {
    private static let cameraPosition = MapCameraPosition.region(
        DiveLocationMapPresentation.defaultRegion.mkCoordinateRegion
    )

    var body: some View {
        Map(position: .constant(Self.cameraPosition))
            .mapStyle(DiveOverviewMapStyle.mapStyle)
            .frame(width: 1, height: 1)
            .clipped()
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                MapKitWarmup.warmUpIfNeeded()
            }
    }
}
