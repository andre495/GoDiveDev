import Foundation
import SwiftData

/// Links accepted GoDive friends into the local **`DiveBuddy`** roster (name match + merge duplicates).
enum GoDiveFriendBuddyLinking: Sendable {
    @MainActor
    private static var cachedFriendEdges: [GoDiveFriendGraphService.FriendEdge] = []

    /// Last friends-graph fingerprint applied to the roster — skips no-op Buddies-list revisits.
    @MainActor
    private static var lastSyncedFriendsFingerprint: String?

    @MainActor
    static func seedCachedFriendEdgesForTesting(_ edges: [GoDiveFriendGraphService.FriendEdge]) {
        cachedFriendEdges = edges
    }

    @MainActor
    static func resetSessionSyncStateForTesting() {
        cachedFriendEdges = []
        lastSyncedFriendsFingerprint = nil
    }

    /// Stable fingerprint for friend edges that affect roster link metadata.
    nonisolated static func friendsRosterSyncFingerprint(
        _ friends: [GoDiveFriendGraphService.FriendEdge]
    ) -> String {
        friends
            .map { edge in
                let photo = edge.photoURL ?? ""
                return "\(edge.friendUID)|\(edge.displayName)|\(photo)"
            }
            .sorted()
            .joined(separator: ";")
    }

    /// **`true`** when every friend already has a linked roster row with matching name + photo.
    nonisolated static func rosterLinksAlreadyCurrent(
        friends: [GoDiveFriendGraphService.FriendEdge],
        linkedBuddies: [(uid: String, displayName: String, photoURL: String?)]
    ) -> Bool {
        guard !friends.isEmpty else { return true }
        let byUID = Dictionary(uniqueKeysWithValues: linkedBuddies.map { ($0.uid, $0) })
        for edge in friends {
            guard let linked = byUID[edge.friendUID] else { return false }
            let preferred = GoDiveInputSanitization.trimmedAndCapped(
                edge.displayName,
                maxLength: DiveBuddyCatalog.maxDisplayNameLength
            )
            let expectedName = preferred.isEmpty
                ? linked.displayName
                : DiveBuddyNameMatching.preferredDisplayName(
                    imported: preferred,
                    existing: linked.displayName
                )
            if linked.displayName != expectedName { return false }
            if linked.photoURL != edge.photoURL { return false }
        }
        return true
    }

    @MainActor
    static func syncRosterLinks(
        friends: [GoDiveFriendGraphService.FriendEdge],
        owner: UserProfile?,
        modelContext: ModelContext
    ) {
        cachedFriendEdges = friends
        guard let owner else { return }

        let fingerprint = friendsRosterSyncFingerprint(friends)
        let existing = fetchOwnerBuddies(ownerProfileID: owner.id, modelContext: modelContext)
        let linkedSnapshots: [(uid: String, displayName: String, photoURL: String?)] = existing.compactMap { buddy in
            guard let uid = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy) else { return nil }
            return (uid, buddy.displayName, buddy.linkedPhotoURL)
        }
        if lastSyncedFriendsFingerprint == fingerprint,
           rosterLinksAlreadyCurrent(friends: friends, linkedBuddies: linkedSnapshots) {
            return
        }

        var didChange = false
        for edge in friends {
            let result = upsertRosterBuddyResult(
                friendUID: edge.friendUID,
                displayName: edge.displayName,
                photoURL: edge.photoURL,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: false
            )
            didChange = didChange || result.didChange
        }

        lastSyncedFriendsFingerprint = fingerprint
        guard didChange else { return }
        try? modelContext.save()
        DiveBuddyRosterChangeNotification.post()
    }

    @MainActor
    static func syncRosterLinksIfPossible(
        owner: UserProfile?,
        modelContext: ModelContext
    ) async {
        guard let owner else { return }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() != nil else { return }
        guard let friends = try? await GoDiveFriendGraphService.listFriendEdges() else { return }
        cachedFriendEdges = friends
        syncRosterLinks(friends: friends, owner: owner, modelContext: modelContext)
    }

    /// Fuzzy-matches unlinked roster buddies to GoDive friends (import batches + single tags).
    @MainActor
    static func autoLinkUnlinkedBuddies(
        owner: UserProfile,
        modelContext: ModelContext,
        buddyIDs: Set<UUID>
    ) async {
        guard !buddyIDs.isEmpty else { return }

        let friends: [GoDiveFriendGraphService.FriendEdge]
        if !cachedFriendEdges.isEmpty {
            friends = cachedFriendEdges
        } else {
            GoDiveFirebaseBootstrap.configureIfNeeded()
            guard GoDiveFirebaseBootstrap.isConfigured else { return }
            guard GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID() != nil else { return }
            guard let fetched = try? await GoDiveFriendGraphService.listFriendEdges() else { return }
            cachedFriendEdges = fetched
            friends = fetched
        }
        guard !friends.isEmpty else { return }

        let buddies = fetchBuddies(ids: buddyIDs, ownerProfileID: owner.id, modelContext: modelContext)
            .filter { !DiveBuddyFriendLinkPresentation.isLinkedFriend($0) }
        guard !buddies.isEmpty else { return }

        var reservedFriendUIDs = linkedFriendUIDs(ownerProfileID: owner.id, modelContext: modelContext)
        var didChange = false

        for buddy in buddies {
            guard !DiveBuddyCatalog.shouldExcludeBuddyName(buddy.displayName, owner: owner) else { continue }
            guard let edge = resolvedFriendEdge(
                buddyDisplayName: buddy.displayName,
                friends: friends,
                reservedFriendUIDs: reservedFriendUIDs
            ) else { continue }

            let result = upsertRosterBuddyResult(
                friendUID: edge.friendUID,
                displayName: edge.displayName,
                photoURL: edge.photoURL,
                owner: owner,
                modelContext: modelContext,
                persistImmediately: false
            )
            if result.buddy != nil {
                reservedFriendUIDs.insert(edge.friendUID)
            }
            didChange = didChange || result.didChange
        }

        guard didChange else { return }
        try? modelContext.save()
        DiveBuddyRosterChangeNotification.post()
    }

    @MainActor
    static func scheduleAutoLinkAfterBuddyTagged(_ buddy: DiveBuddy, modelContext: ModelContext) {
        guard let owner = buddy.owner else { return }
        let buddyID = buddy.id
        let ownerProfileID = owner.id
        let container = modelContext.container
        Task { @MainActor in
            let context = ModelContext(container)
            guard let ownerProfile = fetchOwnerProfile(id: ownerProfileID, modelContext: context),
                  fetchBuddies(ids: [buddyID], ownerProfileID: ownerProfileID, modelContext: context).first != nil
            else { return }
            await autoLinkUnlinkedBuddies(
                owner: ownerProfile,
                modelContext: context,
                buddyIDs: [buddyID]
            )
        }
    }

    /// Picks a single friend when fuzzy match is unambiguous (mirrors **`DiveBuddyContactAutoLink`**).
    nonisolated static func resolvedFriendEdge(
        buddyDisplayName: String,
        friends: [GoDiveFriendGraphService.FriendEdge],
        reservedFriendUIDs: Set<String>
    ) -> GoDiveFriendGraphService.FriendEdge? {
        let scored: [(edge: GoDiveFriendGraphService.FriendEdge, score: Int)] = friends.compactMap { edge in
            guard !reservedFriendUIDs.contains(edge.friendUID) else { return nil }
            let score = DiveBuddyNameMatching.matchScore(
                importedName: buddyDisplayName,
                rosterName: edge.displayName
            )
            guard score > 0 else { return nil }
            return (edge, score)
        }
        guard let topScore = scored.map(\.score).max() else { return nil }
        let topMatches = scored.filter { $0.score == topScore }
        guard topMatches.count == 1 else { return nil }
        return topMatches[0].edge
    }

    @MainActor
    @discardableResult
    static func upsertRosterBuddy(
        friendUID: String,
        displayName: String,
        photoURL: String?,
        owner: UserProfile?,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) -> DiveBuddy? {
        upsertRosterBuddyResult(
            friendUID: friendUID,
            displayName: displayName,
            photoURL: photoURL,
            owner: owner,
            modelContext: modelContext,
            persistImmediately: persistImmediately
        ).buddy
    }

    @MainActor
    @discardableResult
    static func upsertRosterBuddyResult(
        friendUID: String,
        displayName: String,
        photoURL: String?,
        owner: UserProfile?,
        modelContext: ModelContext,
        persistImmediately: Bool = true
    ) -> (buddy: DiveBuddy?, didChange: Bool) {
        guard let owner else { return (nil, false) }
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return (nil, false) }
        guard !DiveBuddyCatalog.shouldExcludeBuddyName(displayName, owner: owner) else {
            return (nil, false)
        }

        let ownerID = owner.id
        let buddies = fetchOwnerBuddies(ownerProfileID: ownerID, modelContext: modelContext)

        var didChange = false
        let canonical: DiveBuddy
        if let linked = buddies.first(where: { $0.linkedFirebaseUID == uid }) {
            canonical = linked
        } else if let nameMatch = resolveNameMatchedBuddy(
            displayName: displayName,
            friendUID: uid,
            among: buddies
        ) {
            canonical = nameMatch
        } else {
            let created = DiveBuddyRosterCreation.addBuddy(
                displayName: displayName,
                profilePhoto: nil,
                contactsIdentifier: nil,
                owner: owner,
                modelContext: modelContext
            )
            guard let created else { return (nil, false) }
            canonical = created
            didChange = true
        }

        didChange = applyFriendMetadata(
            to: canonical,
            friendUID: uid,
            displayName: displayName,
            photoURL: photoURL
        ) || didChange
        let mergedDuplicates = consolidateFuzzyNameDuplicates(
            into: canonical,
            friendDisplayName: displayName,
            friendUID: uid,
            ownerProfileID: ownerID,
            modelContext: modelContext
        )
        didChange = didChange || mergedDuplicates

        if persistImmediately, didChange {
            try? modelContext.save()
            DiveBuddyRosterChangeNotification.post()
        }
        return (canonical, didChange)
    }

    @MainActor
    static func clearLink(friendUID: String, ownerProfileID: UUID, modelContext: ModelContext) {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        let buddies = fetchOwnerBuddies(ownerProfileID: ownerProfileID, modelContext: modelContext)
            .filter { $0.linkedFirebaseUID == uid }
        guard !buddies.isEmpty else { return }
        for buddy in buddies {
            buddy.linkedFirebaseUID = nil
            buddy.linkedPhotoURL = nil
        }
        try? modelContext.save()
        DiveBuddyRosterChangeNotification.post()
        lastSyncedFriendsFingerprint = nil
    }

    // MARK: - Private

    @MainActor
    @discardableResult
    private static func applyFriendMetadata(
        to buddy: DiveBuddy,
        friendUID: String,
        displayName: String,
        photoURL: String?
    ) -> Bool {
        var changed = false
        if buddy.linkedFirebaseUID != friendUID {
            buddy.linkedFirebaseUID = friendUID
            changed = true
        }
        if buddy.linkedPhotoURL != photoURL {
            buddy.linkedPhotoURL = photoURL
            changed = true
        }
        let preferred = GoDiveInputSanitization.trimmedAndCapped(
            displayName,
            maxLength: DiveBuddyCatalog.maxDisplayNameLength
        )
        if !preferred.isEmpty {
            let merged = DiveBuddyNameMatching.preferredDisplayName(
                imported: preferred,
                existing: buddy.displayName
            )
            if buddy.displayName != merged {
                buddy.displayName = merged
                changed = true
            }
        }
        return changed
    }

    @MainActor
    private static func resolveNameMatchedBuddy(
        displayName: String,
        friendUID: String,
        among buddies: [DiveBuddy]
    ) -> DiveBuddy? {
        let eligible = buddies.filter { buddy in
            guard let link = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy) else {
                return true
            }
            return link == friendUID
        }
        let scored: [(DiveBuddy, Int)] = eligible.compactMap { buddy in
            let score = DiveBuddyNameMatching.matchScore(
                importedName: displayName,
                rosterName: buddy.displayName
            )
            return score > 0 ? (buddy, score) : nil
        }
        guard let topScore = scored.map(\.1).max() else { return nil }
        let top = scored.filter { $0.1 == topScore }.map(\.0)
        return top.count == 1 ? top[0] : nil
    }

    @MainActor
    @discardableResult
    private static func consolidateFuzzyNameDuplicates(
        into canonical: DiveBuddy,
        friendDisplayName: String,
        friendUID: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> Bool {
        let buddies = fetchOwnerBuddies(ownerProfileID: ownerProfileID, modelContext: modelContext)
        let duplicates = buddies.filter { candidate in
            guard candidate.id != canonical.id else { return false }
            guard candidate.ownerProfileID == ownerProfileID else { return false }
            if let link = DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: candidate),
               link != friendUID {
                return false
            }
            return DiveBuddyNameMatching.isLikelySamePerson(
                importedName: friendDisplayName,
                rosterName: candidate.displayName
            )
        }
        guard !duplicates.isEmpty else { return false }
        for duplicate in duplicates {
            DiveBuddyRosterMerge.merge(duplicate, into: canonical, modelContext: modelContext)
        }
        return true
    }

    @MainActor
    private static func fetchOwnerProfile(id: UUID, modelContext: ModelContext) -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    @MainActor
    private static func fetchOwnerBuddies(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> [DiveBuddy] {
        let descriptor = FetchDescriptor<DiveBuddy>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func fetchBuddies(
        ids: Set<UUID>,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> [DiveBuddy] {
        fetchOwnerBuddies(ownerProfileID: ownerProfileID, modelContext: modelContext)
            .filter { ids.contains($0.id) }
    }

    @MainActor
    private static func linkedFriendUIDs(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> Set<String> {
        Set(
            fetchOwnerBuddies(ownerProfileID: ownerProfileID, modelContext: modelContext)
                .compactMap { DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: $0) }
        )
    }
}
