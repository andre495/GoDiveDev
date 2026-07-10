import Foundation
import os

/// Console + Instruments markers for import → celebration → Home handoff.
/// Filter Xcode console: **`SignInCelebration`** or subsystem **`PrimoSoftware.GoDiveMVP`**.
enum SignInCelebrationTransitionDiagnostics: Sendable {
    private nonisolated static let logger = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "SignInCelebration"
    )

    private nonisolated(unsafe) static var anchor: CFAbsoluteTime?
    private nonisolated static let signpostLog = OSLog(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "Performance"
    )

    enum Interval: String, Sendable {
        case importToCelebration = "ImportToCelebration"
        case celebrationShellPrewarm = "CelebrationShellPrewarm"
        case celebrationFirstFrame = "CelebrationFirstFrame"
        case homePrewarmAppear = "HomePrewarmAppear"
        case homeOverviewRebuild = "HomeOverviewRebuild"
    }

    nonisolated static func resetAnchor(_ reason: String) {
        anchor = CFAbsoluteTimeGetCurrent()
        mark("anchor_reset: \(reason)")
    }

    nonisolated static func mark(_ event: String) {
        let now = CFAbsoluteTimeGetCurrent()
        if anchor == nil {
            anchor = now
        }
        let elapsedMs = (now - (anchor ?? now)) * 1_000
        let formatted = String(format: "%.1f", elapsedMs)
        logger.notice("[SignInCelebration] +\(formatted, privacy: .public)ms \(event, privacy: .public)")
        #if DEBUG
        print("[SignInCelebration] +\(formatted)ms \(event)")
        #endif
    }

    nonisolated static func begin(_ interval: Interval) -> OSSignpostID {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Interval", signpostID: signpostID, "%{public}s", interval.rawValue)
        mark("signpost_begin: \(interval.rawValue)")
        return signpostID
    }

    nonisolated static func end(_ interval: Interval, signpostID: OSSignpostID) {
        os_signpost(.end, log: signpostLog, name: "Interval", signpostID: signpostID, "%{public}s", interval.rawValue)
        mark("signpost_end: \(interval.rawValue)")
    }
}
