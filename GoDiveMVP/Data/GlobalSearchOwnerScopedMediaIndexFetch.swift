import Foundation
import SwiftData

/// Background fetch of owner-scoped media buddy tags + sightings for **Global Search** media index.
/// Avoids unscoped `@Query` on the full tag/sighting tables (which invalidate Search on any store change).
enum GlobalSearchOwnerScopedMediaIndexFetch: Sendable {
    struct Result: Sendable {
        let buddyTagPersistentIDs: [PersistentIdentifier]
        let sightingPersistentIDs: [PersistentIdentifier]
        let buddyTagRows: [GlobalSearchMediaIndexSnapshotBuilder.CaptureInput.BuddyTagRow]
        let sightingRows: [GlobalSearchMediaIndexSnapshotBuilder.CaptureInput.SightingRow]
        let buddyTagCount: Int
        let sightingCount: Int
    }

    nonisolated static func fetch(
        ownerDiveActivityIDs: Set<UUID>,
        speciesNameByUUID: [String: String],
        container: ModelContainer
    ) async -> Result {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            guard !ownerDiveActivityIDs.isEmpty else {
                return Result(
                    buddyTagPersistentIDs: [],
                    sightingPersistentIDs: [],
                    buddyTagRows: [],
                    sightingRows: [],
                    buddyTagCount: 0,
                    sightingCount: 0
                )
            }

            let allTags = (try? context.fetch(
                FetchDescriptor<DiveMediaBuddyTag>(
                    sortBy: [SortDescriptor(\.id, order: .forward)]
                )
            )) ?? []
            let scopedTags = allTags.filter { tag in
                guard let activityID = tag.diveActivityID else { return false }
                return ownerDiveActivityIDs.contains(activityID)
            }

            let allSightings = (try? context.fetch(
                FetchDescriptor<SightingInstance>(
                    sortBy: [SortDescriptor(\.sightingDateTime, order: .reverse)]
                )
            )) ?? []
            let scopedSightings = allSightings.filter { sighting in
                guard let activityID = sighting.diveActivityID else { return false }
                return ownerDiveActivityIDs.contains(activityID)
            }

            let buddyTagRows = scopedTags.compactMap { tag -> GlobalSearchMediaIndexSnapshotBuilder.CaptureInput.BuddyTagRow? in
                guard let activityID = tag.diveActivityID,
                      let mediaPhotoID = tag.mediaPhotoID,
                      let buddyName = tag.buddy?.displayName
                else { return nil }
                return .init(
                    mediaPhotoID: mediaPhotoID,
                    diveActivityID: activityID,
                    buddyDisplayName: buddyName
                )
            }

            let sightingRows = scopedSightings.compactMap { sighting -> GlobalSearchMediaIndexSnapshotBuilder.CaptureInput.SightingRow? in
                guard let activityID = sighting.diveActivityID,
                      let mediaPhotoID = sighting.mediaPhotoID,
                      let speciesName = speciesNameByUUID[sighting.marineLifeUUID]
                else { return nil }
                return .init(
                    mediaPhotoID: mediaPhotoID,
                    diveActivityID: activityID,
                    speciesName: speciesName
                )
            }

            return Result(
                buddyTagPersistentIDs: scopedTags.map(\.persistentModelID),
                sightingPersistentIDs: scopedSightings.map(\.persistentModelID),
                buddyTagRows: buddyTagRows,
                sightingRows: sightingRows,
                buddyTagCount: scopedTags.count,
                sightingCount: scopedSightings.count
            )
        }.value
    }

    @MainActor
    static func bindBuddyTags(
        persistentIDs: [PersistentIdentifier],
        modelContext: ModelContext
    ) -> [DiveMediaBuddyTag] {
        persistentIDs.compactMap { modelContext.model(for: $0) as? DiveMediaBuddyTag }
    }

    @MainActor
    static func bindSightings(
        persistentIDs: [PersistentIdentifier],
        modelContext: ModelContext
    ) -> [SightingInstance] {
        persistentIDs.compactMap { modelContext.model(for: $0) as? SightingInstance }
    }
}
