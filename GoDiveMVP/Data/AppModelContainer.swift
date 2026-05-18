import SwiftData

/// Lazily created SwiftData container for production builds (not loaded during UI tests).
enum AppModelContainer {
    static let production: ModelContainer = {
        do {
            return try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: false)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
