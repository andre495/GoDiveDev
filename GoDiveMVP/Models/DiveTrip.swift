import Foundation
import SwiftData

/// A planned or completed dive vacation — date range, destinations, optional planned site ids, and linked logbook dives.
@Model
final class DiveTrip {

    var id: UUID = UUID()

    /// Inclusive calendar start (normalize with **`DiveTripDateRange`** for comparisons).
    var startDate: Date = Date()
    /// Inclusive calendar end.
    var endDate: Date = Date()

    /// JSON country labels — CloudKit rejects stored `[String]` (`NSCodableAttributeType`).
    var countriesData: Data?

    /// Destination countries (broad place labels — same vocabulary as **`DiveSite.country`**).
    @Transient
    var countries: [String] {
        get { AppSwiftDataCloudKitArrayStorage.decodeStringList(countriesData) }
        set { countriesData = AppSwiftDataCloudKitArrayStorage.encodeStringList(newValue) }
    }

    /// Optional user label (e.g. **Bonaire 2026**).
    var title: String?

    /// Starred linked dive media shown in the trip detail hero (**`TripDetailView`**).
    var featuredTripMediaPhotoID: UUID?

    /// JSON planned site id strings — CloudKit rejects stored `[UUID]`.
    var plannedSiteIDsData: Data?

    /// Planned catalog / user site ids (**`DiveSite.id`** or **`UserDiveSite.id`**).
    @Transient
    var plannedSiteIDs: [UUID] {
        get { AppSwiftDataCloudKitArrayStorage.decodeUUIDList(plannedSiteIDsData) }
        set { plannedSiteIDsData = AppSwiftDataCloudKitArrayStorage.encodeUUIDList(newValue) }
    }

    /// Logbook dives associated with this trip after it happens.
    @Relationship(deleteRule: .cascade)
    var activityLinksStorage: [DiveTripActivityLink]? = []
    @Transient
    var activityLinks: [DiveTripActivityLink] {
        get { activityLinksStorage ?? [] }
        set { activityLinksStorage = newValue }
    }

    /// Roster buddies invited on a planned trip (before / during the trip).
    @Relationship(deleteRule: .cascade)
    var buddyLinksStorage: [DiveTripBuddyLink]? = []
    @Transient
    var buddyLinks: [DiveTripBuddyLink] {
        get { buddyLinksStorage ?? [] }
        set { buddyLinksStorage = newValue }
    }

    /// Denormalized for **`#Predicate`**; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    /// Firebase `sharedTrips` doc id (sender’s trip UUID string) when this row is an invitee copy.
    var sharedTripSourceID: String?
    /// Sharer Firebase UID when this row is an invitee copy.
    var sharedFromFirebaseUID: String?
    /// Incoming invite doc id under the recipient’s `tripShareInvites` collection.
    var tripShareInviteID: String?
    /// `pending` / `accepted` for invitee copies; nil for ordinary local trips.
    var tripShareStatusRaw: String?
    /// JSON list of friend Firebase UIDs the owner has shared this trip with (sender-side).
    var sharedWithFriendUIDsData: Data?
    /// JSON list of friend Firebase UIDs who accepted the share (sender-side).
    var tripShareAcceptedFriendUIDsData: Data?
    /// Last applied owner-sync fingerprint (invitee copies) to skip no-op patches.
    var tripShareSyncedFingerprint: String?

    /// Friend UIDs this owner has invited to the trip (sender-side tracking).
    @Transient
    var sharedWithFriendUIDs: [String] {
        get { AppSwiftDataCloudKitArrayStorage.decodeStringList(sharedWithFriendUIDsData) }
        set { sharedWithFriendUIDsData = AppSwiftDataCloudKitArrayStorage.encodeStringList(newValue) }
    }

    /// Friend UIDs who accepted the trip-share invite (sender-side).
    @Transient
    var tripShareAcceptedFriendUIDs: [String] {
        get { AppSwiftDataCloudKitArrayStorage.decodeStringList(tripShareAcceptedFriendUIDsData) }
        set {
            tripShareAcceptedFriendUIDsData =
                AppSwiftDataCloudKitArrayStorage.encodeStringList(newValue)
        }
    }

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        countries: [String] = [],
        title: String? = nil,
        plannedSiteIDs: [UUID] = [],
        ownerProfileID: UUID? = nil,
        owner: UserProfile? = nil,
        sharedTripSourceID: String? = nil,
        sharedFromFirebaseUID: String? = nil,
        tripShareInviteID: String? = nil,
        tripShareStatusRaw: String? = nil,
        sharedWithFriendUIDs: [String] = [],
        tripShareAcceptedFriendUIDs: [String] = [],
        tripShareSyncedFingerprint: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.countries = countries
        self.title = title
        self.plannedSiteIDs = plannedSiteIDs
        self.ownerProfileID = owner?.id ?? ownerProfileID
        self.owner = owner
        self.sharedTripSourceID = sharedTripSourceID
        self.sharedFromFirebaseUID = sharedFromFirebaseUID
        self.tripShareInviteID = tripShareInviteID
        self.tripShareStatusRaw = tripShareStatusRaw
        self.sharedWithFriendUIDs = sharedWithFriendUIDs
        self.tripShareAcceptedFriendUIDs = tripShareAcceptedFriendUIDs
        self.tripShareSyncedFingerprint = tripShareSyncedFingerprint
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension DiveTrip {

    /// Linked **`DiveActivity`** rows (materialized from join rows).
    var linkedActivities: [DiveActivity] {
        activityLinks.compactMap(\.diveActivity)
    }

    /// Resolved trip label for lists and headers.
    nonisolated var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        let countryLine = countries
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !countryLine.isEmpty {
            return countryLine.joined(separator: ", ")
        }
        return "Trip"
    }
}
