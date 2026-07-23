import Foundation
import SwiftData

enum SnorkelMediaBuddyTagDraftPresentation {

    static func apply(
        draft: DiveMediaBuddyTagDraftPresentation.DraftState,
        media: SnorkelMediaPhoto,
        snorkel: SnorkelActivity,
        owner: UserProfile?,
        rosterByID: [UUID: DiveBuddy],
        modelContext: ModelContext
    ) throws {
        var effectiveDraftIDs = draft.taggedBuddyIDs
        var effectiveRoster = rosterByID
        if draft.includesSelfWithoutBuddyID, let owner {
            let selfBuddy = try DiveBuddySelfRepresentation.findOrCreateSelfBuddy(
                owner: owner,
                modelContext: modelContext
            )
            effectiveRoster[selfBuddy.id] = selfBuddy
            effectiveDraftIDs.insert(selfBuddy.id)
        }

        let existingTags = try SnorkelMediaBuddyAssociation.tags(
            forMediaPhotoID: media.id,
            modelContext: modelContext
        )
        let current = DiveMediaBuddyTagPresentation.taggedBuddyIDs(
            mediaPhotoID: media.id,
            tags: existingTags
        )
        let toRemove = current.subtracting(effectiveDraftIDs)
        let toAdd = effectiveDraftIDs.subtracting(current)

        for buddyID in toRemove {
            try SnorkelMediaBuddyAssociation.removeBuddyTag(
                buddyID: buddyID,
                from: media,
                snorkel: snorkel,
                modelContext: modelContext
            )
        }

        for buddyID in toAdd {
            guard let buddy = effectiveRoster[buddyID] else { continue }
            _ = try SnorkelMediaBuddyAssociation.tagBuddy(
                buddy,
                on: media,
                snorkel: snorkel,
                modelContext: modelContext,
                persistImmediately: false
            )
        }

        guard !toRemove.isEmpty || !toAdd.isEmpty || draft.includesSelfWithoutBuddyID else { return }
        try modelContext.save()
        if !toRemove.isEmpty || !toAdd.isEmpty {
            DiveActivityMediaStorage.postMediaDidChange()
        }
    }
}
