import Foundation

/// Selects the map rendering backend for dive / Explore surfaces (experiment branch).
enum GoDiveMapEngine: String, Equatable, Sendable {
    case mapKit
    case googleMaps

    nonisolated static let googleMapsLaunchArgument = "-GoDiveMapEngineGoogle"

    /// Launch argument **`-GoDiveMapEngineGoogle`** opts into Google Maps on this branch.
    static var active: GoDiveMapEngine {
        resolved(activeLaunchArguments: ProcessInfo.processInfo.arguments)
    }

    nonisolated static func resolved(activeLaunchArguments: [String]) -> GoDiveMapEngine {
        if activeLaunchArguments.contains(googleMapsLaunchArgument) {
            return .googleMaps
        }
        return .mapKit
    }
}
