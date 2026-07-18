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
    var displayTitle: String {
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
