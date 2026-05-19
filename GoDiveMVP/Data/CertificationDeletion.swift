import Foundation
import SwiftData

/// Removes a **`Certification`** from the store.
enum CertificationDeletion {
    @MainActor
    static func deletePermanently(_ certification: Certification, modelContext: ModelContext) throws {
        modelContext.delete(certification)
        try modelContext.save()
    }
}
