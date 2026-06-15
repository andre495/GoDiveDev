import Foundation
import SwiftData

/// Associates **`DiveTrip`** rows with the signed-in **`UserProfile`**.
enum DiveTripOwnership {
    static func assignOwner(_ owner: UserProfile, to trip: DiveTrip) {
        trip.owner = owner
        trip.ownerProfileID = owner.id
    }
}
