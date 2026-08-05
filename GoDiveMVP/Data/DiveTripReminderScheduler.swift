import Foundation
import os
import SwiftData
import UserNotifications

/// Schedules / cancels local **`UNNotificationRequest`**s for upcoming trip reminders.
enum DiveTripReminderScheduler: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "DiveTripReminder"
    )

    struct ScheduleInput: Sendable, Equatable {
        let tripID: UUID
        let destinationLabel: String?
        let startDate: Date
    }

    @MainActor
    static func scheduleInput(for trip: DiveTrip) -> ScheduleInput {
        ScheduleInput(
            tripID: trip.id,
            destinationLabel: DiveTripReminderSchedule.destinationLabel(
                countries: trip.countries,
                title: trip.title
            ),
            startDate: trip.startDate
        )
    }

    @MainActor
    static func reschedule(for trip: DiveTrip) async {
        await reschedule(scheduleInput(for: trip))
    }

    @MainActor
    static func reschedule(_ input: ScheduleInput) async {
        await cancel(tripID: input.tripID)

        guard AppUserSettings.notifyTripReminders() else { return }

        let granted = await GoDiveLocalNotificationAuthorization.ensureAuthorized()
        guard granted else {
            log.notice("Trip reminders skipped — notification authorization not granted")
            return
        }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        for offset in DiveTripReminderSchedule.fixedOffsets {
            guard let fireDate = DiveTripReminderSchedule.fireDate(
                tripStartDate: input.startDate,
                offset: offset,
                calendar: calendar
            ) else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = DiveTripReminderSchedule.notificationTitle()
            content.body = DiveTripReminderSchedule.notificationBody(
                destinationLabel: input.destinationLabel,
                offset: offset
            )
            content.sound = .default
            content.userInfo = [
                DiveTripReminderSchedule.userInfoTypeKey: DiveTripReminderSchedule.userInfoTypeValue,
                DiveTripReminderSchedule.userInfoTripIDKey: input.tripID.uuidString,
                DiveTripReminderSchedule.userInfoOffsetKey: offset.rawValue,
            ]

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: DiveTripReminderSchedule.notificationIdentifier(
                    tripID: input.tripID,
                    offset: offset
                ),
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                log.error(
                    "Failed to schedule trip reminder: \(String(describing: error), privacy: .private)"
                )
            }
        }
    }

    @MainActor
    static func cancel(tripID: UUID) async {
        let identifiers = DiveTripReminderSchedule.allNotificationIdentifiers(for: tripID)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    @MainActor
    static func resyncOwnedTrips(ownerProfileID: UUID, modelContext: ModelContext) async {
        let ownerID = ownerProfileID
        let descriptor = FetchDescriptor<DiveTrip>(
            predicate: #Predicate { $0.ownerProfileID == ownerID }
        )
        guard let trips = try? modelContext.fetch(descriptor) else { return }
        let inputs = trips.map(scheduleInput(for:))
        for input in inputs {
            await reschedule(input)
        }
    }
}
