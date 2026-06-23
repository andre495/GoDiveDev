import Foundation
import SwiftData

/// A planned or completed dive vacation — date range, destinations, optional catalog sites, and linked logbook dives.
@Model
final class DiveTrip {

    var id: UUID

    /// Inclusive calendar start (normalize with **`DiveTripDateRange`** for comparisons).
    var startDate: Date
    /// Inclusive calendar end.
    var endDate: Date

    /// Destination countries (broad place labels — same vocabulary as **`DiveSite.country`**).
    var countries: [String] = []

    /// Optional user label (e.g. **Bonaire 2026**).
    var title: String?

    /// Starred linked dive media shown in the trip detail hero (**`TripDetailView`**).
    var featuredTripMediaPhotoID: UUID?

    /// Catalog sites the diver plans to visit (**optional** planning metadata).
    @Relationship(deleteRule: .nullify)
    var plannedSites: [DiveSite] = []

    /// Logbook dives associated with this trip after it happens.
    @Relationship(deleteRule: .cascade)
    var activityLinks: [DiveTripActivityLink] = []

    /// Roster buddies invited on a planned trip (before / during the trip).
    @Relationship(deleteRule: .cascade)
    var buddyLinks: [DiveTripBuddyLink] = []

    /// Denormalized for **`#Predicate`**; kept in sync with **`owner`**.
    var ownerProfileID: UUID?
    @Relationship
    var owner: UserProfile?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        countries: [String] = [],
        title: String? = nil,
        plannedSites: [DiveSite] = [],
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
        self.plannedSites = plannedSites
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
