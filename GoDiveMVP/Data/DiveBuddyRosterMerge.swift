import Foundation
import SwiftData

/// Merges duplicate roster **`DiveBuddy`** rows into one canonical person (dive / media / trip links).
enum DiveBuddyRosterMerge {
    @MainActor
    static func merge(_ source: DiveBuddy, into target: DiveBuddy, modelContext: ModelContext) {
        guard source.id != target.id else { return }

        for tag in Array(source.diveParticipations) {
            guard let dive = tag.dive else {
                modelContext.delete(tag)
                continue
            }
            if DiveBuddyActivityAssociation.isBuddyTagged(buddyID: target.id, on: dive) {
                DiveBuddyActivityAssociation.removeTag(tag, from: dive, modelContext: modelContext)
            } else {
                tag.buddy = target
                tag.buddyID = target.id
                source.diveParticipations.removeAll { $0.id == tag.id }
                if !target.diveParticipations.contains(where: { $0.id == tag.id }) {
                    target.diveParticipations.append(tag)
                }
            }
        }

        for tag in Array(source.mediaBuddyTags) {
            guard let media = tag.mediaPhoto else {
                modelContext.delete(tag)
                continue
            }
            let dive = tag.diveActivity ?? media.dive
            if let dive,
               (try? DiveMediaBuddyAssociation.isBuddyTagged(
                   buddyID: target.id,
                   on: media,
                   modelContext: modelContext
               )) == true {
                try? DiveMediaBuddyAssociation.removeBuddyTag(
                    buddyID: source.id,
                    from: media,
                    dive: dive,
                    modelContext: modelContext
                )
            } else {
                tag.buddy = target
                tag.buddyID = target.id
                source.mediaBuddyTags.removeAll { $0.id == tag.id }
                if !target.mediaBuddyTags.contains(where: { $0.id == tag.id }) {
                    target.mediaBuddyTags.append(tag)
                }
            }
        }

        for link in Array(source.tripBuddyLinks) {
            guard let trip = link.trip else {
                modelContext.delete(link)
                continue
            }
            if DiveTripPlannedBuddyLinking.isBuddyOnTrip(buddyID: target.id, trip: trip) {
                modelContext.delete(link)
                source.tripBuddyLinks.removeAll { $0.id == link.id }
                trip.buddyLinks.removeAll { $0.id == link.id }
            } else {
                link.buddy = target
                link.buddyID = target.id
                source.tripBuddyLinks.removeAll { $0.id == link.id }
                if !trip.buddyLinks.contains(where: { $0.id == link.id }) {
                    trip.buddyLinks.append(link)
                }
                if !target.tripBuddyLinks.contains(where: { $0.id == link.id }) {
                    target.tripBuddyLinks.append(link)
                }
            }
        }

        if (target.profilePhoto == nil || target.profilePhoto?.isEmpty == true),
           let photo = source.profilePhoto, !photo.isEmpty {
            target.profilePhoto = photo
        }
        if target.contactsIdentifier == nil, let contactsID = source.contactsIdentifier {
            target.contactsIdentifier = contactsID
        }
        if target.featuredTaggedMediaPhotoID == nil {
            target.featuredTaggedMediaPhotoID = source.featuredTaggedMediaPhotoID
        }

        modelContext.delete(source)
    }
}
