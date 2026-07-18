import Foundation
import SwiftData

/// Diver-owned buddy roster entry (reused across dives via **`DiveBuddyTag`**).
@Model
final class DiveBuddy {

    var id: UUID = UUID()
    var displayName: String = ""
    /// Cached avatar bytes (JPEG/PNG from Contacts or Photos).
    var profilePhoto: Data?
    /// **`CNContact.identifier`** when linked from Contacts; used to refresh name/photo.
    var contactsIdentifier: String?
    /// User-chosen tagged media for the buddy detail hero; **`nil`** uses a random tagged item.
    var featuredTaggedMediaPhotoID: UUID?

    /// Denormalized for **`#Predicate`**; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    @Relationship(deleteRule: .cascade)
    var diveParticipationsStorage: [DiveBuddyTag]? = []
    @Transient
    var diveParticipations: [DiveBuddyTag] {
        get { diveParticipationsStorage ?? [] }
        set { diveParticipationsStorage = newValue }
    }

    @Relationship(deleteRule: .cascade)
    var tripBuddyLinksStorage: [DiveTripBuddyLink]? = []
    @Transient
    var tripBuddyLinks: [DiveTripBuddyLink] {
        get { tripBuddyLinksStorage ?? [] }
        set { tripBuddyLinksStorage = newValue }
    }

    @Relationship(deleteRule: .cascade)
    var mediaBuddyTagsStorage: [DiveMediaBuddyTag]? = []
    @Transient
    var mediaBuddyTags: [DiveMediaBuddyTag] {
        get { mediaBuddyTagsStorage ?? [] }
        set { mediaBuddyTagsStorage = newValue }
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        profilePhoto: Data? = nil,
        contactsIdentifier: String? = nil,
        owner: UserProfile? = nil
    ) {
        self.id = id
        self.displayName = String(displayName.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        self.profilePhoto = profilePhoto
        self.contactsIdentifier = contactsIdentifier
        self.ownerProfileID = owner?.id
        self.owner = owner
    }
}
