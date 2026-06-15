import CoreGraphics
import Foundation

/// Google Maps Static API snapshot for trip share PNGs (**`TripShareMapSnapshotRenderer`**).
enum TripShareGoogleStaticMapPresentation: Sendable {

    nonisolated static let staticMapEndpoint = "https://maps.googleapis.com/maps/api/staticmap"
    nonisolated static let maxPixelDimension = 640
    nonisolated static let maxScale = 2

    /// Builds a hybrid static-map URL with blue planned / red completed markers.
    nonisolated static func staticMapURL(
        pins: [TripDetailMapPin],
        size: CGSize,
        scale: Int,
        apiKey: String
    ) -> URL? {
        guard !pins.isEmpty else { return nil }

        let width = min(max(Int(size.width.rounded(.up)), 1), maxPixelDimension)
        let height = min(max(Int(size.height.rounded(.up)), 1), maxPixelDimension)
        let clampedScale = min(max(scale, 1), maxScale)

        var components = URLComponents(string: staticMapEndpoint)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "maptype", value: "hybrid"),
            URLQueryItem(name: "size", value: "\(width)x\(height)"),
            URLQueryItem(name: "scale", value: String(clampedScale)),
            URLQueryItem(name: "key", value: apiKey),
        ]

        let visible = pins
            .map { formattedCoordinate($0.coordinate) }
            .joined(separator: "|")
        queryItems.append(URLQueryItem(name: "visible", value: visible))

        for kind in [TripDetailMapPinKind.planned, .completed] {
            let group = pins.filter { $0.kind == kind }
            guard !group.isEmpty else { continue }
            let color = kind == .planned ? "blue" : "red"
            let coordinates = group.map { formattedCoordinate($0.coordinate) }.joined(separator: "|")
            queryItems.append(URLQueryItem(name: "markers", value: "color:\(color)|\(coordinates)"))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    nonisolated static func clampedScale(for renderScale: CGFloat) -> Int {
        min(max(Int(renderScale.rounded()), 1), maxScale)
    }

    private nonisolated static func formattedCoordinate(_ coordinate: DiveCoordinate) -> String {
        String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
    }
}
