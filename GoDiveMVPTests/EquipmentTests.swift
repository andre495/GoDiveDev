//
//  EquipmentTests.swift
//  GoDiveMVPTests
//

import CloudKit
import Contacts
import AuthenticationServices
import CoreGraphics
import CoreLocation
import Foundation
import MapKit
import os
import SwiftUI
#if canImport(Photos)
import Photos
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
import SwiftData
import Testing
#if canImport(PencilKit)
import PencilKit
#endif
#if os(iOS)
import UIKit
#endif
@testable import GoDiveMVP


struct EquipmentTests {
        @Test @MainActor
        func equipmentItem_persistsFieldsAndOwner() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "apple-equipment", displayName: "Diver")
            context.insert(owner)

            let purchase = Date(timeIntervalSince1970: 1_700_000_000)
            let nextService = Date(timeIntervalSince1970: 1_900_000_000)
            let lastService = Date(timeIntervalSince1970: 1_900_000_000 - 86_400 * 365)
            let photoBytes = Data([0xFF, 0xD8, 0xFF, 0xE0])

            let item = EquipmentItem(
                manufacturer: "Apeks",
                model: "XTX50",
                type: "Regulator",
                gearType: EquipmentGearType.regulator.rawValue,
                isRetired: false,
                autoAdd: true,
                purchaseDate: purchase,
                purchasedShop: "Local Dive Shop",
                price: 899.99,
                serviceDate: lastService,
                nextServiceDate: nextService,
                serviceRecurrenceDays: 365,
                serviceNotes: "Annual overhaul",
                notes: "Primary reg",
                equipmentPhoto: photoBytes
            )
            EquipmentItemOwnership.assignOwner(owner, to: item)
            context.insert(item)
            try context.save()

            let fetched = try EquipmentItemOwnership.items(forOwnerProfileID: owner.id, modelContext: context)
            #expect(fetched.count == 1)
            let gear = try #require(fetched.first)
            #expect(gear.manufacturer == "Apeks")
            #expect(gear.model == "XTX50")
            #expect(gear.type == "Regulator")
            #expect(gear.gearType == "Regulator")
            #expect(gear.autoAdd == true)
            #expect(gear.isRetired == false)
            #expect(gear.purchasedShop == "Local Dive Shop")
            #expect(gear.price == 899.99)
            #expect(gear.nextServiceDate == nextService)
            #expect(gear.serviceRecurrenceDays == 365)
            #expect(gear.serviceDate == lastService)
            #expect(gear.serviceNotes == "Annual overhaul")
            #expect(gear.notes == "Primary reg")
            #expect(gear.equipmentPhoto == photoBytes)
            #expect(gear.ownerProfileID == owner.id)
            #expect(owner.equipmentItems.count == 1)
        }

        @Test func equipmentItemFormValues_canSave_requiresManufacturerAndModel() {
            var form = EquipmentItemFormValues()
            #expect(form.canSave == false)
            form.manufacturer = "Apeks"
            #expect(form.canSave == false)
            form.model = "XTX"
            #expect(form.canSave == true)
        }

        @Test func equipmentItemFormValues_makeEquipmentItem_mapsOptionalFields() {
            let nextService = Date(timeIntervalSince1970: 2_000_000)
            var form = EquipmentItemFormValues()
            form.manufacturer = "  Mares  "
            form.model = "Avanti"
            form.gearType = .fins
            form.isRetired = true
            form.autoAdd = true
            form.includesPurchaseDate = true
            form.purchaseDate = Date(timeIntervalSince1970: 1_000)
            form.purchasedShop = " Dive Shop "
            form.priceText = "199.50"
            form.includesRecurringService = true
            form.nextServiceDate = nextService
            form.recurrenceIntervalCount = 2
            form.recurrenceUnit = .weeks
            form.serviceNotes = " Annual "
            form.notes = " Travel fins "
            form.equipmentPhoto = Data([0x01])
            let item = form.makeEquipmentItem()
            #expect(item.manufacturer == "Mares")
            #expect(item.model == "Avanti")
            #expect(item.type == "Fins")
            #expect(item.gearType == "Fins")
            #expect(item.isRetired == true)
            #expect(item.autoAdd == true)
            #expect(item.purchaseDate == Date(timeIntervalSince1970: 1_000))
            #expect(item.purchasedShop == "Dive Shop")
            #expect(item.price == 199.5)
            #expect(item.nextServiceDate == nextService)
            #expect(item.serviceRecurrenceDays == 14)
            #expect(
                item.serviceDate == EquipmentServiceSchedule.lastServiceDate(
                    nextServiceDate: nextService,
                    recurrenceDays: 14
                )
            )
            #expect(item.serviceNotes == "Annual")
            #expect(item.notes == "Travel fins")
            #expect(item.equipmentPhoto == Data([0x01]))
            #expect(item.serviceReminderOffsetsRaw == "oneWeekPrior")
        }

        @Test func equipmentServiceReminderSchedule_encodeDecode_roundTripsAndNone() {
            #expect(EquipmentServiceReminderSchedule.encode([]) == "none")
            #expect(EquipmentServiceReminderSchedule.decode("none").isEmpty)
            #expect(EquipmentServiceReminderSchedule.decode(nil).isEmpty)
            #expect(EquipmentServiceReminderSchedule.decode("").isEmpty)

            let multi: Set<EquipmentServiceReminderOffset> = [.dayOfService, .oneMonthPrior, .oneWeekPrior]
            let encoded = EquipmentServiceReminderSchedule.encode(multi)
            #expect(encoded == "oneMonthPrior,oneWeekPrior,dayOfService")
            #expect(EquipmentServiceReminderSchedule.decode(encoded) == multi)
        }

        @Test func equipmentServiceReminderSchedule_fireDate_offsetsRelativeToServiceDay() throws {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let next = try #require(
                calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 15, minute: 30))
            )
            let now = try #require(
                calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))
            )

            let month = try #require(
                EquipmentServiceReminderSchedule.fireDate(
                    nextServiceDate: next,
                    offset: .oneMonthPrior,
                    calendar: calendar,
                    now: now
                )
            )
            #expect(calendar.component(.month, from: month) == 7)
            #expect(calendar.component(.day, from: month) == 15)
            #expect(calendar.component(.hour, from: month) == 9)

            let week = try #require(
                EquipmentServiceReminderSchedule.fireDate(
                    nextServiceDate: next,
                    offset: .oneWeekPrior,
                    calendar: calendar,
                    now: now
                )
            )
            #expect(calendar.isDate(week, inSameDayAs: try #require(calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: next)))))

            let day = try #require(
                EquipmentServiceReminderSchedule.fireDate(
                    nextServiceDate: next,
                    offset: .oneDayPrior,
                    calendar: calendar,
                    now: now
                )
            )
            #expect(calendar.isDate(day, inSameDayAs: try #require(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: next)))))

            let dayOf = try #require(
                EquipmentServiceReminderSchedule.fireDate(
                    nextServiceDate: next,
                    offset: .dayOfService,
                    calendar: calendar,
                    now: now
                )
            )
            #expect(calendar.isDate(dayOf, inSameDayAs: next))
            #expect(calendar.component(.hour, from: dayOf) == 9)

            #expect(
                EquipmentServiceReminderSchedule.fireDate(
                    nextServiceDate: next,
                    offset: .dayOfService,
                    calendar: calendar,
                    now: try #require(calendar.date(byAdding: .day, value: 1, to: next))
                ) == nil
            )
        }

        @Test func equipmentServiceReminderSchedule_notificationIdentifiers_areStablePerOffset() {
            let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            #expect(
                EquipmentServiceReminderSchedule.notificationIdentifier(equipmentID: id, offset: .oneWeekPrior)
                    == "equipment-service-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee-oneWeekPrior"
            )
            #expect(EquipmentServiceReminderSchedule.allNotificationIdentifiers(for: id).count == 4)
        }

        @Test func equipmentServiceReminderSchedule_notificationBody_matchesRequestedCopy() {
            #expect(
                EquipmentServiceReminderSchedule.notificationBody(
                    equipmentTitle: "Apeks XTX50",
                    offset: .oneMonthPrior
                ) == "Your Apeks XTX50 needs service in 1 month"
            )
            #expect(
                EquipmentServiceReminderSchedule.notificationBody(
                    equipmentTitle: "Apeks XTX50",
                    offset: .oneWeekPrior
                ) == "Your Apeks XTX50 needs service in 1 week"
            )
            #expect(
                EquipmentServiceReminderSchedule.notificationBody(
                    equipmentTitle: "Apeks XTX50",
                    offset: .oneDayPrior
                ) == "Your Apeks XTX50 needs service in 1 day"
            )
            #expect(
                EquipmentServiceReminderSchedule.notificationBody(
                    equipmentTitle: "Apeks XTX50",
                    offset: .dayOfService
                ) == "Your Apeks XTX50 needs service today"
            )
            #expect(
                EquipmentServiceReminderSchedule.notificationBody(
                    equipmentTitle: "  ",
                    offset: .oneWeekPrior
                ) == "Your gear needs service in 1 week"
            )
        }

        @Test func equipmentServiceReminderSchedule_equipmentID_fromUserInfo() {
            let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            let userInfo: [AnyHashable: Any] = [
                EquipmentServiceReminderSchedule.userInfoTypeKey:
                    EquipmentServiceReminderSchedule.userInfoTypeValue,
                EquipmentServiceReminderSchedule.userInfoEquipmentIDKey: id.uuidString,
            ]
            #expect(EquipmentServiceReminderSchedule.equipmentID(fromUserInfo: userInfo) == id)
            #expect(
                EquipmentServiceReminderSchedule.equipmentID(
                    fromUserInfo: ["type": "buddy_activity_shared"]
                ) == nil
            )
        }

        @Test @MainActor
        func equipmentServiceReminderNavigationStore_setAndConsumePending() {
            let store = EquipmentServiceReminderNavigationStore.shared
            store.clear()
            let id = UUID()
            store.setPending(equipmentID: id)
            #expect(store.pendingEquipmentID == id)
            #expect(store.consumePendingEquipmentID() == id)
            #expect(store.pendingEquipmentID == nil)
        }

        @Test func equipmentItemFormValues_defaultServiceReminders_followsGlobalGearSetting() throws {
            let suiteName = "GoDiveGearReminderDefaults-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }

            defaults.set(true, forKey: AppUserSettings.notifyGearServiceRemindersKey)
            #expect(
                EquipmentServiceReminderSchedule.defaultOffsets(userDefaults: defaults) == [.oneWeekPrior]
            )

            defaults.set(false, forKey: AppUserSettings.notifyGearServiceRemindersKey)
            #expect(EquipmentServiceReminderSchedule.defaultOffsets(userDefaults: defaults).isEmpty)

            // Empty add-form draft uses the live app defaults key (registered on → 1 week).
            let form = EquipmentItemFormValues()
            #expect(
                form.serviceReminderOffsets == EquipmentServiceReminderSchedule.defaultOffsets()
            )
        }

        @Test func equipmentItemFormValues_makeEquipmentItem_persistsMultiReminderSelection() {
            var form = EquipmentItemFormValues()
            form.manufacturer = "Apeks"
            form.model = "XTX"
            form.includesRecurringService = true
            form.nextServiceDate = Date(timeIntervalSince1970: 2_000_000)
            form.serviceReminderOffsets = [.oneMonthPrior, .oneDayPrior]
            let item = form.makeEquipmentItem()
            #expect(item.serviceReminderOffsetsRaw == "oneMonthPrior,oneDayPrior")
        }

        @Test func equipmentItemFormValues_makeEquipmentItem_persistsNoneReminders() {
            var form = EquipmentItemFormValues()
            form.manufacturer = "Apeks"
            form.model = "XTX"
            form.includesRecurringService = true
            form.setNoServiceReminders()
            let item = form.makeEquipmentItem()
            #expect(item.serviceReminderOffsetsRaw == "none")
        }

        @Test func equipmentItemFormValues_clearsRemindersWhenRecurringOff() {
            var form = EquipmentItemFormValues()
            form.manufacturer = "Apeks"
            form.model = "XTX"
            form.includesRecurringService = false
            form.serviceReminderOffsets = [.oneWeekPrior, .dayOfService]
            let item = form.makeEquipmentItem()
            #expect(item.serviceReminderOffsetsRaw == nil)
        }

        @Test func equipmentItemFormValues_initFromItem_restoresReminderOffsets() {
            let item = EquipmentItem(
                manufacturer: "Mares",
                model: "Prestige",
                type: "Fins",
                nextServiceDate: Date(timeIntervalSince1970: 2_000_000),
                serviceRecurrenceDays: 14,
                serviceReminderOffsetsRaw: "oneMonthPrior,dayOfService"
            )
            let form = EquipmentItemFormValues(from: item)
            #expect(form.serviceReminderOffsets == [.oneMonthPrior, .dayOfService])
        }

        @Test func equipmentItemPresentation_formattedServiceReminders_summarizesOrNone() {
            #expect(EquipmentItemPresentation.formattedServiceReminders(raw: nil) == "None")
            #expect(EquipmentItemPresentation.formattedServiceReminders(raw: "none") == "None")
            #expect(
                EquipmentItemPresentation.formattedServiceReminders(raw: "oneWeekPrior,dayOfService")
                    == "1 week prior, Day of service"
            )
        }

        @Test func equipmentItemFormValues_parsedPrice_emptyWhenBlank() {
            var form = EquipmentItemFormValues()
            #expect(form.parsedPrice() == nil)
            form.priceText = "12"
            #expect(form.parsedPrice() == 12)
        }

        @Test func equipmentServiceSchedule_recurrenceDays_convertsUnits() {
            #expect(EquipmentServiceSchedule.recurrenceDays(interval: 2, unit: .weeks) == 14)
            #expect(EquipmentServiceSchedule.recurrenceDays(interval: 1, unit: .years) == 365)
            #expect(EquipmentServiceSchedule.recurrenceDays(interval: 30, unit: .days) == 30)
            #expect(EquipmentServiceSchedule.recurrenceDays(interval: 0, unit: .days) == nil)
        }

        @Test func equipmentServiceSchedule_lastServiceDate_subtractsRecurrenceFromNext() {
            let next = Date(timeIntervalSince1970: 1_000_000)
            let last = EquipmentServiceSchedule.lastServiceDate(nextServiceDate: next, recurrenceDays: 14)
            #expect(last == Calendar(identifier: .gregorian).date(byAdding: .day, value: -14, to: next))
        }

        @Test func equipmentServiceSchedule_recurrenceIntervalAndUnit_roundTripsStoredDays() throws {
            #expect(try #require(EquipmentServiceSchedule.recurrenceIntervalAndUnit(forStoredDays: 365)) == (interval: 1, unit: .years))
            #expect(try #require(EquipmentServiceSchedule.recurrenceIntervalAndUnit(forStoredDays: 14)) == (interval: 2, unit: .weeks))
            #expect(try #require(EquipmentServiceSchedule.recurrenceIntervalAndUnit(forStoredDays: 10)) == (interval: 10, unit: .days))
        }

        @Test func equipmentItemFormValues_apply_updatesExistingItem() {
            let item = EquipmentItem(
                manufacturer: "Old",
                model: "Model",
                type: "BCD",
                serviceRecurrenceDays: 30
            )
            var form = EquipmentItemFormValues()
            form.manufacturer = "Scubapro"
            form.model = "MK25"
            form.gearType = .regulator
            form.includesRecurringService = true
            form.nextServiceDate = Date(timeIntervalSince1970: 3_000_000)
            form.recurrenceIntervalCount = 2
            form.recurrenceUnit = .weeks
            form.notes = "Updated"
            form.apply(to: item)
            #expect(item.manufacturer == "Scubapro")
            #expect(item.model == "MK25")
            #expect(item.gearType == "Regulator")
            #expect(item.serviceRecurrenceDays == 14)
            #expect(item.notes == "Updated")
            #expect(item.nextServiceDate == Date(timeIntervalSince1970: 3_000_000))
        }

        @Test func equipmentItemFormValues_initFromItem_restoresRecurrenceAndNextDate() {
            let next = Date(timeIntervalSince1970: 2_000_000)
            let item = EquipmentItem(
                manufacturer: "Mares",
                model: "Prestige",
                type: "Fins",
                nextServiceDate: next,
                serviceRecurrenceDays: 14
            )
            let form = EquipmentItemFormValues(from: item)
            #expect(form.manufacturer == "Mares")
            #expect(form.gearType == .fins)
            #expect(form.includesRecurringService == true)
            #expect(form.nextServiceDate == next)
            #expect(form.recurrenceIntervalCount == 2)
            #expect(form.recurrenceUnit == .weeks)
        }

        @Test func equipmentItemFormValues_makeEquipmentItem_clearsScheduleWhenRecurringOff() {
            var form = EquipmentItemFormValues()
            form.manufacturer = "Mares"
            form.model = "Avanti"
            form.includesRecurringService = false
            form.nextServiceDate = Date(timeIntervalSince1970: 2_000_000)
            form.recurrenceIntervalCount = 2
            form.recurrenceUnit = .weeks
            let item = form.makeEquipmentItem()
            #expect(item.nextServiceDate == nil)
            #expect(item.serviceDate == nil)
            #expect(item.serviceRecurrenceDays == nil)
            #expect(item.serviceReminderOffsetsRaw == nil)
        }

        @Test func equipmentItemFormValues_apply_clearsScheduleWhenRecurringOff() {
            let item = EquipmentItem(
                manufacturer: "Mares",
                model: "Avanti",
                type: "Fins",
                nextServiceDate: Date(timeIntervalSince1970: 2_000_000),
                serviceRecurrenceDays: 14,
                serviceReminderOffsetsRaw: "oneWeekPrior"
            )
            var form = EquipmentItemFormValues(from: item)
            form.includesRecurringService = false
            form.apply(to: item)
            #expect(item.nextServiceDate == nil)
            #expect(item.serviceDate == nil)
            #expect(item.serviceRecurrenceDays == nil)
            #expect(item.serviceReminderOffsetsRaw == nil)
        }

        @Test func equipmentItemPresentation_formattedRecurrence_describesInterval() {
            #expect(EquipmentItemPresentation.formattedRecurrence(days: 14) == "Every 2 weeks")
        }

        @Test func equipmentItemPresentation_addSheetAccessibilityIdentifiers() {
            #expect(EquipmentItemPresentation.addSheetCancelAccessibilityIdentifier == "EquipmentAddSheet.Cancel")
            #expect(EquipmentItemPresentation.addSheetDoneAccessibilityIdentifier == "EquipmentAddSheet.Done")
        }

        @Test func equipmentGearType_allCases_includesLockerCategories() {
            #expect(EquipmentGearType.allCases.count == 9)
            #expect(EquipmentGearType.regulator.displayName == "Regulator")
            #expect(EquipmentGearType.resolved(storedGearType: nil, legacyType: "bcd") == .bcd)
            #expect(EquipmentGearType.resolved(storedGearType: "Mask", legacyType: nil) == .mask)
        }

        @Test func equipmentItemPresentation_gearTypeLabel_usesStoredOrLegacyType() {
            let item = EquipmentItem(
                manufacturer: "Apeks",
                model: "XTX",
                type: "Octopus",
                gearType: ""
            )
            #expect(EquipmentItemPresentation.gearTypeLabel(for: item) == "Octopus")
            item.gearType = EquipmentGearType.fins.rawValue
            #expect(EquipmentItemPresentation.gearTypeLabel(for: item) == "Fins")
        }

        @Test func equipmentItemPresentation_divesUsedOnLabel_pluralizes() {
            #expect(EquipmentItemPresentation.divesUsedOnLabel(count: 0) == "Not used on any dives")
            #expect(EquipmentItemPresentation.divesUsedOnLabel(count: 1) == "1 dive")
            #expect(EquipmentItemPresentation.divesUsedOnLabel(count: 5) == "5 dives")
        }

        @Test @MainActor
        func equipmentItemDeletion_deletePermanently_removesRow() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "apple-del", displayName: "Diver")
            context.insert(owner)

            let item = EquipmentItem(manufacturer: "Apeks", model: "XTX", type: "Regulator")
            EquipmentItemOwnership.assignOwner(owner, to: item)
            context.insert(item)
            try context.save()

            try EquipmentItemDeletion.deletePermanently(item, modelContext: context)
            #expect(try EquipmentItemOwnership.items(forOwnerProfileID: owner.id, modelContext: context).isEmpty)
        }

        @Test @MainActor
        func equipmentItemOwnership_filtersByOwnerProfileID() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let a = UserProfile(appleUserIdentifier: "apple-a", displayName: "A")
            let b = UserProfile(appleUserIdentifier: "apple-b", displayName: "B")
            context.insert(a)
            context.insert(b)

            let itemA = EquipmentItem(manufacturer: "Mares", model: "Avanti", type: "Fins")
            EquipmentItemOwnership.assignOwner(a, to: itemA)
            context.insert(itemA)

            let itemB = EquipmentItem(manufacturer: "Suunto", model: "D5", type: "Computer")
            EquipmentItemOwnership.assignOwner(b, to: itemB)
            context.insert(itemB)
            try context.save()

            #expect(try EquipmentItemOwnership.items(forOwnerProfileID: a.id, modelContext: context).count == 1)
            #expect(try EquipmentItemOwnership.items(forOwnerProfileID: b.id, modelContext: context).count == 1)
            #expect(try EquipmentItemOwnership.items(forOwnerProfileID: a.id, modelContext: context).first?.model == "Avanti")
        }

        @Test @MainActor func equipmentDetailContentPagerPresentation_singleTab() {
            #expect(EquipmentDetailContentPagerPresentation.pageCount == 1)
            #expect(EquipmentDetailContentPagerPresentation.defaultPage == .details)
        }
}
