import Foundation
import os

/// Lightweight Instruments hooks for profiling main-thread vs off-main work.
enum AppPerformanceSignpost {
    private nonisolated static let log = OSLog(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "Performance"
    )

    enum Interval: String {
        case launchContainerLoad = "LaunchContainerLoad"
        case launchSessionValidation = "LaunchSessionValidation"
        case homeOverviewRebuild = "HomeOverviewRebuild"
        case homeOverviewCompute = "HomeOverviewCompute"
        case tripDetailContentRebuild = "TripDetailContentRebuild"
        case buddyDetailContentRebuild = "BuddyDetailContentRebuild"
        case logbookCacheRebuild = "LogbookCacheRebuild"
    }

    nonisolated static func begin(_ interval: Interval) -> OSSignpostID {
        let signpostID = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: "Interval", signpostID: signpostID, "%{public}s", interval.rawValue)
        return signpostID
    }

    nonisolated static func end(_ interval: Interval, signpostID: OSSignpostID) {
        os_signpost(.end, log: log, name: "Interval", signpostID: signpostID, "%{public}s", interval.rawValue)
    }
}
