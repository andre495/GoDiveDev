import Foundation
import SwiftData

/// Join row associating a roster **`DiveBuddy`** with a planned **`DiveTrip`**.
@Model
final class DiveTripBuddyLink {

    var id: UUID

    var tripID: UUID?
    @Relationship(inverse: \DiveTrip.buddyLinks)
    var trip: DiveTrip?

    var buddyID: UUID?
    @Relationship(inverse: \DiveBuddy.tripBuddyLinks)
    var buddy: DiveBuddy?

    var addedAt: Date

    init(
        id: UUID = UUID(),
        trip: DiveTrip,
        buddy: DiveBuddy,
        addedAt: Date = .now
    ) {
        self.id = id
        self.tripID = trip.id
        self.trip = trip
        self.buddyID = buddy.id
        self.buddy = buddy
        self.addedAt = addedAt
    }
}
