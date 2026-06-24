import Foundation

/// Media grid + hero for **Explore** dive-site detail (all owner dive photos at the site).
enum ExploreDiveSiteMediaPresentation: Sendable {

    @MainActor
    static func siteDiveActivities(
        diveSiteID: UUID,
        ownerProfileID: UUID?,
        activities: [DiveActivity]
    ) -> [DiveActivity] {
        guard ownerProfileID != nil else { return [] }
        return activities.filter { $0.diveSiteID == diveSiteID }
    }

    @MainActor
    static func linkedMediaItems(from siteActivities: [DiveActivity]) -> [TripDetailLinkedMediaItem] {
        TripDetailMediaPresentation.linkedMediaItems(from: siteActivities)
    }

    @MainActor
    static func mediaPhotos(
        siteActivities: [DiveActivity],
        linkedItems: [TripDetailLinkedMediaItem]
    ) -> [DiveMediaPhoto] {
        TripDetailMediaPresentation.mediaPhotos(from: siteActivities, itemIDs: linkedItems)
    }

    @MainActor
    static func timeZoneOffsetByMediaID(
        siteActivities: [DiveActivity],
        linkedItems: [TripDetailLinkedMediaItem]
    ) -> [UUID: Int?] {
        TripDetailMediaPresentation.timeZoneOffsetByMediaID(from: siteActivities, itemIDs: linkedItems)
    }

    nonisolated static func galleryRefreshToken(
        diveSiteID: UUID,
        ownerProfileID: UUID?,
        activities: [DiveActivity]
    ) -> String {
        guard ownerProfileID != nil else { return "signed-out|\(diveSiteID.uuidString)" }
        let matching = activities.filter { $0.diveSiteID == diveSiteID }
        var hasher = Hasher()
        for activity in matching.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(activity.id)
            hasher.combine(activity.mediaPhotos.count)
            for photo in activity.mediaPhotos.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                hasher.combine(photo.id)
            }
        }
        return "\(matching.count)|\(hasher.finalize())"
    }

    nonisolated static func expectsHeroMedia(siteActivities: [DiveActivity]) -> Bool {
        siteActivities.contains { !$0.mediaPhotos.isEmpty }
    }
}
