import Foundation
import os
import FirebaseAuth
import FirebaseFirestore

/// Friend invites + friendship graph on Firestore.
enum GoDiveFriendGraphService: Sendable {
    nonisolated private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FriendGraph")

    struct PublicProfileSummary: Equatable, Sendable {
        var uid: String
        var displayName: String
        var photoURL: String?
        var profileHeroURL: String?
        var profileHeroMediaKind: GoDiveProfileHeroMediaKind?
        var totalDiveCount: Int?
    }

    /// **`nonisolated`** so **`LogbookRoute`** / tests can hash & equate without MainActor.
    nonisolated struct FriendEdge: Equatable, Sendable, Identifiable, Hashable {
        var id: String { friendUID }
        var friendUID: String
        var friendshipID: String
        var displayName: String
        var photoURL: String?
        var profileHeroURL: String?
        var profileHeroMediaKind: GoDiveProfileHeroMediaKind?
        var totalDiveCount: Int?
        var since: Date?
    }

    enum Outcome: Equatable, Sendable {
        case skippedNotConfigured
        case skippedNotSignedIn
        case success
        case failed(String)
    }

    struct Failure: Error, Equatable, Sendable {
        var message: String
    }

    /// Friendships list row / navigation seed when only UID + display name are known (e.g. Buddy Feed).
    nonisolated static func friendEdge(
        friendUID: String,
        friendshipID: String = "",
        displayName: String,
        photoURL: String? = nil,
        profileHeroURL: String? = nil,
        profileHeroMediaKind: GoDiveProfileHeroMediaKind? = nil,
        totalDiveCount: Int? = nil,
        since: Date? = nil
    ) -> FriendEdge {
        FriendEdge(
            friendUID: friendUID,
            friendshipID: friendshipID,
            displayName: displayName,
            photoURL: photoURL,
            profileHeroURL: profileHeroURL,
            profileHeroMediaKind: profileHeroMediaKind,
            totalDiveCount: totalDiveCount,
            since: since
        )
    }

    @MainActor
    static func createInvite() async -> Result<(token: String, url: URL), Failure> {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else {
            return .failure(Failure(message: GoDiveFriendsPresentation.firebaseUnavailableMessage))
        }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            return .failure(Failure(message: GoDiveFriendsPresentation.firebaseUnavailableMessage))
        }

        let fromDisplayName = resolvedCurrentUserDisplayName()
        await publishDirectoryDisplayNameIfNeeded(fromDisplayName)

        let draft = GoDiveFriendInviteMapping.inviteDraft(
            fromUid: uid,
            fromDisplayName: fromDisplayName
        )
        guard let url = GoDiveFriendInviteURL.preferredInviteURL(token: draft.token)
        else {
            return .failure(Failure(message: "Could not build invite link."))
        }

        do {
            let db = Firestore.firestore()
            try await db.collection(GoDiveFriendInviteMapping.inviteCollection)
                .document(draft.token)
                .setData(GoDiveFriendInviteMapping.inviteFields(from: draft))
            log.notice("Friend invite created")
            return .success((draft.token, url))
        } catch {
            log.error("Friend invite create failed: \(String(describing: error), privacy: .private)")
            return .failure(Failure(message: "Could not create invite. Try again."))
        }
    }

    @MainActor
    static func revokeInvite(token: String) async -> Outcome {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return .skippedNotConfigured }
        guard let uid = Auth.auth().currentUser?.uid else { return .skippedNotSignedIn }
        let normalized = GoDiveFriendInviteURL.normalizedToken(token)
        guard !normalized.isEmpty else { return .failed("Invalid invite.") }

        do {
            let ref = Firestore.firestore()
                .collection(GoDiveFriendInviteMapping.inviteCollection)
                .document(normalized)
            let snap = try await ref.getDocument()
            guard let data = snap.data(),
                  let fromUid = data["fromUid"] as? String,
                  fromUid == uid
            else {
                return .failed("Invite not found.")
            }
            try await ref.setData(
                ["status": GoDiveFriendInviteMapping.inviteStatusRevoked],
                merge: true
            )
            return .success
        } catch {
            log.error("Invite revoke failed: \(String(describing: error), privacy: .private)")
            return .failed("Could not revoke invite.")
        }
    }

    @MainActor
    static func loadInvitePreview(token: String) async -> Result<(fromUid: String, profile: PublicProfileSummary), Failure> {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else {
            return .failure(Failure(message: GoDiveFriendsPresentation.firebaseUnavailableMessage))
        }
        guard let me = Auth.auth().currentUser?.uid else {
            return .failure(Failure(message: GoDiveFriendsPresentation.firebaseUnavailableMessage))
        }
        let normalized = GoDiveFriendInviteURL.normalizedToken(token)
        do {
            let snap = try await Firestore.firestore()
                .collection(GoDiveFriendInviteMapping.inviteCollection)
                .document(normalized)
                .getDocument()
            guard let data = snap.data() else {
                return .failure(Failure(message: GoDiveFriendsPresentation.redeemFailureMessage(.inviteMissing)))
            }
            switch GoDiveFriendInviteMapping.validateRedeem(
                inviteFromUid: data["fromUid"] as? String,
                inviteStatus: data["status"] as? String,
                inviteExpiresAt: (data["expiresAt"] as? Timestamp)?.dateValue(),
                redeemingUid: me,
                alreadyFriends: false,
                currentFriendCount: 0
            ) {
            case .failure(let error):
                // Cap / already-friends checked on redeem.
                if error != .friendCapReached && error != .alreadyFriends {
                    return .failure(Failure(message: GoDiveFriendsPresentation.redeemFailureMessage(error)))
                }
            case .success:
                break
            }
            guard let fromUid = (data["fromUid"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !fromUid.isEmpty
            else {
                return .failure(Failure(message: GoDiveFriendsPresentation.redeemFailureMessage(.inviteMissing)))
            }
            let inviteName = data["fromDisplayName"] as? String
            let profile = await resolvedPublicProfile(
                uid: fromUid,
                inviteFromDisplayName: inviteName
            )
            return .success((fromUid, profile))
        } catch {
            log.error("Invite preview failed: \(String(describing: error), privacy: .private)")
            return .failure(Failure(message: "Could not load invite."))
        }
    }

    @MainActor
    static func redeemInvite(token: String) async -> Result<PublicProfileSummary, Failure> {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else {
            return .failure(Failure(message: GoDiveFriendsPresentation.firebaseUnavailableMessage))
        }
        guard let me = Auth.auth().currentUser?.uid, !me.isEmpty else {
            return .failure(Failure(message: GoDiveFriendsPresentation.firebaseUnavailableMessage))
        }
        let normalized = GoDiveFriendInviteURL.normalizedToken(token)

        do {
            let db = Firestore.firestore()
            let inviteRef = db.collection(GoDiveFriendInviteMapping.inviteCollection).document(normalized)
            let inviteSnap = try await inviteRef.getDocument()
            guard let inviteData = inviteSnap.data() else {
                return .failure(Failure(message: GoDiveFriendsPresentation.redeemFailureMessage(.inviteMissing)))
            }

            let memberLists = try await fetchActiveFriendshipMemberLists()
            let alreadyFriends = GoDiveFriendInviteMapping.hasActiveFriendship(
                with: (inviteData["fromUid"] as? String) ?? "",
                memberLists: memberLists
            )
            let validation = GoDiveFriendInviteMapping.validateRedeem(
                inviteFromUid: inviteData["fromUid"] as? String,
                inviteStatus: inviteData["status"] as? String,
                inviteExpiresAt: (inviteData["expiresAt"] as? Timestamp)?.dateValue(),
                redeemingUid: me,
                alreadyFriends: alreadyFriends,
                currentFriendCount: memberLists.count
            )
            let fromUid: String
            switch validation {
            case .failure(let error):
                return .failure(Failure(message: GoDiveFriendsPresentation.redeemFailureMessage(error)))
            case .success(let uid):
                fromUid = uid
            }

            let inviteFromDisplayName = inviteData["fromDisplayName"] as? String
            let inviterProfile = await resolvedPublicProfile(
                uid: fromUid,
                inviteFromDisplayName: inviteFromDisplayName
            )
            let friendship = GoDiveFriendInviteMapping.friendshipDraft(
                uidA: me,
                uidB: fromUid,
                inviteToken: normalized,
                displayNameA: resolvedCurrentUserDisplayName(),
                displayNameB: inviterProfile.displayName
            )
            let friendshipRef = db.collection(GoDiveFriendInviteMapping.friendshipsCollection)
                .document(friendship.friendshipID)

            let batch = db.batch()
            batch.setData(GoDiveFriendInviteMapping.friendshipFields(from: friendship), forDocument: friendshipRef)
            batch.setData(
                [
                    "status": GoDiveFriendInviteMapping.inviteStatusRedeemed,
                    "redeemedBy": me,
                ],
                forDocument: inviteRef,
                merge: true
            )
            try await batch.commit()

            GoDiveSecurityEvent.record(.friendAdded, detail: "invite")
            log.notice("Friendship created via invite")
            GoDiveFriendGraphChangeNotification.post()
            return .success(inviterProfile)
        } catch {
            log.error("Invite redeem failed: \(String(describing: error), privacy: .private)")
            return .failure(Failure(message: "Could not connect. Try again."))
        }
    }

    // MARK: - Friends list

    @MainActor
    static func listFriendEdges() async throws -> [FriendEdge] {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return [] }
        guard let me = Auth.auth().currentUser?.uid, !me.isEmpty else { return [] }

        let snap = try await Firestore.firestore()
            .collection(GoDiveFriendInviteMapping.friendshipsCollection)
            .whereField("members", arrayContains: me)
            .getDocuments()

        struct Pending {
            var friendUID: String
            var friendshipID: String
            var since: Date?
            var snapshotDisplayName: String?
        }

        var pending: [Pending] = []
        pending.reserveCapacity(snap.documents.count)
        for doc in snap.documents {
            let data = doc.data()
            guard (data["status"] as? String) == GoDiveFriendInviteMapping.friendshipStatusActive else {
                continue
            }
            let members = data["members"] as? [String] ?? []
            guard let other = GoDiveFriendInviteMapping.otherMember(members: members, excluding: me) else {
                continue
            }
            pending.append(
                Pending(
                    friendUID: other,
                    friendshipID: doc.documentID,
                    since: (data["createdAt"] as? Timestamp)?.dateValue(),
                    snapshotDisplayName: GoDiveFriendInviteMapping.memberDisplayName(
                        for: other,
                        in: data["memberDisplayNames"]
                    )
                )
            )
        }

        let profilesByUID = await fetchPublicProfiles(uid: pending.map(\.friendUID))

        let edges = pending.map { item in
            let profile = profilesByUID[item.friendUID]
            return FriendEdge(
                friendUID: item.friendUID,
                friendshipID: item.friendshipID,
                displayName: GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                    directoryDisplayName: profile?.displayName,
                    inviteFromDisplayName: item.snapshotDisplayName
                ),
                photoURL: profile?.photoURL,
                profileHeroURL: profile?.profileHeroURL,
                profileHeroMediaKind: profile?.profileHeroMediaKind,
                totalDiveCount: profile?.totalDiveCount,
                since: item.since
            )
        }
        return edges.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    /// Count active friendships without loading public profiles.
    @MainActor
    static func activeFriendshipCount() async throws -> Int {
        try await fetchActiveFriendshipMemberLists().count
    }

    /// `members` arrays for the current user's active friendships.
    /// Query is `arrayContains` current uid so Firestore list rules allow the empty-result case.
    @MainActor
    private static func fetchActiveFriendshipMemberLists() async throws -> [[String]] {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return [] }
        guard let me = Auth.auth().currentUser?.uid, !me.isEmpty else { return [] }

        let snap = try await Firestore.firestore()
            .collection(GoDiveFriendInviteMapping.friendshipsCollection)
            .whereField("members", arrayContains: me)
            .getDocuments()
        return snap.documents.compactMap { doc in
            let data = doc.data()
            guard (data["status"] as? String) == GoDiveFriendInviteMapping.friendshipStatusActive else {
                return nil
            }
            return data["members"] as? [String]
        }
    }

    @MainActor
    private static func fetchPublicProfiles(uid: [String]) async -> [String: PublicProfileSummary] {
        let unique = Array(Set(uid.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return [:] }

        return await withTaskGroup(of: (String, PublicProfileSummary?).self) { group in
            for id in unique {
                group.addTask {
                    (id, await fetchPublicProfile(uid: id))
                }
            }
            var map: [String: PublicProfileSummary] = [:]
            map.reserveCapacity(unique.count)
            for await (id, profile) in group {
                if let profile {
                    map[id] = profile
                }
            }
            return map
        }
    }

    @MainActor
    static func unfriend(friendshipID: String) async -> Outcome {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return .skippedNotConfigured }
        guard let me = Auth.auth().currentUser?.uid else { return .skippedNotSignedIn }

        do {
            let ref = Firestore.firestore()
                .collection(GoDiveFriendInviteMapping.friendshipsCollection)
                .document(friendshipID)
            let snap = try await ref.getDocument()
            guard let members = snap.data()?["members"] as? [String], members.contains(me) else {
                return .failed("Friendship not found.")
            }
            try await ref.delete()
            GoDiveSecurityEvent.record(.friendRemoved, detail: "unfriend")
            GoDiveFriendGraphChangeNotification.post()
            return .success
        } catch {
            log.error("Unfriend failed: \(String(describing: error), privacy: .private)")
            return .failed("Could not remove friend.")
        }
    }

    @MainActor
    static func hasAnyFriends() async -> Bool {
        ((try? await activeFriendshipCount()) ?? 0) > 0
    }

    nonisolated static func fetchPublicProfile(uid: String) async -> PublicProfileSummary? {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            let snap = try await Firestore.firestore().collection("users").document(trimmed).getDocument()
            guard let data = snap.data() else { return nil }
            let name = (data["displayName"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? UserProfileStore.defaultDisplayName
            let photo = (data["photoURL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let heroURL = (data["profileHeroURL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let heroKind = GoDiveProfileHeroMediaKind.fromFirestoreValue(
                data["profileHeroMediaKind"] as? String
            )
            return PublicProfileSummary(
                uid: trimmed,
                displayName: name.isEmpty ? UserProfileStore.defaultDisplayName : name,
                photoURL: (photo?.isEmpty == false) ? photo : nil,
                profileHeroURL: (heroURL?.isEmpty == false) ? heroURL : nil,
                profileHeroMediaKind: heroKind,
                totalDiveCount: GoDiveFirestoreUserProfileMapping.totalDiveCount(from: data)
            )
        } catch {
            log.error("Public profile fetch failed: \(String(describing: error), privacy: .private)")
            return nil
        }
    }

    @MainActor
    private static func resolvedPublicProfile(
        uid: String,
        inviteFromDisplayName: String?
    ) async -> PublicProfileSummary {
        if var profile = await fetchPublicProfile(uid: uid) {
            profile.displayName = GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                directoryDisplayName: profile.displayName,
                inviteFromDisplayName: inviteFromDisplayName
            )
            return profile
        }
        return PublicProfileSummary(
            uid: uid,
            displayName: GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                directoryDisplayName: nil,
                inviteFromDisplayName: inviteFromDisplayName
            ),
            photoURL: nil
        )
    }

    @MainActor
    private static func resolvedCurrentUserDisplayName() -> String? {
        let profile = AccountSession.shared.currentProfile
        let appleID = profile?.appleUserIdentifier
        return GoDiveFriendInviteMapping.resolvedPublisherDisplayName(
            localProfileName: profile?.displayName,
            authDisplayName: Auth.auth().currentUser?.displayName,
            cachedAppleName: appleID.flatMap { UserProfileStore.cachedDisplayName(forAppleUserIdentifier: $0) },
            returningHintName: appleID.flatMap {
                ReturningAccountHints.rememberedDisplayName(forAppleUserIdentifier: $0)
            }
        )
    }

    /// Best-effort directory write so invite previews can resolve a real name even when the
    /// first signup upsert never completed (stuck photo-step deferral).
    /// Never publishes the placeholder **Diver** — that would overwrite a real directory name.
    @MainActor
    private static func publishDirectoryDisplayNameIfNeeded(_ displayName: String?) async {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard let name = GoDiveFriendInviteMapping.sanitizedFromDisplayName(displayName) else { return }
        do {
            try await Firestore.firestore().collection("users").document(uid).setData(
                [
                    "displayName": name,
                    "updatedAt": FieldValue.serverTimestamp(),
                ],
                merge: true
            )
            GoDiveFirestoreProfilePublishGate.clear()
        } catch {
            log.error("Directory display name publish failed: \(String(describing: error), privacy: .private)")
        }
    }

    /// Deletes friendships involving the current user and open invites they created (account delete).
    @MainActor
    static func deleteAllSocialGraphForCurrentUser() async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let me = Auth.auth().currentUser?.uid, !me.isEmpty else { return }
        let db = Firestore.firestore()
        do {
            let friendships = try await db.collection(GoDiveFriendInviteMapping.friendshipsCollection)
                .whereField("members", arrayContains: me)
                .getDocuments()
            for doc in friendships.documents {
                try await doc.reference.delete()
            }
            let invites = try await db.collection(GoDiveFriendInviteMapping.inviteCollection)
                .whereField("fromUid", isEqualTo: me)
                .getDocuments()
            for doc in invites.documents {
                try await doc.reference.delete()
            }
        } catch {
            log.error("Social graph wipe failed: \(String(describing: error), privacy: .private)")
        }
    }
}
