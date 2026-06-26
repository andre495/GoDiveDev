import Foundation
import SwiftData

/// Keeps denormalized ids in sync when trip ↔ dive links are created or removed.
enum DiveTripActivityLinking {

    @discardableResult
    static func link(
        _ activity: DiveActivity,
        to trip: DiveTrip,
        modelContext: ModelContext
    ) -> DiveTripActivityLink {
        unlinkFromOtherTrips(activity, except: trip.id, modelContext: modelContext)

        if let existing = trip.activityLinks.first(where: { $0.diveActivityID == activity.id }) {
            return existing
        }
        let link = DiveTripActivityLink(trip: trip, diveActivity: activity)
        modelContext.insert(link)
        trip.updatedAt = .now
        return link
    }

    /// Removes trip links on **`activity`** except the optional **`keepingTripID`** row.
    static func unlinkFromOtherTrips(
        _ activity: DiveActivity,
        except keepingTripID: UUID,
        modelContext: ModelContext
    ) {
        let foreignLinks = activity.tripActivityLinks.filter { $0.tripID != keepingTripID }
        guard !foreignLinks.isEmpty else { return }

        for link in foreignLinks {
            if let linkedTrip = link.trip {
                linkedTrip.updatedAt = .now
            }
            modelContext.delete(link)
        }
    }

    static func isLinkedToAnotherTrip(_ activity: DiveActivity, excludingTripID: UUID) -> Bool {
        activity.tripActivityLinks.contains { link in
            guard let tripID = link.tripID else { return false }
            return tripID != excludingTripID
        }
    }

    static func unlink(_ activity: DiveActivity, from trip: DiveTrip, modelContext: ModelContext) {
        let matches = trip.activityLinks.filter { $0.diveActivityID == activity.id }
        for link in matches {
            modelContext.delete(link)
        }
        if !matches.isEmpty {
            trip.updatedAt = .now
        }
    }

    /// Dives on the same owner whose local calendar day falls inside the trip window.
    static func candidateActivities(
        for trip: DiveTrip,
        activities: [DiveActivity],
        calendar: Calendar = .current
    ) -> [DiveActivity] {
        activities.filter { activity in
            guard activity.ownerProfileID == trip.ownerProfileID else { return false }
            return DiveTripDateRange.contains(
                activity.startTime,
                start: trip.startDate,
                end: trip.endDate,
                calendar: calendar
            )
        }
    }

    /// **`true`** when the trip's start calendar day is on or before **`referenceDate`**.
    nonisolated static func hasStarted(
        trip: DiveTrip,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let startDay = calendar.startOfDay(for: trip.startDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return startDay <= referenceDay
    }

    /// Links in-range owner dives once the trip has started. Idempotent; does not save.
    @discardableResult
    static func applyAutoLink(
        to trip: DiveTrip,
        activities: [DiveActivity],
        modelContext: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard hasStarted(trip: trip, referenceDate: referenceDate, calendar: calendar) else { return 0 }
        guard trip.ownerProfileID != nil else { return 0 }

        let existingIDs = Set(trip.activityLinks.compactMap(\.diveActivityID))
        let toLink = candidateActivities(for: trip, activities: activities, calendar: calendar)
            .filter { activity in
                !existingIDs.contains(activity.id)
                    && !isLinkedToAnotherTrip(activity, excludingTripID: trip.id)
            }

        for activity in toLink {
            link(activity, to: trip, modelContext: modelContext)
        }
        return toLink.count
    }

    /// Auto-links matching dives for every started trip owned by **`ownerProfileID`**.
    @discardableResult
    static func applyAutoLinkForOwner(
        ownerProfileID: UUID,
        trips: [DiveTrip],
        activities: [DiveActivity],
        modelContext: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) throws -> Int {
        var linkedCount = 0
        let sortedTrips = trips
            .filter { $0.ownerProfileID == ownerProfileID }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.createdAt < $1.createdAt
            }
        for trip in sortedTrips {
            linkedCount += applyAutoLink(
                to: trip,
                activities: activities,
                modelContext: modelContext,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        if linkedCount > 0 {
            try modelContext.save()
            DiveTripLogbookSync.notifyGroupingDidChange()
        }
        return linkedCount
    }

    /// Fetches owner trips + dives, then **`applyAutoLinkForOwner`**.
    @discardableResult
    static func applyAutoLinkForOwner(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) throws -> Int {
        let trips = try modelContext.fetch(FetchDescriptor<DiveTrip>())
            .filter { $0.ownerProfileID == ownerProfileID }
        let activities = try DiveActivityOwnership.activities(
            forOwnerProfileID: ownerProfileID,
            modelContext: modelContext
        )
        return try applyAutoLinkForOwner(
            ownerProfileID: ownerProfileID,
            trips: trips,
            activities: activities,
            modelContext: modelContext,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }
}
