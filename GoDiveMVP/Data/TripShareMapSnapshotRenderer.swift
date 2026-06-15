import CoreGraphics
import Foundation
import MapKit

enum TripShareMapSnapshotPresentation: Sendable {

    nonisolated static let mapAspectRatio: CGFloat = 4 / 3

    nonisolated static func mapSnapshotSize(cardWidth: CGFloat) -> CGSize {
        let width = max(cardWidth - TripShareCardPresentation.contentPadding * 2, 1)
        return CGSize(width: width, height: width / mapAspectRatio)
    }

    nonisolated static func accessibilityLabel(for pins: [TripDetailMapPin]) -> String {
        TripDetailMapPresentation.accessibilityLabel(for: pins)
    }
}

#if canImport(UIKit)
import SwiftUI
import UIKit

enum TripShareMapSnapshotRenderer {

    @MainActor
    static func snapshotImage(
        pins: [TripDetailMapPin],
        cardWidth: CGFloat = TripShareCardPresentation.cardWidth,
        scale: CGFloat = TripShareCardPresentation.renderScale
    ) async -> UIImage? {
        guard !pins.isEmpty else { return nil }

        let size = TripShareMapSnapshotPresentation.mapSnapshotSize(cardWidth: cardWidth)
        if let apiKey = GoogleMapsBootstrap.loadAPIKey(),
           let url = TripShareGoogleStaticMapPresentation.staticMapURL(
               pins: pins,
               size: size,
               scale: TripShareGoogleStaticMapPresentation.clampedScale(for: scale),
               apiKey: apiKey
           ),
           let image = await fetchImage(from: url) {
            return image
        }

        return await mapKitSnapshotImage(pins: pins, size: size, scale: scale)
    }

    private static func fetchImage(from url: URL) async -> UIImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode),
                  let image = UIImage(data: data)
            else { return nil }
            return image
        } catch {
            return nil
        }
    }

    private static func mapKitSnapshotImage(
        pins: [TripDetailMapPin],
        size: CGSize,
        scale: CGFloat
    ) async -> UIImage? {
        guard let region = TripDetailMapPresentation.region(for: pins) else { return nil }

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = scale
        options.mapType = .hybrid

        let snapshotter = MKMapSnapshotter(options: options)
        guard let snapshot = try? await snapshotter.start() else { return nil }
        return drawPins(on: snapshot, pins: pins)
    }

    private static func drawPins(
        on snapshot: MKMapSnapshotter.Snapshot,
        pins: [TripDetailMapPin]
    ) -> UIImage {
        let baseImage = snapshot.image
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)
        return renderer.image { _ in
            baseImage.draw(at: .zero)

            for pin in pins {
                let coordinate = CLLocationCoordinate2D(
                    latitude: pin.coordinate.latitude,
                    longitude: pin.coordinate.longitude
                )
                let point = snapshot.point(for: coordinate)
                let tint = pinTint(for: pin.kind)
                let pinImage = MapPushPinImageFactory.makeMapAnnotationPinImage(
                    headColor: tint,
                    scale: baseImage.scale
                )
                let drawOrigin = CGPoint(
                    x: point.x - pinImage.size.width / 2,
                    y: point.y - pinImage.size.height / 2
                )
                pinImage.draw(at: drawOrigin)
            }
        }
    }

    private static func pinTint(for kind: TripDetailMapPinKind) -> Color {
        switch kind {
        case .planned:
            return Color(uiColor: .systemBlue)
        case .completed:
            return Color(uiColor: .systemRed)
        }
    }
}
#endif
