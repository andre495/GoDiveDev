import Foundation

/// Whether a dive’s free-text site name likely disagrees with a coordinate-matched catalog `DiveSite` (for future UX; not shown as a Logbook icon today).
enum DiveSiteReviewIndicator {
    /// True when GPS matches a catalog site within tolerance but the activity’s free-text `siteName`
    /// does not match that site’s canonical name (trimmed, case-insensitive). No persisted “reviewed” flag yet.
    ///
    /// **Requirements:** the store must contain **`DiveSite`** rows with **`latCoords`** / **`longCoords`** (Debug: **`MockDataSeeder`** loads **`divesites_sample`**). The activity needs a **`coordinate`** within **`DiveSiteCoordinateMatcher.toleranceDegrees`** of a catalog point. **FIT** files often omit GPS → no match. **Release** builds do not seed mock catalog unless you ship your own sites.
    static func needsReview(for activity: DiveActivity, catalogSites: [DiveSite]) -> Bool {
        guard let matched = DiveSiteCoordinateMatcher.bestMatch(for: activity.coordinate, in: catalogSites) else {
            return false
        }
        let activityName = activity.siteName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let catalogName = matched.siteName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return activityName != catalogName
    }
}
