import Foundation
import os
import SwiftData

/// Dive delete diagnostics. Filter Console / Xcode device log by category **`DiveDelete`**.
enum DiveActivityDeletionDebug: Sendable {

    #if DEBUG
    nonisolated(unsafe) static var isEnabled = true
    #else
    nonisolated(unsafe) static var isEnabled = false
    #endif

    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PrimoSoftware.GoDiveMVP",
        category: "DiveDelete"
    )

    nonisolated static func began(diveID: UUID) {
        guard isEnabled else { return }
        logger.info("begin dive=\(diveID.uuidString, privacy: .public)")
    }

    nonisolated static func succeeded(diveID: UUID) {
        guard isEnabled else { return }
        logger.info("succeeded dive=\(diveID.uuidString, privacy: .public)")
    }

    nonisolated static func failure(diveID: UUID, error: Error, contextLabel: String) {
        guard isEnabled else { return }
        let nsError = error as NSError
        logger.error("""
        failed dive=\(diveID.uuidString, privacy: .public) context=\(contextLabel, privacy: .public) \
        domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) \
        \(String(describing: error), privacy: .public)
        """)
    }

    /// Row counts when delete fails (diagnose constraint / merge issues).
    nonisolated static func snapshot(diveID: UUID, contextLabel: String, modelContext: ModelContext? = nil) {
        guard isEnabled else { return }
        guard let modelContext else { return }
        do {
            let report = try DiveActivityDeletionDebugReport.make(diveID: diveID, modelContext: modelContext)
            logger.error("""
            snapshot context=\(contextLabel, privacy: .public) dive=\(diveID.uuidString, privacy: .public) \
            activity=\(report.activityPresent ? "yes" : "no", privacy: .public) \
            tripLinks=\(report.tripLinkCount, privacy: .public) equipment=\(report.equipmentEntryCount, privacy: .public)
            """)
        } catch {
            logger.error("snapshot-error context=\(contextLabel, privacy: .public) \(String(describing: error), privacy: .public)")
        }
    }
}

struct DiveActivityDeletionDebugReport: Sendable {
    let activityPresent: Bool
    let tripLinkCount: Int
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

        let tripLinkCount = try modelContext.fetchCount(
            FetchDescriptor<DiveTripActivityLink>(predicate: #Predicate { $0.diveActivityID == diveID })
        )
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
            tripLinkCount: tripLinkCount,
            buddyCount: buddyCount,
            mediaCount: mediaCount,
            sightingCount: sightingCount,
            profilePointCount: profilePointCount,
            equipmentEntryCount: equipmentEntryCount
        )
    }
}
