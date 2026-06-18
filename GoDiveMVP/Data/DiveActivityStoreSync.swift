import Foundation
import SwiftData

/// Confirms background **`@ModelActor`** writes are visible in the shared persistent store.
enum DiveActivityStoreSync: Sendable {

    enum Error: Swift.Error, Equatable {
        case diveStillPresent(UUID)
    }

    /// **`true`** when no **`DiveActivity`** row exists for **`diveID`** (reads via a fresh **`ModelContext`**).
    nonisolated static func isDiveAbsent(diveID: UUID, container: ModelContainer) -> Bool {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveID }
        )
        descriptor.fetchLimit = 1
        guard let rows = try? context.fetch(descriptor) else { return false }
        return rows.isEmpty
    }

    /// Polls until the dive row is gone or **`timeoutSeconds`** elapses.
    static func awaitDiveAbsent(
        diveID: UUID,
        container: ModelContainer,
        timeoutSeconds: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if isDiveAbsent(diveID: diveID, container: container) { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw Error.diveStillPresent(diveID)
    }
}
