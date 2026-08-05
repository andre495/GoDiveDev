import Foundation
import os
import SwiftData
import UserNotifications

/// Schedules / cancels local **`UNNotificationRequest`**s for equipment service reminders.
enum EquipmentServiceReminderScheduler: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "EquipmentServiceReminder"
    )

    /// Snapshot used so scheduling work does not retain SwiftData models across awaits.
    struct ScheduleInput: Sendable, Equatable {
        let equipmentID: UUID
        let equipmentTitle: String
        let nextServiceDate: Date?
        let offsets: Set<EquipmentServiceReminderOffset>
        let isRetired: Bool
    }

    @MainActor
    static func scheduleInput(for item: EquipmentItem) -> ScheduleInput {
        ScheduleInput(
            equipmentID: item.id,
            equipmentTitle: EquipmentItemPresentation.title(for: item),
            nextServiceDate: item.nextServiceDate,
            offsets: EquipmentServiceReminderSchedule.decode(item.serviceReminderOffsetsRaw),
            isRetired: item.isRetired
        )
    }

    @MainActor
    static func reschedule(for item: EquipmentItem) async {
        await reschedule(scheduleInput(for: item))
    }

    @MainActor
    static func reschedule(_ input: ScheduleInput) async {
        await cancel(equipmentID: input.equipmentID)

        guard !input.isRetired,
              let nextServiceDate = input.nextServiceDate,
              !input.offsets.isEmpty
        else {
            return
        }

        let granted = await GoDiveLocalNotificationAuthorization.ensureAuthorized()
        guard granted else {
            log.notice("Equipment service reminders skipped — notification authorization not granted")
            return
        }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        for offset in EquipmentServiceReminderSchedule.sortedOffsets(input.offsets) {
            guard let fireDate = EquipmentServiceReminderSchedule.fireDate(
                nextServiceDate: nextServiceDate,
                offset: offset,
                calendar: calendar
            ) else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = EquipmentServiceReminderSchedule.notificationTitle()
            content.body = EquipmentServiceReminderSchedule.notificationBody(
                equipmentTitle: input.equipmentTitle,
                offset: offset
            )
            content.sound = .default
            content.userInfo = [
                EquipmentServiceReminderSchedule.userInfoTypeKey:
                    EquipmentServiceReminderSchedule.userInfoTypeValue,
                EquipmentServiceReminderSchedule.userInfoEquipmentIDKey:
                    input.equipmentID.uuidString,
                EquipmentServiceReminderSchedule.userInfoOffsetKey: offset.rawValue,
            ]

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: EquipmentServiceReminderSchedule.notificationIdentifier(
                    equipmentID: input.equipmentID,
                    offset: offset
                ),
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                log.error(
                    "Failed to schedule equipment service reminder: \(String(describing: error), privacy: .private)"
                )
            }
        }
    }

    @MainActor
    static func cancel(equipmentID: UUID) async {
        let identifiers = EquipmentServiceReminderSchedule.allNotificationIdentifiers(for: equipmentID)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    @MainActor
    static func resyncOwnedEquipment(ownerProfileID: UUID, modelContext: ModelContext) async {
        let ownerID = ownerProfileID
        let descriptor = FetchDescriptor<EquipmentItem>(
            predicate: #Predicate { $0.ownerProfileID == ownerID }
        )
        guard let items = try? modelContext.fetch(descriptor) else { return }
        let inputs = items.map(scheduleInput(for:))
        for input in inputs {
            await reschedule(input)
        }
    }

}
