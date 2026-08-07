import SwiftData
import SwiftUI

/// Zero-size host for a live owner-scoped dive `@Query`.
///
/// Mount only while a root tab is selected so idle tabs do not observe every dive row.
struct OwnerDiveActivitiesQueryBridge: View {
    let onActivitiesChange: ([DiveActivity]) -> Void

    @Query private var activities: [DiveActivity]

    init(
        ownerProfileID: UUID?,
        onActivitiesChange: @escaping ([DiveActivity]) -> Void
    ) {
        self.onActivitiesChange = onActivitiesChange
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _activities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var syncToken: Int {
        var hasher = Hasher()
        hasher.combine(activities.count)
        for activity in activities {
            hasher.combine(activity.id)
            hasher.combine(activity.diveSiteID)
            hasher.combine(activity.startTime.timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: syncToken) {
                onActivitiesChange(activities)
            }
    }
}

/// Zero-size host for live owner-scoped dive + snorkel `@Query`s (Logbook).
struct OwnerActivityLogQueryBridge: View {
    let onActivitiesChange: ([DiveActivity], [SnorkelActivity]) -> Void

    @Query private var diveActivities: [DiveActivity]
    @Query private var snorkelActivities: [SnorkelActivity]

    init(
        ownerProfileID: UUID?,
        onActivitiesChange: @escaping ([DiveActivity], [SnorkelActivity]) -> Void
    ) {
        self.onActivitiesChange = onActivitiesChange
        let filterOwnerID = ownerProfileID ?? Self.noOwnerQueryToken
        _diveActivities = Query(
            filter: #Predicate<DiveActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\DiveActivity.startTime, order: .reverse),
                SortDescriptor(\DiveActivity.id, order: .forward),
            ]
        )
        _snorkelActivities = Query(
            filter: #Predicate<SnorkelActivity> { $0.ownerProfileID == filterOwnerID },
            sort: [
                SortDescriptor(\SnorkelActivity.startTime, order: .reverse),
                SortDescriptor(\SnorkelActivity.id, order: .forward),
            ]
        )
    }

    private static let noOwnerQueryToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var syncToken: Int {
        var hasher = Hasher()
        hasher.combine(diveActivities.count)
        hasher.combine(snorkelActivities.count)
        for activity in diveActivities {
            hasher.combine(activity.id)
            hasher.combine(activity.diveSiteID)
            hasher.combine(activity.startTime.timeIntervalSinceReferenceDate)
        }
        for activity in snorkelActivities {
            hasher.combine(activity.id)
            hasher.combine(activity.startTime.timeIntervalSinceReferenceDate)
        }
        return hasher.finalize()
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: syncToken) {
                onActivitiesChange(diveActivities, snorkelActivities)
            }
    }
}
