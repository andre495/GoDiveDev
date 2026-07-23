import Foundation
import SwiftData

/// Links accepted GoDive friends into the local **`DiveBuddy`** roster (name match + merge duplicates).
enum GoDiveFriendBuddyLinking: Sendable {
    @MainActor
    private static var cachedFriendEdges: [GoDiveFriendGraphService.FriendEdge] = []

    @MainActor
    static func seedCachedFriendEdgesForTesting(_ edges: [GoDiveFriendGraphService.FriendEdge]) {
        cachedFriendEdges = edges
    }

    @MainActor
    static func syncRosterLinks(
        friends: [GoDiveFriendGraphService.FriendEdge],
        owner: UserProfile?,
        modelContext: ModelContext
    ) {
        cachedFriendEdges = friends
        guard let owner else { return }
        for edge in friends {
            _ = upsertRosterBuddy(
                friendUID: edge.friendUID,
                displayName: edge.displayName,
                photoURL: edge.photoURL,
                owner: owner,
                modelContext: modelContext
            )
        }
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

        for buddy in buddies {
            guard !DiveBuddyCatalog.shouldExcludeBuddyName(buddy.displayName, owner: owner) else { continue }
            guard let edge = resolvedFriendEdge(
                buddyDisplayName: buddy.displayName,
                friends: friends,
                reservedFriendUIDs: reservedFriendUIDs
            ) else { continue }

            if upsertRosterBuddy(
                friendUID: edge.friendUID,
                displayName: edge.displayName,
                photoURL: edge.photoURL,
                owner: owner,
                modelContext: modelContext
            ) != nil {
                reservedFriendUIDs.insert(edge.friendUID)
            }
        }
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
        modelContext: ModelContext
    ) -> DiveBuddy? {
        guard let owner else { return nil }
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return nil }
        guard !DiveBuddyCatalog.shouldExcludeBuddyName(displayName, owner: owner) else { return nil }

        let ownerID = owner.id
        let buddies = (try? modelContext.fetch(FetchDescriptor<DiveBuddy>()))?
            .filter { $0.ownerProfileID == ownerID } ?? []

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
            guard let created else { return nil }
            canonical = created
        }

        applyFriendMetadata(
            to: canonical,
            friendUID: uid,
            displayName: displayName,
            photoURL: photoURL
        )
        consolidateFuzzyNameDuplicates(
            into: canonical,
            friendDisplayName: displayName,
            friendUID: uid,
            ownerProfileID: ownerID,
            modelContext: modelContext
        )
        try? modelContext.save()
        DiveBuddyRosterChangeNotification.post()
        return canonical
    }

    @MainActor
    static func clearLink(friendUID: String, ownerProfileID: UUID, modelContext: ModelContext) {
        let uid = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { return }
        let buddies = (try? modelContext.fetch(FetchDescriptor<DiveBuddy>()))?
            .filter { $0.ownerProfileID == ownerProfileID && $0.linkedFirebaseUID == uid } ?? []
        for buddy in buddies {
            buddy.linkedFirebaseUID = nil
            buddy.linkedPhotoURL = nil
        }
        try? modelContext.save()
        DiveBuddyRosterChangeNotification.post()
    }

    // MARK: - Private

    @MainActor
    private static func applyFriendMetadata(
        to buddy: DiveBuddy,
        friendUID: String,
        displayName: String,
        photoURL: String?
    ) {
        buddy.linkedFirebaseUID = friendUID
        buddy.linkedPhotoURL = photoURL
        let preferred = GoDiveInputSanitization.trimmedAndCapped(
            displayName,
            maxLength: DiveBuddyCatalog.maxDisplayNameLength
        )
        if !preferred.isEmpty {
            let merged = DiveBuddyNameMatching.preferredDisplayName(
                imported: preferred,
                existing: buddy.displayName
            )
            buddy.displayName = merged
        }
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
    private static func consolidateFuzzyNameDuplicates(
        into canonical: DiveBuddy,
        friendDisplayName: String,
        friendUID: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) {
        let buddies = (try? modelContext.fetch(FetchDescriptor<DiveBuddy>()))?
            .filter { $0.ownerProfileID == ownerProfileID } ?? []
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
        for duplicate in duplicates {
            DiveBuddyRosterMerge.merge(duplicate, into: canonical, modelContext: modelContext)
        }
    }

    @MainActor
    private static func fetchOwnerProfile(id: UUID, modelContext: ModelContext) -> UserProfile? {
        let all = (try? modelContext.fetch(FetchDescriptor<UserProfile>())) ?? []
        return all.first { $0.id == id }
    }

    @MainActor
    private static func fetchBuddies(
        ids: Set<UUID>,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> [DiveBuddy] {
        let all = (try? modelContext.fetch(FetchDescriptor<DiveBuddy>())) ?? []
        return all.filter { ids.contains($0.id) && $0.ownerProfileID == ownerProfileID }
    }

    @MainActor
    private static func linkedFriendUIDs(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> Set<String> {
        let all = (try? modelContext.fetch(FetchDescriptor<DiveBuddy>())) ?? []
        return Set(
            all.compactMap { buddy -> String? in
                guard buddy.ownerProfileID == ownerProfileID else { return nil }
                return DiveBuddyFriendLinkPresentation.linkedFirebaseUID(for: buddy)
            }
        )
    }
}
