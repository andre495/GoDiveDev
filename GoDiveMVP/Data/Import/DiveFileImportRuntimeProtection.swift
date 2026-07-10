import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// User-facing copy when a file import is cancelled or cannot finish (e.g. app backgrounded mid-import).
enum DiveFileImportInterruption: Sendable {
    static let userMessage =
        "Import was interrupted before it could finish. Keep GoDive open until importing completes, then try again."

    @MainActor
    static func rollbackAndMakeOutcome(
        modelContext: ModelContext,
        totalInFile: Int? = nil
    ) -> DiveFileImportOutcome {
        modelContext.rollback()
        return DiveFileImportOutcome(
            userMessage: userMessage,
            primaryInsertedDiveId: nil,
            totalInFile: totalInFile
        )
    }

    @MainActor
    static func rollbackIfNeededBeforeSave(modelContext: ModelContext) -> DiveFileImportOutcome? {
        guard Task.isCancelled else { return nil }
        return rollbackAndMakeOutcome(modelContext: modelContext)
    }
}

/// Keeps file import alive briefly when the app moves to the background.
enum DiveFileImportBackgroundTask {
    #if canImport(UIKit)
    final class Token: @unchecked Sendable {
        private let lock = NSLock()
        private var identifier: UIBackgroundTaskIdentifier = .invalid

        func begin() {
            lock.lock()
            defer { lock.unlock() }
            guard identifier == .invalid else { return }
            identifier = UIApplication.shared.beginBackgroundTask(withName: "DiveFileImport") { [weak self] in
                self?.end()
            }
        }

        func end() {
            lock.lock()
            defer { lock.unlock() }
            guard identifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }
    #else
    final class Token: Sendable {
        func begin() {}
        func end() {}
    }
    #endif
}

/// Disables SwiftData autosave for the import pass so partial dive rows are not flushed before site / buddy work finishes.
enum DiveFileImportAutosaveScope {
    @MainActor
    static func withAutosaveDisabled<T>(
        modelContext: ModelContext,
        operation: () async throws -> T
    ) async rethrows -> T {
        let priorAutosave = modelContext.autosaveEnabled
        modelContext.autosaveEnabled = false
        defer { modelContext.autosaveEnabled = priorAutosave }
        return try await operation()
    }
}
