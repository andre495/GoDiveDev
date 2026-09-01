//
//  DiveActivityLogbookTests.swift
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


struct DiveActivityLogbookTests {
        @Test @MainActor func diveTripLogbookSync_notifyGroupingDidChange_notifiesObservers() async {
            final class Counter: @unchecked Sendable { var value = 0 }
            let counter = Counter()
            let token = NotificationCenter.default.addObserver(
                forName: .diveTripLogbookGroupingDidChange,
                object: nil,
                queue: nil
            ) { _ in counter.value += 1 }
            defer { NotificationCenter.default.removeObserver(token) }

            DiveTripLogbookSync.notifyGroupingDidChange()
            await Task.yield()
            #expect(counter.value >= 1)
        }

        @Test @MainActor func logbookTripGroupingSync_syncToken_changesWhenTripLinkCountChanges() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let profile = UserProfile(appleUserIdentifier: "sync-token-test", displayName: "Diver")
            context.insert(profile)

            let trip = DiveTrip(startDate: .now, endDate: .now, countries: ["Bonaire"], owner: profile)
            let activity = DiveActivity(source: .manual, startTime: .now, durationMinutes: 45, maxDepthMeters: 20)
            activity.owner = profile
            activity.ownerProfileID = profile.id
            context.insert(trip)
            context.insert(activity)
            try context.save()

            let before = LogbookTripGroupingSync.syncToken(ownerTrips: [trip], activities: [activity])
            _ = DiveTripActivityLinking.link(activity, to: trip, modelContext: context)
            let after = LogbookTripGroupingSync.syncToken(ownerTrips: [trip], activities: [activity])
            #expect(before != after)
        }

        @Test func diveActivityDiveNumbering_partialRenumberNoop_whenDeletingNewest() {
            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let b = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
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
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
            let deletedMid = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
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
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
            let deletedMid = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
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
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let c = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
            let deleted = DiveActivity(source: .manual, startTime: Date(timeIntervalSince1970: -10_000), durationMinutes: 1, maxDepthMeters: 1)
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
            let newest = DiveActivity(source: .manual, startTime: t.addingTimeInterval(100), durationMinutes: 1, maxDepthMeters: 1)
            let older = DiveActivity(source: .manual, startTime: t, durationMinutes: 1, maxDepthMeters: 1)
            let sameTimeA = DiveActivity(source: .manual, startTime: t, durationMinutes: 1, maxDepthMeters: 1)
            let sameTimeB = DiveActivity(source: .manual, startTime: t, durationMinutes: 1, maxDepthMeters: 1)

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

        @Test @MainActor func logbookRoute_includesCatalogSiteDetail() {
            let siteID = UUID()
            #expect(LogbookRoute.diveSite(siteID) == LogbookRoute.diveSite(siteID))
            #expect(LogbookRoute.diveSite(siteID) != LogbookRoute.tripDetail(siteID))
            #expect(LogbookRoute.tripPlanner != LogbookRoute.addActivity)
        }

        @Test @MainActor func logbookPendingRouteNavigation_addActivityReplacesStack() {
            let diveID = UUID()
            let path = LogbookPendingRouteNavigation.path(
                afterConsuming: .addActivity,
                currentPath: [.diveDetail(diveID)]
            )
            #expect(path == [.addActivity])
        }

        @Test @MainActor func logbookAddActivityPresentation_hubOptionsMapToRoutes() {
            let routes = LogbookAddActivityPresentation.hubOptions.map(\.route)
            #expect(routes == [.diveActivityUpload, .snorkelActivityUpload, .connectDeviceComingSoon])
            #expect(LogbookAddActivityPresentation.hubOptions.count == 3)
            #expect(LogbookAddActivityPresentation.hubOptions[1].subtitle.contains("manually"))
        }

        @Test func logbookActivityRowPresentation_activityKindSymbols() {
            #expect(LogbookActivityRowPresentation.scubaDiveLeadingSymbolName == "water.waves.and.arrow.trianglehead.down")
            #expect(LogbookActivityRowPresentation.snorkelLeadingSymbolName == "figure.pool.swim")
        }

        @Test func logbookDisplayCacheBuilder_snorkelRowUsesSnorkelChipAndDetailLine() {
            let snorkelID = UUID()
            let diveID = UUID()
            let newer = Date(timeIntervalSinceReferenceDate: 100)
            let older = Date(timeIntervalSinceReferenceDate: 0)
            let seeds = [
                LogbookActivitySnapshotSeed(
                    id: diveID,
                    kind: .scubaDive,
                    sourceDiveId: nil,
                    sourceActivityId: nil,
                    startTime: older,
                    maxDepthMeters: 20,
                    swimDistanceMeters: nil,
                    durationMinutes: 40,
                    bottomTimeSeconds: nil,
                    diveNumber: 1,
                    diveNumberExplicitlyNone: false,
                    displayName: "Reef",
                    formattedStartDateOnly: "Jan 1",
                    resolvedSiteNameLowercased: "reef",
                    activityTagNames: [],
                    buddyDisplayNames: [],
                    previewMediaPhotoID: nil,
                    linkedTripID: nil,
                    previewMediaIsSnorkel: false
                ),
                LogbookActivitySnapshotSeed(
                    id: snorkelID,
                    kind: .snorkel,
                    sourceDiveId: nil,
                    sourceActivityId: "fit-snorkel",
                    startTime: newer,
                    maxDepthMeters: 0.1,
                    swimDistanceMeters: 210,
                    durationMinutes: 35,
                    bottomTimeSeconds: nil,
                    diveNumber: nil,
                    diveNumberExplicitlyNone: true,
                    displayName: "Lagoon",
                    formattedStartDateOnly: "Jan 2",
                    resolvedSiteNameLowercased: "lagoon",
                    activityTagNames: [],
                    buddyDisplayNames: [],
                    previewMediaPhotoID: nil,
                    linkedTripID: nil,
                    previewMediaIsSnorkel: true
                ),
            ]
            let built = LogbookDisplayCacheBuilder.build(
                visibleSeeds: seeds,
                tripSeeds: [],
                siteSearchQuery: "",
                unitSystem: .metric,
                useChronologicalNumbers: true,
                includeDuplicateScan: false
            )
            let snorkelRow = built.rows.first { $0.id == snorkelID }
            #expect(snorkelRow?.diveNumberLabel == "Snorkel")
            #expect(snorkelRow?.diveNumberLeadingSymbolName == "figure.pool.swim")
            #expect(snorkelRow?.detailLine.contains("210 m") == true)
            let diveRow = built.rows.first { $0.id == diveID }
            #expect(diveRow?.diveNumberLeadingSymbolName == "water.waves.and.arrow.trianglehead.down")
        }

        @Test func logbookActivitySnapshotSeeding_sortedMergedSeeds_ordersNewestFirst() {
            let olderID = UUID()
            let newerID = UUID()
            let older = LogbookActivitySnapshotSeed(
                id: olderID,
                kind: .scubaDive,
                sourceDiveId: nil,
                sourceActivityId: nil,
                startTime: Date(timeIntervalSince1970: 100),
                maxDepthMeters: 10,
                swimDistanceMeters: nil,
                durationMinutes: 30,
                bottomTimeSeconds: nil,
                diveNumber: 1,
                diveNumberExplicitlyNone: false,
                displayName: "Older",
                formattedStartDateOnly: "A",
                resolvedSiteNameLowercased: nil,
                activityTagNames: [],
                buddyDisplayNames: [],
                previewMediaPhotoID: nil,
                linkedTripID: nil,
                previewMediaIsSnorkel: false
            )
            let newer = LogbookActivitySnapshotSeed(
                id: newerID,
                kind: .snorkel,
                sourceDiveId: nil,
                sourceActivityId: nil,
                startTime: Date(timeIntervalSince1970: 200),
                maxDepthMeters: 0,
                swimDistanceMeters: 100,
                durationMinutes: 40,
                bottomTimeSeconds: nil,
                diveNumber: nil,
                diveNumberExplicitlyNone: true,
                displayName: "Newer",
                formattedStartDateOnly: "B",
                resolvedSiteNameLowercased: nil,
                activityTagNames: [],
                buddyDisplayNames: [],
                previewMediaPhotoID: nil,
                linkedTripID: nil,
                previewMediaIsSnorkel: true
            )
            let sorted = LogbookActivitySnapshotSeeding.sortedMergedSeeds([older, newer])
            #expect(sorted.map(\.id) == [newerID, olderID])
        }

        @Test func diveLogbookDisplay_previewMediaPhotoID_usesOldestGalleryPhoto() {
            let activity = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 30,
                maxDepthMeters: 12,
                diveNumber: 3
            )
            let oldest = DiveMediaPhoto(
                sortOrder: 1,
                capturedAt: Date(timeIntervalSince1970: 500),
                dive: activity
            )
            let newest = DiveMediaPhoto(
                sortOrder: 0,
                capturedAt: Date(timeIntervalSince1970: 1_500),
                dive: activity
            )
            activity.mediaPhotos = [newest, oldest]

            let rows = DiveLogbookDisplay.rowData(
                activities: [activity],
                unitSystem: .metric,
                duplicateIds: [],
                useChronologicalNumbers: false
            )
            #expect(rows.first?.previewMediaPhotoID == oldest.id)
        }

        @Test func diveLogbookDisplay_previewMediaPhotoID_usesExplicitFeaturedWhenSet() {
            let activity = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 30,
                maxDepthMeters: 12,
                diveNumber: 4
            )
            let oldest = DiveMediaPhoto(sortOrder: 1, capturedAt: Date(timeIntervalSince1970: 500), dive: activity)
            let newest = DiveMediaPhoto(sortOrder: 0, capturedAt: Date(timeIntervalSince1970: 1_500), dive: activity)
            activity.mediaPhotos = [newest, oldest]
            activity.featuredMediaPhotoID = newest.id

            let rows = DiveLogbookDisplay.rowData(
                activities: [activity],
                unitSystem: .metric,
                duplicateIds: [],
                useChronologicalNumbers: false
            )
            #expect(rows.first?.previewMediaPhotoID == newest.id)
        }

        @Test func logbookActivityRowLayout_usesCompactSpacingTokens() {
            #expect(LogbookActivityRowLayout.contentSpacing == 4)
            #expect(LogbookActivityRowLayout.cardPadding == AppTheme.Spacing.sm)
            #expect(DiveActivityMediaPresentation.logbookRowMediaPreviewMinExtent == 48)
        }

        @Test func logbookRootAppearPresentation_defersCacheUntilLogbookTabSelected() {
            #expect(
                !LogbookRootAppearPresentation.shouldBuildCacheOnAppear(
                    isLogbookTabSelected: false,
                    hasPerformedInitialCacheBuild: false
                )
            )
            #expect(
                LogbookRootAppearPresentation.shouldBuildCacheOnAppear(
                    isLogbookTabSelected: true,
                    hasPerformedInitialCacheBuild: false
                )
            )
            #expect(
                !LogbookRootAppearPresentation.shouldBuildCacheOnAppear(
                    isLogbookTabSelected: true,
                    hasPerformedInitialCacheBuild: true
                )
            )
            #expect(
                !LogbookRootAppearPresentation.shouldBuildCacheOnAppear(
                    isLogbookTabSelected: false,
                    hasPerformedInitialCacheBuild: true
                )
            )
        }

        @Test func logbookRootAppearPresentation_rebuildsOnTabSelectOnlyWhenColdOrEmpty() {
            // Cold with zero activities: do not latch an empty build.
            #expect(
                !LogbookRootAppearPresentation.shouldRebuildCacheOnTabSelect(
                    isLogbookTabSelected: true,
                    hasPerformedInitialCacheBuild: false,
                    hasDisplayRows: false,
                    hasVisibleActivities: false
                )
            )
            #expect(
                LogbookRootAppearPresentation.shouldRebuildCacheOnTabSelect(
                    isLogbookTabSelected: true,
                    hasPerformedInitialCacheBuild: false,
                    hasDisplayRows: false,
                    hasVisibleActivities: true
                )
            )
            #expect(
                !LogbookRootAppearPresentation.shouldRebuildCacheOnTabSelect(
                    isLogbookTabSelected: true,
                    hasPerformedInitialCacheBuild: true,
                    hasDisplayRows: true,
                    hasVisibleActivities: true
                )
            )
            #expect(
                LogbookRootAppearPresentation.shouldRebuildCacheOnTabSelect(
                    isLogbookTabSelected: true,
                    hasPerformedInitialCacheBuild: true,
                    hasDisplayRows: false,
                    hasVisibleActivities: true
                )
            )
            #expect(
                !LogbookRootAppearPresentation.shouldRebuildCacheOnTabSelect(
                    isLogbookTabSelected: true,
                    hasPerformedInitialCacheBuild: true,
                    hasDisplayRows: false,
                    hasVisibleActivities: false
                )
            )
            #expect(
                !LogbookRootAppearPresentation.shouldRebuildCacheOnTabSelect(
                    isLogbookTabSelected: false,
                    hasPerformedInitialCacheBuild: false,
                    hasDisplayRows: false,
                    hasVisibleActivities: true
                )
            )
            #expect(
                !LogbookRootAppearPresentation.shouldApplyDisplayCacheResult(
                    incomingItemCount: 0,
                    visibleActivityCount: 4
                )
            )
            #expect(
                LogbookRootAppearPresentation.shouldApplyDisplayCacheResult(
                    incomingItemCount: 0,
                    visibleActivityCount: 0
                )
            )
        }

        @Test func logbookRow_displayName_usesTrimmedSiteElseNewDive() {
            #expect(LogbookActivityRow.displayName(resolvedSiteName: "  Wall  ") == "Wall")
            #expect(LogbookActivityRow.displayName(resolvedSiteName: nil) == "New Dive")
            #expect(LogbookActivityRow.displayName(resolvedSiteName: "   ") == "New Dive")
        }

        @Test func diveLogbookSiteSearch_emptyQuery_returnsAllSeeds() {
            let a = logbookSnapshotSeed(resolvedSiteNameLowercased: "salt pier")
            let b = logbookSnapshotSeed(resolvedSiteNameLowercased: nil)
            let filtered = DiveLogbookSiteSearch.filtering([a, b], siteQuery: "   ")
            #expect(filtered.count == 2)
            #expect(DiveLogbookSiteSearch.isFiltering(query: "") == false)
        }

        @Test func diveLogbookSiteSearch_matchesResolvedSiteName_caseInsensitiveSubstring() {
            #expect(DiveLogbookSiteSearch.matchesSite(resolvedSiteName: "Salt Pier", query: "salt"))
            #expect(DiveLogbookSiteSearch.matchesSite(resolvedSiteName: "Salt Pier", query: "PIER"))
            #expect(!DiveLogbookSiteSearch.matchesSite(resolvedSiteName: "Salt Pier", query: "turtle"))
            #expect(DiveLogbookSiteSearch.matchesSite(resolvedSiteName: "Turtle Bay", query: "bay"))
            #expect(!DiveLogbookSiteSearch.matchesSite(resolvedSiteName: nil, query: "new"))
            #expect(
                DiveLogbookSiteSearch.matchesConfirmedTag(
                    activityTagNames: ["Night dive", "Training"],
                    confirmedTagName: "night dive"
                )
            )
            #expect(
                !DiveLogbookSiteSearch.matchesConfirmedTag(
                    activityTagNames: ["Training"],
                    confirmedTagName: "Night dive"
                )
            )

            let saltPier = logbookSnapshotSeed(resolvedSiteNameLowercased: "salt pier")
            let turtleBay = logbookSnapshotSeed(resolvedSiteNameLowercased: "turtle bay")
            let unnamed = logbookSnapshotSeed(resolvedSiteNameLowercased: nil)
            #expect(
                DiveLogbookSiteSearch.filtering([saltPier, turtleBay, unnamed], siteQuery: "turtle").map(\.id)
                    == [turtleBay.id]
            )

            let tagged = logbookSnapshotSeed(
                resolvedSiteNameLowercased: "reef point",
                activityTagNames: ["Wreck", "Advanced"]
            )
            let untagged = logbookSnapshotSeed(resolvedSiteNameLowercased: "reef point")
            #expect(
                DiveLogbookSiteSearch.filtering(
                    [tagged, untagged],
                    siteQuery: "reef",
                    confirmedTagName: "Wreck"
                ).map(\.id) == [tagged.id]
            )
            #expect(
                DiveLogbookSiteSearch.filtering([tagged, untagged], siteQuery: "wreck").map(\.id) == []
            )

            #expect(
                DiveLogbookSiteSearch.matchesConfirmedBuddy(
                    buddyDisplayNames: ["Pat Lee", "Jamie"],
                    confirmedBuddyName: "pat lee"
                )
            )
            #expect(
                !DiveLogbookSiteSearch.matchesConfirmedBuddy(
                    buddyDisplayNames: ["Jamie"],
                    confirmedBuddyName: "Pat"
                )
            )

            let withPat = logbookSnapshotSeed(
                resolvedSiteNameLowercased: "salt pier",
                buddyDisplayNames: ["Pat Lee"]
            )
            let withoutPat = logbookSnapshotSeed(resolvedSiteNameLowercased: "salt pier")
            #expect(
                DiveLogbookSiteSearch.filtering(
                    [withPat, withoutPat],
                    siteQuery: "",
                    confirmedBuddyName: "Pat Lee"
                ).map(\.id) == [withPat.id]
            )
            #expect(
                DiveLogbookSiteSearch.filtering(
                    [withPat, withoutPat],
                    siteQuery: "pat",
                    confirmedBuddyName: "Pat Lee"
                ).map(\.id) == [withPat.id]
            )

            let tripID = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
            let linked = logbookSnapshotSeed(resolvedSiteNameLowercased: "salt pier", linkedTripID: tripID)
            let unlinked = logbookSnapshotSeed(resolvedSiteNameLowercased: "salt pier")
            #expect(
                DiveLogbookSiteSearch.matchesConfirmedTrip(
                    linkedTripID: tripID,
                    confirmedTripID: tripID
                )
            )
            #expect(
                !DiveLogbookSiteSearch.matchesConfirmedTrip(
                    linkedTripID: nil,
                    confirmedTripID: tripID
                )
            )
            #expect(
                DiveLogbookSiteSearch.filtering(
                    [linked, unlinked],
                    siteQuery: "",
                    confirmedTripID: tripID
                ).map(\.id) == [linked.id]
            )
        }

        @Test func logbookBuddySearchPresentation_suggestions_onlyWhileTypingWithoutActiveFilter() {
            let catalog = ["Pat Lee", "Jamie Smith", "Alex"]
            #expect(
                LogbookBuddySearchPresentation.suggestions(
                    catalogBuddyNames: catalog,
                    query: "pat",
                    activeBuddyFilter: nil,
                    activeTagFilter: nil
                ).map(\.buddyName) == ["Pat Lee"]
            )
            #expect(
                LogbookBuddySearchPresentation.suggestions(
                    catalogBuddyNames: catalog,
                    query: "pat",
                    activeBuddyFilter: "Pat Lee",
                    activeTagFilter: nil
                ).isEmpty
            )
            #expect(
                LogbookBuddySearchPresentation.suggestions(
                    catalogBuddyNames: catalog,
                    query: "pat",
                    activeBuddyFilter: nil,
                    activeTagFilter: "Training"
                ).isEmpty
            )
            #expect(
                LogbookBuddySearchPresentation.activeBuddyPromptLine(buddyName: "Pat Lee")
                    == "buddy: Pat Lee"
            )
        }

        @Test func logbookTagSearchPresentation_suggestions_onlyWhileTypingWithoutActiveTag() {
            let catalog = ["Drift Dive", "Night Dive", "Training"]
            #expect(
                LogbookTagSearchPresentation.suggestions(
                    catalogTagNames: catalog,
                    query: "drift",
                    activeTagFilter: nil
                ).map(\.tagName) == ["Drift Dive"]
            )
            #expect(
                LogbookTagSearchPresentation.suggestions(
                    catalogTagNames: catalog,
                    query: "drift",
                    activeTagFilter: "Drift Dive"
                ).isEmpty
            )
            #expect(
                LogbookTagSearchPresentation.suggestions(
                    catalogTagNames: catalog,
                    query: "",
                    activeTagFilter: nil
                ).isEmpty
            )
            #expect(
                LogbookTagSearchPresentation.activeTagPromptLine(tagName: "Drift Dive")
                    == "tag: Drift Dive"
            )
        }

        @Test func logbookTripSearchPresentation_suggestions_onlyWhileTypingWithoutActiveFilter() {
            let catalog = [
                LogbookTripSearchCatalogEntry(tripID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, displayTitle: "Bonaire 2026"),
                LogbookTripSearchCatalogEntry(tripID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, displayTitle: "Curaçao Week"),
            ]
            #expect(
                LogbookTripSearchPresentation.suggestions(
                    catalogTrips: catalog,
                    query: "bon",
                    activeTripFilter: nil,
                    activeTagFilter: nil,
                    activeBuddyFilter: nil
                ).map(\.displayTitle) == ["Bonaire 2026"]
            )
            #expect(
                LogbookTripSearchPresentation.suggestions(
                    catalogTrips: catalog,
                    query: "bon",
                    activeTripFilter: LogbookTripSearchSuggestion(
                        id: catalog[0].tripID.uuidString,
                        tripID: catalog[0].tripID,
                        displayTitle: "Bonaire 2026"
                    ),
                    activeTagFilter: nil,
                    activeBuddyFilter: nil
                ).isEmpty
            )
            #expect(
                LogbookTripSearchPresentation.activeTripPromptLine(displayTitle: "Bonaire 2026")
                    == "trip: Bonaire 2026"
            )
        }

        @Test func logbookUpcomingTripPresentation_shouldShowInLogbookList_waitsForDisplayItems() {
            #expect(
                !LogbookUpcomingTripPresentation.shouldShowInLogbookList(
                    isFilteringLogbook: false,
                    showsStoredDiveEmptyState: false,
                    hasDisplayItems: false
                )
            )
            #expect(
                LogbookUpcomingTripPresentation.shouldShowInLogbookList(
                    isFilteringLogbook: false,
                    showsStoredDiveEmptyState: false,
                    hasDisplayItems: true
                )
            )
            #expect(
                LogbookUpcomingTripPresentation.shouldShowInLogbookList(
                    isFilteringLogbook: false,
                    showsStoredDiveEmptyState: true,
                    hasDisplayItems: false
                )
            )
            #expect(
                !LogbookUpcomingTripPresentation.shouldShowInLogbookList(
                    isFilteringLogbook: true,
                    showsStoredDiveEmptyState: false,
                    hasDisplayItems: true
                )
            )
        }

        @Test func logbookUpcomingTripPresentation_nearestUpcomingBanner_picksSoonestStart() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!

            let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            let soonerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let pastID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

            let sooner = DiveTrip(
                id: soonerID,
                startDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 7, day: 7))!,
                countries: ["Bonaire"],
                title: "Sooner Trip"
            )
            let later = DiveTrip(
                id: laterID,
                startDate: calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 8, day: 7))!,
                countries: ["Curaçao"],
                title: "Later Trip"
            )
            let past = DiveTrip(
                id: pastID,
                startDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 5, day: 7))!,
                countries: ["Aruba"],
                title: "Past Trip"
            )

            #expect(
                LogbookUpcomingTripPresentation.isUpcoming(
                    trip: sooner,
                    referenceDate: reference,
                    calendar: calendar
                )
            )
            #expect(
                !LogbookUpcomingTripPresentation.isUpcoming(
                    trip: past,
                    referenceDate: reference,
                    calendar: calendar
                )
            )

            let banner = LogbookUpcomingTripPresentation.nearestUpcomingBanner(
                from: [later, sooner, past],
                referenceDate: reference,
                calendar: calendar
            )
            #expect(banner?.tripID == soonerID)
            #expect(banner?.displayTitle == "Sooner Trip")
            #expect(banner?.eyebrow == "Trip on the horizon")
        }

        @Test func logbookUpcomingTripPresentation_bannerData_mapsTripPlannerHorizonRow() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let start = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
            let end = calendar.date(from: DateComponents(year: 2026, month: 7, day: 7))!
            let trip = DiveTrip(
                startDate: start,
                endDate: end,
                countries: ["Bonaire"],
                title: "Reef week"
            )

            let banner = LogbookUpcomingTripPresentation.bannerData(for: trip)
            #expect(banner.tripID == trip.id)
            #expect(banner.eyebrow == "Trip on the horizon")
            #expect(banner.displayTitle == "Reef week")
            #expect(banner.dateLine == TripPlannerPresentation.listRowSubtitle(for: trip))
        }

        @Test func logbookListSurfaceEquatableInputs_scrollNonceChangeIsNotEqual() {
            let base = LogbookListSurfaceEquatableInputs(
                feedScope: .myActivities,
                myActivitiesKindFilter: .all,
                showsMyActivitiesKindFilterEmptyState: false,
                items: [],
                buddyFeedRows: [],
                buddyFeedHasMoreRows: false,
                buddyFeedTotalRowCount: 0,
                buddyFeedEmptyKind: nil,
                isBuddyFeedLoading: false,
                isMyActivitiesLoading: false,
                upcomingTripBanner: nil,
                showsStoredDiveEmptyState: false,
                bubbleAnimationPaused: false,
                scrollToTopNonce: 0
            )
            var scrolled = base
            scrolled.scrollToTopNonce = 1
            #expect(base == base)
            #expect(base != scrolled)
        }

        @Test func logbookAndFieldGuideCollapsibleHeaderTitles() {
            #expect(LogbookCollapsibleHeaderPresentation.title == "Activity Log")
            #expect(LogbookCollapsibleHeaderPresentation.titleAccessibilityIdentifier == "Logbook.Title")
            #expect(LogbookCollapsibleHeaderPresentation.myActivitiesSegmentTitle == "Me")
            #expect(LogbookCollapsibleHeaderPresentation.buddyFeedSegmentTitle == "Buddies")
            #expect(LogbookFeedScope.myActivities.segmentTitle == "Me")
            #expect(LogbookFeedScope.buddyFeed.segmentTitle == "Buddies")
            #expect(LogbookFeedScope.myActivities.accessibilityLabel == "Me")
            #expect(LogbookFeedScope.buddyFeed.accessibilityLabel == "Buddies")
            // Equal Me / Buddies columns are sized to the longer title.
            let equalWidth = LogbookFeedScopeTogglePresentation.equalSegmentWidth()
            #expect(
                equalWidth == LogbookFeedScopeTogglePresentation.equalSegmentWidth(titles: ["Buddies"])
            )
            #expect(
                equalWidth > LogbookFeedScopeTogglePresentation.equalSegmentWidth(titles: ["Me"])
            )
            #expect(LogbookFeedScopeTogglePresentation.usesGlassShell)
            #expect(LogbookFeedScopeTogglePresentation.shellCornerRadius == 12)
            #expect(LogbookFeedScopeTogglePresentation.segmentCornerRadius == 8)
            // Filter glass is 44pt; toggle shell is ~40pt — chrome row must use the taller height.
            #expect(
                LogbookFeedScopeTogglePresentation.chromeRowHeight
                    == AppTheme.Layout.glassChromeControlHeight
            )
            #expect(
                LogbookFeedScopeTogglePresentation.chromeRowHeight
                    > LogbookFeedScopeTogglePresentation.segmentHeight
                    + (LogbookFeedScopeTogglePresentation.shellPadding * 2)
            )
            #expect(LogbookMyActivitiesKindFilterPresentation.usesGlassButtonStyle)
            #expect(
                LogbookMyActivitiesKindFilterPresentation.showsFilterButton(for: .myActivities)
            )
            #expect(
                !LogbookMyActivitiesKindFilterPresentation.showsFilterButton(for: .buddyFeed)
            )
            #expect(LogbookFeedScope.myActivities.systemImage == "book.closed.fill")
            #expect(LogbookFeedScope.buddyFeed.systemImage == "person.2.fill")
            #expect(LogbookFeedScopePagerPresentation.pages == [.myActivities, .buddyFeed])
            #expect(LogbookFeedScopePagerPresentation.accessibilityIdentifier == "Logbook.FeedScopePager")
            #expect(FieldGuideHubPresentation.tabTitle == "Field Guide")
            #expect(FieldGuideHubPresentation.titleAccessibilityIdentifier == "FieldGuide.Hub.Title")
            #expect(
                FieldGuideCategoryPresentation.browseTitleAccessibilityIdentifier(categoryID: "fishes")
                    == "FieldGuide.Category.fishes.Title"
            )
            #expect(
                FieldGuideSubcategoryPresentation.browseTitleAccessibilityIdentifier(
                    categoryID: "fishes",
                    subcategoryID: "angelfishes"
                ) == "FieldGuide.Category.fishes.Subcategory.angelfishes.Title"
            )
            #expect(
                FieldGuideSubcategoryPresentation.browseTitleAccessibilityIdentifier(
                    categoryID: "fishes",
                    subcategoryID: ""
                ) == "FieldGuide.Category.fishes.Subcategory.all.Title"
            )
        }

        @Test func logbookFeedScopePager_swipeLeftOpensBuddyFeed_swipeRightOpensMyActivities() {
            #expect(
                LogbookFeedScopePagerPresentation.scopeAfterHorizontalSwipe(
                    from: .myActivities,
                    translationWidth: -LogbookFeedScopePagerPresentation.swipeAdvanceThreshold
                ) == .buddyFeed
            )
            #expect(
                LogbookFeedScopePagerPresentation.scopeAfterHorizontalSwipe(
                    from: .buddyFeed,
                    translationWidth: LogbookFeedScopePagerPresentation.swipeAdvanceThreshold
                ) == .myActivities
            )
            #expect(
                LogbookFeedScopePagerPresentation.scopeAfterHorizontalSwipe(
                    from: .myActivities,
                    translationWidth: LogbookFeedScopePagerPresentation.swipeAdvanceThreshold
                ) == nil
            )
            #expect(
                LogbookFeedScopePagerPresentation.scopeAfterHorizontalSwipe(
                    from: .buddyFeed,
                    translationWidth: -LogbookFeedScopePagerPresentation.swipeAdvanceThreshold
                ) == nil
            )
            #expect(
                LogbookFeedScopePagerPresentation.scopeAfterHorizontalSwipe(
                    from: .myActivities,
                    translationWidth: -(LogbookFeedScopePagerPresentation.swipeAdvanceThreshold - 1)
                ) == nil
            )
            #expect(
                LogbookFeedScopePagerPresentation.isHorizontalSwipeDominant(
                    translation: CGSize(width: 40, height: 10)
                )
            )
            #expect(
                !LogbookFeedScopePagerPresentation.isHorizontalSwipeDominant(
                    translation: CGSize(width: 10, height: 40)
                )
            )
        }

        @Test func logbookMyActivitiesSummary_headerLine_usesDiveCountAndBottomTime() {
            let seeds = [
                logbookSnapshotSeed(
                    id: UUID(),
                    resolvedSiteNameLowercased: "reef",
                    durationMinutes: 45,
                    bottomTimeSeconds: 2_700
                ),
                logbookSnapshotSeed(
                    id: UUID(),
                    resolvedSiteNameLowercased: "wall",
                    durationMinutes: 30,
                    bottomTimeSeconds: nil
                ),
                logbookSnapshotSeed(
                    id: UUID(),
                    resolvedSiteNameLowercased: "hidden",
                    durationMinutes: 20,
                    bottomTimeSeconds: 1_200,
                    diveNumberExplicitlyNone: true
                ),
            ]
            let summary = LogbookMyActivitiesSummaryPresentation.summary(from: seeds)
            #expect(summary.diveCount == 2)
            #expect(summary.totalBottomTimeSeconds == 2_700 + 30 * 60 + 1_200)
            let line = LogbookMyActivitiesSummaryPresentation.headerLine(for: summary)
            #expect(line == "2 Dives | 2 hr Bottom Time")
        }

        @Test func logbookMyActivitiesSummary_bottomTimeHoursRounded_nearestHour() {
            #expect(
                LogbookMyActivitiesSummaryPresentation.formattedBottomTimeHoursRounded(
                    totalBottomTimeSeconds: 3_600
                ) == "1 hr"
            )
            #expect(
                LogbookMyActivitiesSummaryPresentation.formattedBottomTimeHoursRounded(
                    totalBottomTimeSeconds: 5_700
                ) == "2 hr"
            )
            #expect(
                LogbookMyActivitiesSummaryPresentation.formattedBottomTimeHoursRounded(
                    totalBottomTimeSeconds: 1_799
                ) == "0 hr"
            )
            #expect(
                LogbookMyActivitiesSummaryPresentation.formattedBottomTimeHoursRounded(
                    totalBottomTimeSeconds: 1_800
                ) == "1 hr"
            )
        }

        @Test func logbookMyActivitiesSummary_singularDiveLabel() {
            let summary = LogbookMyActivitiesSummary(diveCount: 1, totalBottomTimeSeconds: 3_600)
            #expect(LogbookMyActivitiesSummaryPresentation.headerLine(for: summary) == "1 Dive | 1 hr Bottom Time")
        }

        @Test func logbookMyActivitiesSummary_showsLoadingChrome_whenStoreHasDivesButListCacheEmpty() {
            #expect(
                LogbookMyActivitiesSummaryPresentation.showsLoadingChrome(
                    feedScope: .myActivities,
                    visibleDiveCount: 12,
                    visibleSnorkelCount: 0,
                    kindFilter: .all,
                    displayItemCount: 0
                )
            )
            #expect(
                !LogbookMyActivitiesSummaryPresentation.showsLoadingChrome(
                    feedScope: .myActivities,
                    visibleDiveCount: 12,
                    visibleSnorkelCount: 0,
                    kindFilter: .all,
                    displayItemCount: 3
                )
            )
            #expect(
                !LogbookMyActivitiesSummaryPresentation.showsLoadingChrome(
                    feedScope: .buddyFeed,
                    visibleDiveCount: 12,
                    visibleSnorkelCount: 0,
                    kindFilter: .all,
                    displayItemCount: 0
                )
            )
            #expect(
                !LogbookMyActivitiesSummaryPresentation.showsLoadingChrome(
                    feedScope: .myActivities,
                    visibleDiveCount: 0,
                    visibleSnorkelCount: 0,
                    kindFilter: .all,
                    displayItemCount: 0
                )
            )
            #expect(
                !LogbookMyActivitiesSummaryPresentation.showsLoadingChrome(
                    feedScope: .myActivities,
                    visibleDiveCount: 0,
                    visibleSnorkelCount: 5,
                    kindFilter: .dives,
                    displayItemCount: 0
                )
            )
        }

        @Test func logbookMyActivitiesKindFilter_filtersMergedSeeds() {
            let dive = LogbookActivitySnapshotSeed(
                id: UUID(),
                kind: .scubaDive,
                sourceDiveId: "d1",
                sourceActivityId: nil,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                maxDepthMeters: 10,
                swimDistanceMeters: nil,
                durationMinutes: 40,
                bottomTimeSeconds: 2_400,
                diveNumber: 1,
                diveNumberExplicitlyNone: false,
                displayName: "Dive",
                formattedStartDateOnly: "Jan 1",
                resolvedSiteNameLowercased: nil,
                activityTagNames: [],
                buddyDisplayNames: [],
                previewMediaPhotoID: nil,
                linkedTripID: nil,
                previewMediaIsSnorkel: false
            )
            let snorkel = LogbookActivitySnapshotSeed(
                id: UUID(),
                kind: .snorkel,
                sourceDiveId: nil,
                sourceActivityId: "s1",
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                maxDepthMeters: 2,
                swimDistanceMeters: 400,
                durationMinutes: 30,
                bottomTimeSeconds: nil,
                diveNumber: nil,
                diveNumberExplicitlyNone: false,
                displayName: "Snorkel",
                formattedStartDateOnly: "Jan 2",
                resolvedSiteNameLowercased: nil,
                activityTagNames: [],
                buddyDisplayNames: [],
                previewMediaPhotoID: nil,
                linkedTripID: nil,
                previewMediaIsSnorkel: true
            )
            let merged = [snorkel, dive]
            #expect(
                LogbookMyActivitiesKindFilterPresentation.filteredSeeds(merged, filter: .all).count == 2
            )
            #expect(
                LogbookMyActivitiesKindFilterPresentation.filteredSeeds(merged, filter: .dives).map(\.kind)
                == [.scubaDive]
            )
            #expect(
                LogbookMyActivitiesKindFilterPresentation.filteredSeeds(merged, filter: .snorkels).map(\.kind)
                == [.snorkel]
            )
            #expect(
                LogbookMyActivitiesKindFilterPresentation.matchingStoredActivityCount(
                    diveCount: 3,
                    snorkelCount: 2,
                    filter: .dives
                ) == 3
            )
            #expect(LogbookMyActivitiesKindFilterPresentation.menuTitle(for: .snorkels) == "Snorkels")
        }

        @Test func diveActivityDuplicateMatcher_sameSourceDiveId() {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let a = DiveActivityDuplicateMatcher.Signature(
                sourceDiveId: "d1-uuid",
                startTime: start,
                maxDepthMeters: 20,
                durationMinutes: 40
            )
            let b = DiveActivityDuplicateMatcher.Signature(
                sourceDiveId: "d1-uuid",
                startTime: start.addingTimeInterval(3600),
                maxDepthMeters: 99,
                durationMinutes: 99
            )
            #expect(DiveActivityDuplicateMatcher.matchReason(candidate: a, existing: b) == .sameSourceDiveId)
        }

        @Test func diveActivityDuplicateMatcher_fingerprint_crossFormat() {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let garmin = DiveActivityDuplicateMatcher.Signature(
                sourceDiveId: "fit-1-2-3",
                startTime: start,
                maxDepthMeters: 18.2,
                durationMinutes: 45,
                bottomTimeSeconds: 2700
            )
            let mac = DiveActivityDuplicateMatcher.Signature(
                sourceDiveId: "uddf-uuid",
                startTime: start.addingTimeInterval(30),
                maxDepthMeters: 18.0,
                durationMinutes: 45,
                bottomTimeSeconds: 2701
            )
            #expect(DiveActivityDuplicateMatcher.matchReason(candidate: garmin, existing: mac) == .matchingFingerprint)
        }

        @Test func diveActivityDuplicateMatcher_fingerprint_mixedBottomAndDurationMinutes() {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let garmin = DiveActivityDuplicateMatcher.Signature(
                sourceDiveId: "fit-session",
                startTime: start,
                maxDepthMeters: 21.5,
                durationMinutes: 45,
                bottomTimeSeconds: 2700
            )
            let mac = DiveActivityDuplicateMatcher.Signature(
                sourceDiveId: "uddf-macdive-uuid",
                startTime: start.addingTimeInterval(90),
                maxDepthMeters: 21.2,
                durationMinutes: 45,
                bottomTimeSeconds: nil
            )
            #expect(DiveActivityDuplicateMatcher.matchReason(candidate: garmin, existing: mac) == .matchingFingerprint)
        }

        @Test func diveActivityDuplicateMatcher_fingerprint_sessionDurationVsBottomTime_noMatch() {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let garmin = DiveActivityDuplicateMatcher.Signature(
                startTime: start,
                maxDepthMeters: 21.5,
                durationMinutes: 50,
                bottomTimeSeconds: nil
            )
            let mac = DiveActivityDuplicateMatcher.Signature(
                startTime: start,
                maxDepthMeters: 21.5,
                durationMinutes: 45,
                bottomTimeSeconds: 2700
            )
            #expect(DiveActivityDuplicateMatcher.matchReason(candidate: garmin, existing: mac) == nil)
        }

        @Test func diveActivityDuplicateMatcher_differentStartTimes_noMatch() {
            let a = DiveActivityDuplicateMatcher.Signature(
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                maxDepthMeters: 18,
                durationMinutes: 45,
                bottomTimeSeconds: 2700
            )
            let b = DiveActivityDuplicateMatcher.Signature(
                startTime: Date(timeIntervalSince1970: 1_800_000_000),
                maxDepthMeters: 18,
                durationMinutes: 45,
                bottomTimeSeconds: 2700
            )
            #expect(DiveActivityDuplicateMatcher.matchReason(candidate: a, existing: b) == nil)
        }

        @Test func diveActivityDuplicateMatcher_idsWithDuplicates_marksBoth() {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let sigs = [
                DiveActivityDuplicateMatcher.Signature(
                    sourceDiveId: "fit-a",
                    startTime: start,
                    maxDepthMeters: 15,
                    durationMinutes: 30,
                    bottomTimeSeconds: 1800
                ),
                DiveActivityDuplicateMatcher.Signature(
                    sourceDiveId: "uddf-b",
                    startTime: start,
                    maxDepthMeters: 15.2,
                    durationMinutes: 30,
                    bottomTimeSeconds: 1800
                ),
            ]
            let ids = DiveActivityDuplicateMatcher.idsWithDuplicates(in: sigs)
            #expect(ids.count == 2)
        }

        @Test @MainActor
        func diveActivityDiveNumbering_assignNextChained_firstDiveIsOne() throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let newDive = DiveActivity(
                source: .manual,
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
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let imported = DiveActivity(
                source: .garminMK3,
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
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let oldest = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let newest = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
            context.insert(oldest)
            context.insert(newest)
            try context.save()

            let incoming = DiveActivity(
                source: .garminMK3,
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
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let older = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 5)
            let newestNoNumber = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
            context.insert(older)
            context.insert(newestNoNumber)
            try context.save()

            let incoming = DiveActivity(
                source: .garminMK3,
                startTime: Date(timeIntervalSince1970: 200_000),
                durationMinutes: 5,
                maxDepthMeters: 10
            )
            try DiveActivityDiveNumbering.assignNextDiveNumberChainedAfterNewest(for: incoming, modelContext: context)
            #expect(incoming.diveNumber == 6)
        }

        @Test func diveLogbookDisplay_hiddenDiveNumber_showsHyphen_whenAutoRenumberOn() {
            let hidden = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 1,
                maxDepthMeters: 1,
                diveNumber: 5
            )
            hidden.diveNumberExplicitlyNone = true
            let rows = DiveLogbookDisplay.rowData(
                activities: [hidden],
                unitSystem: .metric,
                duplicateIds: [],
                useChronologicalNumbers: true
            )
            #expect(rows.first?.diveNumberLabel == "-")
        }

        @Test func diveLogbookDisplay_hiddenDiveNumber_showsHyphen_whenAutoRenumberOff() {
            let hidden = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 1,
                maxDepthMeters: 1,
                diveNumber: 5
            )
            hidden.diveNumberExplicitlyNone = true
            let rows = DiveLogbookDisplay.rowData(
                activities: [hidden],
                unitSystem: .metric,
                duplicateIds: [],
                useChronologicalNumbers: false
            )
            #expect(rows.first?.diveNumberLabel == "-")
        }

        @Test func diveActivityDiveNumbering_nextChained_skipsExplicitNoneMidSequence() {
            let t0 = Date(timeIntervalSince1970: 10_000)
            let t1 = t0.addingTimeInterval(1_000)
            let t2 = t0.addingTimeInterval(2_000)
            let t3 = t0.addingTimeInterval(3_000)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let b = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
            let d = DiveActivity(source: .manual, startTime: t3, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
            d.diveNumberExplicitlyNone = true
            let n = DiveActivityDiveNumbering.nextChainedDiveNumberForNewImport(existingDives: [a, b, c, d])
            #expect(n == 4)
        }

        @Test func diveActivityDiveNumbering_nextChained_afterOnlyExplicitNoneRowsIsOne() {
            let t0 = Date(timeIntervalSince1970: 50_000)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
            a.diveNumberExplicitlyNone = true
            #expect(DiveActivityDiveNumbering.nextChainedDiveNumberForNewImport(existingDives: [a]) == 1)
        }

        @Test @MainActor
        func diveActivityDiveNumbering_backfill_skipsExplicitNone() throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let explicitNone = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
            explicitNone.diveNumberExplicitlyNone = true
            let legacyNil = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
            context.insert(explicitNone)
            context.insert(legacyNil)
            try context.save()

            try DiveActivityDiveNumbering.backfillMissingDiveNumbers(modelContext: context)

            #expect(explicitNone.diveNumber == nil)
            #expect(explicitNone.diveNumberExplicitlyNone == true)
            #expect(legacyNil.diveNumber == 2)
        }

        @Test func diveActivityDiveNumbering_numberedSequentialIndices_skipsExplicitNone() {
            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let t2 = Date(timeIntervalSince1970: 172_800)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let hidden = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            hidden.diveNumberExplicitlyNone = true
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            let map = DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: [c, hidden, a])
            #expect(map[a.id] == 1)
            #expect(map[hidden.id] == nil)
            #expect(map[c.id] == 2)
        }

        @Test func diveActivityDiveNumbering_numberedDiveCount_excludesExplicitNone() {
            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let hidden = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            hidden.diveNumberExplicitlyNone = true
            #expect(DiveActivityDiveNumbering.numberedDiveCount(in: [a, hidden]) == 1)
        }

        @Test @MainActor
        func diveActivityDiveNumbering_renumberAllChronologically_skipsExplicitNone() throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let t2 = Date(timeIntervalSince1970: 172_800)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let hidden = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 50)
            hidden.diveNumberExplicitlyNone = true
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            context.insert(a)
            context.insert(hidden)
            context.insert(c)
            try context.save()

            try DiveActivityDiveNumbering.renumberAllChronologically(modelContext: context)

            #expect(a.diveNumber == 1)
            #expect(hidden.diveNumber == 50)
            #expect(hidden.diveNumberExplicitlyNone == true)
            #expect(c.diveNumber == 2)
        }

        @Test @MainActor
        func diveActivityDiveNumbering_renumberAllChronologically_rewritesPersisted() throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let a = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            let b = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
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
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let a = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 9)
            let b = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 8)
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

        @Test func diveLogbookDisplay_chronologicalNumbers_whenAutoRenumberEnabled() {
            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let t2 = Date(timeIntervalSince1970: 172_800)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            let b = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)

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

        @Test func diveLogbookDisplay_filteredRows_keepFullLogbookChronologicalNumbers() {
            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let t2 = Date(timeIntervalSince1970: 172_800)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            let b = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)

            let rows = DiveLogbookDisplay.rowData(
                activities: [c],
                unitSystem: .metric,
                duplicateIds: [],
                useChronologicalNumbers: true,
                numberingActivities: [a, b, c]
            )
            #expect(rows.count == 1)
            #expect(rows.first?.diveNumberLabel == "#3")
        }

        @Test func diveLogbookDisplay_chronologicalNumbers_skipHiddenMiddleSlot() {
            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let t2 = Date(timeIntervalSince1970: 172_800)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            let hidden = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 50)
            hidden.diveNumberExplicitlyNone = true
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)

            let rows = DiveLogbookDisplay.rowData(
                activities: [a, hidden, c],
                unitSystem: .metric,
                duplicateIds: [],
                useChronologicalNumbers: true
            )
            let byId = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.diveNumberLabel) })
            #expect(byId[a.id] == "#1")
            #expect(byId[hidden.id] == "-")
            #expect(byId[c.id] == "#2")
        }

        @Test func diveLogbookDisplay_usesPersistedNumber_whenChronologicalDisabled() {
            let a = DiveActivity(
                source: .manual,
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

        @Test @MainActor func logbookDisplayCacheBuilder_matchesDiveLogbookDisplay() {
            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let t2 = Date(timeIntervalSince1970: 172_800)
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 30, maxDepthMeters: 12, diveNumber: 99)
            let hidden = DiveActivity(source: .manual, startTime: t1, durationMinutes: 20, maxDepthMeters: 8, diveNumber: 50)
            hidden.diveNumberExplicitlyNone = true
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 45, maxDepthMeters: 18, diveNumber: 99)

            let visible = [a, hidden, c]
            let signatures = visible.map { DiveActivityDuplicateMatcher.signature(for: $0) }
            let duplicateIds = DiveActivityDuplicateMatcher.idsWithDuplicates(in: signatures)
            let seeds = LogbookActivitySnapshotSeeding.seeds(from: visible)

            for useChronological in [true, false] {
                let legacy = DiveLogbookDisplay.rowData(
                    activities: visible,
                    unitSystem: .imperial,
                    duplicateIds: duplicateIds,
                    useChronologicalNumbers: useChronological,
                    numberingActivities: visible
                )
                let built = LogbookDisplayCacheBuilder.build(
                    visibleSeeds: seeds,
                    tripSeeds: [],
                    siteSearchQuery: "",
                    unitSystem: .imperial,
                    useChronologicalNumbers: useChronological
                )
                #expect(
                    logbookRowsSortedForDisplay(built.rows)
                    == logbookRowsSortedForDisplay(legacy)
                )
                #expect(built.duplicateIds == duplicateIds)
            }

            let filteredBuilt = LogbookDisplayCacheBuilder.build(
                visibleSeeds: seeds,
                tripSeeds: [],
                siteSearchQuery: "zzz-no-match",
                unitSystem: .metric,
                useChronologicalNumbers: true
            )
            #expect(filteredBuilt.rows.isEmpty)
        }

        @Test func logbookTripGrouping_groupsTwoLinkedDivesUnderTripTitle() {
            let tripID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
            let diveA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let diveB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            let newer = Date(timeIntervalSince1970: 200_000)
            let older = Date(timeIntervalSince1970: 100_000)

            var seeds = [
                logbookSnapshotSeed(id: diveA, resolvedSiteNameLowercased: "salt pier", linkedTripID: tripID, startTime: newer),
                logbookSnapshotSeed(id: diveB, resolvedSiteNameLowercased: "hilma hooker", linkedTripID: tripID, startTime: older),
            ]
            let tripSeeds = [
                LogbookTripSnapshotSeed(
                    tripID: tripID,
                    displayTitle: "Bonaire 2026",
                    startDate: older,
                    endDate: newer
                )
            ]

            let rows = seeds.map { seed in
                DiveLogbookRowDisplayData(
                    id: seed.id,
                    displayName: seed.displayName,
                    diveNumberLabel: "#1",
                    detailLine: "detail",
                    showsDuplicateHint: false,
                    previewMediaPhotoID: nil,
                    startTime: seed.startTime
                )
            }
            let items = LogbookTripGrouping.buildListItems(rows: rows, seeds: seeds, tripSeeds: tripSeeds)
            #expect(items.count == 1)
            guard case .tripGroup(let group) = items.first else {
                Issue.record("Expected trip group")
                return
            }
            #expect(group.title == "Bonaire 2026")
            #expect(
                LogbookTripGrouping.formattedGroupHeaderTitle(displayTitle: group.title, diveCount: group.dives.count)
                    == "Bonaire 2026 · 2 dives"
            )
            #expect(group.dives.map(\.id) == [diveA, diveB])

            seeds[1] = logbookSnapshotSeed(id: diveB, resolvedSiteNameLowercased: "hilma hooker", linkedTripID: nil, startTime: older)
            let ungrouped = LogbookTripGrouping.buildListItems(rows: rows, seeds: seeds, tripSeeds: tripSeeds)
            #expect(ungrouped.count == 2)
            #expect(ungrouped.allSatisfy { if case .standalone = $0 { true } else { false } })
        }

        @Test func logbookTripGrouping_assignsDistinctAccentColorsToNeighboringTripGroups() {
            let tripA = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
            let tripB = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
            let tripC = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
            let diveA1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let diveA2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            let diveB1 = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
            let diveB2 = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
            let diveC1 = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
            let diveC2 = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
            let standalone = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!

            let tA = Date(timeIntervalSince1970: 300_000)
            let tB = Date(timeIntervalSince1970: 200_000)
            let tC = Date(timeIntervalSince1970: 100_000)
            let tStandalone = Date(timeIntervalSince1970: 150_000)

            let seeds = [
                logbookSnapshotSeed(id: diveA1, resolvedSiteNameLowercased: "a1", linkedTripID: tripA, startTime: tA),
                logbookSnapshotSeed(id: diveA2, resolvedSiteNameLowercased: "a2", linkedTripID: tripA, startTime: tA.addingTimeInterval(-3600)),
                logbookSnapshotSeed(id: diveB1, resolvedSiteNameLowercased: "b1", linkedTripID: tripB, startTime: tB),
                logbookSnapshotSeed(id: diveB2, resolvedSiteNameLowercased: "b2", linkedTripID: tripB, startTime: tB.addingTimeInterval(-3600)),
                logbookSnapshotSeed(id: diveC1, resolvedSiteNameLowercased: "c1", linkedTripID: tripC, startTime: tC),
                logbookSnapshotSeed(id: diveC2, resolvedSiteNameLowercased: "c2", linkedTripID: tripC, startTime: tC.addingTimeInterval(-3600)),
                logbookSnapshotSeed(id: standalone, resolvedSiteNameLowercased: "solo", linkedTripID: nil, startTime: tStandalone),
            ]
            let tripSeeds = [
                LogbookTripSnapshotSeed(tripID: tripA, displayTitle: "Trip A", startDate: tC, endDate: tA),
                LogbookTripSnapshotSeed(tripID: tripB, displayTitle: "Trip B", startDate: tC, endDate: tB),
                LogbookTripSnapshotSeed(tripID: tripC, displayTitle: "Trip C", startDate: tC, endDate: tC),
            ]
            let rows = seeds.map { seed in
                DiveLogbookRowDisplayData(
                    id: seed.id,
                    displayName: seed.displayName,
                    diveNumberLabel: "#1",
                    detailLine: "detail",
                    showsDuplicateHint: false,
                    previewMediaPhotoID: nil,
                    startTime: seed.startTime
                )
            }

            let items = LogbookTripGrouping.buildListItems(rows: rows, seeds: seeds, tripSeeds: tripSeeds)
            let tripGroups = items.compactMap { item -> LogbookTripGroupDisplayData? in
                if case .tripGroup(let group) = item { return group }
                return nil
            }
            #expect(tripGroups.count == 3)
            #expect(tripGroups[0].accentColorIndex != tripGroups[1].accentColorIndex)
            #expect(tripGroups[1].accentColorIndex != tripGroups[2].accentColorIndex)
            #expect(LogbookTripGroupAccentPalette.nextIndex(after: 0) == 1)
            #expect(LogbookTripGroupAccentPalette.nextIndex(after: LogbookTripGroupAccentPalette.palette.count - 1) == 0)
        }

        @Test func logbookTripGroupAccentPalette_lightModeAvoidsLightPastelHues() {
            for rgb in LogbookTripGroupAccentPalette.lightModePalette {
                let maxChannel = max(rgb.red, rgb.green, rgb.blue)
                #expect(maxChannel <= 0.90)
                let isLightBlue = rgb.blue >= 0.62 && rgb.blue >= rgb.red && rgb.blue >= rgb.green
                #expect(!isLightBlue)
            }
        }

        @Test func logbookTripGroupAccentPalette_darkModeIsLighterThanLightMode() {
            func luminance(_ rgb: LogbookTripGroupAccentPalette.RGB) -> Double {
                0.2126 * rgb.red + 0.7152 * rgb.green + 0.0722 * rgb.blue
            }
            #expect(LogbookTripGroupAccentPalette.lightModePalette.count == LogbookTripGroupAccentPalette.darkModePalette.count)
            for index in LogbookTripGroupAccentPalette.lightModePalette.indices {
                let light = LogbookTripGroupAccentPalette.rgb(at: index, colorScheme: .light)
                let dark = LogbookTripGroupAccentPalette.rgb(at: index, colorScheme: .dark)
                #expect(luminance(light) < luminance(dark))
            }
        }

        @Test func logbookTripGroupAccentPresentation_matchesLogbookRailIndexForTrip() {
            let tripA = UUID()
            let tripB = UUID()
            let tA = Date(timeIntervalSince1970: 3_000)
            let tB = Date(timeIntervalSince1970: 2_000)
            let diveA1 = UUID()
            let diveA2 = UUID()
            let diveB1 = UUID()
            let diveB2 = UUID()
            let seeds = [
                logbookSnapshotSeed(id: diveA1, resolvedSiteNameLowercased: "a1", linkedTripID: tripA, startTime: tA),
                logbookSnapshotSeed(id: diveA2, resolvedSiteNameLowercased: "a2", linkedTripID: tripA, startTime: tA.addingTimeInterval(-3600)),
                logbookSnapshotSeed(id: diveB1, resolvedSiteNameLowercased: "b1", linkedTripID: tripB, startTime: tB),
                logbookSnapshotSeed(id: diveB2, resolvedSiteNameLowercased: "b2", linkedTripID: tripB, startTime: tB.addingTimeInterval(-3600)),
            ]
            let tripSeeds = [
                LogbookTripSnapshotSeed(tripID: tripA, displayTitle: "Trip A", startDate: tA, endDate: tA),
                LogbookTripSnapshotSeed(tripID: tripB, displayTitle: "Trip B", startDate: tB, endDate: tB),
            ]
            let rows = seeds.map { seed in
                DiveLogbookRowDisplayData(
                    id: seed.id,
                    displayName: seed.displayName,
                    diveNumberLabel: "#1",
                    detailLine: "detail",
                    showsDuplicateHint: false,
                    previewMediaPhotoID: nil,
                    startTime: seed.startTime
                )
            }
            let items = LogbookTripGrouping.buildListItems(rows: rows, seeds: seeds, tripSeeds: tripSeeds)
            let tripBIndex = LogbookTripGroupAccentPresentation.accentColorIndex(for: tripB, in: items)
            #expect(tripBIndex != nil)
            let tripGroupB = items.compactMap { item -> LogbookTripGroupDisplayData? in
                if case .tripGroup(let group) = item, group.tripID == tripB { return group }
                return nil
            }.first
            #expect(tripGroupB?.accentColorIndex == tripBIndex)
        }

        @Test func diveActivityDiveNumbering_chronologicallyAfterDeletedSlot_excludesDeletedRow() {
            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let t2 = Date(timeIntervalSince1970: 172_800)
            let deleted = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
            let older = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let newer = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)

            #expect(
                !DiveActivityDiveNumbering.chronologicallyAfterDeletedSlot(
                    deleted,
                    deletedStartTime: t1,
                    deletedId: deleted.id
                )
            )
            #expect(
                !DiveActivityDiveNumbering.chronologicallyAfterDeletedSlot(
                    older,
                    deletedStartTime: t1,
                    deletedId: deleted.id
                )
            )
            #expect(
                DiveActivityDiveNumbering.chronologicallyAfterDeletedSlot(
                    newer,
                    deletedStartTime: t1,
                    deletedId: deleted.id
                )
            )
        }

        @Test func diveBackgroundDeletionWorker_cascadeDelete_removesLargeProfileAndDive() async throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])

            let diveID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 45,
                    maxDepthMeters: 30
                )
                context.insert(activity)
                for i in 0 ..< 200 {
                    let point = DiveProfilePoint(
                        timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                        depthMeters: Double(i % 20),
                        dive: activity
                    )
                    activity.profilePoints.append(point)
                }
                DiveProfilePointStore.insertStagedPoints(for: activity, into: context)
                try context.save()
                return activity.id
            }

            try await DiveBackgroundDeletionWorker(modelContainer: container)
                .deleteDive(id: diveID)

            let counts = try await MainActor.run { () throws -> (Int, Int) in
                let context = ModelContext(container)
                let dives = try context.fetch(FetchDescriptor<DiveActivity>())
                let points = try context.fetch(FetchDescriptor<DiveProfilePoint>())
                return (dives.count, points.count)
            }
            #expect(counts.0 == 0)
            #expect(counts.1 == 0)
        }

        @Test func diveBackgroundDeletionWorker_deleteDive_withLinkedSite_removesDiveProfilePointsAndCatalogSite() async throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])

            let diveID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let site = DiveSite(siteName: "Batch Delete Site", latCoords: 12, longCoords: -68)
                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 25
                )
                context.insert(site)
                context.insert(activity)
                DiveActivitySiteAssociation.link(activity, to: site)
                for i in 0 ..< 80 {
                    activity.profilePoints.append(
                        DiveProfilePoint(
                            timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                            depthMeters: Double(i),
                            dive: activity
                        )
                    )
                }
                DiveProfilePointStore.insertStagedPoints(for: activity, into: context)
                try context.save()
                return activity.id
            }

            try await DiveBackgroundDeletionWorker(modelContainer: container)
                .deleteDive(id: diveID)

            let counts = try await MainActor.run { () throws -> (Int, Int, Int) in
                let context = ModelContext(container)
                let dives = try context.fetch(FetchDescriptor<DiveActivity>())
                let points = try context.fetch(FetchDescriptor<DiveProfilePoint>())
                let sites = try context.fetch(FetchDescriptor<DiveSite>())
                return (dives.count, points.count, sites.count)
            }
            #expect(counts.0 == 0)
            #expect(counts.1 == 0)
            #expect(counts.2 == 0)
        }

        @Test func diveBackgroundDeletionWorker_deleteDive_removesActivityBuddiesAndMedia() async throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveMediaPhoto.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])

            let activityID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let activity = DiveActivity(
                    source: .manual,
                    startTime: .now,
                    durationMinutes: 12,
                    maxDepthMeters: 18
                )
                let person = DiveBuddy(displayName: "Pat")
                let tag = DiveBuddyTag(buddy: person, dive: activity)
                tag.link(to: activity)
                activity.buddies.append(tag)
                let photo = DiveMediaPhoto(sortOrder: 0, mediaKind: .image, dive: activity)
                activity.mediaPhotos.append(photo)
                context.insert(person)
                context.insert(activity)
                context.insert(tag)
                try context.save()
                return activity.id
            }

            try await DiveBackgroundDeletionWorker(modelContainer: container)
                .deleteDive(id: activityID)

            let counts = try await MainActor.run { () throws -> (Int, Int, Int, Int) in
                let context = ModelContext(container)
                let dives = try context.fetch(FetchDescriptor<DiveActivity>())
                let tags = try context.fetch(FetchDescriptor<DiveBuddyTag>())
                let people = try context.fetch(FetchDescriptor<DiveBuddy>())
                let media = try context.fetch(FetchDescriptor<DiveMediaPhoto>())
                return (dives.count, tags.count, people.count, media.count)
            }
            #expect(counts.0 == 0)
            #expect(counts.1 == 0)
            #expect(counts.2 == 1)
            #expect(counts.3 == 0)
        }

        @Test func diveBackgroundDeletionWorker_deleteDive_withAutoAddedEquipment_removesDiveAndGearRows() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)

            let diveID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "delete-equipment", displayName: "Diver")
                let gear = EquipmentItem(
                    manufacturer: "Apeks",
                    model: "XTX",
                    type: "Regulator",
                    autoAdd: true
                )
                EquipmentItemOwnership.assignOwner(owner, to: gear)
                let activity = DiveActivity(
                    source: .manual,
                    startTime: .now,
                    durationMinutes: 40,
                    maxDepthMeters: 20
                )
                activity.owner = owner
                activity.ownerProfileID = owner.id
                context.insert(owner)
                context.insert(gear)
                context.insert(activity)
                try DiveActivityEquipmentAssociation.applyAutoAdd(
                    to: activity,
                    ownerProfileID: owner.id,
                    modelContext: context
                )
                try context.save()
                return activity.id
            }

            try await DiveBackgroundDeletionWorker(modelContainer: container)
                .deleteDive(id: diveID)

            try await MainActor.run { () throws in
                let context = ModelContext(container)
                #expect(try context.fetch(FetchDescriptor<DiveActivity>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<DiveActivityEquipmentList>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<DiveEquipmentEntry>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<EquipmentItem>()).count == 1)
            }
        }

        @Test func diveBackgroundDeletionWorker_deleteDive_withTripActivityLink_removesDiveAndJoinRow() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)

            let diveID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "delete-trip-link", displayName: "Diver")
                let trip = DiveTrip(
                    startDate: Date(timeIntervalSince1970: 0),
                    endDate: Date(timeIntervalSince1970: 604_800),
                    title: "Bonaire Week",
                    ownerProfileID: owner.id
                )
                trip.owner = owner
                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 86_400),
                    durationMinutes: 45,
                    maxDepthMeters: 20
                )
                activity.owner = owner
                activity.ownerProfileID = owner.id
                context.insert(owner)
                context.insert(trip)
                context.insert(activity)
                _ = DiveTripActivityLinking.link(activity, to: trip, modelContext: context)
                try context.save()
                return activity.id
            }

            try await DiveBackgroundDeletionWorker(modelContainer: container)
                .deleteDive(id: diveID)

            try await MainActor.run { () throws in
                let context = ModelContext(container)
                #expect(try context.fetch(FetchDescriptor<DiveActivity>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<DiveTripActivityLink>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<DiveTrip>()).count == 1)
            }
            #expect(DiveActivityStoreSync.isDiveAbsent(diveID: diveID, container: container))
        }

        @Test func diveBackgroundDeletionWorker_deleteDive_withSightingsTagsAndMarineLifeRecord_removesAllReferences() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)

            let diveID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "delete-sightings", displayName: "Diver")
                let site = DiveSite(siteName: "Reef", latCoords: 12, longCoords: -68)
                let species = MarineLife(
                    uuid: "fish-001",
                    commonName: "Parrotfish",
                    scientificName: "Scarus",
                    category: "Fish"
                )
                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 25,
                    diveSiteID: site.id
                )
                activity.owner = owner
                activity.ownerProfileID = owner.id

                let tag = ActivityTag(name: "Night", normalizedName: "night", ownerProfileID: owner.id)
                activity.activityTags.append(tag)
                tag.dives.append(activity)

                let photo = DiveMediaPhoto(sortOrder: 0, mediaKind: .image, dive: activity)
                activity.mediaPhotos.append(photo)

                let sighting = SightingInstance(
                    marineLifeUUID: species.uuid,
                    sightingDateTime: activity.startTime,
                    diveActivity: activity,
                    diveSiteID: site.id,
                    mediaPhoto: photo
                )
                activity.marineLifeSightings.append(sighting)
                let record = MarineLifeUserRecord(
                    owner: owner,
                    marineLifeUUID: species.uuid,
                    isSighted: true,
                    activitiesSightedOn: [activity.id],
                    sitesSightedOn: [site.id],
                    userTaggedMedia: [DiveActivityDeletionMarineLifeCleanup.userTaggedMediaLink(for: photo.id)]
                )
                record.link(marineLifeUUID: species.uuid, owner: owner)

                context.insert(owner)
                context.insert(site)
                context.insert(species)
                context.insert(tag)
                context.insert(activity)
                context.insert(sighting)
                context.insert(record)
                try context.save()
                return activity.id
            }

            try await DiveBackgroundDeletionWorker(modelContainer: container)
                .deleteDive(id: diveID)

            try await MainActor.run {
                let context = ModelContext(container)
                #expect(try context.fetch(FetchDescriptor<DiveActivity>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<SightingInstance>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<DiveMediaPhoto>()).isEmpty)

                let tag = try #require(try context.fetch(FetchDescriptor<ActivityTag>()).first)
                #expect(tag.dives.isEmpty)

                let record = try #require(try context.fetch(FetchDescriptor<MarineLifeUserRecord>()).first)
                #expect(record.activitiesSightedOn.isEmpty)
                #expect(record.sitesSightedOn.isEmpty)
                #expect(record.userTaggedMedia.isEmpty)
            }
        }

        @Test @MainActor
        func diveActivityDiveNumbering_backfillFillsNilRows() throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let t0 = Date(timeIntervalSince1970: 0)
            let t1 = Date(timeIntervalSince1970: 86_400)
            let a = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1)
            let b = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1)
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

            let oldest = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1)
            let mid = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1)
            let newest = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1)

            let shuffled = [newest, oldest, mid]
            let map = DiveActivityDiveNumbering.sequentialIndicesById(for: shuffled)

            #expect(map[oldest.id] == 1)
            #expect(map[mid.id] == 2)
            #expect(map[newest.id] == 3)
        }

        @Test func diveActivityDiveNumbering_sequentialIndices_emptyReturnsEmpty() {
            #expect(DiveActivityDiveNumbering.sequentialIndicesById(for: []).isEmpty)
        }

            @Test @MainActor
            func diveActivityOwnership_assignOwnerAndClaimUnowned() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let owner = UserProfile(appleUserIdentifier: "apple-1", displayName: "Owner")
                context.insert(owner)

                let unowned = DiveActivity(
                    source: .manual,
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
            func diveActivityEquipmentAssociation_link_syncsListAndDivesUsedOn() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let owner = UserProfile(appleUserIdentifier: "apple-gear-link", displayName: "Diver")
                context.insert(owner)

                let gear = EquipmentItem(manufacturer: "Apeks", model: "XTX", type: "Regulator")
                EquipmentItemOwnership.assignOwner(owner, to: gear)
                context.insert(gear)

                let dive = DiveActivity(
                    source: .garminMK3,
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
                    source: .garminMK3,
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
                    source: .garminMK3,
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
                    source: .garminMK3,
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
                    source: .garminMK3,
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
                    source: .garminMK3,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.084, longitude: -68.284)
                )
                context.insert(activity)
                DiveActivitySiteAssociation.link(activity, to: catalog)
                try context.save()

                let mapCoord = activity.resolvedMapCoordinate(catalogSites: [catalog])
                #expect(mapCoord?.latitude == 12.0835)
                #expect(mapCoord?.longitude == -68.283)
                #expect(activity.siteCoordinate?.latitude == 12.0835)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_uniqueExactName_beatsNearbyCoordinate() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let nearbyWrong = DiveSite(
                    siteName: "Nearby GPS Only",
                    latCoords: 12.0835,
                    longCoords: -68.283
                )
                let saltPier = DiveSite(
                    siteName: "Salt Pier",
                    latCoords: 1,
                    longCoords: 1
                )
                context.insert(nearbyWrong)
                context.insert(saltPier)

                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )

                DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: [nearbyWrong, saltPier])
                #expect(activity.diveSiteID == saltPier.id)
                #expect(
                    activity.resolvedMapCoordinate(catalogSites: [nearbyWrong, saltPier])?.latitude == 1
                )
            }
            @Test @MainActor
            func diveActivitySiteAssociation_ambiguousExactName_usesCoordinate() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let saltPierA = DiveSite(siteName: "Salt Pier", latCoords: 12.0835, longCoords: -68.283)
                let saltPierB = DiveSite(siteName: "Salt Pier", latCoords: 5, longCoords: 5)
                context.insert(saltPierA)
                context.insert(saltPierB)

                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )

                DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: [saltPierA, saltPierB])
                #expect(activity.diveSiteID == saltPierA.id)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_namedSite_doesNotLinkToNearbyDifferentName() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let byCoord = DiveSite(
                    siteName: "GPS Site",
                    latCoords: 12.0835,
                    longCoords: -68.283
                )
                let fuzzyCatalog = DiveSite(
                    siteName: "Salt Pier — Bonaire (catalog)",
                    latCoords: 1,
                    longCoords: 1
                )
                context.insert(byCoord)
                context.insert(fuzzyCatalog)

                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )

                DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: [byCoord, fuzzyCatalog])
                #expect(activity.diveSiteID == nil)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_createSiteForImportNameIfNeeded_insertsNamedSite() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let neighbor = DiveSite(
                    siteName: "Other Reef",
                    latCoords: 12.0835,
                    longCoords: -68.283
                )
                context.insert(neighbor)
                var catalog = try DiveActivitySiteAssociation.fetchCatalogSites(modelContext: context)

                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )
                context.insert(activity)

                DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: catalog)
                let created = DiveActivitySiteAssociation.createSiteForImportNameIfNeeded(
                    to: activity,
                    catalogSites: &catalog,
                    modelContext: context
                )

                #expect(created)
                #expect(activity.resolvedLinkedSite?.siteName == "Salt Pier")
                #expect(activity.resolvedLinkedSite?.latCoords == 12.08316)
                #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 1)
                #expect(try context.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_createSiteForImportNameIfNeeded_reusesExistingUserSiteByName() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "test.owner.reuse-site", displayName: "Dre")
                context.insert(owner)

                let first = DiveActivity(
                    source: .macDive,
                    startTime: Date(timeIntervalSince1970: 1_000),
                    durationMinutes: 40,
                    maxDepthMeters: 18,
                    siteName: "Judy's Dream Belair",
                    entryCoordinate: DiveCoordinate(latitude: 12.1, longitude: -68.2)
                )
                first.owner = owner
                first.ownerProfileID = owner.id
                context.insert(first)

                var catalog: [DiveSite] = []
                #expect(
                    DiveActivitySiteAssociation.createSiteForImportNameIfNeeded(
                        to: first,
                        catalogSites: &catalog,
                        modelContext: context
                    )
                )

                let second = DiveActivity(
                    source: .macDive,
                    startTime: Date(timeIntervalSince1970: 2_000),
                    durationMinutes: 45,
                    maxDepthMeters: 20,
                    siteName: "judy's dream belair",
                    entryCoordinate: DiveCoordinate(latitude: 12.1001, longitude: -68.2001)
                )
                second.owner = owner
                second.ownerProfileID = owner.id
                context.insert(second)

                #expect(
                    !DiveActivitySiteAssociation.createSiteForImportNameIfNeeded(
                        to: second,
                        catalogSites: &catalog,
                        modelContext: context
                    )
                )
                #expect(try context.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
                #expect(first.diveSiteID == second.diveSiteID)
                #expect(first.diveSiteID != nil)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_openDiveMapLink_createsSyncedUserDiveSiteSnapshot() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "odm-snapshot-owner", displayName: "Owner")
                context.insert(owner)

                let reference = DiveSiteReferenceSnapshot(
                    id: "salt01",
                    name: "Salt Pier",
                    country: "Caribbean Netherlands",
                    countryCode: "BQ",
                    latitude: 12.0835,
                    longitude: -68.283,
                    maxDepthMeters: 30,
                    entry: "shore",
                    environment: "ocean",
                    topologies: ["reef"],
                    seaName: "Caribbean Sea"
                )
                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )
                activity.owner = owner
                activity.ownerProfileID = owner.id
                context.insert(activity)

                var catalog: [DiveSite] = []
                let outcome = DiveActivitySiteAssociation.applyOpenDiveMapSiteLinkIfNeeded(
                    to: activity,
                    catalogSites: &catalog,
                    modelContext: context,
                    reference: [reference],
                    createSiteWhenMissing: true
                )
                try context.save()

                #expect(outcome == .createdAndLinked)
                guard let siteID = activity.diveSiteID else {
                    Issue.record("Expected diveSiteID after OpenDiveMap link")
                    return
                }
                let userSite = try DiveLinkedSiteResolver.existingUserDiveSite(id: siteID, modelContext: context)
                #expect(userSite != nil)
                #expect(userSite?.openDiveMapReferenceID == "salt01")
                #expect(userSite?.siteName == "Salt Pier")
                #expect(userSite?.ownerProfileID == owner.id)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_hydrateSyncedUserDiveSites_healsOrphanOpenDiveMapLink() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "odm-hydrate-owner", displayName: "Owner")
                context.insert(owner)

                let orphanSiteID = UUID()
                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )
                activity.owner = owner
                activity.ownerProfileID = owner.id
                activity.diveSiteID = orphanSiteID
                context.insert(activity)
                try context.save()

                let reference = DiveSiteReferenceSnapshot(
                    id: "salt01",
                    name: "Salt Pier",
                    country: "Caribbean Netherlands",
                    countryCode: "BQ",
                    latitude: 12.0835,
                    longitude: -68.283,
                    maxDepthMeters: 30,
                    entry: "shore",
                    environment: "ocean",
                    topologies: [],
                    seaName: "Caribbean Sea"
                )
                let hydrated = try DiveActivitySiteAssociation.hydrateSyncedUserDiveSitesForLinkedDives(
                    modelContext: context,
                    catalogSites: [],
                    reference: [reference]
                )
                try context.save()

                #expect(hydrated == 1)
                #expect(activity.diveSiteID == orphanSiteID)
                let userSite = try DiveLinkedSiteResolver.existingUserDiveSite(id: orphanSiteID, modelContext: context)
                #expect(userSite?.openDiveMapReferenceID == "salt01")
                #expect(userSite?.siteName == "Salt Pier")

                let logbookIDs = ExploreSiteScopePresentation.logbookSiteIDs(
                    ownerActivities: [activity],
                    ownerProfileID: owner.id
                )
                let snapshot = ExploreSiteScopeCache.make(
                    ownerProfileID: owner.id,
                    catalog: [],
                    userSites: userSite.map { [$0] } ?? [],
                    ownerActivities: [activity]
                )
                let fromIDs = ExploreSiteScopeCache.make(
                    catalog: [],
                    userSites: userSite.map { [$0] } ?? [],
                    logbookSiteIDs: logbookIDs
                )
                #expect(logbookIDs.contains(orphanSiteID))
                #expect(snapshot.hasLogbookSites)
                #expect(snapshot.logbookPlottableSites.contains(where: { $0.id == orphanSiteID }))
                #expect(fromIDs.logbookSiteIDs == snapshot.logbookSiteIDs)
                #expect(fromIDs.hasLogbookSites == snapshot.hasLogbookSites)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_createSiteFromOpenDiveMapReferenceIfNeeded_enrichesImport() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let reference = DiveSiteReferenceSnapshot(
                    id: "salt01",
                    name: "Salt Pier",
                    country: "Caribbean Netherlands",
                    countryCode: "BQ",
                    latitude: 12.0835,
                    longitude: -68.283,
                    maxDepthMeters: 30,
                    entry: "shore",
                    environment: "ocean",
                    topologies: ["reef"],
                    seaName: "Caribbean Sea"
                )

                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )
                context.insert(activity)
                var catalog: [DiveSite] = []

                let created = DiveActivitySiteAssociation.createSiteFromOpenDiveMapReferenceIfNeeded(
                    to: activity,
                    catalogSites: &catalog,
                    modelContext: context,
                    reference: [reference]
                )

                #expect(created)
                #expect(activity.resolvedLinkedSite?.siteName == "Salt Pier")
                #expect(activity.resolvedLinkedSite?.country == "Caribbean Netherlands")
                #expect(activity.resolvedLinkedSite?.latCoords == 12.0835)
                #expect(activity.resolvedLinkedSite?.siteTags.contains(DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")) == true)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_backfillOpenDiveMapSiteLinks_linksUnlinkedDives() throws {
                DiveActivityOpenDiveMapSiteBackfill.resetCompletionFlagForTesting()
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let localOnlySite = DiveSite(
                    siteName: "Salt Pier",
                    latCoords: 12.0835,
                    longCoords: -68.283
                )
                context.insert(localOnlySite)

                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )
                context.insert(activity)
                try context.save()

                let result = try DiveActivitySiteAssociation.backfillOpenDiveMapSiteLinks(modelContext: context)

                #expect(result.linkedActivityCount == 1)
                #expect(result.createdSiteCount == 0)
                #expect(activity.diveSiteID == localOnlySite.id)
                #expect(localOnlySite.siteTags.contains(where: { $0.hasPrefix(DiveSiteCatalogMatcher.openDiveMapTagPrefix) }))
                #expect(result.enrichedSiteCount == 1)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_createSiteAndLink_persists() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let activity = DiveActivity(
                    source: .garminMK3,
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
                    country: "Caribbean Netherlands",
                    region: " Bonaire ",
                    bodyOfWater: "Caribbean Sea",
                    latCoords: 12.05,
                    longCoords: -68.27,
                    modelContext: context
                )

                #expect(activity.diveSiteID == site.id)
                #expect(activity.siteCoordinate?.latitude == 12.05)
                #expect(site.country == "Caribbean Netherlands")
                #expect(site.region == "Bonaire")
                #expect(site.bodyOfWater == "Caribbean Sea")
                #expect(try context.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
            }
            @Test func diveNotesValidation_draftKeepsSpacesAndNewlinesWhileTyping() {
                #expect(DiveNotesValidation.draftNotes("Saw a ") == "Saw a ")
                #expect(DiveNotesValidation.draftNotes("Line one\n") == "Line one\n")
                #expect(DiveNotesValidation.draftNotes("Reef\u{0000} wall") == "Reef wall")

                let long = String(repeating: "n", count: DiveNotesValidation.maxCharacterCount + 40)
                #expect(DiveNotesValidation.draftNotes(long).count == DiveNotesValidation.maxCharacterCount)
            }
            @Test func diveNotesValidation_persistTrimsEndsButKeepsInternalWhitespace() {
                #expect(GoDiveInputSanitization.sanitizedNotes("  Saw a turtle  ") == "Saw a turtle")
                #expect(GoDiveInputSanitization.sanitizedNotes("Line one\nLine two") == "Line one\nLine two")
                #expect(DiveNotesValidation.cappedNotes("  hello  ") == "hello")
            }
            @Test func diveActivityHorizontalChipRowScrollFade_hidesWhenContentFits() {
                #expect(
                    DiveActivityHorizontalChipRowScrollFadePresentation.trailingFadeOpacity(
                        contentWidth: 200,
                        containerWidth: 320,
                        contentOffsetX: 0
                    ) == 0
                )
            }
            @Test func diveActivityHorizontalChipRowScrollFade_showsWhenOverflowingAndFadesNearEnd() {
                let fadeWidth = DiveActivityHorizontalChipRowScrollFadePresentation.fadeWidth
                #expect(
                    DiveActivityHorizontalChipRowScrollFadePresentation.trailingFadeOpacity(
                        contentWidth: 500,
                        containerWidth: 300,
                        contentOffsetX: 0
                    ) == 1
                )
                #expect(
                    DiveActivityHorizontalChipRowScrollFadePresentation.trailingFadeOpacity(
                        contentWidth: 500,
                        containerWidth: 300,
                        contentOffsetX: 200
                    ) == 0
                )
                let mid = DiveActivityHorizontalChipRowScrollFadePresentation.trailingFadeOpacity(
                    contentWidth: 500,
                    containerWidth: 300,
                    contentOffsetX: 200 - (fadeWidth / 2)
                )
                #expect(abs(mid - 0.5) < 0.001)
            }
            @Test func diveActivity_tankHeroConsumptionLines_requireCylinderPressures() {
                let withoutPressures = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 45,
                    maxDepthMeters: 18,
                    averageDepthMeters: 12,
                    avgSAC: 22,
                    avgRMV: 18
                )
                #expect(withoutPressures.tankHeroSACRateLine(displayUnits: .imperial) == nil)
                #expect(withoutPressures.tankHeroRMVRateLine(displayUnits: .imperial) == nil)
                let sacDisplay = DiveActivityFieldEditing.displayValue(
                    for: .avgSAC,
                    activity: withoutPressures,
                    displayUnits: .imperial,
                    profileGasStats: .init(sampleCount: 0, minPSI: 0, maxPSI: 0)
                )
                #expect(sacDisplay == "—")

                withoutPressures.tankPressureStartPSI = 3000
                withoutPressures.tankPressureEndPSI = 2000
                let sacLine = withoutPressures.tankHeroSACRateLine(displayUnits: .imperial)
                #expect(sacLine != nil)
                let rmvLine = withoutPressures.tankHeroRMVRateLine(displayUnits: .imperial)
                #expect(rmvLine != nil)
            }
            @Test @MainActor func diveActivityBuddiesOverviewPresentation_shouldOpenBuddyDetail() {
                let owner = UserProfile(appleUserIdentifier: "owner", displayName: "Pat Lee")
                let selfBuddy = DiveBuddy(displayName: "Pat", owner: owner)
                let partner = DiveBuddy(displayName: "Alex Kim", owner: owner)

                #expect(
                    !DiveActivityBuddiesOverviewPresentation.shouldOpenBuddyDetail(
                        buddy: nil,
                        owner: owner
                    )
                )
                #expect(
                    !DiveActivityBuddiesOverviewPresentation.shouldOpenBuddyDetail(
                        buddy: selfBuddy,
                        owner: owner
                    )
                )
                #expect(
                    DiveActivityBuddiesOverviewPresentation.shouldOpenBuddyDetail(
                        buddy: partner,
                        owner: owner
                    )
                )
            }
            @Test func diveActivitySectionEditContext_resolvesSectionFromTabAndDetent() {
                let context = DiveActivitySectionEditContext(
                    sectionID: "diveConditions",
                    tab: .map,
                    panelDetent: .large
                )
                #expect(context.id == "map-diveConditions")
                let section = context.resolvedSection()
                #expect(section?.title == "Dive Conditions")
                #expect(section?.fieldIDs.contains(.diveVisibility) == true)
            }
            @Test func diveActivityDTO_decodesSourceAndLegacyDeviceSourceKey() throws {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let json = """
                {"deviceSource":"Manual","startTime":"2025-01-01T12:00:00Z","durationMinutes":1,"maxDepthMeters":1,"profilePoints":[]}
                """
                let dto = try decoder.decode(DiveActivityDTO.self, from: Data(json.utf8))
                #expect(dto.source == .manual)

                let jsonNew = """
                {"source":"Garmin MK3","startTime":"2025-01-01T12:00:00Z","durationMinutes":1,"maxDepthMeters":1,"profilePoints":[]}
                """
                let dtoNew = try decoder.decode(DiveActivityDTO.self, from: Data(jsonNew.utf8))
                #expect(dtoNew.source == .garminMK3)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_matchesExactNameWhenNoEntryGPS() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let catalog = DiveSite(
                    siteName: "Salt Pier",
                    latCoords: 12.0835,
                    longCoords: -68.283
                )
                context.insert(catalog)

                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier"
                )
                context.insert(activity)

                DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: [catalog])
                try context.save()
                #expect(activity.diveSiteID == catalog.id)
                #expect(activity.entryCoordinate == nil)
                #expect(activity.siteCoordinate?.latitude == 12.0835)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_doesNotFuzzyMatchPartialCatalogName() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let catalog = DiveSite(
                    siteName: "Salt Pier — Bonaire (catalog)",
                    latCoords: 12.0835,
                    longCoords: -68.283
                )
                context.insert(catalog)

                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 10,
                    siteName: "Salt Pier"
                )

                DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: [catalog])
                #expect(activity.diveSiteID == nil)
                #expect(activity.entryCoordinate == nil)
                #expect(activity.siteCoordinate == nil)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_createCatalogSite_persistsWithoutDiveLink() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let site = try DiveActivitySiteAssociation.createCatalogSite(
                    siteName: "Manual Reef",
                    country: "Belize",
                    region: "Lighthouse",
                    bodyOfWater: "Caribbean Sea",
                    latCoords: 17.2,
                    longCoords: -87.5,
                    modelContext: context
                )

                #expect(site.siteName == "Manual Reef")
                #expect(site.country == "Belize")
                #expect(site.region == "Lighthouse")
                #expect(site.bodyOfWater == "Caribbean Sea")
                #expect(try context.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
                #expect(try context.fetchCount(FetchDescriptor<DiveActivity>()) == 0)
            }
            @Test @MainActor
            func diveActivitySiteAssociation_applyCatalogSiteEdits_updatesFieldsAndClearsCoords() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let site = try DiveActivitySiteAssociation.createCatalogSite(
                    siteName: "Old Reef",
                    country: "Belize",
                    region: "Lighthouse",
                    bodyOfWater: "Caribbean Sea",
                    latCoords: 17.2,
                    longCoords: -87.5,
                    waterType: .saltwater,
                    modelContext: context
                )
                site.timeZoneIdentifier = "America/Belize"
                site.timeZoneOffsetSeconds = -21_600

                var draft = DiveSiteFormDraft(from: site)
                #expect(draft.siteName == "Old Reef")
                #expect(draft.latitudeText.contains("17.2"))
                #expect(draft.waterType == .saltwater)

                draft.siteName = "  New Reef  "
                draft.country = " Mexico "
                draft.region = "Baja"
                draft.bodyOfWater = "Sea of Cortez"
                draft.waterType = .freshwater
                draft.entry = "boat"
                draft.environment = "ocean"
                draft.maxDepthMetersText = "40"
                draft.latitudeText = ""
                draft.longitudeText = ""

                try DiveActivitySiteAssociation.applyUserSiteEdits(
                    to: site,
                    draft: draft,
                    modelContext: context
                )

                #expect(site.siteName == "New Reef")
                #expect(site.country == "Mexico")
                #expect(site.region == "Baja")
                #expect(site.bodyOfWater == "Sea of Cortez")
                #expect(site.waterType == .freshwater)
                #expect(site.entry == "boat")
                #expect(site.environment == "ocean")
                #expect(site.maxDepthMeters == 40)
                #expect(site.latCoords == nil)
                #expect(site.longCoords == nil)
                #expect(site.timeZoneIdentifier == nil)
                #expect(site.timeZoneOffsetSeconds == nil)
            }
            @Test @MainActor
            func diveUnownedClaimGate_modelContext_usesCountOnlyDecision() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "claim-gate-count", displayName: "Owner")
                context.insert(owner)

                let owned = DiveActivity(source: .manual, startTime: .now, durationMinutes: 20, maxDepthMeters: 10)
                owned.ownerProfileID = owner.id
                context.insert(owned)
                try context.save()

                #expect(
                    try DiveUnownedClaimGate.decision(ownerID: owner.id, modelContext: context) == .nothingToClaim
                )

                let orphan = DiveActivity(
                    source: .manual,
                    startTime: .now.addingTimeInterval(-60),
                    durationMinutes: 25,
                    maxDepthMeters: 12
                )
                orphan.ownerProfileID = nil
                context.insert(orphan)
                try context.save()

                #expect(
                    try DiveUnownedClaimGate.decision(ownerID: owner.id, modelContext: context) == .claim
                )
            }
            @Test func diveUnownedClaimGate_skipsWhenOtherOwnerPresent() {
                let ownerA = UUID()
                let ownerB = UUID()
                #expect(
                    DiveUnownedClaimGate.decision(
                        ownerID: ownerB,
                        diveOwnerIDs: [ownerA, nil],
                        snorkelOwnerIDs: [],
                        buddyOwnerIDs: []
                    ) == .skipOtherOwnersPresent
                )
                #expect(
                    DiveUnownedClaimGate.decision(
                        ownerID: ownerA,
                        diveOwnerIDs: [nil, nil],
                        snorkelOwnerIDs: [nil],
                        buddyOwnerIDs: [nil]
                    ) == .claim
                )
                #expect(
                    DiveUnownedClaimGate.decision(
                        ownerID: ownerA,
                        diveOwnerIDs: [ownerA],
                        snorkelOwnerIDs: [],
                        buddyOwnerIDs: []
                    ) == .nothingToClaim
                )
                #expect(
                    DiveUnownedClaimGate.decision(
                        ownerID: ownerA,
                        diveOwnerIDs: [],
                        snorkelOwnerIDs: [nil],
                        buddyOwnerIDs: []
                    ) == .claim
                )
                #expect(
                    DiveUnownedClaimGate.decision(
                        ownerID: ownerB,
                        diveOwnerIDs: [],
                        snorkelOwnerIDs: [ownerA, nil],
                        buddyOwnerIDs: []
                    ) == .skipOtherOwnersPresent
                )
            }
            @Test @MainActor
            func diveActivityOwnership_claimUnowned_skipsWhenOtherProfileOwnsRows() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let ownerA = UserProfile(appleUserIdentifier: "apple-a", displayName: "A")
                let ownerB = UserProfile(appleUserIdentifier: "apple-b", displayName: "B")
                context.insert(ownerA)
                context.insert(ownerB)

                let ownedByA = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 1,
                    maxDepthMeters: 1
                )
                DiveActivityOwnership.assignOwner(ownerA, to: ownedByA)
                context.insert(ownedByA)

                let orphan = DiveActivity(
                    source: .manual,
                    startTime: Date().addingTimeInterval(60),
                    durationMinutes: 1,
                    maxDepthMeters: 1
                )
                context.insert(orphan)
                try context.save()

                let claimed = try DiveActivityOwnership.claimUnownedDives(for: ownerB, modelContext: context)
                #expect(claimed == 0)
                #expect(orphan.ownerProfileID == nil)
            }
            @Test func diveDerivedDataBuilder_buildsDepthAndPressureFromSnapshots() {
                let input = DiveDerivedDataBuildInput(
                    profilePointSnapshots: [
                        DiveDerivedProfilePointSnapshot(
                            timestamp: Date(timeIntervalSince1970: 0),
                            depthMeters: 0,
                            tankPressurePSI: 3_000
                        ),
                        DiveDerivedProfilePointSnapshot(
                            timestamp: Date(timeIntervalSince1970: 60),
                            depthMeters: 12,
                            tankPressurePSI: 2_000
                        ),
                    ],
                    sortedMediaSnapshots: [],
                    activityStartTime: Date(timeIntervalSince1970: 0),
                    durationMinutes: 60
                )
                let result = DiveDerivedDataBuilder.build(from: input)
                #expect(result.depthSamples.count == 2)
                #expect(result.depthSamples[1].elapsedSeconds == 60)
                #expect(result.pressureSamples.count == 2)
                #expect(result.profileGasStats.sampleCount == 2)
            }
            @Test func diveActivityTabBarPresentation_usesCompactGlassSegments() {
                #expect(DiveActivityTabBarPresentation.segmentSize == 44)
                #expect(DiveActivityTabBarPresentation.chromeWidth == 148)
                #expect(DiveActivityTab.allCases.count == 3)
            }
            @Test func diveActivityTabIcon_matchesGlyphHeight() {
                #expect(DiveActivityTabIcon.tabGlyphPointSize == 22)
                #expect(DiveActivityTabIcon.scubaTankTabGlyphHeight == 16)
                let tankSize = DiveActivityTabIcon.templateAssetSize(for: "ScubaTankTab")
                #expect(tankSize.height == 16)
                #expect(tankSize.width == 16 * DiveActivityTabIcon.scubaTankTabAspectWidthOverHeight)
                #expect(abs(tankSize.width / tankSize.height - DiveActivityTabIcon.scubaTankTabAspectWidthOverHeight) < 0.001)
                let scaledFromPixels = DiveActivityTabIcon.scaledAssetSize(
                    assetPixelSize: DiveActivityTabIcon.scubaTankTabAssetPixelSize,
                    targetHeight: 16
                )
                #expect(scaledFromPixels == tankSize)
            }
            @Test func diveActivityTab_iconSources() {
                #expect(DiveActivityTab.map.systemImageName == "map")
                #expect(DiveActivityTab.map.assetImageName == nil)
                #expect(DiveActivityTab.tank.systemImageName == nil)
                #expect(DiveActivityTab.tank.assetImageName == "ScubaTankTab")
                #expect(DiveActivityTab.camera.systemImageName == "camera")
                #expect(DiveActivityTab.allCases.count == 3)
            }
            @Test func diveActivitySiteAssociation_previewBestMatch_matchesExactNameWithoutLinking() throws {
                let catalog = DiveSite(siteName: "Angel City", latCoords: 12.10325, longCoords: -68.28845)
                let activity = DiveActivity(
                    source: .macDive,
                    startTime: Date(),
                    durationMinutes: 60,
                    maxDepthMeters: 10,
                    siteName: "Angel City"
                )
                let matched = DiveActivitySiteAssociation.previewBestMatch(for: activity, catalogSites: [catalog])
                #expect(matched?.id == catalog.id)
                #expect(activity.diveSiteID == nil)
            }
            @Test func diveProfilePoint_formattedTimestamp_usesActivityOffset() {
                let start = Date(timeIntervalSince1970: 1_700_000_000)
                let activity = DiveActivity(
                    source: .macDive,
                    startTime: start,
                    timeZoneOffsetSeconds: 5 * 3600,
                    durationMinutes: 60,
                    maxDepthMeters: 18
                )
                let point = DiveProfilePoint(timestamp: start.addingTimeInterval(120), depthMeters: 12, dive: activity)
                #expect(
                    point.formattedTimestamp(for: activity)
                        == DiveActivityTimePresentation.formatDateTime(
                            point.timestamp,
                            timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds
                        )
                )
            }
            @Test @MainActor
            func diveActivityDeletion_removesActivityAndCascadedBuddy() async throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)

                let activity = DiveActivity(
                    source: .manual,
                    startTime: .now,
                    durationMinutes: 12,
                    maxDepthMeters: 18
                )
                let person = DiveBuddy(displayName: "Pat")
                let tag = DiveBuddyTag(buddy: person, dive: activity)
                tag.link(to: activity)
                activity.buddies.append(tag)
                context.insert(person)
                context.insert(activity)
                context.insert(tag)
                try context.save()

                try await DiveActivityDeletion.deletePermanently(activity, modelContext: context)

                let dives = try context.fetch(FetchDescriptor<DiveActivity>())
                let tags = try context.fetch(FetchDescriptor<DiveBuddyTag>())
                let people = try context.fetch(FetchDescriptor<DiveBuddy>())
                #expect(dives.isEmpty)
                #expect(tags.isEmpty)
                #expect(people.count == 1)
            }
            @Test func diveActivity_diveNumberLogbookLabel_numberOrHyphen() {
                let numbered = DiveActivity(source: .manual, startTime: Date(), durationMinutes: 1, maxDepthMeters: 1, diveNumber: 7)
                #expect(numbered.diveNumberLogbookLabel == "#7")

                let unset = DiveActivity(source: .manual, startTime: Date(), durationMinutes: 1, maxDepthMeters: 1, diveNumber: nil)
                #expect(unset.diveNumberLogbookLabel == "-")

                let hiddenButStored = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 1,
                    maxDepthMeters: 1,
                    diveNumber: 12
                )
                hiddenButStored.diveNumberExplicitlyNone = true
                #expect(hiddenButStored.diveNumberLogbookLabel == "-")
                #expect(hiddenButStored.diveNumberPlainLabel == "-")
            }
            @Test func diveActivity_gasDetailsLines_trimAndDash() {
                let emptyStrings = DiveActivity(
                    source: .manual,
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
                    source: .manual,
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
                #expect(DiveQuantityFormatting.swimDistance(meters: 210, system: .metric) == "210 m")
                #expect(DiveQuantityFormatting.swimDistance(meters: 100, system: .imperial) == "109 yd")
                #expect(DiveQuantityFormatting.swimDistance(meters: 0, system: .metric) == "—")

                #expect(DiveQuantityFormatting.fieldGuideDepth(meters: 15.5, system: .metric) == "16 m")
                #expect(DiveQuantityFormatting.fieldGuideDepth(meters: 6, system: .imperial) == "20 ft")
                #expect(
                    DiveQuantityFormatting.fieldGuideDepthRange(minMeters: 6, maxMeters: 25, system: .imperial)
                        == "20 ft–80 ft"
                )
                #expect(
                    DiveQuantityFormatting.fieldGuideDepthRange(minMeters: 6, maxMeters: 25, system: .metric)
                        == "6 m–25 m"
                )

                #expect(DiveQuantityFormatting.waterTemperature(celsius: 0, system: .metric) == "0.0 °C")
                #expect(DiveQuantityFormatting.waterTemperature(celsius: 100, system: .imperial) == "212.0 °F")
                #expect(DiveQuantityFormatting.waterTemperature(celsius: nil, system: .metric) == "—")

                #expect(DiveQuantityFormatting.tankVolumeDisplay(system: .imperial) == "80 cu ft")
                #expect(DiveQuantityFormatting.tankVolumeDisplay(system: .metric) == "2265 L")
                #expect(DiveQuantityFormatting.firstLitersValue(in: "80 L (0.080 m³)") == 80)
                #expect(DiveQuantityFormatting.firstLitersValue(in: "no liters here") == nil)
            }
            @Test func diveActivityUserFieldTypes_displayTitles() {
                #expect(DiveCurrentStrength.none.displayTitle == "None")
                #expect(DiveVisibilityRating.great.displayTitle == "Great")
            }
            @Test @MainActor
            func diveActivity_resolvedDiveCurrentStrength_defaultsToNoneWhenNil() {
                let activity = DiveActivity(
                    source: .manual,
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
                    source: .manual,
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
                    source: .macDive,
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
                let jamie = DiveBuddy(displayName: "Jamie")
                activity.buddies.append(DiveBuddyTag(buddy: jamie, dive: activity))
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
            @Test func diveActivityDiverWeightDefaults_applyImportDefaults_usesWaterTypeDefault() {
                let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DiverWeightImport")!
                defaults.removePersistentDomain(forName: "GoDiveMVPTests.DiverWeightImport")
                AppUserSettings.setDefaultSaltwaterWeightKilograms(6.0, userDefaults: defaults)
                AppUserSettings.setDefaultFreshwaterWeightKilograms(4.0, userDefaults: defaults)

                let salt = DiveActivity(source: .garminMK3, startTime: .now, durationMinutes: 30, maxDepthMeters: 18)
                DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: salt, userDefaults: defaults)
                #expect(salt.diveWaterType == .saltwater)
                #expect(salt.diverWeightKilograms == 6.0)

                let fresh = DiveActivity(source: .garminMK3, startTime: .now, durationMinutes: 30, maxDepthMeters: 18)
                fresh.diveWaterType = .freshwater
                DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: fresh, userDefaults: defaults)
                #expect(fresh.diverWeightKilograms == 4.0)

                let existing = DiveActivity(source: .garminMK3, startTime: .now, durationMinutes: 30, maxDepthMeters: 18)
                existing.diverWeightKilograms = 3.0
                DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: existing, userDefaults: defaults)
                #expect(existing.diverWeightKilograms == 3.0)
            }
            @Test func diveActivityDiverWeightDefaults_inheritsFromLinkedCatalogSite() {
                let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DiverWeightSiteInherit")!
                defaults.removePersistentDomain(forName: "GoDiveMVPTests.DiverWeightSiteInherit")
                AppUserSettings.setDefaultSaltwaterWeightKilograms(6.0, userDefaults: defaults)
                AppUserSettings.setDefaultFreshwaterWeightKilograms(4.0, userDefaults: defaults)

                let cenote = DiveSite(siteName: "Cenote Azul", waterType: .freshwater)
                let activity = DiveActivity(source: .garminMK3, startTime: .now, durationMinutes: 30, maxDepthMeters: 18)
                DiveActivitySiteAssociation.link(activity, to: cenote)
                activity.diveSiteID = cenote.id

                DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: activity, userDefaults: defaults)
                #expect(activity.diveWaterType == .freshwater)
                #expect(activity.diverWeightKilograms == 4.0)
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
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)

                let t0 = Date(timeIntervalSince1970: 0)
                let t1 = Date(timeIntervalSince1970: 86_400)
                let toDelete = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
                let remaining = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
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
            func diveActivityDeletion_withoutRenumber_leavesOtherDiveNumber() async throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)

                let t0 = Date(timeIntervalSince1970: 0)
                let t1 = Date(timeIntervalSince1970: 86_400)
                let toDelete = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
                let remaining = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
                context.insert(toDelete)
                context.insert(remaining)
                try context.save()

                try await DiveActivityDeletion.deletePermanently(toDelete, modelContext: context, applySequentialRenumberOverride: false)

                let dives = try context.fetch(FetchDescriptor<DiveActivity>())
                #expect(dives.count == 1)
                #expect(remaining.diveNumber == 2)
            }
            @Test @MainActor
            func diveActivityDeletion_reportProgress_finishesAtOne() async throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)

                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 1,
                    maxDepthMeters: 1,
                    diveNumber: 1
                )
                context.insert(activity)
                try context.save()

                var progressSamples: [Double] = []
                try await DiveActivityDeletion.delete(
                    DiveActivityDeletion.Request(
                        activityID: activity.id,
                        deletedStartTime: activity.startTime,
                        deletedId: activity.id,
                        renumberAfterDelete: false
                    ),
                    container: container,
                    reportProgress: { progressSamples.append($0) }
                )

                #expect(progressSamples.first == 0.12)
                #expect(progressSamples.last == 1.0)
            }
            @Test @MainActor
            func diveActivityDeletion_withRenumber_collapsesNumbers() async throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)

                let t0 = Date(timeIntervalSince1970: 0)
                let t1 = Date(timeIntervalSince1970: 86_400)
                let toDelete = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
                let remaining = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
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
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)

                let t0 = Date(timeIntervalSince1970: 0)
                let t1 = Date(timeIntervalSince1970: 86_400)
                let t2 = Date(timeIntervalSince1970: 172_800)
                let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
                let b = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
                let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
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
            @Test func diveActivityPostDeleteRenumbering_partialRenumberOnBackgroundContext() async throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])

                let t0 = Date(timeIntervalSince1970: 0)
                let t1 = Date(timeIntervalSince1970: 86_400)
                let t2 = Date(timeIntervalSince1970: 172_800)

                let deletedId = try await MainActor.run { () throws -> UUID in
                    let context = ModelContext(container)
                    let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
                    let b = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
                    let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 3)
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
            @Test func diveActivityStoreSync_awaitDiveAbsent_succeedsAfterBackgroundDelete() async throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let diveID = try await MainActor.run { () throws -> UUID in
                    let context = ModelContext(container)
                    let activity = DiveActivity(
                        source: .manual,
                        startTime: .now,
                        durationMinutes: 30,
                        maxDepthMeters: 18
                    )
                    context.insert(activity)
                    try context.save()
                    return activity.id
                }

                try await DiveBackgroundDeletionWorker(modelContainer: container)
                    .deleteDive(id: diveID)

                try await DiveActivityStoreSync.awaitDiveAbsent(diveID: diveID, container: container)
                #expect(DiveActivityStoreSync.isDiveAbsent(diveID: diveID, container: container))
            }
            @Test func diveActivityDeletionDebugReport_countsRelatedRows() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let activity = DiveActivity(source: .manual, startTime: .now, durationMinutes: 10, maxDepthMeters: 12)
                let photo = DiveMediaPhoto(sortOrder: 0, mediaKind: .image, dive: activity)
                activity.mediaPhotos.append(photo)
                context.insert(activity)
                try context.save()

                let report = try DiveActivityDeletionDebugReport.make(diveID: activity.id, modelContext: context)
                #expect(report.activityPresent)
                #expect(report.mediaCount == 1)
                #expect(report.buddyCount == 0)
            }
            @Test func diveActivityDeletionMarineLifeCleanup_removeDiveReferences_stripsActivityMediaAndSite() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let ownerID = UUID()
                let diveID = UUID()
                let siteID = UUID()
                let mediaID = UUID()
                let species = MarineLife(
                    uuid: "fish-002",
                    commonName: "Test Fish",
                    scientificName: "Testus",
                    category: "Fish"
                )
                let record = MarineLifeUserRecord(
                    marineLifeUUID: species.uuid,
                    isSighted: true,
                    activitiesSightedOn: [diveID],
                    sitesSightedOn: [siteID],
                    userTaggedMedia: [DiveActivityDeletionMarineLifeCleanup.userTaggedMediaLink(for: mediaID)]
                )
                record.ownerProfileID = ownerID
                context.insert(species)
                context.insert(record)

                let activity = DiveActivity(
                    id: diveID,
                    source: .manual,
                    startTime: .now,
                    durationMinutes: 10,
                    maxDepthMeters: 12
                )
                let photo = DiveMediaPhoto(id: mediaID, sortOrder: 0, mediaKind: .image, dive: activity)
                activity.mediaPhotos.append(photo)
                context.insert(activity)
                try context.save()

                try DiveActivityDeletionMarineLifeCleanup.removeDiveReferences(
                    diveID: diveID,
                    mediaPhotoIDs: [mediaID],
                    diveSiteID: siteID,
                    ownerProfileID: ownerID,
                    modelContext: context
                )

                #expect(record.activitiesSightedOn.isEmpty)
                #expect(record.sitesSightedOn.isEmpty)
                #expect(record.userTaggedMedia.isEmpty)
            }
            @Test func diveActivityRelationshipDetachment_clearsInverseArraysBeforeDelete() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let owner = UserProfile(appleUserIdentifier: "detach-owner", displayName: "Diver")
                let site = DiveSite(siteName: "Reef", latCoords: 12, longCoords: -68)
                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 25,
                    diveSiteID: site.id
                )
                activity.owner = owner
                activity.ownerProfileID = owner.id
                owner.diveActivities.append(activity)

                let tag = ActivityTag(name: "Night", normalizedName: "night", ownerProfileID: owner.id)
                activity.activityTags.append(tag)
                tag.dives.append(activity)

                context.insert(owner)
                context.insert(site)
                context.insert(tag)
                context.insert(activity)
                try context.save()

                DiveActivityRelationshipDetachment.detachNonCascadeRelationships(
                    from: activity,
                    modelContext: context
                )
                try context.save()

                #expect(tag.dives.isEmpty)
                #expect(owner.diveActivities.isEmpty)
                #expect(activity.activityTags.isEmpty)
                #expect(activity.diveSiteID == nil)
            }
            @Test @MainActor
            func diveActivityDeletion_backgroundRenumber_collapsesTailNumbers() async throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)

                let t0 = Date(timeIntervalSince1970: 0)
                let t1 = Date(timeIntervalSince1970: 86_400)
                let toDelete = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
                let remaining = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
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
                // Production path: tail renumber runs on **`DiveBackgroundRenumberingWorker`**, then merges into the UI context before **`delete`** returns.
                #expect(remaining.diveNumber == 1)
                #expect(try Self.persistedDiveNumber(id: remaining.id, container: container) == 1)
            }

    private static func persistedDiveNumber(id: UUID, container: ModelContainer) throws -> Int? {
        let readContext = ModelContext(container)
        let all = try readContext.fetch(FetchDescriptor<DiveActivity>())
        return all.first { $0.id == id }?.diveNumber
    }
}
