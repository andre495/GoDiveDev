import Foundation
import SwiftData

/// Collects sighting ids and marks community SiteReport + sighting staging deleted when an activity is removed.
enum OntologyGraphActivityCleanup: Sendable {

    nonisolated static func sightingUUIDs(
        diveActivityID: UUID,
        container: ModelContainer
    ) async -> [String] {
        await Task.detached {
            let context = ModelContext(container)
            let all = (try? context.fetch(FetchDescriptor<SightingInstance>())) ?? []
            return all
                .filter { $0.diveActivityID == diveActivityID }
                .map(\.sightingUUID)
                .filter { !$0.isEmpty }
        }.value
    }

    nonisolated static func sightingUUIDs(
        snorkelActivityID: UUID,
        container: ModelContainer
    ) async -> [String] {
        await Task.detached {
            let context = ModelContext(container)
            let all = (try? context.fetch(FetchDescriptor<SightingInstance>())) ?? []
            return all
                .filter { $0.snorkelActivityID == snorkelActivityID }
                .map(\.sightingUUID)
                .filter { !$0.isEmpty }
        }.value
    }

    @MainActor
    static func markCommunityContributionsDeleted(
        activityUUID: UUID,
        sightingUUIDs: [String]
    ) async {
        await OntologySiteReportContributionSync.markDeleted(activityUUID: activityUUID)
        if !sightingUUIDs.isEmpty {
            await OntologySightingContributionSync.markDeleted(sightingUUIDs: sightingUUIDs)
        }
    }
}
