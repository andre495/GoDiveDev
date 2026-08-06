import Foundation

/// Photo sources for overview / feed buddy avatar chips.
struct DiveBuddyAvatarChipSources: Equatable, Sendable {
    var localProfilePhoto: Data?
    var photoURL: String?
}

/// Prefer local roster JPEG, then linked friend Storage URL, then Buddy Feed lookup by Firebase UID.
enum DiveBuddyAvatarChipPresentation: Sendable {
    nonisolated static func sources(
        profilePhoto: Data?,
        linkedPhotoURL: String? = nil,
        firebaseUID: String? = nil,
        lookup: BuddyFeedAvatarLookup = .empty
    ) -> DiveBuddyAvatarChipSources {
        if let local = profilePhoto, !local.isEmpty {
            return DiveBuddyAvatarChipSources(localProfilePhoto: local, photoURL: nil)
        }
        if let linked = trimmedNonEmpty(linkedPhotoURL) {
            return DiveBuddyAvatarChipSources(localProfilePhoto: nil, photoURL: linked)
        }
        let resolved = BuddyFeedAvatarPresentation.resolve(
            firebaseUID: firebaseUID,
            lookup: lookup
        )
        if let local = resolved.localProfilePhoto, !local.isEmpty {
            return DiveBuddyAvatarChipSources(
                localProfilePhoto: local,
                photoURL: resolved.photoURL
            )
        }
        return DiveBuddyAvatarChipSources(
            localProfilePhoto: nil,
            photoURL: resolved.photoURL
        )
    }

    nonisolated static func sources(
        for buddy: DiveBuddy,
        lookup: BuddyFeedAvatarLookup = .empty
    ) -> DiveBuddyAvatarChipSources {
        sources(
            profilePhoto: buddy.profilePhoto,
            linkedPhotoURL: buddy.linkedPhotoURL,
            firebaseUID: DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy),
            lookup: lookup
        )
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}
