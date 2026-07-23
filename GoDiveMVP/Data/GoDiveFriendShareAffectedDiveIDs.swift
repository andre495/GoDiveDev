import Foundation
import SwiftData

/// Resolves SwiftData save deltas into dive IDs whose friend-visible projections may need refresh.
enum GoDiveFriendShareAffectedDiveIDs: Sendable {

    /// Collects dive UUIDs from live models touched in a save (insert/update).
    @MainActor
    static func diveIDs(
        fromModels models: [any PersistentModel],
        ownerProfileID: UUID
    ) -> Set<UUID> {
        var ids = Set<UUID>()
        for model in models {
            collectDiveIDs(from: model, ownerProfileID: ownerProfileID, into: &ids)
        }
        return ids
    }

    @MainActor
    private static func collectDiveIDs(
        from model: any PersistentModel,
        ownerProfileID: UUID,
        into ids: inout Set<UUID>
    ) {
        switch model {
        case let dive as DiveActivity:
            guard dive.ownerProfileID == ownerProfileID else { return }
            ids.insert(dive.id)

        case let tag as DiveBuddyTag:
            if let dive = tag.dive, dive.ownerProfileID == ownerProfileID {
                ids.insert(dive.id)
            } else if let diveID = tag.diveActivityID {
                ids.insert(diveID)
            }

        case let media as DiveMediaPhoto:
            if let dive = media.dive, dive.ownerProfileID == ownerProfileID {
                ids.insert(dive.id)
            } else if let diveID = media.diveActivityID {
                ids.insert(diveID)
            }

        case let sighting as SightingInstance:
            if let dive = sighting.diveActivity, dive.ownerProfileID == ownerProfileID {
                ids.insert(dive.id)
            } else if let diveID = sighting.diveActivityID {
                ids.insert(diveID)
            }

        case let entry as DiveEquipmentEntry:
            if let dive = entry.equipmentList?.dive, dive.ownerProfileID == ownerProfileID {
                ids.insert(dive.id)
            } else {
                ids.insert(entry.diveActivityID)
            }

        case let list as DiveActivityEquipmentList:
            if let dive = list.dive, dive.ownerProfileID == ownerProfileID {
                ids.insert(dive.id)
            } else if let diveID = list.diveActivityID {
                ids.insert(diveID)
            }

        case let buddy as DiveBuddy:
            guard buddy.ownerProfileID == ownerProfileID else { return }
            for participation in buddy.diveParticipations {
                if let dive = participation.dive, dive.ownerProfileID == ownerProfileID {
                    ids.insert(dive.id)
                } else if let diveID = participation.diveActivityID {
                    ids.insert(diveID)
                }
            }

        case let tag as ActivityTag:
            guard tag.ownerProfileID == ownerProfileID else { return }
            for dive in tag.dives where dive.ownerProfileID == ownerProfileID {
                ids.insert(dive.id)
            }

        case let item as EquipmentItem:
            guard item.ownerProfileID == ownerProfileID else { return }
            for entry in item.diveEquipmentEntries {
                if let dive = entry.equipmentList?.dive, dive.ownerProfileID == ownerProfileID {
                    ids.insert(dive.id)
                } else {
                    ids.insert(entry.diveActivityID)
                }
            }

        default:
            break
        }
    }

    /// Persistent identifiers from a **`ModelContext.didSave`** notification.
    nonisolated static func changedIdentifiers(from userInfo: [AnyHashable: Any]?) -> Set<PersistentIdentifier> {
        guard let userInfo else { return [] }
        var ids = Set<PersistentIdentifier>()
        if let inserted = userInfo[ModelContext.NotificationKey.insertedIdentifiers] as? Set<PersistentIdentifier> {
            ids.formUnion(inserted)
        }
        if let updated = userInfo[ModelContext.NotificationKey.updatedIdentifiers] as? Set<PersistentIdentifier> {
            ids.formUnion(updated)
        }
        return ids
    }
}
