import Foundation
import Network
import Observation

/// Thread-safe connectivity flag for PhotoKit / AVFoundation work off the main actor.
final class AppNetworkConnectivitySnapshot: @unchecked Sendable {
    static let shared = AppNetworkConnectivitySnapshot()

    private let lock = NSLock()
    private var isConnected = true

    private init() {}

    nonisolated var allowsCloudMediaFetch: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isConnected
    }

    func update(isConnected: Bool) {
        lock.lock()
        self.isConnected = isConnected
        lock.unlock()
    }
}

/// Observes **`NWPathMonitor`** at launch; drives offline-only media previews (no iCloud / full-res fetch).
@MainActor
@Observable
final class AppNetworkConnectivityMonitor {
    static let shared = AppNetworkConnectivityMonitor()

    private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "AppNetworkConnectivityMonitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { path in
            let connected = AppNetworkConnectivityPresentation.isConnected(
                pathStatusSatisfied: path.status == .satisfied
            )
            AppNetworkConnectivitySnapshot.shared.update(isConnected: connected)
            Task { @MainActor in
                AppNetworkConnectivityMonitor.shared.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}
