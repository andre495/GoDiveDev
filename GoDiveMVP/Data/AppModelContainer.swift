import Foundation
import SwiftData

/// Production SwiftData container — created off the main thread (on-disk **`ModelContainer`** init performs I/O).
enum AppModelContainer {
    private final class LoadState: @unchecked Sendable {
        let lock = NSLock()
        var task: Task<ModelContainer, Never>?
    }

    private static let loadState = LoadState()

    /// Starts on-disk container creation as early as possible ( **`GoDiveMVPApp.init`** ).
    static func beginLoadingProductionIfNeeded() {
        loadState.lock.lock()
        defer { loadState.lock.unlock() }
        guard loadState.task == nil else { return }
        loadState.task = Task.detached(priority: .userInitiated) {
            let signpostID = AppPerformanceSignpost.begin(.launchContainerLoad)
            defer { AppPerformanceSignpost.end(.launchContainerLoad, signpostID: signpostID) }
            do {
                return try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: false)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    /// Loads the on-disk container on a background thread; await from launch before attaching **`.modelContainer`**.
    static func loadProduction() async -> ModelContainer {
        beginLoadingProductionIfNeeded()
        loadState.lock.lock()
        let task = loadState.task
        loadState.lock.unlock()
        guard let task else {
            fatalError("Production ModelContainer load task missing")
        }
        return await task.value
    }
}
