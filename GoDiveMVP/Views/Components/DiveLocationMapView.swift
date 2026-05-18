import MapKit
import SwiftUI

/// MapKit map for a single dive: pin at **`coordinate`** when present, otherwise a default world region.
struct DiveLocationMapView: View {
    let coordinate: DiveCoordinate?
    var markerTitle: String = DiveLocationMapPresentation.defaultMarkerTitle
    /// Height from the **bottom** of **`layoutHeight`** covered by the sheet + home indicator (**points**).
    var bottomContentMargin: CGFloat = 0
    /// Height from the **top** of **`layoutHeight`** covered by status bar + dive toolbar (**points**).
    var topObstructionHeight: CGFloat = 0
    var layoutHeight: CGFloat = 0
    /// Resting sheet detent — camera reframes when this changes (not on every layout tick).
    var cameraLayoutDetent: DiveActivityOverviewDetent = .medium

    @State private var position: MapCameraPosition = .automatic
    @State private var lastAppliedLayoutContext: DiveMapCameraLayoutContext?

    var body: some View {
        Group {
            if GoDiveUITestConfiguration.isActive {
                uiTestMapPlaceholder
            } else {
                liveMap
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var liveMap: some View {
        Map(position: $position) {
            if let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) {
                Annotation(
                    markerTitle,
                    coordinate: CLLocationCoordinate2D(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                ) {
                    DiveSiteMapPinView()
                }
            }
        }
        .mapStyle(DiveOverviewMapStyle.mapStyle)
        .onAppear {
            scheduleCameraRefresh(animated: false)
        }
        .task(id: mapLayoutContext) {
            await Task.yield()
            let previous = lastAppliedLayoutContext
            let animateDetentChange = previous != nil
                && previous?.cameraLayoutDetent != mapLayoutContext.cameraLayoutDetent
            applyCameraPosition(animated: animateDetentChange)
        }
    }

    private var uiTestMapPlaceholder: some View {
        AppTheme.Colors.screenBackgroundGradient
            .overlay {
                Image(systemName: "map")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
    }

    private var coordinateIdentity: String {
        guard let coordinate else { return "none" }
        return "\(coordinate.latitude),\(coordinate.longitude)"
    }

    private var mapLayoutContext: DiveMapCameraLayoutContext {
        DiveMapCameraLayoutContext(
            coordinateIdentity: coordinateIdentity,
            layoutHeight: layoutHeight,
            bottomContentMargin: bottomContentMargin,
            topObstructionHeight: topObstructionHeight,
            cameraLayoutDetent: cameraLayoutDetent
        )
    }

    private var accessibilityLabelText: String {
        if let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) {
            return "Map showing dive location at \(coordinate.latitude), \(coordinate.longitude)"
        }
        return "Map with no dive location recorded"
    }

    private func scheduleCameraRefresh(animated: Bool) {
        Task { @MainActor in
            await Task.yield()
            applyCameraPosition(animated: animated)
        }
    }

    private func applyCameraPosition(animated: Bool) {
        guard layoutHeight > 1 else { return }

        let context = mapLayoutContext
        guard context != lastAppliedLayoutContext else { return }

        let target = Self.cameraPosition(
            for: coordinate,
            bottomContentMargin: bottomContentMargin,
            topObstructionHeight: topObstructionHeight,
            layoutHeight: layoutHeight,
            cameraLayoutDetent: cameraLayoutDetent
        )

        lastAppliedLayoutContext = context
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                position = target
            }
        } else {
            position = target
        }
    }

    private static func cameraPosition(
        for coordinate: DiveCoordinate?,
        bottomContentMargin: CGFloat,
        topObstructionHeight: CGFloat,
        layoutHeight: CGFloat,
        cameraLayoutDetent: DiveActivityOverviewDetent
    ) -> MapCameraPosition {
        guard let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) else {
            return .region(DiveLocationMapPresentation.defaultRegion.mkCoordinateRegion)
        }
        let distance = DiveLocationMapPresentation.cameraDistanceMeters(for: cameraLayoutDetent)
        let center = DiveLocationMapPresentation.adjustedMapCenter(
            for: coordinate,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstructionHeight,
            bottomContentMargin: bottomContentMargin,
            mapCameraDetent: cameraLayoutDetent
        )
        return .camera(
            MapCamera(
                centerCoordinate: center,
                distance: distance
            )
        )
    }
}

/// Shared MapKit base layer for **Explore** and dive overview maps.
enum DiveOverviewMapStyle {
    static let mapStyle = MapStyle.imagery(elevation: .realistic)
}
