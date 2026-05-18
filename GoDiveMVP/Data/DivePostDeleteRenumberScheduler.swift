import Foundation
import SwiftData

/// Coalesces post-delete background renumber passes (several quick deletes → one **`renumberAllChronologically`**).
actor DivePostDeleteRenumberScheduler {

    static let shared = DivePostDeleteRenumberScheduler()

    private var pendingTask: Task<Void, Never>?
    private let debounceNanoseconds: UInt64 = 300_000_000

    func scheduleFullRenumber(container: ModelContainer) {
        pendingTask?.cancel()
        pendingTask = Task {
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            let worker = DiveBackgroundRenumberingWorker(modelContainer: container)
            try? await worker.renumberAllChronologically()
        }
    }
}
