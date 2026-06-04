import Foundation

/// Selects the map rendering backend for dive / Explore surfaces.
enum GoDiveMapEngine: String, Equatable, Sendable {
    case mapKit
    case googleMaps

    /// Optional override for tests and tooling (still supported when no secrets file).
    nonisolated static let googleMapsLaunchArgument = "-GoDiveMapEngineGoogle"

    /// **`GoogleMapsSecrets.plist`** API key present → **Google Maps**; else **MapKit** unless launch arg opts in.
    nonisolated static var active: GoDiveMapEngine {
        resolved(activeLaunchArguments: ProcessInfo.processInfo.arguments)
    }

    nonisolated static func resolved(activeLaunchArguments: [String]) -> GoDiveMapEngine {
        resolved(
            activeLaunchArguments: activeLaunchArguments,
            hasGoogleMapsAPIKey: GoogleMapsBootstrap.loadAPIKey() != nil
        )
    }

    nonisolated static func resolved(
        activeLaunchArguments: [String],
        hasGoogleMapsAPIKey: Bool
    ) -> GoDiveMapEngine {
        if hasGoogleMapsAPIKey || activeLaunchArguments.contains(googleMapsLaunchArgument) {
            return .googleMaps
        }
        return .mapKit
    }
}
