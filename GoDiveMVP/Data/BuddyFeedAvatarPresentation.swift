import Foundation

/// Resolved sources for a Buddy Feed / comment avatar (remote Storage URL and/or local Profile JPEG).
struct BuddyFeedResolvedAvatar: Equatable, Sendable {
    var photoURL: String?
    var localProfilePhoto: Data?
}

/// Lookup context so tagged / comment avatars match Profile and friend graph photos.
struct BuddyFeedAvatarLookup: Equatable, Sendable {
    var currentFirebaseUID: String?
    var currentLocalProfilePhoto: Data?
    var currentRemotePhotoURL: String?
    /// Friend graph `photoURL` keyed by Firebase UID (may include roster `linkedPhotoURL` fallbacks).
    var friendPhotoURLByUID: [String: String]
    /// Local roster JPEG keyed by linked Firebase UID (when Contacts/Photos photo exists).
    var localProfilePhotoByUID: [String: Data]

    /// Explicitly **`nonisolated`** so nonisolated prefetch helpers can use the default without MainActor hops.
    nonisolated static let empty = BuddyFeedAvatarLookup(
        currentFirebaseUID: nil,
        currentLocalProfilePhoto: nil,
        currentRemotePhotoURL: nil,
        friendPhotoURLByUID: [:],
        localProfilePhotoByUID: [:]
    )

    /// Roster-linked Storage URLs + local JPEGs used when the friend-graph edge has no `photoURL`.
    struct RosterFallbacks: Equatable, Sendable {
        var photoURLByUID: [String: String]
        var localProfilePhotoByUID: [String: Data]

        nonisolated static let empty = RosterFallbacks(photoURLByUID: [:], localProfilePhotoByUID: [:])
    }

    nonisolated static func rosterFallbacks(from buddies: [DiveBuddy]) -> RosterFallbacks {
        var urls: [String: String] = [:]
        var locals: [String: Data] = [:]
        for buddy in buddies {
            guard let uid = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy) else {
                continue
            }
            if let photo = buddy.profilePhoto, !photo.isEmpty {
                locals[uid] = photo
            }
            if let url = trimmedNonEmpty(buddy.linkedPhotoURL) {
                urls[uid] = url
            }
        }
        return RosterFallbacks(photoURLByUID: urls, localProfilePhotoByUID: locals)
    }

    nonisolated static func make(
        currentFirebaseUID: String?,
        currentLocalProfilePhoto: Data?,
        currentRemotePhotoURL: String? = nil,
        friends: [GoDiveFriendGraphService.FriendEdge],
        rosterFallbacks: RosterFallbacks = .empty
    ) -> BuddyFeedAvatarLookup {
        var map: [String: String] = [:]
        for friend in friends {
            let uid = friend.friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = friend.photoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !uid.isEmpty, !url.isEmpty else { continue }
            map[uid] = url
        }
        for (uid, url) in rosterFallbacks.photoURLByUID {
            let trimmedUID = uid.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUID.isEmpty, !trimmedURL.isEmpty else { continue }
            if map[trimmedUID] == nil {
                map[trimmedUID] = trimmedURL
            }
        }
        return BuddyFeedAvatarLookup(
            currentFirebaseUID: trimmedNonEmpty(currentFirebaseUID),
            currentLocalProfilePhoto: currentLocalProfilePhoto.flatMap { $0.isEmpty ? nil : $0 },
            currentRemotePhotoURL: trimmedNonEmpty(currentRemotePhotoURL),
            friendPhotoURLByUID: map,
            localProfilePhotoByUID: rosterFallbacks.localProfilePhotoByUID
        )
    }

    /// Convenience — extract roster fallbacks from linked **`DiveBuddy`** rows.
    nonisolated static func make(
        currentFirebaseUID: String?,
        currentLocalProfilePhoto: Data?,
        currentRemotePhotoURL: String? = nil,
        friends: [GoDiveFriendGraphService.FriendEdge],
        rosterBuddies: [DiveBuddy]
    ) -> BuddyFeedAvatarLookup {
        make(
            currentFirebaseUID: currentFirebaseUID,
            currentLocalProfilePhoto: currentLocalProfilePhoto,
            currentRemotePhotoURL: currentRemotePhotoURL,
            friends: friends,
            rosterFallbacks: rosterFallbacks(from: rosterBuddies)
        )
    }

    /// Cheap equality token for list-surface `Equatable` (avoids comparing full JPEG payloads).
    nonisolated var equatableFingerprint: String {
        let photoKey = ProfileAvatarImageCachePresentation.cacheKey(
            for: currentLocalProfilePhoto ?? Data()
        )
        let friends = friendPhotoURLByUID.keys.sorted().map { key in
            "\(key)=\(friendPhotoURLByUID[key] ?? "")"
        }.joined(separator: "|")
        let locals = localProfilePhotoByUID.keys.sorted().map { key in
            let data = localProfilePhotoByUID[key] ?? Data()
            return "\(key)=\(ProfileAvatarImageCachePresentation.cacheKey(for: data))"
        }.joined(separator: "|")
        return [
            currentFirebaseUID ?? "",
            photoKey,
            currentRemotePhotoURL ?? "",
            friends,
            locals,
        ].joined(separator: "#")
    }

    /// Prefer local Profile / roster bytes; otherwise friend-graph / self remote URL.
    nonisolated func resolved(forFirebaseUID rawUID: String?) -> BuddyFeedResolvedAvatar {
        guard let uid = Self.trimmedNonEmpty(rawUID) else {
            return BuddyFeedResolvedAvatar(photoURL: nil, localProfilePhoto: nil)
        }
        if let current = currentFirebaseUID, uid == current {
            // Profile JPEG is the source of truth for "me" on Buddy Feed / comments.
            if let local = currentLocalProfilePhoto, !local.isEmpty {
                return BuddyFeedResolvedAvatar(photoURL: nil, localProfilePhoto: local)
            }
            if let rosterLocal = localProfilePhotoByUID[uid], !rosterLocal.isEmpty {
                return BuddyFeedResolvedAvatar(photoURL: nil, localProfilePhoto: rosterLocal)
            }
            return BuddyFeedResolvedAvatar(
                photoURL: currentRemotePhotoURL ?? friendPhotoURLByUID[uid],
                localProfilePhoto: nil
            )
        }
        if let rosterLocal = localProfilePhotoByUID[uid], !rosterLocal.isEmpty {
            return BuddyFeedResolvedAvatar(
                photoURL: friendPhotoURLByUID[uid],
                localProfilePhoto: rosterLocal
            )
        }
        return BuddyFeedResolvedAvatar(
            photoURL: friendPhotoURLByUID[uid],
            localProfilePhoto: nil
        )
    }

    /// Merge a seed lookup with a freshly built session/friends lookup (keeps seed friend URLs when fetch is empty).
    nonisolated static func merging(
        seed: BuddyFeedAvatarLookup,
        session: BuddyFeedAvatarLookup
    ) -> BuddyFeedAvatarLookup {
        let friendMap: [String: String]
        if session.friendPhotoURLByUID.isEmpty {
            friendMap = seed.friendPhotoURLByUID
        } else {
            var merged = seed.friendPhotoURLByUID
            for (uid, url) in session.friendPhotoURLByUID {
                merged[uid] = url
            }
            friendMap = merged
        }
        var localMap = seed.localProfilePhotoByUID
        for (uid, data) in session.localProfilePhotoByUID {
            localMap[uid] = data
        }
        let localPhoto = session.currentLocalProfilePhoto ?? seed.currentLocalProfilePhoto
        return BuddyFeedAvatarLookup(
            currentFirebaseUID: session.currentFirebaseUID ?? seed.currentFirebaseUID,
            currentLocalProfilePhoto: localPhoto.flatMap { $0.isEmpty ? nil : $0 },
            currentRemotePhotoURL: session.currentRemotePhotoURL ?? seed.currentRemotePhotoURL,
            friendPhotoURLByUID: friendMap,
            localProfilePhotoByUID: localMap
        )
    }

    /// Remote URLs worth warming in **`GoDiveSharedMediaCache`** (tagged + current user).
    nonisolated func prefetchablePhotoURLs(
        taggedFirebaseUIDs: [String]
    ) -> [String] {
        var seen = Set<String>()
        var urls: [String] = []
        func append(_ raw: String?) {
            guard let url = Self.trimmedNonEmpty(raw),
                  GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: url) != nil,
                  seen.insert(url).inserted
            else { return }
            urls.append(url)
        }
        append(currentRemotePhotoURL)
        for uid in taggedFirebaseUIDs {
            append(resolved(forFirebaseUID: uid).photoURL)
        }
        return urls
    }

    nonisolated private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

enum BuddyFeedAvatarPresentation: Sendable {
    /// Testable resolve rules for tagged / comment avatars.
    nonisolated static func resolve(
        firebaseUID: String?,
        lookup: BuddyFeedAvatarLookup
    ) -> BuddyFeedResolvedAvatar {
        lookup.resolved(forFirebaseUID: firebaseUID)
    }
}
