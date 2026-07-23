import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Map hero for the snorkel **heart rate** tab — GPS swim track polyline.
struct SnorkelSwimTrackMapView: View {
    let trackCoordinates: [DiveCoordinate]
    var bottomContentMargin: CGFloat = 0
    var topObstructionHeight: CGFloat = 0
    var layoutHeight: CGFloat = 0
    var cameraLayoutDetent: DiveActivityOverviewDetent = .large
    var isUserInteractionEnabled: Bool = true

    var body: some View {
        Group {
            if GoDiveUITestConfiguration.isActive {
                uiTestPlaceholder
            } else {
                #if canImport(UIKit)
                SnorkelSwimTrackMapRepresentable(
                    trackCoordinates: trackCoordinates,
                    bottomContentMargin: bottomContentMargin,
                    topObstructionHeight: topObstructionHeight,
                    layoutHeight: layoutHeight,
                    cameraLayoutDetent: cameraLayoutDetent,
                    isUserInteractionEnabled: isUserInteractionEnabled
                )
                #else
                Color.clear
                #endif
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var uiTestPlaceholder: some View {
        AppTheme.Colors.screenBackgroundGradient
            .overlay {
                Image(systemName: "figure.pool.swim")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
    }

    private var accessibilityLabelText: String {
        if trackCoordinates.isEmpty {
            return "Map with no GPS track recorded"
        }
        return "Map showing snorkel GPS track with \(trackCoordinates.count) points"
    }
}

#if canImport(UIKit)
struct SnorkelSwimTrackMapRepresentable: UIViewRepresentable {
    let trackCoordinates: [DiveCoordinate]
    let bottomContentMargin: CGFloat
    let topObstructionHeight: CGFloat
    let layoutHeight: CGFloat
    let cameraLayoutDetent: DiveActivityOverviewDetent
    var isUserInteractionEnabled: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.preferredConfiguration = MKImageryMapConfiguration()
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false
        GoDiveMapPointOfInterestSuppression.applyToMapKit(mapView)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncPolyline(on: mapView)
        mapView.isScrollEnabled = isUserInteractionEnabled
        mapView.isZoomEnabled = isUserInteractionEnabled

        guard layoutHeight > 1 else { return }

        let layoutContext = SnorkelTrackMapLayoutContext(
            coordinateCount: trackCoordinates.count,
            layoutHeight: layoutHeight,
            bottomContentMargin: bottomContentMargin,
            topObstructionHeight: topObstructionHeight,
            cameraLayoutDetent: cameraLayoutDetent
        )
        let previous = context.coordinator.lastAppliedLayoutContext
        let animate = previous != nil && previous?.cameraLayoutDetent != layoutContext.cameraLayoutDetent
        guard layoutContext != previous else { return }

        context.coordinator.applyCamera(on: mapView, animated: animate)
        context.coordinator.lastAppliedLayoutContext = layoutContext
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: SnorkelSwimTrackMapRepresentable?
        fileprivate var lastAppliedLayoutContext: SnorkelTrackMapLayoutContext?
        private var polyline: MKPolyline?

        func syncPolyline(on mapView: MKMapView) {
            guard let parent else { return }

            if let existing = polyline {
                mapView.removeOverlay(existing)
                polyline = nil
            }

            let coords = parent.trackCoordinates.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            guard coords.count >= 2 else { return }

            let line = MKPolyline(coordinates: coords, count: coords.count)
            polyline = line
            mapView.addOverlay(line)
        }

        func applyCamera(on mapView: MKMapView, animated: Bool) {
            guard let parent else { return }

            let edgePadding = UIEdgeInsets(
                top: parent.topObstructionHeight + 24,
                left: 32,
                bottom: parent.bottomContentMargin + 24,
                right: 32
            )

            if let region = SnorkelSwimTrackMapPresentation.fittingRegion(for: parent.trackCoordinates) {
                let rect = region.mkMapRect
                mapView.setVisibleMapRect(rect, edgePadding: edgePadding, animated: animated)
                return
            }

            if let coordinate = parent.trackCoordinates.first,
               DiveMapCoordinateResolver.isUsable(coordinate) {
                let camera = MKMapCamera(
                    lookingAtCenter: CLLocationCoordinate2D(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    ),
                    fromDistance: DiveLocationMapPresentation.cameraDistanceMeters(for: parent.cameraLayoutDetent),
                    pitch: 0,
                    heading: 0
                )
                mapView.setCamera(camera, animated: animated)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(AppTheme.Colors.accent)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

fileprivate struct SnorkelTrackMapLayoutContext: Equatable {
    var coordinateCount: Int
    var layoutHeight: CGFloat
    var bottomContentMargin: CGFloat
    var topObstructionHeight: CGFloat
    var cameraLayoutDetent: DiveActivityOverviewDetent
}
#endif
