import Foundation

/// Coordinate-based association of a dive to a known `DiveSite` (± tolerance on each axis).
enum DiveSiteCoordinateMatcher {
    static let toleranceDegrees = 0.01

    static func matchingSites(for coordinate: DiveCoordinate, in sites: [DiveSite]) -> [DiveSite] {
        sites.filter { site in
            guard let lat = site.latCoords, let lon = site.longCoords else { return false }
            return abs(coordinate.latitude - lat) <= toleranceDegrees
                && abs(coordinate.longitude - lon) <= toleranceDegrees
        }
    }

    /// Among sites within the tolerance box, picks the one with the smallest max axis delta.
    static func bestMatch(for coordinate: DiveCoordinate?, in sites: [DiveSite]) -> DiveSite? {
        guard let coordinate else { return nil }
        let candidates = matchingSites(for: coordinate, in: sites)
        return candidates.min(by: { axisBoxScore($0, coordinate: coordinate) < axisBoxScore($1, coordinate: coordinate) })
    }

    private static func axisBoxScore(_ site: DiveSite, coordinate: DiveCoordinate) -> Double {
        guard let lat = site.latCoords, let lon = site.longCoords else { return .infinity }
        return max(abs(coordinate.latitude - lat), abs(coordinate.longitude - lon))
    }
}
