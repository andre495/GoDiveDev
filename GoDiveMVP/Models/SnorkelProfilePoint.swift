import Foundation
import SwiftData

/// GPS + heart-rate samples for a **`SnorkelActivity`** (local store only).
@Model
final class SnorkelProfilePoint {

    var timestamp: Date = Date()
    var latitude: Double = 0
    var longitude: Double = 0
    var heartRateBPM: Int?

    var snorkelActivityID: UUID?

    init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        heartRateBPM: Int? = nil,
        snorkelActivityID: UUID? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.heartRateBPM = heartRateBPM
        self.snorkelActivityID = snorkelActivityID
    }
}
