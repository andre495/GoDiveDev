import Foundation
import os
import SwiftData

/// Production SwiftData container — created off the main thread (on-disk **`ModelContainer`** init performs I/O).
enum AppModelContainer {
    private final class LoadState: @unchecked Sendable {
        private let state = OSAllocatedUnfairLock(initialState: Optional<Task<ModelContainer, Never>>.none)

        func beginLoadingIfNeeded() {
            state.withLock { stored in
                guard stored == nil else { return }
                stored = Task.detached(priority: .userInitiated) {
                    let signpostID = AppPerformanceSignpost.begin(.launchContainerLoad)
                    defer { AppPerformanceSignpost.end(.launchContainerLoad, signpostID: signpostID) }
                    do {
                        return try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: false)
                    } catch {
                        // Last resort — dual-store open already falls back from CloudKit → local.
                        Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "ModelContainer")
                            .fault("Could not create ModelContainer: \(String(describing: error), privacy: .public)")
                        fatalError("Could not create ModelContainer: \(error)")
                    }
                }
            }
        }

        func loadingTask() -> Task<ModelContainer, Never>? {
            state.withLock { $0 }
        }

        func reset() {
            state.withLock { stored in
                stored?.cancel()
                stored = nil
            }
        }
    }

    private static let loadState = LoadState()

    /// Drops the cached load task so the next **`loadProduction()`** opens stores again (CloudKit reconnect).
    static func resetProductionLoadStateForReconnect() {
        loadState.reset()
    }

    /// Re-open on-disk stores after **`scheduleReconnectPrivateCloudKitOnNextLaunch()`**.
    static func reloadProductionAfterCloudKitReconnect() async -> ModelContainer {
        resetProductionLoadStateForReconnect()
        return await loadProduction()
    }

    /// Starts on-disk container creation as early as possible ( **`GoDiveMVPApp.init`** ).
    static func beginLoadingProductionIfNeeded() {
        loadState.beginLoadingIfNeeded()
    }

    /// Loads the on-disk container on a background thread; await from launch before attaching **`.modelContainer`**.
    static func loadProduction() async -> ModelContainer {
        beginLoadingProductionIfNeeded()
        guard let task = loadState.loadingTask() else {
            fatalError("Production ModelContainer load task missing")
        }
        return await task.value
    }
}
