import Foundation

/// Opens **`TripDetailView`** on the **media** pager with a focused gallery item.
struct TripDetailTripMediaLaunch: Hashable {
    let tripID: UUID
    let mediaID: UUID
}
