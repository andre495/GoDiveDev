import Foundation
import Network
import Observation

/// Thread-safe connectivity flag for PhotoKit / AVFoundation work off the main actor.
final class AppNetworkConnectivitySnapshot: @unchecked Sendable {
    nonisolated static let shared = AppNetworkConnectivitySnapshot()

    private let lock = NSLock()
    private nonisolated(unsafe) var isConnected = true
    private nonisolated(unsafe) var usesWiFi = true

    nonisolated private init() {}

    nonisolated var allowsCloudMediaFetch: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isConnected
    }

    nonisolated var usesWiFiInterface: Bool {
        lock.lock()
        defer { lock.unlock() }
        return usesWiFi
    }

    nonisolated func update(isConnected: Bool, usesWiFi: Bool) {
        lock.lock()
        let wasWiFi = self.usesWiFi
        self.isConnected = isConnected
        self.usesWiFi = usesWiFi
        lock.unlock()

        if usesWiFi, !wasWiFi {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .goDiveSharedMediaContentUploadDue, object: nil)
            }
        }
    }

    nonisolated func update(isConnected: Bool) {
        update(isConnected: isConnected, usesWiFi: usesWiFi)
    }
}

/// Observes **`NWPathMonitor`** at launch; drives offline-only media previews (no iCloud / full-res fetch).
@MainActor
@Observable
final class AppNetworkConnectivityMonitor {
    static let shared = AppNetworkConnectivityMonitor()

    private(set) var isConnected = true
    private(set) var usesWiFi = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "AppNetworkConnectivityMonitor", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { path in
            let connected = AppNetworkConnectivityPresentation.isConnected(
                pathStatusSatisfied: path.status == .satisfied
            )
            let usesWiFi = path.usesInterfaceType(.wifi)
            AppNetworkConnectivitySnapshot.shared.update(isConnected: connected, usesWiFi: usesWiFi)
            Task { @MainActor in
                AppNetworkConnectivityMonitor.shared.isConnected = connected
                AppNetworkConnectivityMonitor.shared.usesWiFi = usesWiFi
            }
        }
        monitor.start(queue: queue)
    }
}
