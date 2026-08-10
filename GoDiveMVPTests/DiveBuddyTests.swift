//
//  DiveBuddyTests.swift
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


struct DiveBuddyTests {
        @Test func diveBuddyDetailPresentation_layoutAndHeroSelection() {
            #expect(
                DiveBuddyDetailPresentation.heroLayoutStatsPanelContentHeight
                    == HomeOverviewLayout.heroLayoutStatsPanelContentHeight
            )
            #expect(
                DiveBuddyDetailPresentation.heroLayoutStatsPanelContentHeight
                    == HomeLifetimeStatsPanelLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: false)
            )
            #expect(
                DiveBuddyDetailPresentation.minimumPanelContentHeight
                    == DiveBuddyDetailPresentation.heroLayoutStatsPanelContentHeight
            )
            #expect(DiveBuddyDetailPresentation.profileAvatarDiameter == 120)
            #expect(DiveBuddyDetailPresentation.editToolbarActionStyle == .ellipsis)
            #expect(DiveBuddyDetailPresentation.editToolbarAccessibilityIdentifier == "DiveBuddyDetails.Edit")
            #expect(DiveBuddyDetailPresentation.editToolbarAccessibilityLabel == "Edit")
            #expect(DiveBuddyDetailPresentation.avatarOverlapOffset() == 60)
            #expect(DiveBuddyDetailPresentation.avatarLeadingInset == AppTheme.Spacing.lg)
            #expect(DiveBuddyDetailPresentation.identityTextLift == 12)
            #expect(DiveBuddyDetailPresentation.identityAvatarVerticalOffsetAdjustment == 23)
            #expect(DiveBuddyDetailPresentation.identityPinnedSummaryVerticalOffset == 1)
            #expect(DiveBuddyDetailPresentation.avatarPanelOverlayVerticalOffset() == -37)
            #expect(
                DiveBuddyDetailPresentation.identityPinnedSummaryBottomPadding
                    == BlueSheetDetailPagePinnedSummaryPresentation.pushedDetailPinnedSummaryBottomPadding
            )
            #expect(BlueSheetPinnedSummaryPresentation.buddyTitleFont == .title2.weight(.bold))
            #expect(BlueSheetPinnedSummaryPresentation.buddyAccentFont == .body.weight(.semibold))
            #expect(
                DiveBuddyDetailPresentation.heroModeToggleBottomPadding
                    > HomeLifetimeStatsLayout.panelOverlap
            )
            #expect(DiveBuddyDetailHeroHeaderView.Mode.media.shortTitle == "Media")
            #expect(DiveBuddyDetailHeroHeaderView.Mode.map.shortTitle == "Map")
            #expect(DiveBuddyDetailHeroHeaderView.Mode.allCases.count == 2)
            let pushedGeometryHeight: CGFloat = 852
            let homeTabViewportHeight = HomeOverviewLayout.viewportHeightMatchingHomeTab(
                from: pushedGeometryHeight
            )
            let screenWidth: CGFloat = 393
            let topSafeAreaInset: CGFloat = 59
            let statsBand = DiveBuddyDetailPresentation.heroLayoutStatsPanelContentHeight
            let buddyHero = DiveBuddyDetailPresentation.heroHeight(
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
            let pushedHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
                geometryHeight: pushedGeometryHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset,
                statsPanelContentHeight: statsBand
            ).heroHeight
            #expect(buddyHero == homeHero)
            #expect(pushedHero == homeHero)
            let buddyHeroWithZeroGeometryTop = DiveBuddyDetailPresentation.heroHeight(
                viewportHeight: pushedGeometryHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: 0
            )
            let homeHeroWithZeroGeometryTop = HomeOverviewLayout.metrics(
                viewportHeight: homeTabViewportHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: 0,
                statsPanelContentHeight: statsBand
            ).heroHeight
            #expect(buddyHeroWithZeroGeometryTop == homeHeroWithZeroGeometryTop)

            #expect(
                DiveBuddyTaggedMediaPresentation.isExplicitlyFeatured(
                    mediaID: UUID(),
                    explicitFeaturedID: nil
                ) == false
            )
            let featuredID = UUID()
            let otherID = UUID()
            #expect(
                DiveBuddyTaggedMediaPresentation.toggledFeaturedMediaPhotoID(
                    mediaID: featuredID,
                    explicitFeaturedID: nil
                ) == featuredID
            )
            #expect(
                DiveBuddyTaggedMediaPresentation.toggledFeaturedMediaPhotoID(
                    mediaID: featuredID,
                    explicitFeaturedID: featuredID
                ) == nil
            )
            #expect(
                DiveBuddyTaggedMediaPresentation.toggledFeaturedMediaPhotoID(
                    mediaID: otherID,
                    explicitFeaturedID: featuredID
                ) == otherID
            )

            let first = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 100))
            let second = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 200))
            let picked = DiveBuddyDetailPresentation.randomHeroTaggedMedia(from: [first, second])
            #expect(picked?.id == first.id || picked?.id == second.id)

            #expect(!DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: first))
            let video = DiveMediaPhoto(sortOrder: 0, mediaKind: .video)
            #expect(DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: video))
            #expect(!DiveBuddyDetailPresentation.shouldAutoPlaySelectedVideo(for: nil))
        }

        @Test @MainActor func diveBuddyDetailPresentation_initialPushedLayoutFloors_defaultWhenHomeAnchorUnset() {
            HomeOverviewLayoutAnchor.resetForTesting()
            defer { HomeOverviewLayoutAnchor.resetForTesting() }
            #expect(
                DiveBuddyDetailPresentation.initialPushedLayoutSafeAreaTopFloor()
                    == AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(0)
            )
            #expect(DiveBuddyDetailPresentation.initialPushedLayoutViewportFloor() == 0)
        }

        @Test func diveBuddyDetailPresentation_effectiveTagMerging_prefersQueryRows() {
            #expect(
                DiveBuddyDetailPresentation.effectiveDiveTags(queried: [], relationship: []).isEmpty
            )
            #expect(
                DiveBuddyDetailPresentation.effectiveMediaTags(queried: [], relationship: []).isEmpty
            )
        }

        @Test @MainActor func diveBuddyDetailPresentation_initialSharedDiveContent_seedsRelationshipRows() {
            let owner = UserProfile(appleUserIdentifier: "buddy-seed-owner", displayName: "Owner")
            let buddy = DiveBuddy(displayName: "Pat Lee", owner: owner)
            let dive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            dive.ownerProfileID = owner.id
            let tag = DiveBuddyTag(buddy: buddy, dive: dive)
            buddy.diveParticipations.append(tag)

            let seeded = DiveBuddyDetailPresentation.initialSharedDiveContent(for: buddy)
            #expect(seeded.sharedDives.count == 1)
            #expect(seeded.rows.count == 1)
            #expect(seeded.rows[0].displayName == LogbookActivityRow.displayName(for: dive))
        }

        @Test func diveBuddyDetailPresentation_ownerDiveIndex_buildsNumberingRowsFromActivities() {
            let dive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            dive.ownerProfileID = UUID()
            dive.diveNumberExplicitlyNone = true

            let index = DiveBuddyDetailPresentation.ownerDiveIndex(from: [dive])
            #expect(index.numberingRows.count == 1)
            #expect(index.numberingRows[0].id == dive.id)
            #expect(index.numberingRows[0].diveNumberExplicitlyNone == true)
            #expect(index.timeZoneOffsetByActivityID[dive.id] == dive.timeZoneOffsetSeconds)
        }

        @Test func diveBuddyDetailPresentation_mediaScopeDiveActivityIDs_usesSharedDivesNotFullOwnerLogbook() {
            let sharedDiveID = UUID()
            let taggedOnlyDiveID = UUID()
            let buddy = DiveBuddy(displayName: "Pat")
            let sharedDive = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            sharedDive.id = sharedDiveID

            let taggedDive = DiveActivity(
                source: .manual,
                startTime: .now.addingTimeInterval(-86_400),
                durationMinutes: 35,
                maxDepthMeters: 15
            )
            taggedDive.id = taggedOnlyDiveID
            let tag = DiveMediaBuddyTag(buddy: buddy, diveActivity: taggedDive)

            let scoped = DiveBuddyDetailPresentation.mediaScopeDiveActivityIDs(
                sharedDiveActivities: [sharedDive],
                mediaTags: [tag]
            )
            #expect(scoped == [sharedDiveID, taggedOnlyDiveID])
            #expect(scoped.count == 2)
        }

        @Test func diveBuddyDetailPresentation_deferredContentTaskToken_ignoresNumberingRowCount() {
            let buddyID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            let tokenA = DiveBuddyDetailPresentation.deferredContentTaskToken(
                buddyID: buddyID,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: true
            )
            let tokenB = DiveBuddyDetailPresentation.deferredContentTaskToken(
                buddyID: buddyID,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: true
            )
            let tokenUnits = DiveBuddyDetailPresentation.deferredContentTaskToken(
                buddyID: buddyID,
                unitSystemRawValue: "metric",
                automaticallyRenumberDives: true
            )
            let tokenRenumber = DiveBuddyDetailPresentation.deferredContentTaskToken(
                buddyID: buddyID,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: false
            )
            #expect(tokenA == tokenB)
            #expect(tokenA != tokenUnits)
            #expect(tokenA != tokenRenumber)
            #expect(tokenA == "\(buddyID.uuidString)|imperial|1")
        }

        @Test func diveBuddyDetailPresentation_contentRebuildFingerprint_changesWithEnrichmentFlags() {
            let buddyID = UUID()
            let base = DiveBuddyDetailPresentation.contentRebuildFingerprint(
                buddyID: buddyID,
                diveTagCount: 2,
                mediaTagCount: 3,
                ownerNumberingRowCount: 10,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: true,
                includeSecondarySections: true,
                includeTripRows: false,
                includeMarineLifeEnrichment: false
            )
            let enriched = DiveBuddyDetailPresentation.contentRebuildFingerprint(
                buddyID: buddyID,
                diveTagCount: 2,
                mediaTagCount: 3,
                ownerNumberingRowCount: 10,
                unitSystemRawValue: "imperial",
                automaticallyRenumberDives: true,
                includeSecondarySections: true,
                includeTripRows: false,
                includeMarineLifeEnrichment: true
            )
            #expect(base != enriched)
            #expect(
                base
                    == DiveBuddyDetailPresentation.contentRebuildFingerprint(
                        buddyID: buddyID,
                        diveTagCount: 2,
                        mediaTagCount: 3,
                        ownerNumberingRowCount: 10,
                        unitSystemRawValue: "imperial",
                        automaticallyRenumberDives: true,
                        includeSecondarySections: true,
                        includeTripRows: false,
                        includeMarineLifeEnrichment: false
                    )
            )
        }

        @Test @MainActor func diveBuddyRosterPresentation_sharedDiveCount_doesNotRequireSortedList() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "count-owner", displayName: "Owner")
            context.insert(owner)
            let buddy = DiveBuddy(displayName: "Pat", owner: owner)
            context.insert(buddy)

            let older = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 30,
                maxDepthMeters: 12
            )
            older.ownerProfileID = owner.id
            let newer = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            newer.ownerProfileID = owner.id
            context.insert(older)
            context.insert(newer)
            _ = DiveBuddyActivityAssociation.tagBuddy(buddy, on: older, modelContext: context)
            _ = DiveBuddyActivityAssociation.tagBuddy(buddy, on: newer, modelContext: context)
            try context.save()

            #expect(DiveBuddyRosterPresentation.sharedDiveCount(for: buddy, ownerProfileID: owner.id) == 2)
            let map = DiveBuddyRosterPresentation.sharedDiveCountsByBuddyID(
                for: [buddy],
                ownerProfileID: owner.id
            )
            #expect(map[buddy.id] == 2)
            let denormalizedMap = DiveBuddyRosterPresentation.sharedDiveCountsByBuddyID(
                buddyIDs: [buddy.id],
                modelContext: context
            )
            #expect(denormalizedMap[buddy.id] == 2)
        }

        @Test func buddiesListNavigationRoute_identifiableIDs_areStable() {
            let buddyID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            let friend = GoDiveFriendGraphService.friendEdge(friendUID: "uid-1", displayName: "Pat")
            #expect(BuddiesListNavigationRoute.rosterBuddy(buddyID).id == "buddy-\(buddyID.uuidString)")
            #expect(BuddiesListNavigationRoute.friend(friend).id == "friend-uid-1")
        }

        @Test @MainActor func diveBuddyDetailPresentation_numberedRows_seedFromOwnerIndexCache() {
            OwnerDiveIndexSessionCache.resetForTesting()
            defer { OwnerDiveIndexSessionCache.resetForTesting() }

            let owner = UserProfile(appleUserIdentifier: "buddy-number-cache", displayName: "Owner")
            let buddy = DiveBuddy(displayName: "Pat", owner: owner)
            let dive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            dive.ownerProfileID = owner.id
            let tag = DiveBuddyTag(buddy: buddy, dive: dive)
            buddy.diveParticipations.append(tag)

            OwnerDiveIndexSessionCache.publish(activities: [dive], ownerProfileID: owner.id)
            let seeded = DiveBuddyDetailPresentation.initialSharedDiveContent(for: buddy)
            guard let index = OwnerDiveIndexSessionCache.resolve(ownerProfileID: owner.id) else {
                Issue.record("Expected cached owner dive index")
                return
            }

            let rows = DiveBuddyRosterPresentation.sharedDiveRowDisplayData(
                sharedDives: seeded.sharedDives,
                unitSystem: .metric,
                useChronologicalNumbers: true,
                numberingRows: index.numberingRows
            )
            #expect(rows.count == 1)
        }

        @Test func diveBuddyDetailPresentation_initialMapPins_buildsFromSharedDives() {
            let site = DiveSite(siteName: "Reef", latCoords: 18.0, longCoords: -66.0)
            let dive = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            DiveActivitySiteAssociation.link(dive, to: site)

            let pins = DiveBuddyDetailMapPresentation.pins(from: [dive], catalogSites: [site])
            #expect(pins.count == 1)
            #expect(pins.first?.siteID == site.id)
        }

        @Test @MainActor func diveBuddyDetailContentPager_pages() {
            #expect(DiveBuddyDetailContentPagerPresentation.pageCount == 3)
            #expect(
                DiveBuddyDetailContentPagerPresentation.pages == [
                    .divesTogether,
                    .tripsTogether,
                    .taggedMedia,
                ]
            )
            #expect(DiveBuddyDetailContentPagerPresentation.defaultPage == .divesTogether)
            #expect(
                DiveBuddyDetailContentPagerPresentation.pageTitle(for: .divesTogether) == "Dives together"
            )
            #expect(
                DiveBuddyDetailContentPagerPresentation.pageTitle(for: .tripsTogether)
                    == DiveBuddyTripPresentation.sectionTitle
            )
            #expect(
                DiveBuddyDetailContentPagerPresentation.pageTitle(for: .taggedMedia)
                    == DiveBuddyTaggedMediaPresentation.sectionTitle
            )
            #expect(
                DiveBuddyDetailContentPagerPresentation.accessibilityIdentifier(for: .divesTogether)
                    == "DiveBuddyDetails.ContentPager.DivesTogether"
            )
            #expect(
                DiveBuddyDetailContentPagerPresentation.accessibilityIdentifier(for: .taggedMedia)
                    == "DiveBuddyDetails.ContentPager.TaggedMedia"
            )
            #expect(!DiveBuddyDetailContentPagerPresentation.usesStaticPagerLayout(for: .taggedMedia))
            #expect(!DiveBuddyDetailContentPagerPresentation.usesStaticPagerLayout(for: .divesTogether))
            #expect(!DiveBuddyDetailContentPagerPresentation.usesStaticPagerLayout(for: .tripsTogether))
            #expect(
                DiveBuddyDetailContentPagerPresentation.emptyStateMessage(for: .divesTogether)
                    == "No dives tagged with this buddy yet."
            )
            #expect(DiveBuddyDetailContentPagerPresentation.pageIndicatorClearance == 28)
            #expect(
                DiveBuddyDetailContentPagerPresentation.pinnedPageHeaderBottomSpacing == AppTheme.Spacing.md
            )
            #expect(DiveBuddyDetailContentPagerPresentation.showsPinnedPageHeaders)
            #expect(
                DiveBuddyDetailContentPagerPresentation.pageSubtitle(for: .divesTogether)
                    == "Dives Together"
            )
            #expect(
                DiveBuddyDetailContentPagerPresentation.pageSubtitle(for: .tripsTogether)
                    == "Trips Together"
            )
            #expect(
                DiveBuddyDetailContentPagerPresentation.pageSubtitle(for: .taggedMedia)
                    == "Your Tagged Photos"
            )
            #expect(
                DiveBuddyDetailContentPagerPresentation
                    .pageSubtitleAccessibilityIdentifier(for: .divesTogether)
                    == "DiveBuddyDetails.DivesTogether.Subtitle"
            )
        }

        @Test @MainActor
        func diveBuddyDeletion_deletePermanently_removesBuddyAndUntagsDives() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "apple-buddy-del", displayName: "Diver")
            context.insert(owner)

            let activity = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            DiveActivityOwnership.assignOwner(owner, to: activity)
            context.insert(activity)

            let buddy = DiveBuddy(displayName: "Pat Lee", owner: owner)
            context.insert(buddy)
            _ = DiveBuddyActivityAssociation.tagBuddy(buddy, on: activity, modelContext: context)
            try context.save()

            try DiveBuddyDeletion.deletePermanently(buddy, modelContext: context)

            #expect(try context.fetch(FetchDescriptor<DiveBuddy>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<DiveBuddyTag>()).isEmpty)
            let dives = try context.fetch(FetchDescriptor<DiveActivity>())
            #expect(dives.count == 1)
            #expect(dives.first?.buddies.isEmpty == true)
        }

        @Test @MainActor func diveBuddyDetailPresentation_fetchOwnerDiveIndexOffMainActor() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let ownerID = UUID()
            let profile = UserProfile(id: ownerID, appleUserIdentifier: "test-owner", displayName: "Owner")
            context.insert(profile)
            let dive = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 45,
                maxDepthMeters: 20
            )
            dive.ownerProfileID = ownerID
            context.insert(dive)
            try context.save()

            let index = await DiveBuddyDetailPresentation.fetchOwnerDiveIndex(
                ownerProfileID: ownerID,
                container: container
            )
            #expect(index.numberingRows.count == 1)
            #expect(index.numberingRows.first?.id == dive.id)
        }

        @Test @MainActor func diveBuddyTripPresentation_associatedTrips_includesPlannedAndTaggedLinkedDives() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext

            let owner = UserProfile(appleUserIdentifier: "owner-buddy-trips", displayName: "Alex")
            let buddy = DiveBuddy(displayName: "Jordan", owner: owner)
            let otherBuddy = DiveBuddy(displayName: "Sam", owner: owner)

            let upcomingTrip = DiveTrip(
                startDate: Date(timeIntervalSince1970: 3_000_000),
                endDate: Date(timeIntervalSince1970: 3_086_400),
                title: "Bonaire",
                owner: owner
            )
            let pastTrip = DiveTrip(
                startDate: Date(timeIntervalSince1970: 1_000_000),
                endDate: Date(timeIntervalSince1970: 1_086_400),
                title: "Curacao",
                owner: owner
            )
            let unrelatedTrip = DiveTrip(
                startDate: Date(timeIntervalSince1970: 1_500_000),
                endDate: Date(timeIntervalSince1970: 1_586_400),
                title: "Aruba",
                owner: owner
            )

            let taggedDive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_050_000),
                durationMinutes: 45,
                maxDepthMeters: 20
            )
            taggedDive.ownerProfileID = owner.id
            let link = DiveTripActivityLink(trip: pastTrip, diveActivity: taggedDive)
            let tag = DiveBuddyTag(buddy: buddy, dive: taggedDive)

            context.insert(owner)
            context.insert(buddy)
            context.insert(otherBuddy)
            context.insert(upcomingTrip)
            context.insert(pastTrip)
            context.insert(unrelatedTrip)
            context.insert(taggedDive)
            context.insert(link)
            context.insert(tag)

            DiveTripPlannedBuddyLinking.addBuddy(buddy, to: upcomingTrip, modelContext: context)
            DiveTripPlannedBuddyLinking.addBuddy(otherBuddy, to: unrelatedTrip, modelContext: context)

            let trips = [upcomingTrip, pastTrip, unrelatedTrip]
            let associated = DiveBuddyTripPresentation.associatedTrips(
                buddyID: buddy.id,
                ownerProfileID: owner.id,
                trips: trips,
                sharedDiveIDs: [taggedDive.id]
            )

            #expect(associated.map(\.id).sorted() == [upcomingTrip.id, pastTrip.id].sorted())
            #expect(!DiveBuddyTripPresentation.isBuddyAssociated(
                buddyID: buddy.id,
                trip: unrelatedTrip,
                sharedDiveIDs: [taggedDive.id]
            ))

            let sorted = DiveBuddyTripPresentation.sortedAssociatedTrips(
                associated,
                referenceDate: Date(timeIntervalSince1970: 2_000_000)
            )
            #expect(sorted.map(\.id) == [upcomingTrip.id, pastTrip.id])

            let row = DiveBuddyTripPresentation.rowDisplayData(
                for: upcomingTrip,
                referenceDate: Date(timeIntervalSince1970: 2_000_000)
            )
            #expect(row.title == "Bonaire")
            #expect(row.phaseLabel == TripPlannerPresentation.upcomingSectionTitle)
        }

        @Test @MainActor func diveBuddySelfRepresentation_findOrCreateSelfBuddy_reusesExistingMatch() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "self-buddy", displayName: "Pat Lee")
            let existing = DiveBuddy(displayName: "Pat", owner: owner)
            context.insert(owner)
            context.insert(existing)

            let resolved = try DiveBuddySelfRepresentation.findOrCreateSelfBuddy(
                owner: owner,
                modelContext: context
            )

            #expect(resolved.id == existing.id)
            #expect(try context.fetchCount(FetchDescriptor<DiveBuddy>()) == 1)
        }

        @Test @MainActor func diveBuddyActivityTagDraftPresentation_apply_writesOnlyOnDoneDiff() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext

            let owner = UserProfile(appleUserIdentifier: "buddy-draft-dive", displayName: "Diver")
            let dive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 3_430_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            dive.ownerProfileID = owner.id
            let jamie = DiveBuddy(displayName: "Jamie", owner: owner)
            let alex = DiveBuddy(displayName: "Alex", owner: owner)
            context.insert(owner)
            context.insert(dive)
            context.insert(jamie)
            context.insert(alex)

            _ = DiveBuddyActivityAssociation.tagBuddy(jamie, on: dive, modelContext: context)
            try context.save()
            #expect(dive.buddies.count == 1)

            let roster = [jamie.id: jamie, alex.id: alex]
            DiveBuddyActivityTagDraftPresentation.apply(
                draftTaggedBuddyIDs: [alex.id],
                to: dive,
                rosterByID: roster,
                modelContext: context
            )
            try context.save()

            #expect(Set(dive.buddies.compactMap(\.buddyID)) == [alex.id])
        }

        @Test func diveBuddyTaggedMediaPresentation_galleryRefreshToken_changesWhenTagsChange() {
            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let buddy = DiveBuddy(displayName: "Alex")
            let firstPhoto = DiveMediaPhoto(capturedAt: .now, dive: dive)
            let secondPhoto = DiveMediaPhoto(capturedAt: .now, dive: dive)
            let first = DiveMediaBuddyTag(buddy: buddy, mediaPhoto: firstPhoto, diveActivity: dive)
            let second = DiveMediaBuddyTag(buddy: buddy, mediaPhoto: secondPhoto, diveActivity: dive)
            let diveID = dive.id
            let tokenA = DiveBuddyTaggedMediaPresentation.galleryRefreshToken(
                tags: [first],
                ownerDiveActivityIDs: [diveID]
            )
            let tokenB = DiveBuddyTaggedMediaPresentation.galleryRefreshToken(
                tags: [first, second],
                ownerDiveActivityIDs: [diveID]
            )
            #expect(tokenA != tokenB)
        }

        @Test @MainActor func diveBuddyTaggedMediaPresentation_resolvedTaggedMediaPhotos_fetchesByMediaPhotoID() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            context.insert(dive)
            let buddy = DiveBuddy(displayName: "Alex")
            context.insert(buddy)
            let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 5_000), dive: dive)
            context.insert(media)

            let tag = DiveMediaBuddyTag(buddy: buddy, diveActivity: dive)
            tag.mediaPhoto = nil
            tag.mediaPhotoID = media.id
            context.insert(tag)
            try context.save()

            let photos = DiveBuddyTaggedMediaPresentation.resolvedTaggedMediaPhotos(
                tags: [tag],
                ownerDiveActivityIDs: [dive.id],
                modelContext: context
            )
            #expect(photos.count == 1)
            #expect(photos[0].id == media.id)
        }

        @Test @MainActor func diveBuddyTaggedMediaPresentation_collectsUniqueOwnerPhotos_oldestCaptureFirst() {
            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let otherDive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let buddy = DiveBuddy(displayName: "Alex")
            let older = DiveMediaPhoto(
                capturedAt: Date(timeIntervalSince1970: 1_000),
                dive: dive
            )
            let newer = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 2_000), dive: dive)
            let otherDivePhoto = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_000), dive: otherDive)

            let tags = [
                DiveMediaBuddyTag(
                    buddy: buddy,
                    mediaPhoto: newer,
                    diveActivity: dive
                ),
                DiveMediaBuddyTag(
                    buddy: buddy,
                    mediaPhoto: older,
                    diveActivity: dive
                ),
                DiveMediaBuddyTag(
                    buddy: buddy,
                    mediaPhoto: older,
                    diveActivity: dive
                ),
                DiveMediaBuddyTag(
                    buddy: buddy,
                    mediaPhoto: otherDivePhoto,
                    diveActivity: otherDive
                ),
            ]

            let photos = DiveBuddyTaggedMediaPresentation.taggedMediaPhotos(
                tags: tags,
                ownerDiveActivityIDs: [dive.id]
            )
            #expect(photos.map(\.id) == [older.id, newer.id])

            let offsets = DiveBuddyTaggedMediaPresentation.timeZoneOffsetByMediaID(
                tags: tags,
                ownerDiveActivityIDs: [dive.id],
                timeZoneOffsetByActivityID: [dive.id: -14_400]
            )
            #expect(offsets[older.id] == -14_400)
            #expect(offsets[newer.id] == -14_400)
            #expect(offsets[otherDivePhoto.id] == nil)
        }

        @Test func diveBuddyTaggedMediaPresentation_linkedMediaItems_mapsPhotosToParentDives() {
            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let buddy = DiveBuddy(displayName: "Alex")
            let photo = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 1_000), dive: dive)
            let tags = [
                DiveMediaBuddyTag(buddy: buddy, mediaPhoto: photo, diveActivity: dive),
            ]

            let linked = DiveBuddyTaggedMediaPresentation.linkedMediaItems(
                tags: tags,
                ownerDiveActivityIDs: [dive.id],
                mediaItems: [photo]
            )
            #expect(linked.count == 1)
            #expect(linked[0].id == photo.id)
            #expect(linked[0].diveActivityID == dive.id)
        }

        @Test func diveBuddyTaggedMediaPresentation_sightingsForTaggedMedia_filtersByPhotoID() {
            let mediaID = UUID()
            let otherMediaID = UUID()
            let taggedMedia = DiveMediaPhoto(id: mediaID, sortOrder: 0)
            let otherMedia = DiveMediaPhoto(id: otherMediaID, sortOrder: 1)
            let tagged = SightingInstance(
                marineLifeUUID: "species-1",
                sightingDateTime: Date(timeIntervalSince1970: 1_000),
                mediaPhoto: taggedMedia
            )
            let untagged = SightingInstance(
                marineLifeUUID: "species-2",
                sightingDateTime: Date(timeIntervalSince1970: 2_000),
                mediaPhoto: otherMedia
            )

            let filtered = DiveBuddyTaggedMediaPresentation.sightingsForTaggedMedia(
                allSightings: [tagged, untagged],
                taggedMediaItemIDs: [mediaID]
            )
            #expect(filtered.map(\.id) == [tagged.id])
        }

        @Test func diveBuddyTaggedMediaGridPresentation_cellSideLength_fitsThreeColumns() {
            let width: CGFloat = 300
            let side = DiveBuddyTaggedMediaGridPresentation.cellSideLength(containerWidth: width)
            let total = side * 3 + DiveBuddyTaggedMediaGridPresentation.spacing * 2
            #expect(abs(total - width) < 0.001)
            #expect(DiveBuddyTaggedMediaGridPresentation.columnCount == 3)
            #expect(
                LinkedMediaGridPresentation.cellSideLength(containerWidth: width) == side
            )
        }

        @Test @MainActor func diveBuddyTaggedMediaFullscreenPresentation_lockedDragAxis_prefersDominantTranslation() {
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.lockedDragAxis(
                    translation: CGSize(width: 20, height: 5)
                ) == .horizontal
            )
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.lockedDragAxis(
                    translation: CGSize(width: 5, height: 20)
                ) == .vertical
            )
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.lockedDragAxis(
                    translation: CGSize(width: 5, height: 5)
                ) == nil
            )
        }

        @Test func diveBuddyTaggedMediaFullscreenPresentation_browseOffset_mapsHorizontalSwipe() {
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.browseOffset(
                    forHorizontalTranslation: -40
                ) == 1
            )
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.browseOffset(
                    forHorizontalTranslation: 40
                ) == -1
            )
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.browseOffset(
                    forHorizontalTranslation: 10
                ) == nil
            )
        }

        @Test func diveBuddyTaggedMediaFullscreenPresentation_shouldDismiss_whenDraggedFarEnough() {
            let height: CGFloat = 800
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.shouldDismiss(
                    verticalTranslation: 300,
                    predictedEndTranslation: 300,
                    containerHeight: height
                )
            )
            #expect(
                !DiveBuddyTaggedMediaFullscreenPresentation.shouldDismiss(
                    verticalTranslation: 20,
                    predictedEndTranslation: 20,
                    containerHeight: height
                )
            )
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.shouldDismiss(
                    verticalTranslation: 10,
                    predictedEndTranslation: 250,
                    containerHeight: height
                )
            )
        }

        @Test func diveBuddyTaggedMediaFullscreenPresentation_dismissProgress_scalesAndFades() {
            let progress = DiveBuddyTaggedMediaFullscreenPresentation.dismissProgress(
                verticalTranslation: 120,
                containerHeight: 800
            )
            #expect(progress > 0)
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.dismissScale(progress: progress)
                < 1
            )
            #expect(
                DiveBuddyTaggedMediaFullscreenPresentation.dismissBackgroundOpacity(progress: progress)
                < 1
            )
        }

        @Test @MainActor func diveBuddyTaggedMediaPresentation_photosAvailableFromTagRelationships_collectsUniqueSortedPhotos() {
            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            let buddy = DiveBuddy(displayName: "Alex")
            let older = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 1_000), dive: dive)
            let newer = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 2_000), dive: dive)
            let tags = [
                DiveMediaBuddyTag(buddy: buddy, mediaPhoto: newer, diveActivity: dive),
                DiveMediaBuddyTag(buddy: buddy, mediaPhoto: older, diveActivity: dive),
                DiveMediaBuddyTag(buddy: buddy, mediaPhoto: newer, diveActivity: dive),
            ]

            let photos = DiveBuddyTaggedMediaPresentation.photosAvailableFromTagRelationships(tags)

            #expect(photos.map(\.id) == [older.id, newer.id])
        }

        @Test func diveBuddyTaggedMediaPresentation_resolvedHeroMediaPhotoID_prefersFeaturedThenSessionRandom() {
            let featured = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 100))
            let sessionRandom = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 200))
            let photos = [featured, sessionRandom]

            #expect(
                DiveBuddyTaggedMediaPresentation.resolvedHeroMediaPhotoID(
                    in: photos,
                    explicitFeaturedID: featured.id,
                    sessionRandomID: sessionRandom.id
                ) == featured.id
            )
            #expect(
                DiveBuddyTaggedMediaPresentation.resolvedHeroMediaPhotoID(
                    in: photos,
                    explicitFeaturedID: nil,
                    sessionRandomID: sessionRandom.id
                ) == sessionRandom.id
            )
        }

        @MainActor
        @Test func diveBuddyHeroMediaSession_reusesRandomPickForBuddy() {
            DiveBuddyHeroMediaSession.resetForTesting()
            let buddyID = UUID()
            let first = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 100))
            let second = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 200))
            let photos = [first, second]

            let initial = DiveBuddyHeroMediaSession.resolvedRandomHeroMediaID(
                buddyID: buddyID,
                in: photos
            )
            #expect(initial == first.id || initial == second.id)

            let again = DiveBuddyHeroMediaSession.resolvedRandomHeroMediaID(
                buddyID: buddyID,
                in: photos
            )
            #expect(again == initial)

            let replacement = DiveBuddyHeroMediaSession.pickNewRandomHeroMediaID(
                buddyID: buddyID,
                in: photos
            )
            #expect(replacement == first.id || replacement == second.id)
            DiveBuddyHeroMediaSession.resetForTesting()
        }

        @Test func diveBuddyDetailMapPresentation_pinsUniqueCoordinatesFromSharedDives() {
            let site = DiveSite(
                siteName: "Salt Pier",
                latCoords: 12.0835,
                longCoords: -68.283
            )
            let sharedA = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 100),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "Salt Pier",
                entryCoordinate: DiveCoordinate(latitude: 12.084, longitude: -68.284)
            )
            sharedA.diveSiteID = site.id
            let sharedB = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 200),
                durationMinutes: 35,
                maxDepthMeters: 16,
                siteName: "Salt Pier",
                entryCoordinate: DiveCoordinate(latitude: 12.084, longitude: -68.284)
            )
            sharedB.diveSiteID = site.id
            let sharedC = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 300),
                durationMinutes: 50,
                maxDepthMeters: 22,
                siteName: "Something Else",
                entryCoordinate: DiveCoordinate(latitude: 13.1, longitude: -69.1)
            )

            let pins = DiveBuddyDetailMapPresentation.pins(
                from: [sharedA, sharedB, sharedC],
                catalogSites: [site]
            )
            #expect(pins.count == 2)
            #expect(pins.allSatisfy { $0.kind == .completed })
            #expect(pins.contains(where: { $0.siteID == site.id }))
            #expect(
                DiveBuddyDetailMapPresentation.accessibilityLabel(for: pins)
                    == "Buddy dive sites map, 2 sites"
            )
        }

        @Test func diveBuddyTag_assigningDiveAfterInit_syncsDiveActivityID() {
            let activity = DiveActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 10,
                maxDepthMeters: 5
            )
            let person = DiveBuddy(displayName: "Pat")
            let tag = DiveBuddyTag(buddy: person)
            #expect(tag.diveActivityID == nil)
            tag.link(to: activity)
            #expect(tag.diveActivityID == activity.id)
            #expect(tag.buddyID == person.id)
        }

        @Test func diveBuddyCatalog_reusesContactsIdentifierForSameOwner() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "buddy-owner", displayName: "Diver")
            context.insert(owner)

            let first = DiveBuddyCatalog.findOrCreate(
                displayName: "Pat Lee",
                contactsIdentifier: "contact-abc",
                owner: owner,
                modelContext: context
            )
            let second = DiveBuddyCatalog.findOrCreate(
                displayName: "Patricia Lee",
                contactsIdentifier: "contact-abc",
                owner: owner,
                modelContext: context
            )
            #expect(first.id == second.id)
            #expect(second.displayName == "Patricia Lee")
        }

        @Test func diveBuddyNameMatching_isLikelyDiverSelf_matchesFuzzyProfileName() {
            #expect(DiveBuddyNameMatching.isLikelyDiverSelf(buddyName: "Mike Dugas", diverDisplayName: "Mike Dugas"))
            #expect(DiveBuddyNameMatching.isLikelyDiverSelf(buddyName: "Mike", diverDisplayName: "Mike Dugas"))
            #expect(!DiveBuddyNameMatching.isLikelyDiverSelf(buddyName: "Pat Lee", diverDisplayName: "Mike Dugas"))
            #expect(!DiveBuddyNameMatching.isLikelyDiverSelf(buddyName: "Mike Dugas", diverDisplayName: "Diver"))
            #expect(!DiveBuddyNameMatching.isLikelyDiverSelf(buddyName: "Mike Dugas", diverDisplayName: ""))
        }

        @Test func diveBuddyActivityAssociation_skipsTagWhenNameMatchesOwner() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "self-buddy-owner", displayName: "Mike Dugas")
            context.insert(owner)
            let activity = DiveActivity(
                source: .macDive,
                startTime: .now,
                durationMinutes: 30,
                maxDepthMeters: 12
            )
            context.insert(activity)

            let selfTag = DiveBuddyActivityAssociation.tagNewBuddy(
                displayName: "Mike Dugas",
                owner: owner,
                on: activity,
                modelContext: context
            )
            let buddyTag = DiveBuddyActivityAssociation.tagNewBuddy(
                displayName: "Pat Lee",
                owner: owner,
                on: activity,
                modelContext: context
            )
            #expect(selfTag == nil)
            #expect(buddyTag != nil)
            #expect(activity.buddies.count == 1)
            #expect(activity.buddies[0].displayName == "Pat Lee")
            let roster = try context.fetch(FetchDescriptor<DiveBuddy>())
            #expect(roster.count == 1)
        }

        @Test @MainActor func diveBuddyRosterCreation_addsBuddyWithoutDiveTag() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let owner = UserProfile(appleUserIdentifier: "roster-buddy-owner", displayName: "Mike Dugas")
            context.insert(owner)

            let buddy = DiveBuddyRosterCreation.addBuddy(
                displayName: "Pat Lee",
                owner: owner,
                modelContext: context
            )
            #expect(buddy?.displayName == "Pat Lee")
            #expect(try context.fetch(FetchDescriptor<DiveBuddyTag>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<DiveBuddy>()).count == 1)
        }

        @Test func diveBuddyNameMatching_firstNameLinksToFullRosterName() {
            #expect(DiveBuddyNameMatching.isLikelySamePerson(importedName: "Mike", rosterName: "Mike Dugas"))
            #expect(DiveBuddyNameMatching.isLikelySamePerson(importedName: "Mike Dugas", rosterName: "Mike"))
            #expect(DiveBuddyNameMatching.isLikelySamePerson(importedName: "Dugas Mike", rosterName: "Mike Dugas"))
            #expect(!DiveBuddyNameMatching.isLikelySamePerson(importedName: "Mike Dugas", rosterName: "Mike Smith"))
            #expect(!DiveBuddyNameMatching.isLikelySamePerson(importedName: "Ann Bee", rosterName: "Dan Bee"))
        }

        @Test func diveBuddyNameMatching_preferredDisplayNameKeepsFullName() {
            #expect(
                DiveBuddyNameMatching.preferredDisplayName(imported: "Mike", existing: "Mike Dugas") == "Mike Dugas"
            )
            #expect(
                DiveBuddyNameMatching.preferredDisplayName(imported: "Mike Dugas", existing: "Mike") == "Mike Dugas"
            )
        }

        @Test func diveBuddyCatalog_fuzzyMatchesImportToExistingRoster() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "fuzzy-buddy-owner", displayName: "Diver")
            context.insert(owner)
            let roster = DiveBuddy(displayName: "Mike Dugas", owner: owner)
            context.insert(roster)

            let linked = DiveBuddyCatalog.findOrCreate(
                displayName: "Mike",
                owner: owner,
                modelContext: context
            )
            #expect(linked.id == roster.id)
            #expect(linked.displayName == "Mike Dugas")
        }

        @Test func diveBuddyCatalog_fuzzyMatchSkipsAmbiguousFirstName() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "ambiguous-buddy-owner", displayName: "Diver")
            context.insert(owner)
            context.insert(DiveBuddy(displayName: "Mike Dugas", owner: owner))
            context.insert(DiveBuddy(displayName: "Mike Smith", owner: owner))

            let linked = DiveBuddyCatalog.findOrCreate(
                displayName: "Mike",
                owner: owner,
                modelContext: context
            )
            #expect(linked.displayName == "Mike")
            let rosterCount = try context.fetch(FetchDescriptor<DiveBuddy>()).count
            #expect(rosterCount == 3)
        }

        @Test func diveBuddyImportConsolidation_reusesFuzzyRosterBuddy() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "import-buddy-owner", displayName: "Diver")
            context.insert(owner)
            let roster = DiveBuddy(displayName: "Ann Bee", owner: owner)
            context.insert(roster)

            let activity = DiveActivity(
                source: .macDive,
                startTime: .now,
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            DiveActivityOwnership.assignOwner(owner, to: activity)
            activity.buddies = [DiveBuddyImportConsolidation.makePendingTag(displayName: "Ann")]
            var rosterCache: DiveBuddyImportConsolidation.RosterCache = [
                DiveBuddyCatalog.normalizedNameKey(roster.displayName): roster,
            ]
            DiveBuddyImportConsolidation.prepareForInsert(
                activity,
                owner: owner,
                modelContext: context,
                rosterCache: &rosterCache
            )
            context.insert(activity)

            #expect(activity.buddies.count == 1)
            #expect(activity.buddies[0].buddy?.id == roster.id)
            #expect(activity.buddies[0].displayName == "Ann Bee")
        }

        @Test func diveBuddyImportConsolidation_multiDiveBatch_reusesOneRosterBuddy() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "batch-buddy-owner", displayName: "Diver")
            context.insert(owner)

            var rosterCache = DiveBuddyImportConsolidation.RosterCache()
            let names = ["Mike Dugas", "Mike Dugas", "Mike"]

            for name in names {
                let activity = DiveActivity(
                    source: .macDive,
                    startTime: .now,
                    durationMinutes: 30,
                    maxDepthMeters: 15
                )
                DiveActivityOwnership.assignOwner(owner, to: activity)
                activity.buddies = [DiveBuddyImportConsolidation.makePendingTag(displayName: name)]
                DiveBuddyImportConsolidation.prepareForInsert(
                    activity,
                    owner: owner,
                    modelContext: context,
                    rosterCache: &rosterCache
                )
                context.insert(activity)
            }

            let roster = try context.fetch(FetchDescriptor<DiveBuddy>())
            #expect(roster.count == 1)
            #expect(roster[0].displayName == "Mike Dugas")
            #expect(roster[0].diveParticipations.count == 3)
        }

        @Test func diveBuddyImportConsolidation_detachPendingTags_avoidsOrphanBuddyInsert() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "detach-buddy-owner", displayName: "Diver")
            context.insert(owner)

            let activity = DiveActivity(
                source: .macDive,
                startTime: .now,
                durationMinutes: 20,
                maxDepthMeters: 10
            )
            DiveActivityOwnership.assignOwner(owner, to: activity)

            let pending = DiveBuddyImportConsolidation.makePendingTag(displayName: "Pat Lee")
            pending.dive = activity
            activity.buddies = [pending]

            var rosterCache = DiveBuddyImportConsolidation.RosterCache()
            DiveBuddyImportConsolidation.prepareForInsert(
                activity,
                owner: owner,
                modelContext: context,
                rosterCache: &rosterCache
            )
            context.insert(activity)
            try context.save()

            let roster = try context.fetch(FetchDescriptor<DiveBuddy>())
            #expect(roster.count == 1)
            #expect(roster[0].displayName == "Pat Lee")
            #expect(activity.buddies.count == 1)
            #expect(activity.buddies[0].buddy?.id == roster[0].id)
        }

        @Test func diveBuddyActivityAssociation_doesNotDuplicateTagOnSameDive() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let activity = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 10,
                maxDepthMeters: 12
            )
            context.insert(activity)
            let person = DiveBuddy(displayName: "Jamie")
            context.insert(person)

            let first = DiveBuddyActivityAssociation.tagBuddy(person, on: activity, modelContext: context)
            let second = DiveBuddyActivityAssociation.tagBuddy(person, on: activity, modelContext: context)
            #expect(first != nil)
            #expect(second == nil)
            #expect(activity.buddies.count == 1)
        }

        @Test func diveBuddyContactImport_displayName_prefersFormatter() {
            let contact = CNMutableContact()
            contact.givenName = "Pat"
            contact.familyName = "Lee"
            #expect(DiveBuddyContactImport.displayName(from: contact) == "Pat Lee")
        }

        @Test func diveBuddyEditContactPresentation_titlesForLinkState() {
            #expect(
                DiveBuddyEditContactPresentation.linkButtonTitle(isLinked: false)
                    == "Connect to Contact"
            )
            #expect(
                DiveBuddyEditContactPresentation.linkButtonTitle(isLinked: true)
                    == "Change contact"
            )
            #expect(DiveBuddyEditContactPresentation.disconnectButtonTitle == "Disconnect contact")
            #expect(DiveBuddyEditContactPresentation.sectionTitle == "Contact")
        }

        @Test func diveBuddyContactLinking_applyLinksContactToRosterBuddy() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "link-contact-owner", displayName: "Diver One")
            context.insert(owner)
            let buddy = DiveBuddy(displayName: "Old Name", owner: owner)
            context.insert(buddy)

            let contact = CNMutableContact()
            contact.givenName = "Jamie"
            contact.familyName = "Lee"

            try DiveBuddyContactLinking.apply(
                contact: contact,
                to: buddy,
                owner: owner,
                modelContext: context
            )

            #expect(buddy.displayName == "Jamie Lee")
            #expect(buddy.contactsIdentifier == contact.identifier)
        }

        @Test func diveBuddyContactLinking_rejectsContactAlreadyLinkedToAnotherBuddy() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "dup-contact-owner", displayName: "Diver")
            context.insert(owner)

            let contact = CNMutableContact()
            contact.givenName = "Alex"
            contact.familyName = "Kim"

            let first = DiveBuddy(displayName: "Alex Kim", owner: owner)
            first.contactsIdentifier = contact.identifier
            context.insert(first)

            let second = DiveBuddy(displayName: "Someone Else", owner: owner)
            context.insert(second)

            #expect(throws: DiveBuddyContactLinking.LinkError.self) {
                try DiveBuddyContactLinking.apply(
                    contact: contact,
                    to: second,
                    owner: owner,
                    modelContext: context
                )
            }
        }

        @Test func diveBuddyContactAutoLink_resolvesUniqueFuzzyMatch() {
            let candidates = [
                DiveBuddyContactAutoLink.ContactMatchCandidate(
                    contactsIdentifier: "contact-pat",
                    displayName: "Pat Lee"
                ),
                DiveBuddyContactAutoLink.ContactMatchCandidate(
                    contactsIdentifier: "contact-other",
                    displayName: "Jordan Smith"
                ),
            ]
            let resolved = DiveBuddyContactAutoLink.resolvedContactID(
                buddyDisplayName: "Pat",
                candidates: candidates,
                reservedContactIDs: []
            )
            #expect(resolved == "contact-pat")
        }

        @Test func diveBuddyContactAutoLink_skipsAmbiguousContactMatches() {
            let candidates = [
                DiveBuddyContactAutoLink.ContactMatchCandidate(
                    contactsIdentifier: "contact-a",
                    displayName: "Mike Dugas"
                ),
                DiveBuddyContactAutoLink.ContactMatchCandidate(
                    contactsIdentifier: "contact-b",
                    displayName: "Mike Smith"
                ),
            ]
            let resolved = DiveBuddyContactAutoLink.resolvedContactID(
                buddyDisplayName: "Mike",
                candidates: candidates,
                reservedContactIDs: []
            )
            #expect(resolved == nil)
        }

        @Test func diveBuddyContactAutoLink_skipsContactsAlreadyLinkedToAnotherBuddy() {
            let candidates = [
                DiveBuddyContactAutoLink.ContactMatchCandidate(
                    contactsIdentifier: "contact-taken",
                    displayName: "Pat Lee"
                ),
            ]
            let resolved = DiveBuddyContactAutoLink.resolvedContactID(
                buddyDisplayName: "Pat Lee",
                candidates: candidates,
                reservedContactIDs: ["contact-taken"]
            )
            #expect(resolved == nil)
        }

        @Test func diveBuddyLegacyMigration_linksOrphanTagsToPeople() throws {
            let schema = Schema([
                DiveActivity.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                UserProfile.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "legacy-owner", displayName: "Diver")
            context.insert(owner)
            let activity = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 10,
                maxDepthMeters: 8
            )
            DiveActivityOwnership.assignOwner(owner, to: activity)
            context.insert(activity)

            let tag = DiveBuddyTag(buddy: DiveBuddy(displayName: "Should not use"), dive: activity)
            tag.buddy = nil
            tag.legacyDisplayName = "Legacy Pat"
            context.insert(tag)
            activity.buddies.append(tag)
            try context.save()

            UserDefaults.standard.set(false, forKey: "goDiveDiveBuddyPersonMigrationComplete")
            try DiveBuddyLegacyMigration.migrateIfNeeded(modelContext: context)

            #expect(tag.buddy != nil)
            #expect(tag.displayName == "Legacy Pat")
            #expect(tag.legacyDisplayName == nil)
            #expect(tag.buddy?.ownerProfileID == owner.id)
            UserDefaults.standard.set(true, forKey: "goDiveDiveBuddyPersonMigrationComplete")
        }

        @Test func diveBuddyRosterPresentation_labels() {
            #expect(DiveBuddyRosterPresentation.rosterCountLabel(0) == "No buddies")
            #expect(DiveBuddyRosterPresentation.rosterCountLabel(1) == "1 buddy")
            #expect(DiveBuddyRosterPresentation.rosterCountLabel(4) == "4 buddies")
            #expect(DiveBuddyRosterPresentation.sharedDiveCountLabel(0) == "No dives together")
            #expect(DiveBuddyRosterPresentation.sharedDiveCountLabel(1) == "1 dive together")
            #expect(DiveBuddyRosterPresentation.sharedDiveCountLabel(3) == "3 dives together")
            #expect(DiveBuddyRosterPresentation.listSubtitle(sharedDiveCount: 2) == "2 dives together")
            #expect(ProfilePresentation.diveBuddyRosterCountLabel(2) == "2 buddies")
            #expect(DiveBuddyRosterPresentation.buddyDetailUsesScrollContainer == false)
            #expect(DiveBuddyDetailContentPagerPresentation.pageCount == 3)
            #expect(ExpandableDetailSectionPresentation.buddyDetailScrollsExpandedDiveList)
            #expect(ExpandableDetailSectionPresentation.buddyDetailKeepsExpandedContentMounted)
            #expect(ExpandableDetailSectionPresentation.expandCollapseAnimationDuration == 0.12)
        }

        @Test func diveBuddyRosterPresentation_sharedDiveRowDisplayData_ordersNewestFirst() {
            let ownerID = UUID()
            let older = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            older.ownerProfileID = ownerID
            let newer = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 2_000),
                durationMinutes: 50,
                maxDepthMeters: 24
            )
            newer.ownerProfileID = ownerID

            let rows = DiveBuddyRosterPresentation.sharedDiveRowDisplayData(
                sharedDives: [newer, older],
                unitSystem: .metric,
                useChronologicalNumbers: false,
                numberingActivities: [newer, older]
            )
            #expect(rows.map(\.id) == [newer.id, older.id])
        }

        @Test func diveBuddyRosterPresentation_sharedDiveActivitiesFromTags_ordersNewestFirst() {
            let ownerID = UUID()
            let otherOwnerID = UUID()
            let buddy = DiveBuddy(displayName: "Alex")
            let older = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            older.ownerProfileID = ownerID
            let newer = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 2_000),
                durationMinutes: 50,
                maxDepthMeters: 24
            )
            newer.ownerProfileID = ownerID
            let otherOwnerDive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 3_000),
                durationMinutes: 30,
                maxDepthMeters: 12
            )
            otherOwnerDive.ownerProfileID = otherOwnerID

            let tags = [
                DiveBuddyTag(buddy: buddy, dive: older),
                DiveBuddyTag(buddy: buddy, dive: newer),
                DiveBuddyTag(buddy: buddy, dive: otherOwnerDive),
            ]

            let shared = DiveBuddyRosterPresentation.sharedDiveActivities(
                from: tags,
                ownerProfileID: ownerID
            )
            #expect(shared.map(\.id) == [newer.id, older.id])
        }

        @Test func diveBuddySelfRepresentation_rosterBuddiesExcludingSelf_filtersSelfRow() {
            let owner = UserProfile(appleUserIdentifier: "owner", displayName: "Mike Dugas")
            let selfBuddy = DiveBuddy(displayName: "Mike Dugas", owner: owner)
            let otherBuddy = DiveBuddy(displayName: "Pat Lee", owner: owner)
            let filtered = DiveBuddySelfRepresentation.rosterBuddiesExcludingSelf(
                [selfBuddy, otherBuddy],
                owner: owner
            )
            #expect(filtered.count == 1)
            #expect(filtered[0].displayName == "Pat Lee")
        }

        @Test func diveBuddySelfRepresentation_isSelfBuddyID_matchesResolvedID() {
            let selfBuddyID = UUID()
            #expect(DiveBuddySelfRepresentation.isSelfBuddyID(selfBuddyID, selfBuddyID: selfBuddyID))
            #expect(!DiveBuddySelfRepresentation.isSelfBuddyID(UUID(), selfBuddyID: selfBuddyID))
            #expect(!DiveBuddySelfRepresentation.isSelfBuddyID(selfBuddyID, selfBuddyID: nil))
        }

        @Test @MainActor func diveBuddyPresentation_firstName_usesFirstToken() {
            #expect(DiveBuddyPresentation.firstName(from: "Pat Lee") == "Pat")
            #expect(DiveBuddyPresentation.firstName(from: "  Jamie  ") == "Jamie")
            #expect(DiveBuddyPresentation.firstName(from: "Madonna") == "Madonna")
            #expect(DiveBuddyPresentation.firstName(from: "   ") == "Buddy")

            #expect(
                DiveBuddyPresentation.twoLineDisplayName(from: "Pat Lee")
                    == .init(firstLine: "Pat", secondLine: "Lee")
            )
            #expect(
                DiveBuddyPresentation.twoLineDisplayName(from: "Mary Ann Smith")
                    == .init(firstLine: "Mary Ann", secondLine: "Smith")
            )
            #expect(
                DiveBuddyPresentation.twoLineDisplayName(from: "Madonna")
                    == .init(firstLine: "Madonna", secondLine: nil)
            )
            #expect(
                DiveBuddyPresentation.twoLineDisplayName(from: "  jean luc  picard  ")
                    == .init(firstLine: "jean luc", secondLine: "picard")
            )
            #expect(
                DiveBuddyPresentation.twoLineDisplayName(from: "   ")
                    == .init(firstLine: "Buddy", secondLine: nil)
            )
        }

        @Test func diveBuddyPresentation_addBuddySheetAccessibilityIdentifiers() {
            #expect(DiveBuddyPresentation.addBuddySheetCancelAccessibilityIdentifier == "DiveActivityAddBuddySheet.Cancel")
            #expect(DiveBuddyPresentation.addBuddySheetDoneAccessibilityIdentifier == "DiveActivityAddBuddySheet.Done")
        }

        @Test func diveBuddyPresentation_initials_usesFirstAndLastToken() {
            #expect(DiveBuddyPresentation.initials(from: "Judy Belair") == "JB")
            #expect(DiveBuddyPresentation.initials(from: "Pat Lee") == "PL")
            #expect(DiveBuddyPresentation.initials(from: "Madonna") == "M")
            #expect(DiveBuddyPresentation.initials(from: "  jamie kay  ") == "JK")
            #expect(DiveBuddyPresentation.initials(from: "   ") == "B")
        }
}
