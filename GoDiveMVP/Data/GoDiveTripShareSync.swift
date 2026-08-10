import Foundation
import os
import FirebaseAuth
import FirebaseFirestore
import SwiftData

/// Shares trips with GoDive friends via Firebase invites + owner-synced details.
enum GoDiveTripShareSync: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "TripShareSync"
    )

    enum ShareError: Error, Equatable, Sendable {
        case firebaseUnavailable
        case notSignedIn
        case notFriends
        case invalidTrip
    }

    // MARK: - Sender

    @MainActor
    static func shareTrip(
        _ trip: DiveTrip,
        withFriendUID friendUID: String,
        modelContext: ModelContext
    ) async throws {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { throw ShareError.firebaseUnavailable }
        guard let sharerUID = Auth.auth().currentUser?.uid, !sharerUID.isEmpty else {
            throw ShareError.notSignedIn
        }
        let recipientUID = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipientUID.isEmpty, recipientUID != sharerUID else { throw ShareError.invalidTrip }
        guard await GoDiveFriendGraphService.areFriends(sharerUID, recipientUID) else {
            throw ShareError.notFriends
        }

        let now = Date.now
        let sharedSnapshot = GoDiveTripShareMapping.snapshot(from: trip, now: now)
        let db = Firestore.firestore()
        let sharedRef = db.collection("users").document(sharerUID)
            .collection(GoDiveTripShareMapping.sharedTripsSubcollection)
            .document(sharedSnapshot.tripID)
        try await sharedRef.setData(
            GoDiveTripShareMapping.firestoreData(for: sharedSnapshot),
            merge: true
        )

        let inviteID = GoDiveTripShareMapping.inviteDocumentID(
            sharerUID: sharerUID,
            tripID: sharedSnapshot.tripID
        )
        let sharerName = await currentUserDisplayName()
        let invite = GoDiveTripShareMapping.InviteSnapshot(
            inviteID: inviteID,
            sharerUID: sharerUID,
            tripID: sharedSnapshot.tripID,
            status: .pending,
            title: sharedSnapshot.title ?? trip.displayTitle,
            sharerDisplayName: sharerName,
            createdAt: now,
            updatedAt: nil,
            schemaVersion: GoDiveTripShareMapping.schemaVersion
        )
        let inviteRef = db.collection("users").document(recipientUID)
            .collection(GoDiveTripShareMapping.tripShareInvitesSubcollection)
            .document(inviteID)

        // Re-invite after decline/revoke by deleting then creating (triggers push on create).
        let existing = try? await inviteRef.getDocument()
        if existing?.exists == true {
            try? await inviteRef.delete()
        }
        try await inviteRef.setData(
            GoDiveTripShareMapping.firestoreData(for: invite, includeCreatedAt: true)
        )

        DiveTripShareLineagePresentation.recordSharedWithFriend(trip, friendUID: recipientUID)
        trip.updatedAt = now
        try? modelContext.save()
        log.notice("Trip share invite created for friend")
    }

    /// Republish synced fields when the owner edits a trip that has been shared.
    @MainActor
    static func republishIfShared(
        _ trip: DiveTrip,
        modelContext: ModelContext
    ) async {
        guard !DiveTripShareLineagePresentation.isSharedInviteeCopy(trip) else { return }
        guard !trip.sharedWithFriendUIDs.isEmpty else { return }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let sharerUID = Auth.auth().currentUser?.uid, !sharerUID.isEmpty else { return }

        let snapshot = GoDiveTripShareMapping.snapshot(from: trip, now: .now)
        let ref = Firestore.firestore().collection("users").document(sharerUID)
            .collection(GoDiveTripShareMapping.sharedTripsSubcollection)
            .document(snapshot.tripID)
        do {
            try await ref.setData(
                GoDiveTripShareMapping.firestoreData(for: snapshot),
                merge: true
            )
        } catch {
            log.error("Trip share republish failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Revoke invites for friends removed from the trip (or all on trip delete).
    @MainActor
    static func revokeShares(
        for trip: DiveTrip,
        friendUIDs: [String]? = nil,
        deleteSharedTripDocument: Bool = false
    ) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let sharerUID = Auth.auth().currentUser?.uid, !sharerUID.isEmpty else { return }

        let recipients = (friendUIDs ?? trip.sharedWithFriendUIDs)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !recipients.isEmpty || deleteSharedTripDocument else { return }

        let db = Firestore.firestore()
        let tripID = trip.id.uuidString
        let now = Timestamp(date: .now)

        for recipientUID in recipients {
            let inviteID = GoDiveTripShareMapping.inviteDocumentID(
                sharerUID: sharerUID,
                tripID: tripID
            )
            let inviteRef = db.collection("users").document(recipientUID)
                .collection(GoDiveTripShareMapping.tripShareInvitesSubcollection)
                .document(inviteID)
            do {
                try await inviteRef.setData(
                    [
                        "status": GoDiveTripShareMapping.InviteStatus.revoked.rawValue,
                        "updatedAt": now,
                    ],
                    merge: true
                )
            } catch {
                log.error("Trip share revoke failed: \(error.localizedDescription, privacy: .public)")
            }
            DiveTripShareLineagePresentation.removeSharedWithFriend(trip, friendUID: recipientUID)
        }

        if deleteSharedTripDocument {
            let sharedRef = db.collection("users").document(sharerUID)
                .collection(GoDiveTripShareMapping.sharedTripsSubcollection)
                .document(tripID)
            try? await sharedRef.delete()
        }
    }

    // MARK: - Sender (outgoing acceptances)

    /// Polls invite docs for friends the owner shared with; updates local **Joined** state.
    @MainActor
    static func reconcileOutgoingAcceptances(
        owner: UserProfile,
        modelContext: ModelContext
    ) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let sharerUID = Auth.auth().currentUser?.uid, !sharerUID.isEmpty else { return }

        let ownerID = owner.id
        let trips = ((try? modelContext.fetch(FetchDescriptor<DiveTrip>())) ?? [])
            .filter {
                $0.ownerProfileID == ownerID
                    && !DiveTripShareLineagePresentation.isSharedInviteeCopy($0)
                    && !$0.sharedWithFriendUIDs.isEmpty
            }
        guard !trips.isEmpty else { return }

        var didChange = false
        for trip in trips {
            let tripID = trip.id.uuidString
            for friendUID in trip.sharedWithFriendUIDs {
                let inviteID = GoDiveTripShareMapping.inviteDocumentID(
                    sharerUID: sharerUID,
                    tripID: tripID
                )
                guard let invite = await fetchInvite(
                    recipientUID: friendUID,
                    inviteID: inviteID
                ) else { continue }
                switch invite.status {
                case .accepted:
                    if !DiveTripShareLineagePresentation.hasAcceptedFriend(trip, friendUID: friendUID) {
                        DiveTripShareLineagePresentation.recordAcceptedFriend(trip, friendUID: friendUID)
                        didChange = true
                    }
                case .declined, .revoked:
                    // Clear share/accept so the sender can tap **Invite** again.
                    if DiveTripShareLineagePresentation.hasAcceptedFriend(trip, friendUID: friendUID)
                        || DiveTripShareLineagePresentation.hasSharedWithFriend(trip, friendUID: friendUID)
                    {
                        DiveTripShareLineagePresentation.removeSharedWithFriend(trip, friendUID: friendUID)
                        didChange = true
                    }
                case .pending:
                    break
                }
            }
        }
        if didChange {
            try? modelContext.save()
        }
    }

    /// Applies accept from an FCM payload onto the sender’s local trip.
    @MainActor
    @discardableResult
    static func applyAcceptedPush(
        tripID: UUID,
        friendUID: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> Bool {
        let trips = (try? modelContext.fetch(FetchDescriptor<DiveTrip>())) ?? []
        guard let trip = trips.first(where: {
            $0.id == tripID && $0.ownerProfileID == ownerProfileID
        }) else { return false }
        DiveTripShareLineagePresentation.recordAcceptedFriend(trip, friendUID: friendUID)
        try? modelContext.save()
        return true
    }

    // MARK: - Recipient

    @MainActor
    static func reconcileIncoming(
        owner: UserProfile,
        modelContext: ModelContext
    ) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let myUID = Auth.auth().currentUser?.uid, !myUID.isEmpty else { return }

        let invites: [GoDiveTripShareMapping.InviteSnapshot]
        do {
            invites = try await fetchIncomingInvites(recipientUID: myUID)
        } catch {
            log.error("Trip share invite fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        var didChange = false
        for invite in invites {
            switch invite.status {
            case .pending, .accepted:
                guard let shared = await fetchSharedTrip(
                    sharerUID: invite.sharerUID,
                    tripID: invite.tripID
                ) else { continue }
                let result = GoDiveTripShareMaterializer.materializePending(
                    invite: invite,
                    sharedTrip: shared,
                    owner: owner,
                    modelContext: modelContext
                )
                if invite.status == .accepted,
                   let trip = fetchTrip(id: result.tripID, modelContext: modelContext) {
                    GoDiveTripShareMaterializer.markAccepted(trip)
                }
                didChange = didChange || result.created || result.updated
            case .declined, .revoked:
                if let trip = GoDiveTripShareMaterializer.existingInviteeTrip(
                    inviteID: invite.inviteID,
                    sharedTripSourceID: invite.tripID,
                    sharedFromFirebaseUID: invite.sharerUID,
                    ownerProfileID: owner.id,
                    modelContext: modelContext
                ) {
                    try? GoDiveTripShareMaterializer.deleteLocalCopy(trip, modelContext: modelContext)
                    didChange = true
                }
            }
        }

        // Apply owner sync patches for accepted/pending local copies.
        let inviteeTrips = (try? modelContext.fetch(FetchDescriptor<DiveTrip>()))?
            .filter {
                $0.ownerProfileID == owner.id
                    && DiveTripShareLineagePresentation.isSharedInviteeCopy($0)
            } ?? []
        for trip in inviteeTrips {
            guard let sharer = trip.sharedFromFirebaseUID,
                  let sourceID = trip.sharedTripSourceID,
                  let shared = await fetchSharedTrip(sharerUID: sharer, tripID: sourceID)
            else { continue }
            if GoDiveTripShareMaterializer.applySyncedFields(shared, to: trip) {
                didChange = true
            }
        }

        if didChange {
            try? modelContext.save()
            DiveTripLogbookSync.notifyGroupingDidChange()
        }
    }

    @MainActor
    static func acceptInvite(
        for trip: DiveTrip,
        ownerTrips: [DiveTrip],
        modelContext: ModelContext
    ) async throws {
        guard DiveTripShareLineagePresentation.isPendingInvite(trip) else { return }
        if let conflict = DiveTripOverlapValidation.firstOverlappingTrip(
            start: trip.startDate,
            end: trip.endDate,
            among: ownerTrips,
            excludingTripID: trip.id
        ) {
            throw AcceptError.dateOverlap(conflictTitle: conflict.displayTitle)
        }

        try await updateInviteStatus(for: trip, status: .accepted)
        GoDiveTripShareMaterializer.markAccepted(trip)
        try modelContext.save()
        DiveTripLogbookSync.notifyGroupingDidChange()
        await DiveTripReminderScheduler.reschedule(for: trip)
    }

    @MainActor
    static func declineInvite(
        for trip: DiveTrip,
        modelContext: ModelContext
    ) async throws {
        guard DiveTripShareLineagePresentation.isSharedInviteeCopy(trip) else { return }
        // Pending → declined; accepted leave → declined (rules allow both).
        try await updateInviteStatus(for: trip, status: .declined)
        try GoDiveTripShareMaterializer.deleteLocalCopy(trip, modelContext: modelContext)
    }

    enum AcceptError: Error, Equatable, Sendable {
        case dateOverlap(conflictTitle: String)
        case missingInvite
        case firebaseUnavailable
    }

    // MARK: - Fetch

    nonisolated static func fetchIncomingInvites(
        recipientUID: String
    ) async throws -> [GoDiveTripShareMapping.InviteSnapshot] {
        let snap = try await Firestore.firestore()
            .collection("users")
            .document(recipientUID)
            .collection(GoDiveTripShareMapping.tripShareInvitesSubcollection)
            .getDocuments()
        return snap.documents.compactMap { doc in
            GoDiveTripShareMapping.inviteSnapshot(inviteID: doc.documentID, data: doc.data())
        }
    }

    nonisolated static func fetchSharedTrip(
        sharerUID: String,
        tripID: String
    ) async -> GoDiveTripShareMapping.SharedTripSnapshot? {
        do {
            let snap = try await Firestore.firestore()
                .collection("users")
                .document(sharerUID)
                .collection(GoDiveTripShareMapping.sharedTripsSubcollection)
                .document(tripID)
                .getDocument()
            guard let data = snap.data() else { return nil }
            return GoDiveTripShareMapping.sharedTripSnapshot(tripID: tripID, data: data)
        } catch {
            return nil
        }
    }

    /// Ensure a pending local trip exists for a push/deep-link target; returns local trip id.
    @MainActor
    static func ensureMaterializedTrip(
        inviteID: String,
        sharerUID: String,
        tripID: String,
        owner: UserProfile,
        modelContext: ModelContext
    ) async -> UUID? {
        if let existing = GoDiveTripShareMaterializer.existingInviteeTrip(
            inviteID: inviteID,
            sharedTripSourceID: tripID,
            sharedFromFirebaseUID: sharerUID,
            ownerProfileID: owner.id,
            modelContext: modelContext
        ) {
            return existing.id
        }
        guard let shared = await fetchSharedTrip(sharerUID: sharerUID, tripID: tripID) else {
            return nil
        }
        let invite = GoDiveTripShareMapping.InviteSnapshot(
            inviteID: inviteID,
            sharerUID: sharerUID,
            tripID: tripID,
            status: .pending,
            title: shared.title,
            sharerDisplayName: nil,
            createdAt: .now,
            updatedAt: nil,
            schemaVersion: GoDiveTripShareMapping.schemaVersion
        )
        let result = GoDiveTripShareMaterializer.materializePending(
            invite: invite,
            sharedTrip: shared,
            owner: owner,
            modelContext: modelContext
        )
        try? modelContext.save()
        DiveTripLogbookSync.notifyGroupingDidChange()
        return result.tripID
    }

    // MARK: - Private

    @MainActor
    private static func updateInviteStatus(
        for trip: DiveTrip,
        status: GoDiveTripShareMapping.InviteStatus
    ) async throws {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { throw AcceptError.firebaseUnavailable }
        guard let myUID = Auth.auth().currentUser?.uid, !myUID.isEmpty else {
            throw AcceptError.firebaseUnavailable
        }
        guard let inviteID = trip.tripShareInviteID?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !inviteID.isEmpty
        else { throw AcceptError.missingInvite }

        let ref = Firestore.firestore().collection("users").document(myUID)
            .collection(GoDiveTripShareMapping.tripShareInvitesSubcollection)
            .document(inviteID)
        try await ref.setData(
            [
                "status": status.rawValue,
                "updatedAt": Timestamp(date: .now),
            ],
            merge: true
        )
    }

    @MainActor
    private static func fetchTrip(id: UUID, modelContext: ModelContext) -> DiveTrip? {
        (try? modelContext.fetch(FetchDescriptor<DiveTrip>()))?.first { $0.id == id }
    }

    nonisolated private static func fetchInvite(
        recipientUID: String,
        inviteID: String
    ) async -> GoDiveTripShareMapping.InviteSnapshot? {
        do {
            let snap = try await Firestore.firestore()
                .collection("users")
                .document(recipientUID)
                .collection(GoDiveTripShareMapping.tripShareInvitesSubcollection)
                .document(inviteID)
                .getDocument()
            guard let data = snap.data() else { return nil }
            return GoDiveTripShareMapping.inviteSnapshot(inviteID: inviteID, data: data)
        } catch {
            return nil
        }
    }

    @MainActor
    private static func currentUserDisplayName() async -> String? {
        if let cached = GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID(),
           let profile = await GoDiveFriendGraphService.fetchPublicProfile(uid: cached) {
            let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        return Auth.auth().currentUser?.displayName
    }
}

extension GoDiveFriendGraphService {
    /// Convenience for trip-share friendship gate (active edges for the signed-in user).
    static func areFriends(_ a: String, _ b: String) async -> Bool {
        guard let me = Auth.auth().currentUser?.uid, !me.isEmpty else { return false }
        let other: String
        if a == me {
            other = b
        } else if b == me {
            other = a
        } else {
            return false
        }
        let edges = (try? await listFriendEdges()) ?? []
        return edges.contains { $0.friendUID == other }
    }
}
