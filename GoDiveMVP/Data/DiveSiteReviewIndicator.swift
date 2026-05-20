import Foundation

/// Whether a dive’s free-text site name likely disagrees with a coordinate-matched catalog `DiveSite` (for future UX; not shown as a Logbook icon today).
enum DiveSiteReviewIndicator {
    /// True when GPS matches a catalog site within tolerance but the activity’s free-text `siteName`
    /// does not match that site’s canonical name (trimmed, case-insensitive). No persisted “reviewed” flag yet.
    ///
    /// **Requirements:** the store must contain **`DiveSite`** rows with **`latCoords`** / **`longCoords`** (optional: enable **`MockDataSeeding.isLaunchSeedingEnabled`** to load **`divesites_sample`**). The activity needs a **`coordinate`** within **`DiveSiteCoordinateMatcher.toleranceDegrees`** of a catalog point. **FIT** files often omit GPS → no match.
    static func needsReview(for activity: DiveActivity, catalogSites: [DiveSite]) -> Bool {
        let catalogNameSource: DiveSite? = activity.diveSite
            ?? DiveSiteCoordinateMatcher.bestMatch(for: activity.entryCoordinate, in: catalogSites)
        guard let matched = catalogNameSource else { return false }
        let activityName = activity.siteName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let catalogName = matched.siteName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return activityName != catalogName
    }
}
