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

    struct FriendEdge: Equatable, Sendable, Identifiable, Hashable {
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

        let draft = GoDiveFriendInviteMapping.inviteDraft(fromUid: uid)
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
            let profile = await fetchPublicProfile(uid: fromUid)
                ?? PublicProfileSummary(uid: fromUid, displayName: "Diver", photoURL: nil)
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

            let friendCount = try await activeFriendshipCount()
            let validation = GoDiveFriendInviteMapping.validateRedeem(
                inviteFromUid: inviteData["fromUid"] as? String,
                inviteStatus: inviteData["status"] as? String,
                inviteExpiresAt: (inviteData["expiresAt"] as? Timestamp)?.dateValue(),
                redeemingUid: me,
                alreadyFriends: false,
                currentFriendCount: friendCount
            )
            let fromUid: String
            switch validation {
            case .failure(let error):
                return .failure(Failure(message: GoDiveFriendsPresentation.redeemFailureMessage(error)))
            case .success(let uid):
                fromUid = uid
            }

            let friendshipID = GoDiveFriendInviteMapping.friendshipID(uidA: me, uidB: fromUid)
            if try await friendshipDocumentExists(friendshipID: friendshipID) {
                return .failure(Failure(message: GoDiveFriendsPresentation.redeemFailureMessage(.alreadyFriends)))
            }

            let friendship = GoDiveFriendInviteMapping.friendshipDraft(
                uidA: me,
                uidB: fromUid,
                inviteToken: normalized
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
            let profile = await fetchPublicProfile(uid: fromUid)
                ?? PublicProfileSummary(uid: fromUid, displayName: "Diver", photoURL: nil)
            log.notice("Friendship created via invite")
            GoDiveFriendGraphChangeNotification.post()
            return .success(profile)
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
                    since: (data["createdAt"] as? Timestamp)?.dateValue()
                )
            )
        }

        let profilesByUID = await fetchPublicProfiles(uid: pending.map(\.friendUID))

        let edges = pending.map { item in
            let profile = profilesByUID[item.friendUID]
            return FriendEdge(
                friendUID: item.friendUID,
                friendshipID: item.friendshipID,
                displayName: profile?.displayName ?? "Diver",
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
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return 0 }
        guard let me = Auth.auth().currentUser?.uid, !me.isEmpty else { return 0 }

        let snap = try await Firestore.firestore()
            .collection(GoDiveFriendInviteMapping.friendshipsCollection)
            .whereField("members", arrayContains: me)
            .getDocuments()
        return snap.documents.filter { doc in
            (doc.data()["status"] as? String) == GoDiveFriendInviteMapping.friendshipStatusActive
        }.count
    }

    @MainActor
    private static func friendshipDocumentExists(friendshipID: String) async throws -> Bool {
        let snap = try await Firestore.firestore()
            .collection(GoDiveFriendInviteMapping.friendshipsCollection)
            .document(friendshipID)
            .getDocument()
        guard let data = snap.data() else { return false }
        return (data["status"] as? String) == GoDiveFriendInviteMapping.friendshipStatusActive
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
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Diver"
            let photo = (data["photoURL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let heroURL = (data["profileHeroURL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let heroKind = GoDiveProfileHeroMediaKind.fromFirestoreValue(
                data["profileHeroMediaKind"] as? String
            )
            return PublicProfileSummary(
                uid: trimmed,
                displayName: name.isEmpty ? "Diver" : name,
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
