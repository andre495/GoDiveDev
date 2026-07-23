import Foundation
import SwiftData

enum SnorkelMediaBuddyAssociation {

    static func tags(
        forMediaPhotoID mediaPhotoID: UUID,
        modelContext: ModelContext
    ) throws -> [DiveMediaBuddyTag] {
        let descriptor = FetchDescriptor<DiveMediaBuddyTag>(
            predicate: #Predicate<DiveMediaBuddyTag> {
                $0.mediaPhotoID == mediaPhotoID && $0.snorkelActivityID != nil
            },
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

    @discardableResult
    static func tagBuddy(
        _ buddy: DiveBuddy,
        on media: SnorkelMediaPhoto,
        snorkel: SnorkelActivity,
        modelContext: ModelContext,
        tagID: UUID = UUID(),
        persistImmediately: Bool = true
    ) throws -> DiveMediaBuddyTag {
        if let existing = try existingTag(
            buddyID: buddy.id,
            mediaPhotoID: media.id,
            modelContext: modelContext
        ) {
            return existing
        }

        if !SnorkelBuddyActivityAssociation.isBuddyTagged(buddyID: buddy.id, on: snorkel) {
            _ = SnorkelBuddyActivityAssociation.tagBuddy(buddy, on: snorkel, modelContext: modelContext)
        }

        let tag = DiveMediaBuddyTag(
            id: tagID,
            buddy: buddy,
            snorkelMediaPhoto: media,
            snorkelActivity: snorkel
        )
        modelContext.insert(tag)
        snorkel.mediaBuddyTags.append(tag)
        media.mediaBuddyTags.append(tag)
        buddy.mediaBuddyTags.append(tag)
        GoDiveFriendBuddyLinking.scheduleAutoLinkAfterBuddyTagged(buddy, modelContext: modelContext)
        if persistImmediately {
            try modelContext.save()
            DiveActivityMediaStorage.postMediaDidChange()
        }
        return tag
    }

    static func removeBuddyTag(
        buddyID: UUID,
        from media: SnorkelMediaPhoto,
        snorkel: SnorkelActivity,
        modelContext: ModelContext
    ) throws {
        guard let tag = try existingTag(
            buddyID: buddyID,
            mediaPhotoID: media.id,
            modelContext: modelContext
        ) else { return }

        snorkel.mediaBuddyTags.removeAll { $0.id == tag.id }
        media.mediaBuddyTags.removeAll { $0.id == tag.id }
        tag.buddy?.mediaBuddyTags.removeAll { $0.id == tag.id }
        modelContext.delete(tag)

        let stillTaggedOnMedia = snorkel.mediaBuddyTags.contains { $0.buddyID == buddyID }
        if !stillTaggedOnMedia,
           let activityTag = snorkel.buddies.first(where: { $0.buddyID == buddyID }) {
            SnorkelBuddyActivityAssociation.removeTag(activityTag, from: snorkel, modelContext: modelContext)
        }
    }

    @discardableResult
    static func tagSelf(
        owner: UserProfile,
        on media: SnorkelMediaPhoto,
        snorkel: SnorkelActivity,
        modelContext: ModelContext
    ) throws -> DiveMediaBuddyTag {
        let buddy = try DiveBuddySelfRepresentation.findOrCreateSelfBuddy(
            owner: owner,
            modelContext: modelContext
        )
        return try tagBuddy(buddy, on: media, snorkel: snorkel, modelContext: modelContext)
    }
}
