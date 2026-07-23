import Foundation

/// Logbook list cache builds are expensive — skip off-tab mount when the tab bar preloads Logbook.
enum LogbookRootAppearPresentation: Sendable {

    nonisolated static func shouldBuildCacheOnAppear(
        isLogbookTabSelected: Bool,
        hasPerformedInitialCacheBuild: Bool
    ) -> Bool {
        if hasPerformedInitialCacheBuild { return true }
        return isLogbookTabSelected
    }
}
