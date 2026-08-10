import Foundation
import SwiftData

/// Creates / updates / deletes local `DiveTrip` rows from trip-share invites.
enum GoDiveTripShareMaterializer: Sendable {

    struct MaterializeResult: Equatable, Sendable {
        var tripID: UUID
        var created: Bool
        var updated: Bool
    }

    /// Finds an existing invitee copy for this invite / source trip.
    @MainActor
    static func existingInviteeTrip(
        inviteID: String?,
        sharedTripSourceID: String,
        sharedFromFirebaseUID: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) -> DiveTrip? {
        let trips = (try? modelContext.fetch(FetchDescriptor<DiveTrip>()))?
            .filter { $0.ownerProfileID == ownerProfileID } ?? []
        if let inviteID {
            let trimmedInvite = inviteID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedInvite.isEmpty,
               let match = trips.first(where: { $0.tripShareInviteID == trimmedInvite }) {
                return match
            }
        }
        return trips.first {
            $0.sharedTripSourceID == sharedTripSourceID
                && $0.sharedFromFirebaseUID == sharedFromFirebaseUID
                && DiveTripShareLineagePresentation.isSharedInviteeCopy($0)
        }
    }

    @MainActor
    @discardableResult
    static func materializePending(
        invite: GoDiveTripShareMapping.InviteSnapshot,
        sharedTrip: GoDiveTripShareMapping.SharedTripSnapshot,
        owner: UserProfile,
        modelContext: ModelContext
    ) -> MaterializeResult {
        // SwiftData asserts if relationships span ModelContexts (launch reconcile used a
        // fresh context + AccountSession's owner from the main context → crash loop).
        let ownerInContext = ownerInSameContext(owner, modelContext: modelContext)
        let ownerProfileID = ownerInContext?.id ?? owner.id
        let fingerprint = GoDiveTripShareMapping.syncedFieldsFingerprint(sharedTrip)
        if let existing = existingInviteeTrip(
            inviteID: invite.inviteID,
            sharedTripSourceID: sharedTrip.tripID,
            sharedFromFirebaseUID: invite.sharerUID,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        ) {
            let updated = applySyncedFields(
                sharedTrip,
                to: existing,
                fingerprint: fingerprint,
                force: existing.tripShareSyncedFingerprint == nil
            )
            existing.tripShareInviteID = invite.inviteID
            existing.sharedTripSourceID = sharedTrip.tripID
            existing.sharedFromFirebaseUID = invite.sharerUID
            if DiveTripShareLineagePresentation.status(of: existing) == nil {
                existing.tripShareStatusRaw = GoDiveTripShareMapping.InviteStatus.pending.rawValue
            }
            if let ownerInContext {
                linkSharerAsBuddyIfPossible(
                    sharerUID: invite.sharerUID,
                    sharerDisplayName: invite.sharerDisplayName,
                    trip: existing,
                    owner: ownerInContext,
                    modelContext: modelContext
                )
            }
            return MaterializeResult(tripID: existing.id, created: false, updated: updated)
        }

        let trip = DiveTrip(
            startDate: sharedTrip.startDate,
            endDate: sharedTrip.endDate,
            countries: sharedTrip.countries,
            title: sharedTrip.title,
            plannedSiteIDs: plannedSiteUUIDs(from: sharedTrip.plannedSiteIDs),
            sharedTripSourceID: sharedTrip.tripID,
            sharedFromFirebaseUID: invite.sharerUID,
            tripShareInviteID: invite.inviteID,
            tripShareStatusRaw: GoDiveTripShareMapping.InviteStatus.pending.rawValue,
            tripShareSyncedFingerprint: fingerprint,
            createdAt: .now,
            updatedAt: .now
        )
        if let ownerInContext {
            DiveTripOwnership.assignOwner(ownerInContext, to: trip)
        } else {
            trip.ownerProfileID = ownerProfileID
        }
        modelContext.insert(trip)
        if let ownerInContext {
            linkSharerAsBuddyIfPossible(
                sharerUID: invite.sharerUID,
                sharerDisplayName: invite.sharerDisplayName,
                trip: trip,
                owner: ownerInContext,
                modelContext: modelContext
            )
        }
        return MaterializeResult(tripID: trip.id, created: true, updated: true)
    }

    @MainActor
    @discardableResult
    static func applySyncedFields(
        _ sharedTrip: GoDiveTripShareMapping.SharedTripSnapshot,
        to trip: DiveTrip,
        fingerprint: String? = nil,
        force: Bool = false
    ) -> Bool {
        let nextFingerprint = fingerprint ?? GoDiveTripShareMapping.syncedFieldsFingerprint(sharedTrip)
        if !force, trip.tripShareSyncedFingerprint == nextFingerprint {
            return false
        }
        trip.title = sharedTrip.title
        trip.startDate = sharedTrip.startDate
        trip.endDate = sharedTrip.endDate
        trip.countries = sharedTrip.countries
        trip.plannedSiteIDs = plannedSiteUUIDs(from: sharedTrip.plannedSiteIDs)
        trip.tripShareSyncedFingerprint = nextFingerprint
        trip.updatedAt = .now
        return true
    }

    @MainActor
    static func markAccepted(_ trip: DiveTrip) {
        trip.tripShareStatusRaw = DiveTripShareLineagePresentation.Status.accepted.rawValue
        trip.updatedAt = .now
    }

    @MainActor
    static func deleteLocalCopy(_ trip: DiveTrip, modelContext: ModelContext) throws {
        try DiveTripDeletion.deletePermanently(trip, modelContext: modelContext)
    }

    @MainActor
    private static func linkSharerAsBuddyIfPossible(
        sharerUID: String,
        sharerDisplayName: String?,
        trip: DiveTrip,
        owner: UserProfile,
        modelContext: ModelContext
    ) {
        // Caller must pass an owner already registered in `modelContext`.
        guard owner.modelContext === modelContext else { return }
        guard trip.modelContext === modelContext || trip.modelContext == nil else { return }

        let name = sharerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (name?.isEmpty == false) ? name! : "Dive buddy"
        guard let buddy = GoDiveFriendBuddyLinking.upsertRosterBuddy(
            friendUID: sharerUID,
            displayName: displayName,
            photoURL: nil,
            owner: owner,
            modelContext: modelContext,
            persistImmediately: false
        ) else { return }
        guard buddy.modelContext === modelContext || buddy.modelContext == nil else { return }
        DiveTripPlannedBuddyLinking.addBuddy(buddy, to: trip, modelContext: modelContext)
    }

    /// Re-fetches `owner` when it belongs to a different `ModelContext`.
    @MainActor
    static func ownerInSameContext(
        _ owner: UserProfile,
        modelContext: ModelContext
    ) -> UserProfile? {
        if owner.modelContext === modelContext { return owner }
        let ownerID = owner.id
        return (try? modelContext.fetch(
            FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.id == ownerID }
            )
        ))?.first
    }

    nonisolated private static func plannedSiteUUIDs(from rawIDs: [String]) -> [UUID] {
        rawIDs.compactMap { UUID(uuidString: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}
