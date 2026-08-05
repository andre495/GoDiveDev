import Foundation

/// Explore scope-cache rebuilds are expensive (bundled ODM refs) — skip no-op rebuilds on tab reappear.
enum ExploreScopeCacheAppearPresentation: Sendable {

    nonisolated static func shouldRebuildScopeCacheOnAppear(
        isCacheEmpty: Bool,
        appliedSyncToken: String?,
        currentSyncToken: String
    ) -> Bool {
        if isCacheEmpty { return true }
        guard let appliedSyncToken else { return true }
        return appliedSyncToken != currentSyncToken
    }

}
