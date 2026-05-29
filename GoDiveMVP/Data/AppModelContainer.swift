import SwiftData

/// Production SwiftData container — created off the main thread (on-disk **`ModelContainer`** init performs I/O).
enum AppModelContainer {

    /// Loads the on-disk container on a background thread; await from launch before attaching **`.modelContainer`**.
    static func loadProduction() async -> ModelContainer {
        do {
            return try await Task.detached(priority: .userInitiated) {
                try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: false)
            }.value
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
