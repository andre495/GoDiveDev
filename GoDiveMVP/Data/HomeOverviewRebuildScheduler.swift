import Foundation

/// Coalesces expensive Home overview rebuilds (media notifications, query churn, settings toggles).
actor HomeOverviewRebuildScheduler {

    static let shared = HomeOverviewRebuildScheduler()

    private var pendingTask: Task<Void, Never>?

    /// Runs **`operation`** immediately and waits until it finishes (no debounce).
    func runImmediately(operation: @escaping @Sendable () async -> Void) async {
        pendingTask?.cancel()
        let task = Task(priority: .userInitiated) {
            await operation()
        }
        pendingTask = task
        await task.value
    }

    /// Runs **`operation`** after **`debounceNanoseconds`**, replacing any earlier pending run.
    func schedule(
        debounceNanoseconds: UInt64 = 80_000_000,
        operation: @escaping @Sendable () async -> Void
    ) {
        pendingTask?.cancel()
        pendingTask = Task(priority: .userInitiated) {
            if debounceNanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: debounceNanoseconds)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
