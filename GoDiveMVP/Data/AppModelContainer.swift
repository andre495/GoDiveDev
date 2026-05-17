import SwiftData

/// Lazily created SwiftData container for production builds (not loaded during UI tests).
enum AppModelContainer {
    static let production: ModelContainer = {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
