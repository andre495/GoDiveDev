//
//  GoDiveMVPTests.swift
//  GoDiveMVPTests
//
//  Created by André Dugas on 4/1/26.
//

import CoreGraphics
import CoreLocation
import Foundation
import SwiftData
import Testing
#if os(iOS)
import UIKit
#endif
@testable import GoDiveMVP

struct GoDiveMVPTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func diveActivityDiveNumbering_partialRenumberNoop_whenDeletingNewest() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let b = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        #expect(
            DiveActivityDiveNumbering.partialRenumberAfterDeleteWouldBeNoop(
                remaining: [a],
                deletedStartTime: t1,
                deletedId: b.id
            )
        )
    }

    @Test func diveActivityDiveNumbering_partialRenumberNoop_whenTailAlreadyMatches() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let t2 = Date(timeIntervalSince1970: 172_800)
        let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let c = DiveActivity(deviceSource: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        let deletedMid = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        #expect(
            DiveActivityDiveNumbering.partialRenumberAfterDeleteWouldBeNoop(
                remaining: [a, c],
                deletedStartTime: t1,
                deletedId: deletedMid.id
            )
        )
    }

    @Test func diveActivityDiveNumbering_partialRenumberWouldRun_whenTailHasGap() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let t2 = Date(timeIntervalSince1970: 172_800)
        let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let c = DiveActivity(deviceSource: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
        let deletedMid = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        #expect(
            DiveActivityDiveNumbering.partialRenumberAfterDeleteWouldBeNoop(
                remaining: [a, c],
                deletedStartTime: t1,
                deletedId: deletedMid.id
            ) == false
        )
    }

    @Test func diveActivityDiveNumbering_partialRenumberWouldRun_whenNilInTail() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let c = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
        let deleted = DiveActivity(deviceSource: .manual, startTime: Date(timeIntervalSince1970: -10_000), durationMinutes: 1, maxDepthMeters: 1)
        #expect(
            DiveActivityDiveNumbering.partialRenumberAfterDeleteWouldBeNoop(
                remaining: [a, c],
                deletedStartTime: deleted.startTime,
                deletedId: deleted.id
            ) == false
        )
    }

    @Test func logbookDiveOrdering_newestStartTimeFirstThenId() {
        let t = Date(timeIntervalSince1970: 1_000_000)
        let newest = DiveActivity(deviceSource: .manual, startTime: t.addingTimeInterval(100), durationMinutes: 1, maxDepthMeters: 1)
        let older = DiveActivity(deviceSource: .manual, startTime: t, durationMinutes: 1, maxDepthMeters: 1)
        let sameTimeA = DiveActivity(deviceSource: .manual, startTime: t, durationMinutes: 1, maxDepthMeters: 1)
        let sameTimeB = DiveActivity(deviceSource: .manual, startTime: t, durationMinutes: 1, maxDepthMeters: 1)

        let sorted = [older, newest, sameTimeB, sameTimeA].sorted {
            if $0.startTime != $1.startTime {
                return $0.startTime > $1.startTime
            }
            return $0.id.uuidString < $1.id.uuidString
        }

        #expect(sorted[0].id == newest.id)
        #expect(sorted[1].startTime == t)
        #expect(sorted[2].startTime == t)
        #expect(sorted[3].startTime == t)
        #expect(sorted[1].id.uuidString < sorted[2].id.uuidString)
        #expect(sorted[2].id.uuidString < sorted[3].id.uuidString)
    }

    @Test func mockDataSeeding_launchSeedingDisabledByDefault() {
        #expect(!MockDataSeeding.isLaunchSeedingEnabled)
    }

    @Test func userProfileStore_displayNameFromPersonNameComponents() {
        var components = PersonNameComponents()
        components.givenName = "Alex"
        components.familyName = "Diver"
        #expect(UserProfileStore.displayName(from: components) == "Alex Diver")
        #expect(UserProfileStore.displayName(from: nil) == nil)

        var givenOnly = PersonNameComponents()
        givenOnly.givenName = "Jamie"
        #expect(UserProfileStore.displayName(from: givenOnly) == "Jamie")
    }

    @Test func userProfileStore_cachedDisplayName_roundTrips() {
        let appleID = "apple-cache-test-\(UUID().uuidString)"
        defer { UserProfileStore.cacheDisplayName(nil, forAppleUserIdentifier: appleID) }

        #expect(UserProfileStore.cachedDisplayName(forAppleUserIdentifier: appleID) == nil)
        UserProfileStore.cacheDisplayName("Casey", forAppleUserIdentifier: appleID)
        #expect(UserProfileStore.cachedDisplayName(forAppleUserIdentifier: appleID) == "Casey")
        #expect(
            UserProfileStore.resolvedDisplayName(appleProvided: nil, appleUserIdentifier: appleID) == "Casey"
        )
        #expect(
            UserProfileStore.resolvedDisplayName(appleProvided: "Fresh", appleUserIdentifier: appleID) == "Fresh"
        )
    }

    @Test @MainActor
    func userProfileStore_applyCachedDisplayNameIfNeeded_upgradesPlaceholder() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let appleID = "apple-cache-upgrade-\(UUID().uuidString)"
        defer { UserProfileStore.cacheDisplayName(nil, forAppleUserIdentifier: appleID) }

        UserProfileStore.cacheDisplayName("Riley", forAppleUserIdentifier: appleID)
        let profile = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: appleID,
            displayName: nil,
            modelContext: context
        )
        #expect(profile.displayName == UserProfileStore.defaultDisplayName)

        try UserProfileStore.applyCachedDisplayNameIfNeeded(to: profile, modelContext: context)
        #expect(profile.displayName == "Riley")
    }

    @Test func profilePresentation_diveActivityCountLabel_pluralizes() {
        #expect(ProfilePresentation.diveActivityCountLabel(0) == "No dives logged")
        #expect(ProfilePresentation.diveActivityCountLabel(1) == "1 dive")
        #expect(ProfilePresentation.diveActivityCountLabel(12) == "12 dives")
    }

    @Test func profilePhotoCropRenderer_baseFillScale_coversViewport() {
        let imageSize = CGSize(width: 800, height: 600)
        let cropDiameter: CGFloat = 280
        let scale = ProfilePhotoCropRenderer.baseFillScale(
            imageSize: imageSize,
            cropDiameter: cropDiameter
        )
        // Must use CGFloat division — `280 / 600` (Int) is 0.
        let expectedScale = CGFloat(280) / CGFloat(600)
        #expect(scale == expectedScale)
        #expect(expectedScale > 0)
    }

    @Test func profilePhotoCropRenderer_croppedJPEGData_returnsBytes() {
        #if canImport(UIKit)
        let size = CGSize(width: 200, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let data = ProfilePhotoCropRenderer.croppedJPEGData(
            from: image,
            cropDiameter: 280,
            gestureScale: 1,
            offset: .zero
        )
        #expect(data != nil)
        #expect(data?.isEmpty == false)
        #else
        #expect(Bool(true))
        #endif
    }

    @Test @MainActor
    func userProfile_persistsProfilePhoto() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let photo = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let profile = UserProfile(
            appleUserIdentifier: "apple-photo",
            displayName: "Diver",
            profilePhoto: photo
        )
        context.insert(profile)
        try context.save()

        let fetched = try UserProfileStore.profile(id: profile.id, modelContext: context)
        let stored = try #require(fetched)
        #expect(stored.profilePhoto == photo)

        stored.profilePhoto = nil
        try context.save()
        let clearedFetched = try UserProfileStore.profile(id: profile.id, modelContext: context)
        let cleared = try #require(clearedFetched)
        #expect(cleared.profilePhoto == nil)
    }

    @Test @MainActor
    func userProfileStore_findOrCreateProfile_reusesAppleUser() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let first = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: "apple-user-1",
            displayName: "Casey",
            modelContext: context
        )
        let second = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: "apple-user-1",
            displayName: "Ignored",
            modelContext: context
        )

        #expect(first.id == second.id)
        #expect(second.displayName == "Casey")
        #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
    }

    @Test @MainActor
    func userProfileStore_findOrCreateProfile_upgradesDefaultDisplayName() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let first = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: "apple-user-2",
            displayName: nil,
            modelContext: context
        )
        #expect(first.displayName == UserProfileStore.defaultDisplayName)

        let second = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: "apple-user-2",
            displayName: "Casey",
            modelContext: context
        )

        #expect(first.id == second.id)
        #expect(second.displayName == "Casey")
    }

    @Test @MainActor
    func diveActivityOwnership_assignOwnerAndClaimUnowned() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-1", displayName: "Owner")
        context.insert(owner)

        let unowned = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 1,
            maxDepthMeters: 1
        )
        context.insert(unowned)
        try context.save()

        try DiveActivityOwnership.claimUnownedDives(for: owner, modelContext: context)

        #expect(unowned.ownerProfileID == owner.id)
        #expect(unowned.owner?.id == owner.id)
        let owned = try DiveActivityOwnership.activities(forOwnerProfileID: owner.id, modelContext: context)
        #expect(owned.count == 1)
    }

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
        form.type = "Fins"
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
        form.type = "Regulator"
        form.includesRecurringService = true
        form.nextServiceDate = Date(timeIntervalSince1970: 3_000_000)
        form.recurrenceIntervalCount = 2
        form.recurrenceUnit = .weeks
        form.notes = "Updated"
        form.apply(to: item)
        #expect(item.manufacturer == "Scubapro")
        #expect(item.model == "MK25")
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
    }

    @Test func equipmentItemFormValues_apply_clearsScheduleWhenRecurringOff() {
        let item = EquipmentItem(
            manufacturer: "Mares",
            model: "Avanti",
            type: "Fins",
            nextServiceDate: Date(timeIntervalSince1970: 2_000_000),
            serviceRecurrenceDays: 14
        )
        var form = EquipmentItemFormValues(from: item)
        form.includesRecurringService = false
        form.apply(to: item)
        #expect(item.nextServiceDate == nil)
        #expect(item.serviceDate == nil)
        #expect(item.serviceRecurrenceDays == nil)
    }

    @Test func equipmentItemPresentation_formattedRecurrence_describesInterval() {
        #expect(EquipmentItemPresentation.formattedRecurrence(days: 14) == "Every 2 weeks")
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

    @Test @MainActor
    func diveActivityEquipmentAssociation_link_syncsListAndDivesUsedOn() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-gear-link", displayName: "Diver")
        context.insert(owner)

        let gear = EquipmentItem(manufacturer: "Apeks", model: "XTX", type: "Regulator")
        EquipmentItemOwnership.assignOwner(owner, to: gear)
        context.insert(gear)

        let dive = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 42,
            maxDepthMeters: 22
        )
        DiveActivityOwnership.assignOwner(owner, to: dive)
        context.insert(dive)
        try context.save()

        try DiveActivityEquipmentAssociation.link(gear, to: dive, modelContext: context)
        try context.save()

        #expect(dive.equipmentList != nil)
        #expect(dive.equipmentItemIDs == [gear.id])
        #expect(gear.divesUsedOn == [dive.id])
        #expect(gear.diveEquipmentEntries.count == 1)
        #expect(gear.diveEquipmentEntries.first?.diveActivityID == dive.id)

        try DiveActivityEquipmentAssociation.link(gear, to: dive, modelContext: context)
        #expect(dive.equipmentItemIDs.count == 1)
    }

    @Test @MainActor
    func diveActivityEquipmentAssociation_applyAutoAdd_respectsFlags() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-auto-add", displayName: "Diver")
        context.insert(owner)

        let autoItem = EquipmentItem(
            manufacturer: "Suunto",
            model: "D5",
            type: "Computer",
            autoAdd: true
        )
        let retiredAuto = EquipmentItem(
            manufacturer: "Mares",
            model: "Avanti",
            type: "Fins",
            isRetired: true,
            autoAdd: true
        )
        let manualItem = EquipmentItem(manufacturer: "Apeks", model: "XTX", type: "Regulator", autoAdd: false)
        for item in [autoItem, retiredAuto, manualItem] {
            EquipmentItemOwnership.assignOwner(owner, to: item)
            context.insert(item)
        }

        let dive = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(timeIntervalSince1970: 1_700_000_100),
            durationMinutes: 40,
            maxDepthMeters: 20
        )
        DiveActivityOwnership.assignOwner(owner, to: dive)
        context.insert(dive)
        try context.save()

        try DiveActivityEquipmentAssociation.applyAutoAdd(
            to: dive,
            ownerProfileID: owner.id,
            modelContext: context
        )
        try context.save()

        #expect(dive.equipmentItemIDs == [autoItem.id])
        #expect(autoItem.divesUsedOn == [dive.id])
        #expect(retiredAuto.divesUsedOn.isEmpty)
        #expect(manualItem.divesUsedOn.isEmpty)
    }

    @Test @MainActor
    func diveActivityEquipmentAssociation_diveDelete_clearsDivesUsedOn() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-dive-del", displayName: "Diver")
        context.insert(owner)

        let gear = EquipmentItem(manufacturer: "Apeks", model: "XTX", type: "Regulator", autoAdd: true)
        EquipmentItemOwnership.assignOwner(owner, to: gear)
        context.insert(gear)

        let dive = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(timeIntervalSince1970: 1_700_000_200),
            durationMinutes: 38,
            maxDepthMeters: 18
        )
        DiveActivityOwnership.assignOwner(owner, to: dive)
        context.insert(dive)
        try DiveActivityEquipmentAssociation.link(gear, to: dive, modelContext: context)
        try context.save()
        #expect(gear.divesUsedOn == [dive.id])

        context.delete(dive)
        try context.save()

        #expect(gear.divesUsedOn.isEmpty)
    }

    @Test @MainActor
    func diveActivityEquipmentAssociation_addableEquipment_omitsRetiredAndLinked() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-addable", displayName: "Diver")
        context.insert(owner)

        let linked = EquipmentItem(manufacturer: "Apeks", model: "XTX", type: "Regulator")
        let retired = EquipmentItem(
            manufacturer: "Mares",
            model: "Old",
            type: "BCD",
            isRetired: true
        )
        let available = EquipmentItem(manufacturer: "Suunto", model: "D5", type: "Computer")
        for item in [linked, retired, available] {
            EquipmentItemOwnership.assignOwner(owner, to: item)
            context.insert(item)
        }

        let dive = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(timeIntervalSince1970: 1_700_000_400),
            durationMinutes: 35,
            maxDepthMeters: 15
        )
        DiveActivityOwnership.assignOwner(owner, to: dive)
        context.insert(dive)
        try DiveActivityEquipmentAssociation.link(linked, to: dive, modelContext: context)
        try context.save()

        let addable = try DiveActivityEquipmentAssociation.addableEquipment(
            for: dive,
            ownerProfileID: owner.id,
            modelContext: context
        )
        #expect(addable.count == 1)
        #expect(addable.first?.id == available.id)

        let onDive = try DiveActivityEquipmentAssociation.linkedEquipment(on: dive, modelContext: context)
        #expect(onDive.map(\.id) == [linked.id])
    }

    @Test @MainActor
    func diveActivityEquipmentAssociation_unlinkAll_clearsEntries() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-gear-del", displayName: "Diver")
        context.insert(owner)

        let gear = EquipmentItem(manufacturer: "Apeks", model: "XTX", type: "Regulator")
        EquipmentItemOwnership.assignOwner(owner, to: gear)
        context.insert(gear)

        let dive = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(timeIntervalSince1970: 1_700_000_300),
            durationMinutes: 36,
            maxDepthMeters: 16
        )
        DiveActivityOwnership.assignOwner(owner, to: dive)
        context.insert(dive)
        try DiveActivityEquipmentAssociation.link(gear, to: dive, modelContext: context)
        try context.save()

        try DiveActivityEquipmentAssociation.unlinkAll(from: gear, modelContext: context)
        try context.save()

        #expect(gear.divesUsedOn.isEmpty)
        #expect(gear.diveEquipmentEntries.isEmpty)
        #expect(dive.equipmentItemIDs.isEmpty)
    }

    @Test @MainActor
    func certification_persistsFieldsAndOwner() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-cert", displayName: "Diver")
        context.insert(owner)

        let attained = Date(timeIntervalSince1970: 1_600_000_000)
        let frontBytes = Data([0xFF, 0xD8, 0x01])
        let backBytes = Data([0xFF, 0xD8, 0x02])

        let cert = Certification(
            agency: "PADI",
            certName: "Rescue Diver",
            certNumber: "OW-12345",
            dateAttained: attained,
            instructor: "Jane Smith",
            instructorNumber: "INS-99",
            diveShop: "Blue Water Dive Center",
            isPrimaryCert: true,
            certFrontPicture: frontBytes,
            certBackPicture: backBytes
        )
        CertificationOwnership.assignOwner(owner, to: cert)
        context.insert(cert)
        try context.save()

        let fetched = try CertificationOwnership.items(forOwnerProfileID: owner.id, modelContext: context)
        #expect(fetched.count == 1)
        let card = try #require(fetched.first)
        #expect(card.agency == "PADI")
        #expect(card.certName == "Rescue Diver")
        #expect(card.certNumber == "OW-12345")
        #expect(card.dateAttained == attained)
        #expect(card.instructor == "Jane Smith")
        #expect(card.instructorNumber == "INS-99")
        #expect(card.diveShop == "Blue Water Dive Center")
        #expect(card.isPrimaryCert == true)
        #expect(card.certFrontPicture == frontBytes)
        #expect(card.certBackPicture == backBytes)
        #expect(card.ownerProfileID == owner.id)
        #expect(owner.certifications.count == 1)
    }

    @Test @MainActor
    func certificationOwnership_setAsPrimary_clearsOtherPrimaries() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-cert-primary", displayName: "Diver")
        context.insert(owner)

        let first = Certification(agency: "PADI", certNumber: "1", isPrimaryCert: true)
        let second = Certification(agency: "NAUI", certNumber: "2", isPrimaryCert: false)
        CertificationOwnership.assignOwner(owner, to: first)
        CertificationOwnership.assignOwner(owner, to: second)
        context.insert(first)
        context.insert(second)
        try context.save()

        try CertificationOwnership.setAsPrimary(second, ownerProfileID: owner.id, modelContext: context)

        #expect(first.isPrimaryCert == false)
        #expect(second.isPrimaryCert == true)
        let primary = try CertificationOwnership.primaryCertification(forOwnerProfileID: owner.id, modelContext: context)
        #expect(primary?.id == second.id)
    }

    @Test @MainActor
    func certificationDeletion_deletePermanently_removesRow() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "apple-cert-del", displayName: "Diver")
        context.insert(owner)

        let cert = Certification(agency: "SSI", certNumber: "ADV-1")
        CertificationOwnership.assignOwner(owner, to: cert)
        context.insert(cert)
        try context.save()

        try CertificationDeletion.deletePermanently(cert, modelContext: context)
        #expect(try CertificationOwnership.items(forOwnerProfileID: owner.id, modelContext: context).isEmpty)
    }

    @Test @MainActor
    func certificationOwnership_filtersByOwnerProfileID() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let a = UserProfile(appleUserIdentifier: "apple-cert-a", displayName: "A")
        let b = UserProfile(appleUserIdentifier: "apple-cert-b", displayName: "B")
        context.insert(a)
        context.insert(b)

        let certA = Certification(agency: "PADI", certNumber: "A-1")
        CertificationOwnership.assignOwner(a, to: certA)
        context.insert(certA)

        let certB = Certification(agency: "NAUI", certNumber: "B-1")
        CertificationOwnership.assignOwner(b, to: certB)
        context.insert(certB)
        try context.save()

        #expect(try CertificationOwnership.items(forOwnerProfileID: a.id, modelContext: context).count == 1)
        #expect(try CertificationOwnership.items(forOwnerProfileID: b.id, modelContext: context).count == 1)
        #expect(try CertificationOwnership.items(forOwnerProfileID: a.id, modelContext: context).first?.agency == "PADI")
    }

    @Test func certificationFormValues_canSave_requiresNameAgencyAndCertNumber() {
        var form = CertificationFormValues()
        #expect(form.canSave == false)
        form.certName = "Rescue Diver"
        #expect(form.canSave == false)
        form.agency = "PADI"
        #expect(form.canSave == false)
        form.certNumber = "OW-1"
        #expect(form.canSave == true)
    }

    @Test func certificationFormValues_makeCertification_mapsOptionalFields() {
        let attained = Date(timeIntervalSince1970: 1_500_000)
        var form = CertificationFormValues()
        form.agency = "  NAUI  "
        form.certName = "  Advanced Open Water  "
        form.certNumber = " ADV-99 "
        form.dateAttained = attained
        form.instructor = " Pat "
        form.instructorNumber = " INS-1 "
        form.diveShop = " Reef Shop "
        form.isPrimaryCert = true
        form.certFrontPicture = Data([0x01])
        form.certBackPicture = Data([0x02])
        let cert = form.makeCertification()
        #expect(cert.agency == "NAUI")
        #expect(cert.certName == "Advanced Open Water")
        #expect(cert.certNumber == "ADV-99")
        #expect(cert.dateAttained == attained)
        #expect(cert.instructor == "Pat")
        #expect(cert.instructorNumber == "INS-1")
        #expect(cert.diveShop == "Reef Shop")
        #expect(cert.isPrimaryCert == true)
        #expect(cert.certFrontPicture == Data([0x01]))
        #expect(cert.certBackPicture == Data([0x02]))
    }

    @Test func certificationFormValues_apply_updatesExistingCertification() {
        let cert = Certification(agency: "Old", certNumber: "1", isPrimaryCert: false)
        var form = CertificationFormValues()
        form.agency = "SSI"
        form.certName = "Divemaster"
        form.certNumber = "DM-2"
        form.diveShop = ""
        form.isPrimaryCert = true
        form.apply(to: cert)
        #expect(cert.agency == "SSI")
        #expect(cert.certName == "Divemaster")
        #expect(cert.certNumber == "DM-2")
        #expect(cert.diveShop == nil)
        #expect(cert.isPrimaryCert == true)
    }

    @Test func certificationFormValues_initFromCertification_restoresFields() {
        let attained = Date(timeIntervalSince1970: 2_000_000)
        let cert = Certification(
            agency: "PADI",
            certName: "Open Water",
            certNumber: "OW-1",
            dateAttained: attained,
            instructor: "Alex",
            instructorNumber: "99",
            diveShop: "Blue Shop",
            isPrimaryCert: true,
            certFrontPicture: Data([0xAA])
        )
        let form = CertificationFormValues(from: cert)
        #expect(form.agency == "PADI")
        #expect(form.certName == "Open Water")
        #expect(form.certNumber == "OW-1")
        #expect(form.dateAttained == attained)
        #expect(form.instructor == "Alex")
        #expect(form.diveShop == "Blue Shop")
        #expect(form.isPrimaryCert == true)
        #expect(form.certFrontPicture == Data([0xAA]))
    }

    @Test func certificationPresentation_title_prefersCertName() {
        let cert = Certification(agency: "PADI", certName: "Rescue Diver", certNumber: "123")
        #expect(CertificationPresentation.title(for: cert) == "Rescue Diver")
    }

    @Test func certificationPresentation_title_fallsBackToAgencyAndNumber() {
        let cert = Certification(agency: "PADI", certNumber: "123")
        #expect(CertificationPresentation.title(for: cert) == "PADI · 123")
    }

    @Test func certificationPresentation_profileSubtitle_usesNewestPrimaryCertName() {
        let older = Certification(
            agency: "PADI",
            certName: "Open Water",
            certNumber: "1",
            dateAttained: Date(timeIntervalSince1970: 1_000),
            isPrimaryCert: true
        )
        let newer = Certification(
            agency: "PADI",
            certName: "Rescue Diver",
            certNumber: "2",
            dateAttained: Date(timeIntervalSince1970: 2_000),
            isPrimaryCert: true
        )
        let subtitle = CertificationPresentation.profileCertificationSubtitle(from: [older, newer])
        #expect(subtitle == "Rescue Diver")
    }

    @Test func certificationPresentation_profileSubtitle_defaultsWithoutPrimary() {
        let cert = Certification(
            agency: "PADI",
            certName: "Advanced Open Water",
            certNumber: "1",
            dateAttained: .now,
            isPrimaryCert: false
        )
        #expect(CertificationPresentation.profileCertificationSubtitle(from: [cert]) == "GoDive User")
    }

    @Test func appUserSettings_automaticallyRenumberDivesKey_matchesAppStorage() {
        #expect(AppUserSettings.automaticallyRenumberDivesKey == "goDiveAutomaticallyRenumberDives")
    }

    @Test func appUserSettings_useImperialDisplayUnitsKey_matchesAppStorage() {
        #expect(AppUserSettings.useImperialDisplayUnitsKey == "goDiveUseImperialDisplayUnits")
    }

    @Test func diveSiteCoordinateMatcher_findsSiteNearMockDiveCoordinate() {
        let coordinate = DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
        let site = DiveSite(
            siteName: "Salt Pier — Bonaire (catalog)",
            latCoords: 12.0835,
            longCoords: -68.283,
            siteTags: ["shore"],
            siteRating: 5
        )
        let best = DiveSiteCoordinateMatcher.bestMatch(for: coordinate, in: [site])
        #expect(best?.siteName == site.siteName)
    }

    @Test func diveSiteReviewIndicator_trueWhenCatalogNameDiffersFromActivity() {
        let activity = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 34,
            maxDepthMeters: 7.89
        )
        activity.siteName = "Salt Pier"
        activity.entryCoordinate = DiveCoordinate(latitude: 12.08316, longitude: -68.2833)

        let site = DiveSite(
            siteName: "Salt Pier — Bonaire (catalog)",
            latCoords: 12.0835,
            longCoords: -68.283,
            siteTags: [],
            siteRating: nil
        )

        #expect(DiveSiteReviewIndicator.needsReview(for: activity, catalogSites: [site]) == true)
    }

    @Test func diveSiteReviewIndicator_falseWhenNamesMatchAfterTrim() {
        let activity = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 34,
            maxDepthMeters: 7.89
        )
        activity.siteName = "  salt pier — bonaire (catalog)  "
        activity.entryCoordinate = DiveCoordinate(latitude: 12.08316, longitude: -68.2833)

        let site = DiveSite(
            siteName: "Salt Pier — Bonaire (catalog)",
            latCoords: 12.0835,
            longCoords: -68.283,
            siteTags: [],
            siteRating: nil
        )

        #expect(DiveSiteReviewIndicator.needsReview(for: activity, catalogSites: [site]) == false)
    }

    // MARK: - Depth profile series

    @Test func diveDepthProfileSeries_emptySortedInput() {
        #expect(DiveDepthProfileSeries.samples(sortedAscending: []).isEmpty)
    }

    @Test func diveDepthProfileSeries_elapsedFromFirstSample() throws {
        let cal = Calendar(identifier: .gregorian)
        var c = DateComponents()
        c.year = 2025
        c.month = 6
        c.day = 10
        c.hour = 9
        c.minute = 0
        c.second = 0
        let t0 = try #require(cal.date(from: c))
        let t1 = try #require(cal.date(byAdding: .minute, value: 10, to: t0))
        let rows: [(timestamp: Date, depthMeters: Double)] = [
            (t0, 0.5),
            (t1, 12.0),
        ]
        let s = DiveDepthProfileSeries.samples(sortedAscending: rows)
        #expect(s.count == 2)
        #expect(s[0].elapsedSeconds == 0)
        #expect(abs(s[1].elapsedSeconds - 600) < 0.001)
        #expect(s[1].depthMeters == 12)
    }

    @Test @MainActor
    func diveDepthProfileSeries_sortsUnsortedProfilePoints() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let dive = DiveActivity(
            deviceSource: .manual,
            startTime: Date(timeIntervalSince1970: 100_000),
            durationMinutes: 30,
            maxDepthMeters: 20
        )
        context.insert(dive)
        let late = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 100_600), depthMeters: 10)
        let early = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 100_100), depthMeters: 5)
        dive.profilePoints.append(late)
        dive.profilePoints.append(early)
        try context.save()
        let s = DiveDepthProfileSeries.samples(fromProfilePoints: dive.profilePoints)
        #expect(s.map(\.depthMeters) == [5, 10])
        #expect(s[0].elapsedSeconds == 0)
        #expect(abs(s[1].elapsedSeconds - 500) < 0.001)
    }

    @Test func diveDepthProfileSeries_elapsedAtChartX() {
        let t = DiveDepthProfileSeries.elapsedSeconds(atChartX: 50, rectMinX: 0, rectWidth: 100, maxElapsed: 200)
        #expect(abs(t - 100) < 0.001)
    }

    @Test func diveDepthProfileSeries_indexNearestElapsed() {
        let s = [
            DiveDepthProfileSample(elapsedSeconds: 0, depthMeters: 1),
            DiveDepthProfileSample(elapsedSeconds: 60, depthMeters: 5),
            DiveDepthProfileSample(elapsedSeconds: 120, depthMeters: 3),
        ]
        #expect(DiveDepthProfileSeries.indexNearestElapsed(45, in: s) == 1)
        #expect(DiveDepthProfileSeries.indexNearestElapsed(0, in: s) == 0)
        #expect(DiveDepthProfileSeries.indexNearestElapsed(200, in: s) == 2)
    }

    @Test func diveDepthProfileSeries_pressureSamples_omitsNilTankPressure() throws {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let dive = DiveActivity(
            deviceSource: .manual,
            startTime: t0,
            durationMinutes: 30,
            maxDepthMeters: 20
        )
        let p0 = DiveProfilePoint(timestamp: t0, depthMeters: 0, tankPressurePSI: 3000)
        let p1 = DiveProfilePoint(timestamp: t0.addingTimeInterval(60), depthMeters: 10)
        let p2 = DiveProfilePoint(timestamp: t0.addingTimeInterval(120), depthMeters: 15, tankPressurePSI: 1500)
        dive.profilePoints = [p0, p1, p2]

        let samples = DiveDepthProfileSeries.pressureSamples(fromProfilePoints: dive.profilePoints)
        #expect(samples.count == 2)
        #expect(samples[0].pressurePSI == 3000)
        #expect(abs(samples[1].elapsedSeconds - 120) < 0.001)
        #expect(samples[1].pressurePSI == 1500)
    }

    @Test func diveTankOverviewHeroPresentation_showsMinimizedProfileChart_onlyAtMinimizedWithSamples() {
        #expect(
            DiveTankOverviewHeroPresentation.showsMinimizedProfileChart(for: .minimized, depthSampleCount: 2)
        )
        #expect(
            !DiveTankOverviewHeroPresentation.showsMinimizedProfileChart(for: .minimized, depthSampleCount: 1)
        )
        #expect(
            !DiveTankOverviewHeroPresentation.showsMinimizedProfileChart(for: .medium, depthSampleCount: 10)
        )
    }

    @Test func diveTankOverviewHeroPresentation_minimizedProfileChartFrame_isCenteredInVisibleBand() {
        let layoutSize = CGSize(width: 390, height: 640)
        let layoutHeight: CGFloat = 844
        let topObstruction: CGFloat = 100
        let bottomMargin = layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let frame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: bottomMargin
        )
        #expect(frame.width > 200)
        #expect(abs(frame.midX - layoutSize.width / 2) < 1)
        #expect(frame.minY > topObstruction)
        #expect(frame.maxY < layoutHeight - bottomMargin)
    }

    @Test func diveDepthProfileOverlayChartLayout_resolvedBaseline_prefersEndingPSI() {
        let samples = [
            DiveDepthProfilePressureSample(elapsedSeconds: 0, pressurePSI: 3000),
            DiveDepthProfilePressureSample(elapsedSeconds: 100, pressurePSI: 1500),
        ]
        let baseline = DiveDepthProfileOverlayChartLayout.resolvedPressureBaselinePSI(
            endingPSI: 1400,
            pressureSamples: samples
        )
        #expect(baseline == 1400)
    }

    @Test func diveTankMinimizedGasSummary_psiConsumed_subtractsEndFromStart() {
        #expect(DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: 3000, endPSI: 1200) == 1800)
        #expect(DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: 3000, endPSI: nil) == nil)
        #expect(DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: nil, endPSI: 500) == nil)
        #expect(DiveTankMinimizedGasSummary.psiConsumedPSI(startPSI: 1000, endPSI: 1500) == 0)
    }

    @Test func diveTankMinimizedGasSummary_sacRateLine_formatsValue() {
        #expect(DiveTankMinimizedGasSummary.usedLine(formattedConsumed: "1,800 psi") == "1,800 psi used.")
        #expect(DiveTankMinimizedGasSummary.sacRateLine(formattedRate: "24.3 psi/min") == "SAC: 24.3 psi/min")
        #expect(DiveTankMinimizedGasSummary.rmvRateLine(formattedRate: "18.4 L/min") == "RMV: 18.4 L/min")
        #expect(DiveTankMinimizedGasSummary.sacRateLabel == "SAC:")
        #expect(DiveTankMinimizedGasSummary.rmvRateLabel == "RMV:")
    }

    @Test func diveSACRMVCalculation_scubascribblesFreshwaterAL80Example() throws {
        let feetPerMeter = 3.280839895013123
        let depthMeters = 64.0 / feetPerMeter
        let al80GasLiters = 80.0 * 28.316846592
        let input = DiveSACRMVCalculation.Input(
            tankPressureStartPSI: 3000,
            tankPressureEndPSI: 2300,
            bottomTimeSeconds: 600,
            durationMinutes: 10,
            averageDepthMeters: depthMeters,
            maxDepthMeters: depthMeters,
            waterColumn: .freshwater,
            tankVolumeDescription: "\(Int(al80GasLiters.rounded())) L (AL80 gas)",
            defaultRatedPressurePSI: 3000
        )
        let result = try #require(DiveSACRMVCalculation.compute(input))
        #expect(abs(result.sacPSIPerMinute - 24.3) < 0.2)
        let expectedCFM = 0.65
        let expectedLPM = expectedCFM * 28.316846592
        #expect(abs(result.rmvLitersPerMinute - expectedLPM) < 1.5)
    }

    @Test func diveSACRMVCalculation_usesAL80RatedVolume_evenWithFITVolumeUsedText() throws {
        let input = DiveSACRMVCalculation.Input(
            tankPressureStartPSI: 3000,
            tankPressureEndPSI: 2000,
            bottomTimeSeconds: 600,
            durationMinutes: 10,
            averageDepthMeters: 20,
            maxDepthMeters: 20,
            tankVolumeDescription: "500 L used (~17.7 ft³) (FIT)",
            volumeUsedSurfaceLiters: 500
        )
        let sac = try #require(DiveSACRMVCalculation.sacPSIPerMinute(from: input))
        #expect(sac > 0)
        let rmv = try #require(DiveSACRMVCalculation.rmvLitersPerMinute(from: input, sacPSIPerMinute: sac))
        let ratedLitersPerPSI = DiveActivityTankDefaults.resolvedSpecification().ratedVolumeSurfaceLiters / 3000
        #expect(abs(rmv - sac * ratedLitersPerPSI) < 0.01)
        #expect(abs(rmv - 50.0) > 1)
    }

    @Test func diveQuantityFormatting_surfaceAirConsumption_and_rmv() throws {
        #expect(DiveQuantityFormatting.surfaceAirConsumption(sacPSIPerMinute: 24.3, system: .imperial) == "24.3 psi/min")
        let barLine = try #require(DiveQuantityFormatting.surfaceAirConsumption(sacPSIPerMinute: 24.3, system: .metric))
        #expect(barLine.contains("bar/min"))
        #expect(DiveQuantityFormatting.respiratoryMinuteVolume(litersPerMinute: 18.4, system: .metric) == "18.4 L/min")
        let cfm = try #require(DiveQuantityFormatting.respiratoryMinuteVolume(litersPerMinute: 18.4, system: .imperial))
        #expect(cfm.contains("cu ft/min"))
    }

    @Test func diveDepthProfileOverlayChartLayout_pressurePoint_endingPSIAtBottom() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
        let baseline: Double = 1500
        let maxAbove = DiveDepthProfileOverlayChartLayout.maxPressureAboveBaseline(
            pressureSamples: [
                DiveDepthProfilePressureSample(elapsedSeconds: 0, pressurePSI: 3000),
                DiveDepthProfilePressureSample(elapsedSeconds: 100, pressurePSI: 1500),
            ],
            baselinePSI: baseline
        )
        let start = DiveDepthProfileOverlayChartLayout.pressurePoint(
            sample: DiveDepthProfilePressureSample(elapsedSeconds: 0, pressurePSI: 3000),
            in: rect,
            maxElapsed: 100,
            baselinePSI: baseline,
            maxPressureAboveBaseline: maxAbove
        )
        let end = DiveDepthProfileOverlayChartLayout.pressurePoint(
            sample: DiveDepthProfilePressureSample(elapsedSeconds: 100, pressurePSI: 1500),
            in: rect,
            maxElapsed: 100,
            baselinePSI: baseline,
            maxPressureAboveBaseline: maxAbove
        )
        #expect(abs(end.y - rect.maxY) < 0.01)
        #expect(start.y < end.y)
    }

    @Test func goDiveUITestConfiguration_launchArgument_matchesAppCheck() {
        #expect(GoDiveUITestConfiguration.launchArgument == "-GoDiveUITest")
        #expect(GoDiveUITestConfiguration.launchEnvironmentKey == "GoDiveUITest")
    }

    @Test func diveActivityOverviewMapTeardown_showsLiveMap_untilRequested() {
        #expect(DiveActivityOverviewMapTeardown.showsLiveMap(teardownRequested: false))
        #expect(!DiveActivityOverviewMapTeardown.showsLiveMap(teardownRequested: true))
    }

    @Test func diveLocationMapPresentation_mapViewIdentity_changesWithCoordinate() {
        let diveID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let coord = DiveCoordinate(latitude: 12.08, longitude: -68.28)
        let without = DiveLocationMapPresentation.mapViewIdentity(activityID: diveID, coordinate: nil)
        let withCoord = DiveLocationMapPresentation.mapViewIdentity(activityID: diveID, coordinate: coord)
        #expect(without == "\(diveID.uuidString)-none")
        #expect(withCoord == "\(diveID.uuidString)-12.08,-68.28")
    }

    @Test func diveMapCoordinateResolver_prefersActivityCoordinate() {
        let entry = DiveCoordinate(latitude: 12.08, longitude: -68.28)
        let site = DiveSite(siteName: "Other", latCoords: 1, longCoords: 2)
        #expect(
            DiveMapCoordinateResolver.effectiveCoordinate(
                activityCoordinate: entry,
                siteName: "Salt Pier",
                catalogSites: [site]
            ) == entry
        )
    }

    @Test @MainActor
    func diveActivity_resolvedMapCoordinate_prefersLinkedSite() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let catalog = DiveSite(
            siteName: "Salt Pier — Bonaire (catalog)",
            latCoords: 12.0835,
            longCoords: -68.283
        )
        context.insert(catalog)

        let activity = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18,
            siteName: "Salt Pier",
            entryCoordinate: DiveCoordinate(latitude: 12.084, longitude: -68.284)
        )
        DiveActivitySiteAssociation.link(activity, to: catalog)

        let mapCoord = activity.resolvedMapCoordinate(catalogSites: [catalog])
        #expect(mapCoord?.latitude == 12.0835)
        #expect(mapCoord?.longitude == -68.283)
        #expect(activity.siteCoordinate?.latitude == 12.0835)
    }

    @Test @MainActor
    func diveActivitySiteAssociation_matchesByCoordinateBeforeName() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let byCoord = DiveSite(
            siteName: "GPS Site",
            latCoords: 12.0835,
            longCoords: -68.283
        )
        let byNameOnly = DiveSite(
            siteName: "Salt Pier — Bonaire (catalog)",
            latCoords: 1,
            longCoords: 1
        )
        context.insert(byCoord)
        context.insert(byNameOnly)

        let activity = DiveActivity(
            deviceSource: .macDive,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            siteName: "Salt Pier",
            entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
        )

        DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: [byCoord, byNameOnly])
        #expect(activity.diveSite?.siteName == "GPS Site")
        #expect(activity.diveSiteID == byCoord.id)
    }

    @Test func diveActivityMapSitePrompt_isEligibleWhenUnlinkedWithEntryOrName() {
        let withGPS = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            entryCoordinate: DiveCoordinate(latitude: 12, longitude: -68)
        )
        #expect(DiveActivityMapSitePrompt.isEligible(for: withGPS))

        let withName = DiveActivity(
            deviceSource: .macDive,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            siteName: "Salt Pier"
        )
        #expect(DiveActivityMapSitePrompt.isEligible(for: withName))

        let linked = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            siteName: "Salt Pier"
        )
        let site = DiveSite(siteName: "Catalog", latCoords: 12, longCoords: -68)
        linked.diveSite = site
        #expect(!DiveActivityMapSitePrompt.isEligible(for: linked))
    }

    @Test func diveSiteCoordinatePickerPresentation_initialCenter_prefersParsedText() {
        let center = DiveSiteCoordinatePickerPresentation.initialCenter(
            latitudeText: "12.08316",
            longitudeText: "-68.28330",
            fallback: DiveCoordinate(latitude: 1, longitude: 2)
        )
        #expect(center.latitude == 12.08316)
        #expect(center.longitude == -68.28330)
    }

    @Test func diveSiteCoordinatePickerPresentation_initialCenter_usesFallbackWhenTextEmpty() {
        let fallback = DiveCoordinate(latitude: 12.05, longitude: -68.27)
        let center = DiveSiteCoordinatePickerPresentation.initialCenter(
            latitudeText: "",
            longitudeText: "",
            fallback: fallback
        )
        #expect(center == fallback)
    }

    @Test func diveSiteCoordinatePickerPresentation_formattedTexts_useFiveDecimals() {
        let coordinate = DiveCoordinate(latitude: 12.08316, longitude: -68.28330)
        let formatted = DiveSiteCoordinatePickerPresentation.formattedTexts(for: coordinate)
        #expect(formatted.latitude == "12.08316")
        #expect(formatted.longitude == "-68.28330")
    }

    @Test func diveActivityMapSitePrompt_showsInfoButtonOnlyAfterDecline() {
        let activity = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            entryCoordinate: DiveCoordinate(latitude: 12, longitude: -68)
        )
        #expect(DiveActivityMapSitePrompt.shouldPresentAutomatically(for: activity, userDeclined: false))
        #expect(!DiveActivityMapSitePrompt.showsInfoButton(for: activity, userDeclined: false))
        #expect(!DiveActivityMapSitePrompt.shouldPresentAutomatically(for: activity, userDeclined: true))
        #expect(DiveActivityMapSitePrompt.showsInfoButton(for: activity, userDeclined: true))
    }

    @Test @MainActor
    func diveActivitySiteAssociation_createSiteAndLink_persists() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let activity = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18,
            siteName: "New Wall",
            entryCoordinate: DiveCoordinate(latitude: 12.05, longitude: -68.27)
        )
        context.insert(activity)

        let site = try DiveActivitySiteAssociation.createSiteAndLink(
            to: activity,
            siteName: "New Wall",
            latCoords: 12.05,
            longCoords: -68.27,
            modelContext: context
        )

        #expect(activity.diveSite?.id == site.id)
        #expect(activity.diveSiteID == site.id)
        #expect(activity.siteCoordinate?.latitude == 12.05)
        #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 1)
    }

    @Test @MainActor
    func diveActivitySiteAssociation_matchesByNameWhenNoEntryGPS() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let catalog = DiveSite(
            siteName: "Salt Pier — Bonaire (catalog)",
            latCoords: 12.0835,
            longCoords: -68.283
        )
        context.insert(catalog)

        let activity = DiveActivity(
            deviceSource: .macDive,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            siteName: "Salt Pier"
        )

        DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: [catalog])
        #expect(activity.diveSite?.id == catalog.id)
        #expect(activity.entryCoordinate == nil)
        #expect(activity.siteCoordinate?.latitude == 12.0835)
    }

    @Test func diveMapCoordinateResolver_fallsBackToCatalogSiteName() {
        let site = DiveSite(
            siteName: "Salt Pier — Bonaire (catalog)",
            latCoords: 12.0835,
            longCoords: -68.283
        )
        let resolved = DiveMapCoordinateResolver.effectiveCoordinate(
            activityCoordinate: nil,
            siteName: "Salt Pier",
            catalogSites: [site]
        )
        #expect(resolved?.latitude == 12.0835)
        #expect(resolved?.longitude == -68.283)
    }

    @Test func diveLocationMapPresentation_targetPinScreenYFraction_centersVisibleBand() {
        let layoutHeight: CGFloat = 800
        let top: CGFloat = 100
        let sheetMedium = DiveActivityOverviewPanelMetrics.mediumHeightFraction

        let target = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            sheetHeightFraction: sheetMedium
        )
        let topFraction = top / layoutHeight
        let expected = topFraction + (1 - topFraction - sheetMedium) / 2
        #expect(abs(target - expected) < 0.001)
    }

    @Test func diveLocationMapPresentation_targetPinScreenYFraction_lowerWhenSheetIncludesSafeInset() {
        let layoutHeight: CGFloat = 800
        let top: CGFloat = 100
        let withSafe = layoutHeight * 0.50 + 34
        let withSheetOnly = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            sheetHeightFraction: 0.50
        )
        let withObstructionHeight = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            sheetHeightFraction: withSafe / layoutHeight
        )
        #expect(withSheetOnly > withObstructionHeight)
    }

    @Test func diveLocationMapPresentation_sheetHeightFraction_fromBottomMargin() {
        let layoutHeight: CGFloat = 800
        let bottomContentMargin: CGFloat = 194
        #expect(
            DiveLocationMapPresentation.sheetHeightFraction(
                layoutHeight: layoutHeight,
                bottomContentMargin: bottomContentMargin
            ) == bottomContentMargin / layoutHeight
        )
    }

    @Test func diveLocationMapPresentation_targetPinScreenYFraction_minimized_isBelowMedium() {
        let layoutHeight: CGFloat = 800
        let top: CGFloat = 100
        let medium = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            sheetHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction
        )
        let minimized = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            sheetHeightFraction: DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        )
        #expect(minimized > medium)
    }

    @Test func diveMapCameraLayoutContext_equatable() {
        let a = DiveMapCameraLayoutContext(
            coordinateIdentity: "1,2",
            layoutHeight: 800,
            bottomContentMargin: 400,
            topObstructionHeight: 100,
            cameraLayoutDetent: .medium
        )
        let b = DiveMapCameraLayoutContext(
            coordinateIdentity: "1,2",
            layoutHeight: 800,
            bottomContentMargin: 400,
            topObstructionHeight: 100,
            cameraLayoutDetent: .medium
        )
        #expect(a == b)
        #expect(
            DiveMapCameraLayoutContext(
                coordinateIdentity: "1,2",
                layoutHeight: 800,
                bottomContentMargin: 400,
                topObstructionHeight: 100,
                cameraLayoutDetent: .minimized
            ) != a
        )
    }

    @Test func diveLocationMapPresentation_cameraDistanceMeters_detentZoomSteps() {
        #expect(DiveLocationMapPresentation.minimizedCameraDistanceMeters == 1_200)
        #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .minimized) < DiveLocationMapPresentation.referenceCameraDistanceMeters)
        #expect(
            DiveLocationMapPresentation.cameraDistanceMeters(for: .minimized)
                < DiveLocationMapPresentation.cameraDistanceMeters(for: .medium)
        )
        #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .medium) > DiveLocationMapPresentation.referenceCameraDistanceMeters)
        #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .large) == DiveLocationMapPresentation.cameraDistanceMeters(for: .medium))
    }

    @Test func diveActivityOverviewTabSelection_mapAndTank_useMediumDetent() {
        #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .map) == .medium)
        #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .tank) == .medium)
        #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .camera) == nil)
    }

    @Test func diveActivityOverviewDetent_mapCameraDetent_largeMatchesMedium() {
        #expect(DiveActivityOverviewDetent.large.mapCameraDetent == .medium)
        #expect(DiveActivityOverviewDetent.medium.mapCameraDetent == .medium)
        #expect(DiveActivityOverviewDetent.minimized.mapCameraDetent == .minimized)
    }

    @Test func diveActivityOverviewDetent_allowsMapInteraction_onlyWhenMinimized() {
        #expect(DiveActivityOverviewDetent.minimized.allowsMapInteraction)
        #expect(!DiveActivityOverviewDetent.medium.allowsMapInteraction)
        #expect(!DiveActivityOverviewDetent.large.allowsMapInteraction)
    }

    @Test func diveLocationMapPresentation_coordinateLabel_usesThreeDecimalPlaces() {
        let coordinate = DiveCoordinate(latitude: 12.08316, longitude: -68.28330)
        #expect(
            DiveLocationMapPresentation.coordinateLabel(for: coordinate) == "12.083°, -68.283°"
        )
    }

    @Test func appTheme_sheet_sharedPresentationChrome_isTranslucent() {
        #expect(AppTheme.Sheet.cornerRadius == 20)
        #expect(AppTheme.Sheet.backgroundMaterialOpacity > 0)
        #expect(AppTheme.Sheet.backgroundMaterialOpacity < 1)
        #expect(AppTheme.Sheet.backgroundMaterialOpacity < 0.75)
    }

    @Test func diveTankOverviewHeroPresentation_scale_byDetent() {
        #expect(DiveTankOverviewHeroPresentation.scale(for: .minimized) == 0.5)
        #expect(DiveTankOverviewHeroPresentation.scale(for: .medium) == 1)
    }

    @Test func diveTankOverviewHeroPresentation_medium_fullFill_andGasLabelOnly() {
        #expect(DiveTankOverviewHeroPresentation.showsTankHero(for: .medium))
        #expect(DiveTankOverviewHeroPresentation.showsTankHero(for: .minimized))
        #expect(!DiveTankOverviewHeroPresentation.showsTankHero(for: .large))
        #expect(DiveTankOverviewHeroPresentation.layoutDetent(for: .large) == .medium)
        #expect(DiveTankOverviewHeroPresentation.layoutDetent(for: .minimized) == .minimized)
        #expect(DiveTankOverviewHeroPresentation.showsGasMixLabel(for: .medium))
        #expect(!DiveTankOverviewHeroPresentation.showsGasMixLabel(for: .minimized))
        #expect(!DiveTankOverviewHeroPresentation.showsGasMixLabel(for: .large))
        #expect(
            DiveTankOverviewHeroPresentation.displayPressureFillFraction(
                sheetDetent: .medium,
                animatedFillFraction: 0.25
            ) == 1
        )
        #expect(
            DiveTankOverviewHeroPresentation.displayPressureFillFraction(
                sheetDetent: .minimized,
                animatedFillFraction: 0.25
            ) == 0.25
        )
        #expect(DiveGasMixImport.tankHeroLabel(gasType: "Nitrox", oxygenMix: 32) == "Nitrox 32%")
        #expect(DiveGasMixImport.tankHeroLabel(gasType: nil, oxygenMix: 32) == "No gas specified")
        #expect(DiveGasMixImport.tankHeroLabel(gasType: "Air", oxygenMix: nil) == "No gas specified")
    }

    @Test func diveTankOverviewHeroPresentation_minimizedTopInset_includesDownshift() {
        let chromeTop: CGFloat = 100
        let padding = DiveTankOverviewHeroPresentation.topTrailingPadding(topObstructionHeight: chromeTop)
        #expect(
            padding.top
                == chromeTop
                + DiveTankOverviewHeroPresentation.minimizedTopInsetBelowChrome
                + DiveTankOverviewHeroPresentation.minimizedAdditionalTopOffset
        )
    }

    @Test func diveTankOverviewHeroPresentation_layoutMetrics_animatesMediumToMinimized() {
        let layoutSize = CGSize(width: 390, height: 640)
        let layoutHeight: CGFloat = 844
        let topObstruction: CGFloat = 100
        let bottomMargin = layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let cylinderHeight: CGFloat = 148

        let medium = DiveTankOverviewHeroPresentation.layoutMetrics(
            detent: .medium,
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: layoutHeight * DiveActivityOverviewPanelMetrics.mediumHeightFraction,
            cylinderHeight: cylinderHeight
        )
        let minimized = DiveTankOverviewHeroPresentation.layoutMetrics(
            detent: .minimized,
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: bottomMargin,
            cylinderHeight: cylinderHeight
        )

        #expect(medium.scale == 1)
        #expect(minimized.scale == DiveTankOverviewHeroPresentation.minimizedScale)
        #expect(minimized.cylinderCenterX > medium.cylinderCenterX)
        #expect(minimized.cylinderCenterY < medium.cylinderCenterY)
        #expect(minimized.gasLabelCenterY > minimized.cylinderCenterY)
    }

    @Test func diveTankOverviewHeroPresentation_verticalCenterOffset_medium_shiftsFromPaddedMidpoint() {
        let layoutHeight: CGFloat = 800
        let topObstruction: CGFloat = 100
        let bottomMargin = layoutHeight * DiveActivityOverviewPanelMetrics.mediumHeightFraction
        let offset = DiveTankOverviewHeroPresentation.verticalCenterOffset(
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: bottomMargin,
            sheetHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction
        )
        let targetY = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            sheetHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction
        ) * layoutHeight
        let defaultCenterY = (layoutHeight - bottomMargin) / 2
        #expect(abs(offset - (targetY - defaultCenterY)) < 0.01)
        #expect(offset > 0)
    }

    @Test func diveTankOverviewHeroPresentation_layoutMetrics_medium_centerY_matchesTargetPinY() {
        let layoutSize = CGSize(width: 390, height: 844)
        let layoutHeight = layoutSize.height
        let topObstruction: CGFloat = 100
        let bottomMargin = layoutHeight * DiveActivityOverviewPanelMetrics.mediumHeightFraction
        let cylinderHeight: CGFloat = 148
        let metrics = DiveTankOverviewHeroPresentation.layoutMetrics(
            detent: .medium,
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: bottomMargin,
            cylinderHeight: cylinderHeight
        )
        let targetY = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            sheetHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction
        ) * layoutHeight
        #expect(abs(metrics.cylinderCenterY - targetY) < 0.5)
    }

    @Test func diveLocationMapPresentation_adjustedMapCenter_medium_shiftsSouthOfPin() {
        let coordinate = DiveCoordinate(latitude: 12, longitude: -68)
        let layoutHeight: CGFloat = 800
        let center = DiveLocationMapPresentation.adjustedMapCenter(
            for: coordinate,
            layoutHeight: layoutHeight,
            topObstructionHeight: 100,
            bottomContentMargin: layoutHeight * DiveActivityOverviewPanelMetrics.mediumHeightFraction,
            mapCameraDetent: .medium
        )
        #expect(center.latitude < coordinate.latitude)
        #expect(center.longitude == coordinate.longitude)
    }

    @Test func diveLocationMapPresentation_adjustedMapCenter_medium_shiftIsLessThanUnscaledOffset() {
        let coordinate = DiveCoordinate(latitude: 12, longitude: -68)
        let layoutHeight: CGFloat = 800
        let top: CGFloat = 100
        let bottom = layoutHeight * 0.50
        let sheetFraction = bottom / layoutHeight
        let targetY = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            sheetHeightFraction: sheetFraction
        )
        let unscaled = (0.5 - targetY) * 0.05
        let center = DiveLocationMapPresentation.adjustedMapCenter(
            for: coordinate,
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            bottomContentMargin: bottom,
            mapCameraDetent: .medium
        )
        let appliedShift = coordinate.latitude - center.latitude
        #expect(appliedShift < unscaled)
        #expect(appliedShift > 0)
    }

    @Test func diveLocationMapPresentation_adjustedMapCenter_minimized_shiftsLessThanMedium() {
        let coordinate = DiveCoordinate(latitude: 12, longitude: -68)
        let layoutHeight: CGFloat = 800
        let top: CGFloat = 100
        let bottomInset: CGFloat = 34
        let medium = DiveLocationMapPresentation.adjustedMapCenter(
            for: coordinate,
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            bottomContentMargin: layoutHeight * DiveActivityOverviewPanelMetrics.mediumHeightFraction + bottomInset,
            mapCameraDetent: .medium
        )
        let minimized = DiveLocationMapPresentation.adjustedMapCenter(
            for: coordinate,
            layoutHeight: layoutHeight,
            topObstructionHeight: top,
            bottomContentMargin: layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction + bottomInset,
            mapCameraDetent: .minimized
        )
        #expect(coordinate.latitude - minimized.latitude < coordinate.latitude - medium.latitude)
    }

    @Test func diveMapCoordinateResolver_rejectsNullIsland() {
        #expect(!DiveMapCoordinateResolver.isUsable(DiveCoordinate(latitude: 0, longitude: 0)))
    }

    @Test func diveLocationMapPresentation_withoutCoordinate_usesDefaultRegion() {
        let spec = DiveLocationMapPresentation.regionSpec(for: nil)
        #expect(spec == DiveLocationMapPresentation.defaultRegion)
        #expect(DiveLocationMapPresentation.showsDiveMarker(for: nil) == false)
    }

    @Test func diveLocationMapPresentation_withCoordinate_centersOnDive() {
        let coordinate = DiveCoordinate(latitude: 12.08316, longitude: -68.28330)
        let spec = DiveLocationMapPresentation.regionSpec(for: coordinate)
        #expect(spec.centerLatitude == 12.08316)
        #expect(spec.centerLongitude == -68.28330)
        #expect(spec.latitudeDelta == DiveLocationMapPresentation.diveSiteLatitudeDelta)
        #expect(DiveLocationMapPresentation.showsDiveMarker(for: coordinate) == true)
    }

    @Test func diveActivityOverviewPanelMetrics_snappedHeightFraction_snapsToNearestDetent() {
        let medium = DiveActivityOverviewPanelMetrics.mediumHeightFraction
        #expect(
            DiveActivityOverviewPanelMetrics.snappedHeightFraction(
                currentFraction: medium,
                predictedFraction: 0.18
            ) == DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        )
        #expect(
            DiveActivityOverviewPanelMetrics.snappedHeightFraction(
                currentFraction: medium,
                predictedFraction: 0.52
            ) == medium
        )
        #expect(
            DiveActivityOverviewPanelMetrics.snappedHeightFraction(
                currentFraction: medium,
                predictedFraction: 0.87
            ) == DiveActivityOverviewPanelMetrics.largeHeightFraction
        )
    }

    @Test func diveActivityTabIcon_matchesGlyphHeight() {
        #expect(DiveActivityTabIcon.tabGlyphPointSize == 22)
        let tankSize = DiveActivityTabIcon.templateAssetSize(for: "ScubaTankTab")
        #expect(tankSize.height == 22)
        #expect(tankSize.width < tankSize.height)
        #expect(abs(tankSize.width / tankSize.height - DiveActivityTabIcon.scubaTankTabAspectWidthOverHeight) < 0.001)
    }

    @Test @MainActor func mapKitWarmup_shouldWarmUp_matchesUITestLaunchFlag() {
        #expect(MapKitWarmup.shouldWarmUp == !GoDiveUITestConfiguration.isActive)
    }

    @Test func diveActivityTab_iconSources() {
        #expect(DiveActivityTab.map.systemImageName == "map")
        #expect(DiveActivityTab.map.assetImageName == nil)
        #expect(DiveActivityTab.tank.systemImageName == nil)
        #expect(DiveActivityTab.tank.assetImageName == "ScubaTankTab")
        #expect(DiveActivityTab.camera.systemImageName == "camera")
        #expect(DiveActivityTab.allCases.count == 3)
    }

    @Test func diveActivityTankPanelSummary_remainingPressureFillFraction_clampsAndNilRules() {
        let third = DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: 1000)!
        #expect(abs(third - (1000.0 / 3000.0)) < 1e-9)

        #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: nil, endPSI: 1000) == nil)
        #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: nil) == nil)
        #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 0, endPSI: 0) == nil)
        #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: -100, endPSI: 500) == nil)
        #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: -1) == nil)

        #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: 4500) == 1)
        #expect(DiveActivityTankPanelSummary.remainingPressureFillFraction(startPSI: 3000, endPSI: 0) == 0)
    }

    @Test func diveActivityTankPanelSummary_profilePressureStats_countsAndBounds() {
        let a = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 100), depthMeters: 1, tankPressurePSI: 3_000)
        let b = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 200), depthMeters: 2, tankPressurePSI: nil)
        let c = DiveProfilePoint(timestamp: Date(timeIntervalSince1970: 300), depthMeters: 3, tankPressurePSI: 2_800)

        let s = DiveActivityTankPanelSummary.profilePressureStats(from: [a, b, c])
        #expect(s.sampleCount == 2)
        #expect(s.minPSI == 2_800)
        #expect(s.maxPSI == 3_000)

        let empty = DiveActivityTankPanelSummary.profilePressureStats(from: [])
        #expect(empty.sampleCount == 0)
        #expect(empty.minPSI == nil)
        #expect(empty.maxPSI == nil)
    }

    @Test func diveActivityOverviewPanelMetrics_mediumHeightFraction_isHalfScreen() {
        #expect(DiveActivityOverviewPanelMetrics.mediumHeightFraction == 0.50)
    }

    @Test func diveActivityOverviewPanelMetrics_heightFractionWhileDragging_followsFinger() {
        let medium = DiveActivityOverviewPanelMetrics.mediumHeightFraction
        #expect(
            DiveActivityOverviewPanelMetrics.heightFractionWhileDragging(
                restingFraction: medium,
                dragTranslation: 0,
                layoutHeight: 800
            ) == medium
        )
        #expect(
            DiveActivityOverviewPanelMetrics.heightFractionWhileDragging(
                restingFraction: medium,
                dragTranslation: 160,
                layoutHeight: 800
            ) < medium
        )
    }

    @Test func diveActivityOverviewPanelMetrics_clampedHeightFraction_limitsRange() {
        #expect(DiveActivityOverviewPanelMetrics.clampedHeightFraction(0.05) == 0.20)
        #expect(DiveActivityOverviewPanelMetrics.clampedHeightFraction(0.99) == 0.85)
        #expect(
            DiveActivityOverviewPanelMetrics.clampedHeightFraction(0.50)
                == DiveActivityOverviewPanelMetrics.mediumHeightFraction
        )
    }

    @Test func diveActivityOverviewPanelMetrics_shouldExpandFromScroll_atMedium() {
        #expect(
            DiveActivityOverviewPanelMetrics.shouldExpandFromScroll(
                restingFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction,
                scrollOffsetY: 40
            )
        )
        #expect(
            !DiveActivityOverviewPanelMetrics.shouldExpandFromScroll(
                restingFraction: DiveActivityOverviewPanelMetrics.largeHeightFraction,
                scrollOffsetY: 40
            )
        )
    }

    @Test func diveActivityOverviewPanelMetrics_snappedHeightFractionAfterDrag_stepsThroughMedium() {
        let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let medium = DiveActivityOverviewPanelMetrics.mediumHeightFraction
        let large = DiveActivityOverviewPanelMetrics.largeHeightFraction

        #expect(
            DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                currentFraction: minimized,
                predictedFraction: large,
                verticalTranslation: -80
            ) == medium
        )
        #expect(
            DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                currentFraction: large,
                predictedFraction: minimized,
                verticalTranslation: 80
            ) == medium
        )
        #expect(
            DiveActivityOverviewPanelMetrics.snappedHeightFractionAfterDrag(
                currentFraction: medium,
                predictedFraction: large,
                verticalTranslation: -120
            ) == large
        )
    }

    @Test func diveActivityOverviewPanelMetrics_shouldCollapseToMediumFromScroll_whenExpanded() {
        #expect(
            DiveActivityOverviewPanelMetrics.shouldCollapseToMediumFromScroll(
                restingFraction: DiveActivityOverviewPanelMetrics.largeHeightFraction,
                scrollOffsetY: -30
            )
        )
        #expect(
            !DiveActivityOverviewPanelMetrics.shouldCollapseToMediumFromScroll(
                restingFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction,
                scrollOffsetY: -30
            )
        )
    }

    @Test func diveActivityOverviewPanelMetrics_nextDetent_stepsThroughAllHeights() {
        let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let medium = DiveActivityOverviewPanelMetrics.mediumHeightFraction
        let large = DiveActivityOverviewPanelMetrics.largeHeightFraction

        #expect(DiveActivityOverviewPanelMetrics.nextTallerDetent(after: minimized) == medium)
        #expect(DiveActivityOverviewPanelMetrics.nextTallerDetent(after: medium) == large)
        #expect(DiveActivityOverviewPanelMetrics.nextTallerDetent(after: large) == nil)

        #expect(DiveActivityOverviewPanelMetrics.nextShorterDetent(after: large) == medium)
        #expect(DiveActivityOverviewPanelMetrics.nextShorterDetent(after: medium) == minimized)
        #expect(DiveActivityOverviewPanelMetrics.nextShorterDetent(after: minimized) == nil)
    }

    @Test func diveActivityOverviewDetent_nearest_toHeightFraction_mapsDetents() {
        #expect(
            DiveActivityOverviewDetent.nearest(
                toHeightFraction: DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            ) == .minimized
        )
        #expect(
            DiveActivityOverviewDetent.nearest(
                toHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction
            ) == .medium
        )
        #expect(
            DiveActivityOverviewDetent.nearest(
                toHeightFraction: DiveActivityOverviewPanelMetrics.largeHeightFraction
            ) == .large
        )
    }

    @Test func diveActivityOverviewDetent_roundTripsPresentationDetent() {
        for detent in DiveActivityOverviewDetent.allCases {
            let presentation = detent.presentationDetent
            #expect(DiveActivityOverviewDetent(presentationDetent: presentation) == detent)
            #expect(detent.nextTaller() != nil || detent == .large)
            #expect(detent.nextShorter() != nil || detent == .minimized)
        }
        #expect(DiveActivityOverviewDetent.large.nextTaller() == nil)
        #expect(DiveActivityOverviewDetent.minimized.nextShorter() == nil)
        #expect(DiveActivityOverviewDetent.minimized.nextTaller() == .medium)
    }

    @Test func diveActivityOverviewDetent_bottomObstructionHeight_usesFraction() {
        let height = DiveActivityOverviewDetent.bottomObstructionHeight(
            layoutHeight: 800,
            detent: .medium,
            bottomSafeInset: 34
        )
        #expect(abs(height - (800 * 0.50 + 34)) < 0.01)
    }

    @Test func diveActivityOverviewDetent_sheetHeight_forHeightFraction_isContinuous() {
        let layoutHeight: CGFloat = 800
        let inset: CGFloat = 34
        let fraction: CGFloat = 0.62
        #expect(
            DiveActivityOverviewDetent.sheetHeight(
                forHeightFraction: fraction,
                layoutHeight: layoutHeight,
                bottomSafeInset: inset
            ) == layoutHeight * fraction + inset
        )
    }

    @Test func diveActivityOverviewDetent_sheetHeight_includesBottomSafeInset() {
        let sheet = DiveActivityOverviewDetent.sheetHeight(
            for: .minimized,
            layoutHeight: 844,
            bottomSafeInset: 34
        )
        #expect(abs(sheet - (844 * 0.20 + 34)) < 0.01)
    }

    @Test func diveActivityOverviewPanelMetrics_accessibilityDetentDescription_labelsRestingHeights() {
        #expect(
            DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(
                for: DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            ) == "Minimized"
        )
        #expect(
            DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(
                for: DiveActivityOverviewPanelMetrics.mediumHeightFraction
            ) == "Half height"
        )
        #expect(
            DiveActivityOverviewPanelMetrics.accessibilityDetentDescription(
                for: DiveActivityOverviewPanelMetrics.largeHeightFraction
            ) == "Expanded"
        )
    }

    @Test func diveActivityOverviewPresentation_siteHeaderTitle_prefersTrimmedSiteName() {
        #expect(
            DiveActivityOverviewPresentation.siteHeaderTitle(siteName: "Salt Pier", fallback: "Dive") == "Salt Pier"
        )
        #expect(
            DiveActivityOverviewPresentation.siteHeaderTitle(siteName: "  ", fallback: "Garmin MK3") == "Garmin MK3"
        )
        #expect(
            DiveActivityOverviewPresentation.siteHeaderTitle(siteName: nil, fallback: "Dive") == "Dive"
        )
    }

    @Test func diveImportWaterTemperatureSummary_mergeSessionAndRecords() {
        let m = DiveImportWaterTemperatureSummary.mergedAvgMaxMinCelsius(
            sessionAvg: 28,
            sessionMax: 29,
            sessionMin: 27,
            recordTemps: [28.0, 30.0]
        )
        #expect(m.avg == 28)
        #expect(m.max == 30)
        #expect(m.min == 27)
    }

    @Test func diveImportWaterTemperatureSummary_recordsOnly() {
        let m = DiveImportWaterTemperatureSummary.mergedAvgMaxMinCelsius(
            sessionAvg: nil,
            sessionMax: nil,
            sessionMin: nil,
            recordTemps: [26.0, 28.0]
        )
        #expect(m.avg.map { abs($0 - 27.0) < 0.001 } == true)
        #expect(m.min == 26)
        #expect(m.max == 28)
    }

    @Test func diveImportFitUInt32Seconds_toOptionalInt() {
        #expect(DiveImportFitUInt32Seconds.toOptionalInt(nil) == nil)
        #expect(DiveImportFitUInt32Seconds.toOptionalInt(72) == 72)
    }

    @Test func fitDecoder_emptyData_throwsEmptyFile() {
        var caughtEmptyFile = false
        do {
            _ = try FitDiveFileDecoder.buildDiveActivity(from: Data())
        } catch FitDecodeError.emptyFile {
            caughtEmptyFile = true
        } catch {
            Issue.record("Expected FitDecodeError.emptyFile, got \(error)")
        }
        #expect(caughtEmptyFile)
    }

    @Test func fitDecoder_nonFitBytes_throwsFitDecodeError() {
        let data = Data(repeating: 0xAB, count: 64)
        #expect(throws: FitDecodeError.self) {
            try FitDiveFileDecoder.buildDiveActivity(from: data)
        }
    }

    @Test
    func fitFileImport_readFitFileData_nonFileURL_throws() {
        // `startAccessingSecurityScopedResource()` is not guaranteed to return `false` for sandbox temp
        // file URLs across OS versions; a non-file URL never gains scope, so import must throw.
        let url = URL(string: "https://example.com/godive-read-fit-test.fit")!
        #expect(throws: (any Error).self) {
            try FitDiveFileImport.readFitFileData(from: url)
        }
    }

    @Test @MainActor
    func fitFileImport_emptyData_returnsOutcomeWithEmptyFileMessage() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let outcome = FitDiveFileImport.importFitData(Data(), modelContext: context)
        #expect(outcome.userMessage == FitDecodeError.emptyFile.localizedDescription)
        #expect(outcome.primaryInsertedDiveId == nil)
    }

    @Test func fitTankFieldImport_psiFromBar() throws {
        let twoBarPSI = try #require(FitTankFieldImport.psi(fromBar: 2.0))
        #expect(abs(twoBarPSI - 29.0075476014) < 0.0001)
        #expect(FitTankFieldImport.psi(fromBar: nil) == nil)
        #expect(FitTankFieldImport.psi(fromBar: 0) == nil)
    }

    @Test func fitTankFieldImport_validateDistinct_throwsWhenMoreThanTwoSensors() {
        #expect(throws: FitDecodeError.self) {
            try FitTankFieldImport.validateDistinctTankSensorCount(3)
        }
    }

    @Test func fitTankFieldImport_validateDistinct_acceptsZeroThroughTwo() throws {
        try FitTankFieldImport.validateDistinctTankSensorCount(0)
        try FitTankFieldImport.validateDistinctTankSensorCount(1)
        try FitTankFieldImport.validateDistinctTankSensorCount(2)
    }

    @Test func fitTankFieldImport_nearestPressurePSI_matchesClosestSortedSample() throws {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let samples: [(Date, Double)] = [
            (t0.addingTimeInterval(-10), 200.0),
            (t0.addingTimeInterval(2), 180.0),
            (t0.addingTimeInterval(20), 170.0),
        ]
        let psiNear = try #require(FitTankFieldImport.nearestTankPressurePSI(
            recordTime: t0,
            sortedSamples: samples,
            maxTimeDelta: 5.0
        ))
        let expected = try #require(FitTankFieldImport.psi(fromBar: 180.0))
        #expect(abs(psiNear - expected) < 0.001)
    }

    @Test func fitTankFieldImport_nearestPressurePSI_returnsNilOutsideWindow() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let samples: [(Date, Double)] = [(t0.addingTimeInterval(-30), 200.0)]
        #expect(FitTankFieldImport.nearestTankPressurePSI(
            recordTime: t0,
            sortedSamples: samples,
            maxTimeDelta: 5.0
        ) == nil)
    }

    @Test func diveGasMixImport_tankYellowFillFraction_usesOxygenOrAirDefault() {
        #expect(DiveGasMixImport.tankYellowFillFraction(oxygenMixPercent: 33) == 0.33)
        #expect(DiveGasMixImport.tankYellowFillFraction(oxygenMixPercent: nil) == 0.21)
        #expect(DiveGasMixImport.tankYellowFillFraction(oxygenMixPercent: 21) == 0.21)
    }

    @Test func diveGasMixImport_gasType_airAt21_nitroxOtherwise() {
        #expect(DiveGasMixImport.gasType(forOxygenPercent: 21) == "Air")
        #expect(DiveGasMixImport.gasType(forOxygenPercent: 21.0) == "Air")
        #expect(DiveGasMixImport.gasType(forOxygenPercent: 32) == "Nitrox")
        let fromUddf = DiveGasMixImport.resolved(fromUddfO2: 0.21)
        #expect(fromUddf.oxygenMix == 21)
        #expect(fromUddf.gasType == "Air")
        let fromFit = DiveGasMixImport.resolved(fromFitOxygenContent: 32)
        #expect(fromFit.oxygenMix == 32)
        #expect(fromFit.gasType == "Nitrox")
    }

    @Test func fitTankFieldImport_volumeUsedDescription() {
        #expect(FitTankFieldImport.volumeUsedDescription(volumeUsedLiters: 12.26) == "12 L used (~0.4 ft³) (FIT)")
        #expect(FitTankFieldImport.volumeUsedDescription(volumeUsedLiters: 1347.87)?.contains("1348") == true)
        #expect(FitTankFieldImport.volumeUsedDescription(volumeUsedLiters: 1347.87)?.contains("47.6") == true)
        #expect(FitTankFieldImport.volumeUsedDescription(volumeUsedLiters: nil) == nil)
    }

    /// Regression: **`SingleGasDiveSample.fit`** (Garmin single-gas dive) — verified tank pressures (psi), gas used (~47.6 ft³), entry GPS.
    @Test func fitDecoder_singleGasSample_matchesVerifiedReference() throws {
        let fitURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("SingleGasDiveSample.fit", isDirectory: false)
        let data = try Data(contentsOf: fitURL)
        let a = try FitDiveFileDecoder.buildDiveActivity(from: data)
        let start = try #require(a.tankPressureStartPSI)
        let end = try #require(a.tankPressureEndPSI)
        #expect(abs(start - 3081) < 2.0)
        #expect(abs(end - 1294) < 2.0)
        #expect(a.tankVolumeDescription == DefaultTankSize.al80.specification.storedDescription)
        #expect(a.gasDetailsTankVolumeLine(displayUnits: .imperial) == "80 cu ft")
        #expect(a.gasDetailsTankTypeLine() == "aluminum")
        let c = try #require(a.entryCoordinate)
        #expect(abs(c.latitude - 12.035237) < 1e-4)
        #expect(abs(c.longitude - (-68.262683)) < 1e-4)
        #expect(a.profilePoints.contains { $0.tankPressurePSI != nil })
        let sac = try #require(a.avgSAC)
        #expect(sac > 0)
        let rmv = try #require(a.avgRMV)
        #expect(rmv > 0)
    }

    // MARK: - UDDF

    private enum UddfTestXML {
        static let oneDive = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>9</version></generator>
        <divesite>
            <site id="s1">
                <name>Test Wall</name>
                <geography>
                    <location>Bonaire</location>
                    <latitude>12.1</latitude>
                    <longitude>-68.29</longitude>
                </geography>
            </site>
        </divesite>
        <diver>
            <buddy id="b1"><personal><firstname>Ann</firstname><lastname>Bee</lastname></personal></buddy>
        </diver>
        <profiledata>
            <repetitiongroup id="rg1">
            <dive id="d1-uuid">
                <informationbeforedive>
                    <link ref="s1"/>
                    <link ref="b1"/>
                    <surfaceintervalbeforedive>
                        <passedtime>3600</passedtime>
                    </surfaceintervalbeforedive>
                    <datetime>2025-05-09T11:26:28</datetime>
                </informationbeforedive>
                <informationafterdive>
                    <greatestdepth>21.5</greatestdepth>
                    <diveduration>120.0</diveduration>
                    <lowesttemperature>299.15</lowesttemperature>
                </informationafterdive>
                <samples>
                    <waypoint><depth>0</depth><divetime>0</divetime></waypoint>
                    <waypoint><depth>10</depth><divetime>60</divetime><temperature>301.15</temperature></waypoint>
                </samples>
            </dive>
            </repetitiongroup>
        </profiledata>
        </uddf>
        """

        /// **`tankdata`** + waypoint **`tankpressure`** (MacDive-style Pa values).
        static let oneDiveWithTank = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>9</version></generator>
        <divesite>
            <site id="s1">
                <name>Test Wall</name>
                <geography>
                    <location>Bonaire</location>
                    <latitude>12.1</latitude>
                    <longitude>-68.29</longitude>
                </geography>
            </site>
        </divesite>
        <diver>
            <buddy id="b1"><personal><firstname>Ann</firstname><lastname>Bee</lastname></personal></buddy>
        </diver>
        <gasdefinitions>
            <mix id="mix-1">
                <name>EAN33</name>
                <o2>0.33</o2>
                <n2>0.67</n2>
                <he>0.00</he>
            </mix>
        </gasdefinitions>
        <profiledata>
            <repetitiongroup id="rg1">
            <dive id="d1-uuid">
                <informationbeforedive>
                    <link ref="s1"/>
                    <link ref="b1"/>
                    <datetime>2025-05-09T11:26:28</datetime>
                </informationbeforedive>
                <informationafterdive>
                    <greatestdepth>21.5</greatestdepth>
                    <diveduration>120.0</diveduration>
                    <lowesttemperature>299.15</lowesttemperature>
                </informationafterdive>
                <tankdata>
                    <link ref="mix-1"/>
                    <tankmaterial>steel</tankmaterial>
                    <tankvolume>0.080</tankvolume>
                    <tankpressurebegin>21242747.21</tankpressurebegin>
                    <tankpressureend>8921815.93</tankpressureend>
                </tankdata>
                <samples>
                    <waypoint><depth>0</depth><divetime>0</divetime></waypoint>
                    <waypoint><depth>10</depth><divetime>60</divetime><temperature>301.15</temperature><tankpressure>21241999.83</tankpressure></waypoint>
                </samples>
            </dive>
            </repetitiongroup>
        </profiledata>
        </uddf>
        """

        static let twoDives = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>1</version></generator>
        <divesite><site id="s1"><name>Site</name><geography><latitude>1</latitude><longitude>2</longitude></geography></site></divesite>
        <profiledata><repetitiongroup id="rg">
        <dive id="d-newer">
            <informationbeforedive><link ref="s1"/><datetime>2025-06-01T12:00:00</datetime></informationbeforedive>
            <informationafterdive><greatestdepth>5</greatestdepth><diveduration>60</diveduration></informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive>
        <dive id="d-older">
            <informationbeforedive><link ref="s1"/><datetime>2025-05-01T12:00:00</datetime></informationbeforedive>
            <informationafterdive><greatestdepth>4</greatestdepth><diveduration>60</diveduration></informationafterdive>
            <samples><waypoint><depth>4</depth><divetime>0</divetime></waypoint></samples>
        </dive>
        </repetitiongroup></profiledata>
        </uddf>
        """
    }

    @Test func uddfDecoder_minimal_buildsOneDive() throws {
        let data = Data(UddfTestXML.oneDive.utf8)
        let dives = try UddfDiveFileDecoder.buildDiveActivities(from: data)
        #expect(dives.count == 1)
        let d = try #require(dives.first)
        #expect(d.deviceSource == .macDive)
        #expect(d.sourceDiveId == "d1-uuid")
        #expect(d.siteName == "Test Wall")
        #expect(d.locationName == "Bonaire")
        #expect(d.maxDepthMeters >= 21.5)
        #expect(d.durationMinutes == 2)
        #expect(d.buddies.count == 1)
        #expect(d.buddies[0].displayName == "Ann Bee")
        #expect(d.rawImportVersion?.contains("UDDF-3.2.1") == true)
        #expect(d.rawImportVersion?.contains("TestGen") == true)
        #expect(d.profilePoints.count == 2)
        #expect(d.bottomTimeSeconds == 120)
        #expect(d.surfaceIntervalSeconds == 3600)
        let minW = try #require(d.waterTempMinCelsius)
        #expect(abs(minW - 26.0) < 0.05)
        let secondPoint = try #require(d.profilePoints.sorted { $0.timestamp < $1.timestamp }.last)
        #expect(secondPoint.depthMeters == 10)
        let temp = try #require(secondPoint.temperatureCelsius)
        #expect(abs(temp - 28.0) < 0.1)
        #expect(secondPoint.tankPressurePSI == nil)
    }

    @Test func uddfDecoder_oneDiveWithTank_mapsTankFieldsAndWaypointPressure() throws {
        let data = Data(UddfTestXML.oneDiveWithTank.utf8)
        let dives = try UddfDiveFileDecoder.buildDiveActivities(from: data)
        let d = try #require(dives.first)
        #expect(d.gasType == "Nitrox")
        #expect(d.oxygenMix == 33)
        #expect(d.tankHeroGasMixLabel == "Nitrox 33%")
        #expect(d.tankMaterial == "steel")
        #expect(d.tankVolumeDescription == DefaultTankSize.al80.specification.storedDescription)
        #expect(d.tankMaterial == "steel")
        let startExpected = try #require(UddfTankPressureConversion.psi(fromPascals: 21_242_747.21))
        let endExpected = try #require(UddfTankPressureConversion.psi(fromPascals: 8_921_815.93))
        let waypointExpected = try #require(UddfTankPressureConversion.psi(fromPascals: 21_241_999.83))
        let startPSI = try #require(d.tankPressureStartPSI)
        let endPSI = try #require(d.tankPressureEndPSI)
        #expect(abs(startPSI - startExpected) < 1e-6)
        #expect(abs(endPSI - endExpected) < 1e-6)
        let sorted = d.profilePoints.sorted { $0.timestamp < $1.timestamp }
        #expect(sorted[0].tankPressurePSI == nil)
        let p1psi = try #require(sorted[1].tankPressurePSI)
        #expect(abs(p1psi - waypointExpected) < 1e-6)
        let sac = try #require(d.avgSAC)
        #expect(sac > 0)
        let rmv = try #require(d.avgRMV)
        #expect(rmv > 0)
    }

    @Test func uddfTankPressureConversion_macDiveSamplePascals() throws {
        let pascals = 21_242_747.21
        let psi = try #require(UddfTankPressureConversion.psi(fromPascals: pascals))
        #expect(abs(psi - 3080.999998513114) < 0.0001)
        #expect(UddfTankPressureConversion.psi(fromPascals: nil) == nil)
        #expect(UddfTankPressureConversion.psi(fromPascals: -1) == nil)
    }

    @Test func uddfTankVolumeFormatting_sample() {
        #expect(UddfTankVolumeFormatting.volumeDescription(fromCubicMeters: 0.080) == "80 L (0.080 m³)")
        #expect(UddfTankVolumeFormatting.volumeDescription(fromCubicMeters: nil) == nil)
    }

    @Test func uddfDecoder_twoDives_sortedOldestFirst() throws {
        let data = Data(UddfTestXML.twoDives.utf8)
        let dives = try UddfDiveFileDecoder.buildDiveActivities(from: data)
        #expect(dives.count == 2)
        #expect(dives[0].startTime < dives[1].startTime)
        #expect(dives[0].sourceDiveId == "d-older")
        #expect(dives[1].sourceDiveId == "d-newer")
        #expect(dives[0].bottomTimeSeconds == 60)
        #expect(dives[1].bottomTimeSeconds == 60)
    }

    @Test func uddfDecoder_empty_throws() {
        #expect(throws: UddfDecodeError.self) {
            try UddfDiveFileDecoder.buildDiveActivities(from: Data())
        }
    }

    @Test func uddfParseDate_parsesNaiveISO() throws {
        let d = try #require(UddfDiveFileDecoder.parseUddfDate("2025-05-09T11:26:28"))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        #expect(cal.component(.year, from: d) == 2025)
        #expect(cal.component(.month, from: d) == 5)
        #expect(cal.component(.day, from: d) == 9)
    }

    @Test func diveFileImportSuccess_matchesFitAndMultiUddf() {
        #expect(DiveFileImportSuccess.matches("\(FitDiveFileImport.importSuccessMessagePrefix) starting test."))
        #expect(DiveFileImportSuccess.matches("Imported 3 dives."))
        #expect(!DiveFileImportSuccess.matches("Could not read UDDF XML: broken"))
    }

    @Test func diveFileImportOutcome_didSucceed_matchesDiveFileImportSuccess() {
        let msg = "\(FitDiveFileImport.importSuccessMessagePrefix) starting today."
        let outcome = DiveFileImportOutcome(userMessage: msg, primaryInsertedDiveId: UUID())
        #expect(outcome.didSucceed == DiveFileImportSuccess.matches(msg))
        let fail = DiveFileImportOutcome(userMessage: "nope", primaryInsertedDiveId: nil)
        #expect(fail.didSucceed == DiveFileImportSuccess.matches("nope"))
    }

    @Test @MainActor
    func uddfImport_withoutOwner_returnsSignInMessage() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let data = Data(UddfTestXML.oneDive.utf8)
        let outcome = UddfDiveFileImport.importUddfData(data, modelContext: context)
        #expect(!outcome.didSucceed)
        #expect(outcome.userMessage == "Sign in to import dives.")
    }

    @Test @MainActor
    func uddfImport_twoDives_insertsBoth() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "test-uddf-import", displayName: "Import Test")
        context.insert(owner)
        try context.save()
        let data = Data(UddfTestXML.twoDives.utf8)
        let outcome = UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
        #expect(outcome.didSucceed)
        let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(fetched.count == 2)
        let newer = try #require(fetched.first { $0.sourceDiveId == "d-newer" })
        #expect(outcome.primaryInsertedDiveId == newer.id)
    }

    @Test @MainActor
    func diveActivityDeletion_removesActivityAndCascadedBuddy() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let activity = DiveActivity(
            deviceSource: .manual,
            startTime: .now,
            durationMinutes: 12,
            maxDepthMeters: 18
        )
        let buddy = DiveBuddyTag(displayName: "Pat")
        buddy.dive = activity
        activity.buddies.append(buddy)
        context.insert(activity)
        try context.save()

        try await DiveActivityDeletion.deletePermanently(activity, modelContext: context)

        let dives = try context.fetch(FetchDescriptor<DiveActivity>())
        let buddies = try context.fetch(FetchDescriptor<DiveBuddyTag>())
        #expect(dives.isEmpty)
        #expect(buddies.isEmpty)
    }

    @Test func logbookRow_displayName_usesTrimmedSiteElseNewDive() {
        let named = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(),
            durationMinutes: 10,
            maxDepthMeters: 5,
            siteName: "  Wall  "
        )
        #expect(LogbookActivityRow.displayName(for: named) == "Wall")

        let noSite = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(),
            durationMinutes: 10,
            maxDepthMeters: 5
        )
        #expect(LogbookActivityRow.displayName(for: noSite) == "New Dive")
    }

    // MARK: - Duplicate dive matching

    @Test func diveActivityDuplicateMatcher_sameSourceDiveId() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let a = DiveActivityDuplicateMatcher.Signature(
            DiveActivity(
                deviceSource: .macDive,
                sourceDiveId: "d1-uuid",
                startTime: start,
                durationMinutes: 40,
                maxDepthMeters: 20
            )
        )
        let b = DiveActivityDuplicateMatcher.Signature(
            DiveActivity(
                deviceSource: .macDive,
                sourceDiveId: "d1-uuid",
                startTime: start.addingTimeInterval(3600),
                durationMinutes: 99,
                maxDepthMeters: 99
            )
        )
        #expect(DiveActivityDuplicateMatcher.matchReason(candidate: a, existing: b) == .sameSourceDiveId)
    }

    @Test func diveActivityDuplicateMatcher_fingerprint_crossFormat() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let garmin = DiveActivityDuplicateMatcher.Signature(
            DiveActivity(
                deviceSource: .garminMK3,
                sourceDiveId: "fit-1-2-3",
                startTime: start,
                durationMinutes: 45,
                maxDepthMeters: 18.2,
                bottomTimeSeconds: 2700
            )
        )
        let mac = DiveActivityDuplicateMatcher.Signature(
            DiveActivity(
                deviceSource: .macDive,
                sourceDiveId: "uddf-uuid",
                startTime: start.addingTimeInterval(30),
                durationMinutes: 45,
                maxDepthMeters: 18.0,
                bottomTimeSeconds: 2701
            )
        )
        #expect(DiveActivityDuplicateMatcher.matchReason(candidate: garmin, existing: mac) == .matchingFingerprint)
    }

    @Test func diveActivityDuplicateMatcher_differentStartTimes_noMatch() {
        let a = DiveActivityDuplicateMatcher.Signature(
            DiveActivity(
                deviceSource: .garminMK3,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 45,
                maxDepthMeters: 18,
                bottomTimeSeconds: 2700
            )
        )
        let b = DiveActivityDuplicateMatcher.Signature(
            DiveActivity(
                deviceSource: .macDive,
                startTime: Date(timeIntervalSince1970: 1_800_000_000),
                durationMinutes: 45,
                maxDepthMeters: 18,
                bottomTimeSeconds: 2700
            )
        )
        #expect(DiveActivityDuplicateMatcher.matchReason(candidate: a, existing: b) == nil)
    }

    @Test func diveActivityDuplicateMatcher_idsWithDuplicates_marksBoth() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let sigs = [
            DiveActivityDuplicateMatcher.Signature(
                DiveActivity(
                    deviceSource: .garminMK3,
                    sourceDiveId: "fit-a",
                    startTime: start,
                    durationMinutes: 30,
                    maxDepthMeters: 15,
                    bottomTimeSeconds: 1800
                )
            ),
            DiveActivityDuplicateMatcher.Signature(
                DiveActivity(
                    deviceSource: .macDive,
                    sourceDiveId: "uddf-b",
                    startTime: start,
                    durationMinutes: 30,
                    maxDepthMeters: 15.2,
                    bottomTimeSeconds: 1800
                )
            ),
        ]
        let ids = DiveActivityDuplicateMatcher.idsWithDuplicates(in: sigs)
        #expect(ids.count == 2)
    }

    @Test @MainActor
    func uddfImport_secondImportOfSameFile_blockedAsDuplicate() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "test-uddf-dup", displayName: "Dup Test")
        context.insert(owner)
        try context.save()
        let data = Data(UddfTestXML.oneDive.utf8)
        let first = UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
        #expect(first.didSucceed)
        let second = UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
        #expect(!second.didSucceed)
        #expect(second.userMessage.contains("already in your log"))
        let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(fetched.count == 1)
    }

    @Test @MainActor
    func diveActivityDiveNumbering_assignNextChained_firstDiveIsOne() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let newDive = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 5,
            maxDepthMeters: 10
        )
        try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: newDive, modelContext: context)
        #expect(newDive.diveNumber == 1)
    }

    @Test @MainActor
    func diveActivityDiveNumbering_assignNextChained_ignoresPresetWhenStoreEmpty() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let imported = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(),
            durationMinutes: 5,
            maxDepthMeters: 10,
            diveNumber: 99
        )
        try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: imported, modelContext: context)
        #expect(imported.diveNumber == 1)
    }

    @Test @MainActor
    func diveActivityDiveNumbering_assignNextChained_oneMoreThanNewestByDate() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let oldest = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let newest = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
        context.insert(oldest)
        context.insert(newest)
        try context.save()

        let incoming = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(timeIntervalSince1970: 200_000),
            durationMinutes: 5,
            maxDepthMeters: 10
        )
        try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: incoming, modelContext: context)
        #expect(incoming.diveNumber == 4)
    }

    @Test @MainActor
    func diveActivityDiveNumbering_assignNextChained_whenNewestHasNilUsesMaxOthers() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let older = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 5)
        let newestNoNumber = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
        context.insert(older)
        context.insert(newestNoNumber)
        try context.save()

        let incoming = DiveActivity(
            deviceSource: .garminMK3,
            startTime: Date(timeIntervalSince1970: 200_000),
            durationMinutes: 5,
            maxDepthMeters: 10
        )
        try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: incoming, modelContext: context)
        #expect(incoming.diveNumber == 6)
    }

    @Test func diveActivity_diveNumberLogbookLabel_numberOrHyphen() {
        let numbered = DiveActivity(deviceSource: .manual, startTime: Date(), durationMinutes: 1, maxDepthMeters: 1, diveNumber: 7)
        #expect(numbered.diveNumberLogbookLabel == "#7")

        let unset = DiveActivity(deviceSource: .manual, startTime: Date(), durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
        #expect(unset.diveNumberLogbookLabel == "-")
    }

    @Test func diveActivity_gasDetailsLines_trimAndDash() {
        let emptyStrings = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 1,
            maxDepthMeters: 1,
            tankMaterial: "   ",
            tankVolumeDescription: "\n\t"
        )
        #expect(emptyStrings.gasDetailsTankTypeLine() == "aluminum")
        #expect(emptyStrings.gasDetailsTankVolumeLine(displayUnits: .metric) == "2265 L")
        #expect(emptyStrings.gasDetailsTankVolumeLine(displayUnits: .imperial) == "80 cu ft")
        #expect(emptyStrings.gasDetailsBeginningPressureLine(displayUnits: .imperial) == "—")
        #expect(emptyStrings.gasDetailsEndingPressureLine(displayUnits: .imperial) == "—")

        let filled = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 1,
            maxDepthMeters: 1,
            tankMaterial: "  steel  ",
            tankVolumeDescription: "12 L",
            tankPressureStartPSI: 2999.6,
            tankPressureEndPSI: 800.2
        )
        #expect(filled.gasDetailsTankTypeLine() == "steel")
        #expect(filled.gasDetailsTankVolumeLine(displayUnits: .metric) == "2265 L")
        #expect(filled.gasDetailsTankVolumeLine(displayUnits: .imperial) == "80 cu ft")
        #expect(filled.gasDetailsBeginningPressureLine(displayUnits: .imperial) == "3000 psi")
        #expect(filled.gasDetailsEndingPressureLine(displayUnits: .imperial) == "800 psi")
        #expect(filled.gasDetailsBeginningPressureLine(displayUnits: .metric) == "206.8 bar")
        #expect(filled.gasDetailsEndingPressureLine(displayUnits: .metric) == "55.2 bar")
    }

    @Test func diveQuantityFormatting_depth_temperature_tankVolume() {
        #expect(DiveQuantityFormatting.depth(meters: 10, system: .metric) == "10.0 m")
        #expect(DiveQuantityFormatting.depth(meters: 1, system: .imperial) == "3.3 ft")

        #expect(DiveQuantityFormatting.waterTemperature(celsius: 0, system: .metric) == "0.0 °C")
        #expect(DiveQuantityFormatting.waterTemperature(celsius: 100, system: .imperial) == "212.0 °F")
        #expect(DiveQuantityFormatting.waterTemperature(celsius: nil, system: .metric) == "—")

        #expect(DiveQuantityFormatting.tankVolumeDisplay(system: .imperial) == "80 cu ft")
        #expect(DiveQuantityFormatting.tankVolumeDisplay(system: .metric) == "2265 L")
        #expect(DiveQuantityFormatting.firstLitersValue(in: "80 L (0.080 m³)") == 80)
        #expect(DiveQuantityFormatting.firstLitersValue(in: "no liters here") == nil)
    }

    @Test func defaultTankSize_specifications() {
        #expect(DefaultTankSize.al80.ratedVolumeCubicFeet == 80)
        #expect(DefaultTankSize.al80.materialLabel == "aluminum")
        #expect(DefaultTankSize.al63.ratedVolumeCubicFeet == 63)
        #expect(DefaultTankSize.st100.materialLabel == "steel")
        #expect(DefaultTankSize.st120.ratedVolumeCubicFeet == 120)
        #expect(DefaultTankSize.st120.specification.storedDescription == "120 cu ft (ST120)")
    }

    @Test func diveActivityTankDefaults_respectsUserDefaults() {
        let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DefaultTank")!
        defaults.removePersistentDomain(forName: "GoDiveMVPTests.DefaultTank")
        defaults.set(DefaultTankSize.st120.rawValue, forKey: AppUserSettings.defaultTankSizeKey)

        let spec = DiveActivityTankDefaults.resolvedSpecification(userDefaults: defaults)
        #expect(spec.size == .st120)
        #expect(DiveQuantityFormatting.tankVolumeDisplay(system: .imperial, specification: spec) == "120 cu ft")
        #expect(DiveSACRMVCalculation.ratedTankVolumeLiters(from: nil, userDefaults: defaults) == spec.ratedVolumeSurfaceLiters)

        let activity = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 1,
            maxDepthMeters: 1
        )
        #expect(activity.gasDetailsTankTypeLine(defaultSpecification: spec) == "steel")
        #expect(activity.gasDetailsTankVolumeLine(displayUnits: .metric, defaultSpecification: spec) == "3398 L")
    }

    @Test func diveActivityUserFieldTypes_displayTitles() {
        #expect(DiveCurrentStrength.none.displayTitle == "None")
        #expect(DiveVisibilityRating.great.displayTitle == "Great")
    }

    @Test @MainActor
    func diveActivity_resolvedDiveCurrentStrength_defaultsToNoneWhenNil() {
        let activity = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 1,
            maxDepthMeters: 10
        )
        #expect(activity.diveCurrentStrength == nil)
        #expect(activity.resolvedDiveCurrentStrength == .none)
    }

    @Test @MainActor
    func diveActivity_persistsUserLogFields() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let activity = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18,
            diveCurrentStrength: .medium,
            surfaceCondition: "Calm",
            entryType: "Boat",
            diveVisibility: .good,
            diveOperatorName: "Coral Reef Divers",
            diveMasterName: "Alex"
        )
        context.insert(activity)
        try context.save()

        let id = activity.id
        let descriptor = FetchDescriptor<DiveActivity>(predicate: #Predicate { $0.id == id })
        let fetched = try #require(try context.fetch(descriptor).first)
        #expect(fetched.diveCurrentStrength == .medium)
        #expect(fetched.resolvedDiveCurrentStrength == .medium)
        #expect(fetched.surfaceCondition == "Calm")
        #expect(fetched.entryType == "Boat")
        #expect(fetched.diveVisibility == .good)
        #expect(fetched.diveOperatorName == "Coral Reef Divers")
        #expect(fetched.diveMasterName == "Alex")
    }

    @Test @MainActor func diveActivityDetailsPresentation_includesAllModelFieldGroups() {
        let activity = DiveActivity(
            deviceSource: .macDive,
            sourceDiveId: "uddf-1",
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 45,
            maxDepthMeters: 22,
            averageDepthMeters: 14,
            bottomTimeSeconds: 2400,
            surfaceIntervalSeconds: 1800,
            diveNumber: 12,
            waterTempAvgCelsius: 27,
            siteName: "Salt Pier",
            locationName: "Bonaire",
            tankPressureStartPSI: 3000,
            tankPressureEndPSI: 1200,
            gasType: "Nitrox",
            oxygenMix: 32,
            avgSAC: 20,
            avgRMV: 16,
            rawImportVersion: "MacDive UDDF"
        )
        activity.buddies.append(DiveBuddyTag(displayName: "Jamie"))
        let titles = DiveActivityDetailsPresentation.sections(for: activity, displayUnits: .metric).map(\.title)
        #expect(titles.contains("Dive"))
        #expect(titles.contains("Location"))
        #expect(titles.contains("Gas & cylinder"))
        #expect(titles.contains("Buddies"))
        #expect(titles.contains("Source & import"))
        #expect(titles.contains("Record"))
        let labels = Set(DiveActivityDetailsPresentation.sections(for: activity, displayUnits: .metric).flatMap(\.rows).map(\.label))
        #expect(labels.contains("Max depth"))
        #expect(labels.contains("Beginning pressure"))
        #expect(labels.contains("Source dive ID"))
    }

    @Test func appUserSettings_defaultTankSize_fallsBackToAL80() {
        let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DefaultTankFallback")!
        defaults.removePersistentDomain(forName: "GoDiveMVPTests.DefaultTankFallback")
        defaults.set("INVALID", forKey: AppUserSettings.defaultTankSizeKey)
        let spec = DiveActivityTankDefaults.resolvedSpecification(userDefaults: defaults)
        #expect(spec.size == .al80)
    }

    @Test func diveActivityDiveNumbering_nextChained_skipsExplicitNoneMidSequence() {
        let t0 = Date(timeIntervalSince1970: 10_000)
        let t1 = t0.addingTimeInterval(1_000)
        let t2 = t0.addingTimeInterval(2_000)
        let t3 = t0.addingTimeInterval(3_000)
        let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let b = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        let c = DiveActivity(deviceSource: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
        let d = DiveActivity(deviceSource: .manual, startTime: t3, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
        d.diveNumberExplicitlyNone = true
        let n = DiveActivityDiveNumbering.nextChainedDiveNumberForNewImport(existingDives: [a, b, c, d])
        #expect(n == 4)
    }

    @Test func diveActivityDiveNumbering_nextChained_afterOnlyExplicitNoneRowsIsOne() {
        let t0 = Date(timeIntervalSince1970: 50_000)
        let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
        a.diveNumberExplicitlyNone = true
        #expect(DiveActivityDiveNumbering.nextChainedDiveNumberForNewImport(existingDives: [a]) == 1)
    }

    @Test @MainActor
    func diveActivityDiveNumbering_backfill_skipsExplicitNone() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let explicitNone = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
        explicitNone.diveNumberExplicitlyNone = true
        let legacyNil = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
        context.insert(explicitNone)
        context.insert(legacyNil)
        try context.save()

        try DiveActivityDiveNumbering.backfillMissingDiveNumbers(modelContext: context)

        #expect(explicitNone.diveNumber == nil)
        #expect(explicitNone.diveNumberExplicitlyNone == true)
        #expect(legacyNil.diveNumber == 2)
    }

    @Test @MainActor
    func diveActivityDiveNumbering_renumberAllChronologically_rewritesPersisted() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let a = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
        let b = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        context.insert(a)
        context.insert(b)
        try context.save()

        try DiveActivityDiveNumbering.renumberAllChronologically(modelContext: context)

        #expect(b.diveNumber == 1)
        #expect(a.diveNumber == 2)
    }

    @Test @MainActor
    func diveActivityDiveNumbering_applyAutomaticSequentialRenumberIfNeeded_respectsSettings() throws {
        let key = AppUserSettings.automaticallyRenumberDivesKey
        let prior = UserDefaults.standard.object(forKey: key)
        defer {
            if let prior {
                UserDefaults.standard.set(prior, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let a = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 9)
        let b = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 8)
        context.insert(a)
        context.insert(b)
        try context.save()

        UserDefaults.standard.set(false, forKey: key)
        try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: context)
        #expect(b.diveNumber == 8)
        #expect(a.diveNumber == 9)

        UserDefaults.standard.set(true, forKey: key)
        try DiveActivityDiveNumbering.applyAutomaticSequentialRenumberIfNeeded(modelContext: context)
        #expect(b.diveNumber == 1)
        #expect(a.diveNumber == 2)
    }

    @Test @MainActor
    func diveActivityDeletion_deletePermanently_nilOverride_usesUserDefaultsRenumber() async throws {
        let key = AppUserSettings.automaticallyRenumberDivesKey
        let prior = UserDefaults.standard.object(forKey: key)
        defer {
            if let prior {
                UserDefaults.standard.set(prior, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        UserDefaults.standard.set(true, forKey: key)

        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let toDelete = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let remaining = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        context.insert(toDelete)
        context.insert(remaining)
        try context.save()

        try await DiveActivityDeletion.deletePermanently(
            toDelete,
            modelContext: context,
            awaitPostDeleteRenumber: true
        )

        let dives = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(dives.count == 1)
        #expect(remaining.diveNumber == 1)
    }

    @Test @MainActor
    func diveActivityDeletion_withoutRenumber_leavesOtherDiveNumber() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let toDelete = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let remaining = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        context.insert(toDelete)
        context.insert(remaining)
        try context.save()

        try await DiveActivityDeletion.deletePermanently(toDelete, modelContext: context, applySequentialRenumberOverride: false)

        let dives = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(dives.count == 1)
        #expect(remaining.diveNumber == 2)
    }

    @Test @MainActor
    func diveActivityDeletion_withRenumber_collapsesNumbers() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let toDelete = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let remaining = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        context.insert(toDelete)
        context.insert(remaining)
        try context.save()

        try await DiveActivityDeletion.deletePermanently(
            toDelete,
            modelContext: context,
            applySequentialRenumberOverride: true,
            awaitPostDeleteRenumber: true
        )

        let dives = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(dives.count == 1)
        #expect(remaining.diveNumber == 1)
    }

    @Test @MainActor
    func diveActivityDeletion_renumberAfterDelete_onlyRenumbersNewerDives() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let t2 = Date(timeIntervalSince1970: 172_800)
        let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let b = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        let c = DiveActivity(deviceSource: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
        context.insert(a)
        context.insert(b)
        context.insert(c)
        try context.save()

        try await DiveActivityDeletion.deletePermanently(
            b,
            modelContext: context,
            applySequentialRenumberOverride: true,
            awaitPostDeleteRenumber: true
        )

        #expect(a.diveNumber == 1)
        #expect(c.diveNumber == 2)
    }

    @Test func diveLogbookDisplay_chronologicalNumbers_whenAutoRenumberEnabled() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let t2 = Date(timeIntervalSince1970: 172_800)
        let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
        let b = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
        let c = DiveActivity(deviceSource: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)

        let rows = DiveLogbookDisplay.rowData(
            activities: [c, b, a],
            unitSystem: .metric,
            duplicateIds: [],
            useChronologicalNumbers: true
        )
        let byId = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.diveNumberLabel) })
        #expect(byId[a.id] == "#1")
        #expect(byId[b.id] == "#2")
        #expect(byId[c.id] == "#3")
    }

    @Test func diveLogbookDisplay_usesPersistedNumber_whenChronologicalDisabled() {
        let a = DiveActivity(
            deviceSource: .manual,
            startTime: Date(),
            durationMinutes: 1,
            maxDepthMeters: 1,
            diveNumber: 7
        )
        let rows = DiveLogbookDisplay.rowData(
            activities: [a],
            unitSystem: .metric,
            duplicateIds: [],
            useChronologicalNumbers: false
        )
        #expect(rows.first?.diveNumberLabel == "#7")
    }

    @Test func diveActivityPostDeleteRenumbering_partialRenumberOnBackgroundContext() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let t2 = Date(timeIntervalSince1970: 172_800)

        let deletedId = try await MainActor.run { () throws -> UUID in
            let context = ModelContext(container)
            let a = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let b = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
            let c = DiveActivity(deviceSource: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
            context.insert(a)
            context.insert(b)
            context.insert(c)
            try context.save()
            let deletedId = b.id
            context.delete(b)
            try context.save()
            return deletedId
        }

        try await DiveActivityPostDeleteRenumbering.renumberAfterDelete(
            container: container,
            deletedStartTime: t1,
            deletedId: deletedId
        )

        let numbers = try await MainActor.run { () throws -> (Int?, Int?) in
            let context = ModelContext(container)
            let all = try context.fetch(FetchDescriptor<DiveActivity>())
            let sorted = all.sorted { $0.startTime < $1.startTime }
            #expect(sorted.count == 2)
            return (sorted[0].diveNumber, sorted[1].diveNumber)
        }
        #expect(numbers.0 == 1)
        #expect(numbers.1 == 2)
    }

    @Test @MainActor
    func diveActivityDeletion_deferredRenumber_preservesNumbersUntilBackgroundPass() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let toDelete = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
        let remaining = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
        context.insert(toDelete)
        context.insert(remaining)
        try context.save()

        try await DiveActivityDeletion.deletePermanently(
            toDelete,
            modelContext: context,
            applySequentialRenumberOverride: true,
            awaitPostDeleteRenumber: false
        )

        let divesAfterDelete = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(divesAfterDelete.count == 1)
        #expect(remaining.diveNumber == 2)

        // Background renumber persists via **`@ModelActor`**; poll the store (fresh context), not the pre-delete **`remaining`** instance.
        let remainingId = remaining.id
        var persistedNumber: Int?
        for _ in 0 ..< 100 {
            persistedNumber = try Self.persistedDiveNumber(id: remainingId, container: container)
            if persistedNumber == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(persistedNumber == 1)
    }

    /// Reads **`diveNumber`** from a new **`ModelContext`** so background **`@ModelActor`** saves are visible in tests.
    private static func persistedDiveNumber(id: UUID, container: ModelContainer) throws -> Int? {
        let readContext = ModelContext(container)
        let all = try readContext.fetch(FetchDescriptor<DiveActivity>())
        return all.first { $0.id == id }?.diveNumber
    }

    @Test @MainActor
    func diveActivityDiveNumbering_backfillFillsNilRows() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let a = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1)
        let b = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1)
        context.insert(a)
        context.insert(b)
        try context.save()

        try DiveActivityDiveNumbering.backfillMissingDiveNumbers(modelContext: context)

        #expect(b.diveNumber == 1)
        #expect(a.diveNumber == 2)
    }

    @Test func diveActivityDiveNumbering_sequentialIndices_ordersOldestFirst() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 86_400)
        let t2 = Date(timeIntervalSince1970: 172_800)

        let oldest = DiveActivity(deviceSource: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1)
        let mid = DiveActivity(deviceSource: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1)
        let newest = DiveActivity(deviceSource: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1)

        let shuffled = [newest, oldest, mid]
        let map = DiveActivityDiveNumbering.sequentialIndicesById(for: shuffled)

        #expect(map[oldest.id] == 1)
        #expect(map[mid.id] == 2)
        #expect(map[newest.id] == 3)
    }

    @Test func diveActivityDiveNumbering_sequentialIndices_emptyReturnsEmpty() {
        #expect(DiveActivityDiveNumbering.sequentialIndicesById(for: []).isEmpty)
    }

    // MARK: - Water bubble rendering (legacy `BrandAnimations` bubble math)

    @Test func waterBubbleRendering_opacities_outerIsThirdOfInner() {
        let (inner, outer) = WaterBubbleRendering.bubbleOpacities(hash: 0.37)
        #expect(abs(inner - (0.1 + 0.2 * 0.37)) < 0.000_001)
        #expect(abs(outer - inner * 0.3) < 0.000_001)
    }

    @Test func waterBubbleRendering_opacities_stayInLegacyRanges() {
        for step in 0..<11 {
            let h = CGFloat(step) / 10
            let (inner, outer) = WaterBubbleRendering.bubbleOpacities(hash: h)
            #expect(inner >= 0.1 - 0.000_001 && inner <= 0.3 + 0.000_001)
            #expect(outer <= inner + 0.000_001)
        }
    }

    @Test func waterBubbleRendering_diameter_clampedToMinSideCap() {
        #expect(WaterBubbleRendering.bubbleDiameterPoints(minSide: 200, hash: 0) == 18)
        #expect(WaterBubbleRendering.bubbleDiameterPoints(minSide: 200, hash: 1) == 44)
    }

    @Test func waterBubbleRendering_scale_lerpsFromStartToOnePointTwo() {
        let s0 = WaterBubbleRendering.bubbleScale(progress: 0, travel: 500, hash: 0)
        let mid = WaterBubbleRendering.bubbleScale(progress: 250, travel: 500, hash: 0)
        let s1 = WaterBubbleRendering.bubbleScale(progress: 500, travel: 500, hash: 0)
        #expect(abs(s0 - 0.5) < 0.000_001)
        #expect(mid > s0 && mid < 1.2)
        #expect(abs(s1 - 1.2) < 0.000_001)
    }

    @Test func waterBubbleRendering_paletteIndex_inRange() {
        for step in 0..<30 {
            let h = CGFloat(step) / 29
            let idx = WaterBubbleRendering.paletteIndex(hash: h)
            #expect(idx >= 0 && idx < WaterBubbleRendering.paletteCount)
        }
    }

    @Test func appHeaderMetrics_heightKey_reduceUsesMax() {
        var value: CGFloat = 2
        AppHeaderMetrics.HeightKey.reduce(value: &value) { 5 }
        #expect(value == 5)
        AppHeaderMetrics.HeightKey.reduce(value: &value) { 3 }
        #expect(value == 5)
    }

    #if os(iOS)
    /// Regression guard for hidden navigation bar + interactive pop: delegate must allow begin when stack depth > 1.
    @Test @MainActor
    func navigation_popGestureDelegateAllowsBeginWhenStackHasMoreThanOne() {
        let nav = UINavigationController(rootViewController: UIViewController())
        guard let pop = nav.interactivePopGestureRecognizer else {
            Issue.record("Expected interactivePopGestureRecognizer on UINavigationController")
            return
        }
        pop.delegate = nav
        #expect(nav.gestureRecognizerShouldBegin(pop) == false)

        nav.pushViewController(UIViewController(), animated: false)
        #expect(nav.gestureRecognizerShouldBegin(pop) == true)
    }

    @Test @MainActor
    func navigation_popGestureAllowsSimultaneousRecognitionWithScrollPan() {
        let nav = UINavigationController(rootViewController: UIViewController())
        nav.pushViewController(UIViewController(), animated: false)
        guard let pop = nav.interactivePopGestureRecognizer else {
            Issue.record("Expected interactivePopGestureRecognizer on UINavigationController")
            return
        }
        pop.delegate = nav
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let scrollPan = scroll.panGestureRecognizer
        #expect(nav.gestureRecognizer(pop, shouldRecognizeSimultaneouslyWith: scrollPan))
        #expect(nav.gestureRecognizer(scrollPan, shouldRecognizeSimultaneouslyWith: pop))
    }

    @Test func leadingEdgeSwipePopGate_commitsWhenHorizontalSwipeFromEdge() {
        #expect(
            GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                startLocationX: 8,
                translation: CGSize(width: 100, height: 20)
            )
        )
    }

    @Test func leadingEdgeSwipePopGate_rejectsWhenTooFarFromLeading() {
        #expect(
            !GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                startLocationX: 200,
                translation: CGSize(width: 100, height: 20)
            )
        )
    }

    @Test func leadingEdgeSwipePopGate_rejectsWhenHorizontalDragTooShort() {
        #expect(
            !GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                startLocationX: 10,
                translation: CGSize(width: 40, height: 10)
            )
        )
    }

    @Test func leadingEdgeSwipePopGate_rejectsWhenVerticalDominant() {
        #expect(
            !GoDiveLeadingEdgeSwipePopGate.shouldCommitPop(
                startLocationX: 10,
                translation: CGSize(width: 100, height: 200)
            )
        )
    }
    #endif
}
