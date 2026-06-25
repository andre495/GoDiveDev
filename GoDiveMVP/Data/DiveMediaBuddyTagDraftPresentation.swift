import Foundation
import SwiftData

/// In-memory media buddy tagging — apply to SwiftData once on **Done**.
enum DiveMediaBuddyTagDraftPresentation {

    struct DraftState: Equatable {
        var taggedBuddyIDs: Set<UUID>
        var includesSelfWithoutBuddyID: Bool

        init(
            taggedBuddyIDs: Set<UUID> = [],
            includesSelfWithoutBuddyID: Bool = false
        ) {
            self.taggedBuddyIDs = taggedBuddyIDs
            self.includesSelfWithoutBuddyID = includesSelfWithoutBuddyID
        }

        init(
            mediaPhotoID: UUID,
            tags: [DiveMediaBuddyTag]
        ) {
            taggedBuddyIDs = DiveMediaBuddyTagPresentation.taggedBuddyIDs(
                mediaPhotoID: mediaPhotoID,
                tags: tags
            )
            includesSelfWithoutBuddyID = false
        }

        func isSelfTagged(selfBuddyID: UUID?) -> Bool {
            if includesSelfWithoutBuddyID { return true }
            guard let selfBuddyID else { return false }
            return taggedBuddyIDs.contains(selfBuddyID)
        }

        mutating func toggleSelf(selfBuddyID: UUID?) {
            if isSelfTagged(selfBuddyID: selfBuddyID) {
                includesSelfWithoutBuddyID = false
                if let selfBuddyID {
                    taggedBuddyIDs.remove(selfBuddyID)
                }
            } else if let selfBuddyID {
                taggedBuddyIDs.insert(selfBuddyID)
            } else {
                includesSelfWithoutBuddyID = true
            }
        }

        mutating func toggleBuddy(_ buddyID: UUID) {
            if taggedBuddyIDs.contains(buddyID) {
                taggedBuddyIDs.remove(buddyID)
            } else {
                taggedBuddyIDs.insert(buddyID)
            }
        }
    }

    static func apply(
        draft: DraftState,
        media: DiveMediaPhoto,
        dive: DiveActivity,
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

        let existingTags = try DiveMediaBuddyAssociation.tags(
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
            try DiveMediaBuddyAssociation.removeBuddyTag(
                buddyID: buddyID,
                from: media,
                dive: dive,
                modelContext: modelContext
            )
        }

        for buddyID in toAdd {
            guard let buddy = effectiveRoster[buddyID] else { continue }
            _ = try DiveMediaBuddyAssociation.tagBuddy(
                buddy,
                on: media,
                dive: dive,
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
