import Foundation
import SwiftData

/// Join row associating a logbook **`DiveActivity`** with a **`DiveTrip`**.
@Model
final class DiveTripActivityLink {

    var id: UUID = UUID()

    /// Denormalized for **`#Predicate`** / batch deletes.
    var tripID: UUID?
    @Relationship(inverse: \DiveTrip.activityLinksStorage)
    var trip: DiveTrip?

    /// Denormalized for **`#Predicate`** / batch deletes.
    var diveActivityID: UUID?
    @Relationship(inverse: \DiveActivity.tripActivityLinksStorage)
    var diveActivity: DiveActivity?

    /// When the diver linked this dive to the trip.
    var linkedAt: Date = Date()

    init(
        id: UUID = UUID(),
        trip: DiveTrip,
        diveActivity: DiveActivity,
        linkedAt: Date = .now
    ) {
        self.id = id
        self.tripID = trip.id
        self.trip = trip
        self.diveActivityID = diveActivity.id
        self.diveActivity = diveActivity
        self.linkedAt = linkedAt
    }
}
