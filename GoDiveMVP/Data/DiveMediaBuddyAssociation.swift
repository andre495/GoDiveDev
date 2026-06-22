import Foundation
import SwiftData

/// Tags **`DiveBuddy`** people on **`DiveMediaPhoto`** rows and ensures dive participation.
enum DiveMediaBuddyAssociation {

    static func tags(
        forMediaPhotoID mediaPhotoID: UUID,
        modelContext: ModelContext
    ) throws -> [DiveMediaBuddyTag] {
        let descriptor = FetchDescriptor<DiveMediaBuddyTag>(
            predicate: #Predicate<DiveMediaBuddyTag> { $0.mediaPhotoID == mediaPhotoID },
            sortBy: [SortDescriptor(\.buddyID)]
        )
        return try modelContext.fetch(descriptor)
    }

    static func existingTag(
        buddyID: UUID,
        mediaPhotoID: UUID,
        modelContext: ModelContext
    ) throws -> DiveMediaBuddyTag? {
        let descriptor = FetchDescriptor<DiveMediaBuddyTag>(
            predicate: #Predicate<DiveMediaBuddyTag> {
                $0.buddyID == buddyID && $0.mediaPhotoID == mediaPhotoID
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    static func isBuddyTagged(
        buddyID: UUID,
        on media: DiveMediaPhoto,
        modelContext: ModelContext
    ) throws -> Bool {
        try existingTag(buddyID: buddyID, mediaPhotoID: media.id, modelContext: modelContext) != nil
    }

    @discardableResult
    static func tagBuddy(
        _ buddy: DiveBuddy,
        on media: DiveMediaPhoto,
        dive: DiveActivity,
        modelContext: ModelContext,
        tagID: UUID = UUID()
    ) throws -> DiveMediaBuddyTag {
        if let existing = try existingTag(
            buddyID: buddy.id,
            mediaPhotoID: media.id,
            modelContext: modelContext
        ) {
            return existing
        }

        if !DiveBuddyActivityAssociation.isBuddyTagged(buddyID: buddy.id, on: dive) {
            DiveBuddyActivityAssociation.tagBuddy(buddy, on: dive, modelContext: modelContext)
        }

        let tag = DiveMediaBuddyTag(id: tagID, buddy: buddy, mediaPhoto: media, diveActivity: dive)
        modelContext.insert(tag)
        DiveActivityChildRecordLinking.link(tag, to: media)
        DiveActivityChildRecordLinking.link(tag, to: dive)
        dive.mediaBuddyTags.append(tag)
        buddy.mediaBuddyTags.append(tag)
        try modelContext.save()
        DiveActivityMediaStorage.postMediaDidChange()
        return tag
    }

    @discardableResult
    static func tagSelf(
        owner: UserProfile,
        on media: DiveMediaPhoto,
        dive: DiveActivity,
        modelContext: ModelContext
    ) throws -> DiveMediaBuddyTag {
        let buddy = try DiveBuddySelfRepresentation.findOrCreateSelfBuddy(
            owner: owner,
            modelContext: modelContext
        )
        return try tagBuddy(buddy, on: media, dive: dive, modelContext: modelContext)
    }
}
