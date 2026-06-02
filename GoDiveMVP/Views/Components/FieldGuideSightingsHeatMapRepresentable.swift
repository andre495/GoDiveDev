import MapKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// MapKit heat-style regional overlays for Field Guide sightings.
struct FieldGuideSightingsHeatMapRepresentable: UIViewRepresentable {
    let heatCells: [FieldGuideSightingsHeatPresentation.HeatRegionCell]
    let mapRegion: MKCoordinateRegion
    var bottomContentMargin: CGFloat = 0
    var topObstructionHeight: CGFloat = 0
    var layoutHeight: CGFloat = 0
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
        mapView.delegate = context.coordinator
        context.coordinator.parent = self
        context.coordinator.syncOverlays(on: mapView, heatCells: heatCells)
        context.coordinator.applyLayout(on: mapView, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        let overlaysChanged = context.coordinator.syncOverlays(on: mapView, heatCells: heatCells)
        context.coordinator.applyLayout(on: mapView, animated: overlaysChanged)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FieldGuideSightingsHeatMapRepresentable?
        private var overlays: [MKCircle] = []
        private var cellByOverlay: [ObjectIdentifier: FieldGuideSightingsHeatPresentation.HeatRegionCell] = [:]
        private var lastHeatSignature: String?
        private var lastLayoutSignature: String?

        func regionSignature(_ region: MKCoordinateRegion) -> String {
            String(format: "%.4f,%.4f,%.4f,%.4f",
                   region.center.latitude,
                   region.center.longitude,
                   region.span.latitudeDelta,
                   region.span.longitudeDelta)
        }

        func layoutSignature(for parent: FieldGuideSightingsHeatMapRepresentable) -> String {
            String(format: "%.1f|%.1f|%.1f|%@|%@",
                   parent.bottomContentMargin,
                   parent.topObstructionHeight,
                   parent.layoutHeight,
                   regionSignature(parent.mapRegion),
                   parent.isUserInteractionEnabled ? "1" : "0")
        }

        func applyLayout(on mapView: MKMapView, animated: Bool) {
            guard let parent else { return }
            let signature = layoutSignature(for: parent)
            guard signature != lastLayoutSignature else { return }
            lastLayoutSignature = signature

            mapView.layoutMargins = UIEdgeInsets(
                top: parent.topObstructionHeight,
                left: 0,
                bottom: parent.bottomContentMargin,
                right: 0
            )
            mapView.isScrollEnabled = parent.isUserInteractionEnabled
            mapView.isZoomEnabled = parent.isUserInteractionEnabled
            mapView.setRegion(parent.mapRegion, animated: animated)
        }

        @discardableResult
        func syncOverlays(
            on mapView: MKMapView,
            heatCells: [FieldGuideSightingsHeatPresentation.HeatRegionCell]
        ) -> Bool {
            let signature = heatCells
                .map { "\($0.regionKey):\($0.sightingCount):\($0.normalizedIntensity)" }
                .sorted()
                .joined(separator: "|")
            guard signature != lastHeatSignature else { return false }
            lastHeatSignature = signature

            mapView.removeOverlays(overlays)
            overlays.removeAll()
            cellByOverlay.removeAll()

            for cell in heatCells {
                let center = CLLocationCoordinate2D(
                    latitude: cell.center.latitude,
                    longitude: cell.center.longitude
                )
                let circle = MKCircle(center: center, radius: cell.radiusMeters)
                cellByOverlay[ObjectIdentifier(circle)] = cell
                overlays.append(circle)
                mapView.addOverlay(circle)
            }
            return true
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle,
                  let cell = cellByOverlay[ObjectIdentifier(circle)]
            else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKCircleRenderer(circle: circle)
            let rgb = FieldGuideSightingsHeatPresentation.heatFillColor(intensity: cell.normalizedIntensity)
            renderer.fillColor = UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 0.46)
            renderer.strokeColor = UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 0.72)
            renderer.lineWidth = 1
            return renderer
        }
    }
}
#endif
