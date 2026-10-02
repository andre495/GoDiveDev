//
//  TripPlannerTests.swift
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


struct TripPlannerTests {
        @Test func diveTripReminderSchedule_destinationLabel_prefersCountriesThenTitle() {
            #expect(
                DiveTripReminderSchedule.destinationLabel(
                    countries: ["Bonaire", "Curaçao"],
                    title: "Ignore me"
                ) == "Bonaire, Curaçao"
            )
            #expect(
                DiveTripReminderSchedule.destinationLabel(countries: [], title: "Bonaire 2026")
                    == "Bonaire 2026"
            )
            #expect(DiveTripReminderSchedule.destinationLabel(countries: [], title: "  ") == nil)
        }

        @Test func diveTripReminderSchedule_notificationBody_matchesRequestedCopy() {
            #expect(
                DiveTripReminderSchedule.notificationBody(
                    destinationLabel: "Bonaire",
                    offset: .oneMonthPrior
                ) == "Your trip to Bonaire is in 1 month. Almost there!"
            )
            #expect(
                DiveTripReminderSchedule.notificationBody(
                    destinationLabel: "Indonesia, Philippines",
                    offset: .oneWeekPrior
                ) == "Your trip to Indonesia, Philippines is in 1 week. Pack your bags!"
            )
            #expect(
                DiveTripReminderSchedule.notificationBody(
                    destinationLabel: "Maldives",
                    offset: .oneDayPrior
                ) == "Your trip to Maldives is tomorrow!"
            )
            #expect(
                DiveTripReminderSchedule.notificationBody(
                    destinationLabel: nil,
                    offset: .oneWeekPrior
                ) == "Your trip is in 1 week. Pack your bags!"
            )
        }

        @Test func diveTripReminderSchedule_fireDate_offsetsRelativeToStartDay() throws {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = try #require(
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 8))
            )
            let now = try #require(
                calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 12))
            )

            let month = try #require(
                DiveTripReminderSchedule.fireDate(
                    tripStartDate: start,
                    offset: .oneMonthPrior,
                    calendar: calendar,
                    now: now
                )
            )
            #expect(calendar.component(.month, from: month) == 8)
            #expect(calendar.component(.day, from: month) == 20)
            #expect(calendar.component(.hour, from: month) == 9)

            let week = try #require(
                DiveTripReminderSchedule.fireDate(
                    tripStartDate: start,
                    offset: .oneWeekPrior,
                    calendar: calendar,
                    now: now
                )
            )
            #expect(
                calendar.isDate(
                    week,
                    inSameDayAs: try #require(calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: start)))
                )
            )

            let day = try #require(
                DiveTripReminderSchedule.fireDate(
                    tripStartDate: start,
                    offset: .oneDayPrior,
                    calendar: calendar,
                    now: now
                )
            )
            #expect(
                calendar.isDate(
                    day,
                    inSameDayAs: try #require(calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: start)))
                )
            )

            #expect(
                DiveTripReminderSchedule.fireDate(
                    tripStartDate: start,
                    offset: .oneDayPrior,
                    calendar: calendar,
                    now: try #require(calendar.date(byAdding: .day, value: 1, to: start))
                ) == nil
            )
        }

        @Test func diveTripReminderSchedule_tripID_fromUserInfo() {
            let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            let userInfo: [AnyHashable: Any] = [
                DiveTripReminderSchedule.userInfoTypeKey: DiveTripReminderSchedule.userInfoTypeValue,
                DiveTripReminderSchedule.userInfoTripIDKey: id.uuidString,
            ]
            #expect(DiveTripReminderSchedule.tripID(fromUserInfo: userInfo) == id)
            #expect(
                DiveTripReminderSchedule.tripID(fromUserInfo: ["type": "equipment_service_reminder"]) == nil
            )
            #expect(DiveTripReminderSchedule.allNotificationIdentifiers(for: id).count == 3)
        }

        @Test @MainActor
        func diveTripReminderNavigationStore_setAndConsumePending() {
            let store = DiveTripReminderNavigationStore.shared
            store.clear()
            let id = UUID()
            store.setPending(tripID: id)
            #expect(store.pendingTripID == id)
            #expect(store.consumePendingTripID() == id)
            #expect(store.pendingTripID == nil)
        }

        @Test func tripPlannerPresentation_pageTitleAndExploreIcon() {
            #expect(TripPlannerPresentation.pageTitle == "Trips")
            #expect(TripPlannerPresentation.exploreChromeAccessibilityLabel == "Plan a trip")
            #expect(TripPlannerPresentation.exploreChromeSystemImage == "airplane")
            #expect(TripPlannerPresentation.newTripSheetTitle == "Plan a trip")
            #expect(TripPlannerPresentation.addTripDoneAccessibilityIdentifier == "TripAddSheet.Done")
            #expect(TripPlannerPresentation.addTripCancelAccessibilityIdentifier == "TripAddSheet.Cancel")
            #expect(TripPlannerPresentation.addTripBuddiesAccessibilityIdentifier == "TripAddSheet.AddBuddies")
            #expect(TripPlannerPresentation.editTripBuddiesAccessibilityIdentifier == "TripEditSheet.AddBuddies")
            #expect(TripPlannerPresentation.addTripCountriesAccessibilityIdentifier == "TripAddSheet.AddCountries")
            #expect(TripPlannerPresentation.editTripCountriesAccessibilityIdentifier == "TripEditSheet.AddCountries")
            #expect(TripPlannerPresentation.countryPickerCancelAccessibilityIdentifier == "TripCountryPicker.Cancel")
            #expect(TripPlannerPresentation.countryPickerDoneAccessibilityIdentifier == "TripCountryPicker.Done")
            #expect(TripPlannerPresentation.tripNameSectionTitle == "Trip name")
            #expect(TripPlannerPresentation.buddiesSectionTitle == "Buddies")
            #expect(TripPlannerPresentation.addBuddiesButtonTitle == "Add buddies")
            #expect(TripPlannerPresentation.addCountriesButtonTitle == "Add countries")
            #expect(TripPlannerPresentation.editTripDoneAccessibilityIdentifier == "TripEditSheet.Done")
            #expect(TripPlannerPresentation.editTripCancelAccessibilityIdentifier == "TripEditSheet.Cancel")
        }

        @Test func tripPlannerPresentation_sortsTripsByStartDateNewestFirst() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let olderStart = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
            let newerStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
            let older = DiveTrip(startDate: olderStart, endDate: olderStart, title: "Older")
            let newer = DiveTrip(startDate: newerStart, endDate: newerStart, title: "Newer")
            let sorted = TripPlannerPresentation.sortedForList([older, newer])
            #expect(sorted.map(\.displayTitle) == ["Newer", "Older"])
        }

        @Test func tripPlannerPresentation_listRowSubtitle_includesDatesAndCountries() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            let trip = DiveTrip(
                startDate: start,
                endDate: end,
                countries: ["Bonaire"],
                title: "Reef week"
            )
            let subtitle = TripPlannerPresentation.listRowSubtitle(for: trip)
            #expect(subtitle.contains("Bonaire"))
            #expect(subtitle.contains("·"))
        }

        @Test func tripPlannerPresentation_listRowDisplayData_splitsTitleDatesCountriesAndDiveCount() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            let trip = DiveTrip(
                startDate: start,
                endDate: end,
                countries: ["Bonaire", "Curaçao"],
                title: "Reef week"
            )
            let dateRange = DiveTripPresentation.formattedDateRange(start: start, end: end)

            let upcoming = TripPlannerPresentation.listRowDisplayData(for: trip, phase: .upcoming)
            #expect(upcoming.title == "Reef week")
            #expect(upcoming.dateRangeLine == dateRange)
            #expect(upcoming.countriesLine == "Bonaire, Curaçao")
            #expect(
                upcoming.secondaryDetailLine
                    == TripPlannerPresentation.listRowSecondaryDetail(
                        dateRange: dateRange,
                        countriesLine: "Bonaire, Curaçao"
                    )
            )
            #expect(upcoming.linkedDiveCountLabel == nil)
            #expect(upcoming.inviteBadgeTitle == nil)

            let active = TripPlannerPresentation.listRowDisplayData(for: trip, phase: .active)
            #expect(active.dateRangeLine == dateRange)
            #expect(active.countriesLine == "Bonaire, Curaçao")
            #expect(active.secondaryDetailLine.contains(dateRange))
            #expect(active.secondaryDetailLine.contains("Bonaire, Curaçao"))
            #expect(active.linkedDiveCountLabel == "0 dives")
            #expect(active.previewMediaPhotoID == nil)
            #expect(
                TripPlannerPresentation.listRowAccessibilityLabel(for: active)
                    == "Reef week, 0 dives, \(active.secondaryDetailLine)"
            )
        }

        @Test @MainActor func tripPlannerPresentation_listRowPreviewMediaPhotoID_usesFirstLinkedTripMedia() {
            let dive = DiveActivity(
                source: .manual,
                sourceDiveId: "trip-list-dive",
                startTime: Date(timeIntervalSince1970: 1_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            let firstPhoto = DiveMediaPhoto(sortOrder: 0)
            let secondPhoto = DiveMediaPhoto(sortOrder: 1)
            dive.mediaPhotos = [secondPhoto, firstPhoto]

            let previewID = TripPlannerPresentation.listRowPreviewMediaPhotoID(
                phase: .active,
                linkedActivities: [dive]
            )
            #expect(previewID == firstPhoto.id)
        }

        @Test @MainActor func tripDetailContentPager_resolvedInitialPage_opensMediaWhenStarted() {
            #expect(
                TripDetailContentPagerPresentation.resolvedInitialPage(
                    hasStarted: true,
                    requested: .media
                ) == .media
            )
            #expect(
                TripDetailContentPagerPresentation.resolvedInitialPage(
                    hasStarted: false,
                    requested: .media
                ) == .plannedSites
            )
        }

        @Test func tripPlannerPresentation_linkedDiveCountLabel_pluralizes() {
            #expect(TripPlannerPresentation.linkedDiveCountLabel(count: 1) == "1 dive")
            #expect(TripPlannerPresentation.linkedDiveCountLabel(count: 4) == "4 dives")
        }

        @Test func tripPlannerPresentation_listRowSecondaryDetail_joinsDatesAndCountries() {
            #expect(
                TripPlannerPresentation.listRowSecondaryDetail(
                    dateRange: "Jun 1 – Jun 15, 2026",
                    countriesLine: "Bonaire"
                ) == "Jun 1 – Jun 15, 2026 · Bonaire"
            )
            #expect(
                TripPlannerPresentation.listRowSecondaryDetail(
                    dateRange: "Jun 1 – Jun 15, 2026",
                    countriesLine: nil
                ) == "Jun 1 – Jun 15, 2026"
            )
        }

        @Test func tripPlannerPresentation_lifecyclePhase_classifiesUpcomingActiveAndPast() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 11))!

            let upcoming = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 8))!,
                title: "Future"
            )
            let active = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!,
                title: "In progress"
            )
            let past = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 8))!,
                title: "Done"
            )

            #expect(
                TripPlannerPresentation.lifecyclePhase(
                    for: upcoming,
                    referenceDate: reference,
                    calendar: calendar
                ) == .upcoming
            )
            #expect(
                TripPlannerPresentation.lifecyclePhase(
                    for: active,
                    referenceDate: reference,
                    calendar: calendar
                ) == .active
            )
            #expect(
                TripPlannerPresentation.lifecyclePhase(
                    for: past,
                    referenceDate: reference,
                    calendar: calendar
                ) == .past
            )
        }

        @Test func tripPlannerPresentation_listSections_ordersUpcomingActivePastAndSortsWithinSection() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 11))!

            let soonerUpcoming = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 20))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 22))!,
                title: "Soon"
            )
            let laterUpcoming = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 5))!,
                title: "Later"
            )
            let activeEndingSoon = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 12))!,
                title: "Ending soon"
            )
            let activeEndingLater = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 6, day: 20))!,
                title: "Ending later"
            )
            let recentPast = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 20))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 25))!,
                title: "Recent past"
            )
            let olderPast = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 4, day: 8))!,
                title: "Older past"
            )

            let sections = TripPlannerPresentation.listSections(
                from: [
                    olderPast,
                    laterUpcoming,
                    activeEndingLater,
                    recentPast,
                    soonerUpcoming,
                    activeEndingSoon,
                ],
                referenceDate: reference,
                calendar: calendar
            )

            #expect(sections.map(\.phase) == [.upcoming, .active, .past])
            #expect(sections[0].trips.map(\.displayTitle) == ["Soon", "Later"])
            #expect(sections[1].trips.map(\.displayTitle) == ["Ending soon", "Ending later"])
            #expect(sections[2].trips.map(\.displayTitle) == ["Recent past", "Older past"])
        }

        @Test func tripPlannerPresentation_listSections_omitsEmptySections() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 11))!
            let upcoming = DiveTrip(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 5))!,
                title: "Only upcoming"
            )

            let sections = TripPlannerPresentation.listSections(
                from: [upcoming],
                referenceDate: reference,
                calendar: calendar
            )

            #expect(sections.count == 1)
            #expect(sections[0].phase == .upcoming)
        }

        @Test func diveTripDateRangePickerPresentation_endDateDefaultedToStartMonth() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))!
            let endInOtherMonth = calendar.date(from: DateComponents(year: 2026, month: 3, day: 20))!
            let aligned = DiveTripDateRangePickerPresentation.endDateDefaultedToStartMonth(
                start: start,
                currentEnd: endInOtherMonth,
                calendar: calendar
            )
            #expect(calendar.component(.year, from: aligned) == 2026)
            #expect(calendar.component(.month, from: aligned) == 8)
            #expect(calendar.component(.day, from: aligned) == 20)

            let endBeforeStartDay = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5))!
            let clamped = DiveTripDateRangePickerPresentation.endDateDefaultedToStartMonth(
                start: start,
                currentEnd: endBeforeStartDay,
                calendar: calendar
            )
            #expect(clamped == calendar.startOfDay(for: start))
        }

        @Test func diveTripDateRangePickerPresentation_singleCalendarLayout_isCompactForFormSheet() {
            #expect(DiveTripDateRangePickerPresentation.singleCalendarHeight == 280)
            #expect(DiveTripDateRangePickerPresentation.singleCalendarScale == 0.88)
            #expect(DiveTripDateRangePickerPresentation.singleCalendarHorizontalInset == 28)
            #expect(DiveTripDateRangePickerPresentation.singleCalendarScale < 1)
        }

        @Test func diveTripFormValues_setStartDate_firstPickMatchesEndToStart() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var form = DiveTripFormValues()
            form.title = "Reef week"
            form.endDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 18))!
            let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3))!
            form.setStartDate(start, calendar: calendar)
            #expect(form.hasChosenStartDate)
            #expect(form.startDate == calendar.startOfDay(for: start))
            #expect(form.endDate == form.startDate)
            #expect(DiveTripDateRangePickerPresentation.shouldShowEndDateControls(hasChosenStartDate: true))
        }

        @Test func diveTripFormValues_setStartDate_laterChangeKeepsEndDayInStartMonth() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var form = DiveTripFormValues()
            form.hasChosenStartDate = true
            form.startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 3))!
            form.endDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 18))!
            form.setStartDate(
                calendar.date(from: DateComponents(year: 2026, month: 9, day: 3))!,
                calendar: calendar
            )
            #expect(calendar.component(.month, from: form.startDate) == 9)
            #expect(calendar.component(.month, from: form.endDate) == 9)
            #expect(calendar.component(.day, from: form.endDate) == 18)
            #expect(form.hasValidDateRange)
        }

        @Test func diveTripDateRangePickerPresentation_normalizedDates_singleDayWhenEndMissing() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = DateComponents(year: 2026, month: 6, day: 10)
            let end = DateComponents(year: 2026, month: 6, day: 15)

            let single = DiveTripDateRangePickerPresentation.normalizedDates(
                startComponents: start,
                endComponents: nil,
                calendar: calendar
            )
            #expect(single?.start == calendar.date(from: start))
            #expect(single?.end == single?.start)

            let range = DiveTripDateRangePickerPresentation.normalizedDates(
                startComponents: start,
                endComponents: end,
                calendar: calendar
            )
            #expect(range?.start == calendar.date(from: start))
            #expect(range?.end == calendar.date(from: end))
        }

        @Test func diveTripFormValues_parsesCountriesAndValidatesSave() {
            var form = DiveTripFormValues()
            #expect(!form.canSave)

            form.countriesText = " Bonaire , Curaçao "
            #expect(form.parsedCountries == ["Bonaire", "Curaçao"])
            #expect(!form.canSave)

            form = DiveTripFormValues()
            form.title = "  Reef week  "
            #expect(form.trimmedTitle == "Reef week")
            #expect(!form.canSave)
            form.hasChosenStartDate = true
            #expect(form.canSave)
            #expect(form.parsedCountries.isEmpty)

            form.countriesText = "Dutch Caribbean, Bonaire"
            #expect(form.parsedCountries == ["Caribbean Netherlands", "Bonaire"])
            let trip = form.makeDiveTrip()
            #expect(trip.countries == ["Caribbean Netherlands", "Bonaire"])
            #expect(trip.title == "Reef week")
        }

        @Test @MainActor func diveTripFormValues_initFromTripAndApply() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let profile = UserProfile(appleUserIdentifier: "trip-form-apply", displayName: "Diver")
            context.insert(profile)

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!

            let trip = DiveTrip(
                startDate: start,
                endDate: end,
                countries: ["Bonaire"],
                title: "Old title",
                owner: profile
            )
            context.insert(trip)

            var form = DiveTripFormValues(from: trip)
            #expect(form.countriesText == "Bonaire")
            form.title = "Bonaire 2026"
            form.countriesText = "Bonaire, Curaçao"
            form.apply(to: trip)

            #expect(trip.displayTitle == "Bonaire 2026")
            #expect(trip.countries == ["Bonaire", "Curaçao"])
        }

        @Test @MainActor func tripShareMaterializer_acceptsOwnerFromDifferentModelContext() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let main = container.mainContext
            let profile = UserProfile(appleUserIdentifier: "trip-share-cross-ctx", displayName: "Recipient")
            main.insert(profile)
            let existingBuddy = DiveBuddy(displayName: "Alex", owner: profile)
            existingBuddy.linkedFirebaseUID = "sharer-uid"
            main.insert(existingBuddy)
            try main.save()

            let background = ModelContext(container)
            let start = Date(timeIntervalSince1970: 1_900_000_000)
            let end = Date(timeIntervalSince1970: 1_900_100_000)
            let shared = GoDiveTripShareMapping.SharedTripSnapshot(
                tripID: "SOURCE-TRIP-CTX",
                title: "Bonaire",
                startDate: start,
                endDate: end,
                countries: ["Bonaire"],
                plannedSiteIDs: [],
                updatedAt: end,
                createdAt: start,
                schemaVersion: 1
            )
            let invite = GoDiveTripShareMapping.InviteSnapshot(
                inviteID: "sharer_SOURCE-TRIP-CTX",
                sharerUID: "sharer-uid",
                tripID: "SOURCE-TRIP-CTX",
                status: .pending,
                title: "Bonaire",
                sharerDisplayName: "Alex",
                createdAt: start,
                updatedAt: nil,
                schemaVersion: 1
            )

            // Pass the main-context owner into a different context (the crashing production shape).
            let result = GoDiveTripShareMaterializer.materializePending(
                invite: invite,
                sharedTrip: shared,
                owner: profile,
                modelContext: background
            )
            try background.save()
            #expect(result.created)
            let trip = try #require(
                background.fetch(FetchDescriptor<DiveTrip>()).first { $0.id == result.tripID }
            )
            #expect(DiveTripShareLineagePresentation.isPendingInvite(trip))
            #expect(
                DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).contains {
                    $0.linkedFirebaseUID == "sharer-uid"
                }
            )
        }

        @Test @MainActor func tripDetailBuddyActivitiesPresentation_filtersByTripDatesAndFriendUIDs() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let profile = UserProfile(appleUserIdentifier: "trip-buddy-acts", displayName: "Diver")
            context.insert(profile)
            let friend = DiveBuddy(displayName: "Alex", owner: profile)
            friend.linkedFirebaseUID = "friend-a"
            let local = DiveBuddy(displayName: "Local", owner: profile)
            context.insert(friend)
            context.insert(local)

            let uids = TripDetailBuddyActivitiesPresentation.friendUIDsOnTrip(
                plannedBuddies: [friend, local],
                sharedFromFirebaseUID: "sharer-b"
            )
            #expect(uids == ["friend-a", "sharer-b"])

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let tripStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
            let tripEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
            let inWindow = calendar.date(from: DateComponents(year: 2026, month: 6, day: 5, hour: 12))!
            let outWindow = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 12))!

            func row(id: String, start: Date?) -> LogbookBuddyFeedPresentation.Row {
                LogbookBuddyFeedPresentation.Row(
                    id: id,
                    friendUID: "friend-a",
                    friendDisplayName: "Alex",
                    friendPhotoURL: nil,
                    dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                        id: id,
                        startTime: start,
                        durationMinutes: nil,
                        maxDepthMeters: nil,
                        siteName: "Site",
                        locationName: nil,
                        activityTagNames: [],
                        sightings: [],
                        taggedBuddies: [],
                        equipmentSummary: [],
                        mediaPreviews: [],
                        profileTrackBase64: nil
                    )
                )
            }

            let filtered = TripDetailBuddyActivitiesPresentation.rowsInTripWindow(
                [row(id: "in", start: inWindow), row(id: "out", start: outWindow), row(id: "nil", start: nil)],
                start: tripStart,
                end: tripEnd,
                calendar: calendar
            )
            #expect(filtered.map(\.id) == ["in"])
            #expect(
                TripDetailBuddyActivitiesPresentation.subtitleLine(for: filtered[0]).contains("Site")
            )
        }

        @Test func diveTripDateRange_rejectsEndBeforeStart() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
            #expect(!DiveTripDateRange.isValidOrderedRange(start: start, end: end, calendar: calendar))

            var form = DiveTripFormValues()
            form.title = "Reef week"
            form.startDate = start
            form.endDate = end
            #expect(!form.hasValidDateRange)
            #expect(!form.canSave)
        }

        @Test func diveTripDateRange_allowsSameDayTrip() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let day = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 9))!
            let later = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 18))!
            #expect(DiveTripDateRange.isValidOrderedRange(start: day, end: later, calendar: calendar))

            var form = DiveTripFormValues()
            form.title = "Day trip"
            form.hasChosenStartDate = true
            form.startDate = day
            form.endDate = later
            #expect(form.hasValidDateRange)
            #expect(form.canSave)
        }

        @Test func diveTripPresentation_formatsDateRange() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let day = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
            let single = DiveTripPresentation.formattedDateRange(start: day, end: day)
            #expect(!single.isEmpty)

            let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            let range = DiveTripPresentation.formattedDateRange(start: start, end: end)
            #expect(range.contains("–"))
        }

        @Test func diveTripDateRange_containsInstantOnInclusiveCalendarDays() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 10))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15))!
            let inside = calendar.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 18))!
            let outside = calendar.date(from: DateComponents(year: 2026, month: 4, day: 20))!
            #expect(DiveTripDateRange.contains(inside, start: start, end: end, calendar: calendar))
            #expect(!DiveTripDateRange.contains(outside, start: start, end: end, calendar: calendar))
        }

        @Test func diveTripDateRange_detectsOverlappingInclusiveRanges() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let tripAStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
            let tripAEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            let tripBStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            let tripBEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 20))!
            let tripCStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21))!
            let tripCEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25))!

            #expect(
                DiveTripDateRange.rangesOverlap(
                    start: tripAStart,
                    end: tripAEnd,
                    otherStart: tripBStart,
                    otherEnd: tripBEnd,
                    calendar: calendar
                )
            )
            #expect(
                !DiveTripDateRange.rangesOverlap(
                    start: tripAStart,
                    end: tripAEnd,
                    otherStart: tripCStart,
                    otherEnd: tripCEnd,
                    calendar: calendar
                )
            )
        }

        @Test func diveTripFormValues_rejectsOverlappingOwnerTrips() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let existingStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
            let existingEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            let existing = DiveTrip(
                startDate: existingStart,
                endDate: existingEnd,
                countries: ["Bonaire"],
                title: "Reef week"
            )

            var form = DiveTripFormValues()
            form.title = "Overlap attempt"
            form.startDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 14))!
            form.endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 18))!

            #expect(form.overlappingTrip(among: [existing], calendar: calendar)?.id == existing.id)
            #expect(!form.canSave(existingOwnerTrips: [existing], calendar: calendar))
        }

        @Test func diveTripFormValues_allowsEditingTripWithoutSelfOverlap() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
            let trip = DiveTrip(startDate: start, endDate: end, countries: ["Bonaire"], title: "Reef week")

            var form = DiveTripFormValues(from: trip)
            form.title = "Reef week extended"
            form.endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 16))!

            #expect(form.canSave(existingOwnerTrips: [trip], excludingTripID: trip.id, calendar: calendar))
        }

        @Test func tripDetailPresentation_blueSheetUsesStandardPanelBodySpacing() {
            let content = TripDetailPresentation.blueSheetPageConfiguration(
                accessibilityRootIdentifier: "TripDetail.Content"
            )
            #expect(content.presentation == .pushedDetail)
            #expect(content.showsHero)
            #expect(
                content.pinnedSummaryBottomPadding
                    == BlueSheetDetailPagePinnedSummaryPresentation.pushedDetailPinnedSummaryBottomPadding
            )

            let missing = TripDetailPresentation.blueSheetPageConfiguration(
                accessibilityRootIdentifier: "TripDetail.Root",
                showsHero: false
            )
            #expect(!missing.showsHero)
            #expect(
                missing.pinnedSummaryBottomPadding
                    == BlueSheetDetailPagePinnedSummaryPresentation.pushedDetailPinnedSummaryBottomPadding
            )
        }

        @Test @MainActor func tripDetailContentPager_activeTripPages() {
            #expect(TripDetailContentPagerPresentation.pageCount(hasStarted: true) == 6)
            #expect(
                TripDetailContentPagerPresentation.pages(hasStarted: true) == [
                    .stats, .activities, .tripActivities, .marineLife, .buddies, .media,
                ]
            )
            #expect(TripDetailContentPagerPresentation.defaultPage(hasStarted: true) == .stats)
            #expect(TripDetailContentPagerPresentation.accessibilityIdentifier(for: .stats) == "TripDetail.ContentPager.Stats")
            #expect(
                TripDetailContentPagerPresentation.accessibilityIdentifier(for: .activities)
                    == "TripDetail.ContentPager.MyActivities"
            )
            #expect(
                TripDetailContentPagerPresentation.accessibilityIdentifier(for: .tripActivities)
                    == "TripDetail.ContentPager.TripActivities"
            )
            #expect(TripDetailContentPagerPresentation.accessibilityIdentifier(for: .media) == "TripDetail.ContentPager.Media")
        }

        @Test @MainActor func tripDetailContentPager_usesStaticLayoutForStatsAndMedia() {
            #expect(TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .stats))
            #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .media))
            #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .marineLife))
            #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .activities))
            #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .tripActivities))
            #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .plannedSites))
            #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .buddies))
            #expect(TripDetailContentPagerPresentation.staticPagerContentAlignment(for: .stats) == .top)
            #expect(TripDetailContentPagerPresentation.staticPagerContentAlignment(for: .media) == .top)
            #expect(TripDetailContentPagerPresentation.pageSubtitle(for: .stats) == "Trip Stats")
            #expect(TripDetailContentPagerPresentation.pageSubtitle(for: .activities) == "My Activities")
            #expect(TripDetailContentPagerPresentation.pageSubtitle(for: .tripActivities) == "Trip Activities")
            #expect(TripDetailContentPagerPresentation.pageSubtitle(for: .marineLife) == "Marine Life")
            #expect(TripDetailContentPagerPresentation.pageSubtitle(for: .buddies) == "Dive Buddies")
            #expect(TripDetailContentPagerPresentation.pageSubtitle(for: .media) == "Media")
            #expect(
                TripDetailContentPagerPresentation.pageSubtitle(for: .plannedSites) == "Planned Dive Sites"
            )
            #expect(
                TripDetailContentPagerPresentation.pageSubtitleAccessibilityIdentifier(for: .stats)
                    == "TripDetail.Stats.Subtitle"
            )
            #expect(
                TripDetailContentPagerPresentation.pageSubtitleAccessibilityIdentifier(for: .activities)
                    == "TripDetail.MyActivities.Subtitle"
            )
            #expect(
                TripDetailContentPagerPresentation.pageSubtitleAccessibilityIdentifier(for: .tripActivities)
                    == "TripDetail.TripActivities.Subtitle"
            )
        }

        @Test @MainActor func tripDetailContentPager_plannedTripPages() {
            #expect(TripDetailContentPagerPresentation.pageCount(hasStarted: false) == 2)
            #expect(
                TripDetailContentPagerPresentation.pages(hasStarted: false) == [
                    .plannedSites, .buddies,
                ]
            )
            #expect(TripDetailContentPagerPresentation.defaultPage(hasStarted: false) == .plannedSites)
            #expect(
                TripDetailContentPagerPresentation.accessibilityIdentifier(for: .plannedSites)
                    == "TripDetail.ContentPager.PlannedSites"
            )
            #expect(TripDetailContentPagerPresentation.accessibilityIdentifier(for: .buddies) == "TripDetail.ContentPager.Buddies")
        }

        @Test func diveTripPresentation_tripBuddyTaggedDiveCountLabel() {
            #expect(DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: 0) == "Not tagged on any dives")
            #expect(DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: 1) == "1 dive")
            #expect(DiveTripPresentation.tripBuddyTaggedDiveCountLabel(count: 4) == "4 dives")
        }

        @Test func tripDetailBuddiesPresentation_usesThreeColumnGrid() {
            #expect(TripDetailBuddiesPresentation.gridColumnCount == 3)
            #expect(TripDetailBuddiesPresentation.avatarDiameter == 64)
            #expect(TripDetailBuddiesPresentation.gridCaptionMinHeight > 0)
        }

        @Test func diveTripPresentation_plannedBuddyPickerAccessibilityIdentifiers() {
            #expect(DiveTripPresentation.plannedBuddyPickerCancelAccessibilityIdentifier == "TripPlannedBuddyPicker.Cancel")
            #expect(DiveTripPresentation.plannedBuddyPickerAddBuddyAccessibilityIdentifier == "TripPlannedBuddyPicker.AddBuddy")
            #expect(DiveTripPresentation.plannedBuddyPickerDoneAccessibilityIdentifier == "TripPlannedBuddyPicker.Done")
            #expect(DiveTripPresentation.tripPlannedBuddyPickerFooter.contains("Done"))
        }

        @Test func tripDetailPlannedBuddyPresentation_ordersOwnerFirst() {
            let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
            let buddyID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
            let owner = UserProfile(
                id: ownerID,
                appleUserIdentifier: "owner-share",
                displayName: "Alex Diver"
            )
            let buddy = DiveBuddy(id: buddyID, displayName: "Jordan", owner: owner)

            let members = TripDetailPlannedBuddyPresentation.shareMembers(
                owner: owner,
                plannedBuddies: [buddy]
            )

            #expect(members.count == 2)
            #expect(members[0].id == ownerID)
            #expect(members[0].isOwner)
            #expect(members[0].shareChrome == .you)
            #expect(members[1].id == buddyID)
            #expect(members[1].shareChrome == TripBuddyTripShareChrome.none)
            #expect(TripDetailPlannedBuddyPresentation.subtitle(for: members[0]) == "You")
            #expect(TripDetailPlannedBuddyPresentation.subtitle(for: members[1]).isEmpty)
            #expect(TripDetailPlannedBuddyPresentation.statusBadgeTitle(for: members[1]) == nil)
        }

        @Test @MainActor func tripDetailPlannedBuddyPresentation_shareChromeInviteInvitedJoined() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let owner = UserProfile(appleUserIdentifier: "share-chrome-owner", displayName: "Alex")
            let invitee = DiveBuddy(displayName: "Jordan", owner: owner)
            invitee.linkedFirebaseUID = "friend-jordan"
            let pending = DiveBuddy(displayName: "Sam", owner: owner)
            pending.linkedFirebaseUID = "friend-sam"
            let local = DiveBuddy(displayName: "Local", owner: owner)
            let trip = DiveTrip(
                startDate: Date(timeIntervalSince1970: 2_000_000),
                endDate: Date(timeIntervalSince1970: 2_086_400),
                owner: owner
            )
            context.insert(owner)
            context.insert(invitee)
            context.insert(pending)
            context.insert(local)
            context.insert(trip)

            DiveTripShareLineagePresentation.recordSharedWithFriend(trip, friendUID: "friend-sam")
            DiveTripShareLineagePresentation.recordAcceptedFriend(trip, friendUID: "friend-jordan")

            let members = TripDetailPlannedBuddyPresentation.listMembers(
                owner: owner,
                plannedBuddies: [invitee, pending, local],
                trip: trip
            )
            let byID = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
            #expect(byID[invitee.id]?.shareChrome == .joined)
            #expect(
                TripDetailPlannedBuddyPresentation.statusBadgeTitle(for: byID[invitee.id]!)
                    == "Joined"
            )
            #expect(TripDetailPlannedBuddyPresentation.subtitle(for: byID[invitee.id]!).isEmpty)

            #expect(byID[pending.id]?.shareChrome == .invited)
            #expect(
                TripDetailPlannedBuddyPresentation.statusBadgeTitle(for: byID[pending.id]!)
                    == "Invited"
            )

            #expect(byID[local.id]?.shareChrome == TripBuddyTripShareChrome.none)
            #expect(TripDetailPlannedBuddyPresentation.statusBadgeTitle(for: byID[local.id]!) == nil)

            // Linked friend not yet shared → Invite action chrome.
            let notShared = DiveBuddy(displayName: "Pat", owner: owner)
            notShared.linkedFirebaseUID = "friend-pat"
            context.insert(notShared)
            #expect(
                TripDetailPlannedBuddyPresentation.shareChrome(for: notShared, trip: trip) == .invite
            )
            #expect(TripDetailPlannedBuddyPresentation.joinedBadgeStyle.label == "Joined")
        }

        @Test func tripDetailPlannedBuddyPresentation_usesActiveTripBuddyGridMetrics() {
            #expect(TripDetailBuddiesPresentation.gridColumnCount == 3)
            #expect(TripDetailBuddiesPresentation.avatarDiameter == 64)
            #expect(TripDetailPlannedBuddyPresentation.ownerSubtitle == "You")
            #expect(TripDetailPlannedBuddyPresentation.buddySubtitle == "On this trip")
            #expect(TripDetailPlannedBuddyPresentation.inviteButtonTitle == "Invite")
            #expect(TripDetailPlannedBuddyPresentation.invitedBadgeTitle == "Invited")
        }

        @Test func tripShareCardPresentation_buildsTemporaryPNGFileName() {
            let url = TripShareCardPresentation.temporaryPNGURL(tripTitle: "Bonaire 2026")
            #expect(url.pathExtension == "png")
            #expect(url.lastPathComponent.hasPrefix("GoDive-Trip-"))
            #expect(!url.lastPathComponent.contains("Bonaire"))
            #expect(TripShareTempFilePolicy.isUnderTemporaryDirectory(url))
        }

        @Test func tripShareMapSnapshotPresentation_mapSnapshotSize_fitsCardContentWidth() {
            let size = TripShareMapSnapshotPresentation.mapSnapshotSize(
                cardWidth: TripShareCardPresentation.cardWidth
            )
            let expectedWidth = TripShareCardPresentation.cardWidth
                - TripShareCardPresentation.contentPadding * 2
            #expect(size.width == expectedWidth)
            #expect(abs(size.height - expectedWidth / TripShareMapSnapshotPresentation.mapAspectRatio) < 0.001)
        }

        @Test func tripShareMapSnapshotPresentation_accessibilityLabel_matchesTripDetailMap() {
            let pins = [
                TripDetailMapPin(
                    id: "planned-a",
                    title: "Salt Pier",
                    coordinate: DiveCoordinate(latitude: 12.1, longitude: -68.2),
                    kind: .planned,
                    siteID: nil
                ),
                TripDetailMapPin(
                    id: "completed-b",
                    title: "Hilma Hooker",
                    coordinate: DiveCoordinate(latitude: 12.2, longitude: -68.3),
                    kind: .completed,
                    siteID: nil
                ),
            ]
            #expect(
                TripShareMapSnapshotPresentation.accessibilityLabel(for: pins)
                    == TripDetailMapPresentation.accessibilityLabel(for: pins)
            )
        }

        @Test func tripShareGoogleStaticMapPresentation_buildsHybridStaticMapURL() {
            let pins = [
                TripDetailMapPin(
                    id: "planned-a",
                    title: "Salt Pier",
                    coordinate: DiveCoordinate(latitude: 12.123456, longitude: -68.234567),
                    kind: .planned,
                    siteID: nil
                ),
                TripDetailMapPin(
                    id: "completed-b",
                    title: "Hilma Hooker",
                    coordinate: DiveCoordinate(latitude: 12.223456, longitude: -68.334567),
                    kind: .completed,
                    siteID: nil
                ),
            ]

            let url = TripShareGoogleStaticMapPresentation.staticMapURL(
                pins: pins,
                size: CGSize(width: 400, height: 300),
                scale: 2,
                apiKey: "test-key"
            )

            #expect(url != nil)
            let absolute = url!.absoluteString
            #expect(absolute.contains("maps.googleapis.com/maps/api/staticmap"))
            #expect(absolute.contains("maptype=hybrid"))
            #expect(absolute.contains("400x300"))
            #expect(absolute.contains("scale=2"))
            #expect(absolute.contains("color%3Ablue") || absolute.contains("color:blue"))
            #expect(absolute.contains("color%3Ared") || absolute.contains("color:red"))
            #expect(absolute.contains("test-key"))
        }

        @Test func tripShareGoogleStaticMapPresentation_clampedScale_capsAtTwo() {
            #expect(TripShareGoogleStaticMapPresentation.clampedScale(for: 3) == 2)
            #expect(TripShareGoogleStaticMapPresentation.clampedScale(for: 1) == 1)
        }

        @Test func tripShareCardPresentation_includesLogoAssetName() {
            #expect(TripShareCardPresentation.logoImageName == GoDiveLogoPinPresentation.assetName)
            #expect(TripShareCardPresentation.logoHeight == 72)
        }

        @Test func tripShareCardPresentation_members_usesPlannedBuddiesBeforeTripStarts() {
            let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000030")!
            let buddyID = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
            let owner = UserProfile(
                id: ownerID,
                appleUserIdentifier: "owner-share-planned",
                displayName: "Alex Diver"
            )
            let buddy = DiveBuddy(id: buddyID, displayName: "Jordan", owner: owner)

            let members = TripShareCardPresentation.members(
                hasStarted: false,
                owner: owner,
                ownerLinkedDiveCount: 0,
                plannedBuddies: [buddy],
                taggedBuddies: [
                    DiveTripBuddySummary(buddyID: buddyID, displayName: "Jordan", diveCount: 3)
                ],
                rosterBuddiesByID: [buddyID: buddy]
            )

            #expect(members.count == 2)
            #expect(members[0].id == ownerID)
            #expect(members[0].subtitle == "You")
            #expect(!members[0].usesAccentSubtitle)
            #expect(members[1].subtitle == "On this trip")
            #expect(!members[1].usesAccentSubtitle)
        }

        @Test func tripShareCardPresentation_members_usesTaggedBuddiesWithDiveCountsAfterStart() {
            let buddyID = UUID(uuidString: "00000000-0000-0000-0000-000000000032")!
            let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000033")!
            let owner = UserProfile(
                id: ownerID,
                appleUserIdentifier: "owner-share-active",
                displayName: "Alex Diver"
            )
            let buddy = DiveBuddy(id: buddyID, displayName: "Sam", owner: owner)

            let members = TripShareCardPresentation.members(
                hasStarted: true,
                owner: owner,
                ownerLinkedDiveCount: 3,
                plannedBuddies: [buddy],
                taggedBuddies: [
                    DiveTripBuddySummary(buddyID: buddyID, displayName: "Sam", diveCount: 2)
                ],
                rosterBuddiesByID: [buddyID: buddy]
            )

            #expect(members.count == 2)
            #expect(members[0].id == ownerID)
            #expect(members[0].displayName == "Alex Diver")
            #expect(members[0].subtitle == "3 dives")
            #expect(members[0].usesAccentSubtitle)
            #expect(members[1].displayName == "Sam")
            #expect(members[1].subtitle == "2 dives")
            #expect(members[1].usesAccentSubtitle)
            #expect(members[1].profilePhoto == buddy.profilePhoto)
        }

        @Test func tripShareCardPresentation_marineLifeCalloutLabel_formatsUniqueSpeciesCount() {
            #expect(TripShareCardPresentation.marineLifeCalloutLabel(uniqueSpeciesCount: 0) == nil)
            #expect(TripShareCardPresentation.marineLifeCalloutLabel(uniqueSpeciesCount: 1) == "1 species spotted")
            #expect(TripShareCardPresentation.marineLifeCalloutLabel(uniqueSpeciesCount: 12) == "12 species spotted")
        }

        @Test func tripShareCardPresentation_ownerShareSubtitle_usesDiveCountWhenTripStarted() {
            let subtitle = TripShareCardPresentation.ownerShareSubtitle(
                hasStarted: true,
                ownerLinkedDiveCount: 1
            )
            #expect(subtitle.subtitle == "1 dive")
            #expect(subtitle.usesAccentSubtitle)
        }

        @Test func tripDetailPresentation_deferredContentTaskToken_omitsUpdatedAt() {
            let tripID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            let featured = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            let tokenA = TripDetailPresentation.deferredContentTaskToken(
                tripID: tripID,
                activityLinkCount: 3,
                plannedSiteCount: 2,
                featuredTripMediaPhotoID: featured,
                ownedDiveActivityCount: 40,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: true
            )
            let tokenB = TripDetailPresentation.deferredContentTaskToken(
                tripID: tripID,
                activityLinkCount: 3,
                plannedSiteCount: 2,
                featuredTripMediaPhotoID: featured,
                ownedDiveActivityCount: 40,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: true
            )
            let tokenLinks = TripDetailPresentation.deferredContentTaskToken(
                tripID: tripID,
                activityLinkCount: 4,
                plannedSiteCount: 2,
                featuredTripMediaPhotoID: featured,
                ownedDiveActivityCount: 40,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: true
            )
            #expect(tokenA == tokenB)
            #expect(tokenA != tokenLinks)
            let fingerprint = TripDetailPresentation.contentRebuildFingerprint(
                tripID: tripID,
                activityLinkCount: 3,
                plannedSiteCount: 2,
                featuredTripMediaPhotoID: featured,
                ownedDiveActivityCount: 40,
                rosterBuddyCount: 5,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: true
            )
            #expect(fingerprint.hasPrefix(tokenA))
            #expect(fingerprint.hasSuffix("|5"))
        }

        @Test func tripDetailPresentation_prefersMapHero_forPlannedTripWithSites() {
            #expect(
                TripDetailPresentation.prefersMapHero(
                    tripHasStarted: false,
                    plannedSiteCount: 2,
                    hasMapPins: true,
                    hasTripMedia: false
                )
            )
            #expect(
                TripDetailPresentation.prefersMapHero(
                    tripHasStarted: false,
                    plannedSiteCount: 1,
                    hasMapPins: true,
                    hasTripMedia: true
                )
            )
            #expect(
                !TripDetailPresentation.prefersMapHero(
                    tripHasStarted: false,
                    plannedSiteCount: 2,
                    hasMapPins: false,
                    hasTripMedia: false
                )
            )
            #expect(
                !TripDetailPresentation.prefersMapHero(
                    tripHasStarted: true,
                    plannedSiteCount: 2,
                    hasMapPins: true,
                    hasTripMedia: true
                )
            )
            #expect(
                TripDetailPresentation.prefersMapHero(
                    tripHasStarted: true,
                    plannedSiteCount: 0,
                    hasMapPins: true,
                    hasTripMedia: false
                )
            )
            #expect(
                TripDetailPresentation.prefersMapHero(
                    tripHasStarted: false,
                    plannedSiteCount: 0,
                    hasMapPins: false,
                    hasTripMedia: false,
                    hasCountryFocus: true
                )
            )
            #expect(
                !TripDetailPresentation.prefersMapHero(
                    tripHasStarted: true,
                    plannedSiteCount: 0,
                    hasMapPins: false,
                    hasTripMedia: true,
                    hasCountryFocus: true
                )
            )
        }

        @Test func tripDetailCountryMapPresentation_combinesNearbyCountriesAndPicksFirstWhenSpread() {
            #expect(
                TripDetailCountryMapPresentation.shouldUseCountryFocus(
                    isUpcoming: true,
                    linkedActivityCount: 0,
                    hasMapPins: false
                )
            )
            #expect(
                TripDetailCountryMapPresentation.shouldUseCountryFocus(
                    isUpcoming: false,
                    linkedActivityCount: 0,
                    hasMapPins: false
                )
            )
            #expect(
                !TripDetailCountryMapPresentation.shouldUseCountryFocus(
                    isUpcoming: false,
                    linkedActivityCount: 2,
                    hasMapPins: false
                )
            )
            #expect(
                !TripDetailCountryMapPresentation.shouldUseCountryFocus(
                    isUpcoming: true,
                    linkedActivityCount: 0,
                    hasMapPins: true
                )
            )

            let nearbyNames = TripDetailCountryMapPresentation.focusedCountryNames(
                from: ["Indonesia", "Malaysia"]
            )
            #expect(nearbyNames == ["Indonesia", "Malaysia"])
            let nearby = TripDetailCountryMapPresentation.fittingRegion(
                countries: ["Indonesia", "Malaysia"]
            )
            let indonesia = TripDetailCountryMapPresentation.fittingRegion(countries: ["Indonesia"])
            #expect(nearby != nil)
            #expect(indonesia != nil)
            #expect(nearby!.latitudeDelta > indonesia!.latitudeDelta)

            let spreadNames = TripDetailCountryMapPresentation.focusedCountryNames(
                from: ["United States", "China"]
            )
            #expect(spreadNames == ["United States"])
            let unitedStates = TripDetailCountryMapPresentation.fittingRegion(countries: ["United States"])
            let spread = TripDetailCountryMapPresentation.fittingRegion(
                countries: ["United States", "China"]
            )
            #expect(unitedStates == spread)

            #expect(
                TripDetailCountryMapPresentation.focusRegion(
                    countries: ["Aruba"],
                    isUpcoming: false,
                    linkedActivityCount: 3,
                    hasMapPins: false
                ) == nil
            )
            #expect(
                TripDetailCountryMapPresentation.focusRegion(
                    countries: ["Aruba"],
                    isUpcoming: true,
                    linkedActivityCount: 0,
                    hasMapPins: true
                ) == nil
            )
        }

        @Test func tripDetailCountryMapPresentation_arubaStaysTightAndFramesInHeaderBand() {
            let aruba = TripDetailCountryMapPresentation.fittingRegion(countries: ["Aruba"])
            #expect(aruba != nil)
            #expect(aruba!.latitudeDelta < 0.5)
            #expect(aruba!.longitudeDelta < 0.5)
            #expect(aruba!.latitudeDelta > 0.1)
            #expect(
                TripDetailCountryMapPresentation.approximateGoogleZoomLevel(for: aruba!)
                    > TripDetailCountryMapPresentation.approximateGoogleZoomLevel(
                        for: TripDetailCountryMapPresentation.fittingRegion(countries: ["United States"])!
                    )
            )

            let layout = TripDetailMapFitLayout(
                mapHeight: 400,
                topObstructionHeight: 100,
                panelOverlap: 187
            )
            #expect(TripDetailMapPresentation.mapFitEdgeInsetBottom(for: layout) == 219)
            #expect(TripDetailMapPresentation.countryMapFitEdgeInsetBottom(for: layout) == 187)
        }

        @Test @MainActor func tripDetailMapPresentation_plannedBlueAndCompletedRedPins() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext

            let plannedOnly = DiveSite(siteName: "Salt Pier", latCoords: 12.123, longCoords: -68.456)
            let plannedAndDone = DiveSite(siteName: "Hilma Hooker", latCoords: 12.234, longCoords: -68.567)
            let unplannedDoneSite = DiveSite(siteName: "Something Special", latCoords: 12.345, longCoords: -68.678)
            context.insert(plannedOnly)
            context.insert(plannedAndDone)
            context.insert(unplannedDoneSite)

            let completedAtPlanned = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 45,
                maxDepthMeters: 20
            )
            DiveActivitySiteAssociation.link(completedAtPlanned, to: plannedAndDone)
            context.insert(completedAtPlanned)

            let completedUnplanned = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 40,
                maxDepthMeters: 18,
                entryCoordinate: DiveCoordinate(latitude: 12.111, longitude: -68.222)
            )
            context.insert(completedUnplanned)
            try context.save()

            let pins = TripDetailMapPresentation.pins(
                plannedSites: [
                    DiveLinkedSiteResolver.resolved(from: plannedOnly),
                    DiveLinkedSiteResolver.resolved(from: plannedAndDone),
                ],
                linkedActivities: [completedAtPlanned, completedUnplanned],
                catalogSites: [plannedOnly, plannedAndDone, unplannedDoneSite]
            )

            #expect(pins.count == 3)
            #expect(pins.filter { $0.kind == .planned }.map(\.title) == ["Salt Pier"])
            #expect(pins.filter { $0.kind == .completed }.map(\.title) == ["Hilma Hooker", "Dive"])
            #expect(pins.first(where: { $0.title == "Salt Pier" })?.siteID == plannedOnly.id)
            #expect(pins.first(where: { $0.title == "Hilma Hooker" })?.siteID == plannedAndDone.id)
            #expect(pins.first(where: { $0.title == "Dive" })?.siteID == nil)
            #expect(TripDetailMapPresentation.boundingRegion(for: pins) != nil)
        }

        @Test func tripDetailMapPresentation_boundingRegion_zoomsOutToFitSpreadPins() {
            let pins = [
                TripDetailMapPin(
                    id: "planned-a",
                    title: "North",
                    coordinate: DiveCoordinate(latitude: 12.0, longitude: -68.0),
                    kind: .planned,
                    siteID: nil
                ),
                TripDetailMapPin(
                    id: "completed-b",
                    title: "South",
                    coordinate: DiveCoordinate(latitude: 12.2, longitude: -68.35),
                    kind: .completed,
                    siteID: nil
                ),
            ]

            let region = TripDetailMapPresentation.boundingRegion(for: pins)
            #expect(region != nil)
            let expectedLatDelta = max(0.2 * TripDetailMapPresentation.boundingRegionPaddingMultiplier, TripDetailMapPresentation.boundingRegionMinimumSpanDegrees)
            let expectedLonDelta = max(0.35 * TripDetailMapPresentation.boundingRegionPaddingMultiplier, TripDetailMapPresentation.boundingRegionMinimumSpanDegrees)
            #expect(abs((region?.latitudeDelta ?? 0) - expectedLatDelta) < 1e-9)
            #expect(abs((region?.longitudeDelta ?? 0) - expectedLonDelta) < 1e-9)
            #expect(region?.latitudeDelta ?? 0 > 0.35)
        }

        @Test func tripDetailMapPresentation_singlePinRegion_isWiderThanDiveSiteDefault() {
            let pin = TripDetailMapPin(
                id: "planned-only",
                title: "Salt Pier",
                coordinate: DiveCoordinate(latitude: 12.1, longitude: -68.2),
                kind: .planned,
                siteID: nil
            )

            let region = TripDetailMapPresentation.boundingRegion(for: [pin])
            #expect(region?.latitudeDelta == TripDetailMapPresentation.singlePinRegionSpanDegrees)
            #expect(region?.longitudeDelta == TripDetailMapPresentation.singlePinRegionSpanDegrees)
            #expect(TripDetailMapPresentation.singlePinRegionSpanDegrees > DiveLocationMapPresentation.diveSiteLatitudeDelta)
        }

        @Test func tripDetailMapPresentation_usesPinCalloutLabeling() {
            #expect(TripDetailMapPresentation.usesPinCalloutLabeling)
        }

        @Test func tripDetailMapAnnotation_suppressesDefaultCalloutTitle() {
            let siteID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
            let pin = TripDetailMapPin(
                id: "completed-1",
                title: "Blue Hole",
                coordinate: DiveCoordinate(latitude: 17.3, longitude: -87.5),
                kind: .completed,
                siteID: siteID
            )
            let annotation = TripDetailMapAnnotation(pin: pin)
            #expect(annotation.title == nil)
            #expect(annotation.siteDisplayName == "Blue Hole")
            #expect(annotation.siteID == siteID)
        }

        @Test func tripDetailMapPresentation_mapFitEdgeInsets_centerPinsInVisibleHeroBand() {
            let layout = TripDetailMapFitLayout(
                mapHeight: 480,
                topObstructionHeight: 128,
                panelOverlap: HomeOverviewLayout.panelOverlap
            )
            let insets = TripDetailMapPresentation.mapFitEdgeInsetValues(for: layout)
            #expect(insets.top == layout.topObstructionHeight)
            #expect(insets.bottom == HomeOverviewLayout.panelOverlap + TripDetailMapPresentation.mapMarkerGroundClearance)
            let targetY = TripDetailMapPresentation.targetPinScreenYFraction(for: layout)
            let panelFraction = min(max(layout.panelOverlap / layout.mapHeight, 0), 0.92)
                + TripDetailMapPresentation.mapMarkerGroundClearance / layout.mapHeight
            let expectedY = DiveLocationMapPresentation.targetPinScreenYFraction(
                layoutHeight: layout.mapHeight,
                topObstructionHeight: insets.top,
                sheetHeightFraction: panelFraction
            )
            #expect(abs(targetY - expectedY) < 0.001)
        }

        @Test func tripDetailMapPresentation_effectiveMapHeight_usesHeroHeightBeforeUIKitLayout() {
            let layout = TripDetailMapFitLayout(mapHeight: 412, topObstructionHeight: 96)
            #expect(TripDetailMapPresentation.effectiveMapHeight(measuredBoundsHeight: 0, fitLayout: layout) == 412)
            #expect(TripDetailMapPresentation.effectiveMapHeight(measuredBoundsHeight: 1, fitLayout: layout) == 412)
            #expect(TripDetailMapPresentation.effectiveMapHeight(measuredBoundsHeight: 400, fitLayout: layout) == 400)
            #expect(!TripDetailMapPresentation.hasMeasuredMapBounds(width: 0, height: 412))
            #expect(TripDetailMapPresentation.hasMeasuredMapBounds(width: 390, height: 412))
        }

        @Test func tripDetailMapPresentation_fittingRegion_isTighterThanBoundingRegionForSpreadPins() {
            let pins = [
                TripDetailMapPin(
                    id: "planned-a",
                    title: "North",
                    coordinate: DiveCoordinate(latitude: 12.0, longitude: -68.0),
                    kind: .planned,
                    siteID: nil
                ),
                TripDetailMapPin(
                    id: "completed-b",
                    title: "South",
                    coordinate: DiveCoordinate(latitude: 12.2, longitude: -68.35),
                    kind: .completed,
                    siteID: nil
                ),
            ]

            let bounding = TripDetailMapPresentation.boundingRegion(for: pins)
            let fitting = TripDetailMapPresentation.fittingRegion(for: pins)
            #expect(bounding != nil)
            #expect(fitting != nil)
            #expect((fitting?.latitudeDelta ?? 0) < (bounding?.latitudeDelta ?? 0))
            #expect((fitting?.longitudeDelta ?? 0) < (bounding?.longitudeDelta ?? 0))
            let expectedLatDelta = max(0.2 * TripDetailMapPresentation.fittingRegionPaddingMultiplier, TripDetailMapPresentation.boundingRegionMinimumSpanDegrees)
            #expect(abs((fitting?.latitudeDelta ?? 0) - expectedLatDelta) < 1e-9)
        }

        @Test func tripDetailMapPresentation_fittingRegion_singlePin_usesMinimumSpan() {
            let pin = TripDetailMapPin(
                id: "buddy-only",
                title: "Salt Pier",
                coordinate: DiveCoordinate(latitude: 12.1, longitude: -68.2),
                kind: .completed,
                siteID: nil
            )

            let fitting = TripDetailMapPresentation.fittingRegion(for: [pin])
            #expect(fitting?.latitudeDelta == TripDetailMapPresentation.singlePinRegionSpanDegrees)
            #expect(fitting?.longitudeDelta == TripDetailMapPresentation.singlePinRegionSpanDegrees)
            let mapRect = TripDetailMapPresentation.mkMapRect(for: [pin])
            #expect(mapRect != nil)
            #expect((mapRect?.width ?? 0) > 0)
            #expect((mapRect?.height ?? 0) > 0)
        }

        @Test func tripDetailMediaPresentation_resolvedHeroMediaPhotoID_prefersFeaturedThenSessionRandom() {
            let featured = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 100))
            let sessionRandom = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 200))
            let photos = [featured, sessionRandom]

            #expect(
                TripDetailMediaPresentation.resolvedHeroMediaPhotoID(
                    in: photos,
                    explicitFeaturedID: featured.id,
                    sessionRandomID: sessionRandom.id
                ) == featured.id
            )
            #expect(
                TripDetailMediaPresentation.resolvedHeroMediaPhotoID(
                    in: photos,
                    explicitFeaturedID: nil,
                    sessionRandomID: sessionRandom.id
                ) == sessionRandom.id
            )
        }

        @Test func tripDetailMediaPresentation_toggledFeaturedMediaPhotoID_clearsWhenAlreadyFeatured() {
            let mediaID = UUID()
            #expect(
                TripDetailMediaPresentation.toggledFeaturedMediaPhotoID(
                    mediaID: mediaID,
                    explicitFeaturedID: mediaID
                ) == nil
            )
            #expect(
                TripDetailMediaPresentation.toggledFeaturedMediaPhotoID(
                    mediaID: mediaID,
                    explicitFeaturedID: nil
                ) == mediaID
            )
        }

        @Test func tripDetailDiveSiteNavigation_resolvedSite_prefersPlannedTripSites() {
            let plannedID = UUID()
            let catalogID = UUID()
            let planned = DiveSite(
                id: plannedID,
                siteName: "Salt Pier",
                latCoords: 12.1,
                longCoords: -68.2
            )
            let catalogOnly = DiveSite(
                id: catalogID,
                siteName: "Other",
                latCoords: 12.2,
                longCoords: -68.3
            )

            let resolvedPlanned = TripDetailDiveSiteNavigation.resolvedSite(
                siteID: plannedID,
                plannedSites: [planned],
                catalogSites: [planned, catalogOnly]
            )
            #expect(resolvedPlanned?.id == plannedID)

            let resolvedCatalog = TripDetailDiveSiteNavigation.resolvedSite(
                siteID: catalogID,
                plannedSites: [planned],
                catalogSites: [planned, catalogOnly]
            )
            #expect(resolvedCatalog?.id == catalogID)
        }

        @Test @MainActor func tripDetailMediaPresentation_collectsMediaFromLinkedDivesNewestFirst() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext

            let newerDive = DiveActivity(source: .manual, startTime: Date(timeIntervalSince1970: 2_000), durationMinutes: 40, maxDepthMeters: 18)
            let olderDive = DiveActivity(source: .manual, startTime: Date(timeIntervalSince1970: 1_000), durationMinutes: 45, maxDepthMeters: 20)
            context.insert(newerDive)
            context.insert(olderDive)

            let newerPhoto = DiveMediaPhoto(sortOrder: 0, capturedAt: Date(timeIntervalSince1970: 2_100), dive: newerDive)
            newerDive.mediaPhotos = [newerPhoto]

            let olderPhotoA = DiveMediaPhoto(sortOrder: 0, capturedAt: Date(timeIntervalSince1970: 1_100), dive: olderDive)
            let olderPhotoB = DiveMediaPhoto(sortOrder: 1, capturedAt: Date(timeIntervalSince1970: 1_200), dive: olderDive)
            olderDive.mediaPhotos = [olderPhotoA, olderPhotoB]
            context.insert(newerPhoto)
            context.insert(olderPhotoA)
            context.insert(olderPhotoB)

            let items = TripDetailMediaPresentation.linkedMediaItems(from: [olderDive, newerDive])
            #expect(items.map(\.id) == [newerPhoto.id, olderPhotoA.id, olderPhotoB.id])
            #expect(
                TripDetailMediaPresentation.diveActivityID(for: newerPhoto.id, in: items) == newerDive.id
            )
        }

        @Test func tripDetailMediaGalleryPresentation_browseAccessibilityLabel_mentionsSwipeWhenMultipleItems() {
            #expect(
                TripDetailMediaGalleryPresentation.browseAccessibilityLabel(
                    itemCount: 0,
                    positionLabel: nil
                ) == DiveTripPresentation.tripMediaEmptyMessage
            )
            #expect(
                TripDetailMediaGalleryPresentation.browseAccessibilityLabel(
                    itemCount: 1,
                    positionLabel: "1 of 1"
                ) == "Trip media, 1 of 1, View opens the linked dive"
            )
            #expect(
                TripDetailMediaGalleryPresentation.browseAccessibilityLabel(
                    itemCount: 3,
                    positionLabel: "2 of 3"
                ) == "Trip media, 2 of 3, swipe up for next, swipe down for previous, View opens the linked dive"
            )
            #expect(
                TripDetailMediaGalleryPresentation.browseAccessibilityLabel(
                    itemCount: 2,
                    positionLabel: "1 of 2",
                    hasTaggedMarineLife: true
                ) == "Trip media, 1 of 2, marine life tagged, swipe up for next, swipe down for previous, tap fish icon for marine life overview, View opens the linked dive"
            )
        }

        @Test @MainActor func tripDetailMediaGalleryPresentation_mediaPositionLabel_usesNumericOnlyFormat() {
            let first = DiveMediaPhoto(sortOrder: 0)
            let second = DiveMediaPhoto(sortOrder: 1, mediaKind: .video)
            let photos = [first, second]
            #expect(
                TripDetailMediaGalleryPresentation.mediaPositionLabel(selectedID: second.id, in: photos) == "2 of 2"
            )
            #expect(
                TripDetailMediaGalleryPresentation.mediaPositionLabel(selectedID: first.id, in: photos) == "1 of 2"
            )
        }

        @Test func tripDetailMediaGalleryPresentation_overlayChip_matchesCaptureTimestampCapsule() {
            #expect(TripDetailMediaGalleryPresentation.overlayChipHorizontalPadding == 10)
            #expect(TripDetailMediaGalleryPresentation.overlayChipVerticalPadding == 6)
            #expect(TripDetailMediaGalleryPresentation.overlayChipBackgroundOpacity == 0.55)
            #expect(
                LinkedMediaFullscreenPresentation.topChromeControlHeight
                    == AppToolbarIconButtonMetrics.tapDimension
            )
        }

        @Test func tripDetailMediaGalleryPresentation_showsMarineLifeTagIndicator_whenSpeciesTagged() {
            let mediaID = UUID()
            let media = DiveMediaPhoto(id: mediaID, sortOrder: 0)
            let sighting = SightingInstance(
                marineLifeUUID: "fish-a",
                sightingDateTime: Date(),
                sightingDepthMeters: 10,
                mediaPhoto: media
            )
            #expect(
                TripDetailMediaGalleryPresentation.showsMarineLifeTagIndicator(
                    mediaID: mediaID,
                    sightings: [sighting]
                )
            )
            #expect(
                !TripDetailMediaGalleryPresentation.showsMarineLifeTagIndicator(
                    mediaID: UUID(),
                    sightings: [sighting]
                )
            )
        }

        @Test func tripDetailMediaGalleryPresentation_browseOffset_mapsVerticalSwipeToGalleryStep() {
            let threshold = TripDetailMediaGalleryPresentation.swipeAdvanceThreshold
            #expect(
                TripDetailMediaGalleryPresentation.browseOffset(forVerticalTranslation: -(threshold + 1)) == 1
            )
            #expect(
                TripDetailMediaGalleryPresentation.browseOffset(forVerticalTranslation: threshold + 1) == -1
            )
            #expect(TripDetailMediaGalleryPresentation.browseOffset(forVerticalTranslation: 0) == nil)
            #expect(TripDetailMediaGalleryPresentation.swipeAdvanceThreshold == 36)
            #expect(TripDetailMediaGalleryPresentation.browseAnimationDuration == 0.32)
        }

        @Test func tripDetailMediaGalleryPresentation_interactiveBrowse_followsVerticalDrag() {
            let height: CGFloat = 400
            let halfway: CGFloat = -200

            #expect(
                TripDetailMediaGalleryPresentation.interactiveBrowseProgress(
                    verticalTranslation: halfway,
                    previewHeight: height
                ) == 0.5
            )
            #expect(
                TripDetailMediaGalleryPresentation.adjacentItemOffset(
                    verticalTranslation: halfway,
                    previewHeight: height
                ) == 200
            )
            #expect(
                abs(TripDetailMediaGalleryPresentation.interactiveCurrentScale(progress: 0.5) - 0.93) < 1e-9
            )
            #expect(
                TripDetailMediaGalleryPresentation.interactiveCommitTranslation(step: 1, previewHeight: height) == -400
            )
            #expect(
                TripDetailMediaGalleryPresentation.rubberBandedBrowseTranslation(
                    -120,
                    canBrowseForward: false,
                    canBrowseBackward: true
                ) == -33.6
            )
            #expect(DiveTripPresentation.tripMediaOpenOnDiveButtonTitle == "View")
        }

        @Test func tripDetailMediaGalleryPresentation_taggedSpecies_resolvesFromSightings() {
            let mediaID = UUID()
            let media = DiveMediaPhoto(id: mediaID, sortOrder: 0)
            let queen = MarineLife(
                uuid: "fish-queen",
                commonName: "Queen Angelfish",
                scientificName: "Holacanthus ciliaris",
                category: "fish"
            )
            let sighting = SightingInstance(
                marineLifeUUID: queen.uuid,
                sightingDateTime: Date(),
                sightingDepthMeters: 12,
                mediaPhoto: media
            )

            let species = TripDetailMediaGalleryPresentation.taggedSpecies(
                mediaID: mediaID,
                sightings: [sighting],
                catalog: [queen]
            )
            #expect(species.map(\.uuid) == [queen.uuid])
            #expect(TripDetailMediaGalleryPresentation.marineLifeOverlayFeatureImageHeight == 148)
            #expect(TripDetailMediaGalleryPresentation.marineLifeOverlayFeatureImageMaxWidth == 220)
        }

        @Test func tripDetailMarineLifePresentation_carouselItems_useFieldGuideMosaicFormat() {
            let french = MarineLifeCatalogSnapshot(
                uuid: "fish-b",
                commonName: "French Angelfish",
                scientificName: "Pomacanthus paru",
                category: "fishes",
                subcategory: "angelfishes",
                featureImageURL: "",
                minSizeMeters: 0.25,
                maxSizeMeters: 0.45,
                avgDepthMeters: 14
            )
            let items = TripDetailMarineLifePresentation.carouselItems(
                from: [
                    DiveTripMarineLifeSummary(marineLifeUUID: "fish-a", commonName: "Queen Angelfish", sightingCount: 3),
                    DiveTripMarineLifeSummary(marineLifeUUID: "fish-b", commonName: "French Angelfish", sightingCount: 1),
                ],
                catalogByUUID: ["fish-b": french]
            )
            #expect(items.count == 2)
            #expect(items[0].catalogSnapshot.commonName == "Queen Angelfish")
            #expect(items[0].sightingCountLabel == "3 sightings")
            #expect(items[0].hasCatalogEntry == false)
            #expect(items[0].categoryID == "fishes")
            #expect(items[1].catalogSnapshot.commonName == "French Angelfish")
            #expect(items[1].catalogSnapshot.scientificName == "Pomacanthus paru")
            #expect(items[1].categoryID == "fishes")
            #expect(items[1].sightingCountLabel == "1 sighting")
            #expect(items[1].hasCatalogEntry)
        }

        @Test func tripDetailMarineLifePresentation_sightingCountLabel_formatsCounts() {
            #expect(TripDetailMarineLifePresentation.sightingCountLabel(count: 0) == "No sightings")
            #expect(TripDetailMarineLifePresentation.sightingCountLabel(count: 1) == "1 sighting")
            #expect(TripDetailMarineLifePresentation.sightingCountLabel(count: 4) == "4 sightings")
        }

        @Test func tripDetailMapPresentation_mapHeroHeight_matchesHomeAndBuddySeam() {
            let pushedGeometryHeight: CGFloat = 852
            let homeTabViewportHeight = HomeOverviewLayout.viewportHeightMatchingHomeTab(
                from: pushedGeometryHeight
            )
            let screenWidth: CGFloat = 393
            let topSafeAreaInset: CGFloat = 59
            let statsBand = TripDetailMapPresentation.heroLayoutStatsPanelContentHeight
            #expect(
                statsBand == DiveBuddyDetailPresentation.heroLayoutStatsPanelContentHeight
            )

            let tripHero = TripDetailMapPresentation.mapHeroHeight(
                viewportHeight: pushedGeometryHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset
            )
            let homeHero = HomeOverviewLayout.metrics(
                viewportHeight: homeTabViewportHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset,
                statsPanelContentHeight: statsBand
            ).heroHeight
            let buddyHero = DiveBuddyDetailPresentation.heroHeight(
                viewportHeight: pushedGeometryHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset
            )

            #expect(tripHero == homeHero)
            #expect(tripHero == buddyHero)
        }

        @Test func diveTripPresentation_plannedSitesOverviewSummary_formatsSiteCount() {
            #expect(DiveTripPresentation.plannedSitesOverviewSummary(siteCount: 0) == "None planned")
            #expect(DiveTripPresentation.plannedSitesOverviewSummary(siteCount: 1) == "1 site")
            #expect(DiveTripPresentation.plannedSitesOverviewSummary(siteCount: 3) == "3 sites")
        }

        @Test func diveTripPresentation_plannedSitesPageSubtitle_formatsSiteCount() {
            #expect(
                DiveTripPresentation.plannedSitesPageSubtitle(siteCount: 0)
                    == DiveTripPresentation.tripPlannedSitesEmptyMessage
            )
            #expect(
                DiveTripPresentation.plannedSitesPageSubtitle(siteCount: 1)
                    == DiveTripPresentation.plannedSitesPageSavedSitesSubtitle
            )
            #expect(
                DiveTripPresentation.plannedSitesPageSubtitle(siteCount: 3)
                    == "Saved Dive Sites"
            )
            #expect(
                DiveTripPresentation.plannedSitePickerCancelAccessibilityIdentifier
                    == "TripPlannedSitePicker.Cancel"
            )
            #expect(
                DiveTripPresentation.plannedSitePickerDoneAccessibilityIdentifier
                    == "TripPlannedSitePicker.Done"
            )
        }

        @Test func diveTripPresentation_linkedDivesSummary_formatsDuration() {
            #expect(DiveTripPresentation.linkedDivesSummary(totalDurationMinutes: 95) == "95 total minutes underwater")
        }

        @Test @MainActor func diveTripPresentation_linkedDiveRowDisplayData_ordersNewestFirst() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let profile = UserProfile(appleUserIdentifier: "trip-rows", displayName: "Diver")
            context.insert(profile)

            let older = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 100_000),
                durationMinutes: 40,
                maxDepthMeters: 15
            )
            older.owner = profile
            older.ownerProfileID = profile.id
            let newer = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 200_000),
                durationMinutes: 50,
                maxDepthMeters: 18
            )
            newer.owner = profile
            newer.ownerProfileID = profile.id
            context.insert(older)
            context.insert(newer)

            let trip = DiveTrip(
                startDate: Date(timeIntervalSince1970: 90_000),
                endDate: Date(timeIntervalSince1970: 210_000),
                countries: ["Bonaire"],
                owner: profile
            )
            context.insert(trip)
            _ = DiveTripActivityLinking.link(older, to: trip, modelContext: context)
            _ = DiveTripActivityLinking.link(newer, to: trip, modelContext: context)
            try context.save()

            let rows = DiveTripPresentation.linkedDiveRowDisplayData(
                trip: trip,
                unitSystem: .metric,
                useChronologicalNumbers: false,
                numberingActivities: [older, newer]
            )
            #expect(rows.map(\.id) == [newer.id, older.id])
        }

        @Test func diveTripFormValues_toggleCountry_addsAndRemovesCanonicalNames() {
            var countries: [String] = []
            DiveTripFormValues.toggleCountry("Dutch Caribbean", in: &countries)
            #expect(countries == [DiveSiteCountryPresentation.caribbeanNetherlands])
            DiveTripFormValues.toggleCountry("Curaçao", in: &countries)
            #expect(countries == [DiveSiteCountryPresentation.caribbeanNetherlands, "Curaçao"])
            DiveTripFormValues.toggleCountry("caribbean netherlands", in: &countries)
            #expect(countries == ["Curaçao"])
        }

        @Test @MainActor func tripDetailMediaGalleryFeaturedStarPlacement_supportsDiveLandscapeTopTrailing() {
            #expect(TripDetailMediaGalleryFeaturedStarPlacement.bottomTrailing != .topTrailing)
        }

            @Test func diveTripAggregateBuilder_totalsLongestDeepestBuddiesAndMarineLife() {
                let diveA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                let diveB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
                let buddyID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
                let dives = [
                    DiveTripDiveSnapshot(
                        id: diveA,
                        startTime: Date(timeIntervalSince1970: 1_000),
                        durationMinutes: 48,
                        maxDepthMeters: 24,
                        siteDisplayName: "Salt Pier",
                        diveSiteID: nil,
                        buddyIDs: [buddyID],
                        buddyDisplayNames: ["Alex"]
                    ),
                    DiveTripDiveSnapshot(
                        id: diveB,
                        startTime: Date(timeIntervalSince1970: 2_000),
                        durationMinutes: 62,
                        maxDepthMeters: 30,
                        siteDisplayName: "Hilma Hooker",
                        diveSiteID: nil,
                        buddyIDs: [buddyID],
                        buddyDisplayNames: ["Alex"]
                    ),
                ]
                let sightings = [
                    DiveTripSightingSnapshot(marineLifeUUID: "fish-a", commonName: "Queen Angelfish", diveActivityID: diveA),
                    DiveTripSightingSnapshot(marineLifeUUID: "fish-a", commonName: "Queen Angelfish", diveActivityID: diveB),
                    DiveTripSightingSnapshot(marineLifeUUID: "fish-b", commonName: "French Angelfish", diveActivityID: diveB),
                ]
                let aggregate = DiveTripAggregateBuilder.build(
                    linkedDives: dives,
                    sightings: sightings,
                    plannedSiteNames: ["Something Else"],
                    countries: ["Bonaire"]
                )
                #expect(aggregate.diveCount == 2)
                #expect(aggregate.totalDurationMinutes == 110)
                #expect(aggregate.longestDive?.diveID == diveB)
                #expect(aggregate.longestDive?.durationMinutes == 62)
                #expect(aggregate.deepestDive?.diveID == diveB)
                #expect(aggregate.deepestDive?.maxDepthMeters == 30)
                #expect(aggregate.buddies.count == 1)
                #expect(aggregate.buddies[0].diveCount == 2)
                #expect(aggregate.marineLife.count == 2)
                #expect(aggregate.marineLife[0].marineLifeUUID == "fish-a")
                #expect(aggregate.marineLife[0].sightingCount == 2)
                #expect(aggregate.visitedSiteNames == ["Hilma Hooker", "Salt Pier"])
                #expect(aggregate.plannedSiteNames == ["Something Else"])
                #expect(aggregate.countries == ["Bonaire"])
            }
            @Test func diveTripStatsPresentation_showsStatsWhenTripHasStarted() {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
                let futureStart = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
                let startedToday = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
                let pastStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!

                #expect(
                    !DiveTripStatsPresentation.shouldShowStats(
                        tripStartDate: futureStart,
                        referenceDate: reference,
                        calendar: calendar
                    )
                )
                #expect(
                    DiveTripStatsPresentation.shouldShowStats(
                        tripStartDate: startedToday,
                        referenceDate: reference,
                        calendar: calendar
                    )
                )
                #expect(
                    DiveTripStatsPresentation.shouldShowStats(
                        tripStartDate: pastStart,
                        referenceDate: reference,
                        calendar: calendar
                    )
                )
            }
            @Test func diveTripStatsPresentation_buildsHighlightTilesFromAggregate() {
                let diveA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                let diveB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
                let aggregate = DiveTripAggregateBuilder.build(
                    linkedDives: [
                        DiveTripDiveSnapshot(
                            id: diveA,
                            startTime: Date(timeIntervalSince1970: 1_000),
                            durationMinutes: 48,
                            maxDepthMeters: 24,
                            siteDisplayName: "Salt Pier",
                            diveSiteID: nil,
                            buddyIDs: [],
                            buddyDisplayNames: []
                        ),
                        DiveTripDiveSnapshot(
                            id: diveB,
                            startTime: Date(timeIntervalSince1970: 2_000),
                            durationMinutes: 62,
                            maxDepthMeters: 30,
                            siteDisplayName: "Hilma Hooker",
                            diveSiteID: nil,
                            buddyIDs: [],
                            buddyDisplayNames: []
                        ),
                    ],
                    sightings: [],
                    plannedSiteNames: [],
                    countries: []
                )

                let tiles = DiveTripStatsPresentation.highlightTiles(from: aggregate, unitSystem: .metric)
                #expect(tiles.count == DiveTripStatsPresentation.highlightTileCount)
                #expect(tiles[0].id == "dives")
                #expect(tiles[0].value == "2")
                #expect(tiles[0].footnote == DiveTripStatsPresentation.diveCountFootnotePlural)
                #expect(tiles[1].id == "underwater-time")
                #expect(tiles[1].value == "1 hr 50 min")
                #expect(tiles[1].footnote == DiveTripStatsPresentation.totalBottomTimeFootnote)
                #expect(tiles[2].id == "deepest")
                #expect(tiles[2].value == "30.0 m")
                #expect(tiles[2].footnote == DiveTripStatsPresentation.maxDepthFootnote)
                #expect(tiles[2].linkedDiveID == diveB)
                #expect(tiles[3].id == "longest")
                #expect(tiles[3].value == "1 hr 2 min")
                #expect(tiles[3].footnote == DiveTripStatsPresentation.bottomTimeFootnote)
                #expect(tiles[0].linkedDiveID == nil)
                #expect(tiles[1].linkedDiveID == nil)
            }
            @Test func diveTripStatsPresentation_omitsLinkedDiveWhenStatEmpty() {
                let aggregate = DiveTripAggregateBuilder.build(
                    linkedDives: [
                        DiveTripDiveSnapshot(
                            id: UUID(),
                            startTime: Date(timeIntervalSince1970: 1_000),
                            durationMinutes: 0,
                            maxDepthMeters: 0,
                            siteDisplayName: "Salt Pier",
                            diveSiteID: nil,
                            buddyIDs: [],
                            buddyDisplayNames: []
                        ),
                    ],
                    sightings: [],
                    plannedSiteNames: [],
                    countries: []
                )

                let tiles = DiveTripStatsPresentation.highlightTiles(from: aggregate, unitSystem: .metric)
                #expect(tiles[2].linkedDiveID == nil)
                #expect(tiles[3].linkedDiveID == nil)
            }
            @Test func diveTripAggregateBuilder_buddySummariesCountDistinctLinkedDives() {
                let buddyA = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
                let buddyB = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
                let diveA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
                let diveB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
                let diveC = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

                let aggregate = DiveTripAggregateBuilder.build(
                    linkedDives: [
                        DiveTripDiveSnapshot(
                            id: diveA,
                            startTime: Date(timeIntervalSince1970: 1_000),
                            durationMinutes: 40,
                            maxDepthMeters: 18,
                            siteDisplayName: "Salt Pier",
                            diveSiteID: nil,
                            buddyIDs: [buddyA, buddyB],
                            buddyDisplayNames: ["Alex", "Jordan"]
                        ),
                        DiveTripDiveSnapshot(
                            id: diveB,
                            startTime: Date(timeIntervalSince1970: 2_000),
                            durationMinutes: 50,
                            maxDepthMeters: 24,
                            siteDisplayName: "Hilma Hooker",
                            diveSiteID: nil,
                            buddyIDs: [buddyA],
                            buddyDisplayNames: ["Alex"]
                        ),
                        DiveTripDiveSnapshot(
                            id: diveC,
                            startTime: Date(timeIntervalSince1970: 3_000),
                            durationMinutes: 35,
                            maxDepthMeters: 20,
                            siteDisplayName: "Something Special",
                            diveSiteID: nil,
                            buddyIDs: [buddyB],
                            buddyDisplayNames: ["Jordan"]
                        ),
                    ],
                    sightings: [],
                    plannedSiteNames: [],
                    countries: []
                )

                #expect(aggregate.buddies.count == 2)
                #expect(aggregate.buddies[0].buddyID == buddyA)
                #expect(aggregate.buddies[0].diveCount == 2)
                #expect(aggregate.buddies[1].buddyID == buddyB)
                #expect(aggregate.buddies[1].diveCount == 2)
            }
            @Test @MainActor func diveTripActivityLinking_linksDiveAndSuggestsDateMatches() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let profile = UserProfile(appleUserIdentifier: "trip-test", displayName: "Diver")
                context.insert(profile)

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
                let end = calendar.date(from: DateComponents(year: 2026, month: 5, day: 7))!
                let trip = DiveTrip(startDate: start, endDate: end, countries: ["Bonaire"], owner: profile)
                context.insert(trip)

                let inTrip = DiveActivity(
                    source: .manual,
                    startTime: calendar.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 10))!,
                    durationMinutes: 50,
                    maxDepthMeters: 18
                )
                inTrip.owner = profile
                inTrip.ownerProfileID = profile.id
                let outOfTrip = DiveActivity(
                    source: .manual,
                    startTime: calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 10))!,
                    durationMinutes: 40,
                    maxDepthMeters: 15
                )
                outOfTrip.owner = profile
                outOfTrip.ownerProfileID = profile.id
                context.insert(inTrip)
                context.insert(outOfTrip)
                try context.save()

                let link = DiveTripActivityLinking.link(inTrip, to: trip, modelContext: context)
                #expect(link.tripID == trip.id)
                #expect(link.diveActivityID == inTrip.id)
                let duplicate = DiveTripActivityLinking.link(inTrip, to: trip, modelContext: context)
                #expect(duplicate.id == link.id)

                let candidates = DiveTripActivityLinking.candidateActivities(for: trip, activities: [inTrip, outOfTrip], calendar: calendar)
                #expect(candidates.map(\.id) == [inTrip.id])
            }
            @Test @MainActor func diveTripActivityLinking_autoLinksStartedTripsOnly() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let profile = UserProfile(appleUserIdentifier: "trip-auto-link", displayName: "Diver")
                context.insert(profile)

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
                let pastStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
                let pastEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 7))!
                let futureStart = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
                let futureEnd = calendar.date(from: DateComponents(year: 2026, month: 7, day: 7))!

                let pastTrip = DiveTrip(startDate: pastStart, endDate: pastEnd, countries: ["Bonaire"], owner: profile)
                let futureTrip = DiveTrip(startDate: futureStart, endDate: futureEnd, countries: ["Curaçao"], owner: profile)
                context.insert(pastTrip)
                context.insert(futureTrip)

                let inRange = DiveActivity(
                    source: .manual,
                    startTime: calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 10))!,
                    durationMinutes: 50,
                    maxDepthMeters: 18
                )
                inRange.owner = profile
                inRange.ownerProfileID = profile.id
                context.insert(inRange)
                try context.save()

                #expect(!DiveTripActivityLinking.hasStarted(trip: futureTrip, referenceDate: reference, calendar: calendar))
                #expect(DiveTripActivityLinking.hasStarted(trip: pastTrip, referenceDate: reference, calendar: calendar))

                let linked = DiveTripActivityLinking.applyAutoLink(
                    to: pastTrip,
                    activities: [inRange],
                    modelContext: context,
                    referenceDate: reference,
                    calendar: calendar
                )
                #expect(linked == 1)
                #expect(pastTrip.activityLinks.count == 1)
                #expect(pastTrip.activityLinks.first?.diveActivityID == inRange.id)

                let futureLinked = DiveTripActivityLinking.applyAutoLink(
                    to: futureTrip,
                    activities: [inRange],
                    modelContext: context,
                    referenceDate: reference,
                    calendar: calendar
                )
                #expect(futureLinked == 0)
                #expect(futureTrip.activityLinks.isEmpty)

                let duplicateLinked = DiveTripActivityLinking.applyAutoLink(
                    to: pastTrip,
                    activities: [inRange],
                    modelContext: context,
                    referenceDate: reference,
                    calendar: calendar
                )
                #expect(duplicateLinked == 0)
                #expect(pastTrip.activityLinks.count == 1)
            }
            @Test @MainActor func diveTripActivityLinking_linkMovesDiveFromPreviousTrip() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let profile = UserProfile(appleUserIdentifier: "trip-move-link", displayName: "Diver")
                context.insert(profile)

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let tripAStart = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
                let tripAEnd = calendar.date(from: DateComponents(year: 2026, month: 5, day: 7))!
                let tripBStart = calendar.date(from: DateComponents(year: 2026, month: 5, day: 8))!
                let tripBEnd = calendar.date(from: DateComponents(year: 2026, month: 5, day: 14))!
                let tripA = DiveTrip(startDate: tripAStart, endDate: tripAEnd, countries: ["Bonaire"], owner: profile)
                let tripB = DiveTrip(startDate: tripBStart, endDate: tripBEnd, countries: ["Curaçao"], owner: profile)
                context.insert(tripA)
                context.insert(tripB)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: calendar.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 10))!,
                    durationMinutes: 50,
                    maxDepthMeters: 18
                )
                dive.owner = profile
                dive.ownerProfileID = profile.id
                context.insert(dive)
                try context.save()

                _ = DiveTripActivityLinking.link(dive, to: tripA, modelContext: context)
                #expect(tripA.activityLinks.count == 1)
                #expect(dive.tripActivityLinks.count == 1)

                _ = DiveTripActivityLinking.link(dive, to: tripB, modelContext: context)
                try context.save()

                #expect(tripA.activityLinks.isEmpty)
                #expect(tripB.activityLinks.count == 1)
                #expect(dive.tripActivityLinks.count == 1)
                #expect(dive.tripActivityLinks.first?.tripID == tripB.id)
            }
            @Test @MainActor func diveTripActivityLinking_autoLinkSkipsDivesLinkedToAnotherTrip() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let profile = UserProfile(appleUserIdentifier: "trip-exclusive-auto", displayName: "Diver")
                context.insert(profile)

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 20))!
                let tripAStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
                let tripAEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 7))!
                let tripBStart = calendar.date(from: DateComponents(year: 2026, month: 6, day: 8))!
                let tripBEnd = calendar.date(from: DateComponents(year: 2026, month: 6, day: 14))!
                let tripA = DiveTrip(startDate: tripAStart, endDate: tripAEnd, countries: ["Bonaire"], owner: profile)
                let tripB = DiveTrip(startDate: tripBStart, endDate: tripBEnd, countries: ["Curaçao"], owner: profile)
                context.insert(tripA)
                context.insert(tripB)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: calendar.date(from: DateComponents(year: 2026, month: 6, day: 3, hour: 10))!,
                    durationMinutes: 50,
                    maxDepthMeters: 18
                )
                dive.owner = profile
                dive.ownerProfileID = profile.id
                context.insert(dive)
                try context.save()

                _ = DiveTripActivityLinking.link(dive, to: tripA, modelContext: context)
                try context.save()

                let linkedToB = DiveTripActivityLinking.applyAutoLink(
                    to: tripB,
                    activities: [dive],
                    modelContext: context,
                    referenceDate: reference,
                    calendar: calendar
                )
                #expect(linkedToB == 0)
                #expect(tripB.activityLinks.isEmpty)
                #expect(tripA.activityLinks.count == 1)
                #expect(dive.tripActivityLinks.count == 1)
            }
}
