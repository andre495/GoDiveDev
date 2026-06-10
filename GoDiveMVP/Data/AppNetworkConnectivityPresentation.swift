import Foundation

/// Policy for dive / catalog media when the device has no usable network (e.g. airplane mode).
enum AppNetworkConnectivityPresentation: Sendable {

    nonisolated static func isConnected(pathStatusSatisfied: Bool) -> Bool {
        pathStatusSatisfied
    }

    nonisolated static func allowsCloudMediaFetch(isConnected: Bool) -> Bool {
        isConnected
    }

    nonisolated static func allowsFullResolutionMediaUpgrade(isConnected: Bool) -> Bool {
        isConnected
    }

    /// PhotoKit **`isNetworkAccessAllowed`** for library references.
    nonisolated static func photoKitAllowsNetworkAccess(isConnected: Bool) -> Bool {
        isConnected
    }
}
