import Foundation
import SwiftData

/// Confirms background **`@ModelActor`** snorkel deletes are visible in the shared persistent store.
enum SnorkelActivityStoreSync: Sendable {

    enum Error: Swift.Error, Equatable {
        case snorkelStillPresent(UUID)
    }

    nonisolated static func isSnorkelAbsent(snorkelID: UUID, container: ModelContainer) -> Bool {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SnorkelActivity>(
            predicate: #Predicate { $0.id == snorkelID }
        )
        descriptor.fetchLimit = 1
        guard let rows = try? context.fetch(descriptor) else { return false }
        return rows.isEmpty
    }

    static func awaitSnorkelAbsent(
        snorkelID: UUID,
        container: ModelContainer,
        timeoutSeconds: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if isSnorkelAbsent(snorkelID: snorkelID, container: container) { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw Error.snorkelStillPresent(snorkelID)
    }
}
