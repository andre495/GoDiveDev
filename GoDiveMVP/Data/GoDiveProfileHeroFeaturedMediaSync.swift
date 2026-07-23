import Foundation
import SwiftData

/// Schedules Firebase profile-hero upload when the signed-in diver stars tagged media for their header.
@MainActor
enum GoDiveProfileHeroFeaturedMediaSync {

    /// Resolves the friend-visible profile hero from self-buddy tagged media and queues Storage + Firestore sync.
    static func scheduleSyncForSelfBuddyHeader(
        buddy: DiveBuddy,
        owner: UserProfile?,
        sessionRandomHeroMediaID: UUID?,
        modelContext: ModelContext,
        force: Bool = true
    ) {
        guard let owner,
              DiveBuddySelfRepresentation.isSelfBuddy(buddy, owner: owner)
        else { return }

        let buddyID = buddy.id
        let tags = (try? modelContext.fetch(
            FetchDescriptor<DiveMediaBuddyTag>(
                predicate: #Predicate { $0.buddyID == buddyID }
            )
        )) ?? []

        let ownerID = owner.id
        let activities = (try? modelContext.fetch(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate { $0.ownerProfileID == ownerID }
            )
        )) ?? []
        let ownerDiveActivityIDs = Set(activities.map(\.id))

        let photos = DiveBuddyTaggedMediaPresentation.resolvedTaggedMediaPhotos(
            tags: tags,
            ownerDiveActivityIDs: ownerDiveActivityIDs,
            modelContext: modelContext
        )

        guard
            let heroID = DiveBuddyTaggedMediaPresentation.resolvedHeroMediaPhotoID(
                in: photos,
                explicitFeaturedID: buddy.featuredTaggedMediaPhotoID,
                sessionRandomID: sessionRandomHeroMediaID
            ),
            let heroMedia = photos.first(where: { $0.id == heroID })
        else {
            GoDiveProfileHeroFirestoreSync.scheduleSyncIfNeeded(heroMedia: nil, force: force)
            return
        }

        GoDiveProfileHeroFirestoreSync.scheduleSyncIfNeeded(heroMedia: heroMedia, force: force)
    }
}
