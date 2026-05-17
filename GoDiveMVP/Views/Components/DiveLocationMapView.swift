import MapKit
import SwiftUI

/// MapKit map for a single dive: pin at **`coordinate`** when present, otherwise a default world region.
struct DiveLocationMapView: View {
    let coordinate: DiveCoordinate?
    var markerTitle: String
    /// Height from the **bottom** of **`layoutHeight`** covered by the sheet + home indicator (**points**).
    var bottomContentMargin: CGFloat = 0
    /// Height from the **top** of **`layoutHeight`** covered by status bar + dive toolbar (**points**).
    var topObstructionHeight: CGFloat = 0
    var layoutHeight: CGFloat = 0
    /// Resting sheet detent — camera reframes when this changes (not on every layout tick).
    var cameraLayoutDetent: DiveActivityOverviewDetent = .medium

    @State private var position: MapCameraPosition
    @State private var lastAppliedCameraDetent: DiveActivityOverviewDetent?

    init(
        coordinate: DiveCoordinate?,
        markerTitle: String = DiveLocationMapPresentation.defaultMarkerTitle,
        bottomContentMargin: CGFloat = 0,
        topObstructionHeight: CGFloat = 0,
        layoutHeight: CGFloat = 0,
        cameraLayoutDetent: DiveActivityOverviewDetent = .medium
    ) {
        self.coordinate = coordinate
        self.markerTitle = markerTitle
        self.bottomContentMargin = bottomContentMargin
        self.topObstructionHeight = topObstructionHeight
        self.layoutHeight = layoutHeight
        self.cameraLayoutDetent = cameraLayoutDetent
        _position = State(
            initialValue: Self.cameraPosition(
                for: coordinate,
                bottomContentMargin: bottomContentMargin,
                topObstructionHeight: topObstructionHeight,
                layoutHeight: layoutHeight
            )
        )
        _lastAppliedCameraDetent = State(initialValue: cameraLayoutDetent)
    }

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
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .id(coordinateIdentity)
        .onAppear {
            applyCameraPosition(animated: false)
        }
        .onChange(of: coordinateIdentity) { _, _ in
            applyCameraPosition(animated: false)
        }
        .onChange(of: cameraLayoutDetent) { _, newDetent in
            guard newDetent != lastAppliedCameraDetent else { return }
            lastAppliedCameraDetent = newDetent
            applyCameraPosition(animated: false)
        }
        .onChange(of: layoutHeight) { oldHeight, newHeight in
            guard abs(oldHeight - newHeight) > 1 else { return }
            applyCameraPosition(animated: false)
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

    private var accessibilityLabelText: String {
        if let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) {
            return "Map showing dive location at \(coordinate.latitude), \(coordinate.longitude)"
        }
        return "Map with no dive location recorded"
    }

    private func applyCameraPosition(animated: Bool) {
        let target = Self.cameraPosition(
            for: coordinate,
            bottomContentMargin: bottomContentMargin,
            topObstructionHeight: topObstructionHeight,
            layoutHeight: layoutHeight
        )
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
        layoutHeight: CGFloat
    ) -> MapCameraPosition {
        guard let coordinate, DiveMapCoordinateResolver.isUsable(coordinate) else {
            return .region(DiveLocationMapPresentation.defaultRegion.mkCoordinateRegion)
        }
        let center = DiveLocationMapPresentation.adjustedMapCenter(
            for: coordinate,
            layoutHeight: layoutHeight,
            bottomObstructionHeight: bottomContentMargin,
            topObstructionHeight: topObstructionHeight
        )
        return .camera(
            MapCamera(
                centerCoordinate: center,
                distance: DiveLocationMapPresentation.diveSiteCameraDistanceMeters
            )
        )
    }
}
