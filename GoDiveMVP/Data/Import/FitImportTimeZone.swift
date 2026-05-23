import Foundation
import FITSwiftSDK

/// FIT **`ActivityMesg`** local vs UTC timestamp delta for dive display timezone.
enum FitImportTimeZone {
    /// Seconds east of UTC from **`local_timestamp`** − **`timestamp`** when both are present.
    static func activityOffsetSeconds(from messages: FitMessages) -> Int? {
        guard let activity = messages.activityMesgs.first,
              let local = activity.getLocalTimestamp(),
              let utc = activity.getTimestamp()?.timestamp
        else { return nil }

        let delta = Int(local) - Int(utc)
        let maxOffset = 14 * 3600 + 3600
        guard abs(delta) <= maxOffset else { return nil }
        return delta
    }
}
