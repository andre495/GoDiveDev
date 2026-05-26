import Foundation
import SwiftData

/// Coalesces post-delete background renumber passes (several quick deletes → one partial or full pass).
actor DivePostDeleteRenumberScheduler {

    static let shared = DivePostDeleteRenumberScheduler()

    private var pendingTask: Task<Void, Never>?
    private let debounceNanoseconds: UInt64 = 500_000_000

    /// Waits for the in-flight debounced renumber task (if any). Used after logbook delete before a single UI cache refresh.
    func waitForPending() async {
        await pendingTask?.value
    }

    /// Tail-only renumber after delete (preferred — does not rewrite every dive **#**).
    func schedulePartialRenumber(
        container: ModelContainer,
        deletedStartTime: Date,
        deletedId: UUID
    ) {
        pendingTask?.cancel()
        pendingTask = Task {
            do {
                try await Task.sleep(nanoseconds: debounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            try? await DiveActivityPostDeleteRenumbering.renumberAfterDelete(
                container: container,
                deletedStartTime: deletedStartTime,
                deletedId: deletedId
            )
        }
    }

    /// Full **1…n** rewrite (Settings toggle, import, or explicit full pass).
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
