import Foundation
import os
import SwiftData

/// Snorkel delete diagnostics. Filter Console / Xcode device log by category **`SnorkelDelete`**.
enum SnorkelActivityDeletionDebug: Sendable {

    #if DEBUG
    nonisolated(unsafe) static var isEnabled = true
    #else
    nonisolated(unsafe) static var isEnabled = false
    #endif

    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PrimoSoftware.GoDiveMVP",
        category: "SnorkelDelete"
    )

    nonisolated static func began(snorkelID: UUID) {
        guard isEnabled else { return }
        logger.info("begin snorkel=\(snorkelID.uuidString, privacy: .public)")
    }

    nonisolated static func succeeded(snorkelID: UUID) {
        guard isEnabled else { return }
        logger.info("succeeded snorkel=\(snorkelID.uuidString, privacy: .public)")
    }

    nonisolated static func failure(snorkelID: UUID, error: Error, contextLabel: String) {
        guard isEnabled else { return }
        let nsError = error as NSError
        logger.error("""
        failed snorkel=\(snorkelID.uuidString, privacy: .public) context=\(contextLabel, privacy: .public) \
        domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) \
        \(String(describing: error), privacy: .public)
        """)
    }

    nonisolated static func snapshot(snorkelID: UUID, contextLabel: String, modelContext: ModelContext? = nil) {
        guard isEnabled else { return }
        guard let modelContext else { return }
        do {
            let report = try SnorkelActivityDeletionDebugReport.make(
                snorkelID: snorkelID,
                modelContext: modelContext
            )
            logger.error("""
            snapshot context=\(contextLabel, privacy: .public) snorkel=\(snorkelID.uuidString, privacy: .public) \
            activity=\(report.activityPresent ? "yes" : "no", privacy: .public) \
            buddies=\(report.buddyCount, privacy: .public) media=\(report.mediaCount, privacy: .public) \
            sightings=\(report.sightingCount, privacy: .public)
            """)
        } catch {
            logger.error("snapshot-error context=\(contextLabel, privacy: .public) \(String(describing: error), privacy: .public)")
        }
    }
}

struct SnorkelActivityDeletionDebugReport: Sendable {
    let activityPresent: Bool
    let buddyCount: Int
    let mediaCount: Int
    let mediaBuddyTagCount: Int
    let sightingCount: Int
    let profilePointCount: Int

    nonisolated static func make(
        snorkelID: UUID,
        modelContext: ModelContext
    ) throws -> SnorkelActivityDeletionDebugReport {
        var activityDescriptor = FetchDescriptor<SnorkelActivity>(
            predicate: #Predicate { $0.id == snorkelID }
        )
        activityDescriptor.fetchLimit = 1
        let activityPresent = try !modelContext.fetch(activityDescriptor).isEmpty

        let buddyCount = try modelContext.fetchCount(
            FetchDescriptor<SnorkelBuddyTag>(predicate: #Predicate { $0.snorkelActivityID == snorkelID })
        )
        let mediaCount = try modelContext.fetchCount(
            FetchDescriptor<SnorkelMediaPhoto>(predicate: #Predicate { $0.snorkelActivityID == snorkelID })
        )
        let mediaBuddyTagCount = try modelContext.fetchCount(
            FetchDescriptor<DiveMediaBuddyTag>(predicate: #Predicate { $0.snorkelActivityID == snorkelID })
        )
        let sightingCount = try modelContext.fetchCount(
            FetchDescriptor<SightingInstance>(predicate: #Predicate { $0.snorkelActivityID == snorkelID })
        )
        let profilePointCount = try modelContext.fetchCount(
            FetchDescriptor<SnorkelProfilePoint>(predicate: #Predicate { $0.snorkelActivityID == snorkelID })
        )

        return SnorkelActivityDeletionDebugReport(
            activityPresent: activityPresent,
            buddyCount: buddyCount,
            mediaCount: mediaCount,
            mediaBuddyTagCount: mediaBuddyTagCount,
            sightingCount: sightingCount,
            profilePointCount: profilePointCount
        )
    }
}
