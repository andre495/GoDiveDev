import Foundation
import os
import SwiftData

/// Structured logging for logbook dive delete. Filter **Console.app** by subsystem + category **`DiveDelete`**.
enum DiveActivityDeletionDebug: Sendable {

    #if DEBUG
    nonisolated(unsafe) static var isEnabled = true
    #else
    nonisolated(unsafe) static var isEnabled = false
    #endif

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GoDiveMVP",
        category: "DiveDelete"
    )

    enum Phase: String, Sendable {
        case begin
        case afterBackgroundWorker
        case afterMainContextDelete
        case afterRenumber
        case waitForMainContext
        case succeeded
        case failed
    }

    static func phase(_ phase: Phase, diveID: UUID, detail: String = "") {
        guard isEnabled else { return }
        if detail.isEmpty {
            logger.info("[\(phase.rawValue, privacy: .public)] dive=\(diveID.uuidString, privacy: .public)")
        } else {
            logger.info("[\(phase.rawValue, privacy: .public)] dive=\(diveID.uuidString, privacy: .public) \(detail, privacy: .public)")
        }
    }

    static func failure(diveID: UUID, error: Error, contextLabel: String) {
        guard isEnabled else { return }
        logger.error("[failed] dive=\(diveID.uuidString, privacy: .public) context=\(contextLabel, privacy: .public) error=\(String(describing: error), privacy: .public)")
    }

    /// Row counts for the dive id in a **`ModelContext`** (diagnose hollow-parent / merge issues).
    static func snapshot(diveID: UUID, contextLabel: String, modelContext: ModelContext) {
        guard isEnabled else { return }
        do {
            let report = try DiveActivityDeletionDebugReport.make(diveID: diveID, modelContext: modelContext)
            logger.info("""
            [snapshot] context=\(contextLabel, privacy: .public) dive=\(diveID.uuidString, privacy: .public) \
            activity=\(report.activityPresent ? "yes" : "no", privacy: .public) \
            buddies=\(report.buddyCount, privacy: .public) media=\(report.mediaCount, privacy: .public) \
            sightings=\(report.sightingCount, privacy: .public) profile=\(report.profilePointCount, privacy: .public) \
            equipmentEntries=\(report.equipmentEntryCount, privacy: .public)
            """)
        } catch {
            logger.error("[snapshot-error] context=\(contextLabel, privacy: .public) \(String(describing: error), privacy: .public)")
        }
    }
}

struct DiveActivityDeletionDebugReport: Sendable {
    let activityPresent: Bool
    let buddyCount: Int
    let mediaCount: Int
    let sightingCount: Int
    let profilePointCount: Int
    let equipmentEntryCount: Int

    nonisolated static func make(diveID: UUID, modelContext: ModelContext) throws -> DiveActivityDeletionDebugReport {
        var activityDescriptor = FetchDescriptor<DiveActivity>(
            predicate: #Predicate { $0.id == diveID }
        )
        activityDescriptor.fetchLimit = 1
        let activityPresent = try !modelContext.fetch(activityDescriptor).isEmpty

        let buddyCount = try modelContext.fetchCount(
            FetchDescriptor<DiveBuddyTag>(predicate: #Predicate { $0.diveActivityID == diveID })
        )
        let mediaCount = try modelContext.fetchCount(
            FetchDescriptor<DiveMediaPhoto>(predicate: #Predicate { $0.diveActivityID == diveID })
        )
        let sightingCount = try modelContext.fetchCount(
            FetchDescriptor<SightingInstance>(predicate: #Predicate { $0.diveActivityID == diveID })
        )
        let profilePointCount = try modelContext.fetchCount(
            FetchDescriptor<DiveProfilePoint>(predicate: #Predicate { $0.diveActivityID == diveID })
        )
        let equipmentEntryCount = try modelContext.fetchCount(
            FetchDescriptor<DiveEquipmentEntry>(predicate: #Predicate { $0.diveActivityID == diveID })
        )

        return DiveActivityDeletionDebugReport(
            activityPresent: activityPresent,
            buddyCount: buddyCount,
            mediaCount: mediaCount,
            sightingCount: sightingCount,
            profilePointCount: profilePointCount,
            equipmentEntryCount: equipmentEntryCount
        )
    }
}
