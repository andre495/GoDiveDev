import Foundation

/// UTC **`sightingDateTime`** rules for new sightings (tag-from-media flow uses this next).
enum SightingInstanceDateTimeResolution {

    /// Media capture time wins when the user tags from **`DiveMediaPhoto`**; otherwise dive **`startTime`** (UTC).
    nonisolated static func resolvedUTCDateTime(
        diveStartTime: Date,
        mediaCapturedAt: Date?
    ) -> Date {
        if let mediaCapturedAt {
            return mediaCapturedAt
        }
        return diveStartTime
    }
}
