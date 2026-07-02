//
//  GoDiveMVPTests.swift
//  GoDiveMVPTests
//
//  Created by André Dugas on 4/1/26.
//

import Contacts
import AuthenticationServices
import CoreGraphics
import CoreLocation
import Foundation
import MapKit
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

struct GoDiveMVPTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

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

    @Test @MainActor func diveActivityMediaStorage_postMediaDidChange_notifiesObservers() {
        final class Counter: @unchecked Sendable { var value = 0 }
        let counter = Counter()
        // `queue: nil` delivers synchronously on the posting thread, so the count is set before `post` returns.
        let token = NotificationCenter.default.addObserver(
            forName: .diveActivityMediaDidChange,
            object: nil,
            queue: nil
        ) { _ in counter.value += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        DiveActivityMediaStorage.postMediaDidChange()
        #expect(counter.value >= 1)
    }

    @Test @MainActor func diveActivityMediaFocus_withID_targetsCameraTabMediumDetent() {
        let mediaID = UUID()
        let focus = DiveActivityMediaFocusPresentation.focus(forMediaFocusID: mediaID)
        #expect(
            focus == DiveActivityMediaFocusPresentation.Focus(
                tab: .camera,
                detent: .medium,
                mediaID: mediaID
            )
        )
    }

    @Test func diveActivityMediaFocus_withoutID_isNil() {
        #expect(DiveActivityMediaFocusPresentation.focus(forMediaFocusID: nil) == nil)
    }

    @Test func diveActivityMediaActivation_resolvedPendingFocus_waitsForMediaRows() {
        let pending = UUID()
        let photo = DiveMediaPhoto(id: pending)
        #expect(
            DiveActivityMediaActivation.resolvedPendingFocus(
                pendingMediaID: pending,
                in: []
            ) == nil
        )
        #expect(
            DiveActivityMediaActivation.resolvedPendingFocus(
                pendingMediaID: pending,
                in: [photo]
            ) == pending
        )
        #expect(
            DiveActivityMediaActivation.resolvedPendingFocus(
                pendingMediaID: UUID(),
                in: [photo]
            ) == nil
        )
    }

    @Test func diveActivityMediaPresentation_resolvedSelectedPhotoID_prefersDeepLinkTarget() {
        let first = UUID()
        let second = UUID()
        let photos = [DiveMediaPhoto(id: first), DiveMediaPhoto(id: second)]
        #expect(
            DiveActivityMediaPresentation.resolvedSelectedPhotoID(
                selectedID: first,
                in: photos,
                preferredID: second
            ) == second
        )
    }

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
        #expect(DiveBuddyDetailPresentation.avatarOverlapOffset() == 60)
        #expect(DiveBuddyDetailPresentation.avatarLeadingInset == AppTheme.Spacing.lg)
        #expect(DiveBuddyDetailPresentation.identityTextLift == 12)
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

    @Test @MainActor func ownerDiveIndexSessionCache_reusesPublishedOwnerIndex() {
        OwnerDiveIndexSessionCache.resetForTesting()
        defer { OwnerDiveIndexSessionCache.resetForTesting() }

        let ownerID = UUID()
        let older = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        older.ownerProfileID = ownerID
        older.timeZoneOffsetSeconds = -18_000
        let newer = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 1_800_000_000),
            durationMinutes: 50,
            maxDepthMeters: 24
        )
        newer.ownerProfileID = ownerID

        OwnerDiveIndexSessionCache.publish(activities: [newer, older], ownerProfileID: ownerID)
        let cached = OwnerDiveIndexSessionCache.resolve(ownerProfileID: ownerID)

        #expect(cached?.numberingRows.count == 2)
        #expect(cached?.numberingRows[0].id == newer.id)
        #expect(cached?.timeZoneOffsetByActivityID[older.id] == -18_000)
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

    @Test func pushedNavigationDeferralPresentation_afterPushDelay_matchesTripAutoLinkDeferral() {
        #expect(PushedNavigationDeferralPresentation.afterPushDelay == .milliseconds(300))
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
        dive.diveSite = site
        dive.diveSiteID = site.id

        let pins = DiveBuddyDetailPresentation.initialMapPins(from: [dive])
        #expect(pins.count == 1)
        #expect(pins[0].siteID == site.id)
    }

    @Test func exploreDiveSiteDetailContentSnapshotBuilder_siteActivitiesFromRelationships_filtersOwner() {
        let ownerID = UUID()
        let otherOwnerID = UUID()
        let site = DiveSite(siteName: "Reef")

        let ownerDive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 2_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        ownerDive.ownerProfileID = ownerID
        ownerDive.diveSite = site

        let otherDive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_000),
            durationMinutes: 35,
            maxDepthMeters: 15
        )
        otherDive.ownerProfileID = otherOwnerID
        otherDive.diveSite = site

        site.diveActivities = [ownerDive, otherDive]

        let filtered = ExploreDiveSiteDetailContentSnapshotBuilder.siteActivitiesFromRelationships(
            site: site,
            ownerProfileID: ownerID
        )
        #expect(filtered.count == 1)
        #expect(filtered[0].id == ownerDive.id)
    }

    @Test func pushedNavigationDeferralPresentation_afterPushMapDeferral_matchesAfterPushDelay() {
        #expect(
            PushedNavigationDeferralPresentation.afterPushMapDeferral
                == PushedNavigationDeferralPresentation.afterPushDelay
        )
    }

    @Test @MainActor func homeOverviewPushedLayoutPresentation_pushedPageSeamInputs_usesDefaultBandWithoutStoreScan() {
        let inputs = HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
        #expect(
            inputs.statsPanelContentHeight == HomeOverviewLayout.heroLayoutStatsPanelContentHeight
        )
        #expect(inputs.showsBuddyLeaderboard == false)
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
        #expect(!DiveBuddyDetailContentPagerPresentation.showsPinnedPageHeaders)
    }

    @Test func diveActivityMediaActivation_shouldReaffirmPagerSelection_requiresActiveContext() {
        #expect(
            DiveActivityMediaActivation.shouldReaffirmPagerSelection(
                isMediaContextActive: true,
                mediaCount: 2
            )
        )
        #expect(
            !DiveActivityMediaActivation.shouldReaffirmPagerSelection(
                isMediaContextActive: false,
                mediaCount: 2
            )
        )
        #expect(
            !DiveActivityMediaActivation.shouldReaffirmPagerSelection(
                isMediaContextActive: true,
                mediaCount: 0
            )
        )
    }

    @Test func diveActivityMediaPresentation_shouldReaffirmPagerAfterViewportChange() {
        let portrait = CGSize(width: 390, height: 844)
        let landscape = CGSize(width: 844, height: 390)
        #expect(
            !DiveActivityMediaPresentation.shouldReaffirmPagerAfterViewportChange(
                previousSize: nil,
                newSize: portrait
            )
        )
        #expect(
            DiveActivityMediaPresentation.shouldReaffirmPagerAfterViewportChange(
                previousSize: portrait,
                newSize: landscape
            )
        )
        #expect(
            !DiveActivityMediaPresentation.shouldReaffirmPagerAfterViewportChange(
                previousSize: portrait,
                newSize: portrait
            )
        )
        #expect(DiveActivityMediaPresentation.pagerLayoutReaffirmSettleDelay > .zero)
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
    func userProfileStore_applyDisplayNameFromApple_writesFreshFullName() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let appleID = "apple-fresh-name-\(UUID().uuidString)"

        let profile = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: appleID,
            displayName: nil,
            modelContext: context
        )
        #expect(profile.displayName == UserProfileStore.defaultDisplayName)

        try UserProfileStore.applyDisplayNameFromApple(
            to: profile,
            appleProvided: "Alex Diver",
            appleUserIdentifier: appleID,
            modelContext: context
        )
        #expect(profile.displayName == "Alex Diver")
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

    @Test func profilePresentation_danInsuranceLabel_formatsMemberNumber() {
        #expect(ProfilePresentation.danInsuranceLabel("1234567") == "DAN 1234567")
    }

    @Test func profilePresentation_diveActivityCountLabel_pluralizes() {
        #expect(ProfilePresentation.diveActivityCountLabel(0) == "No dives logged")
        #expect(ProfilePresentation.diveActivityCountLabel(1) == "1 dive")
        #expect(ProfilePresentation.diveActivityCountLabel(12) == "12 dives")
    }

    @Test func profilePresentation_certificationAndEquipmentCountLabels_pluralize() {
        #expect(ProfilePresentation.certificationCountLabel(0) == "No certifications")
        #expect(ProfilePresentation.certificationCountLabel(1) == "1 certification")
        #expect(ProfilePresentation.certificationCountLabel(3) == "3 certifications")
        #expect(ProfilePresentation.equipmentItemCountLabel(0) == "No gear")
        #expect(ProfilePresentation.equipmentItemCountLabel(1) == "1 item")
        #expect(ProfilePresentation.equipmentItemCountLabel(5) == "5 items")
        #expect(ProfilePresentation.tripCountLabel(0) == "No trips")
        #expect(ProfilePresentation.tripCountLabel(1) == "1 trip")
        #expect(ProfilePresentation.tripCountLabel(4) == "4 trips")
    }

    @Test func profileTaggedMediaPresentation_mediaCountLabel() {
        #expect(ProfileTaggedMediaPresentation.mediaCountLabel(0) == "No tagged media")
        #expect(ProfileTaggedMediaPresentation.mediaCountLabel(1) == "1 photo or video")
        #expect(ProfileTaggedMediaPresentation.mediaCountLabel(4) == "4 photos and videos")
    }

    @Test func profileTaggedMediaPresentation_uniqueTaggedMediaCount_dedupesByPhoto() {
        let buddy = DiveBuddy(displayName: "You")
        let buddyID = buddy.id
        let diveID = UUID()
        let mediaA = UUID()
        let mediaB = UUID()
        let otherDiveID = UUID()

        func makeTag(mediaID: UUID, diveID: UUID) -> DiveMediaBuddyTag {
            let tag = DiveMediaBuddyTag(buddy: buddy)
            tag.mediaPhotoID = mediaID
            tag.diveActivityID = diveID
            return tag
        }

        let tags = [
            makeTag(mediaID: mediaA, diveID: diveID),
            makeTag(mediaID: mediaA, diveID: diveID),
            makeTag(mediaID: mediaB, diveID: diveID),
            makeTag(mediaID: UUID(), diveID: otherDiveID),
        ]
        let count = ProfileTaggedMediaPresentation.uniqueTaggedMediaCount(
            tags: tags,
            buddyID: buddyID,
            ownerDiveActivityIDs: [diveID]
        )
        #expect(count == 2)
    }

    @Test func profileDestinationTilePresentation_usesUniformTileHeight() {
        #expect(ProfileDestinationTilePresentation.tileHeight == 54)
        #expect(ProfileDestinationTilePresentation.iconPointSize == 22)
        #expect(ProfileDestinationTilePresentation.iconSlotWidth == 28)
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

    @Test func profilePhotoCropRenderer_clampedOffset_keepsCropInsideImage() {
        let drawSize = CGSize(width: 400, height: 400)
        let cropDiameter: CGFloat = 280
        let clamped = ProfilePhotoCropRenderer.clampedOffset(
            CGSize(width: 500, height: -500),
            drawSize: drawSize,
            cropDiameter: cropDiameter
        )
        #expect(clamped.width == 60)
        #expect(clamped.height == -60)
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

    @Test func userProfileStore_sanitizedDanInsuranceNumber_trimsAndFilters() {
        #expect(UserProfileStore.sanitizedDanInsuranceNumber("") == nil)
        #expect(UserProfileStore.sanitizedDanInsuranceNumber("   ") == nil)
        #expect(UserProfileStore.sanitizedDanInsuranceNumber("  US-12345  ") == "US-12345")
        #expect(UserProfileStore.sanitizedDanInsuranceNumber("AB#12!") == "AB12")
    }

    @Test @MainActor
    func userProfile_persistsDanInsuranceNumber() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let profile = UserProfile(appleUserIdentifier: "apple-dan", displayName: "Diver")
        context.insert(profile)
        try context.save()

        profile.danInsuranceNumber = UserProfileStore.sanitizedDanInsuranceNumber("1234567")
        try context.save()

        let fetched = try UserProfileStore.profile(id: profile.id, modelContext: context)
        let stored = try #require(fetched)
        #expect(stored.danInsuranceNumber == "1234567")

        profile.danInsuranceNumber = nil
        try context.save()
        let cleared = try UserProfileStore.profile(id: profile.id, modelContext: context)
        #expect(cleared?.danInsuranceNumber == nil)
    }

    @Test @MainActor
    func appOnboardingPermissions_newAccountDetectedBeforeProfileInsert() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let appleID = "onboarding-permissions-new-user"

        #expect(try UserProfileStore.profile(appleUserIdentifier: appleID, modelContext: context) == nil)
        _ = try UserProfileStore.findOrCreateProfile(
            appleUserIdentifier: appleID,
            displayName: "Sam",
            modelContext: context
        )
        #expect(try UserProfileStore.profile(appleUserIdentifier: appleID, modelContext: context) != nil)
    }

    @Test func appNewAccountWelcomePresentation_shouldPresentWelcome_onlyForNewNonUITestAccounts() {
        #expect(AppNewAccountWelcomePresentation.shouldPresentWelcome(forNewAccount: true))
        #expect(!AppNewAccountWelcomePresentation.shouldPresentWelcome(forNewAccount: false))
    }

    @Test func appNewAccountWelcomePresentation_welcomeTitle_usesDisplayNameWhenSet() {
        #expect(
            AppNewAccountWelcomePresentation.welcomeTitle(displayName: "Casey")
                == "Welcome, Casey"
        )
        #expect(
            AppNewAccountWelcomePresentation.welcomeTitle(displayName: UserProfileStore.defaultDisplayName)
                == "Welcome to GoDive"
        )
        #expect(
            AppNewAccountWelcomePresentation.welcomeTitle(displayName: nil)
                == "Welcome to GoDive"
        )
    }

    @Test @MainActor
    func accountSession_completeNewAccountWelcome_isNoOpWhenNotShowingWelcome() {
        let session = AccountSession.shared
        session.signOut()
        #expect(!session.showsNewAccountWelcome)
        session.completeNewAccountWelcome()
        #expect(!session.showsNewAccountWelcome)
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
            cardType: .certification,
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
        #expect(card.cardType == .certification)
        #expect(card.certFrontPicture == frontBytes)
        #expect(card.certBackPicture == backBytes)
        #expect(card.ownerProfileID == owner.id)
        #expect(owner.certifications.count == 1)
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
        form.cardType = .specialty
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
        #expect(cert.cardType == .specialty)
        #expect(cert.certFrontPicture == Data([0x01]))
        #expect(cert.certBackPicture == Data([0x02]))
    }

    @Test func certificationFormValues_apply_updatesExistingCertification() {
        let cert = Certification(agency: "Old", certNumber: "1", cardType: .certification)
        var form = CertificationFormValues()
        form.agency = "SSI"
        form.certName = "Divemaster"
        form.certNumber = "DM-2"
        form.diveShop = ""
        form.cardType = .specialty
        form.apply(to: cert)
        #expect(cert.agency == "SSI")
        #expect(cert.certName == "Divemaster")
        #expect(cert.certNumber == "DM-2")
        #expect(cert.diveShop == nil)
        #expect(cert.cardType == .specialty)
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
            cardType: .certification,
            certFrontPicture: Data([0xAA])
        )
        let form = CertificationFormValues(from: cert)
        #expect(form.agency == "PADI")
        #expect(form.certName == "Open Water")
        #expect(form.certNumber == "OW-1")
        #expect(form.dateAttained == attained)
        #expect(form.instructor == "Alex")
        #expect(form.diveShop == "Blue Shop")
        #expect(form.cardType == .certification)
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

    @Test func certificationPresentation_profileFeaturedCertificationCard_returnsNewestCertificationType() {
        let older = Certification(
            agency: "PADI",
            certName: "Open Water",
            certNumber: "1",
            dateAttained: Date(timeIntervalSince1970: 1_000),
            cardType: .certification
        )
        let newer = Certification(
            agency: "PADI",
            certName: "Rescue Diver",
            certNumber: "2",
            dateAttained: Date(timeIntervalSince1970: 2_000),
            cardType: .certification
        )
        let featured = CertificationPresentation.profileFeaturedCertificationCard(from: [older, newer])
        #expect(featured?.certName == "Rescue Diver")
    }

    @Test func certificationPresentation_profileFeaturedCertificationCard_nilWhenOnlySpecialty() {
        let specialty = Certification(
            agency: "PADI",
            certName: "Enriched Air",
            certNumber: "1",
            cardType: .specialty
        )
        #expect(CertificationPresentation.profileFeaturedCertificationCard(from: [specialty]) == nil)
    }

    @Test func certificationPresentation_profileSubtitle_usesNewestCertificationTypeName() {
        let older = Certification(
            agency: "PADI",
            certName: "Open Water",
            certNumber: "1",
            dateAttained: Date(timeIntervalSince1970: 1_000),
            cardType: .certification
        )
        let newer = Certification(
            agency: "PADI",
            certName: "Rescue Diver",
            certNumber: "2",
            dateAttained: Date(timeIntervalSince1970: 2_000),
            cardType: .certification
        )
        let subtitle = CertificationPresentation.profileCertificationSubtitle(from: [older, newer])
        #expect(subtitle == "Rescue Diver")
    }

    @Test func certificationPresentation_profileSubtitle_ignoresNewerSpecialty() {
        let olderCert = Certification(
            agency: "PADI",
            certName: "Open Water",
            certNumber: "1",
            dateAttained: Date(timeIntervalSince1970: 1_000),
            cardType: .certification
        )
        let newerSpecialty = Certification(
            agency: "PADI",
            certName: "Enriched Air",
            certNumber: "2",
            dateAttained: Date(timeIntervalSince1970: 2_000),
            cardType: .specialty
        )
        let subtitle = CertificationPresentation.profileCertificationSubtitle(
            from: [olderCert, newerSpecialty]
        )
        #expect(subtitle == "Open Water")
    }

    @Test func certificationPresentation_profileSubtitle_defaultsWithoutCertificationType() {
        let cert = Certification(
            agency: "PADI",
            certName: "Wreck Diver",
            certNumber: "1",
            dateAttained: .now,
            cardType: .specialty
        )
        #expect(CertificationPresentation.profileCertificationSubtitle(from: [cert]) == "GoDive User")
    }

    @Test func certificationPresentation_profileFeatured_includesCertNumberUnderName() {
        let cert = Certification(
            agency: "PADI",
            certName: "Rescue Diver",
            certNumber: "  RD-991  ",
            dateAttained: .now,
            cardType: .certification
        )
        let display = CertificationPresentation.profileFeaturedCertification(from: [cert])
        #expect(display.title == "Rescue Diver")
        #expect(display.certNumber == "RD-991")
    }

    @Test func certificationPresentation_profileFeatured_omitsNumberWhenNameMissing() {
        let cert = Certification(
            agency: "PADI",
            certNumber: "RD-991",
            dateAttained: .now,
            cardType: .certification
        )
        let display = CertificationPresentation.profileFeaturedCertification(from: [cert])
        #expect(display.title == "PADI · RD-991")
        #expect(display.certNumber == nil)
    }

    @Test func certificationPresentation_profileFeatured_omitsNumberWhenEmpty() {
        let cert = Certification(
            agency: "PADI",
            certName: "Rescue Diver",
            certNumber: "   ",
            dateAttained: .now,
            cardType: .certification
        )
        let display = CertificationPresentation.profileFeaturedCertification(from: [cert])
        #expect(display.title == "Rescue Diver")
        #expect(display.certNumber == nil)
    }

    @Test func certificationPresentation_typeBadgeStyle_differsByCardType() {
        let certification = CertificationPresentation.typeBadgeStyle(for: .certification)
        let specialty = CertificationPresentation.typeBadgeStyle(for: .specialty)
        #expect(certification.label == "Certification")
        #expect(specialty.label == "Specialty")
        #expect(certification.foreground != specialty.foreground)
        #expect(certification.background != specialty.background)
    }

    @Test func certificationPresentation_detailHeaderName_prefersCertName() {
        let cert = Certification(agency: "PADI", certName: "Rescue Diver", certNumber: "99")
        #expect(CertificationPresentation.detailHeaderName(for: cert) == "Rescue Diver")
    }

    @Test func certificationPresentation_detailHeaderName_fallsBackToTitle() {
        let cert = Certification(agency: "PADI", certNumber: "99")
        #expect(CertificationPresentation.detailHeaderName(for: cert) == "PADI · 99")
    }

    @Test func certificationPresentation_sortedForList_newestDateAttainedFirst() {
        let older = Certification(
            agency: "PADI",
            certName: "Open Water",
            certNumber: "1",
            dateAttained: Date(timeIntervalSince1970: 1_000),
            cardType: .certification
        )
        let newer = Certification(
            agency: "NAUI",
            certName: "Rescue Diver",
            certNumber: "2",
            dateAttained: Date(timeIntervalSince1970: 2_000),
            cardType: .specialty
        )
        let sorted = CertificationPresentation.sortedForList([older, newer])
        #expect(sorted.map(\.certName) == ["Rescue Diver", "Open Water"])
    }

    @Test func appUserSettings_automaticallyRenumberDivesKey_matchesAppStorage() {
        #expect(AppUserSettings.automaticallyRenumberDivesKey == "goDiveAutomaticallyRenumberDives")
    }

    @Test func appUserSettings_useImperialDisplayUnitsKey_matchesAppStorage() {
        #expect(AppUserSettings.useImperialDisplayUnitsKey == "goDiveUseImperialDisplayUnits")
    }

    @Test func settingsPresentation_exposesSettingTitlesAndInfoCopy() {
        #expect(SettingsPresentation.ImperialUnits.title == "Imperial units")
        #expect(SettingsPresentation.ImperialUnits.infoMessage.contains("feet"))
        #expect(SettingsPresentation.DefaultTank.title == "Default tank")
        #expect(SettingsPresentation.AutomaticallyRenumberDives.title == "Automatically renumber dives")
        #expect(
            SettingsPresentation.infoAccessibilityLabel(forSettingTitle: "Imperial units")
                == "More information about Imperial units"
        )
        #expect(SettingsPresentation.BulkUddfImport.attachMediaTitle == "Attach photos from library")
        #expect(SettingsPresentation.BulkUddfImport.attachMediaSubtitle.contains("few minutes"))
    }

    @Test func macDiveUddfImportPresentation_steps_endOnImportButtonPage() {
        #expect(MacDiveUddfImportPresentation.stepCount == 6)
        #expect(MacDiveUddfImportPresentation.importButtonTitle == "Import MacDive Data")
        #expect(MacDiveUddfImportPresentation.importButtonStepIndex() == 5)
        #expect(MacDiveUddfImportPresentation.step(at: 5)?.showsImportButton == true)
        #expect(MacDiveUddfImportPresentation.step(at: 0)?.showsImportButton == false)
        #expect(MacDiveUddfImportPresentation.isLastStep(index: 5))
        #expect(!MacDiveUddfImportPresentation.isLastStep(index: 0))
        #expect(MacDiveUddfImportPresentation.clampedStepIndex(99) == 5)
        #expect(MacDiveUddfImportPresentation.step(at: 0)?.screenshotAssetName == "MacDiveImportStep01")
        #expect(MacDiveUddfImportPresentation.step(at: 0)?.title == "Select your dive group")
        #expect(MacDiveUddfImportPresentation.step(at: 1)?.title == "Open dive list settings")
        #expect(MacDiveUddfImportPresentation.step(at: 2)?.title == "Export to UDDF")
        #expect(MacDiveUddfImportPresentation.step(at: 3)?.title == "Save to iCloud")
        #expect(MacDiveUddfImportPresentation.step(at: 4)?.title == "Save on your iPhone")
        #expect(
            MacDiveUddfImportPresentation.step(at: 5)?.detail
                == "Tap Import MacDive Data below and choose the UDDF file you just created and saved."
        )
        #expect(MacDiveUddfImportPresentation.Layout.screenshotMaxHeight == 600)
        #expect(ActivityUploadRoute.fitImportOptions != ActivityUploadRoute.uddfImportOptions)
        #expect(ActivityUploadRoute.macDiveImportGuide == ActivityUploadRoute.macDiveImportGuide)
    }

    @Test func diveFileImportOptionsPresentation_copyForFitAndUddf() {
        #expect(DiveFileImportOptionsPresentation.pageTitle(for: .fit) == "Garmin FIT import")
        #expect(DiveFileImportOptionsPresentation.pageTitle(for: .uddf) == "UDDF import")
        #expect(DiveFileImportOptionsPresentation.chooseFileTitle(for: .fit) == "Choose FIT file")
        #expect(DiveFileImportOptionsPresentation.chooseFileTitle(for: .uddf) == "Choose UDDF file")
        #expect(DiveFileImportOptionsPresentation.accessibilityPrefix(for: .fit) == "ActivityUpload.FitImport")
        #expect(DiveFileImportOptionsPresentation.accessibilityPrefix(for: .uddf) == "ActivityUpload.BulkUddf")
    }

    @Test func appScrollUnderHeaderListLayout_usesLogbookHorizontalInsets() {
        #expect(AppScrollUnderHeaderListLayout.horizontalListRowInset == AppTheme.Spacing.lg)
        #expect(AppScrollUnderHeaderListLayout.listRowSpacing == AppTheme.Spacing.md)
    }

    @Test func appScrollUnderHeaderListLayout_listTopInset_matchesLogbookFormula() {
        #expect(
            AppScrollUnderHeaderListLayout.listTopInset(safeAreaTop: 59, headerClearance: 72) == 131
        )
        #expect(
            AppScrollUnderHeaderListLayout.listBottomInset(safeAreaBottom: 34) == 34 + AppTheme.Spacing.md
        )
        #expect(AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(59) == 59)
    }

    @Test func secondaryDestinationBackButton_defaultTapDimensionIsFortyFourPoints() {
        #expect(SecondaryDestinationChromeMetrics.backButtonMinimumTapDimension == 44)
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
            source: .manual,
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
            source: .manual,
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
            DiveBuddy.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let dive = DiveActivity(
            source: .manual,
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
            source: .manual,
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

    @Test func diveDepthProfileSeries_sortedOverloads_matchDefaultBuilders() {
        let t0 = Date(timeIntervalSince1970: 4_000_000)
        let points = [
            DiveProfilePoint(timestamp: t0.addingTimeInterval(600), depthMeters: 20, tankPressurePSI: 2400),
            DiveProfilePoint(timestamp: t0, depthMeters: 3, tankPressurePSI: 3000),
            DiveProfilePoint(timestamp: t0.addingTimeInterval(300), depthMeters: 12, tankPressurePSI: nil),
        ]
        let sorted = points.sorted { $0.timestamp < $1.timestamp }

        #expect(
            DiveDepthProfileSeries.samples(fromProfilePoints: points)
                == DiveDepthProfileSeries.samples(fromSortedProfilePoints: sorted)
        )
        #expect(
            DiveDepthProfileSeries.pressureSamples(fromProfilePoints: points)
                == DiveDepthProfileSeries.pressureSamples(fromSortedProfilePoints: sorted)
        )
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
            bottomContentMargin: bottomMargin,
            isLandscape: false
        )
        #expect(frame.width > 200)
        #expect(abs(frame.midX - layoutSize.width / 2) < 1)
        #expect(frame.minY > topObstruction)
        #expect(frame.maxY < layoutHeight - bottomMargin)
    }

    @Test func diveTankOverviewHeroPresentation_landscapeMinimizedProfileChart_isFullWidth() {
        let layoutSize = CGSize(width: 844, height: 390)
        let layoutHeight: CGFloat = 390
        let topObstruction: CGFloat = 60
        let bottomMargin: CGFloat = 120
        #expect(DiveTankOverviewHeroPresentation.isLandscapeLayout(layoutSize: layoutSize))
        let frame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: bottomMargin,
            isLandscape: true
        )
        let expectedWidth =
            layoutSize.width - DiveTankOverviewHeroPresentation.minimizedLandscapeChartHorizontalInset * 2
        #expect(abs(frame.width - expectedWidth) < 1)
        #expect(abs(frame.midX - layoutSize.width / 2) < 1)
    }

    @Test func diveDepthProfileChartViewport_zoomAndPan_clampsToFullDive() {
        var viewport = DiveDepthProfileChartViewport.full(elapsedMax: 600)
        #expect(!viewport.isZoomed(fullElapsedMax: 600))

        viewport.zoom(scale: 2, anchorFraction: 0.5, fullElapsedMax: 600)
        #expect(viewport.isZoomed(fullElapsedMax: 600))
        #expect(viewport.elapsedSpan < 600)
        #expect(viewport.elapsedStart >= 0)
        #expect(viewport.elapsedEnd <= 600)

        viewport.pan(elapsedDelta: 400, fullElapsedMax: 600)
        #expect(viewport.elapsedEnd <= 600 + 0.001)
        #expect(viewport.elapsedStart >= 0)

        viewport.reset(fullElapsedMax: 600)
        #expect(!viewport.isZoomed(fullElapsedMax: 600))
        #expect(abs(viewport.elapsedEnd - 600) < 0.001)
    }

    @Test func diveDepthProfileOverlayChartLayout_depthPoint_respectsViewportWindow() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let viewport = DiveDepthProfileChartViewport(elapsedStart: 100, elapsedEnd: 300)
        let sample = DiveDepthProfileSample(elapsedSeconds: 200, depthMeters: 10)
        let point = DiveDepthProfileOverlayChartLayout.depthPoint(
            sample: sample,
            in: rect,
            viewport: viewport,
            maxDepth: 20
        )
        #expect(abs(point.x - 100) < 0.5)
        #expect(abs(point.y - 50) < 0.5)
    }

    @Test func diveTankOverviewHeroPresentation_landscapeMinimized_hidesGasSummaryAndShowsMediaMarkers() {
        #expect(
            !DiveTankOverviewHeroPresentation.showsMinimizedTankGasSummary(
                for: .minimized,
                isLandscape: true,
                startPSI: 3000,
                endPSI: 1200
            )
        )
        #expect(
            DiveTankOverviewHeroPresentation.showsMinimizedTankGasSummary(
                for: .minimized,
                isLandscape: false,
                startPSI: 3000,
                endPSI: 1200
            )
        )
        #expect(
            !DiveTankOverviewHeroPresentation.showsMinimizedCylinder(for: .minimized, isLandscape: true)
        )
        #expect(DiveTankOverviewHeroPresentation.showsMediaMarkersOnLandscapeProfile(isLandscape: true))
        #expect(!DiveTankOverviewHeroPresentation.showsMediaMarkersOnLandscapeProfile(isLandscape: false))
    }

    @Test func diveTankOverviewHeroPresentation_landscapeChartChromeCommitDelay_isPositive() {
        #expect(DiveTankOverviewHeroPresentation.landscapeChartChromeCommitDelay > .zero)
    }

    @Test func diveActivityOverviewLandscapePresentation_hidesSheetAndUnlocksMapAtEveryDetent() {
        #expect(DiveActivityOverviewLandscapePresentation.hidesOverviewPanel(isLandscape: true))
        #expect(!DiveActivityOverviewLandscapePresentation.hidesOverviewPanel(isLandscape: false))
        #expect(
            DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                isLandscape: true,
                detentAllowsInteraction: false
            )
        )
        #expect(
            !DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                isLandscape: false,
                detentAllowsInteraction: false
            )
        )
        #expect(
            DiveActivityOverviewLandscapePresentation.allowsMapInteraction(
                isLandscape: false,
                detentAllowsInteraction: true
            )
        )
    }

    @Test func appPortraitOrientationLockPolicy_listScreensStayPortrait() {
        let sampleID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        let mediaID = UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!

        #expect(AppPortraitOrientationLockPolicy.locksHome(path: []))
        #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.profile]))
        #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.tripPlanner]))
        #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.tripDetail(sampleID)]))
        #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.diveSite(sampleID)]))
        #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.marineLife("species-uuid")]))
        #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.diveBuddy(sampleID)]))
        #expect(!AppPortraitOrientationLockPolicy.locksHome(path: [.diveDetail(sampleID)]))
        #expect(!AppPortraitOrientationLockPolicy.locksHome(path: [.diveMedia(diveID: sampleID, mediaID: mediaID)]))

        #expect(AppPortraitOrientationLockPolicy.locksLogbook(path: []))
        #expect(AppPortraitOrientationLockPolicy.locksLogbook(path: [.tripDetail(sampleID)]))
        #expect(AppPortraitOrientationLockPolicy.locksLogbook(path: [.tripPlanner]))
        #expect(AppPortraitOrientationLockPolicy.locksLogbook(path: [.diveSite(sampleID)]))
        #expect(!AppPortraitOrientationLockPolicy.locksLogbook(path: [.diveDetail(sampleID)]))
        #expect(!AppPortraitOrientationLockPolicy.locksLogbook(path: [.diveMedia(sampleID, mediaID: mediaID)]))

        #expect(AppPortraitOrientationLockPolicy.locksFieldGuide(isShowingDiveDetail: false))
        #expect(!AppPortraitOrientationLockPolicy.locksFieldGuide(isShowingDiveDetail: true))

        #expect(AppPortraitOrientationLockPolicy.locksExplore(path: []))
        #expect(AppPortraitOrientationLockPolicy.locksExplore(path: [.siteDetail(sampleID)]))
        #expect(AppPortraitOrientationLockPolicy.locksExplore(path: [.speciesDetail("species-uuid")]))
        #expect(AppPortraitOrientationLockPolicy.locksExplore(path: [.tripPlanner]))
        #expect(!AppPortraitOrientationLockPolicy.locksExplore(path: [.diveDetail(sampleID)]))

        #expect(AppPortraitOrientationLockPolicy.locksTripDetail(showingLinkedDiveDetail: false))
        #expect(!AppPortraitOrientationLockPolicy.locksTripDetail(showingLinkedDiveDetail: true))

        #expect(
            AppPortraitOrientationLockPolicy.supportedInterfaceOrientations(landscapeUnlockCount: 0) == .portrait
        )
        #expect(
            AppPortraitOrientationLockPolicy.supportedInterfaceOrientations(landscapeUnlockCount: 1)
                == [.portrait, .landscapeLeft, .landscapeRight]
        )
    }

    @Test func diveTankOverviewHeroPresentation_landscapeProfileChart_atEveryDetent() {
        for detent in [DiveActivityOverviewDetent.minimized, .medium, .large] {
            #expect(
                DiveTankOverviewHeroPresentation.showsProfileChart(
                    for: detent,
                    depthSampleCount: 4,
                    isLandscape: true
                )
            )
            #expect(
                !DiveTankOverviewHeroPresentation.showsTankCylinderHero(
                    for: detent,
                    isLandscape: true
                )
            )
        }
        #expect(
            DiveTankOverviewHeroPresentation.showsProfileChart(
                for: .medium,
                depthSampleCount: 4,
                isLandscape: false
            ) == false
        )
    }

    @Test func diveTankOverviewHeroPresentation_landscapeMinimized_hidesSheetAndShowsRotateHintInPortrait() {
        #expect(
            DiveTankOverviewHeroPresentation.showsRotatePhoneHint(
                for: .minimized,
                isLandscape: false,
                depthSampleCount: 4
            )
        )
        #expect(
            !DiveTankOverviewHeroPresentation.showsRotatePhoneHint(
                for: .minimized,
                isLandscape: true,
                depthSampleCount: 4
            )
        )
        let layoutHeight: CGFloat = 844
        let bottomSafe: CGFloat = 34
        let withSheet = DiveActivityOverviewDetent.bottomObstructionHeight(
            layoutHeight: layoutHeight,
            detent: .minimized,
            bottomSafeInset: bottomSafe
        )
        let withoutSheet = DiveTankOverviewHeroPresentation.tankHeroBottomContentMargin(
            layoutHeight: layoutHeight,
            detent: .minimized,
            bottomSafeInset: bottomSafe,
            isLandscape: true
        )
        #expect(withoutSheet < withSheet)
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
            source: .garminMK3,
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
        #expect(activity.diveSite?.siteName == "Salt Pier")
        #expect(activity.diveSiteID == saltPier.id)
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
        #expect(activity.diveSite == nil)
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
        #expect(activity.diveSite?.siteName == "Salt Pier")
        #expect(activity.diveSite?.latCoords == 12.08316)
        #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 2)
    }

    @Test func diveSiteCatalogMatcher_nameAndCoordinateMatch() {
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
        let match = DiveSiteCatalogMatcher.bestReferenceMatch(
            importName: "Salt Pier",
            importCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833),
            reference: [reference]
        )
        #expect(match?.snapshot.id == "salt01")
        #expect((match?.score ?? 0) >= DiveSiteCatalogMatcher.autoLinkThreshold)
    }

    @Test func diveSiteCatalogMatcher_linksExistingTaggedCatalogSite() {
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
            seaName: ""
        )
        let taggedSite = DiveSite(
            siteName: "Salt Pier (OpenDiveMap)",
            latCoords: 12.0835,
            longCoords: -68.283,
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")]
        )
        let activity = DiveActivity(
            source: .macDive,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            siteName: "Salt Pier",
            entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
        )
        let linked = DiveActivitySiteAssociation.applyOpenDiveMapReferenceLinkIfNeeded(
            to: activity,
            catalogSites: [taggedSite],
            reference: [reference]
        )
        #expect(linked)
        #expect(activity.diveSite?.id == taggedSite.id)
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
        #expect(activity.diveSite?.siteName == "Salt Pier")
        #expect(activity.diveSite?.country == "Caribbean Netherlands")
        #expect(activity.diveSite?.latCoords == 12.0835)
        #expect(activity.diveSite?.siteTags.contains(DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")) == true)
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
        #expect(activity.diveSite?.id == localOnlySite.id)
        #expect(localOnlySite.siteTags.contains(where: { $0.hasPrefix(DiveSiteCatalogMatcher.openDiveMapTagPrefix) }))
        #expect(result.enrichedSiteCount == 1)
    }

    @Test func diveSiteCatalogMatcher_makeDiveSite_trimsReferenceName() {
        let reference = DiveSiteReferenceSnapshot(
            id: "waikato",
            name: "\nGet Wet Waikato",
            country: "New Zealand",
            countryCode: "NZ",
            latitude: -37.7623,
            longitude: 175.2498,
            maxDepthMeters: 8,
            entry: "boat",
            environment: "ocean",
            topologies: [],
            seaName: ""
        )
        let site = DiveSiteCatalogMatcher.makeDiveSite(from: reference)
        #expect(site.siteName == "Get Wet Waikato")
    }

    @Test func diveSiteCatalogMatcher_resolvedCatalogSiteName_fallsBackToReferenceName() {
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
            seaName: ""
        )
        let site = DiveSite(
            siteName: "   ",
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")]
        )
        #expect(
            DiveSiteCatalogMatcher.resolvedCatalogSiteName(for: site, reference: [reference]) == "Salt Pier"
        )
    }

    @Test @MainActor
    func diveSiteCatalogMatcher_normalizeCatalogSiteNameIfNeeded_trimsStoredTitle() throws {
        let site = DiveSite(
            siteName: "  Salt Pier  ",
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")]
        )
        let changed = DiveSiteCatalogMatcher.normalizeCatalogSiteNameIfNeeded(site, reference: [])
        #expect(changed)
        #expect(site.siteName == "Salt Pier")
    }

    @Test @MainActor
    func diveSiteCatalogMatcher_normalizeCatalogSiteNameIfNeeded_backfillsFromReference() {
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
            seaName: ""
        )
        let site = DiveSite(
            siteName: "",
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")]
        )
        let changed = DiveSiteCatalogMatcher.normalizeCatalogSiteNameIfNeeded(site, reference: [reference])
        #expect(changed)
        #expect(site.siteName == "Salt Pier")
    }

    @Test @MainActor
    func fitDiveFileImport_persistImportedActivity_createMissingDiveSitesFalse_stillLinksOpenDiveMapMatch() async throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "apple-fit-opendive", displayName: "Owner")
        context.insert(owner)
        try context.save()

        let activity = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            timeZoneOffsetSeconds: 0,
            durationMinutes: 30,
            maxDepthMeters: 18,
            siteName: "Salt Pier",
            entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
        )

        let outcome = await FitDiveFileImport.persistImportedActivity(
            activity,
            modelContext: context,
            owner: owner,
            attachMedia: false,
            createMissingDiveSites: false
        )

        #expect(outcome.didSucceed)
        #expect(activity.diveSite != nil)
        #expect(activity.diveSite?.siteTags.contains(where: { $0.hasPrefix(DiveSiteCatalogMatcher.openDiveMapTagPrefix) }) == true)
    }

    @Test func diveActivityMapSitePrompt_isEligibleWhenUnlinkedWithEntryOrName() {
        let withGPS = DiveActivity(
            source: .garminMK3,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            entryCoordinate: DiveCoordinate(latitude: 12, longitude: -68)
        )
        #expect(DiveActivityMapSitePrompt.isEligible(for: withGPS))

        let withName = DiveActivity(
            source: .macDive,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 10,
            siteName: "Salt Pier"
        )
        #expect(DiveActivityMapSitePrompt.isEligible(for: withName))

        let linked = DiveActivity(
            source: .manual,
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

    @Test func diveSiteCoordinatePickerPresentation_approximateZoomLevel_matchesPickerSpan() {
        let center = DiveCoordinate(latitude: 12.083, longitude: -68.283)
        let zoom = DiveSiteCoordinatePickerPresentation.approximateZoomLevel(for: center)
        let reference = DiveLocationMapGoogleCameraPresentation.approximateZoomLevel(
            atLatitude: center.latitude,
            viewingDistanceMeters: DiveSiteCoordinatePickerPresentation.pickerRegionViewingDistanceMeters
        )
        #expect(zoom == reference)
        #expect(zoom > 10)
    }

    @Test func diveActivityMapSitePrompt_showsInfoButtonOnlyAfterDecline() {
        let activity = DiveActivity(
            source: .garminMK3,
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

        #expect(activity.diveSite?.id == site.id)
        #expect(activity.diveSiteID == site.id)
        #expect(activity.siteCoordinate?.latitude == 12.05)
        #expect(site.country == "Caribbean Netherlands")
        #expect(site.region == "Bonaire")
        #expect(site.bodyOfWater == "Caribbean Sea")
        #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 1)
    }

    @Test func diveSiteMapper_mapsOptionalPlaceFields() {
        let dto = DiveSiteDTO(
            id: nil,
            siteName: "Test Reef",
            country: "Mexico",
            region: nil,
            bodyOfWater: "Gulf of California",
            latCoords: 24.0,
            longCoords: -110.0,
            siteTags: nil,
            siteRating: nil
        )
        let site = DiveSiteMapper.map(dto)
        #expect(site.country == "Mexico")
        #expect(site.region == "")
        #expect(site.bodyOfWater == "Gulf of California")
    }

    @Test func marineLifeMapper_mapsSnakeCaseDTO() {
        let dto = MarineLifeDTO(
            uuid: "marine-life-test-turtle",
            commonName: "Green Sea Turtle",
            featureImage: "https://example.com/turtle.jpg",
            scientificName: "Chelonia mydas",
            category: "marine_reptiles",
            subcategory: "turtles",
            description: "Herbivorous sea turtle.",
            minSize: 0.5,
            maxSize: 1.1,
            avgDepth: 10
        )
        let species = MarineLifeMapper.map(dto)
        #expect(species.uuid == "marine-life-test-turtle")
        #expect(species.commonName == "Green Sea Turtle")
        #expect(species.featureImageURL == "https://example.com/turtle.jpg")
        #expect(species.category == "marine_reptiles")
        #expect(species.subcategory == "turtles")
        #expect(species.aboutText == "Herbivorous sea turtle.")
        #expect(species.minSizeMeters == 0.5)
        #expect(species.avgDepthMeters == 10)
    }

    @Test func marineLifeMapper_mapsQueenAngelfishExtendedCatalogFields() {
        let dto = MarineLifeDTO(
            uuid: "marine-life-queen-angelfish",
            commonName: "Queen Angelfish",
            featureImage: nil,
            scientificName: "Holacanthus ciliaris",
            category: "Fish",
            subcategory: "Disk and Large Oval",
            familyName: "Angelfishes",
            description: "Oval-bodied angelfish.",
            minSize: 0.2,
            maxSize: 0.36,
            minDepth: 6,
            maxDepth: 25,
            avgDepth: nil,
            distinctiveFeatures: "Blue with yellow rims on scales.",
            abundance: "Common in Florida, Bahamas, Gulf of Mexico, Bermuda.",
            habitatBehavior: "Swim slowly near corals.",
            diverReaction: "Wary, tend to keep their distance."
        )
        let species = MarineLifeMapper.map(dto)
        #expect(species.commonName == "Queen Angelfish")
        #expect(species.category == "fish")
        #expect(species.subcategory == "disk-and-large-oval")
        #expect(species.familyName == "Angelfishes")
        #expect(species.minDepthMeters == 6)
        #expect(species.maxDepthMeters == 25)
        #expect(species.avgDepthMeters == 15.5)
        #expect(species.distinctiveFeatures == "Blue with yellow rims on scales.")
        #expect(species.diverReaction == "Wary, tend to keep their distance.")
    }

    @Test func marineLifeMapper_mapsFeatureModelResourceName() {
        let dto = MarineLifeDTO(
            uuid: "marine-life-french-angelfish",
            commonName: "French Angelfish",
            featureModel: "FrenchAngelfish",
            scientificName: "Pomacanthus paru"
        )
        let species = MarineLifeMapper.map(dto)
        #expect(species.featureModelResourceName == "FrenchAngelfish")
    }

    @Test func fieldGuideMarineLifeHeroPresentation_prefersModelOverRemoteImage() {
        let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
            featureModelResourceName: "FrenchAngelfish",
            featureImageResourceName: "marine-life-french-angelfish",
            featureImageURL: "https://example.com/fish.jpg"
        )
        #expect(kind == .model3D(.frenchAngelfish))
    }

    @Test func fieldGuideMarineLifeHeroPresentation_caribbeanReefSquidUsesBundledModel() {
        let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
            featureModelResourceName: "CaribbeanReefSquid",
            featureImageResourceName: "",
            featureImageURL: ""
        )
        guard case .model3D(let config) = kind else {
            Issue.record("Expected 3D model hero")
            return
        }
        #expect(config.modelResourceName == "CaribbeanReefSquid")
    }

    @Test func fieldGuideMarineLifeHeroPresentation_greenSeaTurtleUsesBundledModel() {
        let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
            featureModelResourceName: "GreenSeaTurtle",
            featureImageResourceName: "",
            featureImageURL: ""
        )
        guard case .model3D(let config) = kind else {
            Issue.record("Expected 3D model hero")
            return
        }
        #expect(config.modelResourceName == "GreenSeaTurtle")
    }

    @Test func fieldGuideMarineLifeHeroPresentation_spottedEagleRayUsesBundledModel() {
        let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
            featureModelResourceName: "SpottedEagleRay",
            featureImageResourceName: "",
            featureImageURL: ""
        )
        guard case .model3D(let config) = kind else {
            Issue.record("Expected 3D model hero")
            return
        }
        #expect(config.modelResourceName == "SpottedEagleRay")
    }

    @Test func fieldGuideMarineLifeHeroPresentation_remoteImageWhenNoModel() {
        let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
            featureModelResourceName: "",
            featureImageResourceName: "",
            featureImageURL: "https://example.com/fish.jpg"
        )
        guard case .remoteImage(let url) = kind else {
            Issue.record("Expected remote image hero")
            return
        }
        #expect(url.absoluteString == "https://example.com/fish.jpg")
    }

    @Test func fieldGuideMarineLifeHeroPresentation_placeholderWhenEmpty() {
        let kind = FieldGuideMarineLifeHeroPresentation.heroKind(
            featureModelResourceName: "",
            featureImageResourceName: "",
            featureImageURL: ""
        )
        #expect(kind == .placeholder)
    }

    @Test func fieldGuideMarineLifeBundledImagePresentation_prefersBundledResourceOverRemoteURL() {
        let source = FieldGuideMarineLifeBundledImagePresentation.imageSource(
            featureImageResourceName: "missing-resource",
            featureImageURL: "https://example.com/fish.jpg"
        )
        guard case .remote(let url) = source else {
            Issue.record("Expected remote fallback when bundled file is absent")
            return
        }
        #expect(url.absoluteString == "https://example.com/fish.jpg")
    }

    @Test func fieldGuideMarineLifeBundledImagePresentation_noneWhenEmpty() {
        let source = FieldGuideMarineLifeBundledImagePresentation.imageSource(
            featureImageResourceName: "",
            featureImageURL: ""
        )
        #expect(source == .none)
    }

    @Test func fieldGuideMarineLifeImageLayout_usesFixedMosaicAndHeroBounds() {
        #expect(FieldGuideMarineLifeImageLayout.mosaicAspectRatio == CGFloat(4.0 / 3.0))
        #expect(FieldGuideMarineLifeImageLayout.mosaicLabelBlockHeight == 88)
        #expect(FieldGuideMarineLifeImageLayout.detailHeroBaseHeight == 280)
    }

    @Test func fieldGuideSubcategorySearchPresentation_filtersByTitleOrHint() {
        let angelfishes = FieldGuideTaxonomy.Subcategory(
            id: "angelfishes",
            title: "Angelfishes",
            hint: "Species from Caribbean Reef Life — Angelfishes",
            systemImage: "fish"
        )
        let gobies = FieldGuideTaxonomy.Subcategory(
            id: "gobies",
            title: "Gobies",
            hint: "Species from Caribbean Reef Life — Gobies",
            systemImage: "fish"
        )

        #expect(
            FieldGuideSubcategorySearchPresentation.filtering([angelfishes, gobies], query: "angel")
                == [angelfishes]
        )
        #expect(
            FieldGuideSubcategorySearchPresentation.filtering([angelfishes, gobies], query: "Caribbean Gobies")
                == [gobies]
        )
        #expect(
            FieldGuideSubcategorySearchPresentation.showsAllSpeciesFallback(
                subcategories: [],
                speciesCount: 12,
                query: ""
            )
        )
        #expect(
            !FieldGuideSubcategorySearchPresentation.showsAllSpeciesFallback(
                subcategories: [],
                speciesCount: 12,
                query: "octopus"
            )
        )
    }

    @Test func fieldGuideSpeciesHeroPresentation_prefersTaggedVideoAndTogglesSource() {
        let photo = DiveMediaPhoto(sortOrder: 0, mediaKind: .image)
        let video = DiveMediaPhoto(sortOrder: 1, mediaKind: .video)
        #expect(
            FieldGuideSpeciesHeroPresentation.initialTaggedMediaPhotoID(from: [photo, video])
                == video.id
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.initialTaggedMediaPhotoID(from: [photo])
                == photo.id
        )
        #expect(FieldGuideSpeciesHeroPresentation.initialTaggedMediaPhotoID(from: []) == nil)

        #expect(
            FieldGuideSpeciesHeroPresentation.resolvedTaggedMedia(
                selectedID: photo.id,
                in: [photo, video]
            )?.id == photo.id
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.resolvedTaggedMedia(
                selectedID: nil,
                in: [photo, video]
            )?.id == video.id
        )

        #expect(FieldGuideSpeciesHeroPresentation.showsSourceToggle(hasTaggedMedia: true))
        #expect(!FieldGuideSpeciesHeroPresentation.showsSourceToggle(hasTaggedMedia: false))
        #expect(
            FieldGuideSpeciesHeroPresentation.defaultMediaSource(hasTaggedMedia: true)
                == .taggedUserMedia
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.defaultMediaSource(hasTaggedMedia: false)
                == .catalogReference
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.toggledSource(.taggedUserMedia)
                == .catalogReference
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.toggledSource(.catalogReference)
                == .taggedUserMedia
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.sourceToggleDiameter
                == DiveBuddyDetailPresentation.profileAvatarDiameter / 2
        )
        #expect(FieldGuideSpeciesHeroPresentation.sourceToggleDiameter == 60)

        let compact = FieldGuideSpeciesHeroPresentation.compactSceneConfiguration(
            for: .frenchAngelfish
        )
        #expect(!compact.allowsDragRotation)
        #expect(compact.modelResourceName == "FrenchAngelfish")
    }

    @Test func fieldGuideSpeciesHeroPresentation_catalogHeroDisplay_defaultsToImageAndToggles() {
        let both = FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
            featureModelResourceName: "FrenchAngelfish",
            featureImageResourceName: "marine-life-french-angelfish",
            featureImageURL: "https://example.com/fish.jpg"
        )
        #expect(both.hasModel3D)
        #expect(both.hasImage)
        #expect(both.supportsHeaderToggle)
        #expect(
            FieldGuideSpeciesHeroPresentation.defaultCatalogHeroDisplay(availability: both)
                == .image
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.resolvedCatalogHeroDisplay(
                selection: .model3D,
                availability: both
            ) == .model3D
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.toggledCatalogHeroDisplay(.image) == .model3D
        )
        #expect(
            FieldGuideSpeciesHeroPresentation.toggledCatalogHeroDisplay(.model3D) == .image
        )

        let modelOnly = FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
            featureModelResourceName: "FrenchAngelfish",
            featureImageResourceName: "",
            featureImageURL: ""
        )
        #expect(modelOnly.hasModel3D)
        #expect(!modelOnly.hasImage)
        #expect(!modelOnly.supportsHeaderToggle)
        #expect(
            FieldGuideSpeciesHeroPresentation.resolvedCatalogHeroDisplay(
                selection: .image,
                availability: modelOnly
            ) == .model3D
        )

        let imageOnly = FieldGuideSpeciesHeroPresentation.catalogHeroAvailability(
            featureModelResourceName: "",
            featureImageResourceName: "",
            featureImageURL: "https://example.com/fish.jpg"
        )
        #expect(!imageOnly.hasModel3D)
        #expect(imageOnly.hasImage)
        #expect(!imageOnly.supportsHeaderToggle)
        #expect(
            FieldGuideSpeciesHeroPresentation.resolvedCatalogHeroDisplay(
                selection: .model3D,
                availability: imageOnly
            ) == .image
        )
    }

    @Test func fieldGuideMarineLifeHeroPresentation_catalogImageKind_ignoresModelName() {
        let kind = FieldGuideMarineLifeHeroPresentation.catalogImageKind(
            featureImageResourceName: "",
            featureImageURL: "https://example.com/fish.jpg"
        )
        guard case .remoteImage(let url) = kind else {
            Issue.record("Expected remote catalog image")
            return
        }
        #expect(url.absoluteString == "https://example.com/fish.jpg")
        #expect(
            FieldGuideMarineLifeHeroPresentation.hasCatalogModel(
                featureModelResourceName: "FrenchAngelfish"
            )
        )
    }

    @Test @MainActor func fieldGuideMarineLifeDetailView_heroHeight_usesPushedLayoutMetrics() {
        let geometryHeight: CGFloat = 852
        let screenWidth: CGFloat = 390
        let topSafeAreaInset: CGFloat = 59
        let seamInputs = HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
        let transitionFloor = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(from: 803)

        let heroHeight = BlueSheetHeaderPageLayoutBuilder.heroHeight(
            geometryHeight: geometryHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: seamInputs.statsPanelContentHeight,
            showsBuddyLeaderboard: seamInputs.showsBuddyLeaderboard,
            transitionViewportFloor: transitionFloor
        )
        #expect(heroHeight > FieldGuideMarineLifeImageLayout.detailHeroBaseHeight)
    }

    @Test func blueSheetDetailPageConfiguration_standardDefaults() {
        let config = BlueSheetDetailPageConfiguration.standard(
            accessibilityRootIdentifier: "GoDive.TestDetail"
        )
        #expect(config.accessibilityRootIdentifier == "GoDive.TestDetail")
        #expect(config.presentation == .pushedDetail)
        #expect(config.showsHero)
        #expect(config.hidesTabBarWhenPushed)
    }

    @Test func blueSheetDetailPageConfiguration_tabRoot() {
        let config = BlueSheetDetailPageConfiguration.tabRoot(
            accessibilityRootIdentifier: "GoDive.Home"
        )
        #expect(config.presentation == .tabRoot)
        #expect(config.showsHero)
        #expect(!config.hidesTabBarWhenPushed)
    }

    @Test func blueSheetPagePresentation_pageLayoutKind() {
        #expect(BlueSheetPagePresentation.tabRoot.pageLayoutKind == .home)
        #expect(BlueSheetPagePresentation.pushedDetail.pageLayoutKind == .buddyDetail)
    }

    @Test func blueSheetPageProportions_reexportHomeOverviewLayoutTokens() {
        #expect(BlueSheetPageProportions.panelOverlap == HomeOverviewLayout.panelOverlap)
        #expect(BlueSheetPageProportions.blueSheetPanelScale == HomeOverviewLayout.blueSheetPanelScale)
        #expect(BlueSheetPageProportions.heroHeightToWidthRatio == HomeOverviewLayout.heroHeightToWidthRatio)
        #expect(BlueSheetPageProportions.heroBottomExtension == HomeOverviewLayout.heroBottomExtension)
        #expect(BlueSheetPageProportions.tabBarScrollInset == HomeOverviewLayout.tabBarScrollInset)
        #expect(BlueSheetPageProportions.rootTabBarLayoutHeight == HomeOverviewLayout.rootTabBarLayoutHeight)
    }

    @Test func homeOverviewLayout_blueSheetPanelScale_increasesOverlapAndHeroBleed() {
        #expect(abs(HomeOverviewLayout.blueSheetPanelScale - 1.10 * 1.15) < 0.001)
        #expect(HomeOverviewLayout.panelOverlap == 187)
        #expect(HomeOverviewLayout.heroBottomExtension == 202)
        #expect(HomeOverviewLayout.heroBottomExtension > HomeOverviewLayout.panelOverlap)
        let statsContent: CGFloat = 400
        let scaledBand = HomeOverviewLayout.minimumStatsBandHeight(statsPanelContentHeight: statsContent)
        #expect(scaledBand == (statsContent + HomeOverviewLayout.tabBarScrollInset) * HomeOverviewLayout.blueSheetPanelScale)
        #expect(scaledBand > statsContent + HomeOverviewLayout.tabBarScrollInset)
    }

    @Test func blueSheetPageLayoutBuilder_tabRootMatchesPushedHeroHeightWhenViewportAligned() {
        let pushedGeometryHeight: CGFloat = 852
        let homeTabViewportHeight = HomeOverviewLayout.viewportHeightMatchingHomeTab(
            from: pushedGeometryHeight
        )
        let screenWidth: CGFloat = 393
        let topSafeAreaInset: CGFloat = 59
        let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
            showsBuddyLeaderboard: false
        )

        let tabRootHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: homeTabViewportHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: topSafeAreaInset,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .tabRoot(isNavigationStackAtRoot: true, frozenRootViewportHeight: homeTabViewportHeight)
        )
        let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: pushedGeometryHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: topSafeAreaInset,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .pushedDetail(transitionViewportHeightFloor: 0)
        )
        #expect(tabRootHero == pushedHero)
    }

    @Test func homeOverviewLayout_settledHomeTabContentGeometryHeight_normalizesFullScreenPeek() {
        let tabContentHeight: CGFloat = 803
        let fullScreenHeight = tabContentHeight + HomeOverviewLayout.rootTabBarLayoutHeight
        #expect(
            HomeOverviewLayout.settledHomeTabContentGeometryHeight(from: fullScreenHeight)
                == tabContentHeight
        )
        #expect(
            HomeOverviewLayout.tabRootFullScreenGeometryHeight(from: tabContentHeight)
                == tabContentHeight
        )
        #expect(
            HomeOverviewLayout.tabRootVirtualFullScreenHeight(from: tabContentHeight)
                == fullScreenHeight
        )
    }

    @Test func blueSheetPageLayoutBuilder_tabRootHeroHeightMatchesPushedDetail() {
        let tabContentGeometryHeight: CGFloat = 803
        let pushedGeometryHeight = tabContentGeometryHeight + HomeOverviewLayout.rootTabBarLayoutHeight
        let screenWidth: CGFloat = 393
        let topSafeAreaInset: CGFloat = 59
        let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
            showsBuddyLeaderboard: false
        )

        let tabRootHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: tabContentGeometryHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: topSafeAreaInset,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .tabRoot(isNavigationStackAtRoot: true, frozenRootViewportHeight: nil)
        )
        let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: pushedGeometryHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: topSafeAreaInset,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .pushedDetail(transitionViewportHeightFloor: 0)
        )
        #expect(tabRootHero == pushedHero)
    }

    @Test func homeTabRootLayoutPresentation_stackMatchesDetailFullScreenHeight() {
        let tabContentGeometryHeight: CGFloat = 803
        let pushedGeometryHeight = tabContentGeometryHeight + HomeOverviewLayout.rootTabBarLayoutHeight
        let screenWidth: CGFloat = 393
        let topSafeAreaInset: CGFloat = 59
        let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
            showsBuddyLeaderboard: false
        )

        let tabRootStack = HomeTabRootLayoutPresentation.stackFrameHeight(
            from: tabContentGeometryHeight
        )
        let pushedStack = HomeOverviewLayout.pushedPageLayoutHeight(from: pushedGeometryHeight)
        #expect(tabRootStack == pushedStack)
        #expect(tabRootStack == pushedGeometryHeight)

        let tabRootHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: tabContentGeometryHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: topSafeAreaInset,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .tabRoot(isNavigationStackAtRoot: true, frozenRootViewportHeight: nil)
        )
        let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: pushedGeometryHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: topSafeAreaInset,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .pushedDetail(transitionViewportHeightFloor: 0)
        )
        #expect(tabRootHero == pushedHero)

        let homeScreenBot = HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .home,
            geometryHeight: tabContentGeometryHeight,
            heroHeight: tabRootHero
        )
        let detailScreenBot = HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .buddyDetail,
            geometryHeight: pushedGeometryHeight,
            heroHeight: pushedHero
        )
        #expect(homeScreenBot == detailScreenBot)
    }

    @Test func homeTabRootLayoutPresentation_zeroGeometrySafeTop_matchesDetailHeroHeight() {
        let tabContentGeometryHeight: CGFloat = 803
        let pushedGeometryHeight = tabContentGeometryHeight + HomeOverviewLayout.rootTabBarLayoutHeight
        let screenWidth: CGFloat = 393
        let resolvedTopSafeAreaInset: CGFloat = 59
        let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
            showsBuddyLeaderboard: false
        )

        let homeHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: tabContentGeometryHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: 0,
            layoutSafeAreaTopFloor: resolvedTopSafeAreaInset,
            seamInputs: seamInputs,
            mode: .tabRoot(isNavigationStackAtRoot: true, frozenRootViewportHeight: nil)
        )
        let detailHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: pushedGeometryHeight,
            screenWidth: screenWidth,
            rawGeometrySafeTop: 0,
            layoutSafeAreaTopFloor: resolvedTopSafeAreaInset,
            seamInputs: seamInputs,
            mode: .pushedDetail(transitionViewportHeightFloor: 0)
        )
        #expect(homeHero == detailHero)
        #expect(homeHero > HomeOverviewLayout.heroHeight(width: screenWidth, topSafeAreaInset: 0))
    }

    @Test func homeTabRootLayoutPresentation_panelBottomInsetPrefersMeasuredTabBar() {
        #expect(
            HomeTabRootLayoutPresentation.panelBottomSafeAreaInset(
                measuredTabBarClearance: 83,
                safeAreaBottom: 34
            ) == 83
        )
        #expect(
            HomeTabRootLayoutPresentation.panelBottomSafeAreaInset(
                measuredTabBarClearance: 0,
                safeAreaBottom: 34
            ) == RootTabBarLayoutMeasurement.estimatedClearanceAboveTabBar(safeAreaBottom: 34)
        )
    }

    @Test func rootTabBarLayoutMeasurement_estimatedClearanceAboveTabBar() {
        #expect(RootTabBarLayoutMeasurement.estimatedClearanceAboveTabBar(safeAreaBottom: 0) == 49)
        #expect(
            RootTabBarLayoutMeasurement.resolvedPanelBottomSafeAreaInset(
                measuredTabBarClearance: 72,
                safeAreaBottom: 0
            ) == 72
        )
    }

    @Test func homeOverviewLayout_tabRootVirtualFullScreenHeight_addsRootTabBarReserve() {
        let tabContentHeight: CGFloat = 803
        #expect(
            HomeOverviewLayout.tabRootVirtualFullScreenHeight(from: tabContentHeight)
                == tabContentHeight + HomeOverviewLayout.rootTabBarLayoutHeight
        )
        #expect(
            HomeOverviewLayout.tabRootHeroLayoutViewportHeight(from: tabContentHeight)
                == HomeOverviewLayout.viewportHeightMatchingHomeTab(
                    from: tabContentHeight + HomeOverviewLayout.rootTabBarLayoutHeight
                )
        )
        #expect(
            HomeOverviewLayout.tabRootPageLayoutHeight(from: tabContentHeight)
                == HomeOverviewLayout.pushedPageLayoutHeight(
                    from: tabContentHeight + HomeOverviewLayout.rootTabBarLayoutHeight
                )
        )
    }

    @Test func blueSheetPageLayoutBuilder_tabRootStackUsesDetailFullScreenFrame() {
        let tabContentGeometryHeight: CGFloat = 803
        let pushedGeometryHeight = tabContentGeometryHeight + HomeOverviewLayout.rootTabBarLayoutHeight
        let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
            showsBuddyLeaderboard: false
        )

        let tabRootHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: tabContentGeometryHeight,
            screenWidth: 393,
            rawGeometrySafeTop: 59,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .tabRoot(isNavigationStackAtRoot: true, frozenRootViewportHeight: nil)
        )
        let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: pushedGeometryHeight,
            screenWidth: 393,
            rawGeometrySafeTop: 59,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .pushedDetail(transitionViewportHeightFloor: 0)
        )
        #expect(tabRootHero == pushedHero)

        let tabRootStack = HomeTabRootLayoutPresentation.stackFrameHeight(
            from: tabContentGeometryHeight
        )
        let pushedStack = HomeOverviewLayout.pushedPageLayoutHeight(from: pushedGeometryHeight)
        #expect(tabRootStack == pushedStack)
        #expect(tabRootStack == pushedGeometryHeight)
    }

    @Test @MainActor func blueSheetPageLayoutBuilder_pushedHeroUsesPublishedHomeAnchor() {
        HomeOverviewLayoutAnchor.resetForTesting()
        defer { HomeOverviewLayoutAnchor.resetForTesting() }

        let screenWidth: CGFloat = 393
        let topSafeAreaInset: CGFloat = 59
        let anchoredHeroHeight: CGFloat = 312
        let homeTabViewportHeight = HomeOverviewLayout.viewportHeightMatchingHomeTab(from: 852)
        let seamInputs = HomeOverviewPushedLayoutPresentation.SeamInputs(
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight,
            showsBuddyLeaderboard: false
        )

        HomeOverviewLayoutAnchor.publish(
            HomeOverviewLayoutAnchor.RootSnapshot(
                heroHeight: anchoredHeroHeight,
                screenWidth: screenWidth,
                topSafeAreaInset: topSafeAreaInset,
                statsPanelContentHeight: seamInputs.statsPanelContentHeight,
                showsBuddyLeaderboard: seamInputs.showsBuddyLeaderboard,
                homeTabViewportHeight: homeTabViewportHeight
            )
        )

        let pushedHero = BlueSheetPageLayoutBuilder.heroHeight(
            geometryHeight: 852,
            screenWidth: screenWidth,
            rawGeometrySafeTop: topSafeAreaInset,
            layoutSafeAreaTopFloor: 0,
            seamInputs: seamInputs,
            mode: .pushedDetail(transitionViewportHeightFloor: 0)
        )
        #expect(pushedHero == anchoredHeroHeight)
    }

    @Test @MainActor func homeOverviewLayoutAnchor_publishHomeTabRootLayout_copiesSettledLayout() {
        HomeOverviewLayoutAnchor.resetForTesting()
        defer { HomeOverviewLayoutAnchor.resetForTesting() }

        let layout = BlueSheetHeaderPageLayoutContext(
            geometryWidth: 393,
            geometryHeight: 803,
            safeTop: 59,
            topInset: 108,
            heroTopSafeAreaInset: 59,
            layoutHeight: 803,
            layoutViewportHeight: 803,
            heroHeight: 280,
            bottomScrollInset: 50,
            panelBottomSafeAreaInset: 34,
            headerScrollClearance: 0,
            presentation: .tabRoot
        )

        HomeOverviewLayoutAnchor.publishHomeTabRootLayout(
            layout,
            statsPanelContentHeight: 220,
            showsBuddyLeaderboard: true
        )

        let root = HomeOverviewLayoutAnchor.root
        #expect(root?.heroHeight == layout.heroHeight)
        #expect(root?.screenWidth == layout.geometryWidth)
        #expect(root?.topSafeAreaInset == layout.heroTopSafeAreaInset)
        #expect(root?.homeTabViewportHeight == layout.layoutViewportHeight)
        #expect(root?.statsPanelContentHeight == 220)
        #expect(root?.showsBuddyLeaderboard == true)
    }

    @Test @MainActor func homeOverviewLayoutAnchor_publish_skipsIdenticalSnapshot() {
        HomeOverviewLayoutAnchor.resetForTesting()
        defer { HomeOverviewLayoutAnchor.resetForTesting() }

        let snapshot = HomeOverviewLayoutAnchor.RootSnapshot(
            heroHeight: 280,
            screenWidth: 393,
            topSafeAreaInset: 59,
            statsPanelContentHeight: 200,
            showsBuddyLeaderboard: false,
            homeTabViewportHeight: 803
        )
        HomeOverviewLayoutAnchor.publish(snapshot)
        HomeOverviewLayoutAnchor.publish(snapshot)
        #expect(HomeOverviewLayoutAnchor.root == snapshot)
    }

    @Test func blueSheetDetailPagePinnedSummaryPresentation_usesThemeSpacing() {
        #expect(BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding == AppTheme.Spacing.lg)
        #expect(BlueSheetDetailPagePinnedSummaryPresentation.topPadding == AppTheme.Spacing.md)
        #expect(BlueSheetDetailPagePinnedSummaryPresentation.bottomPadding == AppTheme.Spacing.sm)
        #expect(BlueSheetDetailPagePinnedSummaryPresentation.pinnedSummaryAccessibilitySuffix == "PinnedSummary")
    }

    @Test func blueSheetTopChromePresentation_homeHeroUsesLogbookScrimFeather() {
        #expect(BlueSheetTopChromePresentation.HomeHeroFade.usesBrandStatusBarScrim)
        #expect(BlueSheetTopChromePresentation.HomeHeroFade.logbookScrimFeather == 52)
    }

    @Test func blueSheetTopChromePresentation_detailTopUsesListFeather() {
        #expect(BlueSheetTopChromePresentation.DetailTopFade.usesListStatusBarScrim)
        #expect(BlueSheetTopChromePresentation.DetailTopFade.statusBarFeather == 22)
    }

    @Test func blueSheetTopChromePresentation_homeProfileAvatarDiameter_isTwentyPercentLarger() {
        #expect(BlueSheetTopChromePresentation.homeProfileAvatarDiameter == 48 * 1.2)
    }

    @Test func appHeaderBrandRowMetrics_wordmarkLineHeight_tracksLargeTitle() {
        #if os(iOS)
        let expected = ceil(UIFont.preferredFont(forTextStyle: .largeTitle).lineHeight)
        #expect(AppHeaderBrandRowMetrics.wordmarkLineHeight == expected)
        #endif
    }

    @Test func blueSheetPinnedSummaryPresentation_rowSpacingUsesTheme() {
        #expect(BlueSheetPinnedSummaryPresentation.rowSpacing == AppTheme.Spacing.sm)
    }

    @Test func blueSheetDetailPagePinnedSummaryPresentation_shellHorizontalPaddingMatchesPagerInset() {
        #expect(BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding == AppTheme.Spacing.lg)
    }

    @Test func blueSheetDetailHeroPresentation_placeholderTokens() {
        #expect(BlueSheetDetailHeroPresentation.placeholderFillOpacity == 0.12)
        #expect(BlueSheetDetailHeroPresentation.placeholderIconSize == 56)
        #expect(BlueSheetDetailHeroPresentation.loadingBandOpacity == 0.35)
    }

    @Test func blueSheetDetailPageConfiguration_pushedDetailDefaultsToShowsHero() {
        let config = BlueSheetDetailPageConfiguration.pushedDetail(
            accessibilityRootIdentifier: "Test.Hero"
        )
        #expect(config.showsHero)
    }

    @Test func blueSheetDetailPagerPresentation_tripScrollInsetExtraUsesThemeSpacing() {
        #expect(BlueSheetDetailPagerPresentation.tripScrollBottomInsetExtra == AppTheme.Spacing.lg)
        #expect(BlueSheetDetailPagerPresentation.scrollPageSpacing == AppTheme.Spacing.lg)
    }

    @Test @MainActor func exploreReferenceSiteDetailContentPagerPresentation_singleTab() {
        #expect(ExploreReferenceSiteDetailContentPagerPresentation.pageCount == 1)
        #expect(ExploreReferenceSiteDetailContentPagerPresentation.defaultPage == .details)
    }

    @Test @MainActor func equipmentDetailContentPagerPresentation_singleTab() {
        #expect(EquipmentDetailContentPagerPresentation.pageCount == 1)
        #expect(EquipmentDetailContentPagerPresentation.defaultPage == .details)
    }

    @Test func pageLayoutKind_includesSpeciesAndDiveSiteDetail() {
        #expect(PageLayoutKind.speciesDetail.displayName == "Species detail")
        #expect(PageLayoutKind.diveSiteDetail.displayName == "Dive site detail")
        #expect(PageLayoutKind.allCases.contains(.speciesDetail))
        #expect(PageLayoutKind.allCases.contains(.diveSiteDetail))
    }

    @Test @MainActor func fieldGuideSpeciesDetailContentPager_pages() {
        #expect(FieldGuideSpeciesDetailContentPagerPresentation.pageCount == 4)
        #expect(
            FieldGuideSpeciesDetailContentPagerPresentation.pages == [
                .about,
                .stats,
                .taggedDives,
                .taggedMedia,
            ]
        )
        #expect(FieldGuideSpeciesDetailContentPagerPresentation.defaultPage == .about)
        #expect(
            FieldGuideSpeciesDetailContentPagerPresentation.pageTitle(for: .taggedDives) == "Tagged dives"
        )
        #expect(
            FieldGuideSpeciesDetailContentPagerPresentation.accessibilityIdentifier(for: .taggedMedia)
                == "FieldGuide.SpeciesDetail.ContentPager.TaggedMedia"
        )
        #expect(!FieldGuideSpeciesDetailContentPagerPresentation.usesStaticPagerLayout(for: .about))
        #expect(
            FieldGuideSpeciesDetailContentPagerPresentation.emptyStateMessage(for: .taggedDives)
                == "No dives tagged with this species yet."
        )
    }

    @Test func fieldGuidePresentation_sightedDiveRowDisplayData_ordersNewestFirst() {
        let older = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 1_000_000),
            durationMinutes: 1,
            maxDepthMeters: 1
        )
        let newer = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 2_000_000),
            durationMinutes: 1,
            maxDepthMeters: 1
        )
        let rows = FieldGuidePresentation.sightedDiveRowDisplayData(
            activityIDs: [older.id, newer.id],
            activities: [older, newer],
            unitSystem: .metric
        )
        #expect(rows.count == 2)
        #expect(rows[0].id == newer.id)
        #expect(rows[1].id == older.id)
    }

    @Test func fieldGuideSpeciesDetailMapPresentation_pinsUniqueCoordinatesFromTaggedDives() {
        let site = DiveSite(
            siteName: "Salt Pier",
            latCoords: 12.0835,
            longCoords: -68.283
        )
        let taggedA = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 100),
            durationMinutes: 40,
            maxDepthMeters: 18,
            siteName: "Salt Pier",
            entryCoordinate: DiveCoordinate(latitude: 12.084, longitude: -68.284)
        )
        taggedA.diveSiteID = site.id
        let taggedB = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 200),
            durationMinutes: 35,
            maxDepthMeters: 16,
            siteName: "Salt Pier",
            entryCoordinate: DiveCoordinate(latitude: 12.084, longitude: -68.284)
        )
        taggedB.diveSiteID = site.id
        let taggedC = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 300),
            durationMinutes: 50,
            maxDepthMeters: 22,
            siteName: "Something Else",
            entryCoordinate: DiveCoordinate(latitude: 13.1, longitude: -69.1)
        )

        let pins = FieldGuideSpeciesDetailMapPresentation.pins(
            from: [taggedA, taggedB, taggedC],
            catalogSites: [site]
        )
        #expect(pins.count == 2)
        #expect(pins.allSatisfy { $0.kind == .completed })
        #expect(pins.contains(where: { $0.siteID == site.id }))
        #expect(
            FieldGuideSpeciesDetailMapPresentation.accessibilityLabel(for: pins)
                == "Species sighting sites map, 2 sites"
        )
    }

    @Test func fieldGuideCatalogBrowseListPresentation_matchesHubListSpacing() {
        #expect(
            FieldGuideCatalogBrowseListPresentation.listRowSpacing
                == FieldGuideHubTileLayout.listRowSpacing
        )
        #expect(FieldGuideCatalogBrowseListPresentation.listRowSpacing == AppTheme.Spacing.sm)
        let safeTop: CGFloat = 59
        let headerClearance: CGFloat = 52
        #expect(
            FieldGuideCatalogBrowseListPresentation.listTopInset(
                safeAreaTop: safeTop,
                headerClearance: headerClearance
            ) == safeTop + headerClearance
        )
        #expect(
            FieldGuideCatalogBrowseListPresentation.listBottomInset(safeAreaBottom: 34)
                == AppScrollUnderHeaderListLayout.listBottomInset(safeAreaBottom: 34)
        )
    }

    @Test func fieldGuideSpeciesSearchResultsPresentation_searchesFullCatalog() {
        let angelfish = MarineLifeCatalogSnapshot(
            uuid: "marine-life-french-angelfish",
            commonName: "French Angelfish",
            scientificName: "Pomacanthus paru",
            category: "fish",
            subcategory: "angelfishes",
            featureImageURL: "",
            minSizeMeters: 0.2,
            maxSizeMeters: 0.4,
            avgDepthMeters: 12
        )
        let turtle = MarineLifeCatalogSnapshot(
            uuid: "marine-life-green-turtle",
            commonName: "Green Turtle",
            scientificName: "Chelonia mydas",
            category: "reptiles",
            subcategory: "sea-turtles",
            featureImageURL: "",
            minSizeMeters: 0.8,
            maxSizeMeters: 1.5,
            avgDepthMeters: 8
        )
        let fishOnlyPayload = [angelfish]
        let fullCatalog = [angelfish, turtle]

        let scoped = FieldGuideMarineLifeSearch.filtering(fishOnlyPayload, query: "turtle")
        #expect(scoped.isEmpty)

        let globalRows = FieldGuideSpeciesSearchResultsPresentation.rowData(
            catalogSnapshots: fullCatalog,
            query: "turtle",
            unitSystem: .metric
        )
        #expect(globalRows.count == 1)
        #expect(globalRows[0].marineLifeUUID == turtle.uuid)
        #expect(FieldGuideSpeciesSearchEnvironment.searchPlaceholder == "Search Marine Life")
    }

    @Test func fieldGuideSpeciesSearchResultsPresentation_indexedRowData_matchesUnindexedFilter() {
        let angelfish = MarineLifeCatalogSnapshot(
            uuid: "marine-life-french-angelfish",
            commonName: "French Angelfish",
            scientificName: "Pomacanthus paru",
            category: "fish",
            subcategory: "angelfishes",
            featureImageURL: "",
            minSizeMeters: 0.2,
            maxSizeMeters: 0.4,
            avgDepthMeters: 12
        )
        let turtle = MarineLifeCatalogSnapshot(
            uuid: "marine-life-green-turtle",
            commonName: "Green Turtle",
            scientificName: "Chelonia mydas",
            category: "reptiles",
            subcategory: "sea-turtles",
            featureImageURL: "",
            minSizeMeters: 0.8,
            maxSizeMeters: 1.5,
            avgDepthMeters: 8
        )
        let catalog = [angelfish, turtle]
        let index = FieldGuideSpeciesSearchResultsPresentation.searchableTextByUUID(for: catalog)

        let indexedRows = FieldGuideSpeciesSearchResultsPresentation.rowData(
            catalogSnapshots: catalog,
            searchableTextByUUID: index,
            query: "chelonia",
            unitSystem: .metric
        )
        let unindexedRows = FieldGuideSpeciesSearchResultsPresentation.rowData(
            catalogSnapshots: catalog,
            query: "chelonia",
            unitSystem: .metric
        )
        #expect(indexedRows.map(\.marineLifeUUID) == unindexedRows.map(\.marineLifeUUID))
        #expect(indexedRows.count == 1)
        #expect(indexedRows[0].marineLifeUUID == turtle.uuid)
    }

    @Test func catalogSubstringSearch_matchesPrelowercasedHaystack() {
        let haystack = "salt pier bonaire caribbean"
        #expect(CatalogSubstringSearch.matchesPrelowercased(haystack, query: "bonaire"))
        #expect(!CatalogSubstringSearch.matchesPrelowercased(haystack, query: "belize"))
    }

    @Test func fieldGuideCategoryPresentation_detailHeroHeight_includesSafeAreaInset() {
        let inset: CGFloat = 59
        #expect(
            FieldGuideCategoryPresentation.detailHeroHeight(extraTopInset: inset)
                == FieldGuideCategoryImageLayout.detailHeroBaseHeight + inset
        )
        #expect(FieldGuideCategoryImageLayout.detailHeroBaseHeight == 200)
    }

    @Test func fieldGuideSubcategoryPresentation_matchesCategoryDetailHeroChrome() {
        let inset: CGFloat = 59
        #expect(
            FieldGuideSubcategoryPresentation.detailHeroHeight(extraTopInset: inset)
                == FieldGuideCategoryPresentation.detailHeroHeight(extraTopInset: inset)
        )
        let safeTop: CGFloat = 59
        let headerClearance: CGFloat = 52
        #expect(
            FieldGuideSubcategoryPresentation.chromeTopInset(
                safeAreaTop: safeTop,
                headerClearance: headerClearance
            ) == safeTop + headerClearance
        )
    }

    @Test func fieldGuideCatalogIndex_browsePayload_usesTaxonomySubcategoryTitle() {
        let payload = FieldGuideCatalogIndex.browsePayload(
            categoryID: "fishes",
            subcategoryID: "angelfishes",
            speciesIndex: [:]
        )
        #expect(payload.title == "Angelfishes")
        #expect(payload.categoryID == "fishes")
        #expect(payload.subcategoryID == "angelfishes")
    }

    @Test func fieldGuideMarineLifeHeroPresentation_autoSpinPausesWhileDraggingAndAfterDrag() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let pausedUntil = now.addingTimeInterval(15)

        #expect(
            !FieldGuideMarineLifeHeroPresentation.shouldAdvanceAutoSpin(
                autoRotateSpeedRadiansPerSecond: 0.225,
                isDragging: true,
                autoSpinPausedUntil: nil,
                now: now
            )
        )
        #expect(
            !FieldGuideMarineLifeHeroPresentation.shouldAdvanceAutoSpin(
                autoRotateSpeedRadiansPerSecond: 0.225,
                isDragging: false,
                autoSpinPausedUntil: pausedUntil,
                now: now
            )
        )
        #expect(
            FieldGuideMarineLifeHeroPresentation.shouldAdvanceAutoSpin(
                autoRotateSpeedRadiansPerSecond: 0.225,
                isDragging: false,
                autoSpinPausedUntil: pausedUntil,
                now: pausedUntil
            )
        )
    }

    @Test @MainActor func marineLifeCatalogSeeder_seedsFrenchAngelfishModel() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
        let french = try context.fetch(FetchDescriptor<MarineLife>()).first {
            $0.uuid == "marine-life-french-angelfish"
        }
        #expect(french?.commonName == "French Angelfish")
        #expect(french?.featureImageResourceName == "marine-life-french-angelfish")
        #expect(french?.featureModelResourceName == "FrenchAngelfish")
        #expect(french?.scientificName == "Pomacanthus paru")
    }

    @Test @MainActor func marineLifeCatalogSeeder_seedsCaribbeanReefSquid() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
        let squid = try context.fetch(FetchDescriptor<MarineLife>()).first {
            $0.uuid == "marine-life-caribbean-reef-squid"
        }
        #expect(squid?.commonName == "Caribbean Reef Squid")
        #expect(squid?.scientificName == "Sepioteuthis sepioidea")
        #expect(squid?.category == "invertebrates")
        #expect(squid?.subcategory == "squids")
        #expect(squid?.featureModelResourceName == "CaribbeanReefSquid")
    }

    @Test @MainActor func marineLifeCatalogSeeder_seedsGreenSeaTurtleModel() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
        let turtle = try context.fetch(FetchDescriptor<MarineLife>()).first {
            $0.uuid == "marine-life-green-sea-turtle"
        }
        #expect(turtle?.commonName == "Green Sea Turtle")
        #expect(turtle?.scientificName == "Chelonia mydas")
        #expect(turtle?.featureModelResourceName == "GreenSeaTurtle")
    }

    @Test @MainActor func marineLifeCatalogSeeder_seedsSpottedEagleRayModel() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
        let ray = try context.fetch(FetchDescriptor<MarineLife>()).first {
            $0.uuid == "marine-life-whitespotted-eagle-ray"
        }
        #expect(ray?.commonName == "Spotted Eagle Ray")
        #expect(ray?.scientificName == "Aetobatus narinari")
        #expect(ray?.featureModelResourceName == "SpottedEagleRay")
    }

    @Test func fieldGuidePresentation_depthLine_prefersMinMaxRange() {
        let entry = MarineLifeCatalogSnapshot(
            uuid: "queen",
            commonName: "Queen Angelfish",
            scientificName: "Holacanthus ciliaris",
            category: "fish",
            subcategory: "disk-and-large-oval",
            featureImageURL: "",
            minSizeMeters: 0.2,
            maxSizeMeters: 0.36,
            avgDepthMeters: 15.5,
            minDepthMeters: 6,
            maxDepthMeters: 25
        )
        let line = FieldGuidePresentation.sizeDepthLine(for: entry, unitSystem: .imperial)
        #expect(line.contains("20 ft–80 ft"))
        let metricLine = FieldGuidePresentation.depthLine(
            minMeters: 6,
            maxMeters: 25,
            avgMeters: 15.5,
            unitSystem: .metric
        )
        #expect(metricLine == "6 m–25 m")
    }

    @Test @MainActor func marineLifeCatalogSeeder_isIdempotentByUUID() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
        let firstCount = try context.fetchCount(FetchDescriptor<MarineLife>())
        #expect(firstCount > 0)
        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
        #expect(try context.fetchCount(FetchDescriptor<MarineLife>()) == firstCount)
    }

    @Test @MainActor func marineLifeCatalogSeeder_prunesSpeciesRemovedFromBundledJSON() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        context.insert(
            MarineLife(
                uuid: "marine-life-orphan-catalog-row",
                commonName: "Orphan Species",
                scientificName: "Orphanus testus"
            )
        )
        try context.save()

        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)

        let orphan = try context.fetch(FetchDescriptor<MarineLife>()).first {
            $0.uuid == "marine-life-orphan-catalog-row"
        }
        #expect(orphan == nil)
        #expect(try context.fetchCount(FetchDescriptor<MarineLife>()) > 0)
    }

    @Test @MainActor func marineLifeCatalogSeeder_preservesUserCreatedSpeciesOnReseed() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let userSpecies = FieldGuideMarineLifeAddPresentation.makeMarineLife(
            from: FieldGuideMarineLifeAddPresentation.FormValues(
                commonName: "My Custom Goby",
                scientificName: "Gobius customus",
                categoryID: "fishes",
                subcategoryID: "gobies"
            )
        )
        context.insert(userSpecies)
        try context.save()

        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)

        let preserved = try context.fetch(FetchDescriptor<MarineLife>()).first {
            $0.uuid == userSpecies.uuid
        }
        #expect(preserved?.commonName == "My Custom Goby")
        #expect(FieldGuideMarineLifeAddPresentation.isUserCreated(uuid: userSpecies.uuid))
    }

    @Test func fieldGuideMarineLifeAddPresentation_validatesAndBuildsSpecies() {
        var form = FieldGuideMarineLifeAddPresentation.FormValues(
            commonName: "  Blue Tang  ",
            scientificName: "Acanthurus coeruleus",
            categoryID: "fishes",
            subcategoryID: "surgeonfishes",
            familyName: "Acanthuridae",
            aboutText: "Herbivorous reef fish."
        )
        #expect(FieldGuideMarineLifeAddPresentation.canSave(form))
        let species = FieldGuideMarineLifeAddPresentation.makeMarineLife(from: form)
        #expect(species.commonName == "Blue Tang")
        #expect(species.category == "fishes")
        #expect(species.subcategory == "surgeonfishes")
        #expect(FieldGuideMarineLifeAddPresentation.isUserCreated(uuid: species.uuid))

        form.commonName = "   "
        #expect(!FieldGuideMarineLifeAddPresentation.canSave(form))
        #expect(FieldGuideMarineLifeAddPresentation.sheetTitle == "New species")
        #expect(
            FieldGuideMarineLifeAddPresentation.chromeAccessibilityIdentifier
                == "FieldGuide.AddSpecies"
        )
    }

    @Test @MainActor func marineLifeCatalogSeeder_seedsQueenAngelfish() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        try MarineLifeCatalogSeeder.seedBundledCatalogIfNeeded(context: context)
        let queen = try context.fetch(FetchDescriptor<MarineLife>()).first { $0.uuid == "marine-life-queen-angelfish" }
        #expect(queen?.commonName == "Queen Angelfish")
        #expect(queen?.familyName == "Pomacanthidae")
        #expect(queen?.minDepthMeters == 1)
        #expect(queen?.maxDepthMeters == 70)
    }

    @Test func marineLifeCommonNameFormatting_titleCasesEachWord() {
        #expect(MarineLifeCommonNameFormatting.normalized("French angelfish") == "French Angelfish")
        #expect(MarineLifeCommonNameFormatting.normalized("  GREEN SEA TURTLE  ") == "Green Sea Turtle")
        #expect(MarineLifeCommonNameFormatting.normalized("spotted eagle ray") == "Spotted Eagle Ray")
    }

    @Test func marineLifeCommonNameFormatting_handlesHyphensAndApostrophes() {
        #expect(MarineLifeCommonNameFormatting.normalized("king angelfish") == "King Angelfish")
        #expect(MarineLifeCommonNameFormatting.normalized("two-spot demoiselle") == "Two-Spot Demoiselle")
    }

    @Test @MainActor func marineLife_initNormalizesCommonName() throws {
        let species = MarineLife(uuid: "marine-life-title-case-test", commonName: "queen angelfish")
        #expect(species.commonName == "Queen Angelfish")
    }

    @Test @MainActor func marineLifeCommonNameNormalization_updatesStoredRows() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let species = MarineLife(uuid: "marine-life-legacy-case", commonName: "legacy species")
        context.insert(species)
        try context.save()

        species.commonName = "french angelfish"
        try context.save()

        try MarineLifeCommonNameNormalization.normalizeStoredCatalogIfNeeded(modelContext: context)
        #expect(species.commonName == "French Angelfish")
    }

    @Test @MainActor func marineLife_subcategoryDefaultsEmptyForSwiftDataMigration() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let species = MarineLife(uuid: "marine-life-migration-test", commonName: "Test Species")
        context.insert(species)
        try context.save()
        #expect(species.subcategory == "")
    }

    @Test func sightingInstanceDateTimeResolution_prefersMediaCapturedAt() {
        let diveStart = Date(timeIntervalSince1970: 1_000_000)
        let mediaTime = Date(timeIntervalSince1970: 1_000_500)
        #expect(
            SightingInstanceDateTimeResolution.resolvedUTCDateTime(
                diveStartTime: diveStart,
                mediaCapturedAt: mediaTime
            ) == mediaTime
        )
        #expect(
            SightingInstanceDateTimeResolution.resolvedUTCDateTime(
                diveStartTime: diveStart,
                mediaCapturedAt: nil
            ) == diveStart
        )
    }

    @Test @MainActor func sightingInstanceCreation_insert_linksMarineLifeAndDive() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 2_000_000),
            durationMinutes: 45,
            maxDepthMeters: 18
        )
        let species = MarineLife(uuid: "marine-life-test-ray", commonName: "Spotted Eagle Ray")
        context.insert(dive)
        context.insert(species)

        let draft = SightingInstanceCreation.makeDraft(
            marineLifeUUID: species.uuid,
            dive: dive,
            sightingDepthMeters: 12
        )
        let sighting = try SightingInstanceCreation.insert(
            draft: draft,
            marineLife: species,
            dive: dive,
            modelContext: context
        )

        #expect(sighting.marineLifeUUID == species.uuid)
        #expect(sighting.diveActivityID == dive.id)
        #expect(sighting.sightingDateTime == dive.startTime)
        #expect(sighting.sightingDepthMeters == 12)
        #expect(sighting.mediaPhotoID == nil)
    }

    @Test func diveActivityMediaPresentation_showsMarineLifeTagOnHero_isDisabled() {
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagOnHero(for: .minimized))
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagOnHero(for: .medium))
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagOnHero(for: .large))
    }

    @Test func diveActivityMediaPresentation_showsMarineLifeTagInCarousel_onlyAtMinimized() {
        #expect(DiveActivityMediaPresentation.showsMarineLifeTagInCarousel(for: .minimized))
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagInCarousel(for: .medium))
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagInCarousel(for: .large))
    }

    @Test func diveActivityMediaPresentation_carouselThumbnailExtent_scalesSelectedItem() {
        let base = DiveActivityMediaPresentation.carouselThumbnailSize
        #expect(DiveActivityMediaPresentation.carouselThumbnailExtent(isSelected: false) == base)
        #expect(
            DiveActivityMediaPresentation.carouselThumbnailExtent(isSelected: true)
                == base * DiveActivityMediaPresentation.carouselSelectedThumbnailScale
        )
    }

    @Test func diveActivityMediaPresentation_mediaTab_usesFullBleedHeroAndTranslucentPanelAtAllDetents() {
        for detent in [DiveActivityOverviewDetent.minimized, .medium, .large] {
            #expect(DiveActivityMediaPresentation.usesFullBleedMediaHero(for: detent))
            #expect(DiveActivityMediaPresentation.usesTranslucentOverviewPanel(for: detent))
        }
    }

    @Test func diveActivityMediaPresentation_panelTopScrollFadeHeight_onlyAtLargeOnMediaTab() {
        #expect(
            DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                detent: .large,
                isMediaTabSelected: true
            ) == DiveActivityOverviewPanelMetrics.mediaLargeDetentTopScrollFadeHeight
        )
        #expect(
            DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                detent: .medium,
                isMediaTabSelected: true
            ) == 0
        )
        #expect(
            DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                detent: .large,
                isMediaTabSelected: false
            ) == 0
        )
    }

    @Test func diveActivityMediaPresentation_showsHeroTopChromeScrim_onlyOnMapAndTank() {
        #expect(!DiveActivityMediaPresentation.showsHeroTopChromeScrim(isMediaTabSelected: true))
        #expect(DiveActivityMediaPresentation.showsHeroTopChromeScrim(isMediaTabSelected: false))
    }

    @Test func diveActivityMediaPresentation_panelTopScrollKeepsTranslucentChromeAtLargeMediaTab() {
        #expect(
            !DiveActivityMediaPresentation.panelTopScrollUsesOpaqueFadeBackground(
                detent: .large,
                isMediaTabSelected: true
            )
        )
        #expect(
            DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                detent: .large,
                isMediaTabSelected: true
            ) > 0
        )
    }

    @Test func diveActivityMediaPresentation_speciesWasFishialIdentified_matchesScientificName() {
        let media = DiveMediaPhoto(fishialConfirmedSpeciesName: "Holacanthus ciliaris")
        let species = MarineLife(
            uuid: "marine-life-queen-angelfish",
            commonName: "Queen Angelfish",
            scientificName: "Holacanthus ciliaris"
        )
        let other = MarineLife(
            uuid: "marine-life-french-angelfish",
            commonName: "French Angelfish",
            scientificName: "Holacanthus paru"
        )
        #expect(DiveActivityMediaPresentation.speciesWasFishialIdentified(species: species, on: media))
        #expect(!DiveActivityMediaPresentation.speciesWasFishialIdentified(species: other, on: media))
    }

    @Test func diveActivityMediaPresentation_speciesWasFishialIdentified_matchesAnyConfirmedName() {
        let media = DiveMediaPhoto(
            fishialConfirmedSpeciesName: "Holacanthus ciliaris|Paracanthurus hepatus"
        )
        let queen = MarineLife(
            uuid: "marine-life-queen-angelfish",
            commonName: "Queen Angelfish",
            scientificName: "Holacanthus ciliaris"
        )
        let blueTang = MarineLife(
            uuid: "marine-life-blue-tang",
            commonName: "Blue Tang",
            scientificName: "Paracanthurus hepatus"
        )
        let other = MarineLife(
            uuid: "marine-life-french-angelfish",
            commonName: "French Angelfish",
            scientificName: "Holacanthus paru"
        )
        #expect(DiveActivityMediaPresentation.speciesWasFishialIdentified(species: queen, on: media))
        #expect(DiveActivityMediaPresentation.speciesWasFishialIdentified(species: blueTang, on: media))
        #expect(!DiveActivityMediaPresentation.speciesWasFishialIdentified(species: other, on: media))
    }

    @Test func diveActivityMediaPresentation_resolvedTaggedSpeciesUUID_prefersChipSelection() {
        let uuids = ["fish-a", "fish-b", "fish-c"]
        #expect(
            DiveActivityMediaPresentation.resolvedTaggedSpeciesUUID(
                selectedUUID: "fish-b",
                taggedSpeciesUUIDs: uuids
            ) == "fish-b"
        )
        #expect(
            DiveActivityMediaPresentation.resolvedTaggedSpeciesUUID(
                selectedUUID: "removed-fish",
                taggedSpeciesUUIDs: uuids
            ) == "fish-a"
        )
        #expect(
            DiveActivityMediaPresentation.resolvedTaggedSpeciesUUID(
                selectedUUID: nil,
                taggedSpeciesUUIDs: uuids
            ) == "fish-a"
        )
        #expect(
            DiveActivityMediaPresentation.resolvedTaggedSpeciesUUID(
                selectedUUID: "fish-b",
                taggedSpeciesUUIDs: []
            ) == nil
        )
    }

    @Test func diveActivityMediaPresentation_opensMarineLifeDetailOnTaggedChipTap_onlyAtMediumWithTags() {
        #expect(
            DiveActivityMediaPresentation.opensMarineLifeDetailOnTaggedChipTap(
                detent: .medium,
                taggedSpeciesCount: 2
            )
        )
        #expect(
            !DiveActivityMediaPresentation.opensMarineLifeDetailOnTaggedChipTap(
                detent: .medium,
                taggedSpeciesCount: 0
            )
        )
        #expect(
            !DiveActivityMediaPresentation.opensMarineLifeDetailOnTaggedChipTap(
                detent: .large,
                taggedSpeciesCount: 2
            )
        )
    }

    @Test func diveActivityMediaPresentation_showsMarineLifeTagInSheet_onlyAtMedium() {
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagInSheet(for: .minimized))
        #expect(DiveActivityMediaPresentation.showsMarineLifeTagInSheet(for: .medium))
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagInSheet(for: .large))
    }

    @Test func diveActivityMediaPresentation_showsBuddyTagInSheet_onlyAtMedium() {
        #expect(!DiveActivityMediaPresentation.showsBuddyTagInSheet(for: .minimized))
        #expect(DiveActivityMediaPresentation.showsBuddyTagInSheet(for: .medium))
        #expect(!DiveActivityMediaPresentation.showsBuddyTagInSheet(for: .large))
    }

    @Test func diveActivityMediaPresentation_buddyTagControlIsActive_whenTagged() {
        #expect(!DiveActivityMediaPresentation.buddyTagControlIsActive(taggedBuddyCount: 0))
        #expect(DiveActivityMediaPresentation.buddyTagControlIsActive(taggedBuddyCount: 1))
    }

    @Test func diveActivityMediaPresentation_showsMarineLifeTagSummary_onlyAtMedium() {
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagSummaryInSheet(for: .minimized))
        #expect(DiveActivityMediaPresentation.showsMarineLifeTagSummaryInSheet(for: .medium))
        #expect(!DiveActivityMediaPresentation.showsMarineLifeTagSummaryInSheet(for: .large))
    }

    @Test func diveActivityMediaPresentation_showsMarineLifeDetail_onlyAtLarge() {
        #expect(!DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: .minimized))
        #expect(!DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: .medium))
        #expect(DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: .large))
    }

    @Test func diveActivityMediaPresentation_showsMediaSheetChromeActions_onlyAtMedium() {
        #expect(!DiveActivityMediaPresentation.showsMediaSheetChromeActions(for: .minimized))
        #expect(DiveActivityMediaPresentation.showsMediaSheetChromeActions(for: .medium))
        #expect(!DiveActivityMediaPresentation.showsMediaSheetChromeActions(for: .large))
    }

    @Test func diveActivityOverviewPanelMetrics_mediaCarouselScreenAlignmentTopInset_matchesDetentGap() {
        let layoutHeight: CGFloat = 800
        #expect(
            DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
                layoutHeight: layoutHeight,
                detent: .medium
            ) == layoutHeight * (0.50 - 0.20)
        )
        #expect(
            DiveActivityOverviewPanelMetrics.mediaCarouselExpandedRegionHeight(
                layoutHeight: layoutHeight
            ) == layoutHeight * (0.50 - 0.20)
        )
    }

    @Test @MainActor func marineLifeSightingRecorder_tagsMediaAndUpdatesUserRecord() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "test-tag", displayName: "Diver")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_000_000),
            durationMinutes: 40,
            maxDepthMeters: 20
        )
        dive.owner = owner
        dive.ownerProfileID = owner.id
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_000_100))
        media.link(to: dive)
        let species = MarineLife(uuid: "marine-life-tag-test", commonName: "French Angelfish")

        context.insert(owner)
        context.insert(dive)
        context.insert(media)
        context.insert(species)

        let contextCapture = DiveMediaCaptureContext(elapsedSeconds: 600, depthMeters: 15)
        _ = try MarineLifeSightingRecorder.tagSpecies(
            species,
            on: media,
            dive: dive,
            captureContext: contextCapture,
            owner: owner,
            modelContext: context
        )

        let sightings = try context.fetch(FetchDescriptor<SightingInstance>())
        #expect(sightings.count == 1)
        #expect(sightings[0].marineLifeUUID == species.uuid)
        #expect(sightings[0].mediaPhotoID == media.id)
        #expect(sightings[0].sightingDateTime == media.capturedAt)
        #expect(sightings[0].sightingDepthMeters == 15)

        let records = try MarineLifeUserRecordOwnership.userRecords(
            forOwnerProfileID: owner.id,
            modelContext: context
        )
        #expect(records.count == 1)
        #expect(records[0].isSighted)
        #expect(records[0].activitiesSightedOn.contains(dive.id))
        #expect(records[0].userTaggedMedia.contains("media:\(media.id.uuidString)"))
    }

    @Test @MainActor func marineLifeSightingRecorder_sightingsForMedia_filtersByPhotoID() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "test-sightings-filter", displayName: "Diver")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_100_000),
            durationMinutes: 40,
            maxDepthMeters: 20
        )
        dive.owner = owner
        dive.ownerProfileID = owner.id
        let taggedMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_100_100))
        let otherMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_100_200))
        taggedMedia.link(to: dive)
        otherMedia.link(to: dive)
        let angelfish = MarineLife(uuid: "marine-life-filter-angelfish", commonName: "French Angelfish")
        let ray = MarineLife(uuid: "marine-life-filter-ray", commonName: "Spotted Eagle Ray")
        let turtle = MarineLife(uuid: "marine-life-filter-turtle", commonName: "Green Turtle")

        context.insert(owner)
        context.insert(dive)
        context.insert(taggedMedia)
        context.insert(otherMedia)
        context.insert(angelfish)
        context.insert(ray)
        context.insert(turtle)

        _ = try MarineLifeSightingRecorder.tagSpecies(
            angelfish,
            on: taggedMedia,
            dive: dive,
            captureContext: nil,
            owner: owner,
            modelContext: context
        )
        _ = try MarineLifeSightingRecorder.tagSpecies(
            ray,
            on: taggedMedia,
            dive: dive,
            captureContext: nil,
            owner: owner,
            modelContext: context
        )
        _ = try MarineLifeSightingRecorder.tagSpecies(
            turtle,
            on: otherMedia,
            dive: dive,
            captureContext: nil,
            owner: owner,
            modelContext: context
        )

        let taggedSightings = try MarineLifeSightingRecorder.sightings(
            forMediaPhotoID: taggedMedia.id,
            modelContext: context
        )
        #expect(taggedSightings.count == 2)
        #expect(Set(taggedSightings.map(\.marineLifeUUID)) == Set([angelfish.uuid, ray.uuid]))
    }

    @Test @MainActor func marineLifeSightingRecorder_tagPendingSpecies_persistsBatchWithSingleSave() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "test-batch-tag", displayName: "Diver")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_200_000),
            durationMinutes: 40,
            maxDepthMeters: 20
        )
        dive.owner = owner
        dive.ownerProfileID = owner.id
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_200_100))
        media.link(to: dive)
        let angelfish = MarineLife(uuid: "marine-life-batch-angelfish", commonName: "French Angelfish")
        let ray = MarineLife(uuid: "marine-life-batch-ray", commonName: "Spotted Eagle Ray")

        context.insert(owner)
        context.insert(dive)
        context.insert(media)
        context.insert(angelfish)
        context.insert(ray)

        try MarineLifeSightingRecorder.tagPendingSpecies(
            [angelfish, ray],
            on: media,
            dive: dive,
            captureContext: DiveMediaCaptureContext(elapsedSeconds: 600, depthMeters: 12),
            owner: owner,
            modelContext: context
        )

        let sightings = try MarineLifeSightingRecorder.sightings(
            forMediaPhotoID: media.id,
            modelContext: context
        )
        #expect(sightings.count == 2)
        #expect(Set(sightings.map(\.marineLifeUUID)) == Set([angelfish.uuid, ray.uuid]))

        let records = try MarineLifeUserRecordOwnership.userRecords(
            forOwnerProfileID: owner.id,
            modelContext: context
        )
        #expect(records.count == 2)
        #expect(records.allSatisfy { $0.isSighted })
        #expect(records.allSatisfy { $0.activitiesSightedOn.contains(dive.id) })
        #expect(records.allSatisfy { $0.userTaggedMedia.contains("media:\(media.id.uuidString)") })
    }

    @Test func marineLifeMediaTagPresentation_taggedRows_listsUniqueSpeciesOnMedia() {
        let taggedMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_000_000))
        let otherMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_000_200))
        let angelfish = MarineLife(uuid: "marine-life-row-angelfish", commonName: "Zebra Angelfish")
        let ray = MarineLife(uuid: "marine-life-row-ray", commonName: "Spotted Eagle Ray")

        let sightingOnMedia = SightingInstance(
            marineLifeUUID: angelfish.uuid,
            sightingDateTime: Date(timeIntervalSince1970: 4_000_000),
            marineLife: angelfish,
            mediaPhoto: taggedMedia
        )
        let duplicateOnMedia = SightingInstance(
            marineLifeUUID: angelfish.uuid,
            sightingDateTime: Date(timeIntervalSince1970: 4_000_100),
            marineLife: angelfish,
            mediaPhoto: taggedMedia
        )
        let otherMediaSighting = SightingInstance(
            marineLifeUUID: ray.uuid,
            sightingDateTime: Date(timeIntervalSince1970: 4_000_200),
            marineLife: ray,
            mediaPhoto: otherMedia
        )

        let rows = MarineLifeMediaTagPresentation.taggedRows(
            mediaPhotoID: taggedMedia.id,
            sightings: [sightingOnMedia, duplicateOnMedia, otherMediaSighting],
            catalog: [angelfish, ray],
            unitSystem: .metric
        )

        #expect(rows.count == 1)
        #expect(rows[0].marineLifeUUID == angelfish.uuid)
        #expect(rows[0].commonName == "Zebra Angelfish")
        #expect(rows[0].featureImageResourceName == angelfish.featureImageResourceName)
    }

    @Test func marineLifeMediaTagPresentation_mediumDetentAccessibilityLabel_listsTaggedNames() {
        #expect(
            MarineLifeMediaTagPresentation.mediumDetentAccessibilityLabel(taggedNames: [])
                == MarineLifeMediaTagPresentation.untaggedPrompt
        )
        #expect(
            MarineLifeMediaTagPresentation.mediumDetentAccessibilityLabel(
                taggedNames: ["French Angelfish", "Green Turtle"]
            ) == "Marine life: French Angelfish, Green Turtle"
        )
    }

    @Test func marineLifeMediaTagPresentation_descriptionSections_includesPopulatedFields() {
        let species = MarineLife(
            uuid: "marine-life-desc-test",
            commonName: "French Angelfish",
            aboutText: "A Caribbean classic.",
            distinctiveFeatures: "Yellow tail",
            abundance: "Common",
            habitatBehavior: "Reefs",
            diverReaction: "Approachable"
        )

        let sections = MarineLifeMediaTagPresentation.descriptionSections(for: species)
        #expect(sections.map { $0.title } == [
            "Distinctive features",
            "Abundance",
            "Habitat & behavior",
            "Diver reaction",
            "About",
        ])
    }

    @Test @MainActor func marineLifeMediaTagPresentation_resolvedTaggedSpecies_listsUniqueSortedSpecies() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let taggedMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_100_000))
        let angelfish = MarineLife(uuid: "marine-life-resolve-angelfish", commonName: "French Angelfish")
        let ray = MarineLife(uuid: "marine-life-resolve-ray", commonName: "Spotted Eagle Ray")
        let turtle = MarineLife(uuid: "marine-life-resolve-turtle", commonName: "Green Turtle")

        context.insert(taggedMedia)
        context.insert(angelfish)
        context.insert(ray)
        context.insert(turtle)

        let angelfishSighting = SightingInstance(
            marineLifeUUID: angelfish.uuid,
            sightingDateTime: Date(timeIntervalSince1970: 4_100_100),
            marineLife: angelfish,
            mediaPhoto: taggedMedia
        )
        let raySighting = SightingInstance(
            marineLifeUUID: ray.uuid,
            sightingDateTime: Date(timeIntervalSince1970: 4_100_200),
            marineLife: ray,
            mediaPhoto: taggedMedia
        )
        let turtleSighting = SightingInstance(
            marineLifeUUID: turtle.uuid,
            sightingDateTime: Date(timeIntervalSince1970: 4_100_300),
            marineLife: turtle,
            mediaPhoto: DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_100_400))
        )
        context.insert(angelfishSighting)
        context.insert(raySighting)
        context.insert(turtleSighting)

        let resolved = MarineLifeMediaTagPresentation.resolvedTaggedSpecies(
            mediaPhotoID: taggedMedia.id,
            sightings: [angelfishSighting, raySighting, turtleSighting],
            catalog: [angelfish, ray, turtle]
        )

        #expect(resolved.count == 2)
        #expect(resolved.map(\.commonName) == ["French Angelfish", "Spotted Eagle Ray"])
    }

    @Test func marineLifeMediaTagPresentation_taggedCommonNames_mapsRowCommonNames() {
        let rows = [
            MarineLifeMediaTagPresentation.TaggedSpeciesRow(
                marineLifeUUID: "a",
                commonName: "French Angelfish",
                scientificName: "Pomacanthus paru",
                category: "fish",
                featureImageURL: "",
                featureImageResourceName: "",
                detailLine: ""
            ),
            MarineLifeMediaTagPresentation.TaggedSpeciesRow(
                marineLifeUUID: "b",
                commonName: "Green Turtle",
                scientificName: "Chelonia mydas",
                category: "reptiles",
                featureImageURL: "",
                featureImageResourceName: "",
                detailLine: ""
            ),
        ]
        #expect(MarineLifeMediaTagPresentation.taggedCommonNames(from: rows) == [
            "French Angelfish",
            "Green Turtle",
        ])
    }

    @Test func expandableDetailSectionPresentation_collapsedByDefaultWithItems() {
        #expect(ExpandableDetailSectionPresentation.showsExpandControl(itemCount: 0) == false)
        #expect(ExpandableDetailSectionPresentation.showsExpandControl(itemCount: 3))
        #expect(
            ExpandableDetailSectionPresentation.headerAccessibilityLabel(
                title: "Dives together",
                itemCount: 2,
                isExpanded: false
            ).contains("collapsed")
        )
        #expect(
            ExpandableDetailSectionPresentation.headerAccessibilityLabel(
                title: "Activities at this site",
                itemCount: 1,
                isExpanded: true
            ).contains("expanded")
        )
    }

    @Test func fieldGuideTaxonomy_fishesCategoryHasDetailHeaderCopy() {
        let fish = FieldGuideTaxonomy.category(id: "fishes")
        #expect(fish?.title == "Fishes")
        #expect(fish?.description.contains("Caribbean Reef Life") == true)
        #expect(fish?.heroImageName == "FieldGuideCategoryFish")
        #expect(fish?.subcategories.count == 48)
    }

    @Test func fieldGuideTaxonomy_resolvesLegacyCategoryLabels() {
        let ray = MarineLifeCatalogSnapshot(
            uuid: "ray",
            commonName: "Spotted Eagle Ray",
            scientificName: "Aetobatus narinari",
            category: "Ray",
            subcategory: "",
            featureImageURL: "",
            minSizeMeters: 0,
            maxSizeMeters: 0,
            avgDepthMeters: 0
        )
        #expect(FieldGuideTaxonomy.resolvedCategoryID(for: ray) == "fishes")
        #expect(FieldGuideTaxonomy.resolvedSubcategoryID(for: ray) == "rays")
        #expect(FieldGuideTaxonomy.subcategoryTitle(for: ray) == "Rays")
    }

    @Test func fieldGuideCatalogIndex_countsSpeciesPerCategoryAndSubcategory() {
        let samples = [
            MarineLifeCatalogSnapshot(
                uuid: "a",
                commonName: "French Angelfish",
                scientificName: "",
                category: "fishes",
                subcategory: "angelfishes",
                featureImageURL: "",
                minSizeMeters: 0,
                maxSizeMeters: 0,
                avgDepthMeters: 0
            ),
            MarineLifeCatalogSnapshot(
                uuid: "b",
                commonName: "Spotted Eagle Ray",
                scientificName: "",
                category: "fishes",
                subcategory: "rays",
                featureImageURL: "",
                minSizeMeters: 0,
                maxSizeMeters: 0,
                avgDepthMeters: 0
            ),
        ]
        let summaries = FieldGuideCatalogIndex.summaries(for: samples)
        let fish = summaries.first { $0.categoryID == "fishes" }
        #expect(fish?.speciesCount == 2)
        #expect(fish?.subcategoryCounts["angelfishes"] == 1)
        #expect(fish?.subcategoryCounts["rays"] == 1)
        #expect(FieldGuideCatalogIndex.species(in: "fishes", subcategoryID: "eels", catalog: samples).isEmpty)
    }

    @Test func appLaunchLayout_matchesStoryboardConstraints() {
        let safeMidY: CGFloat = 400
        let logoCenterY = AppLaunchLayout.logoCenterY(safeAreaMidY: safeMidY)
        #expect(logoCenterY == safeMidY - 48)

        let titleCenterY = AppLaunchLayout.titleCenterY(logoCenterY: logoCenterY)
        #expect(titleCenterY == logoCenterY + 64 + 24 + AppLaunchLayout.titleLineHeight / 2)

        #expect(AppLaunchLayout.logoSize == 128)
        #expect(AppLaunchLayout.logoToTitleSpacing == 24)
        #if canImport(UIKit)
        let launchTitleFont = UIFont.boldSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        )
        #expect(AppLaunchLayout.titleFontSize == launchTitleFont.pointSize)
        #expect(AppLaunchLayout.titleLineHeight == ceil(launchTitleFont.lineHeight))
        #else
        #expect(AppLaunchLayout.titleFontSize == 34)
        #endif
        #expect(AppLaunchLayout.fixedBackgroundBlue == 0.09)
        #expect(AppLaunchLayout.fixedTitleBlue == 1.0)
    }

    @Test @MainActor func fieldGuideCatalogIndex_categorySummaryIsHashable() {
        let summary = FieldGuideCatalogIndex.CategorySummary(
            categoryID: "fishes",
            speciesCount: 3,
            subcategoryCounts: ["eels": 1, "rays": 2]
        )
        var seen: Set<FieldGuideCatalogIndex.CategorySummary> = []
        seen.insert(summary)
        #expect(seen.contains(summary))
    }

    @Test func fieldGuideCatalogIndex_subcategorySpeciesIndex_lookup() {
        let samples = [
            MarineLifeCatalogSnapshot(
                uuid: "a",
                commonName: "Zebra Fish",
                scientificName: "",
                category: "fishes",
                subcategory: "gobies",
                featureImageURL: "",
                minSizeMeters: 0,
                maxSizeMeters: 0,
                avgDepthMeters: 0
            ),
            MarineLifeCatalogSnapshot(
                uuid: "b",
                commonName: "Angelfish",
                scientificName: "",
                category: "fishes",
                subcategory: "angelfishes",
                featureImageURL: "",
                minSizeMeters: 0,
                maxSizeMeters: 0,
                avgDepthMeters: 0
            ),
            MarineLifeCatalogSnapshot(
                uuid: "c",
                commonName: "Another Oval",
                scientificName: "",
                category: "fishes",
                subcategory: "angelfishes",
                featureImageURL: "",
                minSizeMeters: 0,
                maxSizeMeters: 0,
                avgDepthMeters: 0
            ),
        ]

        let index = FieldGuideCatalogIndex.subcategorySpeciesIndex(for: samples)
        let payload = FieldGuideCatalogIndex.browsePayload(
            categoryID: "fishes",
            subcategoryID: "angelfishes",
            speciesIndex: index
        )

        #expect(payload.title == "Angelfishes")
        #expect(payload.species.map(\.uuid) == ["b", "c"])
        #expect(
            FieldGuideCatalogIndex.browsePayload(
                categoryID: "fishes",
                subcategoryID: "eels",
                speciesIndex: index
            ).species.isEmpty
        )
    }

    @Test func fieldGuideHubTileLayout_matchesLogbookActivityRowSpacing() {
        #expect(FieldGuideHubTileLayout.listRowSpacing == AppTheme.Spacing.sm)
        #expect(FieldGuideHubTileLayout.tilePadding == LogbookActivityRowLayout.cardPadding)
        #expect(FieldGuideHubTileLayout.tileCornerRadius == LogbookActivityRowLayout.cardCornerRadius)
        #expect(FieldGuideHubTileLayout.tileHeight == HomeLifetimeStatsTilesLayout.statTileHeight)
        #expect(FieldGuideHubTileLayout.hubTitleScrollFeather == 44)
        #expect(FieldGuideHubTileLayout.hubScrollScrimHeight(topChromeInset: 111) == 155)
        #expect(FieldGuideHubTileLayout.titleTwoLineMinHeight(isFeatured: false) > 0)
    }

    @Test func diveMarineLifeTagSheetPresentation_fishialIdentifyIsActive_whenSpeciesNameConfirmed() {
        #expect(
            !DiveMarineLifeTagSheetPresentation.fishialIdentifyIsActive(
                confirmedSpeciesName: nil
            )
        )
        #expect(
            DiveMarineLifeTagSheetPresentation.fishialIdentifyIsActive(
                confirmedSpeciesName: "Holacanthus ciliaris"
            )
        )
    }

    @Test func diveMarineLifeTagSheetPresentation_fishialIdentifyIconGradient_usesPinkPurpleStops() {
        #expect(DiveMarineLifeTagSheetPresentation.fishialIdentifyGradientLeading == Color(
            red: 0.96,
            green: 0.42,
            blue: 0.74
        ))
        #expect(DiveMarineLifeTagSheetPresentation.fishialIdentifyGradientTrailing == Color(
            red: 0.58,
            green: 0.34,
            blue: 0.96
        ))
        #expect(DiveMarineLifeTagSheetPresentation.leadingToolbarSpacing == 4)
    }

    @Test func diveMarineLifeTagPickerPresentation_filtersByCommonNameOrSubcategory() {
        let angelfish = MarineLife(
            uuid: "marine-life-french-angelfish",
            commonName: "French Angelfish",
            scientificName: "Pomacanthus paru",
            category: "fishes",
            subcategory: "angelfishes"
        )
        let grouper = MarineLife(
            uuid: "marine-life-grouper",
            commonName: "Black Grouper",
            scientificName: "Mycteroperca bonaci",
            category: "fishes",
            subcategory: "groupers"
        )
        let catalog = [angelfish, grouper]

        #expect(DiveMarineLifeTagPickerPresentation.filtering(catalog, query: "french").count == 1)
        #expect(DiveMarineLifeTagPickerPresentation.filtering(catalog, query: "angel").count == 1)
        #expect(DiveMarineLifeTagPickerPresentation.filtering(catalog, query: "groupers").count == 1)
        #expect(DiveMarineLifeTagPickerPresentation.filtering(catalog, query: "").count == 2)
    }

    @Test func diveMarineLifeTagPickerPresentation_filteredPickerRows_useIndexedSearch() {
        let cache = DiveMarineLifeTagPickerPresentation.CatalogCache.make(from: [
            MarineLife(
                uuid: "marine-life-french-angelfish",
                commonName: "French Angelfish",
                scientificName: "Pomacanthus paru",
                category: "fishes",
                subcategory: "angelfishes"
            ),
            MarineLife(
                uuid: "marine-life-grouper",
                commonName: "Black Grouper",
                scientificName: "Mycteroperca bonaci",
                category: "fishes",
                subcategory: "groupers"
            ),
        ])
        let allRows = DiveMarineLifeTagPickerPresentation.makePickerRows(
            snapshots: cache.snapshots,
            taggedUUIDs: [],
            unitSystem: .metric
        )
        let filtered = DiveMarineLifeTagPickerPresentation.filteredPickerRows(
            allRows: allRows,
            snapshots: cache.snapshots,
            searchableTextByUUID: cache.searchableTextByUUID,
            query: "grouper"
        )
        #expect(filtered.count == 1)
        #expect(filtered[0].marineLifeUUID == "marine-life-grouper")
    }

    @Test func diveMarineLifeTagPickerPresentation_rowMarkedTagged_updatesTaggedState() {
        let row = DiveMarineLifeTagPickerPresentation.RowDisplayData(
            marineLifeUUID: "marine-life-angelfish",
            commonName: "French Angelfish",
            trailingLabel: "Angelfishes",
            detailLine: "Pomacanthus paru",
            featureImageURL: "",
            featureImageResourceName: "",
            isTagged: false
        )
        let tagged = DiveMarineLifeTagPickerPresentation.rowMarkedTagged(row, isTagged: true)
        #expect(tagged.isTagged)
        #expect(tagged.marineLifeUUID == row.marineLifeUUID)
        #expect(tagged.commonName == row.commonName)
    }

    @Test func fieldGuideMarineLifeSearch_precomputedSearchText_matchesLegacyMatcher() {
        let angelfish = MarineLifeCatalogSnapshot(
            uuid: "marine-life-angelfish",
            commonName: "French Angelfish",
            scientificName: "Pomacanthus paru",
            category: "fish",
            subcategory: "disk-and-large-oval",
            featureImageURL: "",
            minSizeMeters: 0.2,
            maxSizeMeters: 0.4,
            avgDepthMeters: 12
        )
        let haystack = FieldGuideMarineLifeSearch.precomputedSearchText(for: angelfish)
        #expect(haystack.contains("french angelfish"))
        #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "french"))
        #expect(haystack.contains("pomacanthus"))
        #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "paru"))
        #expect(!haystack.contains("turtle"))
        #expect(!FieldGuideMarineLifeSearch.matches(angelfish, query: "turtle"))
    }

    @Test func fieldGuideMarineLifeSearch_matchesCommonScientificOrCategory() {
        let angelfish = MarineLifeCatalogSnapshot(
            uuid: "marine-life-angelfish",
            commonName: "French Angelfish",
            scientificName: "Pomacanthus paru",
            category: "fish",
            subcategory: "disk-and-large-oval",
            featureImageURL: "",
            minSizeMeters: 0.2,
            maxSizeMeters: 0.35,
            avgDepthMeters: 15
        )
        #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "french"))
        #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "pomacanthus"))
        #expect(FieldGuideMarineLifeSearch.matches(angelfish, query: "fish"))
        #expect(!FieldGuideMarineLifeSearch.matches(angelfish, query: "turtle"))
        #expect(FieldGuideMarineLifeSearch.filtering([angelfish], query: "paru").count == 1)
        #expect(FieldGuideMarineLifeSearch.filtering([angelfish], query: "").count == 1)
    }

    @Test func diveSiteMarineLifePresentation_sightedSpeciesLinks_dedupesAndSorts() {
        let siteID = UUID()
        let ownerID = UUID()
        let diveID = UUID()
        let angelfishUUID = "marine-life-angelfish"
        let rayUUID = "marine-life-ray"

        let angelfish = MarineLife(uuid: angelfishUUID, commonName: "French Angelfish")
        let ray = MarineLife(uuid: rayUUID, commonName: "Spotted Eagle Ray")

        let sightings = [
            SightingInstance(
                marineLifeUUID: angelfishUUID,
                sightingDateTime: Date(timeIntervalSince1970: 1_000_000),
                diveActivity: DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 1_000_000),
                    durationMinutes: 40,
                    maxDepthMeters: 20
                ),
                diveSite: DiveSite(siteName: "Salt Pier")
            ),
            SightingInstance(
                marineLifeUUID: angelfishUUID,
                sightingDateTime: Date(timeIntervalSince1970: 1_000_100),
                marineLife: angelfish
            ),
            SightingInstance(
                marineLifeUUID: rayUUID,
                sightingDateTime: Date(timeIntervalSince1970: 1_000_200),
                marineLife: ray
            ),
        ]
        sightings[0].diveSiteID = siteID
        sightings[0].diveActivityID = diveID
        sightings[1].diveSiteID = siteID
        sightings[1].diveActivityID = diveID
        sightings[2].diveSiteID = siteID
        sightings[2].diveActivityID = diveID

        let catalogByUUID = [
            angelfishUUID: angelfish.fieldGuideCatalogSnapshot,
            rayUUID: ray.fieldGuideCatalogSnapshot,
        ]

        let links = DiveSiteMarineLifePresentation.sightedSpeciesLinks(
            diveSiteID: siteID,
            ownerProfileID: ownerID,
            sightings: sightings,
            ownerDiveActivityIDs: [diveID],
            catalogByUUID: catalogByUUID
        )

        #expect(links.count == 2)
        #expect(links[0].displayName == "French Angelfish")
        #expect(links[1].displayName == "Spotted Eagle Ray")
    }

    @Test func diveSiteMarineLifePresentation_siteActivityLinks_filtersBySiteAndSortsNewestFirst() {
        let siteID = UUID()
        let otherSiteID = UUID()
        let ownerID = UUID()
        let olderID = UUID()
        let newerID = UUID()

        let links = DiveSiteMarineLifePresentation.siteActivityLinks(
            diveSiteID: siteID,
            ownerProfileID: ownerID,
            activities: [
                DiveActivitySightingLinkSnapshot(
                    id: olderID,
                    diveSiteID: siteID,
                    resolvedSiteName: "Salt Pier",
                    startTime: Date(timeIntervalSince1970: 1_000_000),
                    timeZoneOffsetSeconds: nil
                ),
                DiveActivitySightingLinkSnapshot(
                    id: newerID,
                    diveSiteID: siteID,
                    resolvedSiteName: "Salt Pier",
                    startTime: Date(timeIntervalSince1970: 2_000_000),
                    timeZoneOffsetSeconds: nil
                ),
                DiveActivitySightingLinkSnapshot(
                    id: UUID(),
                    diveSiteID: otherSiteID,
                    resolvedSiteName: "Other Site",
                    startTime: Date(timeIntervalSince1970: 3_000_000),
                    timeZoneOffsetSeconds: nil
                ),
            ]
        )

        #expect(links.map(\.id) == [newerID, olderID])
        #expect(links.allSatisfy { $0.title == "Salt Pier" })
    }

    @Test @MainActor func exploreDiveSiteMediaPresentation_includesAllDiveMediaAtSite_notOnlySightingLinked() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let ownerID = UUID()
        let siteID = UUID()
        let otherSiteID = UUID()

        let diveAtSite = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 2_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        diveAtSite.ownerProfileID = ownerID
        diveAtSite.diveSiteID = siteID
        context.insert(diveAtSite)

        let diveElsewhere = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_000),
            durationMinutes: 35,
            maxDepthMeters: 15
        )
        diveElsewhere.ownerProfileID = ownerID
        diveElsewhere.diveSiteID = otherSiteID
        context.insert(diveElsewhere)

        let sightingLinkedPhoto = DiveMediaPhoto(
            sortOrder: 0,
            capturedAt: Date(timeIntervalSince1970: 2_100),
            dive: diveAtSite
        )
        let unattachedDivePhoto = DiveMediaPhoto(
            sortOrder: 1,
            capturedAt: Date(timeIntervalSince1970: 2_200),
            dive: diveAtSite
        )
        let otherSitePhoto = DiveMediaPhoto(
            sortOrder: 0,
            capturedAt: Date(timeIntervalSince1970: 3_100),
            dive: diveElsewhere
        )
        diveAtSite.mediaPhotos = [sightingLinkedPhoto, unattachedDivePhoto]
        diveElsewhere.mediaPhotos = [otherSitePhoto]
        context.insert(sightingLinkedPhoto)
        context.insert(unattachedDivePhoto)
        context.insert(otherSitePhoto)

        let sighting = SightingInstance(
            marineLifeUUID: "species-site-media",
            sightingDateTime: Date(timeIntervalSince1970: 2_100),
            diveActivity: diveAtSite,
            mediaPhoto: sightingLinkedPhoto
        )
        context.insert(sighting)
        try context.save()

        let siteActivities = ExploreDiveSiteMediaPresentation.siteDiveActivities(
            diveSiteID: siteID,
            ownerProfileID: ownerID,
            activities: [diveAtSite, diveElsewhere]
        )
        #expect(siteActivities.map(\.id) == [diveAtSite.id])

        let linked = ExploreDiveSiteMediaPresentation.linkedMediaItems(from: siteActivities)
        let photos = ExploreDiveSiteMediaPresentation.mediaPhotos(
            siteActivities: siteActivities,
            linkedItems: linked
        )
        #expect(photos.map(\.id) == [sightingLinkedPhoto.id, unattachedDivePhoto.id])
        #expect(!photos.contains(where: { $0.id == otherSitePhoto.id }))
    }

    @Test func activityTagStore_normalizedName_collapsesWhitespaceAndCase() {
        #expect(ActivityTagStore.normalizedName(from: "  Night  Dive  ") == "night dive")
        #expect(ActivityTagStore.displayName(from: "  Wreck  ") == "Wreck")
    }

    @Test @MainActor func activityTagStore_findOrCreate_dedupesPerOwner() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let ownerID = UUID()

        let first = try ActivityTagStore.findOrCreateTag(
            rawName: "Night Dive",
            ownerProfileID: ownerID,
            modelContext: context
        )
        let second = try ActivityTagStore.findOrCreateTag(
            rawName: "night dive",
            ownerProfileID: ownerID,
            modelContext: context
        )
        #expect(first?.id == second?.id)

        let allTags = try ActivityTagStore.fetchTags(ownerProfileID: ownerID, modelContext: context)
        #expect(allTags.count == 1)
        #expect(allTags[0].name == "Night Dive")
    }

    @Test @MainActor func activityTagStore_applyAndRemove_updatesDiveMembership() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let ownerID = UUID()
        let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
        dive.ownerProfileID = ownerID
        context.insert(dive)

        let tag = try ActivityTagStore.findOrCreateTag(
            rawName: "Training",
            ownerProfileID: ownerID,
            modelContext: context
        )
        #expect(tag != nil)

        ActivityTagStore.applyTag(tag!, to: dive)
        #expect(ActivityTagStore.sortedTags(on: dive).map(\.name) == ["Training"])
        #expect(ActivityTagStore.summaryLine(for: dive) == "Training")

        ActivityTagStore.removeTag(tag!, from: dive)
        #expect(dive.activityTags.isEmpty)
    }

    @Test func tripPlannerPresentation_pageTitleAndExploreIcon() {
        #expect(TripPlannerPresentation.pageTitle == "Trips")
        #expect(TripPlannerPresentation.exploreChromeAccessibilityLabel == "Plan a trip")
        #expect(TripPlannerPresentation.exploreChromeSystemImage == "airplane")
        #expect(TripPlannerPresentation.newTripSheetTitle == "Plan a trip")
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

    @Test func diveTripFormValues_parsesCountriesAndValidatesSave() {
        var form = DiveTripFormValues()
        #expect(!form.canSave)

        form.countriesText = " Bonaire , Curaçao "
        #expect(form.parsedCountries == ["Bonaire", "Curaçao"])
        #expect(form.canSave)

        form = DiveTripFormValues()
        form.title = "  Reef week  "
        #expect(form.trimmedTitle == "Reef week")
        #expect(form.canSave)
        #expect(form.parsedCountries.isEmpty)
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
        form.title = "Bonaire 2026"
        form.countriesText = "Curaçao"
        form.apply(to: trip, plannedSites: [])

        #expect(trip.displayTitle == "Bonaire 2026")
        #expect(trip.countries == ["Curaçao"])
    }

    @Test @MainActor func diveTripDeletion_deletePermanentlyRemovesTrip() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let profile = UserProfile(appleUserIdentifier: "trip-delete", displayName: "Diver")
        context.insert(profile)

        let trip = DiveTrip(
            startDate: .now,
            endDate: .now,
            countries: ["Bonaire"],
            title: "Delete me",
            owner: profile
        )
        context.insert(trip)
        try context.save()

        try DiveTripDeletion.deletePermanently(trip, modelContext: context)

        let remaining = try context.fetch(FetchDescriptor<DiveTrip>())
        #expect(remaining.isEmpty)
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

    @Test @MainActor func tripDetailContentPager_activeTripPages() {
        #expect(TripDetailContentPagerPresentation.pageCount(hasStarted: true) == 5)
        #expect(
            TripDetailContentPagerPresentation.pages(hasStarted: true) == [
                .stats, .activities, .marineLife, .buddies, .media,
            ]
        )
        #expect(TripDetailContentPagerPresentation.defaultPage(hasStarted: true) == .stats)
        #expect(TripDetailContentPagerPresentation.accessibilityIdentifier(for: .stats) == "TripDetail.ContentPager.Stats")
        #expect(TripDetailContentPagerPresentation.accessibilityIdentifier(for: .media) == "TripDetail.ContentPager.Media")
    }

    @Test @MainActor func tripDetailContentPager_usesStaticLayoutForStatsAndMedia() {
        #expect(TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .stats))
        #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .media))
        #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .marineLife))
        #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .activities))
        #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .plannedSites))
        #expect(!TripDetailContentPagerPresentation.usesStaticPagerLayout(for: .buddies))
        #expect(TripDetailContentPagerPresentation.staticPagerContentAlignment(for: .stats) == .center)
        #expect(TripDetailContentPagerPresentation.staticPagerContentAlignment(for: .media) == .top)
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

    @Test @MainActor func diveTripPlannedBuddyLinking_addsAndRemovesBuddies() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "owner-planned-buddies", displayName: "Alex")
        let buddy = DiveBuddy(displayName: "Jordan", owner: owner)
        let trip = DiveTrip(
            startDate: Date(timeIntervalSince1970: 2_000_000),
            endDate: Date(timeIntervalSince1970: 2_086_400),
            owner: owner
        )
        context.insert(owner)
        context.insert(buddy)
        context.insert(trip)

        #expect(DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).isEmpty)
        #expect(!DiveTripPlannedBuddyLinking.isBuddyOnTrip(buddyID: buddy.id, trip: trip))

        DiveTripPlannedBuddyLinking.addBuddy(buddy, to: trip, modelContext: context)
        #expect(DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).map(\.id) == [buddy.id])
        #expect(DiveTripPlannedBuddyLinking.isBuddyOnTrip(buddyID: buddy.id, trip: trip))

        DiveTripPlannedBuddyLinking.toggleBuddy(buddy, on: trip, modelContext: context)
        #expect(DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).isEmpty)
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
        #expect(members[1].id == buddyID)
        #expect(TripDetailPlannedBuddyPresentation.subtitle(for: members[0]) == "You")
        #expect(TripDetailPlannedBuddyPresentation.subtitle(for: members[1]) == "On this trip")
    }

    @Test func tripDetailPlannedBuddyPresentation_usesActiveTripBuddyGridMetrics() {
        #expect(TripDetailBuddiesPresentation.gridColumnCount == 3)
        #expect(TripDetailBuddiesPresentation.avatarDiameter == 64)
        #expect(TripDetailPlannedBuddyPresentation.ownerSubtitle == "You")
        #expect(TripDetailPlannedBuddyPresentation.buddySubtitle == "On this trip")
    }

    @Test func tripShareCardPresentation_buildsTemporaryPNGFileName() {
        let url = TripShareCardPresentation.temporaryPNGURL(tripTitle: "Bonaire 2026")
        #expect(url.pathExtension == "png")
        #expect(url.lastPathComponent.contains("GoDive-Trip-Bonaire 2026"))
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
        #expect(TripShareCardPresentation.logoImageName == "GoDiveLogoPin")
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
        completedAtPlanned.diveSite = plannedAndDone
        completedAtPlanned.diveSiteID = plannedAndDone.id

        let completedUnplanned = DiveActivity(
            source: .manual,
            startTime: .now,
            durationMinutes: 40,
            maxDepthMeters: 18,
            entryCoordinate: DiveCoordinate(latitude: 12.111, longitude: -68.222)
        )

        let pins = TripDetailMapPresentation.pins(
            plannedSites: [plannedOnly, plannedAndDone],
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

    @MainActor
    @Test func tripHeroMediaSession_reusesRandomPickForTrip() {
        TripHeroMediaSession.resetForTesting()
        let tripID = UUID()
        let first = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 100))
        let second = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 200))
        let photos = [first, second]

        let initial = TripHeroMediaSession.resolvedRandomHeroMediaID(
            tripID: tripID,
            in: photos
        )
        #expect(initial == first.id || initial == second.id)

        let again = TripHeroMediaSession.resolvedRandomHeroMediaID(
            tripID: tripID,
            in: photos
        )
        #expect(again == initial)

        TripHeroMediaSession.resetForTesting()
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

    @Test @MainActor func logbookRoute_includesCatalogSiteDetail() {
        let siteID = UUID()
        #expect(LogbookRoute.diveSite(siteID) == LogbookRoute.diveSite(siteID))
        #expect(LogbookRoute.diveSite(siteID) != LogbookRoute.tripDetail(siteID))
        #expect(LogbookRoute.tripPlanner != LogbookRoute.addActivity)
    }

    @Test @MainActor func tripStackNavigationRoutes_tripDetailPrecedesSiteOnStack() {
        let tripID = UUID()
        let siteID = UUID()
        let mediaID = UUID()

        let exploreStack: [ExploreRoute] = [
            .tripPlanner,
            .tripDetail(tripID),
            .siteDetail(siteID),
        ]
        #expect(exploreStack.count == 3)
        #expect(exploreStack[1] == .tripDetail(tripID))

        let homeStack: [HomeRoute] = [
            .profile,
            .tripPlanner,
            .tripDetail(tripID),
            .diveSite(siteID),
        ]
        #expect(homeStack[2] == .tripDetail(tripID))

        let logbookStack: [LogbookRoute] = [
            .tripDetail(tripID),
            .diveSite(siteID),
        ]
        #expect(logbookStack[0] == .tripDetail(tripID))

        #expect(ExploreRoute.tripDetailMedia(tripID: tripID, mediaID: mediaID)
            == ExploreRoute.tripDetailMedia(tripID: tripID, mediaID: mediaID))
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

    @Test func tripDetailMediaGalleryPresentation_mediaPositionLabel_usesNumericOnlyFormat() {
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

    @Test func exploreDiveSiteListSearch_matchesNameAndPlace() {
        let site = DiveSite(siteName: "Salt Pier", country: "Bonaire", region: "Caribbean")
        #expect(ExploreDiveSiteListSearch.matches(site, query: "salt"))
        #expect(ExploreDiveSiteListSearch.matches(site, query: "bonaire"))
        #expect(ExploreDiveSiteListSearch.matches(site, query: "caribbean"))
        #expect(!ExploreDiveSiteListSearch.matches(site, query: "aruba"))
        #expect(ExploreDiveSiteListSearch.filtering([site], query: "pier").count == 1)
    }

    @Test func fieldGuidePresentation_listDetailLine_joinsScientificNameAndSizeDepth() {
        #expect(
            FieldGuidePresentation.listDetailLine(
                scientificName: "Pomacanthus paru",
                sizeDepthLine: "up to 18 in · avg 45 ft"
            ) == "Pomacanthus paru · up to 18 in · avg 45 ft"
        )
        #expect(
            FieldGuidePresentation.listDetailLine(
                scientificName: "",
                sizeDepthLine: "avg 15 m"
            ) == "avg 15 m"
        )
        #expect(FieldGuidePresentation.listTrailingLabel(category: "Fish") == "Fish")
        #expect(FieldGuidePresentation.listTrailingLabel(category: "  ") == "—")
    }

    @Test func fieldGuideTaggedMediaPresentation_galleryRefreshToken_changesWhenSightingsChange() {
        let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
        let firstPhoto = DiveMediaPhoto(capturedAt: .now, dive: dive)
        let secondPhoto = DiveMediaPhoto(capturedAt: .now, dive: dive)
        let first = SightingInstance(
            marineLifeUUID: "a",
            sightingDateTime: .now,
            diveActivity: dive,
            mediaPhoto: firstPhoto
        )
        let second = SightingInstance(
            marineLifeUUID: "a",
            sightingDateTime: .now,
            diveActivity: dive,
            mediaPhoto: secondPhoto
        )
        let diveID = dive.id
        let tokenA = FieldGuideTaggedMediaPresentation.galleryRefreshToken(
            sightings: [first],
            ownerDiveActivityIDs: [diveID]
        )
        let tokenB = FieldGuideTaggedMediaPresentation.galleryRefreshToken(
            sightings: [first, second],
            ownerDiveActivityIDs: [diveID]
        )
        #expect(tokenA != tokenB)
    }

    @Test @MainActor func fieldGuideTaggedMediaPresentation_resolvedTaggedMediaPhotos_fetchesByMediaPhotoID() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
        context.insert(dive)
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 5_000), dive: dive)
        context.insert(media)

        let sighting = SightingInstance(
            marineLifeUUID: "species-fetch-by-id",
            sightingDateTime: Date(timeIntervalSince1970: 5_000),
            diveActivity: dive
        )
        sighting.mediaPhoto = nil
        sighting.mediaPhotoID = media.id
        context.insert(sighting)
        try context.save()

        let photos = FieldGuideTaggedMediaPresentation.resolvedTaggedMediaPhotos(
            sightings: [sighting],
            ownerDiveActivityIDs: [dive.id],
            modelContext: context
        )
        #expect(photos.count == 1)
        #expect(photos[0].id == media.id)
    }

    @Test func fieldGuideTaggedMediaPresentation_collectsUniqueOwnerPhotos_oldestCaptureFirst() {
        let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
        let otherDive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
        let older = DiveMediaPhoto(
            capturedAt: Date(timeIntervalSince1970: 1_000),
            dive: dive
        )
        let newer = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 2_000), dive: dive)
        let otherDivePhoto = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_000), dive: otherDive)

        let speciesUUID = "marine-life-tagged-media"
        let sightings = [
            SightingInstance(
                marineLifeUUID: speciesUUID,
                sightingDateTime: Date(timeIntervalSince1970: 2_000),
                diveActivity: dive,
                mediaPhoto: newer
            ),
            SightingInstance(
                marineLifeUUID: speciesUUID,
                sightingDateTime: Date(timeIntervalSince1970: 1_500),
                diveActivity: dive,
                mediaPhoto: older
            ),
            SightingInstance(
                marineLifeUUID: speciesUUID,
                sightingDateTime: Date(timeIntervalSince1970: 1_600),
                diveActivity: dive,
                mediaPhoto: older
            ),
            SightingInstance(
                marineLifeUUID: speciesUUID,
                sightingDateTime: Date(timeIntervalSince1970: 3_000),
                diveActivity: otherDive,
                mediaPhoto: otherDivePhoto
            ),
        ]

        let photos = FieldGuideTaggedMediaPresentation.taggedMediaPhotos(
            sightings: sightings,
            ownerDiveActivityIDs: [dive.id]
        )
        #expect(photos.map(\.id) == [older.id, newer.id])

        let offsets = FieldGuideTaggedMediaPresentation.timeZoneOffsetByMediaID(
            sightings: sightings,
            ownerDiveActivityIDs: [dive.id],
            timeZoneOffsetByActivityID: [dive.id: -14_400]
        )
        #expect(offsets[older.id] == -14_400)
        #expect(offsets[newer.id] == -14_400)
        #expect(offsets[otherDivePhoto.id] == nil)
    }

    @Test func fieldGuidePresentation_sightedActivityLinks_sortsNewestFirstAndFormatsTitle() {
        let olderID = UUID()
        let newerID = UUID()
        let links = FieldGuidePresentation.sightedActivityLinks(
            activityIDs: [olderID, newerID],
            activities: [
                DiveActivitySightingLinkSnapshot(
                    id: olderID,
                    diveSiteID: nil,
                    resolvedSiteName: "Salt Pier",
                    startTime: Date(timeIntervalSince1970: 1_000_000),
                    timeZoneOffsetSeconds: nil
                ),
                DiveActivitySightingLinkSnapshot(
                    id: newerID,
                    diveSiteID: nil,
                    resolvedSiteName: nil,
                    startTime: Date(timeIntervalSince1970: 2_000_000),
                    timeZoneOffsetSeconds: nil
                ),
            ]
        )

        #expect(links.count == 2)
        #expect(links[0].id == newerID)
        #expect(links[0].title == "New Dive")
        #expect(links[1].id == olderID)
        #expect(links[1].title == "Salt Pier")
        #expect(!links[0].dateText.isEmpty)
    }

    @Test func fieldGuideTaggedMediaPresentation_linkedMediaItems_mapsPhotosToParentDives() {
        let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
        let photo = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 1_000), dive: dive)
        let sighting = SightingInstance(
            marineLifeUUID: "species-linked-media",
            sightingDateTime: Date(timeIntervalSince1970: 1_000),
            diveActivity: dive,
            mediaPhoto: photo
        )
        sighting.mediaPhotoID = photo.id

        let linked = FieldGuideTaggedMediaPresentation.linkedMediaItems(
            sightings: [sighting],
            ownerDiveActivityIDs: [dive.id],
            mediaItems: [photo]
        )
        #expect(linked.count == 1)
        #expect(linked[0].id == photo.id)
        #expect(linked[0].diveActivityID == dive.id)
    }

    @Test func diveSiteFormValidation_sanitizedPlaceField_trimsWhitespace() {
        #expect(DiveSiteFormValidation.sanitizedPlaceField("  Bonaire  ") == "Bonaire")
        #expect(DiveSiteFormValidation.sanitizedPlaceField("   ") == "")
    }

    @Test func diveActivityManualCreation_makeBlank_usesManualSourceAndNoSourceDiveId() {
        let dive = DiveActivityManualCreation.makeBlankActivity(
            defaultTank: DefaultTankSize.al80.specification
        )
        #expect(dive.source == .manual)
        #expect(dive.sourceDiveId == nil)
        #expect(dive.durationMinutes == 0)
        #expect(dive.maxDepthMeters == 0)
        #expect(dive.profilePoints.isEmpty)
        #expect(dive.tankMaterial == "aluminum")
    }

    @Test func diveActivityManualCreation_makeBlank_appliesStartTimeAndSiteName() {
        let when = Date(timeIntervalSince1970: 1_700_000_000)
        let dive = DiveActivityManualCreation.makeBlankActivity(
            startTime: when,
            siteName: "Salt Pier"
        )
        #expect(dive.startTime == when)
        #expect(dive.siteName == "Salt Pier")
    }

    @Test @MainActor
    func diveActivityManualCreation_persist_linksExistingCatalogSite() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let profile = UserProfile(appleUserIdentifier: "manual-existing-site", displayName: "Diver")
        context.insert(profile)

        let catalogSite = DiveSite(siteName: "Salt Pier", country: "Bonaire", waterType: .saltwater)
        context.insert(catalogSite)
        try context.save()

        let dive = DiveActivityManualCreation.makeBlankActivity()
        let outcome = DiveActivityManualCreation.persist(
            dive,
            siteSelection: .existingSite(id: catalogSite.id),
            modelContext: context,
            owner: profile
        )
        #expect(outcome.primaryInsertedDiveId == dive.id)
        #expect(dive.diveSite?.id == catalogSite.id)
        #expect(dive.diveSiteID == catalogSite.id)
        #expect(dive.resolvedDiveWaterType == .saltwater)
    }

    @Test @MainActor
    func diveActivityManualCreation_persist_createsAndLinksNewCatalogSite() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let profile = UserProfile(appleUserIdentifier: "manual-new-site", displayName: "Diver")
        context.insert(profile)
        try context.save()

        let draft = DiveSiteFormDraft(
            siteName: "Cenote Dos Ojos",
            country: "Mexico",
            region: "Quintana Roo",
            bodyOfWater: "",
            latitudeText: "20.32480",
            longitudeText: "-87.39320",
            waterType: .freshwater
        )
        let dive = DiveActivityManualCreation.makeBlankActivity()
        let outcome = DiveActivityManualCreation.persist(
            dive,
            siteSelection: .newSite(draft),
            modelContext: context,
            owner: profile
        )
        #expect(outcome.primaryInsertedDiveId == dive.id)
        #expect(dive.diveSite?.siteName == "Cenote Dos Ojos")
        #expect(dive.diveSite?.resolvedWaterType == .freshwater)
        #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 1)
    }

    @Test @MainActor
    func diveActivityManualCreation_persist_insertsOwnedDive() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let profile = UserProfile(appleUserIdentifier: "manual-create-test", displayName: "Diver")
        context.insert(profile)
        try context.save()

        let dive = DiveActivityManualCreation.makeBlankActivity()
        let outcome = DiveActivityManualCreation.persist(dive, modelContext: context, owner: profile)
        #expect(outcome.primaryInsertedDiveId == dive.id)
        #expect(outcome.userMessage.hasPrefix(DiveActivityManualCreation.successMessagePrefix))

        let stored = try DiveActivityOwnership.activities(forOwnerProfileID: profile.id, modelContext: context)
        #expect(stored.count == 1)
        #expect(stored.first?.source == .manual)
        #expect(stored.first?.sourceDiveId == nil)
        #expect(stored.first?.ownerProfileID == profile.id)
    }

    @Test func diveActivityOverviewPanelMetrics_panelContentTopPadding_matchesSheetToken() {
        #expect(DiveActivityOverviewPanelMetrics.panelContentTopPadding == AppTheme.Sheet.contentTopSpacing)
    }

    @Test func diveActivityEditableCatalog_sourceAndImportFieldsAreNotEditable() {
        #expect(!DiveActivityEditableCatalog.isEditable(.source))
        #expect(!DiveActivityEditableCatalog.isEditable(.sourceDiveId))
        #expect(!DiveActivityEditableCatalog.isEditable(.rawImportVersion))
        let activity = DiveActivity(
            source: .garminMK3,
            sourceDiveId: "fit-123",
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18,
            rawImportVersion: "FIT 1.0"
        )
        let sourceSection = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
            .first { $0.id == "source" }!
        #expect(DiveActivityEditableCatalog.editableFields(in: sourceSection, for: activity).isEmpty)
        #expect(DiveActivityEditableCatalog.headerAction(for: sourceSection, activity: activity) == .none)
    }

    @Test func diveActivityFieldEditing_applyDraft_doesNotChangeSourceOrImportVersion() {
        let activity = DiveActivity(
            source: .macDive,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18,
            rawImportVersion: "UDDF 3.2"
        )
        var draft = DiveActivityFieldEditDraft()
        draft.source = .manual
        draft.text = "Edited"
        DiveActivityFieldEditing.applyDraft(draft, for: .source, to: activity, displayUnits: .metric)
        DiveActivityFieldEditing.applyDraft(draft, for: .rawImportVersion, to: activity, displayUnits: .metric)
        #expect(activity.source == .macDive)
        #expect(activity.rawImportVersion == "UDDF 3.2")
    }

    @Test func diveActivityEditableCatalog_sacAndRmvAreNotEditable() {
        #expect(!DiveActivityEditableCatalog.isEditable(.avgSAC))
        #expect(!DiveActivityEditableCatalog.isEditable(.avgRMV))
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18,
            avgSAC: 20,
            avgRMV: 16
        )
        let consumption = DiveActivityEditableCatalog.sections(for: .tank, detent: .medium)
            .first { $0.id == "consumption" }!
        #expect(DiveActivityEditableCatalog.editableFields(in: consumption, for: activity).isEmpty)
        #expect(DiveActivityEditableCatalog.headerAction(for: consumption, activity: activity) == .none)
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

    @Test func diveActivityEditableCatalog_sectionHeaderActions() {
        let manualDive = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        let mapSections = DiveActivityEditableCatalog.sections(for: .map, detent: .large)
        let diveConditions = mapSections.first { $0.id == "diveConditions" }!
        let buddies = mapSections.first { $0.id == "buddies" }!
        let equipment = DiveActivityEditableCatalog.sections(for: .tank, detent: .medium)
            .first { $0.id == "equipment" }!

        #expect(DiveActivityEditableCatalog.headerAction(for: diveConditions, activity: manualDive) == .editForm)
        #expect(DiveActivityEditableCatalog.headerAction(for: buddies, activity: manualDive) == .add)
        #expect(DiveActivityEditableCatalog.headerAction(for: equipment, activity: manualDive) == .manageEquipment)

        #expect(DiveActivityEditableCatalog.isEditable(.durationMinutes, for: manualDive))
        #expect(!DiveActivityEditableCatalog.isEditable(.durationMinutes, for: DiveActivity(
            source: .garminMK3,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18
        )))
        #expect(DiveActivityEditableCatalog.isEditable(.startTime, for: manualDive))
        #expect(DiveActivityEditableCatalog.isEditable(.diveNumber, for: manualDive))
    }

    @Test func diveActivityEditableCatalog_overviewPanelHidesDiveSummaryAndTankDiagnostics() {
        let mapSections = DiveActivityEditableCatalog.sections(for: .map, detent: .large)
        #expect(!mapSections.contains { $0.id == "dive" })

        let tankMedium = DiveActivityEditableCatalog.sections(for: .tank, detent: .medium)
        let tankLarge = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
        #expect(!tankMedium.contains { $0.id == "profileGas" })
        #expect(!tankLarge.contains { $0.id == "profileGas" })
        #expect(!tankLarge.contains { $0.id == "record" })
    }

    @Test func diveActivityEditableCatalog_mapStatsBoxEdit_resolvesHiddenDiveSection() {
        let manual = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        #expect(DiveActivityEditableCatalog.mapStatsBoxShowsEditButton(for: manual))

        let context = DiveActivitySectionEditContext(
            sectionID: DiveActivityEditableCatalog.mapDiveSummarySection.id,
            tab: .map,
            panelDetent: .medium
        )
        let section = context.resolvedSection()
        #expect(section?.id == "dive")
        #expect(section?.fieldIDs.contains(.maxDepthMeters) == true)
        #expect(
            DiveActivityEditableCatalog.editableFields(in: DiveActivityEditableCatalog.mapDiveSummarySection, for: manual)
                .contains(.durationMinutes)
        )
    }

    @Test func diveActivityEditableCatalog_manualEntryOnlyFields_blockedForImports() {
        let imported = DiveActivity(
            source: .macDive,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        for field in DiveActivityEditableCatalog.manualEntryOnlyFieldIDs {
            #expect(!DiveActivityEditableCatalog.isEditable(field, for: imported))
        }
        let manual = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        for field in DiveActivityEditableCatalog.manualEntryOnlyFieldIDs {
            #expect(DiveActivityEditableCatalog.isEditable(field, for: manual))
        }
    }

    @Test func diveActivityFieldEditing_applyDraft_skipsManualEntryOnlyFieldsOnImports() {
        let activity = DiveActivity(
            source: .garminMK3,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        var draft = DiveActivityFieldEditDraft()
        draft.text = "52"
        DiveActivityFieldEditing.applyDraft(draft, for: .durationMinutes, to: activity, displayUnits: .metric)
        #expect(activity.durationMinutes == 40)
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

    @Test func diveImportedLocationParsing_splitsCommaSeparatedRegionAndCountry() {
        let fields = DiveImportedLocationParsing.placeFields(
            fromLocationName: " Bonaire , Caribbean Netherlands "
        )
        #expect(fields.region == "Bonaire")
        #expect(fields.country == "Caribbean Netherlands")
    }

    @Test func diveImportedLocationParsing_singleSegmentIsRegion() {
        let fields = DiveImportedLocationParsing.placeFields(fromLocationName: "Bonaire")
        #expect(fields.region == "Bonaire")
        #expect(fields.country == "")
    }

    @Test func diveActivityMapSitePrompt_draft_prefillsPlaceFromImportLocation() {
        let activity = DiveActivity(
            source: .macDive,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18,
            siteName: "Salt Pier",
            locationName: "Bonaire, Caribbean Netherlands"
        )
        let draft = DiveActivityMapSitePrompt.draft(from: activity)
        #expect(draft.siteName == "Salt Pier")
        #expect(draft.region == "Bonaire")
        #expect(draft.country == "Caribbean Netherlands")
    }

    @Test func diveActivityMapSitePrompt_draft_keepsCatalogPlaceWhenEditing() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 1,
            maxDepthMeters: 1,
            locationName: "Ignored, Place"
        )
        let site = DiveSite(
            siteName: "Catalog Reef",
            country: "Mexico",
            region: "Baja",
            bodyOfWater: "Sea of Cortez",
            latCoords: 24.5,
            longCoords: -110.2
        )
        let draft = DiveActivityMapSitePrompt.draft(from: activity, catalogSite: site)
        #expect(draft.siteName == "Catalog Reef")
        #expect(draft.country == "Mexico")
        #expect(draft.region == "Baja")
        #expect(draft.bodyOfWater == "Sea of Cortez")
    }

    @Test func diveActivityMapSitePrompt_draft_fillsEmptyCatalogPlaceFromImport() {
        let activity = DiveActivity(
            source: .macDive,
            startTime: Date(),
            durationMinutes: 1,
            maxDepthMeters: 1,
            locationName: "Bonaire, Caribbean Netherlands"
        )
        let site = DiveSite(siteName: "Salt Pier")
        let draft = DiveActivityMapSitePrompt.draft(from: activity, catalogSite: site)
        #expect(draft.region == "Bonaire")
        #expect(draft.country == "Caribbean Netherlands")
    }

    @Test func diveActivityEditableCatalog_mapDiveConditions_mergesWaterTempAndConditions() {
        let mapSections = DiveActivityEditableCatalog.sections(for: .map, detent: .large)
        #expect(mapSections.contains { $0.id == "diveConditions" && $0.title == "Dive Conditions" })
        #expect(!mapSections.contains { $0.id == "environment" })
        #expect(!mapSections.contains { $0.id == "conditions" })
        let diveConditions = mapSections.first { $0.id == "diveConditions" }
        #expect(diveConditions?.fieldIDs.contains(.waterTempAvgCelsius) == true)
        #expect(diveConditions?.fieldIDs.contains(.diveVisibility) == true)
    }

    @Test func diveActivityEditableCatalog_mapAndTankSectionsAreDistinct() {
        let mapIDs = Set(
            DiveActivityEditableCatalog.sections(for: .map, detent: .large).flatMap(\.fieldIDs)
        )
        let tankIDs = Set(
            DiveActivityEditableCatalog.sections(for: .tank, detent: .large).flatMap(\.fieldIDs)
        )
        #expect(!mapIDs.contains(.siteName))
        #expect(!mapIDs.contains(.locationName))
        #expect(!mapIDs.contains(.source))
        #expect(!mapIDs.contains(.recordID))
        #expect(!mapIDs.contains(.diveOperatorName))
        #expect(mapIDs.contains(.notes))
        #expect(!mapIDs.contains(.tankPressureStartPSI))
        #expect(tankIDs.contains(.tankPressureStartPSI))
        #expect(tankIDs.contains(.source))
        #expect(!tankIDs.contains(.recordID))
        #expect(tankIDs.contains(.diveOperatorName))
        #expect(!tankIDs.contains(.startTime))
    }

    @Test func diveActivityEditableCatalog_tankLargeDetentSections_filterAtMedium() {
        let medium = DiveActivityEditableCatalog.sections(for: .tank, detent: .medium)
        let large = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
        #expect(!medium.contains { $0.id == "operator" })
        #expect(!medium.contains { $0.id == "source" })
        #expect(large.contains { $0.id == "operator" })
        #expect(large.contains { $0.id == "source" })
    }

    @Test func diveActivityFieldValueParsing_depthAndPressureRespectDisplayUnits() {
        #expect(DiveActivityFieldValueParsing.parseDepthMeters("30", displayUnits: .metric) == 30)
        #expect(
            abs((DiveActivityFieldValueParsing.parseDepthMeters("100", displayUnits: .imperial) ?? 0) - 30.48) < 0.1
        )
        #expect(DiveActivityFieldValueParsing.parsePressurePSI("200", displayUnits: .imperial) == 200)
        #expect(
            abs((DiveActivityFieldValueParsing.parsePressurePSI("200", displayUnits: .metric) ?? 0) - 2900.75) < 1
        )
    }

    @Test func diveActivityFieldEditing_applyDraft_updatesDuration() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        var draft = DiveActivityFieldEditDraft()
        draft.text = "52"
        DiveActivityFieldEditing.applyDraft(draft, for: .durationMinutes, to: activity, displayUnits: .metric)
        #expect(activity.durationMinutes == 52)
    }

    @Test func diveSignatureDataFormatting_emptyOrMissingIsNotDisplayable() {
        #expect(!DiveSignatureDataFormatting.hasDisplayableContent(nil))
        #if canImport(PencilKit)
        #expect(!DiveSignatureDataFormatting.hasDisplayableContent(PKDrawing().dataRepresentation()))
        #endif
    }

    @Test func diveActivityFieldEditing_signatureDisplayValue_usesPlaceholderWhenEmpty() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        let empty = DiveActivityFieldEditing.displayValue(
            for: .diveSignature,
            activity: activity,
            displayUnits: .metric,
            profileGasStats: .init(sampleCount: 0, minPSI: 0, maxPSI: 0)
        )
        #expect(empty == "—")
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

        DiveActivitySiteAssociation.applyBestMatch(to: activity, catalogSites: [catalog])
        #expect(activity.diveSite?.id == catalog.id)
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
        #expect(activity.diveSite == nil)
        #expect(activity.entryCoordinate == nil)
        #expect(activity.siteCoordinate == nil)
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

    @Test func exploreCatalogMapPresentation_plottableSites_filtersInvalidCoordinates() {
        let reef = DiveSite(siteName: "Reef", latCoords: 12.083, longCoords: -68.283)
        let missing = DiveSite(siteName: "No GPS")
        let nullIsland = DiveSite(siteName: "Zero", latCoords: 0, longCoords: 0)

        let plotted = ExploreCatalogMapPresentation.plottableSites(from: [reef, missing, nullIsland])

        #expect(plotted.count == 1)
        #expect(plotted[0].id == reef.id)
        #expect(plotted[0].siteName == "Reef")
        #expect(plotted[0].coordinate.latitude == 12.083)
    }

    @Test func exploreCatalogMapPresentation_region_fitsMultipleSites() {
        let sites = [
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "South",
                coordinate: DiveCoordinate(latitude: 10, longitude: -70)
            ),
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "North",
                coordinate: DiveCoordinate(latitude: 14, longitude: -66)
            ),
        ]

        let region = ExploreCatalogMapPresentation.region(for: sites)

        #expect(region != nil)
        #expect(abs(region!.center.latitude - 12) < 0.001)
        #expect(abs(region!.center.longitude - (-68)) < 0.001)
        #expect(region!.span.latitudeDelta >= 0.04)
        #expect(region!.span.longitudeDelta >= 0.04)
    }

    @Test func exploreCatalogMapPresentation_boundingRegion_matchesMapKitRegion() {
        let sites = [
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "South",
                coordinate: DiveCoordinate(latitude: 10, longitude: -70)
            ),
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "North",
                coordinate: DiveCoordinate(latitude: 14, longitude: -66)
            ),
        ]

        let bounding = ExploreCatalogMapPresentation.boundingRegion(for: sites)
        let mapKitRegion = ExploreCatalogMapPresentation.region(for: sites)

        #expect(bounding != nil)
        #expect(mapKitRegion != nil)
        #expect(abs(bounding!.centerLatitude - mapKitRegion!.center.latitude) < 0.000_001)
        #expect(abs(bounding!.centerLongitude - mapKitRegion!.center.longitude) < 0.000_001)
        #expect(abs(bounding!.latitudeDelta - mapKitRegion!.span.latitudeDelta) < 0.000_001)
        #expect(abs(bounding!.longitudeDelta - mapKitRegion!.span.longitudeDelta) < 0.000_001)
    }

    @Test func goDiveMapEngine_defaultsToMapKit_withoutLaunchArgumentOrSecrets() {
        #expect(
            GoDiveMapEngine.resolved(activeLaunchArguments: [], hasGoogleMapsAPIKey: false) == .mapKit
        )
        #expect(
            GoDiveMapEngine.resolved(activeLaunchArguments: ["-GoDiveUITest"], hasGoogleMapsAPIKey: false)
                == .mapKit
        )
    }

    @Test func fishialImageBlobMetadata_base64MD5_matchesOpenSSLStyleDigest() {
        let data = Data("fishial".utf8)
        #expect(FishialImageBlobMetadata.base64MD5Checksum(for: data) == "peUq2S6hdJKbT/NXPmFd2w==")
        let metadata = FishialImageBlobMetadata.fromJPEGData(data, filename: "frames/fish.jpg")
        #expect(metadata.filename == "fish.jpg")
        #expect(metadata.contentType == "image/jpeg")
        #expect(metadata.byteSize == data.count)
    }

    @Test func fishialVideoScrubPresentation_clampsFractionAndFormatsTimestamps() {
        #expect(FishialVideoScrubPresentation.clampedFraction(-0.2) == 0)
        #expect(FishialVideoScrubPresentation.clampedFraction(1.5) == 1)
        #expect(FishialVideoScrubPresentation.timeSeconds(durationSeconds: 120, fraction: 0.5) == 60)

        #expect(
            FishialVideoScrubPresentation.formattedTimestamp(durationSeconds: 125, fraction: 0.5)
                == "1:02"
        )
        #expect(FishialVideoScrubPresentation.formattedDuration(durationSeconds: 125) == "2:05")
    }

    @Test func fishialVideoScrubPresentation_usesPrecisePlaybackSeekWhenNotScrubbing() {
        #expect(FishialVideoScrubPresentation.usesPrecisePlaybackSeek(isScrubbing: true) == false)
        #expect(FishialVideoScrubPresentation.usesPrecisePlaybackSeek(isScrubbing: false) == true)
    }

    @Test func fishialImageCropPresentation_squareCropViewportSize_fitsContainer() {
        let size = FishialImageCropPresentation.squareCropViewportSize(
            in: CGSize(width: 360, height: 500),
            horizontalPadding: 16,
            verticalPadding: 8
        )
        #expect(size.width == 328)
        #expect(size.height == 328)
    }

    @Test func fishialImageCropRenderer_baseFillScale_coversViewport() {
        let imageSize = CGSize(width: 1_600, height: 900)
        let cropSize = CGSize(width: 320, height: 320)
        let scale = FishialImageCropRenderer.baseFillScale(
            imageSize: imageSize,
            cropSize: cropSize
        )
        #expect(scale == CGFloat(320) / CGFloat(900))
    }

    @Test func fishialImageCropRenderer_clampedOffset_keepsCropInsideImage() {
        let drawSize = CGSize(width: 420, height: 420)
        let cropSize = CGSize(width: 300, height: 300)
        let clamped = FishialImageCropRenderer.clampedOffset(
            CGSize(width: 500, height: -500),
            drawSize: drawSize,
            cropSize: cropSize
        )
        #expect(clamped.width == 60)
        #expect(clamped.height == -60)
    }

    @Test func fishialImageCropRenderer_croppedJPEGData_returnsBytes() {
        #if canImport(UIKit)
        let size = CGSize(width: 240, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let cropSize = CGSize(width: 200, height: 200)
        let data = FishialImageCropRenderer.croppedJPEGData(
            from: image,
            cropSize: cropSize,
            gestureScale: 1.2,
            offset: .zero,
            displayScale: 2
        )
        #expect(data != nil)
        #expect(data?.isEmpty == false)
        #else
        #expect(Bool(true))
        #endif
    }

    @Test func fishialMediaSelectionPresentation_usesPreviewForSelectionAndFullQualityForExport() {
        #expect(FishialMediaSelectionPresentation.photoPreviewMaxEdge == 1_024)
        #expect(
            FishialMediaSelectionPresentation.photoExportMaxEdge
                == DiveMediaFishialFrameExport.maxJPEGEdge
        )
        #expect(FishialMediaSelectionPresentation.videoScrubRequestQuality == .homeCarousel)
        #expect(FishialMediaSelectionPresentation.videoExportRequestQuality == .fullQuality)
    }

    @Test func fishialStillCropContext_isPhotoSelection_whenNoVideoScrubContext() {
        #if canImport(UIKit)
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_300_000))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        let preview = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let cropContext = FishialStillCropContext(diveMedia: media, previewImage: preview)
        #expect(cropContext.isPhotoSelection)
        #expect(cropContext.diveMedia?.id == media.id)
        #else
        #expect(Bool(true))
        #endif
    }

    @Test func diveMediaFishialFrameExport_filenames_usePhotoAndScrubbedStillNames() {
        let mediaID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        #expect(
            DiveMediaFishialFrameExport.photoFilename(mediaID: mediaID)
                == "dive-media-11111111-1111-1111-1111-111111111111.jpg"
        )
        #expect(
            DiveMediaFishialFrameExport.scrubFrameFilename(mediaID: mediaID, timeSeconds: 12.345)
                == "dive-media-11111111-1111-1111-1111-111111111111-t12345.jpg"
        )
        #expect(DiveMediaFishialFrameExport.defaultVideoScrubFraction == 0.5)
    }

    @Test func fishialRecognitionPresentation_rankedSpecies_mergesBestAccuracyAcrossFrames() {
        let speciesID = "11111111-1111-1111-1111-111111111111"
        let otherSpeciesID = "22222222-2222-2222-2222-222222222222"
        let definitions = [
            speciesID: FishialSpeciesDefinition(
                commonName: "Queen Angelfish",
                scientificName: "Holacanthus ciliaris",
                imageURL: nil
            ),
            otherSpeciesID: FishialSpeciesDefinition(
                commonName: "Gray Angelfish",
                scientificName: "Pomacanthus paru",
                imageURL: nil
            ),
        ]
        let frameA = FishialRecognitionResponse(
            ok: true,
            objects: [
                FishialDetectedFish(species: [
                    FishialSpeciesCandidate(id: speciesID, certainty: 0.62),
                    FishialSpeciesCandidate(id: otherSpeciesID, certainty: 0.20),
                ]),
            ],
            definitions: definitions
        )
        let frameB = FishialRecognitionResponse(
            ok: true,
            objects: [
                FishialDetectedFish(species: [
                    FishialSpeciesCandidate(id: speciesID, certainty: 0.88),
                ]),
            ],
            definitions: definitions
        )

        let merged = FishialRecognitionPresentation.rankedSpecies(merging: [frameA, frameB])
        #expect(merged.count == 2)
        #expect(merged[0].scientificName == "Holacanthus ciliaris")
        #expect(merged[0].accuracy == 0.88)
        #expect(merged[1].scientificName == "Pomacanthus paru")
    }

    @Test func fishialObservationLocation_formatsLocationHeaderAndResolvesDiveCoordinate() {
        let coordinate = DiveCoordinate(latitude: -55.2604, longitude: -67.8862)
        #expect(
            FishialObservationLocation.locationHeaderValue(for: coordinate)
                == "-55.260, -67.886"
        )

        let site = DiveSite(
            siteName: "Test Reef",
            latCoords: 12.10325,
            longCoords: -68.28845
        )
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 0),
            durationMinutes: 45,
            maxDepthMeters: 18,
            siteName: "Imported Site",
            entryCoordinate: DiveCoordinate(latitude: 1, longitude: 2)
        )
        activity.diveSite = site

        #expect(
            FishialObservationLocation.resolvedCoordinate(for: activity, catalogSites: [])?.latitude
                == 12.10325
        )
    }

    @Test func fishialAPIClient_recognizeJPEG_runsV2AuthAndRecognitionFlow() async throws {
        let jpegData = Data("fake-jpeg-bytes".utf8)
        let credentials = FishialSecretsBootstrap.Credentials(
            clientID: "test-client-id",
            clientSecret: "test-client-secret"
        )
        let speciesID = "33333333-3333-3333-3333-333333333333"
        let coordinate = DiveCoordinate(latitude: -55.2604, longitude: -67.8862)

        let session = MockFishialURLSession(handlers: [
            { request in
                #expect(request.url?.absoluteString == "https://api-recognition.fishial.ai/v2/auth")
                #expect(request.httpMethod == "POST")
                return MockFishialURLSession.jsonResponse(
                    statusCode: 200,
                    body: #"{"access_token":"token-123"}"#,
                    url: request.url!
                )
            },
            { request in
                #expect(request.url?.absoluteString == "https://api-recognition.fishial.ai/v2/recognize")
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")
                #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
                #expect(
                    request.value(forHTTPHeaderField: "Fishial-Location-Lat-Lon")
                        == FishialObservationLocation.locationHeaderValue(for: coordinate)
                )
                #expect(request.httpBody == jpegData)
                return MockFishialURLSession.jsonResponse(
                    statusCode: 200,
                    body: """
                    {
                      "ok": true,
                      "queryToken": "query-token",
                      "objects": [
                        {
                          "species": [
                            { "id": "\(speciesID)", "certainty": 0.91 }
                          ]
                        }
                      ],
                      "definitions": {
                        "\(speciesID)": {
                          "commonName": "Queen Angelfish",
                          "scientificName": "Holacanthus ciliaris"
                        }
                      }
                    }
                    """,
                    url: request.url!
                )
            },
        ])

        let client = FishialAPIClient(
            configuration: FishialAPIClient.Configuration(credentials: credentials),
            session: session
        )
        let response = try await client.recognizeJPEG(jpegData, observationCoordinate: coordinate)
        let ranked = FishialRecognitionPresentation.rankedSpecies(from: response)
        #expect(ranked.count == 1)
        #expect(
            ranked == [
                FishialRankedSpecies(scientificName: "Holacanthus ciliaris", accuracy: 0.91),
            ]
        )
    }

    @Test func fishialIdentificationResultPresentation_resultLines_formatsSelectedFrameOutput() {
        let outcome = DiveMediaFishialIdentification.Outcome(
            selectedFilename: "dive-media-frame-3.jpg",
            observationCoordinate: DiveCoordinate(latitude: 12.103, longitude: -68.288),
            rankedSpecies: [
                FishialRecognitionPresentation.RankedSpecies(
                    scientificName: "Holacanthus ciliaris",
                    accuracy: 0.885
                ),
            ],
            detectedFishCount: 1,
            species: [FishialSpeciesMatch(name: "Holacanthus ciliaris", accuracy: 0.91)]
        )

        let body = FishialIdentificationResultPresentation.resultLines(from: outcome).joined(separator: "\n")
        #expect(body.contains("Selected still: dive-media-frame-3.jpg"))
        #expect(body.contains("Dive location sent: 12.103, -68.288"))
        #expect(body.contains("Fish shapes detected: 1"))
        #expect(body.contains("Holacanthus ciliaris — 89%"))
    }

    @Test func fishialIdentificationReviewPresentation_reviewMode_branchesByResultCount() {
        let optionA = FishialCatalogReviewOption(
            marineLifeUUID: "queen-angelfish",
            catalogCommonName: "Queen Angelfish",
            catalogScientificName: "Holacanthus ciliaris",
            featureImageURL: "https://example.com/queen.jpg",
            fishialScientificName: "Holacanthus ciliaris",
            fishialAccuracy: 0.91,
            nameMatchScore: 1.0
        )
        let optionB = FishialCatalogReviewOption(
            marineLifeUUID: "gray-angelfish",
            catalogCommonName: "Gray Angelfish",
            catalogScientificName: "Pomacanthus arcuatus",
            featureImageURL: "https://example.com/gray.jpg",
            fishialScientificName: "Pomacanthus arcuatus",
            fishialAccuracy: 0.72,
            nameMatchScore: 1.0
        )

        #expect(
            FishialIdentificationReviewPresentation.reviewMode(for: [], rankedSpecies: [])
                == .noFishDetected
        )
        #expect(
            FishialIdentificationReviewPresentation.reviewMode(
                for: [],
                rankedSpecies: [
                    FishialRankedSpecies(scientificName: "Completely unknownicus", accuracy: 0.99),
                ]
            ) == .unmatchedFishialSuggestion("Completely unknownicus")
        )
        #expect(
            FishialIdentificationReviewPresentation.reviewMode(for: [optionA], rankedSpecies: [])
                == .confirmSingle(optionA)
        )
        #expect(
            FishialIdentificationReviewPresentation.reviewMode(for: [optionA, optionB], rankedSpecies: [])
                == .selectFromMultiple([optionA, optionB])
        )
    }

    @Test func fishialIdentificationReviewPresentation_unmatchedFieldGuideMessage_usesSpeciesName() {
        let message = FishialIdentificationReviewPresentation.unmatchedFieldGuideMessage(
            speciesName: "Holacanthus ciliaris"
        )
        #expect(message.contains("Holacanthus ciliaris"))
        #expect(message.contains("GoDive has no such record in its field guide"))
    }

    @Test func fishialMarineLifeCatalogMatching_scientificNameSimilarity_handlesExactAndFuzzyNames() {
        #expect(
            FishialMarineLifeCatalogMatching.scientificNameSimilarity(
                fishial: "Holacanthus ciliaris",
                catalog: "Holacanthus ciliaris"
            ) == 1.0
        )
        #expect(
            FishialMarineLifeCatalogMatching.scientificNameSimilarity(
                fishial: "Holacanthus ciliaris.",
                catalog: "holacanthus  ciliaris"
            ) == 1.0
        )
        #expect(
            FishialMarineLifeCatalogMatching.scientificNameSimilarity(
                fishial: "Holacanthus ciliarus",
                catalog: "Holacanthus ciliaris"
            ) >= FishialMarineLifeCatalogMatching.defaultMinimumSimilarity
        )
        #expect(
            FishialMarineLifeCatalogMatching.scientificNameSimilarity(
                fishial: "Acanthurus coeruleus",
                catalog: "Holacanthus ciliaris"
            ) < FishialMarineLifeCatalogMatching.defaultMinimumSimilarity
        )
    }

    @Test func fishialMarineLifeCatalogMatching_catalogReviewOptions_mapsFishialResultsToCatalogRows() {
        let catalog = [
            FishialMarineLifeCatalogSnapshot(
                uuid: "queen-angelfish",
                scientificName: "Holacanthus ciliaris",
                commonName: "Queen Angelfish",
                featureImageURL: "https://example.com/queen.jpg"
            ),
            FishialMarineLifeCatalogSnapshot(
                uuid: "blue-tang",
                scientificName: "Acanthurus coeruleus",
                commonName: "Blue Tang",
                featureImageURL: "https://example.com/tang.jpg"
            ),
        ]
        let ranked = [
            FishialRankedSpecies(scientificName: "Holacanthus ciliaris", accuracy: 0.91),
            FishialRankedSpecies(scientificName: "Acanthurus coeruleus", accuracy: 0.74),
            FishialRankedSpecies(scientificName: "Completely unknownicus", accuracy: 0.99),
        ]

        let options = FishialMarineLifeCatalogMatching.catalogReviewOptions(
            from: ranked,
            catalog: catalog
        )
        #expect(options.count == 2)
        #expect(options[0].marineLifeUUID == "queen-angelfish")
        #expect(options[0].catalogCommonName == "Queen Angelfish")
        #expect(options[0].featureImageURL == "https://example.com/queen.jpg")
        #expect(options[1].marineLifeUUID == "blue-tang")
    }

    @Test func diveMediaPhoto_resolvedFishialConfirmedSpeciesName_trimsBlankValues() {
        let unset = DiveMediaPhoto(fishialConfirmedSpeciesName: "   ")
        #expect(unset.resolvedFishialConfirmedSpeciesName == nil)
        #expect(unset.resolvedFishialConfirmedSpeciesNames.isEmpty)

        let confirmed = DiveMediaPhoto(fishialConfirmedSpeciesName: "  Holacanthus ciliaris  ")
        #expect(confirmed.resolvedFishialConfirmedSpeciesName == "Holacanthus ciliaris")
        #expect(confirmed.resolvedFishialConfirmedSpeciesNames == ["Holacanthus ciliaris"])

        let multiple = DiveMediaPhoto(
            fishialConfirmedSpeciesName: "Holacanthus ciliaris|Paracanthurus hepatus"
        )
        #expect(
            multiple.resolvedFishialConfirmedSpeciesNames == [
                "Holacanthus ciliaris",
                "Paracanthurus hepatus",
            ]
        )
    }

    @Test func fishialConfirmedSpeciesPresentation_mergesWithoutDuplicates() {
        let merged = FishialConfirmedSpeciesPresentation.mergedScientificNames(
            existingStoredValue: "Holacanthus ciliaris",
            adding: ["Holacanthus ciliaris", " Paracanthurus hepatus ", "holacanthus ciliaris"]
        )
        #expect(merged == ["Holacanthus ciliaris", "Paracanthurus hepatus"])
        #expect(
            FishialConfirmedSpeciesPresentation.storageValue(for: merged)
                == "Holacanthus ciliaris|Paracanthurus hepatus"
        )
    }

    @Test @MainActor func diveMediaFishialIdentificationStorage_saveConfirmedSpecies_persistsOnMedia() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveMediaPhoto.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let dive = DiveActivity(
            source: .manual,
            startTime: .now,
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        context.insert(dive)

        let media = DiveMediaPhoto(sortOrder: 0, mediaKind: .image, dive: dive)
        context.insert(media)
        try context.save()

        let saved = try DiveMediaFishialIdentificationStorage.saveConfirmedSpecies(
            "Holacanthus ciliaris",
            on: media,
            modelContext: context
        )
        #expect(saved == "Holacanthus ciliaris")
        #expect(media.fishialConfirmedSpeciesName == "Holacanthus ciliaris")
        #expect(media.resolvedFishialConfirmedSpeciesName == "Holacanthus ciliaris")
    }

    @Test @MainActor func diveMediaFishialIdentificationStorage_saveConfirmedCatalogMatch_tagsSpeciesAndPersistsFishID() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "fishial-tag", displayName: "Diver")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_200_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        dive.owner = owner
        dive.ownerProfileID = owner.id
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_200_100))
        media.link(to: dive)
        let species = MarineLife(
            uuid: "fishial-catalog-queen",
            commonName: "Queen Angelfish",
            scientificName: "Holacanthus ciliaris"
        )

        context.insert(owner)
        context.insert(dive)
        context.insert(media)
        context.insert(species)

        let option = FishialCatalogReviewOption(
            marineLifeUUID: species.uuid,
            catalogCommonName: species.commonName,
            catalogScientificName: species.scientificName,
            featureImageURL: "https://example.com/queen.jpg",
            fishialScientificName: "Holacanthus ciliaris",
            fishialAccuracy: 0.91,
            nameMatchScore: 1.0
        )

        let saved = try DiveMediaFishialIdentificationStorage.saveConfirmedCatalogMatch(
            option,
            marineLife: species,
            media: media,
            dive: dive,
            captureContext: DiveMediaCaptureContext(elapsedSeconds: 120, depthMeters: 12),
            owner: owner,
            modelContext: context
        )
        #expect(saved == "Queen Angelfish")
        #expect(media.fishialConfirmedSpeciesName == "Holacanthus ciliaris")

        let sightings = try MarineLifeSightingRecorder.sightings(
            forMediaPhotoID: media.id,
            modelContext: context
        )
        #expect(sightings.count == 1)
        #expect(sightings[0].marineLifeUUID == species.uuid)
        #expect(sightings[0].sightingDepthMeters == 12)
    }

    @Test @MainActor func marineLifeSightingRecorder_batchFetch_scopesByDiveAndMediaIDs() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "batch-sightings", displayName: "Diver")
        let linkedDive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 4_000_000),
            durationMinutes: 45,
            maxDepthMeters: 20
        )
        linkedDive.owner = owner
        linkedDive.ownerProfileID = owner.id

        let otherDive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 4_100_000),
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        otherDive.owner = owner
        otherDive.ownerProfileID = owner.id

        let taggedMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_000_100))
        taggedMedia.link(to: linkedDive)
        let otherMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_100_100))
        otherMedia.link(to: otherDive)

        let species = MarineLife(uuid: "batch-species", commonName: "Parrotfish", scientificName: "Sparisoma")
        context.insert(species)
        context.insert(linkedDive)
        context.insert(otherDive)

        _ = try MarineLifeSightingRecorder.tagSpecies(
            species,
            on: taggedMedia,
            dive: linkedDive,
            captureContext: nil,
            owner: owner,
            modelContext: context
        )
        _ = try MarineLifeSightingRecorder.tagSpecies(
            species,
            on: otherMedia,
            dive: otherDive,
            captureContext: nil,
            owner: owner,
            modelContext: context
        )

        let diveScoped = try MarineLifeSightingRecorder.sightings(
            forDiveActivityIDs: [linkedDive.id],
            modelContext: context
        )
        #expect(diveScoped.count == 1)
        #expect(diveScoped[0].diveActivityID == linkedDive.id)

        let mediaScoped = try MarineLifeSightingRecorder.sightings(
            forMediaPhotoIDs: [taggedMedia.id],
            modelContext: context
        )
        #expect(mediaScoped.count == 1)
        #expect(mediaScoped[0].mediaPhotoID == taggedMedia.id)
    }

    @Test @MainActor func diveMediaFishialIdentificationStorage_saveConfirmedCatalogMatches_tagsMultipleSpecies() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "fishial-multi-tag", displayName: "Diver")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_300_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        dive.owner = owner
        dive.ownerProfileID = owner.id
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_300_100))
        media.link(to: dive)
        let queen = MarineLife(
            uuid: "fishial-multi-queen",
            commonName: "Queen Angelfish",
            scientificName: "Holacanthus ciliaris"
        )
        let blueTang = MarineLife(
            uuid: "fishial-multi-blue-tang",
            commonName: "Blue Tang",
            scientificName: "Paracanthurus hepatus"
        )

        context.insert(owner)
        context.insert(dive)
        context.insert(media)
        context.insert(queen)
        context.insert(blueTang)

        let options = [
            FishialCatalogReviewOption(
                marineLifeUUID: queen.uuid,
                catalogCommonName: queen.commonName,
                catalogScientificName: queen.scientificName,
                featureImageURL: "https://example.com/queen.jpg",
                fishialScientificName: queen.scientificName,
                fishialAccuracy: 0.91,
                nameMatchScore: 1.0
            ),
            FishialCatalogReviewOption(
                marineLifeUUID: blueTang.uuid,
                catalogCommonName: blueTang.commonName,
                catalogScientificName: blueTang.scientificName,
                featureImageURL: "https://example.com/blue-tang.jpg",
                fishialScientificName: blueTang.scientificName,
                fishialAccuracy: 0.84,
                nameMatchScore: 1.0
            ),
        ]

        let saved = try DiveMediaFishialIdentificationStorage.saveConfirmedCatalogMatches(
            options,
            marineLifeByUUID: [queen.uuid: queen, blueTang.uuid: blueTang],
            media: media,
            dive: dive,
            captureContext: DiveMediaCaptureContext(elapsedSeconds: 120, depthMeters: 12),
            owner: owner,
            modelContext: context
        )
        #expect(saved == ["Queen Angelfish", "Blue Tang"])
        #expect(
            media.fishialConfirmedSpeciesName
                == "Holacanthus ciliaris|Paracanthurus hepatus"
        )

        let sightings = try MarineLifeSightingRecorder.sightings(
            forMediaPhotoID: media.id,
            modelContext: context
        )
        #expect(sightings.count == 2)
        #expect(Set(sightings.map(\.marineLifeUUID)) == Set([queen.uuid, blueTang.uuid]))
    }

    @Test @MainActor func diveMediaBuddyAssociation_tagBuddy_tagsMediaAndDiveWhenMissing() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "media-buddy-tag", displayName: "Diver")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_400_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        dive.owner = owner
        dive.ownerProfileID = owner.id
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_400_100))
        media.link(to: dive)
        let buddy = DiveBuddy(displayName: "Jamie", owner: owner)

        context.insert(owner)
        context.insert(dive)
        context.insert(media)
        context.insert(buddy)

        #expect(dive.buddies.isEmpty)

        let tag = try DiveMediaBuddyAssociation.tagBuddy(
            buddy,
            on: media,
            dive: dive,
            modelContext: context
        )
        #expect(tag.buddyID == buddy.id)
        #expect(tag.mediaPhotoID == media.id)
        #expect(dive.buddies.count == 1)
        #expect(dive.buddies[0].buddyID == buddy.id)

        let mediaTags = try DiveMediaBuddyAssociation.tags(
            forMediaPhotoID: media.id,
            modelContext: context
        )
        #expect(mediaTags.count == 1)
    }

    @Test @MainActor func diveMediaBuddyAssociation_tagSelf_tagsMediaAndDive() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let owner = UserProfile(appleUserIdentifier: "media-self-tag", displayName: "Mike Dugas")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_420_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        dive.owner = owner
        dive.ownerProfileID = owner.id
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_420_100))
        media.link(to: dive)

        context.insert(owner)
        context.insert(dive)
        context.insert(media)

        let tag = try DiveMediaBuddyAssociation.tagSelf(
            owner: owner,
            on: media,
            dive: dive,
            modelContext: context
        )

        #expect(tag.buddyID != nil)
        #expect(dive.buddies.count == 1)
        #expect(DiveBuddySelfRepresentation.isSelfBuddy(dive.buddies[0].buddy!, owner: owner))

        let mediaTags = try DiveMediaBuddyAssociation.tags(
            forMediaPhotoID: media.id,
            modelContext: context
        )
        #expect(mediaTags.count == 1)
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

    @Test @MainActor func diveMediaBuddyAssociation_tagBuddy_doesNotDuplicateDiveTag() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "media-buddy-dup", displayName: "Diver")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_410_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        dive.owner = owner
        dive.ownerProfileID = owner.id
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_410_100))
        media.link(to: dive)
        let buddy = DiveBuddy(displayName: "Alex", owner: owner)

        context.insert(owner)
        context.insert(dive)
        context.insert(media)
        context.insert(buddy)

        _ = DiveBuddyActivityAssociation.tagBuddy(buddy, on: dive, modelContext: context)
        #expect(dive.buddies.count == 1)

        _ = try DiveMediaBuddyAssociation.tagBuddy(
            buddy,
            on: media,
            dive: dive,
            modelContext: context
        )
        #expect(dive.buddies.count == 1)

        let mediaTags = try DiveMediaBuddyAssociation.tags(
            forMediaPhotoID: media.id,
            modelContext: context
        )
        #expect(mediaTags.count == 1)
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

    @Test @MainActor func diveMediaBuddyTagDraftPresentation_apply_batchesMediaTagWrites() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext

        let owner = UserProfile(appleUserIdentifier: "buddy-draft-media", displayName: "Diver")
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_440_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        dive.ownerProfileID = owner.id
        let media = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 3_440_100))
        media.link(to: dive)
        let jamie = DiveBuddy(displayName: "Jamie", owner: owner)
        let alex = DiveBuddy(displayName: "Alex", owner: owner)
        context.insert(owner)
        context.insert(dive)
        context.insert(media)
        context.insert(jamie)
        context.insert(alex)

        _ = try DiveMediaBuddyAssociation.tagBuddy(
            jamie,
            on: media,
            dive: dive,
            modelContext: context
        )
        #expect(try DiveMediaBuddyAssociation.tags(forMediaPhotoID: media.id, modelContext: context).count == 1)

        let draft = DiveMediaBuddyTagDraftPresentation.DraftState(taggedBuddyIDs: [alex.id])
        try DiveMediaBuddyTagDraftPresentation.apply(
            draft: draft,
            media: media,
            dive: dive,
            owner: owner,
            rosterByID: [jamie.id: jamie, alex.id: alex],
            modelContext: context
        )

        let tags = try DiveMediaBuddyAssociation.tags(forMediaPhotoID: media.id, modelContext: context)
        #expect(tags.count == 1)
        #expect(tags[0].buddyID == alex.id)
        #expect(dive.buddies.count == 1)
        #expect(dive.buddies[0].buddyID == alex.id)
    }

    @Test func fishialSecretsBootstrap_validatedCredentials_rejectsPlaceholders() {
        #expect(
            FishialSecretsBootstrap.validatedCredentials(
                clientID: "YOUR_FISHIAL_CLIENT_ID",
                clientSecret: "abc123"
            ) == nil
        )
        #expect(
            FishialSecretsBootstrap.validatedCredentials(
                clientID: "c0fae174f24c0950352c2bbd",
                clientSecret: "5edac99f92bf7acb66425c47fb153c5f"
            ) == FishialSecretsBootstrap.Credentials(
                clientID: "c0fae174f24c0950352c2bbd",
                clientSecret: "5edac99f92bf7acb66425c47fb153c5f"
            )
        )
    }

    @Test func goDiveMapEngine_googleMapsSecretsFile_selectsGoogleMaps() {
        #expect(
            GoDiveMapEngine.resolved(activeLaunchArguments: [], hasGoogleMapsAPIKey: true) == .googleMaps
        )
    }

    @Test func goDiveMapEngine_googleMapsLaunchArgument_selectsGoogleMaps() {
        #expect(
            GoDiveMapEngine.resolved(
                activeLaunchArguments: [GoDiveMapEngine.googleMapsLaunchArgument],
                hasGoogleMapsAPIKey: false
            ) == .googleMaps
        )
    }

    @Test func exploreCatalogMapMarkerPresentation_truncatesLongSiteNames() {
        let short = ExploreCatalogMapMarkerPresentation.displayTitle(for: "Salt Pier")
        #expect(short == "Salt Pier")

        let longName = String(repeating: "A", count: 40)
        let truncated = ExploreCatalogMapMarkerPresentation.displayTitle(for: longName)
        #expect(truncated.count == ExploreCatalogMapMarkerPresentation.titleMaxCharacters)
        #expect(truncated.hasSuffix("…"))
    }

    @Test func exploreCatalogMapPinDensity_fewerPinsWhenZoomedOut() {
        let sites = (0..<40).map { index in
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Site \(index)",
                coordinate: DiveCoordinate(latitude: Double(index) * 0.05, longitude: 0)
            )
        }
        let viewport = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 1.0, longitude: 0),
            latitudeSpan: 80,
            longitudeSpan: 120
        )

        let sparse = ExploreCatalogMapPinDensity.visibleSiteIDs(sites: sites, viewport: viewport)
        #expect(sparse.count <= ExploreCatalogMapPinDensity.minimumVisiblePinCount)

        let denseViewport = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 1.0, longitude: 0),
            latitudeSpan: ExploreCatalogMapPinDensity.fullPinRevealLatitudeSpan,
            longitudeSpan: 0.2
        )
        let dense = ExploreCatalogMapPinDensity.visibleSiteIDs(sites: sites, viewport: denseViewport)
        let denseCandidates = ExploreCatalogMapPinDensity.sitesInViewport(sites, viewport: denseViewport)
        #expect(dense.count == denseCandidates.count)
    }

    @Test func exploreCatalogMapPinDensity_alwaysShowsVisitedPinsWhenZoomedOut() {
        let visited = ExploreCatalogMapPresentation.PlottedSite(
            id: UUID(),
            siteName: "My Reef",
            coordinate: DiveCoordinate(latitude: 45, longitude: 10),
            isVisited: true
        )
        let unvisited = (0..<80).map { index in
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Site \(index)",
                coordinate: DiveCoordinate(latitude: Double(index) * 0.4, longitude: Double(index) * 0.2)
            )
        }
        let viewport = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 20, longitude: 8),
            latitudeSpan: 100,
            longitudeSpan: 120
        )

        let visible = ExploreCatalogMapPinDensity.visibleSiteIDs(
            sites: [visited] + unvisited,
            viewport: viewport
        )

        #expect(visible.contains(visited.id))
        #expect(visible.count > 1)
        #expect(visible.count < unvisited.count + 1)
    }

    @Test func exploreCatalogMapPinDensity_spreadsUnvisitedPinsAcrossViewport() {
        let quadrants: [(baseLatitude: Double, baseLongitude: Double)] = [
            (-20, -70),
            (-20, 70),
            (20, -70),
            (20, 70),
        ]
        let sites = quadrants.flatMap { quadrant in
            (0..<15).map { index in
                ExploreCatalogMapPresentation.PlottedSite(
                    id: UUID(),
                    siteName: "Site \(quadrant.baseLatitude)-\(index)",
                    coordinate: DiveCoordinate(
                        latitude: quadrant.baseLatitude + Double(index) * 0.01,
                        longitude: quadrant.baseLongitude + Double(index) * 0.01
                    )
                )
            }
        }
        let viewport = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 0, longitude: 0),
            latitudeSpan: 60,
            longitudeSpan: 180
        )

        let visibleIDs = ExploreCatalogMapPinDensity.visibleSiteIDs(
            sites: sites,
            viewport: viewport
        )
        let visibleSites = sites.filter { visibleIDs.contains($0.id) }
        let longitudes = visibleSites.map(\.coordinate.longitude)

        #expect(visibleSites.count >= 4)
        #expect((longitudes.max() ?? 0) - (longitudes.min() ?? 0) > 40)
    }

    @Test func exploreCatalogMapStickyPinVisibility_keepsRevealedPinsWhilePanning() {
        let sites = (0..<80).map { index in
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Site \(index)",
                coordinate: DiveCoordinate(
                    latitude: Double(index % 10) * 2,
                    longitude: Double(index / 10) * 15
                )
            )
        }
        var state = ExploreCatalogMapStickyPinVisibility.State()

        let viewportA = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 9, longitude: 52.5),
            latitudeSpan: 22,
            longitudeSpan: 80
        )
        let freshA = ExploreCatalogMapPinDensity.visibleSiteIDs(sites: sites, viewport: viewportA)
        let visibleA = ExploreCatalogMapStickyPinVisibility.visibleSiteIDs(
            sites: sites,
            viewport: viewportA,
            freshEligible: freshA,
            state: &state
        )

        let viewportB = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 9, longitude: 67.5),
            latitudeSpan: 22,
            longitudeSpan: 80
        )
        let freshB = ExploreCatalogMapPinDensity.visibleSiteIDs(sites: sites, viewport: viewportB)
        let visibleB = ExploreCatalogMapStickyPinVisibility.visibleSiteIDs(
            sites: sites,
            viewport: viewportB,
            freshEligible: freshB,
            state: &state
        )

        let overlap = visibleA.intersection(
            Set(ExploreCatalogMapPinDensity.sitesInViewport(sites, viewport: viewportB).map(\.id))
        )
        #expect(visibleB.isSuperset(of: overlap))
        #expect(visibleB.count >= visibleA.count)
    }

    @Test func exploreCatalogMapStickyPinVisibility_cullsWhenZoomingOut() {
        let sites = (0..<80).map { index in
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Site \(index)",
                coordinate: DiveCoordinate(
                    latitude: Double(index % 10) * 2,
                    longitude: Double(index / 10) * 15
                )
            )
        }
        var state = ExploreCatalogMapStickyPinVisibility.State()
        let viewportZoomedIn = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 9, longitude: 52.5),
            latitudeSpan: 30,
            longitudeSpan: 80
        )
        let freshZoomedIn = ExploreCatalogMapPinDensity.visibleSiteIDs(
            sites: sites,
            viewport: viewportZoomedIn
        )
        _ = ExploreCatalogMapStickyPinVisibility.visibleSiteIDs(
            sites: sites,
            viewport: viewportZoomedIn,
            freshEligible: freshZoomedIn,
            state: &state
        )

        let viewportZoomedOut = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 9, longitude: 52.5),
            latitudeSpan: 120,
            longitudeSpan: 160
        )
        let freshZoomedOut = ExploreCatalogMapPinDensity.visibleSiteIDs(
            sites: sites,
            viewport: viewportZoomedOut
        )
        let visibleZoomedOut = ExploreCatalogMapStickyPinVisibility.visibleSiteIDs(
            sites: sites,
            viewport: viewportZoomedOut,
            freshEligible: freshZoomedOut,
            state: &state
        )

        #expect(visibleZoomedOut.count <= freshZoomedIn.count)
        #expect(visibleZoomedOut == freshZoomedOut)
    }

    @Test func exploreCatalogMapPinDensity_revealsMorePinsWhileZoomingIn() {
        let sites = (0..<200).map { index in
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Site \(index)",
                coordinate: DiveCoordinate(
                    latitude: Double(index % 20) * 0.15,
                    longitude: Double(index / 20) * 0.15 - 1.5
                )
            )
        }
        let center = DiveCoordinate(latitude: 1.42, longitude: -0.07)

        let wider = ExploreCatalogMapPinDensity.visibleSiteIDs(
            sites: sites,
            viewport: ExploreCatalogMapViewport(center: center, latitudeSpan: 100, longitudeSpan: 120)
        )
        let mid = ExploreCatalogMapPinDensity.visibleSiteIDs(
            sites: sites,
            viewport: ExploreCatalogMapViewport(center: center, latitudeSpan: 40, longitudeSpan: 50)
        )
        let tighter = ExploreCatalogMapPinDensity.visibleSiteIDs(
            sites: sites,
            viewport: ExploreCatalogMapViewport(center: center, latitudeSpan: 12, longitudeSpan: 14)
        )

        #expect(wider.count <= ExploreCatalogMapPinDensity.minimumVisiblePinCount)
        #expect(mid.count > wider.count)
        #expect(tighter.count > mid.count)
    }

    @Test func exploreCatalogMapPinLabelPolicy_allSites_neverLabelsPins() {
        let sites = [
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Salt Pier",
                coordinate: DiveCoordinate(latitude: 12.083, longitude: -68.283)
            ),
        ]
        let labeled = ExploreCatalogMapPinLabelPolicy.pinOnlyAlways.labeledSiteIDs(
            sites: sites,
            visibleLatitudeSpan: 0.01,
            mapCenter: DiveCoordinate(latitude: 12.083, longitude: -68.283)
        )
        #expect(labeled.isEmpty)
        #expect(ExploreCatalogMapPinLabelPolicy.usesPinCallout(for: .allSites))
        #expect(ExploreCatalogMapPinLabelPolicy.usesPinCallout(for: .logbook))

        let manySites = (0..<20).map { index in
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Site \(index)",
                coordinate: DiveCoordinate(latitude: Double(index) * 0.1, longitude: 0)
            )
        }
        let viewport = ExploreCatalogMapViewport(
            center: DiveCoordinate(latitude: 1.0, longitude: 0),
            latitudeSpan: 60,
            longitudeSpan: 80
        )
        let visible = ExploreCatalogMapPinLabelPolicy.pinOnlyAlways.visibleSiteIDs(
            sites: manySites,
            viewport: viewport
        )
        #expect(visible.count < manySites.count)
        #expect(ExploreCatalogMapPinLabelPolicy.progressiveZoomReveal.visibleSiteIDs(
            sites: manySites,
            viewport: viewport
        ).count == manySites.count)
    }

    @Test func exploreCatalogMapLabelVisibility_fewerLabelsWhenZoomedOut() {
        #expect(
            ExploreCatalogMapLabelVisibility.maximumLabelCount(visibleLatitudeSpan: 20, siteCount: 10) == 0
        )
        #expect(
            ExploreCatalogMapLabelVisibility.maximumLabelCount(
                visibleLatitudeSpan: ExploreCatalogMapLabelVisibility.allLabelsLatitudeSpan,
                siteCount: 10
            ) == 10
        )

        let midZoom = ExploreCatalogMapLabelVisibility.maximumLabelCount(visibleLatitudeSpan: 2.0, siteCount: 10)
        #expect(midZoom > 0)
        #expect(midZoom < 10)
    }

    @Test func exploreCatalogMapLabelVisibility_staggerRevealsLabelsIncrementally() {
        let sites = (0..<6).map { index in
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Site \(index)",
                coordinate: DiveCoordinate(latitude: Double(index) * 0.2, longitude: 0)
            )
        }
        let center = DiveCoordinate(latitude: 0.5, longitude: 0)

        let wider = ExploreCatalogMapLabelVisibility.labeledSiteIDs(
            sites: sites,
            visibleLatitudeSpan: 6.5,
            mapCenter: center
        )
        let tighter = ExploreCatalogMapLabelVisibility.labeledSiteIDs(
            sites: sites,
            visibleLatitudeSpan: 2.5,
            mapCenter: center
        )
        let tightest = ExploreCatalogMapLabelVisibility.labeledSiteIDs(
            sites: sites,
            visibleLatitudeSpan: ExploreCatalogMapLabelVisibility.allLabelsLatitudeSpan,
            mapCenter: center
        )

        #expect(wider.count < tighter.count)
        #expect(tighter.count < tightest.count)
        #expect(tightest.count == sites.count)
        #expect(wider.isEmpty)
    }

    @Test func exploreCatalogMapLabelVisibility_revealProgress_isStaggeredByRank() {
        #expect(ExploreCatalogMapLabelVisibility.revealProgress(forRank: 0, siteCount: 5) == 0.32)
        #expect(ExploreCatalogMapLabelVisibility.revealProgress(forRank: 4, siteCount: 5) == 1.0)
        let mid = ExploreCatalogMapLabelVisibility.revealProgress(forRank: 2, siteCount: 5)
        #expect(mid > 0.32)
        #expect(mid < 1.0)
    }

    @Test func exploreCatalogMapLabelVisibility_labeledTripPinIDs_matchExploreRules() {
        let pins = [
            TripDetailMapPin(
                id: "planned-north",
                title: "Salt Pier",
                coordinate: DiveCoordinate(latitude: 12.0, longitude: -68.0),
                kind: .planned,
                siteID: nil
            ),
            TripDetailMapPin(
                id: "completed-south",
                title: "Hilma Hooker",
                coordinate: DiveCoordinate(latitude: 12.2, longitude: -68.2),
                kind: .completed,
                siteID: nil
            ),
        ]
        let center = DiveCoordinate(latitude: 12.1, longitude: -68.1)

        let wider = ExploreCatalogMapLabelVisibility.labeledTripPinIDs(
            pins: pins,
            visibleLatitudeSpan: 6.5,
            mapCenter: center
        )
        let tightest = ExploreCatalogMapLabelVisibility.labeledTripPinIDs(
            pins: pins,
            visibleLatitudeSpan: ExploreCatalogMapLabelVisibility.allLabelsLatitudeSpan,
            mapCenter: center
        )

        #expect(wider.isEmpty)
        #expect(tightest.count == pins.count)
    }

    @Test func goDiveMapPointOfInterestSuppression_googleStyleJSON_parses() {
        let data = Data(GoDiveMapPointOfInterestSuppression.googleMapsSuppressPOIStyleJSON.utf8)
        let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        #expect(json != nil)
        #expect(json?.contains { ($0["featureType"] as? String) == "poi.business" } == true)
    }

    @Test func exploreCatalogMapLabelVisibility_prefersSitesNearMapCenter() {
        let sites = [
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Near",
                coordinate: DiveCoordinate(latitude: 12.0, longitude: -68.0)
            ),
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Far",
                coordinate: DiveCoordinate(latitude: 14.0, longitude: -66.0)
            ),
        ]
        let center = DiveCoordinate(latitude: 12.01, longitude: -68.01)
        let labeled = ExploreCatalogMapLabelVisibility.labeledSiteIDs(
            sites: sites,
            visibleLatitudeSpan: 2.5,
            mapCenter: center
        )

        #expect(labeled.count == 1)
        #expect(labeled.contains(sites[0].id))
    }

    @Test func mapAnnotationPinAnchor_pinOnly_usesZeroOffset() {
        #expect(MapAnnotationPinAnchor.pinOnlyCenterOffset == .zero)
    }

    @Test func mapAnnotationPinAnchor_labelBelowPin_offsetsTipToCoordinate() {
        let totalHeight: CGFloat = 70
        let offset = MapAnnotationPinAnchor.centerOffsetForLabelBelowPin(totalViewHeight: totalHeight)

        #expect(offset.x == 0)
        #expect(abs(offset.y - (MapPushPinMetrics.tipYInAnnotationView - totalHeight * 0.5)) < 0.001)
    }

    @Test func mapPushPinMetrics_mapAnnotationImage_tipIsVerticallyCentered() {
        #expect(MapPushPinMetrics.mapAnnotationImageHeight == MapPushPinMetrics.renderedHeight * 2)
        #expect(MapPushPinMetrics.tipYInMapAnnotationImage == MapPushPinMetrics.mapAnnotationImageHeight * 0.5)
        #expect(MapPushPinMetrics.tipYInAnnotationView == MapPushPinMetrics.renderedHeight)
    }

    @Test func exploreDiveSiteListDisplay_rowData_coordinatesPlaceAndDiveCount() {
        let rated = DiveSite(
            siteName: "Salt Pier",
            country: "Bonaire",
            region: "Caribbean",
            latCoords: 12.083,
            longCoords: -68.283,
            siteRating: 4
        )
        let unrated = DiveSite(siteName: "Mystery Reef", country: "Belize")
        unrated.diveActivities = [DiveActivity(source: .macDive, sourceDiveId: "a", startTime: .now, durationMinutes: 40, maxDepthMeters: 18)]

        let rows = ExploreDiveSiteListDisplay.rowData(for: [rated, unrated])

        #expect(rows.count == 2)
        #expect(rows[0].displayName == "Salt Pier")
        #expect(rows[0].diveCountLabel == nil)
        #expect(rows[0].coordinateLine.contains("12.083"))
        #expect(rows[0].placeLine == "Bonaire · Caribbean")
        #expect(rows[1].diveCountLabel == "1 dive")
        #expect(rows[1].coordinateLine == DiveSitePresentation.missingValue)
        #expect(rows[1].placeLine == "Belize")
    }

    @Test func exploreDiveSiteListDisplay_plannedTripRow_omitsDiveCount() {
        let rated = DiveSite(
            siteName: "Salt Pier",
            country: "Bonaire",
            region: "Caribbean",
            siteRating: 4
        )
        let unrated = DiveSite(siteName: "Mystery Reef", country: "Belize")
        unrated.diveActivities = [
            DiveActivity(source: .macDive, sourceDiveId: "a", startTime: .now, durationMinutes: 40, maxDepthMeters: 18),
        ]

        let rows = ExploreDiveSiteListDisplay.rowData(for: [rated, unrated], trailingStyle: .plannedTrip)

        #expect(rows[0].diveCountLabel == nil)
        #expect(rows[1].diveCountLabel == nil)
        #expect(rows[0].placeLine == "Bonaire · Caribbean")
    }

    @Test func exploreSiteScopePresentation_logbookSites_filtersLinkedCatalogRows() {
        let siteID = UUID()
        let linkedSite = DiveSite(id: siteID, siteName: "Salt Pier", latCoords: 12.08, longCoords: -68.28)
        let unlinkedSite = DiveSite(siteName: "Never Dived")
        let ownerID = UUID()
        let linkedActivity = DiveActivity(
            source: .macDive,
            startTime: .now,
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        linkedActivity.ownerProfileID = ownerID
        linkedActivity.diveSiteID = siteID

        let logbookIDs = ExploreSiteScopePresentation.logbookSiteIDs(
            ownerActivities: [linkedActivity],
            ownerProfileID: ownerID
        )
        let logbookSites = ExploreSiteScopePresentation.logbookCatalogSites(
            catalog: [linkedSite, unlinkedSite],
            logbookSiteIDs: logbookIDs
        )

        #expect(logbookSites.count == 1)
        #expect(logbookSites[0].id == siteID)
    }

    @Test func exploreReferenceSiteListSearch_matchesNameAndCountry() {
        let snapshot = DiveSiteReferenceSnapshot(
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
        #expect(ExploreReferenceSiteListSearch.matches(snapshot, query: "salt pier"))
        #expect(ExploreReferenceSiteListSearch.matches(snapshot, query: "caribbean sea"))
        #expect(ExploreReferenceSiteListSearch.matches(snapshot, query: "netherlands"))
        #expect(!ExploreReferenceSiteListSearch.matches(snapshot, query: "madagascar"))
    }

    @Test func exploreSiteScopePresentation_plottableReferenceSite_prefersCatalogMatch() {
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
            seaName: ""
        )
        let catalogSite = DiveSite(
            siteName: "Salt Pier (mine)",
            latCoords: 12.0835,
            longCoords: -68.283,
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")]
        )
        let plotted = ExploreSiteScopePresentation.plottableSites(
            scope: .allSites,
            catalog: [catalogSite],
            logbookSiteIDs: [],
            reference: [reference]
        )
        #expect(plotted.count == 1)
        #expect(plotted[0].selection == .catalog(catalogSite.id))
        #expect(!plotted[0].isVisited)
    }

    @Test func exploreSiteScopePresentation_plottableReferenceSite_marksVisitedLogbookSites() {
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
            seaName: ""
        )
        let unvisitedReference = DiveSiteReferenceSnapshot(
            id: "reef02",
            name: "Blue Reef",
            country: "Belize",
            countryCode: "BZ",
            latitude: 17.3,
            longitude: -87.7,
            maxDepthMeters: 20,
            entry: "boat",
            environment: "ocean",
            topologies: [],
            seaName: ""
        )
        let visitedSite = DiveSite(
            siteName: "Salt Pier (mine)",
            latCoords: 12.0835,
            longCoords: -68.283,
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")]
        )

        let plotted = ExploreSiteScopePresentation.plottableSites(
            scope: .allSites,
            catalog: [visitedSite],
            logbookSiteIDs: [visitedSite.id],
            reference: [reference, unvisitedReference]
        )

        #expect(plotted.count == 2)
        #expect(plotted.first(where: { $0.siteName.contains("Salt") })?.isVisited == true)
        #expect(plotted.first(where: { $0.siteName == "Blue Reef" })?.isVisited == false)
    }

    @Test func exploreSiteScopePresentation_allSites_includesUnmatchedLogbookSites() {
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
            seaName: ""
        )
        let localOnlySite = DiveSite(
            id: UUID(),
            siteName: "Secret Local Reef",
            country: "Puerto Rico",
            latCoords: 18.4,
            longCoords: -65.1
        )
        let logbookIDs: Set<UUID> = [localOnlySite.id]

        let plotted = ExploreSiteScopePresentation.plottableSites(
            scope: .allSites,
            catalog: [localOnlySite],
            logbookSiteIDs: logbookIDs,
            reference: [reference]
        )
        let rows = ExploreSiteScopePresentation.catalogListRows(
            scope: .allSites,
            catalog: [localOnlySite],
            logbookSiteIDs: logbookIDs,
            reference: [reference],
            query: ""
        )

        #expect(plotted.count == 2)
        let localPin = plotted.first(where: { $0.siteName == "Secret Local Reef" })
        #expect(localPin?.isVisited == true)
        #expect(rows.count == 2)
        let localRow = rows.first(where: { $0.displayName == "Secret Local Reef" })
        #expect(localRow?.referenceID == nil)
    }

    @Test func exploreDiveSiteSearchPresentation_buildsMapSuggestionsFromScopedRows() {
        let siteID = UUID()
        let linkedSite = DiveSite(id: siteID, siteName: "Salt Pier", latCoords: 12.08, longCoords: -68.28)
        let ownerID = UUID()
        let linkedActivity = DiveActivity(
            source: .macDive,
            startTime: .now,
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        linkedActivity.ownerProfileID = ownerID
        linkedActivity.diveSiteID = siteID
        let logbookIDs = ExploreSiteScopePresentation.logbookSiteIDs(
            ownerActivities: [linkedActivity],
            ownerProfileID: ownerID
        )
        let plottable = ExploreSiteScopePresentation.plottableSites(
            scope: .logbook,
            catalog: [linkedSite],
            logbookSiteIDs: logbookIDs,
            reference: []
        )

        #expect(
            ExploreDiveSiteSearchPresentation.showsSuggestions(
                viewMode: .map,
                query: "salt",
                mapFocusedSelection: nil
            )
        )
        #expect(
            !ExploreDiveSiteSearchPresentation.showsSuggestions(
                viewMode: .list,
                query: "salt",
                mapFocusedSelection: nil
            )
        )
        #expect(
            !ExploreDiveSiteSearchPresentation.showsSuggestions(
                viewMode: .map,
                query: "salt",
                mapFocusedSelection: .catalog(siteID)
            )
        )

        let suggestions = ExploreDiveSiteSearchPresentation.suggestions(
            scope: .logbook,
            catalog: [linkedSite],
            logbookSiteIDs: logbookIDs,
            reference: [],
            plottableSites: plottable,
            query: "salt"
        )
        #expect(suggestions.count == 1)
        #expect(suggestions[0].siteName == "Salt Pier")
        #expect(suggestions[0].selection == .catalog(siteID))
        #expect(suggestions[0].coordinate.latitude == 12.08)
        #expect(suggestions[0].rowDisplayData.displayName == "Salt Pier")
    }

    @Test func exploreCatalogMapPresentation_sitesChangeSignature_detectsVisitedChanges() {
        let siteID = UUID()
        let visited = ExploreCatalogMapPresentation.PlottedSite(
            id: siteID,
            siteName: "Salt Pier",
            coordinate: DiveCoordinate(latitude: 12.08, longitude: -68.28),
            isVisited: true
        )
        let unvisited = ExploreCatalogMapPresentation.PlottedSite(
            id: siteID,
            siteName: "Salt Pier",
            coordinate: DiveCoordinate(latitude: 12.08, longitude: -68.28),
            isVisited: false
        )
        let visitedSignature = ExploreCatalogMapPresentation.sitesChangeSignature(for: [visited])
        let unvisitedSignature = ExploreCatalogMapPresentation.sitesChangeSignature(for: [unvisited])
        #expect(visitedSignature != unvisitedSignature)
        #expect(
            ExploreCatalogMapPresentation.sitesChangeSignature(for: [visited])
                == visitedSignature
        )
    }

    @Test func exploreSiteScopeCache_precomputesBothScopes() {
        let siteID = UUID()
        let linkedSite = DiveSite(id: siteID, siteName: "Salt Pier", latCoords: 12.08, longCoords: -68.28)
        let ownerID = UUID()
        let linkedActivity = DiveActivity(
            source: .macDive,
            startTime: .now,
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        linkedActivity.ownerProfileID = ownerID
        linkedActivity.diveSiteID = siteID

        let snapshot = ExploreSiteScopeCache.make(
            ownerProfileID: ownerID,
            catalog: [linkedSite],
            ownerActivities: [linkedActivity]
        )

        #expect(snapshot.hasLogbookSites)
        #expect(snapshot.logbookPlottableSites.count == 1)
        #expect(snapshot.allSitesPlottableSites.count >= 1)
        #expect(snapshot.logbookListRows.map(\.displayName) == ["Salt Pier"])
        #expect(snapshot.plottableSignature(for: .logbook) != snapshot.plottableSignature(for: .allSites))
    }

    @Test func exploreSiteScopeCache_filteringListRows_matchesDisplayFields() {
        let rows = [
            DiveSitePresentation.listRecord(
                for: DiveSite(siteName: "Salt Pier", country: "Bonaire", region: "Caribbean")
            ),
            DiveSitePresentation.listRecord(
                for: DiveSite(siteName: "Blue Hole", country: "Belize", region: "")
            ),
        ]
        #expect(
            ExploreSiteScopeCache.filteringListRows(rows, scope: .allSites, query: "belize").count == 1
        )
        #expect(
            ExploreSiteScopeCache.filteringListRows(rows, scope: .logbook, query: "caribbean").count == 1
        )
    }

    @Test func exploreSiteScopeCache_filteringListRows_usesPrecomputedHaystack() {
        let row = DiveSitePresentation.listRecord(
            for: DiveSite(siteName: "Salt Pier", country: "Bonaire", region: "Caribbean")
        )
        #expect(!row.searchHaystackLowercased.isEmpty)
        #expect(
            ExploreSiteScopeCache.filteringListRows([row], scope: .logbook, query: "bonaire").count == 1
        )
        #expect(
            ExploreSiteScopeCache.filteringListRows([row], scope: .logbook, query: "xyz-nope").isEmpty
        )
    }

    @Test func exploreSiteScope_segmentLabelsIncludeIconsAndTitles() {
        #expect(ExploreSiteScope.logbook.shortTitle == "My Sites")
        #expect(ExploreSiteScope.allSites.shortTitle == "All Sites")
        #expect(ExploreSiteScope.logbook.systemImage == "book.closed.fill")
        #expect(ExploreSiteScope.allSites.systemImage == "globe.americas.fill")
    }

    @Test func exploreSiteScopeChromePresentation_bottomLayoutReservesTabBarAndToggle() {
        #expect(ExploreSiteScopeChromePresentation.toggleChromeHeight == 40)
        #expect(ExploreSiteScopeChromePresentation.paddingAboveTabBar(safeAreaBottom: 34) == 4)
        #expect(ExploreSiteScopeChromePresentation.showsBottomToggle(isSearchFocused: true) == false)
        #expect(ExploreSiteScopeChromePresentation.showsBottomToggle(isSearchFocused: false))
        #expect(
            ExploreSiteScopeChromePresentation.showsKeyboardAdjacentToggle(
                isSearchFocused: true,
                showsSiteScopeToggle: true,
                isNavigationStackAtRoot: true
            )
        )
        #expect(
            !ExploreSiteScopeChromePresentation.showsKeyboardAdjacentToggle(
                isSearchFocused: false,
                showsSiteScopeToggle: true,
                isNavigationStackAtRoot: true
            )
        )
        #expect(AppTheme.Layout.exploreMapSearchSuggestionVisibleRows == 3)
        let rowHeight = AppTheme.Layout.exploreMapSearchSuggestionRowHeight
        let rowSpacing = AppTheme.Spacing.md
        #expect(
            AppTheme.Layout.exploreMapSearchSuggestionPanelHeight(rowCount: 1)
                == rowHeight
        )
        #expect(
            AppTheme.Layout.exploreMapSearchSuggestionPanelHeight(rowCount: 2)
                == rowHeight * 2 + rowSpacing
        )
        #expect(
            AppTheme.Layout.exploreMapSearchSuggestionPanelHeight(rowCount: 3)
                == rowHeight * 3 + rowSpacing * 2
        )
        #expect(
            AppTheme.Layout.exploreMapSearchSuggestionPanelHeight(rowCount: 8)
                == AppTheme.Layout.exploreMapSearchSuggestionPanelHeight
        )
        #expect(
            ExploreSiteScopeChromePresentation.listExtraBottomInset
                == ExploreSiteScopeChromePresentation.toggleChromeHeight + ExploreSiteScopeChromePresentation.spacingAboveTabBar
        )
    }

    @Test func exploreDiveSiteListPresentation_sections_groupsByCountryAndSortsTitles() {
        let bonaireRow = DiveSitePresentation.listRecord(
            for: DiveSite(
                siteName: "Salt Pier",
                country: "Bonaire",
                region: "Caribbean",
                latCoords: 12.08,
                longCoords: -68.28
            )
        )
        let belizeRow = DiveSitePresentation.listRecord(
            for: DiveSite(siteName: "Blue Hole", country: "Belize")
        )
        let unknownRow = DiveSitePresentation.listRecord(for: DiveSite(siteName: "Mystery Reef"))

        let sections = ExploreDiveSiteListPresentation.sections(
            from: [bonaireRow, belizeRow, unknownRow, bonaireRow]
        )
        #expect(sections.map(\.title) == ["Belize", "Bonaire", ExploreDiveSiteListPresentation.unknownCountrySectionTitle])
        #expect(sections[1].rows.map(\.displayName) == ["Salt Pier"])
    }

    @Test func exploreDiveSiteListPresentation_referencePlaceLine_usesUnifiedPlaceFields() {
        let snapshot = DiveSiteReferenceSnapshot(
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
        #expect(
            ExploreDiveSiteListPresentation.referencePlaceLine(for: snapshot)
                == "Caribbean Netherlands · Caribbean Sea"
        )
        #expect(ExploreDiveSiteListPresentation.listCountry(from: snapshot) == "Caribbean Netherlands")
    }

    @Test func diveSiteCountryPresentation_canonicalDisplayName_mergesDutchCaribbean() {
        #expect(
            DiveSiteCountryPresentation.canonicalDisplayName(for: "Dutch Caribbean")
                == DiveSiteCountryPresentation.caribbeanNetherlands
        )
        #expect(
            DiveSiteCountryPresentation.canonicalDisplayName(for: "Caribbean Netherlands")
                == DiveSiteCountryPresentation.caribbeanNetherlands
        )
    }

    @Test func diveSiteCountryPresentation_searchTerms_includesAliases() {
        let terms = DiveSiteCountryPresentation.searchTerms(for: "Caribbean Netherlands")
        #expect(terms.contains("Caribbean Netherlands"))
        #expect(terms.contains(where: { $0.caseInsensitiveCompare("Dutch Caribbean") == .orderedSame }))
    }

    @Test func exploreDiveSiteListPresentation_sections_mergesDutchCaribbeanWithCaribbeanNetherlands() {
        let dutchRow = DiveSitePresentation.listRecord(
            for: DiveSite(siteName: "Karpata", country: "Dutch Caribbean", latCoords: 12.08, longCoords: -68.28)
        )
        let netherlandsRow = DiveSitePresentation.listRecord(
            for: DiveSite(
                siteName: "Salt Pier",
                country: "Caribbean Netherlands",
                latCoords: 12.09,
                longCoords: -68.29
            )
        )

        let sections = ExploreDiveSiteListPresentation.sections(from: [dutchRow, netherlandsRow])
        #expect(sections.count == 1)
        #expect(sections[0].title == DiveSiteCountryPresentation.caribbeanNetherlands)
        #expect(sections[0].rows.count == 2)
    }

    @Test func exploreDiveSiteListSearch_matchesDutchCaribbeanAlias() {
        let site = DiveSite(siteName: "Karpata", country: "Dutch Caribbean", region: "Bonaire")
        #expect(ExploreDiveSiteListSearch.matches(site, query: "dutch"))
        #expect(ExploreDiveSiteListSearch.matches(site, query: "caribbean netherlands"))
    }

    @Test func exploreDiveSiteListDisplay_cityCountryLine_formatsRegionAndCountry() {
        #expect(
            ExploreDiveSiteListDisplay.cityCountryLine(country: "Bonaire", region: "Caribbean")
                == "Bonaire · Caribbean"
        )
        #expect(ExploreDiveSiteListDisplay.cityCountryLine(country: "Belize", region: "") == "Belize")
        #expect(ExploreDiveSiteListDisplay.cityCountryLine(country: "", region: "Pacific") == "Pacific")
    }

    @Test func diveSitePresentation_listRecord_usesDashForMissingValues() {
        let catalog = DiveSitePresentation.listRecord(for: DiveSite(siteName: "Mystery Reef"))
        let reference = DiveSitePresentation.listRecord(
            for: DiveSiteReferenceSnapshot(
                id: "reef01",
                name: "Open Reef",
                country: "Belize",
                countryCode: "BZ",
                latitude: nil,
                longitude: nil,
                maxDepthMeters: nil,
                entry: "",
                environment: "",
                topologies: [],
                seaName: ""
            )
        )

        #expect(catalog.region == DiveSitePresentation.missingValue)
        #expect(catalog.coordinateLine == DiveSitePresentation.missingValue)
        #expect(reference.region == DiveSitePresentation.missingValue)
        #expect(reference.rating == DiveSitePresentation.missingValue)
        #expect(catalog.placeDetailRows.count == 3)
        #expect(catalog.detailRows.count == 7)
        #expect(reference.placeDetailRows.count == 3)
        #expect(reference.detailRows.count == 7)
    }

    @Test func diveSitePresentation_pinnedHeader_formatsLocationAndDiveCount() {
        let bonaire = DiveSitePresentation.listRecord(
            for: DiveSite(
                siteName: "Salt Pier",
                country: "Caribbean Netherlands",
                region: "Bonaire",
                bodyOfWater: "Caribbean Sea"
            )
        )
        #expect(bonaire.pinnedLocationLine == "Bonaire, Caribbean Netherlands")
        #expect(bonaire.pinnedDiveCountLabel == "0 dives")

        let belizeOnly = DiveSitePresentation.listRecord(
            for: DiveSite(siteName: "Blue Hole", country: "Belize")
        )
        #expect(belizeOnly.pinnedLocationLine == "Belize")
        #expect(DiveSitePresentation.pinnedDiveCountLabel(count: 1) == "1 dive")
        #expect(DiveSitePresentation.pinnedDiveCountLabel(count: 3) == "3 dives")

        let unknown = DiveSitePresentation.listRecord(for: DiveSite(siteName: "Mystery Reef"))
        #expect(unknown.pinnedLocationLine == nil)
    }

    @Test func diveSitePresentation_displayPinnedStarRating_defaultsToZero() {
        #expect(DiveSitePresentation.displayPinnedStarRating(from: 4) == 4)
        #expect(DiveSitePresentation.displayPinnedStarRating(from: 1) == 1)
        #expect(DiveSitePresentation.displayPinnedStarRating(from: 5) == 5)
        #expect(DiveSitePresentation.displayPinnedStarRating(from: nil) == 0)
        #expect(DiveSitePresentation.displayPinnedStarRating(from: 0) == 0)
        #expect(DiveSitePresentation.displayPinnedStarRating(from: 6) == 0)

        let rated = DiveSitePresentation.listRecord(
            for: DiveSite(siteName: "Salt Pier", country: "Bonaire", siteRating: 3)
        )
        #expect(rated.pinnedStarRating == 3)
        #expect(
            DiveSitePresentation.pinnedStarRatingAccessibilityLabel(rating: 3, isEditable: true)
                == "Rating 3 out of 5 stars. Tap a star to rate this site."
        )

        let unrated = DiveSitePresentation.listRecord(for: DiveSite(siteName: "Mystery Reef"))
        #expect(unrated.pinnedStarRating == 0)
        #expect(
            DiveSitePresentation.pinnedStarRatingAccessibilityLabel(rating: 0, isEditable: false)
                == "Unrated, 0 out of 5 stars"
        )
    }

    @Test func diveSitePresentation_starRatingEditing_requiresVisitAndTogglesOff() {
        #expect(
            DiveSitePresentation.isStarRatingEditable(ownerHasVisited: true, isReferenceOnly: false)
        )
        #expect(
            !DiveSitePresentation.isStarRatingEditable(ownerHasVisited: false, isReferenceOnly: false)
        )
        #expect(
            !DiveSitePresentation.isStarRatingEditable(ownerHasVisited: true, isReferenceOnly: true)
        )
        #expect(DiveSitePresentation.storageSiteRating(for: 0) == nil)
        #expect(DiveSitePresentation.storageSiteRating(for: 4) == 4)
        #expect(DiveSitePresentation.toggledStarRating(current: 3, selectedStar: 3) == 0)
        #expect(DiveSitePresentation.toggledStarRating(current: 2, selectedStar: 4) == 4)
    }

    @Test func exploreDiveSiteDetailPresentation_catalogMapPin_usesSiteCoordinates() {
        let site = DiveSite(
            siteName: "Salt Pier",
            country: "Bonaire",
            latCoords: 12.083,
            longCoords: -68.283
        )
        let pins = ExploreDiveSiteDetailPresentation.mapPins(for: site)
        #expect(pins.count == 1)
        #expect(pins[0].siteID == site.id)
        #expect(pins[0].kind == .completed)
        #expect(pins[0].title == "Salt Pier")
        #expect(pins[0].coordinate.latitude == 12.083)
    }

    @Test func exploreDiveSiteDetailPresentation_referenceMapPin_omitsWithoutCoordinates() {
        let snapshot = DiveSiteReferenceSnapshot(
            id: "reef01",
            name: "Open Reef",
            country: "Belize",
            countryCode: "BZ",
            latitude: nil,
            longitude: nil,
            maxDepthMeters: nil,
            entry: "",
            environment: "",
            topologies: [],
            seaName: ""
        )
        #expect(ExploreDiveSiteDetailPresentation.mapPins(for: snapshot).isEmpty)

        let located = DiveSiteReferenceSnapshot(
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
        let pins = ExploreDiveSiteDetailPresentation.mapPins(for: located)
        #expect(pins.count == 1)
        #expect(pins[0].kind == .planned)
        #expect(pins[0].siteID == nil)
    }

    @Test func exploreDiveSiteDetailPresentation_showsHeroModeToggleWhenMediaAndMapExist() {
        #expect(
            ExploreDiveSiteDetailPresentation.showsHeroModeToggle(
                hasTaggedMedia: true,
                hasMapPin: true
            )
        )
        #expect(
            !ExploreDiveSiteDetailPresentation.showsHeroModeToggle(
                hasTaggedMedia: false,
                hasMapPin: true
            )
        )
        #expect(
            !ExploreDiveSiteDetailPresentation.showsHeroModeToggle(
                hasTaggedMedia: true,
                hasMapPin: false
            )
        )
    }

    @Test func exploreDiveSiteDetailPresentation_canDefaultHeroMode_waitsForOwnerRoster() {
        #expect(
            ExploreDiveSiteDetailPresentation.canDefaultHeroMode(
                hasOwnerProfile: false,
                ownerDiveQueryReady: false
            )
        )
        #expect(
            !ExploreDiveSiteDetailPresentation.canDefaultHeroMode(
                hasOwnerProfile: true,
                ownerDiveQueryReady: false
            )
        )
        #expect(
            ExploreDiveSiteDetailPresentation.canDefaultHeroMode(
                hasOwnerProfile: true,
                ownerDiveQueryReady: true
            )
        )
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
        #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiveActivity>()) == 0)
    }

    @Test func exploreDiveSiteAddPresentation_chromeCopy() {
        #expect(ExploreDiveSiteAddPresentation.sheetTitle == "New dive site")
        #expect(ExploreDiveSiteAddPresentation.chromeAccessibilityLabel == "Add dive site")
        #expect(ExploreDiveSiteAddPresentation.chromeSystemImage == "plus")
        #expect(ExploreDiveSiteAddPresentation.chromeAccessibilityIdentifier == "Explore.AddDiveSite")
    }

    @Test func exploreDiveSiteDetailContentPager_pages() {
        #expect(ExploreDiveSiteDetailContentPagerPresentation.pageCount == 4)
        #expect(
            ExploreDiveSiteDetailContentPagerPresentation.pages == [
                .diveDetails,
                .divesHere,
                .marineLifeHere,
                .taggedMedia,
            ]
        )
        #expect(ExploreDiveSiteDetailContentPagerPresentation.defaultPage == .diveDetails)
        #expect(
            ExploreDiveSiteDetailContentPagerPresentation.pageTitle(for: .divesHere)
                == ExploreDiveSiteDetailContentPagerPresentation.divesHereSectionTitle
        )
        #expect(
            ExploreDiveSiteDetailContentPagerPresentation.pageTitle(for: .marineLifeHere)
                == ExploreDiveSiteDetailContentPagerPresentation.marineLifeHereSectionTitle
        )
        #expect(
            ExploreDiveSiteDetailContentPagerPresentation.pageTitle(for: .taggedMedia)
                == ExploreDiveSiteDetailContentPagerPresentation.taggedMediaSectionTitle
        )
        #expect(
            ExploreDiveSiteDetailContentPagerPresentation.emptyStateMessage(for: .divesHere)
                == "No dives logged at this site yet."
        )
        #expect(
            ExploreDiveSiteDetailContentPagerPresentation.accessibilityIdentifier(for: .marineLifeHere)
                == "Explore.DiveSiteDetail.ContentPager.MarineLifeHere"
        )
        #expect(!ExploreDiveSiteDetailContentPagerPresentation.usesStaticPagerLayout(for: .taggedMedia))
    }

    @Test func exploreDiveSiteDetailPresentation_prefersMapHeroWithoutTaggedMedia() {
        #expect(
            ExploreDiveSiteDetailPresentation.prefersMapHero(
                hasTaggedMedia: false,
                hasMapPin: true
            )
        )
        #expect(
            !ExploreDiveSiteDetailPresentation.prefersMapHero(
                hasTaggedMedia: true,
                hasMapPin: true
            )
        )
        #expect(
            !ExploreDiveSiteDetailPresentation.prefersMapHero(
                hasTaggedMedia: false,
                hasMapPin: false
            )
        )
    }

    @Test @MainActor func exploreDiveSiteDetailContentSnapshotBuilder_fetchSiteDiveActivities_filtersOwnerSiteLinks() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let ownerID = UUID()
        let otherSiteID = UUID()

        let diveAtSite = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 2_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        diveAtSite.ownerProfileID = ownerID
        let site = DiveSite(siteName: "Reef")
        context.insert(site)
        diveAtSite.diveSiteID = site.id
        context.insert(diveAtSite)

        let diveElsewhere = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 3_000),
            durationMinutes: 35,
            maxDepthMeters: 15
        )
        diveElsewhere.ownerProfileID = ownerID
        diveElsewhere.diveSiteID = otherSiteID
        context.insert(diveElsewhere)

        try context.save()

        let fetched = ExploreDiveSiteDetailContentSnapshotBuilder.fetchSiteDiveActivities(
            diveSiteID: site.id,
            ownerProfileID: ownerID,
            modelContext: context
        )
        #expect(fetched.count == 1)
        #expect(fetched[0].id == diveAtSite.id)

        let snapshot = ExploreDiveSiteDetailContentSnapshotBuilder.buildLight(
            site: site,
            siteActivities: fetched,
            ownerProfileID: ownerID,
            unitSystem: .metric
        )
        #expect(snapshot.siteDiveRows.count == 1)
        #expect(snapshot.sightedSpeciesLinks.isEmpty)
        #expect(snapshot.marineLifeCatalog.isEmpty)
    }

    @Test func exploreDiveSiteListDisplay_placeSummary_omitsEmptyFields() {
        let site = DiveSite(siteName: "Reef", country: "  ", region: "Pacific", bodyOfWater: "Coral Sea")
        #expect(ExploreDiveSiteListDisplay.placeSummary(for: site) == "Pacific · Coral Sea")
    }

    @Test func exploreCatalogMapPresentation_region_singleSite_usesDiveSiteSpan() {
        let sites = [
            ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Solo",
                coordinate: DiveCoordinate(latitude: 12.083, longitude: -68.283)
            ),
        ]

        let region = ExploreCatalogMapPresentation.region(for: sites)

        #expect(region?.center.latitude == 12.083)
        #expect(region?.center.longitude == -68.283)
        #expect(region?.span.latitudeDelta == DiveLocationMapPresentation.diveSiteLatitudeDelta)
        #expect(region?.span.longitudeDelta == DiveLocationMapPresentation.diveSiteLongitudeDelta)
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
        #expect(DiveLocationMapPresentation.minimizedCameraDistanceMeters == 6_200)
        #expect(DiveLocationMapPresentation.mediumCameraDistanceMeters == 1_200)
        #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .minimized) > DiveLocationMapPresentation.referenceCameraDistanceMeters)
        #expect(
            DiveLocationMapPresentation.cameraDistanceMeters(for: .minimized)
                > DiveLocationMapPresentation.cameraDistanceMeters(for: .medium)
        )
        #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .medium) < DiveLocationMapPresentation.referenceCameraDistanceMeters)
        #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .large) == DiveLocationMapPresentation.cameraDistanceMeters(for: .medium))
    }

    @Test func diveLocationMapGoogleCameraPresentation_zoomLevel_tightensWhenDistanceShrinks() {
        let wide = DiveLocationMapGoogleCameraPresentation.approximateZoomLevel(
            atLatitude: 12.083,
            viewingDistanceMeters: DiveLocationMapPresentation.minimizedCameraDistanceMeters
        )
        let tight = DiveLocationMapGoogleCameraPresentation.approximateZoomLevel(
            atLatitude: 12.083,
            viewingDistanceMeters: DiveLocationMapPresentation.mediumCameraDistanceMeters
        )
        #expect(tight > wide)
    }

    @Test func diveLocationMapGoogleCameraPresentation_cameraSpec_centersOnDiveCoordinate() {
        let coordinate = DiveCoordinate(latitude: 12.083, longitude: -68.283)
        let spec = DiveLocationMapGoogleCameraPresentation.cameraSpec(
            coordinate: coordinate,
            layoutHeight: 800,
            topObstructionHeight: 100,
            bottomContentMargin: 400,
            cameraLayoutDetent: .medium
        )
        #expect(abs(spec.centerLatitude - coordinate.latitude) < 0.000_001)
        #expect(abs(spec.centerLongitude - coordinate.longitude) < 0.000_001)
        #expect(spec.zoomLevel > 1)
    }

    @Test func diveLocationMapGoogleCameraPresentation_paddedViewportCenter_matchesTargetPinY() {
        let layoutHeight: CGFloat = 844
        let topObstruction: CGFloat = 100
        let bottomMargin = DiveActivityOverviewDetent.bottomObstructionHeight(
            layoutHeight: layoutHeight,
            detent: .medium,
            bottomSafeInset: 34
        )
        let paddedCenterY = topObstruction + (layoutHeight - topObstruction - bottomMargin) / 2
        let targetY = DiveLocationMapPresentation.targetPinScreenYFraction(
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            sheetHeightFraction: bottomMargin / layoutHeight
        ) * layoutHeight
        #expect(abs(paddedCenterY - targetY) < 0.5)
    }

    @Test func diveActivityOverviewTabSelection_allTabs_useMediumDetent() {
        #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .map) == .medium)
        #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .tank) == .medium)
        #expect(DiveActivityOverviewTabSelection.overviewDetent(whenSelecting: .camera) == .medium)
    }

    @Test func diveActivityMediaPresentation_sortedPhotos_withoutCaptureDate_respectsSortOrder() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        let second = DiveMediaPhoto(sortOrder: 1, dive: activity)
        let first = DiveMediaPhoto(sortOrder: 0, dive: activity)
        activity.mediaPhotos = [second, first]
        let sorted = DiveActivityMediaPresentation.sortedPhotos(on: activity)
        #expect(sorted.map(\.sortOrder) == [0, 1])
    }

    @Test func diveActivityMediaPresentation_sortedPhotos_ordersByCapturedAt_oldestFirst() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        let oldest = Date(timeIntervalSince1970: 1_000)
        let middle = Date(timeIntervalSince1970: 2_000)
        let newest = Date(timeIntervalSince1970: 3_000)
        activity.mediaPhotos = [
            DiveMediaPhoto(sortOrder: 2, capturedAt: newest, dive: activity),
            DiveMediaPhoto(sortOrder: 0, capturedAt: oldest, dive: activity),
            DiveMediaPhoto(sortOrder: 1, capturedAt: middle, dive: activity),
        ]
        let sorted = DiveActivityMediaPresentation.sortedPhotos(on: activity)
        #expect(sorted.map(\.capturedAt) == [oldest, middle, newest])
    }

    @Test func diveActivityMediaPresentation_oldestGalleryPhotoID_returnsFirstInGalleryOrder() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        let oldest = DiveMediaPhoto(
            sortOrder: 1,
            capturedAt: Date(timeIntervalSince1970: 1_000),
            dive: activity
        )
        let newest = DiveMediaPhoto(
            sortOrder: 0,
            capturedAt: Date(timeIntervalSince1970: 3_000),
            dive: activity
        )
        activity.mediaPhotos = [newest, oldest]
        #expect(DiveActivityMediaPresentation.oldestGalleryPhotoID(on: activity) == oldest.id)
        #expect(DiveActivityMediaPresentation.oldestGalleryPhotoID(in: []) == nil)
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

    @Test func diveActivityMediaPresentation_featuredPhotoID_prefersExplicitThenFallsBackToOldest() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        let oldest = DiveMediaPhoto(sortOrder: 1, capturedAt: Date(timeIntervalSince1970: 1_000), dive: activity)
        let newest = DiveMediaPhoto(sortOrder: 0, capturedAt: Date(timeIntervalSince1970: 3_000), dive: activity)
        activity.mediaPhotos = [newest, oldest]

        // Default (no explicit choice) → oldest gallery item.
        #expect(DiveActivityMediaPresentation.featuredPhotoID(on: activity) == oldest.id)

        // Explicit valid choice wins.
        activity.featuredMediaPhotoID = newest.id
        #expect(DiveActivityMediaPresentation.featuredPhotoID(on: activity) == newest.id)
        #expect(DiveActivityMediaPresentation.isFeatured(mediaID: newest.id, in: activity.mediaPhotos, explicitFeaturedID: newest.id))
        #expect(!DiveActivityMediaPresentation.isFeatured(mediaID: oldest.id, in: activity.mediaPhotos, explicitFeaturedID: newest.id))

        // Stale explicit id (asset removed / pruned) → falls back to oldest.
        activity.featuredMediaPhotoID = UUID()
        #expect(DiveActivityMediaPresentation.featuredPhotoID(on: activity) == oldest.id)

        // No media → nil.
        #expect(DiveActivityMediaPresentation.featuredPhotoID(in: [], explicitFeaturedID: UUID()) == nil)
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

    @Test func diveActivityMediaStorage_setFeaturedMedia_persistsAndClears() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        context.insert(activity)
        try context.save()

        let featured = UUID()
        try DiveActivityMediaStorage.setFeaturedMedia(featured, on: activity, modelContext: context)
        #expect(activity.featuredMediaPhotoID == featured)

        try DiveActivityMediaStorage.setFeaturedMedia(nil, on: activity, modelContext: context)
        #expect(activity.featuredMediaPhotoID == nil)
    }

    #if canImport(Photos)
    @Test func diveMediaReferenceLoader_videoRequestOptions_useFullResolutionPlayback() {
        let options = DiveMediaReferenceLoader.makeVideoRequestOptions()
        // Highest-quality original (download from iCloud when needed) rather than a transcoded/automatic stream.
        #expect(options.deliveryMode == .highQualityFormat)
        #expect(options.isNetworkAccessAllowed)
    }
    #endif

    #if canImport(UIKit)
    @Test func diveMediaPreviewPersistence_encodeDecode_roundTrip() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
        }
        let data = DiveMediaPreviewPersistence.encodePreviewJPEG(image)
        #expect(data != nil)
        let decoded = DiveMediaPreviewPersistence.decodePreviewJPEG(data)
        #expect(decoded != nil)
        #expect(decoded?.size.width == DiveMediaPreviewPersistence.storedPreviewEdge)
    }

    @Test func diveMediaPreviewPersistence_shouldPersistPreview_onlyWhenMissing() {
        #expect(DiveMediaPreviewPersistence.shouldPersistPreview(existingData: nil))
        #expect(DiveMediaPreviewPersistence.shouldPersistPreview(existingData: Data()))
        #expect(!DiveMediaPreviewPersistence.shouldPersistPreview(existingData: Data([0xFF, 0xD8])))
    }

    @Test func diveMediaPreviewPersistence_showsMissingPlaceholder_onlyAfterLoadFinishes() {
        #expect(
            !DiveMediaPreviewPersistence.showsMissingMediaPlaceholder(
                hasDisplayedImage: true,
                loadFinished: false
            )
        )
        #expect(
            !DiveMediaPreviewPersistence.showsMissingMediaPlaceholder(
                hasDisplayedImage: false,
                loadFinished: false
            )
        )
        #expect(
            DiveMediaPreviewPersistence.showsMissingMediaPlaceholder(
                hasDisplayedImage: false,
                loadFinished: true
            )
        )
    }

    @Test @MainActor func diveMediaPreviewStorage_hasStoredPreview_reflectsJPEGData() {
        let media = DiveMediaPhoto(
            sortOrder: 0,
            photosLocalIdentifier: "preview-test"
        )
        #expect(!DiveMediaPreviewStorage.hasStoredPreview(for: media))
        media.previewJPEGData = Data([0xFF, 0xD8, 0xFF])
        #expect(DiveMediaPreviewStorage.hasStoredPreview(for: media))
    }

    @Test @MainActor func homeMediaHighlightSessionCache_hasDisplayableImage_usesStoredPreview() {
        HomeMediaHighlightSessionCache.shared.clear()
        let media = DiveMediaPhoto(
            sortOrder: 0,
            photosLocalIdentifier: "stored-preview-id"
        )
        media.previewJPEGData = Data([0xFF, 0xD8, 0xFF])
        #expect(HomeMediaHighlightSessionCache.shared.hasDisplayableImage(for: media))
    }
    #endif

    @Test func diveMediaVideoLoad_classify_distinguishesMissingFromRetryable() {
        // A produced player item is always "loaded", regardless of asset reachability.
        #expect(DiveMediaVideoLoad.classify(itemResolved: true, isLibraryAsset: true, assetStillExists: false) == .loaded)
        // Library asset that no longer exists -> prune the reference.
        #expect(DiveMediaVideoLoad.classify(itemResolved: false, isLibraryAsset: true, assetStillExists: false) == .assetMissing)
        // Library asset that still exists but didn't load (timeout/offline) -> offer retry.
        #expect(DiveMediaVideoLoad.classify(itemResolved: false, isLibraryAsset: true, assetStillExists: true) == .retryable)
        // No network — offline icon only, not retry chrome.
        #expect(
            DiveMediaVideoLoad.classify(
                itemResolved: false,
                isLibraryAsset: true,
                assetStillExists: true,
                isNetworkAvailable: false
            ) == .offlineUnavailable
        )
        // Non-library (file) source that didn't load -> retry, never prune.
        #expect(DiveMediaVideoLoad.classify(itemResolved: false, isLibraryAsset: false, assetStillExists: false) == .retryable)
    }

    @Test func appNetworkConnectivityPresentation_offlineSkipsCloudMedia() {
        #expect(AppNetworkConnectivityPresentation.allowsCloudMediaFetch(isConnected: true))
        #expect(!AppNetworkConnectivityPresentation.allowsCloudMediaFetch(isConnected: false))
        #expect(AppNetworkConnectivityPresentation.photoKitAllowsNetworkAccess(isConnected: true))
        #expect(!AppNetworkConnectivityPresentation.photoKitAllowsNetworkAccess(isConnected: false))
        #expect(
            DiveMediaProgressivePresentation.shouldUpgradeToFullVideo(
                isPlaybackActive: true,
                isPausedByUserHold: false,
                currentFidelity: .preview,
                isNetworkAvailable: false
            ) == false
        )
    }

    @Test func diveMediaVideoLoad_timeout_isPositive() {
        #expect(DiveMediaVideoLoad.timeoutSeconds > 0)
    }

    @Test func homeLifetimeStatsPresentation_buildsAggregatesAndLinks() {
        let siteA = UUID()
        let siteB = UUID()
        let deepDive = UUID()
        let longDive = UUID()
        let dives = [
            HomeDiveStatsInput(id: deepDive, maxDepthMeters: 30, durationMinutes: 40, diveSiteID: siteA, diveNumberLabel: "#1", siteDisplayName: "Salt Pier"),
            HomeDiveStatsInput(id: longDive, maxDepthMeters: 18, durationMinutes: 62, diveSiteID: siteA, diveNumberLabel: "#2", siteDisplayName: "Salt Pier"),
            HomeDiveStatsInput(id: UUID(), maxDepthMeters: 12, durationMinutes: 35, diveSiteID: siteB, diveNumberLabel: "#3", siteDisplayName: "Turtle Bay"),
        ]
        let sightings = [
            HomeLifetimeStatsPresentation.SightingCountInput(marineLifeUUID: "fish-a", commonName: "Parrotfish"),
            HomeLifetimeStatsPresentation.SightingCountInput(marineLifeUUID: "fish-a", commonName: "Parrotfish"),
            HomeLifetimeStatsPresentation.SightingCountInput(marineLifeUUID: "fish-b", commonName: "Ray"),
        ]

        let stats = HomeLifetimeStatsPresentation.build(dives: dives, sightings: sightings)

        #expect(stats.diveCount == 3)
        #expect(stats.averageMaxDepthMeters == 20)
        #expect(abs((stats.averageDurationMinutes ?? 0) - (137.0 / 3.0)) < 0.001)
        #expect(stats.deepestDive?.id == deepDive)
        #expect(stats.deepestMaxDepthMeters == 30)
        #expect(stats.longestDive?.id == longDive)
        #expect(stats.longestDurationMinutes == 62)
        #expect(stats.mostVisitedSite?.name == "Salt Pier")
        #expect(stats.mostVisitedSite?.visitCount == 2)
        #expect(stats.mostVisitedSite?.id == siteA)
        #expect(stats.topSpecies?.marineLifeUUID == "fish-a")
        #expect(stats.topSpecies?.sightingCount == 2)
    }

    @Test func homeMediaHighlightPresentation_dailySeedIsStableAndShuffleRespectsLimit() {
        let ownerID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let seedA = HomeMediaHighlightPresentation.dailySeed(ownerProfileID: ownerID, referenceDate: day)
        let seedB = HomeMediaHighlightPresentation.dailySeed(ownerProfileID: ownerID, referenceDate: day)
        #expect(seedA == seedB)

        let candidates = (0 ..< 20).map { index in
            HomeMediaHighlight(
                mediaID: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", index))!,
                diveActivityID: UUID(),
                diveNumberLabel: "#\(index + 1)",
                siteDisplayName: "Site \(index)",
                diveSiteID: nil,
                taggedSpeciesCount: 0,
                taggedBuddyCount: 0
            )
        }
        let picks = HomeMediaHighlightPresentation.randomizedHighlights(from: candidates, limit: 8, seed: seedA)
        #expect(picks.count == 8)
        #expect(Set(picks.map(\.mediaID)).count == 8)
    }

    @Test @MainActor func diveMediaVideoAssetSessionCache_evictsOldestBeyondCapacity() {
        #if canImport(AVFoundation)
        DiveMediaVideoAssetSessionCache.shared.clear()
        defer { DiveMediaVideoAssetSessionCache.shared.clear() }

        let asset = AVURLAsset(url: URL(fileURLWithPath: "/dev/null"))
        for index in 0 ... DiveMediaVideoAssetSessionCache.capacity {
            DiveMediaVideoAssetSessionCache.shared.store(asset, localIdentifier: "warm-id-\(index)")
        }

        #expect(DiveMediaVideoAssetSessionCache.shared.videoAsset(for: "warm-id-0") == nil)
        #expect(DiveMediaVideoAssetSessionCache.shared.videoAsset(for: "warm-id-\(DiveMediaVideoAssetSessionCache.capacity)") != nil)
        #expect(DiveMediaVideoAssetSessionCache.capacity == 24)
        #endif
    }

    @Test @MainActor func homeMediaHighlightSessionCache_evictsOldestImageBeyondCarouselLimit() {
        #if canImport(UIKit)
        HomeMediaHighlightSessionCache.shared.clear()
        defer { HomeMediaHighlightSessionCache.shared.clear() }

        let image = UIImage()
        for index in 0 ..< 7 {
            HomeMediaHighlightSessionCache.shared.storeImage(
                image,
                localIdentifier: "img-id-\(index)",
                edge: 480
            )
        }

        #expect(HomeMediaHighlightSessionCache.shared.image(for: "img-id-0", edge: 480) == nil)
        #expect(HomeMediaHighlightSessionCache.shared.image(for: "img-id-6", edge: 480) != nil)
        #expect(HomeMediaHighlightPresentation.carouselLimit == 3)
        #endif
    }

    @Test @MainActor func homeMediaHighlightSessionCache_pinsCarouselIdentifiersDuringTrim() {
        #if canImport(UIKit)
        HomeMediaHighlightSessionCache.shared.clear()
        defer { HomeMediaHighlightSessionCache.shared.clear() }

        let image = UIImage()
        HomeMediaHighlightSessionCache.shared.setPinnedCarouselLocalIdentifiers(["carousel-a", "carousel-b"])
        HomeMediaHighlightSessionCache.shared.storeImage(image, localIdentifier: "carousel-a", edge: 480)
        HomeMediaHighlightSessionCache.shared.storeImage(image, localIdentifier: "carousel-b", edge: 480)

        for index in 0 ..< 6 {
            HomeMediaHighlightSessionCache.shared.storeImage(
                image,
                localIdentifier: "other-\(index)",
                edge: 480
            )
        }

        #expect(HomeMediaHighlightSessionCache.shared.image(for: "carousel-a", edge: 480) != nil)
        #expect(HomeMediaHighlightSessionCache.shared.image(for: "carousel-b", edge: 480) != nil)
        #endif
    }

    @Test func homeOverviewRefreshToken_contentFingerprint_changesWhenDiveMetricsChange() {
        let base = [
            HomeDiveStatsInput(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                maxDepthMeters: 20,
                durationMinutes: 40,
                diveSiteID: nil,
                diveNumberLabel: "#1",
                siteDisplayName: "Wall"
            ),
        ]
        let before = HomeOverviewRefreshToken.contentFingerprint(dives: base, sightingCount: 0, mediaCount: 1)
        var deeper = base
        deeper[0] = HomeDiveStatsInput(
            id: base[0].id,
            maxDepthMeters: 30,
            durationMinutes: base[0].durationMinutes,
            diveSiteID: base[0].diveSiteID,
            diveNumberLabel: base[0].diveNumberLabel,
            siteDisplayName: base[0].siteDisplayName
        )
        let afterDepth = HomeOverviewRefreshToken.contentFingerprint(dives: deeper, sightingCount: 0, mediaCount: 1)
        #expect(before != afterDepth)
    }

    @Test func homeBuddyRosterRefreshToken_fingerprint_changesWhenProfilePhotoChanges() {
        let buddyID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        let before = HomeBuddyRosterRefreshToken.fingerprint(
            buddies: [
                HomeBuddyRosterRefreshToken.BuddyRow(
                    id: buddyID,
                    displayName: "Alex",
                    profilePhoto: Data([0x01])
                ),
            ]
        )
        let after = HomeBuddyRosterRefreshToken.fingerprint(
            buddies: [
                HomeBuddyRosterRefreshToken.BuddyRow(
                    id: buddyID,
                    displayName: "Alex",
                    profilePhoto: Data([0x02])
                ),
            ]
        )
        #expect(before != after)
    }

    @Test func homeOverviewRefreshToken_contentFingerprint_changesWhenBuddyProfilePhotoChanges() {
        let diveID = UUID()
        let buddyID = UUID()
        let tags = [
            HomeBuddyLeaderboardPresentation.TagInput(
                buddyID: buddyID,
                displayName: "Alex",
                profilePhoto: Data([0x01]),
                diveActivityID: diveID
            ),
        ]
        let before = HomeOverviewRefreshToken.contentFingerprint(
            dives: [],
            buddyTags: tags,
            sightingCount: 0,
            mediaCount: 0
        )
        let after = HomeOverviewRefreshToken.contentFingerprint(
            dives: [],
            buddyTags: [
                HomeBuddyLeaderboardPresentation.TagInput(
                    buddyID: buddyID,
                    displayName: "Alex",
                    profilePhoto: Data([0x02]),
                    diveActivityID: diveID
                ),
            ],
            sightingCount: 0,
            mediaCount: 0
        )
        #expect(before != after)
    }

    @Test func homeOverviewRefreshToken_changesWhenDiveMetricsChange() {
        let diveID = UUID()
        let siteID = UUID()
        let base = [
            HomeDiveStatsInput(id: diveID, maxDepthMeters: 20, durationMinutes: 40, diveSiteID: siteID, diveNumberLabel: "#12", siteDisplayName: "Reef"),
        ]
        let before = HomeOverviewRefreshToken.make(dives: base, sightingCount: 0, mediaCount: 1)
        let afterDepth = HomeOverviewRefreshToken.make(
            dives: [HomeDiveStatsInput(id: diveID, maxDepthMeters: 28, durationMinutes: 40, diveSiteID: siteID, diveNumberLabel: "#12", siteDisplayName: "Reef")],
            sightingCount: 0,
            mediaCount: 1
        )
        let afterCount = HomeOverviewRefreshToken.make(
            dives: base + [HomeDiveStatsInput(id: UUID(), maxDepthMeters: 10, durationMinutes: 30, diveSiteID: nil, diveNumberLabel: "#13", siteDisplayName: "Quarry")],
            sightingCount: 0,
            mediaCount: 1
        )
        #expect(before != afterDepth)
        #expect(before != afterCount)
    }

    @Test func homeLifetimeStatsPresentation_formattedAverageDiveSummary_joinsDepthAndDuration() {
        let summary = HomeLifetimeStatsPresentation.formattedAverageDiveSummary(
            depthMeters: 20,
            durationMinutes: 45,
            unitSystem: .metric
        )
        #expect(summary.contains("20.0 m"))
        #expect(summary.contains("45 min"))
        #expect(summary.contains("·"))
    }

    @Test func homeMediaHighlightPresentation_buildCandidates_mapsSiteAndSpecies() {
        let diveID = UUID()
        let mediaID = UUID()
        let siteID = UUID()
        let dives = [
            HomeDiveStatsInput(
                id: diveID,
                maxDepthMeters: 18,
                durationMinutes: 40,
                diveSiteID: siteID,
                diveNumberLabel: "#42",
                siteDisplayName: "Reef"
            ),
        ]
        let candidates = HomeMediaHighlightPresentation.buildCandidates(
            mediaPhotos: [HomeMediaHighlightSource(mediaID: mediaID, diveActivityID: diveID)],
            dives: dives,
            taggedSpeciesCountByMediaID: [mediaID: 2]
        )
        #expect(candidates.count == 1)
        #expect(candidates[0].siteDisplayName == "Reef")
        #expect(candidates[0].diveActionLabel == "#42 Reef")
        #expect(candidates[0].taggedSpeciesCount == 2)
        #expect(candidates[0].hasTaggedSpecies)
        #expect(candidates[0].linkedTripTitle == nil)
    }

    @Test func homeMediaHighlightPresentation_buildCandidates_mapsLinkedTripTitleAndAccent() {
        let diveID = UUID()
        let mediaID = UUID()
        let tripID = UUID()
        let dives = [
            HomeDiveStatsInput(
                id: diveID,
                maxDepthMeters: 18,
                durationMinutes: 40,
                diveSiteID: nil,
                diveNumberLabel: "#3",
                siteDisplayName: "Salt Pier",
                linkedTripID: tripID,
                linkedTripTitle: "Bonaire 2026",
                linkedTripAccentColorIndex: 2
            ),
        ]
        let candidates = HomeMediaHighlightPresentation.buildCandidates(
            mediaPhotos: [HomeMediaHighlightSource(mediaID: mediaID, diveActivityID: diveID)],
            dives: dives
        )
        #expect(candidates.count == 1)
        #expect(candidates[0].linkedTripTitle == "Bonaire 2026")
        #expect(candidates[0].linkedTripAccentColorIndex == 2)
        #expect(candidates[0].showsLinkedTrip)
    }

    @Test func homeMediaHighlightPresentation_highlightsByRefreshingTagCounts_preservesSlideOrder() {
        let mediaA = UUID()
        let mediaB = UUID()
        let diveID = UUID()
        let highlights = [
            HomeMediaHighlight(
                mediaID: mediaA,
                diveActivityID: diveID,
                diveNumberLabel: "#1",
                siteDisplayName: "Reef",
                diveSiteID: nil,
                taggedSpeciesCount: 0,
                taggedBuddyCount: 0
            ),
            HomeMediaHighlight(
                mediaID: mediaB,
                diveActivityID: diveID,
                diveNumberLabel: "#1",
                siteDisplayName: "Reef",
                diveSiteID: nil,
                taggedSpeciesCount: 1,
                taggedBuddyCount: 0
            ),
        ]

        let refreshed = HomeMediaHighlightPresentation.highlightsByRefreshingTagCounts(
            highlights,
            taggedSpeciesCountByMediaID: [mediaA: 2, mediaB: 1],
            taggedBuddyCountByMediaID: [mediaA: 1]
        )

        #expect(refreshed.map(\.mediaID) == [mediaA, mediaB])
        #expect(refreshed[0].taggedSpeciesCount == 2)
        #expect(refreshed[0].taggedBuddyCount == 1)
        #expect(refreshed[0].hasTaggedBuddies)
        #expect(refreshed[1].taggedSpeciesCount == 1)
        #expect(refreshed[1].taggedBuddyCount == 0)
    }

    @Test func homeMediaHighlightPresentation_taggedBuddyCountByMediaID_countsMultipleTags() {
        let diveID = UUID()
        let mediaID = UUID()
        let ownerDiveIDs: Set<UUID> = [diveID]
        let counts = HomeMediaHighlightPresentation.taggedBuddyCountByMediaID(
            buddyTags: [
                HomeMediaHighlightBuddyTagInput(mediaPhotoID: mediaID, diveActivityID: diveID),
                HomeMediaHighlightBuddyTagInput(mediaPhotoID: mediaID, diveActivityID: diveID),
                HomeMediaHighlightBuddyTagInput(mediaPhotoID: UUID(), diveActivityID: diveID),
            ],
            ownerDiveIDs: ownerDiveIDs
        )
        #expect(counts[mediaID] == 2)
    }

    @Test func homeMediaHighlightPresentation_taggedBuddyRowsByMediaID_dedupesAndSorts() {
        let diveID = UUID()
        let mediaID = UUID()
        let buddyA = UUID()
        let buddyB = UUID()
        let ownerDiveIDs: Set<UUID> = [diveID]
        let rows = HomeMediaHighlightPresentation.taggedBuddyRowsByMediaID(
            buddyTags: [
                HomeMediaHighlightBuddyTagInput(
                    mediaPhotoID: mediaID,
                    diveActivityID: diveID,
                    buddyID: buddyB,
                    displayName: "Zoe"
                ),
                HomeMediaHighlightBuddyTagInput(
                    mediaPhotoID: mediaID,
                    diveActivityID: diveID,
                    buddyID: buddyA,
                    displayName: "Alex"
                ),
                HomeMediaHighlightBuddyTagInput(
                    mediaPhotoID: mediaID,
                    diveActivityID: diveID,
                    buddyID: buddyA,
                    displayName: "Alex"
                ),
            ],
            ownerDiveIDs: ownerDiveIDs
        )
        #expect(rows[mediaID]?.map(\.buddyID) == [buddyA, buddyB])
        #expect(rows[mediaID]?.map(\.displayName) == ["Alex", "Zoe"])
    }

    @Test func homeOverviewRefreshToken_carouselTagFingerprint_changesWhenMediaTagsChange() {
        let diveID = UUID()
        let mediaID = UUID()
        let ownerDiveIDs: Set<UUID> = [diveID]
        let before = HomeOverviewRefreshToken.carouselTagFingerprint(
            sightings: [],
            buddyTags: [],
            ownerDiveIDs: ownerDiveIDs
        )
        let afterSpecies = HomeOverviewRefreshToken.carouselTagFingerprint(
            sightings: [HomeMediaHighlightSightingInput(mediaPhotoID: mediaID, diveActivityID: diveID)],
            buddyTags: [],
            ownerDiveIDs: ownerDiveIDs
        )
        let afterBuddy = HomeOverviewRefreshToken.carouselTagFingerprint(
            sightings: [HomeMediaHighlightSightingInput(mediaPhotoID: mediaID, diveActivityID: diveID)],
            buddyTags: [
                HomeMediaHighlightBuddyTagInput(
                    mediaPhotoID: mediaID,
                    diveActivityID: diveID,
                    buddyID: UUID()
                ),
            ],
            ownerDiveIDs: ownerDiveIDs
        )
        #expect(before != afterSpecies)
        #expect(afterSpecies != afterBuddy)
    }

    @Test func homeMediaCarouselEmptyPresentation_definesEncouragingCopyAndFrameLayout() {
        #expect(HomeMediaCarouselEmptyPresentation.frameCount == 3)
        #expect(HomeMediaCarouselEmptyPresentation.animationCycleSeconds > 0)
        #expect(HomeMediaCarouselEmptyPresentation.title.contains("highlight reel"))
        #expect(HomeMediaCarouselEmptyPresentation.message.contains("Logbook"))
        #expect(HomeMediaCarouselEmptyPresentation.frameOffsetAmplitude(index: 2) > HomeMediaCarouselEmptyPresentation.frameOffsetAmplitude(index: 0))
        #expect(HomeMediaCarouselEmptyPresentation.contentDownshift == 80)
    }

    @Test func homeMediaHighlightPresentation_excludesLongVideosFromCarouselCandidates() {
        let diveID = UUID()
        let shortVideoID = UUID()
        let longVideoID = UUID()
        let photoID = UUID()
        let dives = [
            HomeDiveStatsInput(
                id: diveID,
                maxDepthMeters: 10,
                durationMinutes: 30,
                diveSiteID: nil,
                diveNumberLabel: "#1",
                siteDisplayName: "Site"
            ),
        ]
        let sources = [
            HomeMediaHighlightSource(
                mediaID: photoID,
                diveActivityID: diveID,
                mediaKind: .image
            ),
            HomeMediaHighlightSource(
                mediaID: shortVideoID,
                diveActivityID: diveID,
                mediaKind: .video,
                videoDurationSeconds: 29
            ),
            HomeMediaHighlightSource(
                mediaID: longVideoID,
                diveActivityID: diveID,
                mediaKind: .video,
                videoDurationSeconds: 31
            ),
        ]
        let candidates = HomeMediaHighlightPresentation.buildCandidates(
            mediaPhotos: sources,
            dives: dives
        )
        #expect(candidates.map(\.mediaID) == [photoID, shortVideoID])
        #expect(HomeMediaHighlightPresentation.isEligibleCarouselSource(sources[1]))
        #expect(!HomeMediaHighlightPresentation.isEligibleCarouselSource(sources[2]))
        #expect(HomeMediaHighlightPresentation.carouselVideoMaxDurationSeconds == 30)
    }

    @Test func homeMediaHighlightWarmupPresentation_overlayDismissReady() {
        #expect(HomeMediaHighlightWarmupPresentation.bootstrapOverlayMaxWaitSeconds == 5)
        #expect(
            HomeMediaHighlightWarmupPresentation.isOverlayDismissReady(
                isBootstrapReady: true,
                firstSlideHasDisplayableImage: false
            )
        )
        #expect(
            HomeMediaHighlightWarmupPresentation.isOverlayDismissReady(
                isBootstrapReady: false,
                firstSlideHasDisplayableImage: true
            )
        )
        #expect(
            !HomeMediaHighlightWarmupPresentation.isOverlayDismissReady(
                isBootstrapReady: false,
                firstSlideHasDisplayableImage: false
            )
        )
    }

    @Test func homeMediaHighlightPresentation_taggedSpeciesCountByMediaID_countsMultipleTags() {
        let diveID = UUID()
        let mediaID = UUID()
        let counts = HomeMediaHighlightPresentation.taggedSpeciesCountByMediaID(
            sightings: [
                HomeMediaHighlightSightingInput(mediaPhotoID: mediaID, diveActivityID: diveID),
                HomeMediaHighlightSightingInput(mediaPhotoID: mediaID, diveActivityID: diveID),
                HomeMediaHighlightSightingInput(mediaPhotoID: UUID(), diveActivityID: diveID),
            ],
            ownerDiveIDs: [diveID]
        )
        #expect(counts[mediaID] == 2)
    }

    @Test func homeMediaHighlightPresentation_diveActionLabel_joinsNumberAndSite() {
        #expect(
            HomeMediaHighlightPresentation.diveActionLabel(
                diveNumberLabel: "#12",
                siteDisplayName: "Salt Pier"
            ) == "#12 Salt Pier"
        )
        #expect(
            HomeMediaHighlightPresentation.diveActionLabel(
                diveNumberLabel: "-",
                siteDisplayName: "Quarry"
            ) == "Quarry"
        )
    }

    @Test func homeMediaHighlightWarmupPresentation_bootstrapQualityAndReadiness() {
        #expect(HomeMediaHighlightWarmupPresentation.startupFullQualityCount == 1)
        #expect(HomeMediaHighlightWarmupPresentation.bootstrapQuality(forCarouselIndex: 0) == .full)
        #expect(HomeMediaHighlightWarmupPresentation.bootstrapQuality(forCarouselIndex: 1) == .preview)
        #expect(HomeMediaHighlightWarmupPresentation.bootstrapQuality(forCarouselIndex: 2) == .preview)
        #expect(HomeMediaHighlightWarmupPresentation.heroImageEdge(containerWidth: 390) == 780)
        #expect(HomeMediaHighlightWarmupPresentation.heroImageEdge(containerWidth: 500) == 900)

        #expect(
            HomeMediaHighlightWarmupPresentation.isBootstrapReady(
                fullReadyCount: 1,
                previewOrFullReadyCount: 1,
                totalCount: 3
            )
        )
        #expect(
            !HomeMediaHighlightWarmupPresentation.isBootstrapReady(
                fullReadyCount: 0,
                previewOrFullReadyCount: 3,
                totalCount: 3
            )
        )
        #expect(HomeMediaHighlightWarmupPresentation.backgroundFullQualityIndices(totalCount: 3) == [1, 2])
    }

    @Test func logbookActivityRowLayout_usesCompactSpacingTokens() {
        #expect(LogbookActivityRowLayout.contentSpacing == 4)
        #expect(LogbookActivityRowLayout.cardPadding == AppTheme.Spacing.sm)
        #expect(DiveActivityMediaPresentation.logbookRowMediaPreviewMinExtent == 48)
    }

    @Test func appListTileCardChrome_matchesLogbookActivityRowFillAndStroke() {
        #expect(AppListTileCardChrome.fill == AppTheme.Colors.surfaceElevated)
        #expect(AppListTileCardChrome.strokeWidth == 1)
    }

    @Test func diveMediaVideoRequestQuality_cachesInSession() {
        #expect(DiveMediaVideoRequestQuality.fullQuality.cachesInSession)
        #expect(DiveMediaVideoRequestQuality.homeCarousel.cachesInSession)
    }

    @Test func diveActivityMediaPresentation_overviewUsesPreviewVideoQuality() {
        #expect(DiveActivityMediaPresentation.overviewLibraryVideoQuality == .homeCarousel)
    }

    @Test func rootStackReturnNavigationPresentation_tabBarRestoreAndLogbookSkip() {
        #expect(RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: 0))
        #expect(!RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: 1))
        #expect(
            RootStackReturnNavigationPresentation.shouldSkipLogbookCacheRefreshOnReturn(
                hasPerformedInitialCacheBuild: true,
                hasDisplayRows: true
            )
        )
        #expect(
            !RootStackReturnNavigationPresentation.shouldSkipLogbookCacheRefreshOnReturn(
                hasPerformedInitialCacheBuild: false,
                hasDisplayRows: true
            )
        )
        #expect(
            !RootStackReturnNavigationPresentation.shouldSkipLogbookCacheRefreshOnReturn(
                hasPerformedInitialCacheBuild: true,
                hasDisplayRows: false
            )
        )
    }

    @Test func homeReturnNavigationPresentation_skipsRedundantRebuildWhenCarouselReady() {
        #expect(
            HomeReturnNavigationPresentation.shouldSkipFullRebuildOnReturn(
                hasPerformedInitialBuild: true,
                carouselSlidesAreDisplayable: true,
                hasCarouselHighlights: true
            )
        )
        #expect(
            !HomeReturnNavigationPresentation.shouldSkipFullRebuildOnReturn(
                hasPerformedInitialBuild: false,
                carouselSlidesAreDisplayable: true,
                hasCarouselHighlights: true
            )
        )
        #expect(
            !HomeReturnNavigationPresentation.shouldSkipFullRebuildOnReturn(
                hasPerformedInitialBuild: true,
                carouselSlidesAreDisplayable: false,
                hasCarouselHighlights: true
            )
        )
    }

    @Test func homeReturnNavigationPresentation_skipsForegroundRebuildWhenCarouselReady() {
        #expect(
            HomeReturnNavigationPresentation.shouldSkipFullRebuildOnForegroundActivation(
                hasPerformedInitialBuild: true,
                carouselSlidesAreDisplayable: true,
                hasCarouselHighlights: true
            )
        )
        #expect(
            !HomeReturnNavigationPresentation.shouldSkipFullRebuildOnForegroundActivation(
                hasPerformedInitialBuild: true,
                carouselSlidesAreDisplayable: true,
                hasCarouselHighlights: false
            )
        )
    }

    @Test func homeOverviewAggregateComputer_aggregatesOwnerMediaAndSightings() {
        let diveID = UUID()
        let mediaID = UUID()
        let siteID = UUID()
        let activitySeed = LogbookActivitySnapshotSeed(
            id: diveID,
            sourceDiveId: nil,
            startTime: Date(timeIntervalSinceReferenceDate: 0),
            maxDepthMeters: 18,
            durationMinutes: 42,
            bottomTimeSeconds: nil,
            diveNumber: 1,
            diveNumberExplicitlyNone: false,
            displayName: "Blue Hole",
            formattedStartDateOnly: "Jan 1",
            resolvedSiteNameLowercased: "blue hole",
            activityTagNames: [],
            buddyDisplayNames: [],
            previewMediaPhotoID: mediaID,
            linkedTripID: nil
        )
        let input = HomeOverviewBuildInput(
            activitySeeds: [activitySeed],
            tripSeeds: [],
            diveSiteIDByActivityID: [diveID: siteID],
            buddyTagSeeds: [],
            mediaPhotoSeeds: [
                HomeOverviewMediaPhotoSeed(
                    id: mediaID,
                    diveActivityID: diveID,
                    sortOrder: 0,
                    mediaKind: DiveMediaKind.image.rawValue,
                    photosLocalIdentifier: "test-photo"
                ),
            ],
            sightingSeeds: [
                HomeOverviewSightingSeed(
                    mediaPhotoID: mediaID,
                    diveActivityID: diveID,
                    marineLifeUUID: "turtle-uuid",
                    commonName: "Green sea turtle"
                ),
            ],
            mediaBuddyTagSeeds: [],
            automaticallyRenumberDives: true,
            displayUnits: .metric,
            ownerProfileID: UUID(),
            selfBuddyID: nil,
            referenceDate: Date(timeIntervalSinceReferenceDate: 0)
        )

        let result = HomeOverviewAggregateComputer.build(from: input)
        #expect(result.diveStatsInputs.count == 1)
        #expect(result.diveStatsInputs[0].diveSiteID == siteID)
        #expect(result.ownerMediaPhotoIDs == [mediaID])
        #expect(result.sightingCountInputs.count == 1)
        #expect(result.lifetimeStats.diveCount == 1)
        #expect(result.mediaHighlightSightings.count == 1)
        #expect(result.contentFingerprint != 0)
    }

    @Test func homeOverviewAggregateComputer_ignoresSightingsOutsideOwnerDives() {
        let ownerDiveID = UUID()
        let otherDiveID = UUID()
        let activitySeed = LogbookActivitySnapshotSeed(
            id: ownerDiveID,
            sourceDiveId: nil,
            startTime: Date(timeIntervalSinceReferenceDate: 0),
            maxDepthMeters: 12,
            durationMinutes: 30,
            bottomTimeSeconds: nil,
            diveNumber: 1,
            diveNumberExplicitlyNone: false,
            displayName: "Reef",
            formattedStartDateOnly: "Jan 2",
            resolvedSiteNameLowercased: "reef",
            activityTagNames: [],
            buddyDisplayNames: [],
            previewMediaPhotoID: nil,
            linkedTripID: nil
        )
        let input = HomeOverviewBuildInput(
            activitySeeds: [activitySeed],
            tripSeeds: [],
            diveSiteIDByActivityID: [ownerDiveID: nil],
            buddyTagSeeds: [],
            mediaPhotoSeeds: [],
            sightingSeeds: [
                HomeOverviewSightingSeed(
                    mediaPhotoID: UUID(),
                    diveActivityID: otherDiveID,
                    marineLifeUUID: "fish-uuid",
                    commonName: "Fish"
                ),
            ],
            mediaBuddyTagSeeds: [],
            automaticallyRenumberDives: false,
            displayUnits: .metric,
            ownerProfileID: UUID(),
            selfBuddyID: nil,
            referenceDate: Date(timeIntervalSinceReferenceDate: 0)
        )

        let result = HomeOverviewAggregateComputer.build(from: input)
        #expect(result.sightingCountInputs.isEmpty)
        #expect(result.mediaHighlightSightings.isEmpty)
    }

    @Test func appPerformanceSignpost_intervalNamesAreStable() {
        #expect(AppPerformanceSignpost.Interval.launchContainerLoad.rawValue == "LaunchContainerLoad")
        #expect(AppPerformanceSignpost.Interval.launchSessionValidation.rawValue == "LaunchSessionValidation")
        #expect(AppPerformanceSignpost.Interval.homeOverviewRebuild.rawValue == "HomeOverviewRebuild")
        #expect(AppPerformanceSignpost.Interval.tripDetailContentRebuild.rawValue == "TripDetailContentRebuild")
    }

    @Test func appLaunchSessionRestorePresentation_persistedProfileID_parsesStoredUUID() {
        let id = UUID()
        #expect(
            AppLaunchSessionRestorePresentation.persistedProfileID(storedUUIDString: id.uuidString) == id
        )
        #expect(AppLaunchSessionRestorePresentation.persistedProfileID(storedUUIDString: nil) == nil)
        #expect(AppLaunchSessionRestorePresentation.persistedProfileID(storedUUIDString: "not-a-uuid") == nil)
    }

    @Test func appLaunchSessionValidationPolicy_offlineFirstKeepsSessionWhenCredentialCheckFails() {
        #expect(!AppLaunchSessionValidationPolicy.shouldSignOut(credentialState: nil, checkFailed: true))
    }

    @Test func appLaunchSessionValidationPolicy_signsOutWhenCredentialRevoked() {
        #expect(
            AppLaunchSessionValidationPolicy.shouldSignOut(
                credentialState: .revoked,
                checkFailed: false
            )
        )
        #expect(
            !AppLaunchSessionValidationPolicy.shouldSignOut(
                credentialState: .authorized,
                checkFailed: false
            )
        )
    }

    @Test @MainActor func homeMediaHighlightWarmup_repinCarouselSessionCache_restoresPinnedIdentifiersAfterClear() {
        #if canImport(UIKit)
        HomeMediaHighlightSessionCache.shared.clear()
        defer { HomeMediaHighlightSessionCache.shared.clear() }

        let mediaID = UUID()
        let media = DiveMediaPhoto(
            id: mediaID,
            photosLocalIdentifier: "carousel-repin-test"
        )
        let highlight = HomeMediaHighlight(
            mediaID: mediaID,
            diveActivityID: UUID(),
            diveNumberLabel: "#1",
            siteDisplayName: "Reef",
            diveSiteID: nil,
            taggedSpeciesCount: 0,
            taggedBuddyCount: 0
        )
        let image = UIImage(systemName: "photo")!
        HomeMediaHighlightWarmup.repinCarouselSessionCache(
            highlights: [highlight],
            mediaByID: [mediaID: media]
        )
        HomeMediaHighlightSessionCache.shared.storeImage(
            image,
            localIdentifier: "carousel-repin-test",
            edge: HomeMediaHighlightWarmupPresentation.previewImageEdge
        )

        HomeMediaHighlightSessionCache.shared.clear()
        #expect(!HomeMediaHighlightWarmup.isHighlightDisplayable(highlight, media: media))

        HomeMediaHighlightWarmup.repinCarouselSessionCache(
            highlights: [highlight],
            mediaByID: [mediaID: media]
        )
        HomeMediaHighlightSessionCache.shared.storeImage(
            image,
            localIdentifier: "carousel-repin-test",
            edge: HomeMediaHighlightWarmupPresentation.previewImageEdge
        )
        #expect(HomeMediaHighlightWarmup.isHighlightDisplayable(highlight, media: media))
        #endif
    }

    @Test func diveMediaProgressivePresentation_posterTargetSize_beforeLayoutUsesFastEdge() {
        let poster = DiveMediaProgressivePresentation.posterTargetSize(screenPixelWidth: 0)
        #expect(poster.width == DiveMediaProgressivePresentation.posterImageEdge)
    }

    @Test func diveMediaProgressivePresentation_posterAndUpgradePolicy() {
        let poster = DiveMediaProgressivePresentation.posterTargetSize(screenPixelWidth: 1_200)
        #expect(poster.width == DiveMediaProgressivePresentation.posterImageEdge)
        #expect(
            DiveMediaProgressivePresentation.shouldUpgradeToFullVideo(
                isPlaybackActive: true,
                isPausedByUserHold: false,
                currentFidelity: .preview
            )
        )
        #expect(
            !DiveMediaProgressivePresentation.shouldUpgradeToFullVideo(
                isPlaybackActive: false,
                isPausedByUserHold: false,
                currentFidelity: .preview
            )
        )
        #expect(
            DiveMediaProgressivePresentation.shouldUpgradeToFullVideo(
                isPlaybackActive: false,
                isPausedByUserHold: false,
                currentFidelity: .preview,
                allowsBackgroundUpgrade: true
            )
        )
        #expect(
            !DiveMediaProgressivePresentation.shouldUpgradeToFullVideo(
                isPlaybackActive: true,
                isPausedByUserHold: true,
                currentFidelity: .preview
            )
        )
        #expect(DiveMediaProgressivePresentation.prefetchNeighborIndices(selectedIndex: 2, itemCount: 5) == [2, 1, 3])
        #expect(DiveMediaProgressivePresentation.prefetchNeighborIndices(selectedIndex: 0, itemCount: 3) == [0, 1])

        let sourceKey = "asset:ABC"
        #expect(
            DiveMediaProgressivePresentation.resolvedKey(
                sourceIdentityKey: sourceKey,
                fidelity: .preview
            ) == "asset:ABC|preview"
        )
        #expect(
            DiveMediaProgressivePresentation.isVideoQualityFidelityUpgrade(
                from: "asset:ABC|preview",
                to: "asset:ABC|full"
            )
        )
        #expect(
            !DiveMediaProgressivePresentation.isVideoQualityFidelityUpgrade(
                from: "asset:ABC|full",
                to: "asset:XYZ|full"
            )
        )
        #expect(
            DiveMediaProgressivePresentation.previewResolvedKey(forFullResolvedKey: "asset:ABC|full")
                == "asset:ABC|preview"
        )
        let previewIdentity = DiveMediaProgressivePresentation.playerRepresentableIdentity(
            sourceIdentityKey: sourceKey,
            playbackActivationGeneration: 2
        )
        let fullIdentity = DiveMediaProgressivePresentation.playerRepresentableIdentity(
            sourceIdentityKey: sourceKey,
            playbackActivationGeneration: 2
        )
        #expect(previewIdentity == fullIdentity)
        #expect(previewIdentity == "asset:ABC-activate-2")
    }

    @Test func diveMediaVideoRequestQuality_sessionCacheKeySuffix_isDistinct() {
        #expect(DiveMediaVideoRequestQuality.fullQuality.sessionCacheKeySuffix == "full")
        #expect(DiveMediaVideoRequestQuality.homeCarousel.sessionCacheKeySuffix == "preview")
        #expect(
            DiveMediaVideoAssetSessionCache.storageKey(
                localIdentifier: "abc",
                quality: .fullQuality
            ) == "abc|full"
        )
        #expect(
            DiveMediaVideoAssetSessionCache.storageKey(
                localIdentifier: "abc",
                quality: .homeCarousel
            ) == "abc|preview"
        )
    }

    @Test func diveActivityMediaPresentation_mediaControlActiveState_reflectsTagsAndFishialConfirm() {
        #expect(!DiveActivityMediaPresentation.marineLifeTagControlIsActive(taggedSpeciesCount: 0))
        #expect(DiveActivityMediaPresentation.marineLifeTagControlIsActive(taggedSpeciesCount: 1))

        #expect(!DiveActivityMediaPresentation.fishialIdentifyControlIsActive(confirmedSpeciesName: nil))
        #expect(!DiveActivityMediaPresentation.fishialIdentifyControlIsActive(confirmedSpeciesName: "  "))
        #expect(
            DiveActivityMediaPresentation.fishialIdentifyControlIsActive(
                confirmedSpeciesName: "Holacanthus ciliaris"
            )
        )
    }

    @Test func marineLifeMediaTagPresentation_hasTaggedSpeciesOnMedia_countsUniqueSpecies() {
        let taggedMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_100_000))
        let otherMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_100_100))
        let sightings = [
            SightingInstance(
                marineLifeUUID: "fish-a",
                sightingDateTime: Date(timeIntervalSince1970: 4_100_000),
                mediaPhoto: taggedMedia
            ),
            SightingInstance(
                marineLifeUUID: "fish-a",
                sightingDateTime: Date(timeIntervalSince1970: 4_100_050),
                mediaPhoto: taggedMedia
            ),
            SightingInstance(
                marineLifeUUID: "fish-b",
                sightingDateTime: Date(timeIntervalSince1970: 4_100_100),
                mediaPhoto: otherMedia
            ),
        ]

        #expect(
            MarineLifeMediaTagPresentation.hasTaggedSpeciesOnMedia(
                mediaPhotoID: taggedMedia.id,
                sightings: sightings
            )
        )
        #expect(
            !MarineLifeMediaTagPresentation.hasTaggedSpeciesOnMedia(
                mediaPhotoID: UUID(),
                sightings: sightings
            )
        )
    }

    @Test func homeMediaHighlightWarmupPresentation_shouldLoadHeroImage_whenPreviewOnlyCached() {
        #expect(HomeMediaHighlightWarmupPresentation.shouldLoadHeroImage(hasCachedImageAtTargetEdge: false))
        #expect(!HomeMediaHighlightWarmupPresentation.shouldLoadHeroImage(hasCachedImageAtTargetEdge: true))
    }

    @Test func homeMediaHighlightWarmup_shouldStorePreviewAndHeroInSessionCache() {
        #expect(HomeMediaHighlightWarmup.shouldStoreInSessionCache(edge: 480))
        #expect(HomeMediaHighlightWarmup.shouldStoreInSessionCache(edge: 780))
        #expect(!HomeMediaHighlightWarmup.shouldStoreInSessionCache(edge: 200))
    }

    @Test func homeMediaHighlightWarmup_bootstrapTier_warmsFirstSlidesAtFullQuality() {
        for index in 0 ..< HomeMediaHighlightPresentation.carouselLimit {
            let quality = HomeMediaHighlightWarmupPresentation.bootstrapQuality(forCarouselIndex: index)
            if index < HomeMediaHighlightWarmupPresentation.startupFullQualityCount {
                #expect(quality == .full)
            } else {
                #expect(quality == .preview)
            }
        }
    }

    @Test func homeMediaCarouselLayout_slideChromeBottomInset_sitsInPanelOverlapBand() {
        let inset = HomeMediaCarouselLayout.slideChromeBottomInset
        #expect(inset < HomeLifetimeStatsLayout.panelOverlap + AppTheme.Spacing.sm)
        #expect(inset >= HomeLifetimeStatsLayout.panelOverlap - AppTheme.Spacing.lg)
        #expect(HomeMediaCarouselPresentation.keepsAllSlidesLoaded(slideCount: 3))
        #expect(HomeMediaCarouselPresentation.keepsAllSlidesLoaded(slideCount: 1))
        #expect(!HomeMediaCarouselPresentation.keepsAllSlidesLoaded(slideCount: 0))
        #expect(!HomeMediaCarouselPresentation.keepsAllSlidesLoaded(slideCount: 4))
    }

    @Test func homeMediaCarouselLayout_heroHeight_includesTopSafeAreaAndStatsOverlap() {
        let bottomExtension = HomeLifetimeStatsLayout.heroBottomExtension
        let height = HomeMediaCarouselLayout.heroHeight(
            width: 390,
            topSafeAreaInset: 59,
            additionalBottomExtension: bottomExtension
        )
        #expect(height > 390 * 0.70)
        #expect(height >= 390 * HomeMediaCarouselLayout.heroHeightToWidthRatio + 59 + bottomExtension - 0.001)

        let gradientHeight = HomeMediaCarouselLayout.headerGradientHeight(
            headerOverlayHeight: 112,
            topSafeAreaInset: 59,
            heroHeight: height
        )
        #expect(gradientHeight >= 112 + 96)
        #expect(gradientHeight >= height * 0.52 - 0.001)
    }

    @Test func homeMediaCarouselLayout_carouselContentHeight_compensatesForPushedHeroBandBleed() {
        let bandHeight: CGFloat = 520
        let safeTop: CGFloat = 59
        #expect(
            HomeMediaCarouselLayout.carouselContentHeight(
                heroBandHeight: bandHeight,
                topSafeAreaInset: safeTop,
                appliesOwnTopSafeAreaBleed: true
            ) == bandHeight
        )
        #expect(
            HomeMediaCarouselLayout.carouselContentHeight(
                heroBandHeight: bandHeight,
                topSafeAreaInset: safeTop,
                appliesOwnTopSafeAreaBleed: false
            ) == bandHeight + safeTop
        )
    }

    @Test func homeMediaCarouselPresentation_nextIndex_wrapsAndRequiresMultipleSlides() {
        #expect(HomeMediaCarouselPresentation.nextIndex(after: 0, count: 3) == 1)
        #expect(HomeMediaCarouselPresentation.nextIndex(after: 2, count: 3) == 0)
        #expect(HomeMediaCarouselPresentation.loopingPagerSlideCount(slideCount: 3) == 4)
        #expect(HomeMediaCarouselPresentation.loopingPagerSlideCount(slideCount: 1) == 1)
        #expect(HomeMediaCarouselPresentation.logicalSlideIndex(pagerIndex: 3, slideCount: 3) == 0)
        #expect(HomeMediaCarouselPresentation.nextLoopingPagerIndex(after: 2, slideCount: 3) == 3)
        #expect(HomeMediaCarouselPresentation.nextLoopingPagerIndex(after: 0, slideCount: 3) == 1)
        #expect(HomeMediaCarouselPresentation.shouldResetLoopingPagerIndex(pagerIndex: 3, slideCount: 3))
        #expect(!HomeMediaCarouselPresentation.shouldResetLoopingPagerIndex(pagerIndex: 2, slideCount: 3))
        #expect(HomeMediaCarouselPresentation.nextIndex(after: 0, count: 0) == 0)
        #expect(HomeMediaCarouselPresentation.shouldAutoAdvance(slideCount: 1) == false)
        #expect(HomeMediaCarouselPresentation.shouldAutoAdvance(slideCount: 2) == true)
        #expect(HomeMediaCarouselPresentation.shouldRestartClipAfterPlaybackFinished(slideCount: 0) == true)
        #expect(HomeMediaCarouselPresentation.shouldRestartClipAfterPlaybackFinished(slideCount: 1) == true)
        #expect(HomeMediaCarouselPresentation.shouldRestartClipAfterPlaybackFinished(slideCount: 3) == false)
        #expect(HomeMediaCarouselPresentation.photoDisplaySeconds == 10)
    }

    @Test func homeMediaCarouselPresentation_shouldBumpPlaybackResumeWhenAllowed() {
        #expect(
            HomeMediaCarouselPresentation.shouldBumpPlaybackResumeWhenAllowed(
                wasPlaybackAllowed: false,
                isPlaybackAllowed: true
            )
        )
        #expect(
            !HomeMediaCarouselPresentation.shouldBumpPlaybackResumeWhenAllowed(
                wasPlaybackAllowed: true,
                isPlaybackAllowed: true
            )
        )
        #expect(
            !HomeMediaCarouselPresentation.shouldBumpPlaybackResumeWhenAllowed(
                wasPlaybackAllowed: false,
                isPlaybackAllowed: false
            )
        )
        #expect(
            !HomeMediaCarouselPresentation.shouldBumpPlaybackResumeWhenAllowed(
                wasPlaybackAllowed: true,
                isPlaybackAllowed: false
            )
        )
        #expect(!HomeMediaCarouselPresentation.bumpsPlaybackResumeWhenInteractionHoldEnds)
    }

    @Test @MainActor func homeMediaCarouselPresentation_carouselVideoSourceIdentityKeys_collectsVideoSlides() {
        let videoID = UUID()
        let photoID = UUID()
        let video = DiveMediaPhoto(
            sortOrder: 0,
            mediaKind: .video,
            photosLocalIdentifier: "video-asset-id"
        )
        video.id = videoID
        let photo = DiveMediaPhoto(sortOrder: 1, mediaKind: .image)
        photo.id = photoID
        let highlights = [
            HomeMediaHighlight(
                mediaID: videoID,
                diveActivityID: UUID(),
                diveNumberLabel: "#1",
                siteDisplayName: "Reef",
                diveSiteID: nil,
                taggedSpeciesCount: 0,
                taggedBuddyCount: 0
            ),
            HomeMediaHighlight(
                mediaID: photoID,
                diveActivityID: UUID(),
                diveNumberLabel: "#2",
                siteDisplayName: "Wall",
                diveSiteID: nil,
                taggedSpeciesCount: 0,
                taggedBuddyCount: 0
            ),
        ]
        let keys = HomeMediaCarouselPresentation.carouselVideoSourceIdentityKeys(
            highlights: highlights,
            mediaByID: [videoID: video, photoID: photo]
        )
        #expect(keys.count == 1)
        #expect(keys.first == video.videoPlaybackSource?.identityKey)
    }

    @Test func homeMediaCarouselPresentation_shouldAdvanceFromSlide_onlyWhenVisible() {
        #expect(
            HomeMediaCarouselPresentation.shouldAdvanceFromSlide(
                selectedIndex: 0,
                finishingSlideIndex: 0,
                isPlaybackAllowed: true
            )
        )
        #expect(
            !HomeMediaCarouselPresentation.shouldAdvanceFromSlide(
                selectedIndex: 1,
                finishingSlideIndex: 0,
                isPlaybackAllowed: true
            )
        )
        #expect(
            !HomeMediaCarouselPresentation.shouldAdvanceFromSlide(
                selectedIndex: 0,
                finishingSlideIndex: 0,
                isPlaybackAllowed: false
            )
        )
        #expect(
            !HomeMediaCarouselPresentation.shouldAdvanceFromSlide(
                selectedIndex: 0,
                finishingSlideIndex: 0,
                isPlaybackAllowed: true,
                holdsSlideForInteraction: true
            )
        )
    }

    @Test func homeMediaCarouselPresentation_holdsSlideForInteraction_whenOverlayOrBuddyListOpen() {
        #expect(
            HomeMediaCarouselPresentation.holdsSlideForInteraction(
                showsMarineLifeOverlay: true,
                hasExpandedBuddyList: false
            )
        )
        #expect(
            HomeMediaCarouselPresentation.holdsSlideForInteraction(
                showsMarineLifeOverlay: false,
                hasExpandedBuddyList: true
            )
        )
        #expect(
            !HomeMediaCarouselPresentation.holdsSlideForInteraction(
                showsMarineLifeOverlay: false,
                hasExpandedBuddyList: false
            )
        )
    }

    @Test func homeMediaCarouselPresentation_marineLifeCarouselOverlaySizing_isCompact() {
        let size = HomeMediaCarouselPresentation.marineLifeOverlaySize(width: 390, height: 420)
        #expect(size.width == 390)
        #expect(size.height == 420)
        #expect(HomeMediaCarouselPresentation.marineLifeOverlayCornerRadius == 0)
        let bandHeight: CGFloat = 520
        let safeTop: CGFloat = 59
        let carouselHeight = HomeMediaCarouselPresentation.marineLifeCarouselOverlayFrameHeight(
            heroBandHeight: bandHeight,
            topSafeAreaInset: safeTop,
            appliesOwnTopSafeAreaBleed: false
        )
        #expect(carouselHeight == bandHeight + safeTop)
        let overlayInHeroBand = HomeMediaCarouselPresentation.marineLifeOverlaySize(
            width: 390,
            height: carouselHeight
        )
        #expect(overlayInHeroBand.height == carouselHeight)
        let imageHeight = HomeMediaCarouselPresentation.marineLifeCarouselOverlayImageHeight(previewHeight: 420)
        #expect(imageHeight >= 72)
        #expect(imageHeight <= 104)
        let imageWidth = HomeMediaCarouselPresentation.marineLifeCarouselOverlayImageMaxWidth(previewWidth: 390)
        #expect(imageWidth >= 144)
        #expect(imageWidth <= 204)
        let singlePageHeight = HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageHeight(
            previewHeight: 420,
            speciesCount: 1
        )
        let multiPageHeight = HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageHeight(
            previewHeight: 420,
            speciesCount: 3
        )
        #expect(multiPageHeight == singlePageHeight)
        #expect(
            singlePageHeight
                == HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesRowHeight
        )
        let closeTop: CGFloat = 175
        let speciesTop: CGFloat = 320
        let columnHeight = HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnHeight(
            closeTopInset: closeTop,
            speciesContentTopInset: speciesTop
        )
        #expect(columnHeight == speciesTop + HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesRowHeight - closeTop)
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageFadeOpaqueStop > 0
                && HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageFadeOpaqueStop < 1
        )
        let templateSeam: CGFloat = 392
        let topSafe: CGFloat = 59
        let heroBand: CGFloat = 520
        let overlayHeight = topSafe + heroBand
        let seamOffset = HomeMediaCarouselPresentation.marineLifeCarouselOverlaySheetSeamYOffsetFromTemplate
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayTemplateSeamYInHeroBand(
                heroBandHeight: heroBand,
                panelOverlap: HomeOverviewLayout.panelOverlap
            ) == heroBand - HomeOverviewLayout.panelOverlap
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlaySheetSeamYFromTop(
                heroBandHeight: heroBand,
                topSafeAreaInset: topSafe,
                panelOverlap: HomeOverviewLayout.panelOverlap
            ) == overlayHeight - HomeOverviewLayout.panelOverlap + seamOffset
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayClampedSeamYFromTop(
                templateSeamYFromTop: templateSeam,
                proposedSeamYFromTop: nil,
                minimumSeamY: 100,
                maximumSeamY: 500
            ) == templateSeam
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayClampedSeamYFromTop(
                templateSeamYFromTop: templateSeam,
                proposedSeamYFromTop: 520,
                minimumSeamY: 100,
                maximumSeamY: 500
            ) == 500
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorBottomInset(
                overlayHeight: overlayHeight,
                sheetSeamYFromTop: templateSeam
            ) == overlayHeight - templateSeam
                + HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesContentLeadingInset > 0
        )
        #expect(seamOffset == -25)
        let seamYFromTop = overlayHeight - HomeOverviewLayout.panelOverlap + seamOffset
        let pageIndicatorTopInset = HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorTopInsetFromTop(
            sheetSeamYFromTop: seamYFromTop
        )
        let pageIndicatorTopOffset = HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorTopOffsetFromSeamSpacing
        #expect(pageIndicatorTopOffset == 65)
        #expect(
            pageIndicatorTopInset
                == HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorTopInsetAboveSeam(
                    sheetSeamYFromTop: seamYFromTop
                ) + pageIndicatorTopOffset
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayProductionSeamYInHeroBand(
                heroBandHeight: heroBand,
                panelOverlap: HomeOverviewLayout.panelOverlap
            ) == heroBand - HomeOverviewLayout.panelOverlap + seamOffset
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlaySheetSeamYFromTop(
                heroBandHeight: heroBand,
                topSafeAreaInset: topSafe,
                panelOverlap: HomeOverviewLayout.panelOverlap
            ) == overlayHeight - HomeOverviewLayout.panelOverlap + seamOffset
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorBottomInset(
                overlayHeight: overlayHeight,
                heroBandHeight: heroBand,
                topSafeAreaInset: topSafe,
                panelOverlap: HomeOverviewLayout.panelOverlap
            ) == HomeOverviewLayout.panelOverlap
                - seamOffset
                + HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesBottomMargin(
                overlayHeight: overlayHeight,
                heroBandHeight: heroBand,
                topSafeAreaInset: topSafe,
                panelOverlap: HomeOverviewLayout.panelOverlap
            )
                > HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorBottomInset(
                    overlayHeight: overlayHeight,
                    heroBandHeight: heroBand,
                    topSafeAreaInset: topSafe,
                    panelOverlap: HomeOverviewLayout.panelOverlap
                )
        )
        let tallerOverlayHeight: CGFloat = overlayHeight + 24
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlaySheetSeamYFromTop(
                heroBandHeight: heroBand,
                topSafeAreaInset: topSafe,
                panelOverlap: HomeOverviewLayout.panelOverlap
            )
                < tallerOverlayHeight - HomeOverviewLayout.panelOverlap
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayMediaScrimOpacity
                < TripDetailMediaGalleryPresentation.marineLifeOverlayMediaScrimOpacity
        )
        #expect(HomeMediaCarouselPresentation.marineLifeCarouselOverlayMediaScrimOpacity > 0.3)
    }

    @Test func homeMediaCarouselPresentation_taggedBuddyExpandedListHeight_capsAtTwoFullProfiles() {
        let avatarDiameter: CGFloat = 40
        let avatarSpacing: CGFloat = 8
        let twoBuddyHeight = HomeMediaCarouselPresentation.taggedBuddyExpandedListHeight(
            buddyCount: 2,
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing
        )
        #expect(twoBuddyHeight == 88)
        let threeBuddyHeight = HomeMediaCarouselPresentation.taggedBuddyExpandedListHeight(
            buddyCount: 3,
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing
        )
        #expect(
            threeBuddyHeight
                == twoBuddyHeight + HomeMediaCarouselPresentation.taggedBuddyThirdProfilePeekHeight
        )
        #expect(HomeMediaCarouselPresentation.taggedBuddyListShowsScrollFade(buddyCount: 2) == false)
        #expect(HomeMediaCarouselPresentation.taggedBuddyListShowsScrollFade(buddyCount: 3))
        #expect(HomeMediaCarouselPresentation.taggedBuddyPeekProfileIndex(buddyCount: 3) == 0)
        #expect(HomeMediaCarouselPresentation.taggedBuddyPeekProfileIndex(buddyCount: 4) == 1)
    }

    @Test func homeMediaCarouselPresentation_buddyRowFadeMask_peekAndScrollZones() {
        let avatarDiameter: CGFloat = 40
        let avatarSpacing: CGFloat = 8
        let viewportHeight = HomeMediaCarouselPresentation.taggedBuddyExpandedListHeight(
            buddyCount: 4,
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing
        )
        let fullZoneTop = viewportHeight - HomeMediaCarouselPresentation.taggedBuddyFullZoneHeight(
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing
        )

        let hiddenAbove = HomeMediaCarouselPresentation.buddyRowFadeMask(
            rowMinYInViewport: -40,
            rowMaxYInViewport: -2,
            viewportHeight: viewportHeight,
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing,
            buddyCount: 4
        )
        #expect(hiddenAbove.isHidden)

        let fullOpacity = HomeMediaCarouselPresentation.buddyRowFadeMask(
            rowMinYInViewport: fullZoneTop,
            rowMaxYInViewport: fullZoneTop + avatarDiameter,
            viewportHeight: viewportHeight,
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing,
            buddyCount: 4
        )
        #expect(!fullOpacity.isHidden)
        #expect(fullOpacity.fadeHeight == 0)
        #expect(fullOpacity.transparentTopHeight == 0)
        #expect(fullOpacity.opaqueBottomHeight == avatarDiameter)

        let peeking = HomeMediaCarouselPresentation.buddyRowFadeMask(
            rowMinYInViewport: -30,
            rowMaxYInViewport: 10,
            viewportHeight: viewportHeight,
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing,
            buddyCount: 4
        )
        #expect(!peeking.isHidden)
        #expect(peeking.opaqueBottomHeight == 0)
        #expect(peeking.transparentTopHeight == 30)
        #expect(peeking.fadeHeight == 10)
        #expect(peeking.transparentTopHeight + peeking.fadeHeight + peeking.opaqueBottomHeight == avatarDiameter)

        let transitioning = HomeMediaCarouselPresentation.buddyRowFadeMask(
            rowMinYInViewport: 5,
            rowMaxYInViewport: 45,
            viewportHeight: viewportHeight,
            avatarDiameter: avatarDiameter,
            avatarSpacing: avatarSpacing,
            buddyCount: 4
        )
        #expect(!transitioning.isHidden)
        #expect(transitioning.transparentTopHeight == 0)
        #expect(transitioning.opaqueBottomHeight > 0)
        #expect(transitioning.fadeHeight > 0)
        #expect(
            transitioning.transparentTopHeight
                + transitioning.fadeHeight
                + transitioning.opaqueBottomHeight == avatarDiameter
        )
    }

    @Test func homeMediaCarouselPresentation_slideChromeControlHeight_matchesTwoLineDiveChip() {
        let height = HomeMediaCarouselPresentation.slideChromeControlHeight
        #expect(height >= 40)
        #expect(height <= 56)
        #expect(height > 44)
        #expect(HomeMediaCarouselPresentation.taggedOverlayIconTapDimension == 56)
        #expect(HomeMediaCarouselPresentation.taggedOverlayIconTapDimension >= height)
    }

    @Test @MainActor
    func homeMediaCarouselDiveLinkChrome_usesAdaptiveSlateForeground() {
        #expect(
            HomeMediaCarouselDiveLinkChromePresentation.siteTitleForeground
                == AppTheme.Colors.backButtonForeground
        )
        #expect(
            HomeMediaCarouselDiveLinkChromePresentation.diveNumberForeground
                == AppTheme.Colors.secondaryText
        )
    }

    @Test func homeMediaCarouselDiveLinkChrome_subtitle_joinsDiveNumberAndTripWithMiddleDot() {
        #expect(
            HomeMediaCarouselDiveLinkChromePresentation.diveLinkSubtitle(
                diveNumberLabel: "#12",
                linkedTripTitle: "Bonaire 2026"
            ) == "#12 · Bonaire 2026"
        )
        #expect(
            HomeMediaCarouselDiveLinkChromePresentation.diveLinkSubtitle(
                diveNumberLabel: "-",
                linkedTripTitle: "Bonaire 2026"
            ) == "Bonaire 2026"
        )
        #expect(
            HomeMediaCarouselDiveLinkChromePresentation.diveLinkSubtitle(
                diveNumberLabel: "#3",
                linkedTripTitle: nil
            ) == "#3"
        )
    }

    @Test func homeMediaCarouselPresentation_marineLifeOverlayCloseTopInset_alignsWithHomeHeaderProfileRow() {
        let topSafeAreaInset: CGFloat = 59
        let headerClearance: CGFloat = 112
        let inset = HomeMediaCarouselPresentation.marineLifeOverlayCloseTopInset(
            topSafeAreaInset: topSafeAreaInset,
            headerClearance: headerClearance
        )
        let rowHeight = HomeMediaCarouselPresentation.marineLifeOverlayHeaderBrandRowHeight()
        let profileCenterY = topSafeAreaInset
            + HomeMediaCarouselPresentation.marineLifeOverlayHomeHeaderTopPadding
            + rowHeight / 2
        #expect(
            inset
                == max(
                    0,
                    profileCenterY
                        - HomeMediaCarouselPresentation.marineLifeOverlayCloseButtonTapDimension / 2
                        + HomeMediaCarouselPresentation.marineLifeCarouselOverlayCloseTopOffsetFromHeaderAlignment
                )
        )
    }

    @Test func homeMediaCarouselPresentation_marineLifeCarouselOverlaySpeciesDescriptionLineLimit_fitsAbovePageDots() {
        let closeInset: CGFloat = 140
        let speciesNameTop = HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesNameTopInset(
            closeTopInset: closeInset
        )
        let pageIndicatorTop: CGFloat = 360
        let limit = HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesDescriptionLineLimit(
            speciesNameTopInset: speciesNameTop,
            pageIndicatorTopInset: pageIndicatorTop
        )
        #expect(limit > 4)
        let reservedDescriptionHeight = CGFloat(limit) * HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesDescriptionLineHeight
        let reservedNameHeight = 2 * HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesCommonNameLineHeight
        #expect(
            speciesNameTop
                + reservedNameHeight
                + HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesNameToDescriptionSpacing
                + reservedDescriptionHeight
                + HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesToPageIndicatorSpacing
                <= pageIndicatorTop + 1
        )
    }

    @Test func homeMediaCarouselPresentation_marineLifeCarouselOverlaySpeciesDescriptionText_prefersAboutText() {
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesDescriptionText(
                aboutText: "  Bold blue angelfish on Caribbean reefs.  ",
                distinctiveFeatures: "Crown spot on forehead"
            ) == "Bold blue angelfish on Caribbean reefs."
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesDescriptionText(
                aboutText: "",
                distinctiveFeatures: "Electric blue body with yellow tail."
            ) == "Electric blue body with yellow tail."
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesDescriptionText(
                aboutText: "   ",
                distinctiveFeatures: "   "
            ) == nil
        )
    }

    @Test func homeMediaCarouselPresentation_marineLifeCarouselOverlaySpeciesContentTopInset_alignsWithFeatureImageTop() {
        let topSafeAreaInset: CGFloat = 59
        let heroBandHeight: CGFloat = 520
        let previewHeight = topSafeAreaInset + heroBandHeight
        let speciesRowHeight = HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesRowHeight
        let panelOverlap = HomeOverviewLayout.panelOverlap
        let closeInset = HomeMediaCarouselPresentation.marineLifeOverlayCloseTopInset(
            previewHeight: previewHeight,
            topSafeAreaInset: topSafeAreaInset,
            headerOverlayHeight: 112
        )
        let speciesTopInset = HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesContentTopInset(
            closeTopInset: closeInset
        )
        #expect(speciesTopInset == closeInset)
        let speciesNameTopInset = HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesNameTopInset(
            closeTopInset: closeInset
        )
        #expect(
            speciesNameTopInset
                == closeInset
                    + HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop
        )
        let pageIndicatorTopInset = HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorTopInsetFromTop(
            sheetSeamYFromTop: HomeMediaCarouselPresentation.marineLifeCarouselOverlaySheetSeamYFromTop(
                heroBandHeight: heroBandHeight,
                topSafeAreaInset: topSafeAreaInset,
                panelOverlap: panelOverlap
            )
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnHeight(
                closeTopInset: closeInset,
                pageIndicatorTopInset: pageIndicatorTopInset,
                speciesRowHeight: speciesRowHeight
            )
                == pageIndicatorTopInset - closeInset
                    - HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesToPageIndicatorSpacing
                    - HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnBottomLift
        )
        #expect(
            HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorBottomInset(
                overlayHeight: previewHeight,
                heroBandHeight: heroBandHeight,
                topSafeAreaInset: topSafeAreaInset,
                panelOverlap: panelOverlap
            ) > panelOverlap
        )
    }

    @Test func homeLifetimeStatsLayout_usesTwoColumnFixedHeightTiles() {
        #expect(HomeLifetimeStatsLayout.gridColumnCount == 2)
        #expect(HomeLifetimeStatsLayout.highlightStatTileCount == 4)
        #expect(HomeLifetimeStatsLayout.rowCount(tileCount: 4) == 2)
        #expect(HomeLifetimeStatsLayout.rowCount(tileCount: 3) == 2)
        #expect(HomeLifetimeStatsLayout.statTileHeight == 82)
        let fourTileGrid = HomeLifetimeStatsLayout.gridHeight(tileCount: 4)
        #expect(abs(fourTileGrid - (HomeLifetimeStatsLayout.statTileHeight * 2 + HomeLifetimeStatsLayout.gridSpacing)) < 0.001)
        let threeTileGrid = HomeLifetimeStatsLayout.gridHeight(tileCount: 3)
        #expect(abs(threeTileGrid - (HomeLifetimeStatsLayout.statTileHeight * 2 + HomeLifetimeStatsLayout.gridSpacing)) < 0.001)
        #expect(HomeLifetimeStatsLayout.panelTopCornerRadius == AppTheme.Sheet.cornerRadius)
        #expect(HomeLifetimeStatsLayout.panelOverlap >= 140)
        #expect(HomeLifetimeStatsLayout.valueFontSize() >= 18)
        #expect(HomeLifetimeStatsLayout.panelTopContentPaddingWhenOverlapping == 0)
        #expect(HomeLifetimeStatsLayout.panelBottomContentPadding == 0)
        #expect(HomeLifetimeStatsLayout.gridSpacing == HomeLifetimeStatsTilesLayout.gridSpacing)
        #expect(HomeLifetimeStatsLayout.heroBottomExtension > HomeLifetimeStatsLayout.panelOverlap)
        #expect(HomeLifetimeStatsPresentation.topSpeciesEmptyFootnote.contains("Tag marine life"))
    }

    @Test func homeLifetimeStatsTilesLayout_resolvedVerticalEdgeInsets_centersBetweenSeamAndTabTop() {
        let statRowCount = 2
        let minContent = HomeLifetimeStatsTilesLayout.scrollContentHeight(
            statRowCount: statRowCount,
            showsBuddyLeaderboard: true
        )

        let baseline = HomeLifetimeStatsTilesLayout.resolvedVerticalEdgeInsets(
            totalHeight: minContent,
            statRowCount: statRowCount,
            showsBuddyLeaderboard: true
        )
        #expect(baseline.top == 0)
        #expect(baseline.bottom == 0)

        let expanded = HomeLifetimeStatsTilesLayout.resolvedVerticalEdgeInsets(
            totalHeight: minContent + 40,
            statRowCount: statRowCount,
            showsBuddyLeaderboard: true
        )
        #expect(expanded.top == 20)
        #expect(expanded.bottom == 20)
        #expect(
            abs(minContent + expanded.top + expanded.bottom - (minContent + 40)) < 0.001
        )
    }

    @Test func homeLifetimeStatsTilesLayout_resolvedVerticalEdgeInset_splitsSlackEvenly() {
        let spacing = HomeLifetimeStatsTilesLayout.gridSpacing
        let statRowCount = 2
        let minContent = HomeLifetimeStatsTilesLayout.scrollContentHeight(
            statRowCount: statRowCount,
            showsBuddyLeaderboard: true
        )

        #expect(
            HomeLifetimeStatsTilesLayout.resolvedVerticalEdgeInset(
                totalHeight: minContent + 24,
                statRowCount: statRowCount,
                showsBuddyLeaderboard: true
            ) == 12
        )
        #expect(HomeLifetimeStatsTilesLayout.gridSpacing == spacing)
    }

    @Test func homeLifetimeStatsTilesLayout_resolvedFlexibleLayoutHeights_usesUniformRowSpacing() {
        let spacing = HomeLifetimeStatsTilesLayout.gridSpacing
        let statRowCount = 2
        let minStatRow = HomeLifetimeStatsTilesLayout.statTileHeight
        let minBuddy = HomeLifetimeStatsTilesLayout.buddyTileHeight
        let minTotal = CGFloat(statRowCount) * minStatRow + spacing + minBuddy

        let rows = HomeLifetimeStatsTilesLayout.resolvedFlexibleLayoutHeights(
            totalHeight: minTotal + 60,
            statRowCount: statRowCount,
            showsBuddyLeaderboard: true
        )
        #expect(rows.statRowHeight > minStatRow)
        #expect(rows.buddyRowHeight > minBuddy)
        let used = rows.statRowHeight * CGFloat(statRowCount)
            + CGFloat(max(statRowCount - 1, 0)) * spacing
            + spacing
            + rows.buddyRowHeight
        #expect(abs(used - (minTotal + 60)) < 0.001)
    }

    @Test func homeLifetimeStatsTilesLayout_resolvedFlexibleSectionHeights_distributesExtraByBaselineWeights() {
        let minGrid = HomeLifetimeStatsTilesLayout.gridHeight(tileCount: 4)
        let minBuddy = HomeLifetimeStatsTilesLayout.buddyTileHeight
        let spacing = HomeLifetimeStatsTilesLayout.gridSpacing
        let minTotal = minGrid + spacing + minBuddy

        let withoutBuddy = HomeLifetimeStatsTilesLayout.resolvedFlexibleSectionHeights(
            totalHeight: 260,
            showsBuddyLeaderboard: false
        )
        #expect(withoutBuddy.grid == 260)
        #expect(withoutBuddy.buddy == 0)

        let atMinimum = HomeLifetimeStatsTilesLayout.resolvedFlexibleSectionHeights(
            totalHeight: minTotal,
            showsBuddyLeaderboard: true
        )
        #expect(atMinimum.grid == minGrid)
        #expect(atMinimum.buddy == minBuddy)

        let expanded = HomeLifetimeStatsTilesLayout.resolvedFlexibleSectionHeights(
            totalHeight: minTotal + 84,
            showsBuddyLeaderboard: true
        )
        #expect(expanded.grid > minGrid)
        #expect(expanded.buddy > minBuddy)
        #expect(abs(expanded.grid + expanded.buddy + spacing - (minTotal + 84)) < 0.001)
    }

    @Test func homeBuddyLeaderboardLayout_fitsHomeStatsPanelEstimate() {
        #expect(HomeBuddyLeaderboardLayout.estimatedTileHeight == 120)
        #expect(HomeLifetimeStatsTilesLayout.buddyTileHeight == 120)
        #expect(HomeBuddyLeaderboardLayout.podiumRowHeight == 80)
        #expect(HomeBuddyLeaderboardLayout.avatarDiameter == 44)
        #expect(
            HomeLifetimeStatsLayout.estimatedBuddyLeaderboardHeight
                == HomeBuddyLeaderboardLayout.estimatedTileHeight
        )
        #expect(
            HomeLifetimeStatsTilesLayout.scrollContentHeight(showsBuddyLeaderboard: true) == 316
        )
    }

    @Test func homeLifetimeStatsPanelLayout_matchesVisualGridAndPadding() {
        let fourTileGrid = HomeLifetimeStatsLayout.gridHeight(tileCount: 4)
        #expect(
            abs(
                HomeLifetimeStatsPanelLayout.estimatedScrollContentHeight(showsBuddyLeaderboard: false)
                    - fourTileGrid
            ) < 0.001
        )
        #expect(
            HomeLifetimeStatsPanelLayout.estimatedScrollContentHeight(showsBuddyLeaderboard: true)
                > HomeLifetimeStatsPanelLayout.estimatedScrollContentHeight(showsBuddyLeaderboard: false)
        )
        #expect(
            HomeLifetimeStatsPanelLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: false)
                == HomeLifetimeStatsPanelLayout.estimatedScrollContentHeight(showsBuddyLeaderboard: false)
        )
    }

    @Test func homeOverviewLayout_carouselLeavesMinimumStatsBand() {
        let viewport: CGFloat = 769
        let statsContent: CGFloat = 400
        let minimumStats = HomeOverviewLayout.minimumStatsBandHeight(statsPanelContentHeight: statsContent)
        let metrics = HomeOverviewLayout.metrics(
            viewportHeight: viewport,
            screenWidth: 390,
            topSafeAreaInset: 59,
            statsPanelContentHeight: statsContent
        )
        #expect(metrics.heroHeight + minimumStats - HomeOverviewLayout.panelOverlap <= viewport + 1)
    }

    @Test func homeOverviewLayout_shrinksCarouselWhenViewportIsShort() {
        let viewport: CGFloat = 667
        let metrics = HomeOverviewLayout.metrics(
            viewportHeight: viewport,
            screenWidth: 390,
            topSafeAreaInset: 59,
            statsPanelContentHeight: 400
        )
        #expect(metrics.heroHeight < HomeOverviewLayout.heroHeight(width: 390, topSafeAreaInset: 59))
    }

    @Test func homeOverviewLayout_homeRootViewportHeight_matchesSettledRootDuringPush() {
        let pushedGeometryHeight: CGFloat = 852
        let settledRootHeight = HomeOverviewLayout.homeRootViewportHeight(
            geometryHeight: pushedGeometryHeight,
            isNavigationStackAtRoot: false
        )
        #expect(settledRootHeight == pushedGeometryHeight - HomeOverviewLayout.rootTabBarLayoutHeight)
        #expect(
            HomeOverviewLayout.homeRootViewportHeight(
                geometryHeight: settledRootHeight,
                isNavigationStackAtRoot: true
            ) == settledRootHeight
        )
    }

    @Test func homeRootViewportPresentation_frozenHeightWhilePushed() {
        let resolution = HomeRootViewportPresentation.resolvedViewportHeight(
            geometryHeight: 852,
            isNavigationStackAtRoot: false,
            frozenRootViewportHeight: 803
        )
        #expect(resolution.height == 803)
        #expect(resolution.frozenRootViewportHeight == 803)
        let latched = HomeRootViewportPresentation.resolvedViewportHeight(
            geometryHeight: 852,
            isNavigationStackAtRoot: true,
            frozenRootViewportHeight: 803
        )
        #expect(latched.height == 852)
        #expect(latched.frozenRootViewportHeight == 852)
    }

    @Test func homeOverviewLayout_pushedPageLayoutHeight_fillsFullScreenGeometry() {
        let pushedGeometryHeight: CGFloat = 852
        let transitionFloor = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(from: 803)
        #expect(HomeOverviewLayout.pushedPageLayoutHeight(from: pushedGeometryHeight) == 852)
        #expect(
            HomeOverviewLayout.pushedPageLayoutHeight(
                from: pushedGeometryHeight,
                transitionViewportFloor: transitionFloor
            ) == 852
        )
        #expect(
            HomeOverviewLayout.pushedHeroLayoutViewportHeight(
                from: 803,
                transitionViewportFloor: transitionFloor
            ) == HomeOverviewLayout.viewportHeightMatchingHomeTab(from: 803)
        )
        #expect(
            HomeOverviewLayout.pushedHeroLayoutViewportHeight(from: pushedGeometryHeight) == 803
        )
        #expect(
            HomeOverviewLayout.pushedPageScrollBottomInset(safeAreaBottom: 34)
                == 34 + HomeOverviewLayout.pageIndicatorClearance
        )
        #expect(
            HomeOverviewLayout.pushedPanelBottomScrollFadeHeight(safeAreaBottom: 34)
                == HomeOverviewLayout.rootTabBarLayoutHeight + 34
        )
    }

    @Test func homeOverviewLayout_pushedHeroLayoutTransitionViewportCandidate_onlyLatchesTabContentGeometry() {
        let tabContentGeometry: CGFloat = 803
        let fullScreenGeometry: CGFloat = 852
        let subtracted = HomeOverviewLayout.viewportHeightMatchingHomeTab(from: tabContentGeometry)
        let tabCandidate = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(
            from: tabContentGeometry
        )
        let fullCandidate = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(
            from: fullScreenGeometry
        )
        #expect(tabCandidate == 803)
        #expect(fullCandidate == 852)
        #expect(subtracted < tabCandidate)
        #expect(
            HomeOverviewLayout.viewportHeightMatchingHomeTab(from: fullScreenGeometry)
                < fullCandidate
        )
    }

    @Test func homeOverviewLayout_pushedHeroLayoutMetrics_firstFrameTabContentHeight_matchesSettledHeroOnWidePhone() {
        let screenWidth: CGFloat = 517
        let topSafeAreaInset: CGFloat = 59
        let transitionFloor = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(from: 803)
        let firstFrameHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: 803,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard,
            showsBuddyLeaderboard: true,
            transitionViewportFloor: transitionFloor
        ).heroHeight
        let settledHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: 852,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard,
            showsBuddyLeaderboard: true,
            transitionViewportFloor: transitionFloor
        ).heroHeight
        let firstFrameViewport = HomeOverviewLayout.pushedHeroLayoutViewportHeight(
            from: 803,
            transitionViewportFloor: transitionFloor
        )
        let settledViewport = HomeOverviewLayout.pushedHeroLayoutViewportHeight(
            from: 852,
            transitionViewportFloor: transitionFloor
        )
        #expect(firstFrameViewport == HomeOverviewLayout.viewportHeightMatchingHomeTab(from: 803))
        #expect(settledViewport == 803)
        #expect(firstFrameHero < settledHero)
    }

    @Test func homeOverviewLayout_pushedHeroLayoutMetrics_stableHeroOnFirstAndSettledGeometry() {
        let screenWidth: CGFloat = 517
        let topSafeAreaInset: CGFloat = 59
        let transitionFloor = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(from: 803)
        let firstFrameHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: 803,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard,
            showsBuddyLeaderboard: true,
            transitionViewportFloor: transitionFloor
        ).heroHeight
        let settledHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: 852,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard,
            showsBuddyLeaderboard: true,
            transitionViewportFloor: transitionFloor
        ).heroHeight
        let firstFrameViewport = HomeOverviewLayout.pushedHeroLayoutViewportHeight(
            from: 803,
            transitionViewportFloor: transitionFloor
        )
        let settledViewport = HomeOverviewLayout.pushedHeroLayoutViewportHeight(
            from: 852,
            transitionViewportFloor: transitionFloor
        )
        #expect(firstFrameViewport < settledViewport)
        #expect(firstFrameHero < settledHero)
    }

    @Test func homeOverviewLayout_pushedHeroLayoutMetrics_stableHeroWhenGeometryTopInsetUnsettled() {
        let screenWidth: CGFloat = 517
        let settledTopSafeAreaInset: CGFloat = 59
        let transitionFloor = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(from: 803)
        let unsettledHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: 852,
            screenWidth: screenWidth,
            topSafeAreaInset: 0
        ).heroHeight
        let settledHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: 852,
            screenWidth: screenWidth,
            topSafeAreaInset: settledTopSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard,
            showsBuddyLeaderboard: true,
            transitionViewportFloor: transitionFloor
        ).heroHeight
        #expect(unsettledHero != settledHero)
        #expect(
            HomeOverviewLayout.pushedHeroLayoutMetrics(
                geometryHeight: 852,
                screenWidth: screenWidth,
                topSafeAreaInset: settledTopSafeAreaInset,
                statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard,
                showsBuddyLeaderboard: true,
                transitionViewportFloor: transitionFloor
            ).heroHeight == settledHero
        )
    }

    @Test @MainActor func homeOverviewPushedLayoutPresentation_statsPanelContentHeightMatchingHome_usesLeaderboardBandWhenVisible() {
        HomeOverviewLayoutAnchor.resetForTesting()
        let buddy = DiveBuddy(displayName: "Alex")
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 100),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        let tag = DiveBuddyTag(buddy: buddy, dive: activity)
        activity.buddies = [tag]

        let withLeaderboard = HomeOverviewPushedLayoutPresentation.statsPanelContentHeightMatchingHome(
            activities: [activity],
            diveBuddyTags: [tag]
        )
        #expect(
            withLeaderboard
                == HomeLifetimeStatsLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: true)
        )
        #expect(
            HomeOverviewPushedLayoutPresentation.statsPanelContentHeightMatchingHome(activities: [])
                == HomeLifetimeStatsLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: false)
        )
    }

    @Test @MainActor func homeOverviewPushedLayoutPresentation_statsPanelContentHeightMatchingHome_usesDiveBuddyTagsWhenRelationshipsUnset() {
        HomeOverviewLayoutAnchor.resetForTesting()
        let buddy = DiveBuddy(displayName: "Alex")
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 100),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        let tag = DiveBuddyTag(buddy: buddy, dive: activity)

        let viaTags = HomeOverviewPushedLayoutPresentation.statsPanelContentHeightMatchingHome(
            activities: [activity],
            diveBuddyTags: [tag]
        )
        #expect(
            viaTags
                == HomeLifetimeStatsLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: true)
        )

        let viaActivitiesOnly = HomeOverviewPushedLayoutPresentation.statsPanelContentHeightMatchingHome(
            activities: [
                DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 200),
                    durationMinutes: 40,
                    maxDepthMeters: 18
                ),
            ]
        )
        #expect(
            viaActivitiesOnly
                == HomeLifetimeStatsLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: false)
        )
    }

    @Test func blueSheetHeaderPageLayoutBuilder_heroHeight_matchesPushedHeroLayoutMetrics() {
        let geometryHeight: CGFloat = 852
        let screenWidth: CGFloat = 390
        let topSafeAreaInset: CGFloat = 59
        let statsBand = HomeOverviewLayout.heroLayoutStatsPanelContentHeight
        let transitionFloor = HomeOverviewLayout.pushedHeroLayoutTransitionViewportCandidate(from: 803)

        let viaBuilder = BlueSheetHeaderPageLayoutBuilder.heroHeight(
            geometryHeight: geometryHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: statsBand,
            showsBuddyLeaderboard: false,
            transitionViewportFloor: transitionFloor
        )
        let direct = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: geometryHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: statsBand,
            showsBuddyLeaderboard: false,
            transitionViewportFloor: transitionFloor
        ).heroHeight
        #expect(viaBuilder == direct)
    }

    @Test func homeOverviewLayout_pushedHeroLayoutMetrics_widePhoneLeaderboardSeam_matchesHomeScreenBot() {
        let screenWidth: CGFloat = 517
        let topSafeAreaInset: CGFloat = 59
        let homeTabViewport: CGFloat = 803
        let pushedGeometryHeight: CGFloat = 852
        let homeHero = HomeOverviewLayout.metrics(
            viewportHeight: homeTabViewport,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard
        ).heroHeight
        let pushedHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: pushedGeometryHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard,
            showsBuddyLeaderboard: true
        ).heroHeight
        #expect(pushedHero == homeHero)
        let homeScreenBot = HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .home,
            geometryHeight: homeTabViewport,
            heroHeight: homeHero
        )
        let pushedScreenBot = HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .buddyDetail,
            geometryHeight: pushedGeometryHeight,
            heroHeight: pushedHero
        )
        #expect(homeScreenBot == pushedScreenBot)
        let statsBand = HomeOverviewLayout.minimumStatsBandHeight(
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard
        )
        let expectedScreenBot = homeTabViewport + HomeOverviewLayout.rootTabBarLayoutHeight
            - max(homeHero - HomeOverviewLayout.panelOverlap, 0)
        #expect(abs(homeScreenBot - expectedScreenBot) < 0.001)
        #expect(abs(homeScreenBot - statsBand) > 1)
    }

    @Test func homeOverviewLayout_heroLayoutStatsBand_matchesHomeTwoByTwoGrid() {
        #expect(
            HomeOverviewLayout.heroLayoutStatsPanelContentHeight
                == HomeLifetimeStatsPanelLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: false)
        )
    }

    @Test func homeOverviewLayout_pushedHeroLayoutMetrics_matchesSettledHomeTabSeam() {
        let pushedGeometryHeight: CGFloat = 852
        let homeTabViewportHeight = HomeOverviewLayout.viewportHeightMatchingHomeTab(
            from: pushedGeometryHeight
        )
        let screenWidth: CGFloat = 393
        let topSafeAreaInset: CGFloat = 59
        let statsBand = HomeOverviewLayout.heroLayoutStatsPanelContentHeight
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
        #expect(pushedHero == homeHero)
    }

    @Test func homeOverviewLayout_pushedHeroTopSafeAreaInset_usesRawGeometryWithOptionalFloor() {
        #expect(HomeOverviewLayout.pushedHeroTopSafeAreaInset(rawGeometrySafeTop: 59) == 59)
        #expect(
            HomeOverviewLayout.pushedHeroTopSafeAreaInset(
                rawGeometrySafeTop: 0,
                transitionSafeTopFloor: 59
            ) == 59
        )
    }

    @Test func homeOverviewLayout_sheetSeamYFromScreenBottom_matchesHomeTabBarReserve() {
        let heroHeight: CGFloat = 461
        let seamY = heroHeight - HomeOverviewLayout.panelOverlap
        let homeScreenBottom = HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .home,
            geometryHeight: 803,
            heroHeight: heroHeight
        )
        let pushedScreenBottom = HomeOverviewLayout.sheetSeamYFromScreenBottom(
            pageKind: .buddyDetail,
            geometryHeight: 852,
            heroHeight: heroHeight
        )
        #expect(homeScreenBottom == pushedScreenBottom)
        #expect(homeScreenBottom == 803 + HomeOverviewLayout.rootTabBarLayoutHeight - seamY)
        #expect(pushedScreenBottom == 852 - seamY)
    }

    @Test func homeOverviewLayout_pushedHeroLayoutMetrics_capsToHomeLeaderboardSeamOnWidePhones() {
        let pushedGeometryHeight: CGFloat = 852
        let homeTabViewportHeight = HomeOverviewLayout.viewportHeightMatchingHomeTab(
            from: pushedGeometryHeight
        )
        let screenWidth: CGFloat = 517
        let topSafeAreaInset: CGFloat = 59
        let homeHeroWithLeaderboard = HomeOverviewLayout.metrics(
            viewportHeight: homeTabViewportHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard
        ).heroHeight
        let homeHeroTwoByTwo = HomeOverviewLayout.metrics(
            viewportHeight: homeTabViewportHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeight
        ).heroHeight
        let pushedHero = HomeOverviewLayout.pushedHeroLayoutMetrics(
            geometryHeight: pushedGeometryHeight,
            screenWidth: screenWidth,
            topSafeAreaInset: topSafeAreaInset,
            statsPanelContentHeight: HomeOverviewLayout.heroLayoutStatsPanelContentHeightWithLeaderboard,
            showsBuddyLeaderboard: true
        ).heroHeight

        #expect(homeHeroTwoByTwo > homeHeroWithLeaderboard)
        #expect(pushedHero == homeHeroWithLeaderboard)

        let seamY = pushedHero - HomeOverviewLayout.panelOverlap
        let homeScreenBottomSeam = homeTabViewportHeight
            + HomeOverviewLayout.rootTabBarLayoutHeight
            - seamY
        let pushedScreenBottomSeam = pushedGeometryHeight - seamY
        #expect(homeScreenBottomSeam == pushedScreenBottomSeam)
    }

    @Test func appSessionBootstrapPresentation_showsLaunchOverlayOnlyWhileRestoringSession() {
        #expect(
            AppSessionBootstrapPresentation.showsLaunchOverlay(
                isRestoringSession: true
            )
        )
        #expect(
            !AppSessionBootstrapPresentation.showsLaunchOverlay(
                isRestoringSession: false
            )
        )
    }

    @Test func diveMediaImportProgressPresentation_progressFraction_clampsToUnitInterval() {
        #expect(DiveMediaImportProgressPresentation.progressFraction(completed: 2, total: 5) == 0.4)
        #expect(DiveMediaImportProgressPresentation.progressFraction(completed: 5, total: 5) == 1.0)
        #expect(DiveMediaImportProgressPresentation.progressFraction(completed: 0, total: 0) == 0)
    }

    @Test func diveImportMilestone_labels_matchSimplifiedDialogCopy() {
        #expect(DiveImportMilestone.readingFile.label == "Reading File")
        #expect(DiveImportMilestone.creatingDiveLogs.label == "Creating Dive Logs")
        #expect(DiveImportMilestone.addingMedia.label == "Adding Media")
    }

    @Test func diveImportMilestone_fractions_advanceMonotonicallyAcrossMilestones() {
        // Each milestone's bar segment is contiguous and forward-moving.
        #expect(DiveImportMilestone.readingFile.endFraction == DiveImportMilestone.creatingDiveLogs.startFraction)
        #expect(DiveImportMilestone.creatingDiveLogs.endFraction == DiveImportMilestone.addingMedia.startFraction)
        #expect(DiveImportMilestone.readingFile.startFraction < DiveImportMilestone.readingFile.endFraction)
        #expect(DiveImportMilestone.addingMedia.endFraction == 1.0)
    }

    @Test func diveImportMilestone_fraction_interpolatesWithinSegmentAndClamps() {
        let milestone = DiveImportMilestone.creatingDiveLogs
        #expect(milestone.fraction(completed: 0, total: 4) == milestone.startFraction)
        #expect(milestone.fraction(completed: 4, total: 4) == milestone.endFraction)
        let midpoint = milestone.startFraction + (milestone.endFraction - milestone.startFraction) * 0.5
        #expect(abs(milestone.fraction(completed: 2, total: 4) - midpoint) < 0.0001)
        // Guards against divide-by-zero and out-of-range work counts.
        #expect(milestone.fraction(completed: 1, total: 0) == milestone.startFraction)
        #expect(milestone.fraction(completed: 9, total: 4) == milestone.endFraction)
    }

    @Test func diveMediaImportProgressPresentation_stageLabels_includeIndex() {
        #expect(DiveMediaImportProgressPresentation.loadingStage(itemIndex: 2, total: 5) == "Loading 2 of 5…")
        #expect(DiveMediaImportProgressPresentation.savingStage(itemIndex: 3, total: 5) == "Saving 3 of 5…")
        #expect(DiveMediaImportProgressPresentation.countLabel(completed: 3, total: 5) == "3 of 5 added")
    }

    @Test func diveMediaImportProgressPresentation_failureMessageWhenNoneSaved_pluralizes() {
        #expect(
            DiveMediaImportProgressPresentation.failureMessageWhenNoneSaved(attempted: 1)
                .contains("selected item")
        )
        #expect(
            DiveMediaImportProgressPresentation.failureMessageWhenNoneSaved(attempted: 3)
                .contains("selected items")
        )
    }

    @Test func diveActivityMediaEmptyHeroPresentation_centersGhostFramesInVisibleHeroBand() {
        let layoutHeight: CGFloat = 844
        let bottomSafeInset: CGFloat = 34
        let topObstruction: CGFloat = 100

        let mediumY = DiveActivityMediaEmptyHeroPresentation.ghostFramesCenterY(
            layoutHeight: layoutHeight,
            sheetHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction,
            bottomSafeInset: bottomSafeInset,
            topObstructionHeight: topObstruction
        )
        let minimizedY = DiveActivityMediaEmptyHeroPresentation.ghostFramesCenterY(
            layoutHeight: layoutHeight,
            sheetHeightFraction: DiveActivityOverviewPanelMetrics.minimizedHeightFraction,
            bottomSafeInset: bottomSafeInset,
            topObstructionHeight: topObstruction
        )

        let screenCenter = layoutHeight / 2
        #expect(abs(minimizedY - screenCenter) < abs(mediumY - screenCenter))
        #expect(mediumY < minimizedY)
    }

    @Test func diveActivityMediaEmptyHeroPresentation_hidesHeroAnimationAtLargeDetent() {
        #expect(
            !DiveActivityMediaEmptyHeroPresentation.showsHeroGhostFrames(
                forHeightFraction: DiveActivityOverviewPanelMetrics.largeHeightFraction
            )
        )
        #expect(
            DiveActivityMediaEmptyHeroPresentation.showsHeroGhostFrames(
                forHeightFraction: DiveActivityOverviewPanelMetrics.mediumHeightFraction
            )
        )
    }

    @Test func diveActivityMediaEmptyHeroPresentation_showsUploadTextInMediumAndLargeSheet() {
        #expect(DiveActivityMediaEmptyHeroPresentation.showsUploadPromptTextInSheet(for: .medium))
        #expect(DiveActivityMediaEmptyHeroPresentation.showsUploadPromptTextInSheet(for: .large))
        #expect(!DiveActivityMediaEmptyHeroPresentation.showsUploadPromptTextInSheet(for: .minimized))
    }

    @Test func diveActivityMediaEmptyHeroPresentation_reusesHomeHighlightTitle() {
        #expect(DiveActivityMediaEmptyHeroPresentation.title == HomeMediaCarouselEmptyPresentation.title)
        #expect(DiveActivityMediaEmptyHeroPresentation.message.contains("Tap +"))
    }

    @Test func diveActivityMediaPresentation_emptyStateMessage() {
        #expect(DiveActivityMediaPresentation.emptyStateMessage == "No media added")
        #expect(DiveActivityMediaPresentation.mediaCountLabel(photoCount: 0) == "No media added")
        #expect(DiveActivityMediaPresentation.mediaCountLabel(photoCount: 2) == "2 items")
    }

    @Test func diveActivityMediaPresentation_nextSortOrder_increments() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        activity.mediaPhotos = [
            DiveMediaPhoto(sortOrder: 0),
            DiveMediaPhoto(sortOrder: 2),
        ]
        #expect(DiveActivityMediaPresentation.nextSortOrder(on: activity) == 3)
    }

    @Test func diveActivityMediaPresentation_showsBackgroundPhotos_atAllDetents() {
        for detent in [DiveActivityOverviewDetent.minimized, .medium, .large] {
            #expect(DiveActivityMediaPresentation.showsBackgroundPhotos(for: detent))
        }
    }

    @Test @MainActor func diveMediaScopeCachePresentation_mergedTier_prefersFull() {
        #expect(
            DiveMediaScopeCachePresentation.mergedTier(existing: nil, incoming: .preview) == .preview
        )
        #expect(
            DiveMediaScopeCachePresentation.mergedTier(existing: .preview, incoming: .full) == .full
        )
        #expect(
            DiveMediaScopeCachePresentation.mergedTier(existing: .full, incoming: .preview) == .full
        )
    }

    @Test func diveMediaScopeCachePresentation_libraryAssetSourceIdentityKey() {
        #expect(
            DiveMediaScopeCachePresentation.libraryAssetSourceIdentityKey(
                localIdentifier: "ABC"
            ) == "asset:ABC"
        )
    }

    @Test @MainActor func diveMediaRetentionScope_fieldGuideContexts() {
        let siteID = UUID()
        #expect(DiveMediaRetentionScope.marineLifeSpecies("fish-1") == .marineLifeSpecies("fish-1"))
        #expect(DiveMediaRetentionScope.diveSite(siteID) == .diveSite(siteID))
        #expect(DiveMediaRetentionScope.buddyDetail(siteID) == .buddyDetail(siteID))
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

    @Test func diveBuddyTaggedMediaPresentation_collectsUniqueOwnerPhotos_oldestCaptureFirst() {
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

    @Test func linkedMediaGridPresentation_matchesBuddyGridMetrics() {
        #expect(LinkedMediaGridPresentation.columnCount == 3)
        #expect(LinkedMediaGridPresentation.spacing == AppTheme.Spacing.sm)
        #expect(
            LinkedMediaGridPresentation.cornerRadius
                == DiveActivityMediaPresentation.carouselThumbnailCornerRadius
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

    @Test func homeSheetPanelBottomScrim_screenBottomAnchoredBandCenterY_pinsBandBottomToPhysicalScreen() {
        let layoutHeight: CGFloat = 818
        let safeBottom: CGFloat = 34
        let bandHeight = HomeOverviewLayout.pushedPanelBottomScrollFadeHeight(safeAreaBottom: safeBottom)
        let centerY = HomeSheetPanelBottomScrimPresentation.screenBottomAnchoredBandCenterY(
            layoutHeight: layoutHeight,
            safeAreaBottom: safeBottom,
            bandHeight: bandHeight
        )
        #expect(centerY + bandHeight / 2 == layoutHeight + safeBottom)
    }

    @Test func linkedMediaFullscreenPresentation_linkedDiveCoverIdentity_isStablePerDiveAndMedia() {
        let diveID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let mediaID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        #expect(
            LinkedMediaFullscreenPresentation.linkedDiveCoverIdentity(
                diveID: diveID,
                mediaID: mediaID
            ) == "\(diveID.uuidString)-\(mediaID.uuidString)"
        )
    }

    @Test func linkedMediaFullscreenPresentation_topChromeInset_addsPortraitBumpOnly() {
        let safeTop: CGFloat = 59
        let portrait = CGSize(width: 390, height: 844)
        let landscape = CGSize(width: 844, height: 390)
        #expect(
            LinkedMediaFullscreenPresentation.topChromeInset(
                safeAreaTop: safeTop,
                containerSize: portrait
            ) == safeTop + LinkedMediaFullscreenPresentation.portraitTopChromeExtraInset
        )
        #expect(
            LinkedMediaFullscreenPresentation.topChromeInset(
                safeAreaTop: safeTop,
                containerSize: landscape
            ) == safeTop
        )
        #expect(
            LinkedMediaFullscreenPresentation.topChromeRowOffset(
                safeAreaTop: safeTop,
                containerSize: portrait
            ) == safeTop
                + LinkedMediaFullscreenPresentation.portraitTopChromeExtraInset
                + LinkedMediaFullscreenPresentation.topChromeRowPadding
        )
        #expect(
            LinkedMediaFullscreenPresentation.topChromeRowOffset(
                safeAreaTop: safeTop,
                containerSize: landscape
            ) == safeTop + LinkedMediaFullscreenPresentation.topChromeRowPadding
        )
    }

    @Test func linkedMediaFullscreenPresentation_gestureDismiss_isSnappierThanBrowse() {
        #expect(
            LinkedMediaFullscreenPresentation.gestureDismissAnimationDuration
                < LinkedMediaFullscreenPresentation.browseAnimationDuration
        )
        #expect(
            LinkedMediaFullscreenPresentation.gestureDismissSpringResponse
                < LinkedMediaFullscreenPresentation.browseAnimationDuration
        )
    }

    @Test func diveBuddyTaggedMediaPresentation_photosAvailableFromTagRelationships_collectsUniqueSortedPhotos() {
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

    @Test func diveActivityVideoPlaybackPolicy_shouldRestartFromBeginning_whenPageBecomesActive() {
        #expect(
            DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
                wasPlaybackActive: false,
                isPlaybackActive: true,
                mediaURLChanged: false
            )
        )
        #expect(
            !DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
                wasPlaybackActive: true,
                isPlaybackActive: true,
                mediaURLChanged: false
            )
        )
        #expect(
            DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
                wasPlaybackActive: true,
                isPlaybackActive: true,
                mediaURLChanged: true
            )
        )
        #expect(
            DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
                wasPlaybackActive: false,
                isPlaybackActive: true,
                mediaURLChanged: true
            )
        )
        #expect(
            DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
                wasPlaybackActive: true,
                isPlaybackActive: true,
                mediaURLChanged: false,
                isAtEnd: true
            )
        )
    }

    @Test func diveActivityVideoPlaybackPolicy_mediaIdentityChanged_ignoresPreviewToFullUpgrade() {
        #expect(
            !DiveActivityVideoPlaybackPolicy.mediaIdentityChanged(
                previousKey: "asset:ABC|preview",
                nextKey: "asset:ABC|full"
            )
        )
        #expect(
            DiveActivityVideoPlaybackPolicy.mediaIdentityChanged(
                previousKey: "asset:ABC|preview",
                nextKey: "asset:XYZ|preview"
            )
        )
        #expect(
            !DiveActivityVideoPlaybackPolicy.shouldRestartFromBeginning(
                wasPlaybackActive: true,
                isPlaybackActive: true,
                mediaURLChanged: DiveActivityVideoPlaybackPolicy.mediaIdentityChanged(
                    previousKey: "asset:ABC|preview",
                    nextKey: "asset:ABC|full"
                )
            )
        )
    }

    @Test func diveActivityMediaPresentation_shouldPlayBackgroundVideo_inLandscapeLayout() {
        for detent in [DiveActivityOverviewDetent.minimized, .medium, .large] {
            #expect(
                DiveActivityMediaPresentation.shouldPlayBackgroundVideo(
                    isMediaTabSelected: true,
                    detent: detent
                )
            )
        }
        #expect(
            !DiveActivityMediaPresentation.shouldPlayBackgroundVideo(
                isMediaTabSelected: false,
                detent: .medium
            )
        )
    }

    @Test @MainActor
    func diveMediaVideoPlaybackSessionCache_reusesSnapshotAcrossStore() {
        DiveMediaVideoPlaybackSessionCache.shared.clear()
        defer { DiveMediaVideoPlaybackSessionCache.shared.clear() }

        let asset = AVURLAsset(url: URL(fileURLWithPath: "/tmp/test-video.mov"))
        let item = AVPlayerItem(asset: asset)
        let snapshot = DiveMediaVideoPlaybackSessionCache.SwiftUISnapshot(
            playerItem: item,
            resolvedKey: "asset:test-id|preview",
            videoFidelity: .preview,
            isDisplayReady: true,
            posterImage: nil
        )
        DiveMediaVideoPlaybackSessionCache.shared.storeSwiftUISnapshot(snapshot, sourceIdentityKey: "asset:test-id")

        let restored = DiveMediaVideoPlaybackSessionCache.shared.swiftUISnapshot(forSourceIdentityKey: "asset:test-id")
        #expect(restored?.resolvedKey == "asset:test-id|preview")
        #expect(restored?.isDisplayReady == true)
        #expect(restored?.videoFidelity == .preview)
    }

    @Test @MainActor func diveMediaVideoPlaybackSessionCache_invalidateLibraryPlayback_clearsSnapshotsAndPlayers() {
        #if canImport(AVFoundation)
        DiveMediaVideoPlaybackSessionCache.shared.clear()
        defer { DiveMediaVideoPlaybackSessionCache.shared.clear() }

        let sourceKey = "asset:carousel-video"
        let asset = AVURLAsset(url: URL(fileURLWithPath: "/tmp/carousel-video.mov"))
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        DiveMediaVideoPlaybackSessionCache.shared.storeSwiftUISnapshot(
            DiveMediaVideoPlaybackSessionCache.SwiftUISnapshot(
                playerItem: item,
                resolvedKey: "\(sourceKey)|preview",
                videoFidelity: .preview,
                isDisplayReady: true,
                posterImage: nil
            ),
            sourceIdentityKey: sourceKey
        )
        DiveMediaVideoPlaybackSessionCache.shared.store(player: player, resolvedKey: "\(sourceKey)|preview")

        DiveMediaVideoPlaybackSessionCache.shared.invalidateLibraryPlayback(sourceIdentityKey: sourceKey)

        #expect(DiveMediaVideoPlaybackSessionCache.shared.swiftUISnapshot(forSourceIdentityKey: sourceKey) == nil)
        #expect(DiveMediaVideoPlaybackSessionCache.shared.player(forResolvedKey: "\(sourceKey)|preview") == nil)
        #endif
    }

    @Test func diveActivityVideoPlaybackPolicy_shouldPlay_respectsHoldPause() {
        #expect(
            DiveActivityVideoPlaybackPolicy.shouldPlay(
                isPlaybackActive: true,
                isPausedByUserHold: false
            )
        )
        #expect(
            !DiveActivityVideoPlaybackPolicy.shouldPlay(
                isPlaybackActive: true,
                isPausedByUserHold: true
            )
        )
        #expect(
            !DiveActivityVideoPlaybackPolicy.shouldPlay(
                isPlaybackActive: false,
                isPausedByUserHold: false
            )
        )
    }

    @Test func diveActivityVideoPlaybackPolicy_holdPauseGesture_failsOnSmallMovement() {
        #expect(DiveActivityVideoPlaybackPolicy.holdPauseMaximumMovementPoints <= 8)
        #expect(DiveActivityVideoPlaybackPolicy.holdPauseMinimumDurationSeconds >= 0.15)
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

    @Test @MainActor
    func diveActivityMapCoordinateResolution_skipsCatalogLookupWhenEntryGPSPresent() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 45,
            maxDepthMeters: 18
        )
        activity.entryCoordinate = DiveCoordinate(latitude: 12.1, longitude: -68.9)
        #expect(!DiveActivityMapCoordinateResolution.needsCatalogSiteLookup(for: activity))
    }

    @Test func diveActivityMediaPresentation_shouldPlayBackgroundVideo_mediaTabAtEveryDetent() {
        for detent in [DiveActivityOverviewDetent.minimized, .medium, .large] {
            #expect(
                DiveActivityMediaPresentation.shouldPlayBackgroundVideo(
                    isMediaTabSelected: true,
                    detent: detent
                )
            )
        }
        #expect(
            !DiveActivityMediaPresentation.shouldPlayBackgroundVideo(
                isMediaTabSelected: false,
                detent: .medium
            )
        )
    }

    @Test func diveActivityMediaPresentation_resolvedSelectedPhotoID() {
        let first = UUID()
        let second = UUID()
        let photos = [
            DiveMediaPhoto(id: first, sortOrder: 0),
            DiveMediaPhoto(id: second, sortOrder: 1),
        ]
        #expect(
            DiveActivityMediaPresentation.resolvedSelectedPhotoID(selectedID: second, in: photos) == second
        )
        #expect(
            DiveActivityMediaPresentation.resolvedSelectedPhotoID(selectedID: UUID(), in: photos) == first
        )
        #expect(
            DiveActivityMediaPresentation.resolvedSelectedPhotoID(selectedID: first, in: []) == first
        )
        #expect(DiveActivityMediaPresentation.resolvedSelectedPhotoID(selectedID: nil, in: []) == nil)
    }

    @Test func diveActivityMediaPresentation_adjacentPhotoID_stepsThroughGalleryOrder() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let photos = [
            DiveMediaPhoto(id: first, sortOrder: 0),
            DiveMediaPhoto(id: second, sortOrder: 1),
            DiveMediaPhoto(id: third, sortOrder: 2),
        ]

        #expect(
            DiveActivityMediaPresentation.adjacentPhotoID(selectedID: first, in: photos, offset: 1) == second
        )
        #expect(
            DiveActivityMediaPresentation.adjacentPhotoID(selectedID: second, in: photos, offset: -1) == first
        )
        #expect(
            DiveActivityMediaPresentation.adjacentPhotoID(selectedID: third, in: photos, offset: 1) == nil
        )
        #expect(
            DiveActivityMediaPresentation.adjacentPhotoID(selectedID: first, in: photos, offset: -1) == nil
        )
        #expect(
            DiveActivityMediaPresentation.adjacentPhotoID(selectedID: UUID(), in: photos, offset: 1) == second
        )
    }

    @Test @MainActor
    func diveActivityMediaStorage_addLibraryReference_persistsOrderedRows() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        context.insert(activity)
        try context.save()

        _ = try DiveActivityMediaStorage.addLibraryReference(localIdentifier: "A/1", mediaKind: .image, to: activity, modelContext: context)
        _ = try DiveActivityMediaStorage.addLibraryReference(localIdentifier: "B/2", mediaKind: .video, to: activity, modelContext: context)

        let sorted = DiveActivityMediaPresentation.sortedPhotos(on: activity)
        #expect(sorted.count == 2)
        #expect(sorted.map(\.sortOrder) == [0, 1])
        #expect(sorted.map(\.photosLocalIdentifier) == ["A/1", "B/2"])
    }

    // MARK: - Photos library reference media (pointer, no duplicated bytes)

    @Test func diveMediaStorage_shouldReferenceLibraryAsset_requiresNonEmptyIdentifier() {
        #expect(DiveActivityMediaStorage.shouldReferenceLibraryAsset(localIdentifier: "ABC/L0/001"))
        #expect(!DiveActivityMediaStorage.shouldReferenceLibraryAsset(localIdentifier: "   "))
        #expect(!DiveActivityMediaStorage.shouldReferenceLibraryAsset(localIdentifier: nil))
    }

    @Test func diveMediaPhoto_libraryAssetLocalIdentifier_trimsAndNilsWhenBlank() {
        let reference = DiveMediaPhoto(mediaKind: .image, photosLocalIdentifier: "  ABC/L0/001  ")
        #expect(reference.libraryAssetLocalIdentifier == "ABC/L0/001")

        let blank = DiveMediaPhoto(photosLocalIdentifier: "   ")
        #expect(blank.libraryAssetLocalIdentifier == nil)
    }

    @Test @MainActor func diveMediaPhoto_videoPlaybackSource_isLibraryAssetForVideoOnly() {
        let referenceVideo = DiveMediaPhoto(mediaKind: .video, photosLocalIdentifier: "VID/L0/009")
        #expect(referenceVideo.videoPlaybackSource == .libraryAsset("VID/L0/009"))

        let imageReference = DiveMediaPhoto(mediaKind: .image, photosLocalIdentifier: "IMG/L0/001")
        #expect(imageReference.videoPlaybackSource == nil)

        // Video with no identifier cannot resolve a source.
        let identifierless = DiveMediaPhoto(mediaKind: .video, photosLocalIdentifier: "")
        #expect(identifierless.videoPlaybackSource == nil)
    }

    @Test @MainActor func diveVideoSource_identityKey_distinguishesFileAndAsset() {
        let fileURL = URL(fileURLWithPath: "/tmp/clip.mov")
        #expect(DiveVideoSource.file(fileURL).identityKey == "file:\(fileURL.absoluteString)")
        #expect(DiveVideoSource.libraryAsset("ABC").identityKey == "asset:ABC")
        #expect(DiveVideoSource.file(fileURL) != DiveVideoSource.libraryAsset("ABC"))
    }

    @Test func diveMediaReferencePruning_shouldPrune_onlyWhenMissingUnderFullAuthorization() {
        // Deleted original, full access → prune.
        #expect(DiveMediaReferencePruning.shouldPrune(hasIdentifier: true, hasFullAuthorization: true, assetExists: false))
        // Asset still exists (e.g. offline) → keep.
        #expect(!DiveMediaReferencePruning.shouldPrune(hasIdentifier: true, hasFullAuthorization: true, assetExists: true))
        // Limited access can't see unselected assets → never prune.
        #expect(!DiveMediaReferencePruning.shouldPrune(hasIdentifier: true, hasFullAuthorization: false, assetExists: false))
        // No identifier → nothing to prune.
        #expect(!DiveMediaReferencePruning.shouldPrune(hasIdentifier: false, hasFullAuthorization: true, assetExists: false))
    }

    @Test @MainActor func diveMediaStorage_addLibraryReference_persistsPointerWithoutBytes() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        context.insert(activity)
        try context.save()

        let addedID = try DiveActivityMediaStorage.addLibraryReference(
            localIdentifier: "ASSET/L0/123",
            mediaKind: .video,
            capturedAt: Date(timeIntervalSince1970: 1_000),
            to: activity,
            modelContext: context
        )
        let row = try #require(activity.mediaPhotos.first { $0.id == addedID })
        #expect(row.resolvedMediaKind == .video)
        #expect(row.photosLocalIdentifier == "ASSET/L0/123")
        #expect(row.libraryAssetLocalIdentifier == "ASSET/L0/123")
        #expect(row.videoPlaybackSource == .libraryAsset("ASSET/L0/123"))
    }

    @Test func diveMediaCaptureDateExtraction_parseExifDateTime_respectsOffset() {
        let parsed = DiveMediaCaptureDateExtraction.parseExifDateTime(
            "2024:08:23 18:22:27",
            offsetSeconds: -4 * 3600
        )
        let expected = Date(timeIntervalSince1970: 1_724_451_747)
        #expect(parsed == expected)
    }

    @Test func diveMediaCaptureDateExtraction_exifOffsetSeconds_parsesSignedHoursAndMinutes() {
        #expect(DiveMediaCaptureDateExtraction.exifOffsetSeconds(from: "-04:00") == -14_400)
        #expect(DiveMediaCaptureDateExtraction.exifOffsetSeconds(from: "+05:30") == 19_800)
        #expect(DiveMediaCaptureDateExtraction.exifOffsetSeconds(from: nil) == nil)
    }

    @Test func diveMediaCaptureDateExtraction_firstCaptureDate_prefersEarlierCandidate() {
        let exif = Date(timeIntervalSince1970: 1_700_000_000)
        let library = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(DiveMediaCaptureDateExtraction.firstCaptureDate([exif, library]) == exif)
        #expect(DiveMediaCaptureDateExtraction.firstCaptureDate([nil, library]) == library)
    }

    @Test func diveMediaCaptureDateExtraction_parseMetadataDateString_parsesISO8601() {
        let parsed = DiveMediaCaptureDateExtraction.parseMetadataDateString("2024-08-23T18:22:27Z")
        let expected = Date(timeIntervalSince1970: 1_724_437_347)
        #expect(parsed == expected)
    }

    @Test func diveMediaCaptureDateExtraction_parseIPTCDateTime_combinesDateAndTime() {
        let parsed = DiveMediaCaptureDateExtraction.parseIPTCDateTime(date: "20240823", time: "182227")
        #expect(parsed != nil)
    }

    @Test @MainActor
    func diveActivityMediaStorage_addLibraryReference_persistsCapturedAt() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        context.insert(activity)
        try context.save()

        let capturedAt = Date(timeIntervalSince1970: 1_724_446_947)
        _ = try DiveActivityMediaStorage.addLibraryReference(
            localIdentifier: "ASSET/L0/777",
            mediaKind: .image,
            capturedAt: capturedAt,
            to: activity,
            modelContext: context
        )

        let row = try #require(activity.mediaPhotos.first)
        #expect(row.capturedAt == capturedAt)
    }

    @Test func diveActivityMediaPresentation_showsCaptureDateOnHero_onlyAtMinimized() {
        #expect(DiveActivityMediaPresentation.showsCaptureDateOnHero(for: .minimized))
        #expect(!DiveActivityMediaPresentation.showsCaptureDateOnHero(for: .medium))
        #expect(!DiveActivityMediaPresentation.showsCaptureDateOnHero(for: .large))
    }

    @Test func diveActivityMediaPresentation_captureOverlayBottomInset_sitsAboveSheetAtMinimized() {
        let layoutHeight: CGFloat = 800
        let bottomSafeInset: CGFloat = 34
        let sheetHeight = DiveActivityOverviewDetent.sheetHeight(
            for: .minimized,
            layoutHeight: layoutHeight,
            bottomSafeInset: bottomSafeInset
        )
        #expect(
            DiveActivityMediaPresentation.captureOverlayBottomInset(
                layoutHeight: layoutHeight,
                detent: .minimized,
                bottomSafeInset: bottomSafeInset
            ) == sheetHeight + DiveActivityMediaPresentation.captureOverlayClearanceAboveSheet
        )
        #expect(
            DiveActivityMediaPresentation.captureOverlayBottomInset(
                layoutHeight: layoutHeight,
                detent: .medium,
                bottomSafeInset: bottomSafeInset
            ) == 0
        )
    }

    @Test func diveActivityMediaPresentation_fullScreenImageTargetEdge_clampsToScreenAndCap() {
        #expect(DiveActivityMediaPresentation.fullScreenImageTargetEdge(screenPixelWidth: 100) == 800)
        #expect(DiveActivityMediaPresentation.fullScreenImageTargetEdge(screenPixelWidth: 1_170) == 1_170)
        #expect(DiveActivityMediaPresentation.fullScreenImageTargetEdge(screenPixelWidth: 3_000) == 2_048)
    }

    @Test func diveActivityMediaPresentation_mediaCarouselPinnedStackHeight_alignsCarouselSlot() {
        let layoutHeight: CGFloat = 800
        let inset = DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
            layoutHeight: layoutHeight,
            detent: .medium
        )
        #expect(
            DiveActivityMediaPresentation.mediaCarouselPinnedStackHeight(
                layoutHeight: layoutHeight,
                detent: .medium
            ) == inset + DiveActivityMediaPresentation.carouselRowHeight
        )
    }

    @Test func diveActivityMediaPresentation_disablesPanelScroll_mediaTabUntilLarge() {
        #expect(
            DiveActivityMediaPresentation.disablesPanelScroll(
                isMediaTabSelected: true,
                detent: .minimized
            )
        )
        #expect(
            DiveActivityMediaPresentation.disablesPanelScroll(
                isMediaTabSelected: true,
                detent: .medium
            )
        )
        #expect(
            !DiveActivityMediaPresentation.disablesPanelScroll(
                isMediaTabSelected: true,
                detent: .large
            )
        )
        #expect(
            !DiveActivityMediaPresentation.disablesPanelScroll(
                isMediaTabSelected: false,
                detent: .medium
            )
        )
    }

    @Test func diveActivityMediaPresentation_sheetBodyHeightAboveMediaCarousel_reservesChromeRow() {
        let layoutHeight: CGFloat = 800
        let mediumInset = DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
            layoutHeight: layoutHeight,
            detent: .medium
        )
        #expect(
            DiveActivityMediaPresentation.sheetBodyHeightAboveMediaCarousel(
                layoutHeight: layoutHeight,
                detent: .medium
            ) == mediumInset - DiveActivityMediaPresentation.sheetChromeRowHeight
        )
        let largeInset = DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
            layoutHeight: layoutHeight,
            detent: .large
        )
        #expect(
            DiveActivityMediaPresentation.sheetBodyHeightAboveMediaCarousel(
                layoutHeight: layoutHeight,
                detent: .large
            ) == largeInset
        )
    }

    @Test func marineLifeMediaTagPresentation_chipDisplayTitle_truncatesAtMaxLength() {
        #expect(
            MarineLifeMediaTagPresentation.chipDisplayTitle(for: "French Angelfish")
                == "French Angelfish"
        )
        let longName = String(repeating: "A", count: 30)
        #expect(
            MarineLifeMediaTagPresentation.chipDisplayTitle(for: longName)
                == String(repeating: "A", count: 25) + "…"
        )
        #expect(
            MarineLifeMediaTagPresentation.chipDisplayTitle(for: "  Spotted Eagle Ray  ")
                == "Spotted Eagle Ray"
        )
    }

    @Test func marineLifeMediaTagPresentation_largeDetentUntaggedPrompt_directsUserToMediumSheet() {
        #expect(
            MarineLifeMediaTagPresentation.largeDetentUntaggedPrompt
                .contains("medium height")
        )
    }

    @Test func diveActivityMediaPresentation_showsMediaCarouselInSheet_atMinimizedAndMediumOnly() {
        #expect(DiveActivityMediaPresentation.showsMediaCarouselInSheet(for: .minimized))
        #expect(DiveActivityMediaPresentation.showsMediaCarouselInSheet(for: .medium))
        #expect(!DiveActivityMediaPresentation.showsMediaCarouselInSheet(for: .large))
    }

    @Test func diveActivityMediaPresentation_carouselRowHeight_fitsNestedScrollView() {
        #expect(
            DiveActivityMediaPresentation.carouselRowHeight
                > DiveActivityMediaPresentation.carouselThumbnailSize
        )
        #expect(
            DiveActivityMediaPresentation.carouselRowHeight
                == DiveActivityMediaPresentation.carouselThumbnailExtent(isSelected: true) + 4
        )
    }

    @Test func rootTab_logbook_matchesContentViewTabOrder() {
        #expect(RootTabIndex.home == 0)
        #expect(RootTabIndex.logbook == 1)
        #expect(RootTabIndex.fieldGuide == 2)
        #expect(RootTabIndex.explore == 3)
    }

    @Test func diveDepthProfileMediaPlotting_depthMeters_interpolatesBetweenSamples() {
        let samples = [
            DiveDepthProfileSample(elapsedSeconds: 0, depthMeters: 0),
            DiveDepthProfileSample(elapsedSeconds: 100, depthMeters: 20),
        ]
        #expect(DiveDepthProfileMediaPlotting.depthMeters(atElapsed: 50, in: samples) == 10)
    }

    @Test func diveDepthProfileMediaPlotting_markers_onlyWithinDiveWindow() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let points = [
            DiveProfilePoint(timestamp: start, depthMeters: 5),
            DiveProfilePoint(timestamp: start.addingTimeInterval(600), depthMeters: 18),
        ]
        let samples = DiveDepthProfileSeries.samples(fromProfilePoints: points)
        let inWindow = DiveMediaPhoto(
            sortOrder: 0,
            mediaKind: .image,
            capturedAt: start.addingTimeInterval(300)
        )
        let before = DiveMediaPhoto(
            sortOrder: 1,
            mediaKind: .image,
            capturedAt: start.addingTimeInterval(-60)
        )
        let after = DiveMediaPhoto(
            sortOrder: 2,
            mediaKind: .video,
            capturedAt: start.addingTimeInterval(900)
        )
        let markers = DiveDepthProfileMediaPlotting.markers(
            mediaPhotos: [inWindow, before, after],
            profileSamples: samples,
            activityStartTime: start,
            durationMinutes: 10,
            profilePoints: points
        )
        #expect(markers.count == 1)
        #expect(markers.first?.mediaID == inWindow.id)
        #expect(markers.first?.isVideo == false)
        #expect(markers.first?.elapsedSeconds == 300)
    }

    @Test func diveMutedVideoAudioSession_usesAmbientMixWithOthers() {
        #expect(DiveMutedVideoAudioSession.categoryRawValueForTesting == "AVAudioSessionCategoryAmbient")
        #expect(DiveMutedVideoAudioSession.includesMixWithOthersForTesting)
    }

    @Test func diveActivityMediaPresentation_formattedCaptureAtDivePosition_usesDisplayUnits() {
        let context = DiveMediaCaptureContext(elapsedSeconds: 720, depthMeters: 18.288)
        let imperial = DiveActivityMediaPresentation.formattedCaptureAtDivePosition(
            context: context,
            displayUnits: .imperial
        )
        #expect(imperial.contains("ft"))
        #expect(imperial.contains("12 minutes into the dive"))

        let metric = DiveActivityMediaPresentation.formattedCaptureAtDivePosition(
            context: context,
            displayUnits: .metric
        )
        #expect(metric.contains("m"))
        #expect(metric.contains("12 minutes into the dive"))
    }

    @Test func diveDepthProfileMediaPlotting_captureContext_matchesMarkerWindow() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let points = [
            DiveProfilePoint(timestamp: start, depthMeters: 0),
            DiveProfilePoint(timestamp: start.addingTimeInterval(1200), depthMeters: 30),
        ]
        let samples = DiveDepthProfileSeries.samples(fromProfilePoints: points)
        let media = DiveMediaPhoto(
            sortOrder: 0,
            mediaKind: .image,
            capturedAt: start.addingTimeInterval(600)
        )
        let context = DiveDepthProfileMediaPlotting.captureContext(
            for: media,
            profileSamples: samples,
            activityStartTime: start,
            durationMinutes: 20,
            profilePoints: points
        )
        #expect(context?.elapsedSeconds == 600)
        #expect(context?.depthMeters == 15)
    }

    @Test func diveDepthProfileMediaPlotting_captureContextsByMediaID_matchesCaptureContext() {
        let start = Date(timeIntervalSince1970: 2_100_000)
        let points = [
            DiveProfilePoint(timestamp: start, depthMeters: 0),
            DiveProfilePoint(timestamp: start.addingTimeInterval(1200), depthMeters: 30),
        ]
        let samples = DiveDepthProfileSeries.samples(fromProfilePoints: points)
        let inWindow = DiveMediaPhoto(sortOrder: 0, mediaKind: .image, capturedAt: start.addingTimeInterval(300))
        let outWindow = DiveMediaPhoto(sortOrder: 1, mediaKind: .video, capturedAt: start.addingTimeInterval(1300))

        let contexts = DiveDepthProfileMediaPlotting.captureContextsByMediaID(
            mediaPhotos: [inWindow, outWindow],
            profileSamples: samples,
            activityStartTime: start,
            durationMinutes: 20,
            profilePoints: points
        )
        let single = DiveDepthProfileMediaPlotting.captureContext(
            for: inWindow,
            profileSamples: samples,
            activityStartTime: start,
            durationMinutes: 20,
            profilePoints: points
        )

        #expect(contexts[inWindow.id] == single)
        #expect(contexts[outWindow.id] == nil)
    }

    @Test func diveDepthProfileMediaPlotting_markerThumbnailScale_isOneAtFullViewport() {
        let viewport = DiveDepthProfileChartViewport.full(elapsedMax: 1000)
        #expect(
            DiveDepthProfileMediaPlotting.markerThumbnailScale(
                viewport: viewport,
                fullElapsedMax: 1000
            ) == 1
        )
        #expect(
            DiveDepthProfileMediaPlotting.markerThumbnailDisplaySize(
                viewport: viewport,
                fullElapsedMax: 1000
            ) == DiveDepthProfileMediaPlotting.markerThumbnailSize
        )
    }

    @Test func diveDepthProfileMediaPlotting_markerThumbnailScale_growsWhenZoomedIn() {
        var viewport = DiveDepthProfileChartViewport.full(elapsedMax: 1000)
        viewport.zoom(scale: 4, anchorFraction: 0.5, fullElapsedMax: 1000)
        let scale = DiveDepthProfileMediaPlotting.markerThumbnailScale(
            viewport: viewport,
            fullElapsedMax: 1000
        )
        #expect(scale > 1)
        #expect(scale <= DiveDepthProfileMediaPlotting.markerThumbnailMaxScale)
        #expect(
            DiveDepthProfileMediaPlotting.markerThumbnailDisplaySize(
                viewport: viewport,
                fullElapsedMax: 1000
            ) > DiveDepthProfileMediaPlotting.markerThumbnailSize
        )
    }

    @Test func diveDepthProfileMediaPlotting_markerThumbnailMetrics_areCompactSquares() {
        #expect(DiveDepthProfileMediaPlotting.markerThumbnailSize == 28)
        #expect(DiveDepthProfileMediaPlotting.markerThumbnailCornerRadius == 5)
        #expect(
            DiveDepthProfileMediaPlotting.markerThumbnailSize
                < DiveActivityMediaPresentation.carouselThumbnailSize
        )
    }

    @Test func diveActivityMediaPresentation_mediaPositionLabel_usesSelectedItem() {
        let first = DiveMediaPhoto(sortOrder: 0, mediaKind: .image)
        let second = DiveMediaPhoto(sortOrder: 1, mediaKind: .video)
        let photos = [first, second]

        #expect(
            DiveActivityMediaPresentation.mediaPositionLabel(selectedID: second.id, in: photos) == "Video 2 of 2"
        )
        #expect(
            DiveActivityMediaPresentation.mediaPositionLabel(selectedID: UUID(), in: photos) == "Photo 1 of 2"
        )
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

    @Test func diveLocationMapPresentation_mapMarkerCoordinateTitle_usesLocaleFormatting() {
        let coordinate = DiveCoordinate(latitude: 12.08316, longitude: -68.28330)
        let enUS = Locale(identifier: "en_US")
        #expect(
            DiveLocationMapPresentation.mapMarkerCoordinateTitle(for: coordinate, locale: enUS)
                == "12.083°, -68.283°"
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

    @Test func diveLocationMapPresentation_adjustedMapCenter_minimized_shiftsMoreThanMedium() {
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
        #expect(coordinate.latitude - minimized.latitude > coordinate.latitude - medium.latitude)
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

    @Test func pushedDetailHeroModeTogglePresentation_compactChromeWidth() {
        #expect(PushedDetailHeroModeTogglePresentation.segmentSize == 44)
        #expect(PushedDetailHeroModeTogglePresentation.chromeWidth == 100)
    }

    @Test func appButtonChrome_standaloneIconMinTapDimension_matchesBackButton() {
        #expect(AppButtonChrome.standaloneIconMinTapDimension == SecondaryDestinationChromeMetrics.backButtonMinimumTapDimension)
        #expect(AppButtonChrome.standaloneIconMinTapDimension == AppToolbarIconButtonMetrics.tapDimension)
        #expect(AppToolbarIconButtonMetrics.tapDimension == AppTheme.Layout.glassChromeControlHeight)
    }

    @Test @MainActor func mapKitWarmup_shouldWarmUp_matchesUITestLaunchFlag() {
        #expect(MapKitWarmup.shouldWarmUp == !GoDiveUITestConfiguration.isActive)
    }

    @Test func googleMapsBootstrap_shouldWarmUpAtLaunch_respectsEngineAndUITestFlag() {
        #expect(
            GoogleMapsBootstrap.shouldWarmUpAtLaunch
                == (!GoDiveUITestConfiguration.isActive && GoDiveMapEngine.active == .googleMaps && GoogleMapsBootstrap.loadAPIKey() != nil)
        )
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

    @Test func diveActivityOverviewPanelMetrics_mapPanelVisibility_followsRestingDetent() {
        let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let medium = DiveActivityOverviewPanelMetrics.mediumHeightFraction
        let large = DiveActivityOverviewPanelMetrics.largeHeightFraction

        #expect(
            !DiveActivityOverviewPanelMetrics.mapPanelShowsStatsBox(
                restingDetent: .minimized,
                heightFraction: minimized
            )
        )
        #expect(
            DiveActivityOverviewPanelMetrics.mapPanelShowsStatsBox(
                restingDetent: .medium,
                heightFraction: medium
            )
        )
        #expect(
            !DiveActivityOverviewPanelMetrics.mapPanelShowsDetails(
                restingDetent: .medium,
                heightFraction: medium
            )
        )
        #expect(
            DiveActivityOverviewPanelMetrics.mapPanelShowsDetails(
                restingDetent: .large,
                heightFraction: large
            )
        )
        #expect(
            DiveActivityOverviewPanelMetrics.mapDetailsPresentationOpacity(
                restingDetent: .large,
                heightFraction: medium
            ) == 1
        )
    }

    @Test func diveActivityOverviewPanelMetrics_mapRevealProgress_tracksDetentBands() {
        let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
        let medium = DiveActivityOverviewPanelMetrics.mediumHeightFraction
        let large = DiveActivityOverviewPanelMetrics.largeHeightFraction

        #expect(
            DiveActivityOverviewPanelMetrics.mapStatsRevealProgress(heightFraction: minimized) == 0
        )
        #expect(
            DiveActivityOverviewPanelMetrics.mapStatsRevealProgress(heightFraction: medium) == 1
        )
        #expect(
            DiveActivityOverviewPanelMetrics.mapDetailsRevealProgress(heightFraction: medium) == 0
        )
        #expect(
            DiveActivityOverviewPanelMetrics.mapDetailsRevealProgress(heightFraction: large) == 1
        )

        let midStats = (minimized + medium) / 2
        let statsMid = DiveActivityOverviewPanelMetrics.mapStatsRevealProgress(
            heightFraction: midStats
        )
        #expect(statsMid > 0.35 && statsMid < 0.65)

        let midDetails = (medium + large) / 2
        let detailsMid = DiveActivityOverviewPanelMetrics.mapDetailsRevealProgress(
            heightFraction: midDetails
        )
        #expect(detailsMid > 0.35 && detailsMid < 0.65)
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

    @Test func diveActivityOverviewPresentation_siteTitleLinksToCatalogOverview_requiresLinkedSiteID() {
        let siteID = UUID()
        #expect(
            DiveActivityOverviewPresentation.siteTitleLinksToCatalogOverview(linkedCatalogSiteID: siteID)
        )
        #expect(
            !DiveActivityOverviewPresentation.siteTitleLinksToCatalogOverview(linkedCatalogSiteID: nil)
        )
    }

    @Test @MainActor func appHeaderStackedTitleChrome_usesCenteredPrimaryTextBelowBackRow() {
        #expect(AppHeaderStackedTitleChrome.titlePlacement == .belowBackRow)
        #expect(AppHeaderStackedTitleChrome.titleMultilineAlignment == .center)
    }

    @Test func diveActivityOverviewPresentation_mapHeaderCopy() {
        #expect(
            DiveActivityOverviewPresentation.diveNumberChipLabel(
                diveNumber: 12,
                diveNumberExplicitlyNone: false
            ) == "#12"
        )
        #expect(
            DiveActivityOverviewPresentation.diveNumberChipLabel(
                diveNumber: nil,
                diveNumberExplicitlyNone: true
            ) == nil
        )
        #expect(
            DiveActivityOverviewPresentation.regionCountryLine(
                region: "Bonaire",
                country: "Caribbean Netherlands"
            ) == "Bonaire, Caribbean Netherlands"
        )
        #expect(
            DiveActivityOverviewPresentation.regionCountryLine(
                locationName: "Negril, Jamaica"
            ) == "Negril, Jamaica"
        )
        let line = DiveActivityOverviewPresentation.startDateDashTimeLine(
            startTime: Date(timeIntervalSince1970: 0),
            timeZoneOffsetSeconds: 0
        )
        #expect(line.contains(" - "))
        let parts = line.split(separator: " - ", maxSplits: 1).map(String.init)
        #expect(parts.count == 2)
        #expect(!parts[1].contains(parts[0]))
    }

    @Test func diveActivityTimePresentation_timeOnlyOmitsCalendarDate() {
        let instant = Date(timeIntervalSinceReferenceDate: 0)
        let date = DiveActivityTimePresentation.formatLongDateOnly(instant, timeZoneOffsetSeconds: 0)
        let time = DiveActivityTimePresentation.formatTimeOnly(instant, timeZoneOffsetSeconds: 0)
        #expect(!time.isEmpty)
        #expect(!time.contains("2001"))
        #expect(!time.contains("January"))
        #expect(date.contains("2001"))
    }

    @Test func diveActivityOverviewPresentation_mapOverviewStatsLayout() {
        let layout = DiveActivityOverviewPresentation.mapOverviewStatsLayout(
            durationMinutes: 42,
            maxDepthMeters: 18.3,
            averageDepthMeters: 12,
            surfaceIntervalSeconds: 3600,
            displayUnits: .imperial
        )
        #expect(layout.leadingStats.count == 2)
        #expect(layout.leadingStats[0].titleLine1 == "Dive")
        #expect(layout.leadingStats[0].titleLine2 == "Duration")
        #expect(layout.leadingStats[0].valueNumber == "42")
        #expect(layout.leadingStats[0].valueUnit == "min")
        #expect(layout.leadingStats[0].icon == .clock)
        #expect(layout.leadingStats[1].titleLine1 == "Surface")
        #expect(layout.leadingStats[1].titleLine2 == "Interval")
        #expect(layout.leadingStats[1].valueNumber == "60")
        #expect(layout.leadingStats[1].valueUnit == "min")
        #expect(layout.leadingStats[1].icon == .palmTree)
        let longInterval = DiveActivityOverviewPresentation.formattedMapSurfaceIntervalParts(5_400)
        #expect(longInterval.number == "1 Hr")
        #expect(longInterval.unit == "30 Mins")
        let justOverHour = DiveActivityOverviewPresentation.formattedMapSurfaceIntervalParts(3_660)
        #expect(justOverHour.number == "1 Hr")
        #expect(justOverHour.unit == "1 Min")
        let twoHours = DiveActivityOverviewPresentation.formattedMapSurfaceIntervalParts(7_200)
        #expect(twoHours.number == "2 Hrs")
        #expect(twoHours.unit == "0 Mins")
        #expect(DiveActivityOverviewPresentation.mapSurfaceIntervalHourUnit(1) == "Hr")
        #expect(DiveActivityOverviewPresentation.mapSurfaceIntervalHourUnit(2) == "Hrs")
        #expect(DiveActivityOverviewPresentation.mapSurfaceIntervalMinuteUnit(1) == "Min")
        #expect(DiveActivityOverviewPresentation.mapSurfaceIntervalMinuteUnit(30) == "Mins")
        #expect(layout.depthStats[0].titleLine1 == "Avg")
        #expect(layout.depthStats[1].titleLine1 == "Max")
        #expect(layout.depthStats[1].valueNumber == "60.0")
        #expect(layout.depthStats[1].valueUnit == "ft")
        #expect(layout.depthStats[0].valueNumber == "39.4")
        #expect(abs(layout.depthGauge.maxFillFraction - (18.3 / 40)) < 0.001)
        #expect(abs(layout.depthGauge.avgLineFraction - (12 / 40)) < 0.001)
        #expect(layout.depthGauge.showsAverageLine)
        #expect(
            DiveActivityOverviewPresentation.splitDisplayValue("60.0 ft").number == "60.0"
        )
        #expect(
            DiveActivityOverviewPresentation.splitDisplayValue("60.0 ft").unit == "ft"
        )
        #expect(
            DiveActivityOverviewPresentation.depthGaugeFillFraction(depthMeters: 80, referenceMaxMeters: 40) == 1
        )
        #expect(
            DiveActivityOverviewPresentation.formattedDurationSeconds(nil) == "—"
        )
    }

    @Test func diveActivityOverviewPanelMetrics_mapMinimizedScrollContentMinHeight() {
        let height = DiveActivityOverviewPanelMetrics.mapMinimizedPanelScrollContentMinHeight(
            layoutHeight: 844,
            bottomSafeInset: 34
        )
        #expect(height > 0)
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
    func fitFileImport_emptyData_returnsOutcomeWithEmptyFileMessage() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddy.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let outcome = await FitDiveFileImport.importFitData(Data(), modelContext: context)
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

    @Test func uddfDiveNumberFields_zero_isExplicitlyNone() {
        let resolved = UddfDiveFileDecoder.diveNumberFields(fromUddfDiveNumber: 0)
        #expect(resolved.diveNumber == nil)
        #expect(resolved.diveNumberExplicitlyNone == true)
    }

    @Test func uddfDiveNumberFields_positive_preservesNumber() {
        let resolved = UddfDiveFileDecoder.diveNumberFields(fromUddfDiveNumber: 146)
        #expect(resolved.diveNumber == 146)
        #expect(resolved.diveNumberExplicitlyNone == false)
    }

    @Test func uddfDecoder_divenumberZero_showsDashInLogbook() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>1</version></generator>
        <profiledata><repetitiongroup id="rg">
        <dive id="d-zero">
            <informationbeforedive>
                <datetime>2025-05-09T11:26:28</datetime>
                <divenumber>0</divenumber>
            </informationbeforedive>
            <informationafterdive>
                <greatestdepth>10</greatestdepth>
                <diveduration>60</diveduration>
            </informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive>
        </repetitiongroup></profiledata>
        </uddf>
        """
        let dive = try UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first
        let activity = try #require(dive)
        #expect(activity.diveNumber == nil)
        #expect(activity.diveNumberExplicitlyNone == true)
        #expect(activity.diveNumberLogbookLabel == "-")
    }

    @Test func uddfDecoder_minimal_buildsOneDive() throws {
        let data = Data(UddfTestXML.oneDive.utf8)
        let dives = try UddfDiveFileDecoder.buildDiveActivities(from: data)
        #expect(dives.count == 1)
        let d = try #require(dives.first)
        #expect(d.source == .macDive)
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

    @Test func diveDateTimeParsing_zuluStoresZeroOffset() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime("2025-05-09T14:00:00Z")
        #expect(parsed?.timeZoneOffsetSeconds == 0)
        #expect(parsed?.instant != nil)
    }

    @Test func diveDateTimeParsing_explicitOffsetFromDatetime() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime("2025-05-09T11:26:28+07:00")
        #expect(parsed?.timeZoneOffsetSeconds == 7 * 3600)
    }

    @Test func diveDateTimeParsing_naiveMacDiveDatetime_isUTC_instant() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime("2024-08-23T22:22:27")
        #expect(parsed?.timeZoneOffsetSeconds == nil)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        #expect(cal.component(.hour, from: parsed!.instant) == 22)
    }

    @Test func diveDateTimeParsing_naiveDatetime_withSiteTimezone_interpretsWallClockAsLocal() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime("2024-08-23T22:22:27", siteTimeZoneHours: -4)
        #expect(parsed?.timeZoneOffsetSeconds == -4 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
        #expect(localCal.component(.hour, from: parsed!.instant) == 22)
        #expect(localCal.component(.minute, from: parsed!.instant) == 22)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        #expect(utcCal.component(.day, from: parsed!.instant) == 24)
        #expect(utcCal.component(.hour, from: parsed!.instant) == 2)
    }

    @Test func diveDateTimeParsing_naiveWithSiteTimeZoneHours_convertsToUTCInstant() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime("2025-05-09T11:26:28", siteTimeZoneHours: -4)
        #expect(parsed?.timeZoneOffsetSeconds == -4 * 3600)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        #expect(utcCal.component(.hour, from: parsed!.instant) == 15)
        #expect(utcCal.component(.minute, from: parsed!.instant) == 26)
    }

    @Test func diveSiteTimeZoneResolution_uddfHoursIfPersisted_readsStoredSiteTimezone() throws {
        let site = DiveSite(
            siteName: "Cedar Pass",
            timeZoneIdentifier: "America/Cancun",
            timeZoneOffsetSeconds: -5 * 3600
        )
        let instant = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant("2021-07-18T14:53:45"))
        #expect(DiveSiteTimeZoneResolution.uddfHoursIfPersisted(from: site, at: instant) == -5.0)
    }

    @Test @MainActor
    func diveGeographicTimeZoneLookup_uddfHoursFromSite_usesPersistedCatalogSiteWithoutNetwork() async throws {
        let site = DiveSite(
            siteName: "Cedar Pass",
            latCoords: 20.37539,
            longCoords: -87.0398,
            timeZoneIdentifier: "America/Cancun",
            timeZoneOffsetSeconds: -5 * 3600
        )
        let instant = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant("2021-07-18T14:53:45"))
        let resolver = FailingGeocodingTimeZoneResolver()
        let hours = await DiveGeographicTimeZoneLookup.uddfHoursFromSite(
            latitude: site.latCoords,
            longitude: site.longCoords,
            locationName: site.siteName,
            catalogSite: site,
            at: instant,
            resolver: resolver
        )
        #expect(hours == -5.0)
        #expect(resolver.coordinateLookupCount == 0)
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
        #expect(activity.diveSite == nil)
    }

    @Test func diveActivityTimeZoneResolution_prefersPreviewCatalogSiteCoordinates() {
        let catalog = DiveSite(siteName: "Cedar Pass", latCoords: 20.37539, longCoords: -87.0398)
        let activity = DiveActivity(
            source: .macDive,
            startTime: Date(),
            durationMinutes: 60,
            maxDepthMeters: 10,
            siteName: "Cedar Pass"
        )
        let coordinate = DiveActivityTimeZoneResolution.coordinateForLookup(
            on: activity,
            catalogSites: [catalog]
        )
        #expect(coordinate?.latitude == 20.37539)
        #expect(coordinate?.longitude == -87.0398)
    }

    @Test func diveGeographicTimeZoneLookup_uddfHoursFromSite_prefersNetworkOverOffline() async throws {
        let tz = try #require(TimeZone(identifier: "America/Cancun"))
        let resolver = FixedGeocodingTimeZoneResolver(timeZone: tz)
        let instant = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant("2021-07-18T14:53:45"))
        let hours = await DiveGeographicTimeZoneLookup.uddfHoursFromSite(
            latitude: 39.59303,
            longitude: -104.8778,
            locationName: nil,
            at: instant,
            resolver: resolver
        )
        #expect(hours == Double(tz.secondsFromGMT(for: instant)) / 3600.0)
    }

    @Test @MainActor
    func uddfMacDiveImportDatetimeNetworkNormalization_realignsLocalWallUsingNetworkTimezone() async throws {
        let raw = "2021-07-18T14:53:45"
        let offlineMisparse = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(raw))
        let activity = DiveActivity(
            source: .macDive,
            startTime: offlineMisparse,
            durationMinutes: 60,
            maxDepthMeters: 10,
            siteName: "Cedar Pass",
            locationName: "Cozumel",
            entryCoordinate: DiveCoordinate(latitude: 20.37539, longitude: -87.0398)
        )
        activity.uddfImportDatetimeRaw = raw
        activity.uddfWatchNaiveDatetimeSemantics = .diveLocalWallTime

        let tz = try #require(TimeZone(identifier: "America/Cancun"))
        await UddfMacDiveImportDatetimeNetworkNormalization.apply(
            [activity],
            resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
        )

        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        #expect(localCal.component(.hour, from: activity.startTime) == 14)
        #expect(localCal.component(.minute, from: activity.startTime) == 53)
        #expect(activity.timeZoneOffsetSeconds == tz.secondsFromGMT(for: activity.startTime))
    }

    @Test func diveDateTimeParsing_cozumelCoordinates_inferAmericaCancun() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime(
            "2021-07-18T14:53:45",
            siteLatitude: 20.37539,
            siteLongitude: -87.0398
        )
        #expect(parsed?.timeZoneOffsetSeconds == -5 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = TimeZone(identifier: "America/Cancun") ?? .gmt
        #expect(localCal.component(.hour, from: parsed!.instant) == 14)
    }

    @Test func diveDateTimeParsing_cozumelLocationName_withoutCoordinates_interpretsLocalWall() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime(
            "2021-07-22T16:10:31",
            siteLocationName: "Cozumel"
        )
        #expect(parsed?.timeZoneOffsetSeconds == -5 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = TimeZone(identifier: "America/Cancun") ?? .gmt
        #expect(localCal.component(.hour, from: parsed!.instant) == 16)
    }

    @Test func diveDateTimeParsing_naiveWithBonaireSiteCoordinates_interpretsMacDiveWallAsLocal() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime(
            "2024-04-27T15:55:55",
            siteTimeZoneHours: nil,
            siteLatitude: 12.10325,
            siteLongitude: -68.28845
        )
        #expect(parsed?.timeZoneOffsetSeconds == -4 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
        #expect(localCal.component(.hour, from: parsed!.instant) == 15)
        #expect(localCal.component(.minute, from: parsed!.instant) == 55)
    }

    @Test func uddfNaiveDatetimeStartTimeCorrection_isUtcWallClockInstant_detectsUtcMisparse() throws {
        let raw = "2024-04-27T15:55:55"
        let utcMisparse = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(raw))
        #expect(
            UddfNaiveDatetimeStartTimeCorrection.isUtcWallClockInstant(
                startTime: utcMisparse,
                rawDatetime: raw
            )
        )
        let localParsed = try #require(
            DiveDateTimeParsing.parseUddfDateTime(
                raw,
                siteLatitude: 12.10325,
                siteLongitude: -68.28845
            )
        )
        #expect(
            !UddfNaiveDatetimeStartTimeCorrection.isUtcWallClockInstant(
                startTime: localParsed.instant,
                rawDatetime: raw
            )
        )
    }

    @Test @MainActor
    func uddfNaiveDatetimeStartTimeCorrection_realignsUtcMisparseUsingImportRaw() async throws {
        let raw = "2024-04-27T15:55:55"
        let utcMisparse = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(raw))
        let activity = DiveActivity(
            source: .macDive,
            startTime: utcMisparse,
            timeZoneOffsetSeconds: -4 * 3600,
            durationMinutes: 72,
            maxDepthMeters: 18,
            bottomTimeSeconds: 4_351,
            entryCoordinate: DiveCoordinate(latitude: 12.10325, longitude: -68.28845)
        )
        activity.uddfImportDatetimeRaw = raw
        let profilePoint = DiveProfilePoint(
            timestamp: utcMisparse,
            depthMeters: 5,
            dive: activity
        )
        activity.profilePoints = [profilePoint]

        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        await UddfNaiveDatetimeStartTimeCorrection.reconcile(
            [activity],
            resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
        )

        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        #expect(localCal.component(.hour, from: activity.startTime) == 15)
        #expect(localCal.component(.minute, from: activity.startTime) == 55)
        #expect(activity.startTime.timeIntervalSince(profilePoint.timestamp) == 0)
    }

    @Test func uddfMacDiveWatchDatetimeSemantics_classifiesGarminDescentAndSuuntoComputer() {
        let garminDescent = UddfEquipmentCatalogItem(
            id: "g1",
            kind: "variouspieces",
            name: "Garmin Descent Mk3i 43mm",
            model: "Descent Mk3i 43mm",
            manufacturerName: "Garmin"
        )
        let suuntoComputer = UddfEquipmentCatalogItem(
            id: "s1",
            kind: "divecomputer",
            name: "Suunto D4i",
            model: "D4i",
            manufacturerName: "Suunto"
        )
        let suuntoTransmitter = UddfEquipmentCatalogItem(
            id: "t1",
            kind: "variouspieces",
            name: "Suunto Tank Pressure Transmitter",
            model: "Tank Pressure Transmitter",
            manufacturerName: "Suunto"
        )
        let catalog = [garminDescent.id: garminDescent, suuntoComputer.id: suuntoComputer, suuntoTransmitter.id: suuntoTransmitter]

        #expect(
            UddfMacDiveWatchDatetimeSemanticsResolver.classify(
                equipmentUsedRefs: [garminDescent.id],
                catalog: catalog
            ) == .utcWallClock
        )
        #expect(
            UddfMacDiveWatchDatetimeSemanticsResolver.classify(
                equipmentUsedRefs: [suuntoComputer.id],
                catalog: catalog
            ) == .diveLocalWallTime
        )
        #expect(
            UddfMacDiveWatchDatetimeSemanticsResolver.classify(
                equipmentUsedRefs: [suuntoTransmitter.id],
                catalog: catalog
            ) == nil
        )
    }

    @Test func diveDateTimeParsing_macDiveGarminSemantics_parsesNaiveAsUtcInstant() {
        let parsed = DiveDateTimeParsing.parseUddfDateTime(
            "2026-05-02T00:43:02",
            siteLatitude: 12.12201,
            siteLongitude: -68.29028,
            macDiveNaiveSemantics: .utcWallClock
        )
        #expect(parsed?.timeZoneOffsetSeconds == nil)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        #expect(utcCal.component(.hour, from: parsed!.instant) == 0)
        #expect(utcCal.component(.minute, from: parsed!.instant) == 43)
    }

    @Test @MainActor
    func uddfNaiveDatetimeStartTimeCorrection_garminUtcWallClock_doesNotShiftStartTime() async throws {
        let raw = "2026-04-30T18:07:53"
        let utcInstant = try #require(DiveDateTimeParsing.parseUddfDateTime(
            raw,
            macDiveNaiveSemantics: .utcWallClock
        )?.instant)
        let activity = DiveActivity(
            source: .macDive,
            startTime: utcInstant,
            durationMinutes: 63,
            maxDepthMeters: 15.88,
            bottomTimeSeconds: 3_811,
            locationName: "Bonaire",
            entryCoordinate: DiveCoordinate(latitude: 12.03342, longitude: -68.26169)
        )
        activity.uddfImportDatetimeRaw = raw
        activity.uddfWatchNaiveDatetimeSemantics = .utcWallClock

        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        await UddfNaiveDatetimeStartTimeCorrection.reconcile(
            [activity],
            resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
        )

        #expect(abs(activity.startTime.timeIntervalSince(utcInstant)) < 1.0)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        #expect(utcCal.component(.hour, from: activity.startTime) == 18)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        #expect(localCal.component(.hour, from: activity.startTime) == 14)
    }

    @Test @MainActor
    func uddfImportedDiveNormalization_garminBonaire_keepsUtcInstantAndLocalDisplay() async throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>MacDive</name><version>1.4.13</version></generator>
        <diver><owner id="o1"><equipment>
            <variouspieces id="dc-garmin">
                <name>Garmin Descent Mk3i 43mm</name>
                <manufacturer><name>Garmin</name></manufacturer>
                <model>Descent Mk3i 43mm</model>
            </variouspieces>
        </equipment></owner></diver>
        <divesite><site id="s1"><name>Sweet Dreams</name>
            <geography><location>Bonaire</location>
                <latitude>12.03342</latitude><longitude>-68.26169</longitude>
            </geography>
        </site></divesite>
        <profiledata><repetitiongroup id="rg"><dive id="d1">
            <informationbeforedive><link ref="s1"/><datetime>2026-04-30T18:07:53</datetime></informationbeforedive>
            <informationafterdive>
                <greatestdepth>15.88</greatestdepth><diveduration>3811.59</diveduration>
                <equipmentused><link ref="dc-garmin"/></equipmentused>
            </informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive></repetitiongroup></profiledata>
        </uddf>
        """
        let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        await UddfImportedDiveNormalization.normalizeBeforePersist(
            [activity],
            resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
        )

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        #expect(utcCal.component(.hour, from: activity.startTime) == 18)
        #expect(utcCal.component(.minute, from: activity.startTime) == 7)

        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        #expect(localCal.component(.hour, from: activity.startTime) == 14)
        #expect(localCal.component(.minute, from: activity.startTime) == 7)
        #expect(activity.timeZoneOffsetSeconds == tz.secondsFromGMT(for: activity.startTime))
    }

    @Test func uddfDecoder_garminMacDiveExport_keepsNaiveDatetimeAsUtcInstant() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>MacDive</name><version>1.4.13</version></generator>
        <diver><owner id="o1"><equipment>
            <variouspieces id="dc-garmin">
                <name>Garmin Descent Mk3i 43mm</name>
                <manufacturer><name>Garmin</name></manufacturer>
                <model>Descent Mk3i 43mm</model>
            </variouspieces>
        </equipment></owner></diver>
        <divesite><site id="s1"><name>Reef</name>
            <geography><latitude>12.12201</latitude><longitude>-68.29028</longitude></geography>
        </site></divesite>
        <profiledata><repetitiongroup id="rg"><dive id="d1">
            <informationbeforedive><link ref="s1"/><datetime>2026-05-02T00:43:02</datetime></informationbeforedive>
            <informationafterdive>
                <greatestdepth>10</greatestdepth><diveduration>60</diveduration>
                <equipmentused><link ref="dc-garmin"/></equipmentused>
            </informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive></repetitiongroup></profiledata>
        </uddf>
        """
        let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
        #expect(activity.uddfWatchNaiveDatetimeSemantics == .utcWallClock)
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        #expect(utcCal.component(.hour, from: activity.startTime) == 0)
        #expect(utcCal.component(.minute, from: activity.startTime) == 43)
    }

    @Test func uddfDecoder_suuntoMacDiveExport_parsesNaiveDatetimeAsDiveLocal() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>MacDive</name><version>1.4.13</version></generator>
        <diver><owner id="o1"><equipment>
            <divecomputer id="dc-suunto">
                <name>Suunto D4i</name>
                <manufacturer><name>Suunto</name></manufacturer>
                <model>D4i</model>
            </divecomputer>
        </equipment></owner></diver>
        <divesite><site id="s1"><name>Cedar Pass</name>
            <geography><timezone>-4.0</timezone><latitude>20.37539</latitude><longitude>-71.0</longitude></geography>
        </site></divesite>
        <profiledata><repetitiongroup id="rg"><dive id="d1">
            <informationbeforedive><link ref="s1"/><datetime>2021-07-18T14:53:45</datetime></informationbeforedive>
            <informationafterdive>
                <greatestdepth>10</greatestdepth><diveduration>60</diveduration>
                <equipmentused><link ref="dc-suunto"/></equipmentused>
            </informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive></repetitiongroup></profiledata>
        </uddf>
        """
        let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
        #expect(activity.uddfWatchNaiveDatetimeSemantics == .diveLocalWallTime)
        #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
        #expect(localCal.component(.hour, from: activity.startTime) == 14)
        #expect(localCal.component(.minute, from: activity.startTime) == 53)
    }

    @Test func uddfDecoder_angelCityMacDiveExport_parsesNaiveDatetimeAsBonaireLocal() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>MacDive</name><version>1.4.13</version></generator>
        <divesite>
            <site id="s1">
                <name>Angel City</name>
                <geography>
                    <location>Bonaire</location>
                    <latitude>12.10325</latitude>
                    <longitude>-68.28845</longitude>
                </geography>
            </site>
        </divesite>
        <profiledata><repetitiongroup id="rg">
        <dive id="d1">
            <informationbeforedive><link ref="s1"/><datetime>2024-04-27T15:55:55</datetime></informationbeforedive>
            <informationafterdive><greatestdepth>10</greatestdepth><diveduration>60</diveduration></informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive>
        </repetitiongroup></profiledata>
        </uddf>
        """
        let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
        #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
        #expect(localCal.component(.hour, from: activity.startTime) == 15)
        #expect(localCal.component(.minute, from: activity.startTime) == 55)
    }

    @Test func uddfDecoder_naiveDatetimeWithSiteTimezone_storesLocalWallAsUTCInstant() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>1</version></generator>
        <divesite>
            <site id="s1">
                <name>Reef</name>
                <geography><timezone>-4.0</timezone></geography>
            </site>
        </divesite>
        <profiledata><repetitiongroup id="rg">
        <dive id="d1">
            <informationbeforedive><link ref="s1"/><datetime>2024-08-23T22:22:27</datetime></informationbeforedive>
            <informationafterdive><greatestdepth>10</greatestdepth><diveduration>60</diveduration></informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive>
        </repetitiongroup></profiledata>
        </uddf>
        """
        let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
        #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
        #expect(localCal.component(.hour, from: activity.startTime) == 22)
    }

    @Test @MainActor
    func diveGeographicTimeZoneLookup_offsetSeconds_atInstant() async throws {
        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        let resolver = FixedGeocodingTimeZoneResolver(timeZone: tz)
        let coord = DiveGeographicTimeZoneLookup.CoordinateInput(latitude: 12.12201, longitude: -68.29050)
        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = 2024
        comps.month = 8
        comps.day = 23
        comps.hour = 22
        comps.minute = 22
        comps.second = 27
        let instant = try #require(comps.date)
        let offset = await DiveGeographicTimeZoneLookup.offsetSeconds(
            for: coord,
            at: instant,
            resolver: resolver
        )
        #expect(offset == -4 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        #expect(localCal.component(.hour, from: instant) == 18)
    }

    @Test @MainActor
    func diveActivityTimeZoneResolution_fillsMissingOffsetFromCoordinates() async throws {
        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = 2024
        comps.month = 8
        comps.day = 23
        comps.hour = 22
        comps.minute = 22
        comps.second = 27
        let start = try #require(comps.date)
        let activity = DiveActivity(
            source: .macDive,
            startTime: start,
            timeZoneOffsetSeconds: nil,
            durationMinutes: 64,
            maxDepthMeters: 11.5,
            entryCoordinate: DiveCoordinate(latitude: 12.12201, longitude: -68.29050)
        )
        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        await DiveActivityTimeZoneResolution.resolveMissingOffset(
            for: activity,
            resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
        )
        #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        #expect(localCal.component(.hour, from: activity.startTime) == 18)
    }

    @Test func uddfDecoder_siteGeographyTimeZone_setsActivityOffset() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>1</version></generator>
        <divesite>
            <site id="s1">
                <name>Reef</name>
                <geography>
                    <latitude>12.1</latitude>
                    <longitude>-68.29</longitude>
                    <timezone>-4.0</timezone>
                </geography>
            </site>
        </divesite>
        <profiledata><repetitiongroup id="rg">
        <dive id="d1">
            <informationbeforedive><link ref="s1"/><datetime>2025-05-09T11:26:28</datetime></informationbeforedive>
            <informationafterdive><greatestdepth>10</greatestdepth><diveduration>60</diveduration></informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive>
        </repetitiongroup></profiledata>
        </uddf>
        """
        let dive = try UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first
        let activity = try #require(dive)
        #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
    }

    @Test func diveActivityTimePresentation_formatUTCDateTime_usesZulu() {
        let instant = Date(timeIntervalSince1970: 0)
        let label = DiveActivityTimePresentation.formatUTCDateTime(instant)
        #expect(label.hasSuffix("Z"))
    }

    @Test func diveActivityTimePresentation_formatTimeZoneOffsetLabel_formatsHoursAndMinutes() {
        #expect(DiveActivityTimePresentation.formatTimeZoneOffsetLabel(offsetSeconds: -4 * 3600) == "UTC-4:00")
        #expect(DiveActivityTimePresentation.formatTimeZoneOffsetLabel(offsetSeconds: 5 * 3600 + 30 * 60) == "UTC+5:30")
        #expect(DiveActivityTimePresentation.formatTimeZoneOffsetLabel(offsetSeconds: nil) == "Not set (device timezone)")
    }

    @Test func diveActivityTimePresentation_usesStoredOffset() {
        let instant = Date(timeIntervalSince1970: 0)
        let formatted = DiveActivityTimePresentation.formatDateTime(instant, timeZoneOffsetSeconds: -4 * 3600)
        #expect(!formatted.isEmpty)
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

    @Test func uddfProfilePoint_timestamps_followParsedStartInstant() throws {
        let dive = try UddfDiveFileDecoder.buildDiveActivities(from: Data(UddfTestXML.oneDive.utf8)).first
        let activity = try #require(dive)
        let sorted = activity.profilePoints.sorted { $0.timestamp < $1.timestamp }
        let first = try #require(sorted.first)
        let last = try #require(sorted.last)
        #expect(first.timestamp == activity.startTime)
        #expect(last.timestamp > activity.startTime)
    }

    @Test func diveFileImporterPresentation_pickerMode_allowedTypes() {
        // Each mode is restricted to exactly its extension type — no broad `.data` / `.xml` that would
        // leave every document selectable in the picker.
        #expect(DiveFileImporterPresentation.PickerMode.fit.allowedContentTypes == [.goDiveFit])
        #expect(DiveFileImporterPresentation.PickerMode.uddf.allowedContentTypes == [.goDiveUddf])
        #expect(!DiveFileImporterPresentation.PickerMode.fit.allowedContentTypes.contains(.data))
        #expect(!DiveFileImporterPresentation.PickerMode.uddf.allowedContentTypes.contains(.data))
        #expect(!DiveFileImporterPresentation.PickerMode.uddf.allowedContentTypes.contains(.xml))
        #expect(DiveFileImporterPresentation.PickerMode.uddf.isUddf)
        #expect(!DiveFileImporterPresentation.PickerMode.fit.isUddf)
    }

    @Test @MainActor
    func fitDiveFileImport_persistImportedActivity_createMissingDiveSitesFalse_doesNotCreateSite() async throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "apple-fit-sites", displayName: "Owner")
        context.insert(owner)
        try context.save()

        let activity = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            timeZoneOffsetSeconds: 0, // avoid network timezone resolution in the test
            durationMinutes: 30,
            maxDepthMeters: 18,
            siteName: "Totally Unmatched Reef XYZ"
        )

        let outcome = await FitDiveFileImport.persistImportedActivity(
            activity,
            modelContext: context,
            owner: owner,
            attachMedia: false,
            createMissingDiveSites: false
        )

        #expect(outcome.didSucceed)
        // Unmatched import name + createMissingDiveSites false → no new catalog site, dive left unlinked.
        let sites = try context.fetch(FetchDescriptor<DiveSite>())
        #expect(sites.isEmpty)
        #expect(activity.diveSite == nil)
        #expect(activity.siteName == "Totally Unmatched Reef XYZ")
    }

    @Test func diveFileImporterPresentation_isUserCancellation_recognizesPickerCancel() {
        let cocoaCancel = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        #expect(DiveFileImporterPresentation.isUserCancellation(cocoaCancel))
        #expect(DiveFileImporterPresentation.isUserCancellation(CancellationError()))
        #expect(DiveFileImporterPresentation.isUserCancellation(URLError(.cancelled)))
        let other = NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
        #expect(!DiveFileImporterPresentation.isUserCancellation(other))
    }

    @Test func uddfImportSummary_message_listsCounts() {
        let summary = UddfImportSummary(
            imported: 143,
            duplicates: 5,
            diveSitesCreated: 12,
            primaryInsertedDiveId: nil
        )
        let message = UddfImportSummary.message(for: summary)
        #expect(message.contains("143 dives imported"))
        #expect(message.contains("5 duplicate dives found"))
        #expect(message.contains("12 dive sites created"))
    }

    @Test func diveFileImportSuccess_matchesFitAndMultiUddf() {
        #expect(DiveFileImportSuccess.matches("\(FitDiveFileImport.importSuccessMessagePrefix) starting test."))
        #expect(DiveFileImportSuccess.matches("Imported 3 dives."))
        #expect(DiveFileImportSuccess.matches("Imported 143 dives. 5 duplicate dives found."))
        #expect(!DiveFileImportSuccess.matches("Could not read UDDF XML: broken"))
    }

    @Test @MainActor
    func uddfImport_onProgress_reportsInsertedAndProcessed() async throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "test-uddf-progress", displayName: "Progress")
        context.insert(owner)
        try context.save()
        let activities = try UddfDiveFileDecoder.buildDiveActivities(from: Data(UddfTestXML.twoDives.utf8))
        var snapshots: [(Int, Int, Int, Int)] = []
        _ = await UddfDiveFileImport.persistImportedActivities(
            activities,
            modelContext: context,
            owner: owner
        ) { imported, duplicates, processed, total in
            snapshots.append((imported, duplicates, processed, total))
        }
        #expect(snapshots.count == 2)
        #expect(snapshots[0] == (1, 0, 1, 2))
        #expect(snapshots[1] == (2, 0, 2, 2))
    }

    @Test @MainActor
    func uddfImport_skipsWhenGarminFingerprintAlreadyInLog() async throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "test-cross-fmt", displayName: "Cross")
        context.insert(owner)
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let garmin = DiveActivity(
            source: .garminMK3,
            sourceDiveId: "garmin-fit-abc",
            startTime: start,
            durationMinutes: 76,
            maxDepthMeters: 13.18,
            bottomTimeSeconds: 4561
        )
        DiveActivityOwnership.assignOwner(owner, to: garmin)
        context.insert(garmin)
        try context.save()

        let mac = DiveActivity(
            source: .macDive,
            sourceDiveId: "5B4EE0E4-1075-45A2-AF0A-BB08B0635051",
            startTime: start.addingTimeInterval(45),
            durationMinutes: 76,
            maxDepthMeters: 13.0,
            bottomTimeSeconds: 4560
        )
        let outcome = await UddfDiveFileImport.persistImportedActivities(
            [mac],
            modelContext: context,
            owner: owner
        )
        #expect(!outcome.didSucceed)
        #expect(outcome.insertedCount == 0)
        #expect(outcome.skippedDuplicateCount == 1)
        let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.source == .garminMK3)
    }

    @Test @MainActor
    func uddfImport_bulk_skipsDuplicateAgainstExistingLog() async throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "test-uddf-bulk-dup", displayName: "Bulk Dup")
        context.insert(owner)
        try context.save()
        let data = Data(UddfTestXML.twoDives.utf8)
        let first = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
        #expect(first.didSucceed)
        #expect(first.insertedCount == 2)
        let second = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
        #expect(!second.didSucceed)
        #expect(second.insertedCount == 0)
        #expect(second.skippedDuplicateCount == 2)
        #expect(second.totalInFile == 2)
        #expect(second.userMessage.contains("2 duplicate dives found"))
        let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(fetched.count == 2)
    }

    @Test func diveFileImportOutcome_didSucceed_matchesDiveFileImportSuccess() {
        let msg = "\(FitDiveFileImport.importSuccessMessagePrefix) starting today."
        let outcome = DiveFileImportOutcome(userMessage: msg, primaryInsertedDiveId: UUID())
        #expect(outcome.didSucceed == DiveFileImportSuccess.matches(msg))
        let fail = DiveFileImportOutcome(userMessage: "nope", primaryInsertedDiveId: nil)
        #expect(fail.didSucceed == DiveFileImportSuccess.matches("nope"))
    }

    @Test @MainActor
    func uddfImport_withoutOwner_returnsSignInMessage() async throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let data = Data(UddfTestXML.oneDive.utf8)
        let outcome = await UddfDiveFileImport.importUddfData(data, modelContext: context)
        #expect(!outcome.didSucceed)
        #expect(outcome.userMessage == "Sign in to import dives.")
    }

    @Test @MainActor
    func uddfImport_twoDives_insertsBoth() async throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "test-uddf-import", displayName: "Import Test")
        context.insert(owner)
        try context.save()
        let data = Data(UddfTestXML.twoDives.utf8)
        let outcome = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
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
            DiveBuddy.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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

    @Test func logbookRow_displayName_usesTrimmedSiteElseNewDive() {
        #expect(LogbookActivityRow.displayName(resolvedSiteName: "  Wall  ") == "Wall")
        #expect(LogbookActivityRow.displayName(resolvedSiteName: nil) == "New Dive")
        #expect(LogbookActivityRow.displayName(resolvedSiteName: "   ") == "New Dive")
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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

    @Test func profileAvatarImageCachePresentation_cacheKey_isStableForSameData() {
        let data = Data([0x01, 0x02, 0x03, 0x04])
        let keyA = ProfileAvatarImageCachePresentation.cacheKey(for: data)
        let keyB = ProfileAvatarImageCachePresentation.cacheKey(for: data)
        #expect(keyA == keyB)
        #expect(keyA != ProfileAvatarImageCachePresentation.cacheKey(for: Data([0x05])))
    }

    @Test func homeBuddyLeaderboard_topEntries_excludesSelfBuddyID() {
        let selfBuddyID = UUID()
        let otherBuddyID = UUID()
        let diveID = UUID()
        let tags: [HomeBuddyLeaderboardPresentation.TagInput] = [
            .init(buddyID: selfBuddyID, displayName: "You", profilePhoto: nil, diveActivityID: diveID),
            .init(buddyID: otherBuddyID, displayName: "Pat Lee", profilePhoto: nil, diveActivityID: diveID),
        ]
        let top = HomeBuddyLeaderboardPresentation.topEntries(
            from: tags,
            excludingBuddyID: selfBuddyID
        )
        #expect(top.count == 1)
        #expect(top[0].id == otherBuddyID)
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

    @Test func homeBuddyLeaderboard_topEntries_countsUniqueDivesPerBuddy() {
        let buddyA = UUID()
        let buddyB = UUID()
        let dive1 = UUID()
        let dive2 = UUID()
        let dive3 = UUID()
        let tags: [HomeBuddyLeaderboardPresentation.TagInput] = [
            .init(buddyID: buddyA, displayName: "Pat Lee", profilePhoto: nil, diveActivityID: dive1),
            .init(buddyID: buddyA, displayName: "Pat Lee", profilePhoto: nil, diveActivityID: dive2),
            .init(buddyID: buddyA, displayName: "Pat Lee", profilePhoto: nil, diveActivityID: dive3),
            .init(buddyID: buddyB, displayName: "Jamie", profilePhoto: nil, diveActivityID: dive1),
            .init(buddyID: buddyB, displayName: "Jamie", profilePhoto: nil, diveActivityID: dive2),
            .init(buddyID: buddyA, displayName: "Pat Lee", profilePhoto: nil, diveActivityID: dive1),
        ]
        let top = HomeBuddyLeaderboardPresentation.topEntries(from: tags)
        #expect(top.count == 2)
        #expect(top[0].id == buddyA)
        #expect(top[0].diveCount == 3)
        #expect(top[0].rank == 1)
        #expect(top[1].id == buddyB)
        #expect(top[1].diveCount == 2)
        #expect(top[1].rank == 2)
    }

    @Test func homeBuddyLeaderboard_topEntries_limitsToThree() {
        let tags = (0..<5).map { index in
            HomeBuddyLeaderboardPresentation.TagInput(
                buddyID: UUID(),
                displayName: "Buddy \(index)",
                profilePhoto: nil,
                diveActivityID: UUID()
            )
        }
        #expect(HomeBuddyLeaderboardPresentation.topEntries(from: tags).count == 3)
    }

    @Test func homeBuddyLeaderboard_shouldShow_requiresDivesAndTaggedBuddies() {
        let entry = HomeBuddyLeaderboardEntry(
            id: UUID(),
            displayName: "Pat",
            profilePhoto: nil,
            diveCount: 1,
            rank: 1
        )
        #expect(HomeBuddyLeaderboardPresentation.shouldShow(diveCount: 1, entries: [entry]))
        #expect(!HomeBuddyLeaderboardPresentation.shouldShow(diveCount: 0, entries: [entry]))
        #expect(!HomeBuddyLeaderboardPresentation.shouldShow(diveCount: 3, entries: []))
    }

    @Test func homeLifetimeStatsLeaderboardPresentation_rankedDiveIDs_limitsToFiveAndSorts() {
        let dives = (1...7).map { index in
            HomeDiveStatsInput(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                maxDepthMeters: Double(index),
                durationMinutes: index * 10,
                diveSiteID: nil,
                diveNumberLabel: "#\(index)",
                siteDisplayName: "Site \(index)"
            )
        }

        let deepest = HomeLifetimeStatsLeaderboardPresentation.rankedDiveIDs(
            dives: dives,
            kind: .deepestDives
        )
        #expect(deepest.count == 5)
        #expect(deepest.first == dives[6].id)

        let longest = HomeLifetimeStatsLeaderboardPresentation.rankedDiveIDs(
            dives: dives,
            kind: .longestDives
        )
        #expect(longest.count == 5)
        #expect(longest.first == dives[6].id)
    }

    @Test func homeLifetimeStatsLeaderboardPresentation_topSites_countsVisitsAndLimitsToFive() {
        let sharedSiteID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let dives = [
            HomeDiveStatsInput(
                id: UUID(),
                maxDepthMeters: 10,
                durationMinutes: 40,
                diveSiteID: sharedSiteID,
                diveNumberLabel: "#1",
                siteDisplayName: "Cathedral"
            ),
            HomeDiveStatsInput(
                id: UUID(),
                maxDepthMeters: 12,
                durationMinutes: 42,
                diveSiteID: sharedSiteID,
                diveNumberLabel: "#2",
                siteDisplayName: "Cathedral"
            ),
            HomeDiveStatsInput(
                id: UUID(),
                maxDepthMeters: 8,
                durationMinutes: 35,
                diveSiteID: nil,
                diveNumberLabel: "#3",
                siteDisplayName: "Blue Hole"
            ),
        ]

        let topSites = HomeLifetimeStatsLeaderboardPresentation.topSites(dives: dives)
        #expect(topSites.count == 2)
        #expect(topSites[0].name == "Cathedral")
        #expect(topSites[0].visitCount == 2)
        #expect(topSites[0].siteID == sharedSiteID)
        #expect(topSites[1].name == "Blue Hole")
        #expect(topSites[1].visitCount == 1)
        #expect(topSites[1].siteID == nil)
    }

    @Test func homeLifetimeStatsLeaderboardPresentation_topSpecies_limitsToFive() {
        let sightings = [
            HomeLifetimeStatsPresentation.SightingCountInput(
                marineLifeUUID: "fish-a",
                commonName: "French Angelfish"
            ),
            HomeLifetimeStatsPresentation.SightingCountInput(
                marineLifeUUID: "fish-a",
                commonName: "French Angelfish"
            ),
            HomeLifetimeStatsPresentation.SightingCountInput(
                marineLifeUUID: "fish-b",
                commonName: "Green Turtle"
            ),
        ]

        let topSpecies = HomeLifetimeStatsLeaderboardPresentation.topSpecies(sightings: sightings)
        #expect(topSpecies.count == 2)
        #expect(topSpecies[0].marineLifeUUID == "fish-a")
        #expect(topSpecies[0].sightingCount == 2)
        #expect(
            HomeLifetimeStatsLeaderboardPresentation.pageTitle(for: .deepestDives)
                == "Top 5 deepest dives"
        )
    }

    @Test func homeLifetimeStatsLeaderboardPresentation_siteRowDisplayData_usesOwnerVisitCount() {
        let site = DiveSite(
            siteName: "Salt Pier",
            country: "Caribbean Netherlands",
            region: "Bonaire",
            bodyOfWater: "Caribbean Sea",
            latCoords: 12.084,
            longCoords: -68.283
        )
        let entry = HomeLifetimeStatsLeaderboardPresentation.SiteEntry(
            id: site.id.uuidString,
            rank: 1,
            siteID: site.id,
            name: "Salt Pier",
            visitCount: 4
        )

        let row = HomeLifetimeStatsLeaderboardPresentation.siteRowDisplayData(entry: entry, site: site)
        #expect(row.displayName == "Salt Pier")
        #expect(row.diveCountLabel == HomeLifetimeStatsPresentation.siteVisitLabel(count: 4))
        #expect(row.coordinateLine.contains("12"))
    }

    @Test func homeLifetimeStatsLeaderboardPresentation_siteRowDisplayData_importNameBuildsExploreTile() {
        let entry = HomeLifetimeStatsLeaderboardPresentation.SiteEntry(
            id: "name:blue hole",
            rank: 1,
            siteID: nil,
            name: "Blue Hole",
            visitCount: 2
        )

        let row = HomeLifetimeStatsLeaderboardPresentation.siteRowDisplayData(entry: entry, site: nil)
        #expect(row.displayName == "Blue Hole")
        #expect(row.diveCountLabel == HomeLifetimeStatsPresentation.siteVisitLabel(count: 2))
        #expect(row.catalogSiteID == nil)
    }

    @Test func homeLifetimeStatsLeaderboardPresentation_speciesRowDisplayData_showsPreviewWhenImageExists() {
        let entry = HomeLifetimeStatsLeaderboardPresentation.SpeciesEntry(
            id: "fish-a",
            rank: 1,
            marineLifeUUID: "fish-a",
            commonName: "French Angelfish",
            sightingCount: 3
        )

        let withoutImage = HomeLifetimeStatsLeaderboardPresentation.speciesRowDisplayData(
            entry: entry,
            featureImageURL: "",
            featureImageResourceName: ""
        )
        #expect(!withoutImage.showsPreviewImage)

        let withRemote = HomeLifetimeStatsLeaderboardPresentation.speciesRowDisplayData(
            entry: entry,
            featureImageURL: "https://example.com/fish.jpg",
            featureImageResourceName: ""
        )
        #expect(withRemote.showsPreviewImage)
        #expect(withRemote.sightingCountLabel == HomeLifetimeStatsPresentation.sightingCountLabel(count: 3))
    }

    @Test func homeRoute_diveBuddy_usesRosterBuddyIDForNavigation() {
        let buddyID = UUID()
        let route = HomeRoute.diveBuddy(buddyID)
        if case .diveBuddy(let resolvedID) = route {
            #expect(resolvedID == buddyID)
        } else {
            Issue.record("Expected diveBuddy route case")
        }
    }

    @Test func diveBuddyPresentation_firstName_usesFirstToken() {
        #expect(DiveBuddyPresentation.firstName(from: "Pat Lee") == "Pat")
        #expect(DiveBuddyPresentation.firstName(from: "  Jamie  ") == "Jamie")
        #expect(DiveBuddyPresentation.firstName(from: "Madonna") == "Madonna")
        #expect(DiveBuddyPresentation.firstName(from: "   ") == "Buddy")
    }

    @Test func diveBuddyPresentation_initials_usesFirstAndLastToken() {
        #expect(DiveBuddyPresentation.initials(from: "Judy Belair") == "JB")
        #expect(DiveBuddyPresentation.initials(from: "Pat Lee") == "PL")
        #expect(DiveBuddyPresentation.initials(from: "Madonna") == "M")
        #expect(DiveBuddyPresentation.initials(from: "  jamie kay  ") == "JK")
        #expect(DiveBuddyPresentation.initials(from: "   ") == "B")
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

    @Test func appTheme_logbookSearchFieldHeight_matchesInlineChromeRow() {
        #expect(AppTheme.Layout.logbookSearchFieldHeight == AppTheme.Layout.glassChromeControlHeight)
        #expect(AppTheme.Layout.glassChromeControlHeight == 44)
    }

    @Test func logbookListSurfaceEquatableInputs_scrollNonceChangeIsNotEqual() {
        let base = LogbookListSurfaceEquatableInputs(
            items: [],
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

    @Test func collapsibleInlineTitleHeaderPresentation_scrollOffsetCollapseLogic() {
        #expect(CollapsibleInlineTitleHeaderPresentation.collapseScrollOffsetThreshold == 8)
        #expect(!CollapsibleInlineTitleHeaderPresentation.isCollapsed(forScrollOffset: 0))
        #expect(!CollapsibleInlineTitleHeaderPresentation.isCollapsed(forScrollOffset: 8))
        #expect(CollapsibleInlineTitleHeaderPresentation.isCollapsed(forScrollOffset: 8.1))
        #expect(CollapsibleInlineTitleHeaderPresentation.chromeBandHeight == 68)
        #expect(CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight == 128)
        #expect(CollapsibleInlineTitleHeaderPresentation.sideControlWidth == 44)
        #expect(CollapsibleInlineTitleHeaderPresentation.topObstructionHeight(safeAreaTop: 59) == 127)
        #expect(CollapsibleInlineTitleHeaderPresentation.scrimBandHeight(safeAreaTop: 59) == 255)
    }

    @Test func logbookAndFieldGuideCollapsibleHeaderTitles() {
        #expect(LogbookCollapsibleHeaderPresentation.title == "Activity Log")
        #expect(LogbookCollapsibleHeaderPresentation.titleAccessibilityIdentifier == "Logbook.Title")
        #expect(FieldGuideHubPresentation.tabTitle == "Field Guide")
        #expect(FieldGuideHubPresentation.titleAccessibilityIdentifier == "FieldGuide.Hub.Title")
    }

    @Test func headerChromeIconForeground_isWhite() {
        #expect(AppTheme.Colors.headerChromeIconForeground == .white)
    }

    @Test func globalSearchPresentation_indexesDivesSitesAndSpecies() {
        let siteID = UUID()
        let catalog = GlobalSearchPresentation.Catalog(
            dives: [
                GlobalSearchPresentation.DiveIndexEntry(
                    id: UUID(),
                    title: "Salt Pier #12",
                    subtitle: "Salt Pier",
                    searchHaystack: "salt pier #12 salt pier"
                ),
            ],
            diveSites: [
                GlobalSearchPresentation.DiveSiteIndexEntry(
                    title: "Salt Pier",
                    subtitle: "Bonaire",
                    searchHaystacks: ["Salt Pier", "Bonaire"],
                    destination: .diveSite(siteID)
                ),
            ],
            species: [
                GlobalSearchPresentation.SpeciesIndexEntry(
                    uuid: "marine-life-turtle",
                    title: "Green Sea Turtle",
                    subtitle: "Chelonia mydas",
                    searchText: "green sea turtle chelonia mydas"
                ),
            ],
            buddies: [],
            tags: [],
            trips: [],
            equipment: [],
            certifications: []
        )

        let results = GlobalSearchPresentation.search(catalog: catalog, query: "salt")
        #expect(results.sections.count == 2)
        #expect(results.sections.map(\.kind) == [.diveSites, .dives])

        let turtleResults = GlobalSearchPresentation.search(catalog: catalog, query: "turtle")
        #expect(turtleResults.sections.count == 1)
        #expect(turtleResults.sections.first?.kind == .species)
    }

    @Test func globalSearchSiteIndexSeeding_indexesReferenceCatalogAndSupplementalSites() {
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
        let unvisitedReference = DiveSiteReferenceSnapshot(
            id: "reef02",
            name: "Blue Reef",
            country: "Belize",
            countryCode: "BZ",
            latitude: 17.3,
            longitude: -87.7,
            maxDepthMeters: 20,
            entry: "boat",
            environment: "ocean",
            topologies: [],
            seaName: ""
        )
        let catalogSite = DiveSite(
            siteName: "Salt Pier (mine)",
            latCoords: 12.0835,
            longCoords: -68.283,
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")]
        )
        let localOnlySite = DiveSite(
            siteName: "Secret Spot",
            latCoords: 1,
            longCoords: 2
        )
        let ownerID = UUID()
        let linkedActivity = DiveActivity(
            source: .manual,
            startTime: .now,
            durationMinutes: 45,
            maxDepthMeters: 20
        )
        linkedActivity.ownerProfileID = ownerID
        linkedActivity.diveSiteID = localOnlySite.id

        let entries = GlobalSearchSiteIndexSeeding.entries(
            diveSites: [catalogSite, localOnlySite],
            ownerActivities: [linkedActivity],
            ownerProfileID: ownerID,
            reference: [reference, unvisitedReference]
        )

        #expect(entries.count == 3)
        #expect(
            entries.contains {
                if case .diveSite(let siteID) = $0.destination {
                    return siteID == catalogSite.id && $0.title == "Salt Pier (mine)"
                }
                return false
            }
        )
        #expect(
            entries.contains {
                if case .referenceSite(let referenceID) = $0.destination {
                    return referenceID == "reef02" && $0.title == "Blue Reef"
                }
                return false
            }
        )
        #expect(
            entries.contains {
                if case .diveSite(let siteID) = $0.destination {
                    return siteID == localOnlySite.id && $0.title == "Secret Spot"
                }
                return false
            }
        )

        let searchResults = GlobalSearchPresentation.search(
            catalog: GlobalSearchPresentation.Catalog(
                dives: [],
                diveSites: entries,
                species: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: []
            ),
            query: "blue reef"
        )
        #expect(searchResults.sections.count == 1)
        #expect(searchResults.sections.first?.kind == .diveSites)
        let destination = searchResults.sections.first?.hits.first?.destination
        if case .referenceSite("reef02") = destination {
            // expected reference hit
        } else {
            Issue.record("Expected referenceSite(reef02), got \(String(describing: destination))")
        }
    }

    @Test func globalSearchPresentation_emptyQueryReturnsNoSections() {
        let catalog = GlobalSearchPresentation.Catalog(
            dives: [],
            diveSites: [],
            species: [],
            buddies: [],
            tags: [],
            trips: [],
            equipment: [],
            certifications: []
        )
        #expect(GlobalSearchPresentation.search(catalog: catalog, query: "   ").sections.isEmpty)
    }

    @Test func globalSearchPresentation_contextTokenScopesBrowseResultsWithoutQuery() {
        let siteID = UUID()
        let catalog = GlobalSearchPresentation.Catalog(
            dives: [
                GlobalSearchPresentation.DiveIndexEntry(
                    id: UUID(),
                    title: "Salt Pier #12",
                    subtitle: "Salt Pier",
                    searchHaystack: "salt pier"
                ),
            ],
            diveSites: [
                GlobalSearchPresentation.DiveSiteIndexEntry(
                    title: "Salt Pier",
                    subtitle: "Bonaire",
                    searchHaystacks: ["Salt Pier"],
                    destination: .diveSite(siteID)
                ),
            ],
            species: [],
            buddies: [],
            tags: [],
            trips: [],
            equipment: [],
            certifications: []
        )

        let diveOnly = GlobalSearchPresentation.search(
            catalog: catalog,
            query: "",
            contextTokens: [.dives]
        )
        #expect(diveOnly.sections.count == 1)
        #expect(diveOnly.sections.first?.kind == .dives)
        #expect(diveOnly.sections.first?.hits.count == 1)

        let siteOnly = GlobalSearchPresentation.search(
            catalog: catalog,
            query: "",
            contextTokens: [.sites]
        )
        #expect(siteOnly.sections.count == 1)
        #expect(siteOnly.sections.first?.kind == .diveSites)
    }

    @Test func globalSearchPresentation_contextTokenAndQueryFilterWithinScope() {
        let catalog = GlobalSearchPresentation.Catalog(
            dives: [
                GlobalSearchPresentation.DiveIndexEntry(
                    id: UUID(),
                    title: "Salt Pier #12",
                    subtitle: "Salt Pier",
                    searchHaystack: "salt pier"
                ),
                GlobalSearchPresentation.DiveIndexEntry(
                    id: UUID(),
                    title: "Hilma Hooker",
                    subtitle: "Hilma Hooker",
                    searchHaystack: "hilma hooker"
                ),
            ],
            diveSites: [],
            species: [],
            buddies: [],
            tags: [],
            trips: [],
            equipment: [],
            certifications: []
        )

        let results = GlobalSearchPresentation.search(
            catalog: catalog,
            query: "salt",
            contextTokens: [.dives]
        )
        #expect(results.sections.count == 1)
        #expect(results.sections.first?.hits.count == 1)
        #expect(results.sections.first?.hits.first?.title == "Salt Pier #12")
    }

    @Test func globalSearchPresentation_isActiveWhenContextTokenSelected() {
        #expect(!GlobalSearchPresentation.isActive(query: "", contextTokens: []))
        #expect(GlobalSearchPresentation.isActive(query: "", contextTokens: [.gear]))
        #expect(GlobalSearchPresentation.isActive(query: "abc", contextTokens: []))
    }

    @Test func globalSearchPresentation_applyReturnToCategoryBrowse_clearsQueryAndTokens() {
        var query = "turtle"
        var tokens: [GlobalSearchPresentation.ContextToken] = [.marineLife]
        GlobalSearchPresentation.applyReturnToCategoryBrowse(query: &query, contextTokens: &tokens)
        #expect(query.isEmpty)
        #expect(tokens.isEmpty)
        #expect(!GlobalSearchPresentation.isActive(query: query, contextTokens: tokens))
    }

    @Test func globalSearchResultsDismissPresentation_revealsCategoryTilesDuringInteractivePop() {
        #expect(!GlobalSearchResultsDismissPresentation.revealsCategoryTiles(
            isResultsPanelVisible: true,
            dragOffset: 0
        ))
        #expect(GlobalSearchResultsDismissPresentation.revealsCategoryTiles(
            isResultsPanelVisible: true,
            dragOffset: 12
        ))
        #expect(GlobalSearchResultsDismissPresentation.revealsCategoryTiles(
            isResultsPanelVisible: false,
            dragOffset: 0
        ))
    }

    @Test func globalSearchResultsDismissPresentation_commitDismissOffset_usesContainerWidth() {
        #expect(GlobalSearchResultsDismissPresentation.commitDismissOffset(containerWidth: 390) == 390)
        #expect(GlobalSearchResultsDismissPresentation.commitDismissOffset(containerWidth: 0) == 1)
    }

    @Test func globalSearchResultsDismissPresentation_revealUsesInstantOffsetNotSlideIn() {
        #expect(GlobalSearchResultsDismissPresentation.initialResultsPanelDragOffsetOnReveal(
            containerWidth: 390
        ) == 0)
        #expect(
            GlobalSearchResultsDismissPresentation.initialResultsPanelDragOffsetOnReveal(
                containerWidth: 390
            ) != GlobalSearchResultsDismissPresentation.commitDismissOffset(containerWidth: 390)
        )
    }

    @Test func globalSearchTabLaunchPresentation_defersIndexUntilSearchOrPush() {
        #expect(!GlobalSearchTabLaunchPresentation.shouldMountSearchIndexImmediately(
            isSearchActive: false,
            pathDepth: 0
        ))
        #expect(GlobalSearchTabLaunchPresentation.shouldMountSearchIndexImmediately(
            isSearchActive: true,
            pathDepth: 0
        ))
        #expect(GlobalSearchTabLaunchPresentation.shouldMountSearchIndexImmediately(
            isSearchActive: false,
            pathDepth: 1
        ))
        #expect(!GlobalSearchTabLaunchPresentation.shouldBuildSearchCatalog(isSearchActive: false))
        #expect(GlobalSearchTabLaunchPresentation.shouldBuildSearchCatalog(isSearchActive: true))
    }

    @Test func globalSearchResultsDismissPresentation_blocksResultsInteractionWhileDismissDragActiveOrOffset() {
        #expect(GlobalSearchResultsDismissPresentation.blocksResultsInteraction(
            isDismissDragActive: true,
            dragOffset: 0
        ))
        #expect(GlobalSearchResultsDismissPresentation.blocksResultsInteraction(
            isDismissDragActive: false,
            dragOffset: 40
        ))
        #expect(GlobalSearchResultsDismissPresentation.blocksResultsInteraction(
            isDismissDragActive: false,
            dragOffset: 0.5
        ))
        #expect(!GlobalSearchResultsDismissPresentation.blocksResultsInteraction(
            isDismissDragActive: false,
            dragOffset: 0
        ))
    }

    @Test func globalSearchResultsDismissPresentation_blocksResultsRowSelectionWhilePanelIsOffset() {
        #expect(GlobalSearchResultsDismissPresentation.blocksResultsRowSelection(
            isDismissDragActive: false,
            dragOffset: 12
        ))
        #expect(!GlobalSearchResultsDismissPresentation.blocksResultsRowSelection(
            isDismissDragActive: false,
            dragOffset: 0
        ))
    }

    @Test func globalSearchResultsDismissPresentation_locksResultsListScrollWhileDismissDragActive() {
        #expect(GlobalSearchResultsDismissPresentation.locksResultsListScroll(
            isDismissDragActive: true,
            dragOffset: 0
        ))
        #expect(GlobalSearchResultsDismissPresentation.locksResultsListScroll(
            isDismissDragActive: false,
            dragOffset: 12
        ))
        #expect(!GlobalSearchResultsDismissPresentation.locksResultsListScroll(
            isDismissDragActive: false,
            dragOffset: 0
        ))
    }

    @Test func globalSearchResultsSectionHeaderPresentation_reservesBackButtonAndScrollMargin() {
        let layout = GlobalSearchPresentation.ResultsSectionHeaderPresentation.self
        #expect(layout.horizontalPadding == AppTheme.Spacing.lg)
        #expect(layout.backButtonReservedWidth() == AppTheme.Spacing.lg + layout.backButtonTapWidth)
        #expect(layout.titleFontSize == 20)
        #expect(layout.verticalPadding == AppTheme.Spacing.sm)
        #expect(layout.scrollContentTopMargin(chromeHeight: 44) == 44)
        #expect(layout.scrollContentTopMargin(chromeHeight: 0) == 0)
    }

    @Test func globalSearchResultsChromePresentation_layersScrimAboveListBelowBackRow() {
        let chrome = GlobalSearchPresentation.ResultsChromePresentation.self
        #expect(chrome.topScrimZIndex == 0.5)
        #expect(chrome.topChromeZIndex == 1.0)
        #expect(chrome.topScrimZIndex < chrome.topChromeZIndex)
        #expect(chrome.topScrimObstructionHeight(safeAreaTop: 59, chromeHeight: 44) == 103)
    }

    @Test func globalSearchResultsDismissPresentation_genericBrowseSlideOffset() {
        #expect(GlobalSearchResultsDismissPresentation.genericBrowseSlideOffset(
            dragOffset: 0,
            containerWidth: 400,
            isResultsPanelVisible: false
        ) == 0)
        #expect(GlobalSearchResultsDismissPresentation.genericBrowseSlideOffset(
            dragOffset: 0,
            containerWidth: 400,
            isResultsPanelVisible: true
        ) == -400)
        #expect(GlobalSearchResultsDismissPresentation.genericBrowseSlideOffset(
            dragOffset: 120,
            containerWidth: 400,
            isResultsPanelVisible: true
        ) == -280)
        #expect(GlobalSearchResultsDismissPresentation.genericBrowseSlideOffset(
            dragOffset: 400,
            containerWidth: 400,
            isResultsPanelVisible: true
        ) == 0)
    }

    @Test func globalSearchPushedDestinationPresentation_attachesStackSearchOnlyAtRoot() {
        #expect(GlobalSearchPushedDestinationPresentation.attachesStackSearch(pathCount: 0))
        #expect(!GlobalSearchPushedDestinationPresentation.attachesStackSearch(pathCount: 1))
        #expect(!GlobalSearchPushedDestinationPresentation.attachesStackSearch(pathCount: 2))
    }

    @Test func globalSearchPushedDestinationPresentation_dismissesNavigationSearchOnlyOnPush() {
        #expect(GlobalSearchPushedDestinationPresentation.shouldDismissNavigationSearchOnPathChange(
            previousDepth: 0,
            newDepth: 1
        ))
        #expect(!GlobalSearchPushedDestinationPresentation.shouldDismissNavigationSearchOnPathChange(
            previousDepth: 1,
            newDepth: 0
        ))
        #expect(!GlobalSearchPushedDestinationPresentation.shouldDismissNavigationSearchOnPathChange(
            previousDepth: 0,
            newDepth: 0
        ))
    }

    @Test func globalSearchPushedDestinationPresentation_dismissesSearchBeforePathAppendFromRoot() {
        #expect(GlobalSearchPushedDestinationPresentation.shouldDismissSearchBeforePathAppend(
            currentPathDepth: 0
        ))
        #expect(!GlobalSearchPushedDestinationPresentation.shouldDismissSearchBeforePathAppend(
            currentPathDepth: 1
        ))
    }

    @Test func globalSearchPushedDestinationPresentation_shouldForceResultsPanelOnPopFromDetail() {
        #expect(GlobalSearchPushedDestinationPresentation.shouldForceResultsPanelOnPopFromDetail(
            previousDepth: 1,
            newDepth: 0,
            preservedSessionIsActive: true
        ))
        #expect(!GlobalSearchPushedDestinationPresentation.shouldForceResultsPanelOnPopFromDetail(
            previousDepth: 1,
            newDepth: 0,
            preservedSessionIsActive: false
        ))
        #expect(!GlobalSearchPushedDestinationPresentation.shouldForceResultsPanelOnPopFromDetail(
            previousDepth: 0,
            newDepth: 1,
            preservedSessionIsActive: true
        ))
    }

    @Test func globalSearchPushedDestinationPresentation_shouldRestoreStackSearchOnPopToResults() {
        #expect(GlobalSearchPushedDestinationPresentation.shouldRestoreStackSearchOnPathChange(
            previousDepth: 1,
            newDepth: 0,
            isSearchActive: true
        ))
        #expect(!GlobalSearchPushedDestinationPresentation.shouldRestoreStackSearchOnPathChange(
            previousDepth: 1,
            newDepth: 0,
            isSearchActive: false
        ))
        #expect(!GlobalSearchPushedDestinationPresentation.shouldRestoreStackSearchOnPathChange(
            previousDepth: 0,
            newDepth: 1,
            isSearchActive: true
        ))
    }

    @Test func globalSearchPushedDestinationPresentation_attachesStackInteractivePopWhenPushed() {
        #expect(!GlobalSearchPushedDestinationPresentation.attachesStackInteractivePop(pathCount: 0))
        #expect(GlobalSearchPushedDestinationPresentation.attachesStackInteractivePop(pathCount: 1))
    }

    @Test func globalSearchPresentation_contextTokens_coverMainConceptsInOrder() {
        let tokens = GlobalSearchPresentation.ContextToken.allCases
        #expect(tokens.count == 8)
        #expect(tokens.map(\.title) == [
            "Dives",
            "Buddies",
            "Sites",
            "Marine life",
            "Tags",
            "Gear",
            "Trips",
            "Certifications",
        ])
        #expect(tokens.map(\.accessibilityIdentifier) == [
            "GlobalSearch.ContextToken.dives",
            "GlobalSearch.ContextToken.buddies",
            "GlobalSearch.ContextToken.sites",
            "GlobalSearch.ContextToken.marineLife",
            "GlobalSearch.ContextToken.tags",
            "GlobalSearch.ContextToken.gear",
            "GlobalSearch.ContextToken.trips",
            "GlobalSearch.ContextToken.certifications",
        ])
    }

    @Test func globalSearchPresentation_contextTokens_useFieldGuideAccentCategories() {
        let accentIDs = GlobalSearchPresentation.ContextToken.allCases.map(\.fieldGuideAccentCategoryID)
        #expect(accentIDs.count == 8)
        #expect(accentIDs.contains("fishes"))
        #expect(accentIDs.contains("marine_mammals"))
        #expect(accentIDs.contains("corals"))
        #expect(Set(accentIDs).count >= 6)
    }

    @Test func globalSearchPresentation_resultSections_followDisplayPriorityOrder() {
        let siteID = UUID()
        let catalog = GlobalSearchPresentation.Catalog(
            dives: [
                GlobalSearchPresentation.DiveIndexEntry(
                    id: UUID(),
                    title: "Blue Hole dive",
                    subtitle: nil,
                    searchHaystack: "blue hole dive"
                ),
            ],
            diveSites: [
                GlobalSearchPresentation.DiveSiteIndexEntry(
                    title: "Blue Hole",
                    subtitle: "Belize",
                    searchHaystacks: ["Blue Hole"],
                    destination: .diveSite(siteID)
                ),
            ],
            species: [],
            buddies: [
                GlobalSearchPresentation.BuddyIndexEntry(id: UUID(), displayName: "Blue Buddy"),
            ],
            tags: [
                GlobalSearchPresentation.TagIndexEntry(
                    id: UUID(),
                    name: "Blue tag",
                    appliedDiveCount: 2,
                    searchHaystack: "blue tag"
                ),
            ],
            trips: [],
            equipment: [],
            certifications: []
        )

        let results = GlobalSearchPresentation.search(catalog: catalog, query: "blue")
        #expect(results.sections.map(\.kind) == [.buddies, .diveSites, .tags, .dives])
    }

    @Test func globalSearchPresentation_contextTokenTileLayout_matchesHomeStatsGridSpacing() {
        let layout = GlobalSearchPresentation.ContextTokenPresentation.self
        #expect(layout.gridColumnCount == HomeLifetimeStatsTilesLayout.gridColumnCount)
        #expect(layout.gridSpacing == HomeLifetimeStatsTilesLayout.gridSpacing)
        #expect(layout.contentHorizontalPadding == AppTheme.Spacing.lg)
        #expect(layout.idleHeaderTitle == "Search")
        #expect(layout.idleHeaderTitleBandHeight() == layout.idleHeaderTitleTopPadding + layout.idleHeaderEstimatedHeight + layout.idleHeaderTitleBottomPadding)
        #expect(layout.idleHeaderTitleTopPadding == AppTheme.Layout.appHeaderTopPadding)
        #expect(layout.idleHeaderTitleBottomPadding == AppTheme.Layout.appHeaderBottomPadding)
        #expect(layout.idleHeaderEstimatedHeight == 34)
        #expect(layout.headerToGridSpacing == AppTheme.Spacing.sm)
        #expect(layout.tabSearchChromeHeight == 56)
        #expect(layout.keyboardOpenGridExtraBottomSpacing == AppTheme.Spacing.sm)
        #expect(layout.resultsListTopInset(safeAreaTop: 59, chromeHeight: 44) == 103)
        #expect(layout.categoryGridBottomInset(resolvedSafeAreaBottom: 34) == 34 + layout.tabSearchChromeHeight)
        #expect(
            layout.categoryGridBottomInset(
                resolvedSafeAreaBottom: 34,
                keyboardOverlapHeight: 320,
                isKeyboardVisible: true
            ) == 320 + layout.tabSearchChromeHeight + layout.keyboardOpenGridExtraBottomSpacing
        )
        #expect(
            layout.gridRowCount(
                tokenCount: GlobalSearchPresentation.ContextToken.allCases.count,
                columnCount: layout.gridColumnCount
            ) == 4
        )
    }

    @Test func globalSearchResultListRowLayout_usesFullWidthHairlineAndCompactArtwork() {
        let layout = GlobalSearchResultListRowLayout.self
        #expect(layout.artworkSize == 30)
        #expect(layout.rowVerticalPadding == 10)
        #expect(layout.separatorHeight == 0.5)
        #expect(layout.compactScale == 0.6)
    }

    // MARK: - Duplicate dive matching

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
    func uddfImport_secondImportOfSameFile_blockedAsDuplicate() async throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "test-uddf-dup", displayName: "Dup Test")
        context.insert(owner)
        try context.save()
        let data = Data(UddfTestXML.oneDive.utf8)
        let first = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
        #expect(first.didSucceed)
        let second = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
        #expect(!second.didSucceed)
        #expect(second.userMessage.contains("already in your log") || second.userMessage.contains("duplicate"))
        let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
        #expect(fetched.count == 1)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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

    @Test func defaultTankSize_specifications() {
        #expect(DefaultTankSize.al80.ratedVolumeCubicFeet == 80)
        #expect(DefaultTankSize.al80.materialLabel == "aluminum")
        #expect(DefaultTankSize.al80.settingsPickerTitle == "AL80")
        #expect(DefaultTankSize.al80.settingsPickerMaterialLabel == "Aluminum")
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
            source: .manual,
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

    @Test func appUserSettings_defaultTankSize_fallsBackToAL80() {
        let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DefaultTankFallback")!
        defaults.removePersistentDomain(forName: "GoDiveMVPTests.DefaultTankFallback")
        defaults.set("INVALID", forKey: AppUserSettings.defaultTankSizeKey)
        let spec = DiveActivityTankDefaults.resolvedSpecification(userDefaults: defaults)
        #expect(spec.size == .al80)
    }

    @Test func appUserSettings_defaultDiverWeights_storeAndReadKilograms() {
        let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DefaultDiverWeights")!
        defaults.removePersistentDomain(forName: "GoDiveMVPTests.DefaultDiverWeights")
        #expect(AppUserSettings.defaultSaltwaterWeightKilograms(userDefaults: defaults) == nil)
        AppUserSettings.setDefaultSaltwaterWeightKilograms(5.0, userDefaults: defaults)
        AppUserSettings.setDefaultFreshwaterWeightKilograms(4.5, userDefaults: defaults)
        #expect(AppUserSettings.defaultSaltwaterWeightKilograms(userDefaults: defaults) == 5.0)
        #expect(AppUserSettings.defaultFreshwaterWeightKilograms(userDefaults: defaults) == 4.5)
        AppUserSettings.setDefaultSaltwaterWeightKilograms(nil, userDefaults: defaults)
        #expect(AppUserSettings.defaultSaltwaterWeightKilograms(userDefaults: defaults) == nil)
    }

    @Test func diveActivityFieldValueParsing_diverWeight_roundTripImperialAndMetric() {
        #expect(
            DiveActivityFieldValueParsing.parseDiverWeightKilograms("12.0", displayUnits: .imperial)
                == 12.0 / 2.2046226218
        )
        #expect(
            DiveActivityFieldValueParsing.formatDiverWeightInput(kilograms: 5.0, displayUnits: .metric) == "5.0"
        )
        #expect(
            DiveQuantityFormatting.diverWeight(kilograms: 5.0, system: .metric) == "5.0 kg"
        )
        #expect(
            DiveQuantityFormatting.diverWeight(kilograms: nil, system: .imperial) == "—"
        )
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

    @Test func diveSite_resolvedWaterType_defaultsToSaltwaterWhenUnset() {
        let site = DiveSite(siteName: "Reef")
        #expect(site.waterType == nil)
        #expect(site.resolvedWaterType == .saltwater)
        site.waterType = .freshwater
        #expect(site.resolvedWaterType == .freshwater)
    }

    @Test func diveActivityDiverWeightDefaults_inheritsFromLinkedCatalogSite() {
        let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DiverWeightSiteInherit")!
        defaults.removePersistentDomain(forName: "GoDiveMVPTests.DiverWeightSiteInherit")
        AppUserSettings.setDefaultSaltwaterWeightKilograms(6.0, userDefaults: defaults)
        AppUserSettings.setDefaultFreshwaterWeightKilograms(4.0, userDefaults: defaults)

        let cenote = DiveSite(siteName: "Cenote Azul", waterType: .freshwater)
        let activity = DiveActivity(source: .garminMK3, startTime: .now, durationMinutes: 30, maxDepthMeters: 18)
        activity.diveSite = cenote
        activity.diveSiteID = cenote.id

        DiveActivityDiverWeightDefaults.applyInheritedDefaults(to: activity, userDefaults: defaults)
        #expect(activity.diveWaterType == .freshwater)
        #expect(activity.diverWeightKilograms == 4.0)
    }

    @Test func diveActivityEditableCatalog_includesWeightsSectionOnTankTab() {
        let sections = DiveActivityEditableCatalog.sections(for: .tank, detent: .large)
        #expect(sections.contains { $0.id == "weights" })
        let weights = sections.first { $0.id == "weights" }
        #expect(weights?.fieldIDs == [.diveWaterType, .diverWeightKilograms])
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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

    @Test @MainActor
    func diveActivityDiveNumbering_renumberAllChronologically_skipsExplicitNone() throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddy.self,
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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

    @Test func logbookTripGroupAccentPalette_avoidsLightPastelHues() {
        for rgb in LogbookTripGroupAccentPalette.palette {
            let maxChannel = max(rgb.red, rgb.green, rgb.blue)
            #expect(maxChannel <= 0.90)
            let isLightBlue = rgb.blue >= 0.62 && rgb.blue >= rgb.red && rgb.blue >= rgb.green
            #expect(!isLightBlue)
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

    @Test func diveActivityPostDeleteRenumbering_partialRenumberOnBackgroundContext() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddy.self,
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

    @Test @MainActor
    func diveSiteCatalogMaintenance_deleteSiteIfOrphaned_removesOnlyUnlinkedSite() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let orphan = DiveSite(siteName: "Orphan", latCoords: 12, longCoords: -68)
        let linked = DiveSite(siteName: "Linked", latCoords: 12.1, longCoords: -68.1)
        context.insert(orphan)
        context.insert(linked)
        try context.save()

        try DiveSiteCatalogMaintenance.deleteSiteIfOrphaned(siteID: orphan.id, modelContext: context)

        let sites = try context.fetch(FetchDescriptor<DiveSite>())
        #expect(sites.count == 1)
        #expect(sites.first?.id == linked.id)
    }

    @Test func diveBackgroundRenumberingWorker_partialRenumberOnlyTouchesTail() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddy.self,
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
            let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
            let b = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
            let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
            context.insert(a)
            context.insert(b)
            context.insert(c)
            try context.save()
            return b.id
        }

        try await DiveBackgroundRenumberingWorker(modelContainer: container)
            .renumberDivesNewerThanDeleted(deletedStartTime: t1, deletedId: deletedId)

        let numbers = try await MainActor.run { () throws -> [Int?] in
            let context = ModelContext(container)
            let all = try context.fetch(FetchDescriptor<DiveActivity>())
            let sorted = all.sorted { $0.startTime < $1.startTime }
            return sorted.map(\.diveNumber)
        }
        #expect(numbers == [1, 2, 2])
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

    @Test @MainActor
    func diveSiteCatalogMaintenance_deletesSiteWithNoLinkedDives() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let site = DiveSite(siteName: "Solo Reef", latCoords: 12, longCoords: -68)
        context.insert(site)
        try context.save()

        try DiveSiteCatalogMaintenance.deleteSitesWithNoLinkedDives(modelContext: context)

        #expect(try context.fetch(FetchDescriptor<DiveSite>()).isEmpty)
    }

    @Test @MainActor
    func diveSiteCatalogMaintenance_keepsSiteWhenAnotherDiveRemains() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let site = DiveSite(siteName: "Shared", latCoords: 12, longCoords: -68)
        let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 30, maxDepthMeters: 20)
        context.insert(site)
        context.insert(dive)
        DiveActivitySiteAssociation.link(dive, to: site)
        try context.save()

        try DiveSiteCatalogMaintenance.deleteSitesWithNoLinkedDives(modelContext: context)

        let sites = try context.fetch(FetchDescriptor<DiveSite>())
        #expect(sites.count == 1)
        #expect(sites.first?.id == site.id)
    }

    @Test func diveBackgroundDeletionWorker_cascadeDelete_removesLargeProfileAndDive() async throws {
        let schema = Schema([
            DiveActivity.self,
            DiveBuddy.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
                diveSiteID: site.id,
                diveSite: site
            )
            activity.owner = owner
            activity.ownerProfileID = owner.id
            site.diveActivities.append(activity)

            let tag = ActivityTag(name: "Night", normalizedName: "night", ownerProfileID: owner.id)
            activity.activityTags.append(tag)
            tag.dives.append(activity)

            let photo = DiveMediaPhoto(sortOrder: 0, mediaKind: .image, dive: activity)
            activity.mediaPhotos.append(photo)

            let sighting = SightingInstance(
                marineLifeUUID: species.uuid,
                sightingDateTime: activity.startTime,
                marineLife: species,
                diveActivity: activity,
                diveSite: site,
                mediaPhoto: photo
            )
            activity.marineLifeSightings.append(sighting)
            species.sightingInstances.append(sighting)

            let record = MarineLifeUserRecord(
                owner: owner,
                marineLife: species,
                isSighted: true,
                activitiesSightedOn: [activity.id],
                sitesSightedOn: [site.id],
                userTaggedMedia: [DiveActivityDeletionMarineLifeCleanup.userTaggedMediaLink(for: photo.id)]
            )
            record.link(to: species, owner: owner)

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
            marineLife: species,
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
            diveSiteID: site.id,
            diveSite: site
        )
        activity.owner = owner
        activity.ownerProfileID = owner.id
        site.diveActivities.append(activity)
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
        #expect(site.diveActivities.isEmpty)
        #expect(activity.activityTags.isEmpty)
        #expect(activity.diveSite == nil)
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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
            DiveBuddy.self,
            DiveBuddyTag.self,
            DiveProfilePoint.self,
            DiveSite.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
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

    @Test func appStatusBarEdgeScrim_brandHeaderFeatherIsTallerThanListChrome() {
        let brand = AppStatusBarEdgeScrimMetrics.brandHeaderFeatherHeight
        let list = AppStatusBarEdgeScrimMetrics.listChromeFeatherHeight
        #expect(brand == 40)
        #expect(list == 22)
        #expect(brand > list)
        #expect(brand / list > 1.3)
        #expect(AppStatusBarEdgeScrimMetrics.brandHeaderMaxScrimOpacity == 0.60)
    }

    @Test func exploreMapChromeScrim_usesDeepOceanBaseInLightMode() {
        #expect(AppTheme.Colors.mapChromeScrimBase == AppTheme.Colors.surfaceGradientBottom)
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

    @Test func diveActivityMediaAttachWindow_shouldAttachAsset_usesCreationDateNotExifWallClock() throws {
        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        var startWall = DateComponents()
        startWall.year = 2026
        startWall.month = 4
        startWall.day = 30
        startWall.hour = 14
        startWall.minute = 7
        startWall.second = 53
        let startTime = try #require(localCal.date(from: startWall))

        let activity = DiveActivity(
            source: .macDive,
            startTime: startTime,
            timeZoneOffsetSeconds: tz.secondsFromGMT(for: startTime),
            durationMinutes: 63,
            maxDepthMeters: 15.88,
            bottomTimeSeconds: 3_811
        )
        let window = DiveActivityMediaAttachWindow.window(for: activity)

        // GoPro photo taken 14:30 local Bonaire → correct absolute creationDate is in-window.
        var captureWall = startWall
        captureWall.minute = 30
        let creationDate = try #require(localCal.date(from: captureWall))
        #expect(window.shouldAttachAsset(creationDate: creationDate))

        // The same EXIF wall clock mis-parsed as UTC (14:30Z) is 4h early and would be out of window —
        // but it must not influence the decision.
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let misZonedExif = try #require(utcCal.date(from: captureWall))
        #expect(!window.contains(misZonedExif))
        #expect(window.shouldAttachAsset(creationDate: creationDate))

        #expect(!window.shouldAttachAsset(creationDate: nil))
    }

    @Test func diveActivityMediaAttachWindow_shouldAttachAsset_recoversGoProLocalAsUtc() throws {
        // Bonaire (UTC-4) Garmin dive at 14:08:08 local (18:08:08 UTC), ~64 min.
        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        var startWall = DateComponents()
        startWall.year = 2026
        startWall.month = 5
        startWall.day = 1
        startWall.hour = 14
        startWall.minute = 8
        startWall.second = 8
        let startTime = try #require(localCal.date(from: startWall))
        let offset = tz.secondsFromGMT(for: startTime)

        let activity = DiveActivity(
            source: .macDive,
            startTime: startTime,
            timeZoneOffsetSeconds: offset,
            durationMinutes: 64,
            maxDepthMeters: 16.26,
            bottomTimeSeconds: 3_861
        )
        let window = DiveActivityMediaAttachWindow.window(for: activity)

        // GoPro wrote local wall clock (14:55:01) into a field read as UTC → creationDate is 14:55:01 UTC,
        // four hours before the true-UTC dive window.
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var goProWall = DateComponents()
        goProWall.year = 2026
        goProWall.month = 5
        goProWall.day = 1
        goProWall.hour = 14
        goProWall.minute = 55
        goProWall.second = 1
        let goProCreation = try #require(utcCal.date(from: goProWall))

        // Direct absolute test fails; removing the dive-local offset recovers the real instant in-window.
        #expect(!window.shouldAttachAsset(creationDate: goProCreation))
        #expect(window.shouldAttachAsset(creationDate: goProCreation, diveLocalOffsetSeconds: offset))

        // A correctly-zoned asset (18:55:01 UTC) still matches directly with the offset hint present.
        let correctlyZoned = goProCreation.addingTimeInterval(TimeInterval(-offset))
        #expect(window.shouldAttachAsset(creationDate: correctlyZoned, diveLocalOffsetSeconds: offset))
    }

    @Test func diveActivityMediaAttachWindow_resolvedTimeZone_infersFromEntryCoordinate() throws {
        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        let instant = Date(timeIntervalSince1970: 1_800_000_000)
        let activity = DiveActivity(
            source: .macDive,
            startTime: instant,
            durationMinutes: 60,
            maxDepthMeters: 12,
            entryCoordinate: DiveCoordinate(latitude: 12.03342, longitude: -68.26169)
        )
        let resolved = DiveActivityMediaAttachWindow.resolvedTimeZone(for: activity, at: instant)
        #expect(resolved.secondsFromGMT(for: instant) == tz.secondsFromGMT(for: instant))
    }

    @Test func diveActivityMediaAttachWindow_garminBonaire_matchesLocalCaptureNotUtcWallLocal() throws {
        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        var diveStartWall = DateComponents()
        diveStartWall.year = 2026
        diveStartWall.month = 4
        diveStartWall.day = 30
        diveStartWall.hour = 14
        diveStartWall.minute = 7
        diveStartWall.second = 53
        let startTime = try #require(localCal.date(from: diveStartWall))

        let activity = DiveActivity(
            source: .macDive,
            startTime: startTime,
            timeZoneOffsetSeconds: tz.secondsFromGMT(for: startTime),
            durationMinutes: 63,
            maxDepthMeters: 15.88,
            bottomTimeSeconds: 3_811,
            locationName: "Bonaire",
            entryCoordinate: DiveCoordinate(latitude: 12.03342, longitude: -68.26169)
        )
        let window = DiveActivityMediaAttachWindow.window(for: activity, paddingSeconds: 0)

        var duringWall = diveStartWall
        duringWall.minute = 30
        let duringDiveLocal = try #require(localCal.date(from: duringWall))
        #expect(window.contains(duringDiveLocal, for: activity))

        var utcWallAsLocal = diveStartWall
        utcWallAsLocal.hour = 18
        utcWallAsLocal.minute = 30
        let wrongLocalClock = try #require(localCal.date(from: utcWallAsLocal))
        #expect(!window.contains(wrongLocalClock, for: activity))
    }

    @Test func diveActivityMediaAttachWindow_photoLibraryFetchWindow_spansLocalCalendarDay() throws {
        let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        var wall = DateComponents()
        wall.year = 2026
        wall.month = 4
        wall.day = 30
        wall.hour = 23
        wall.minute = 30
        let startTime = try #require(localCal.date(from: wall))

        let activity = DiveActivity(
            source: .macDive,
            startTime: startTime,
            timeZoneOffsetSeconds: tz.secondsFromGMT(for: startTime),
            durationMinutes: 45,
            maxDepthMeters: 10
        )
        let precise = DiveActivityMediaAttachWindow.window(for: activity)
        let fetch = DiveActivityMediaAttachWindow.photoLibraryFetchWindow(for: activity)
        #expect(fetch.inclusiveStart <= precise.inclusiveStart)
        #expect(fetch.inclusiveEnd >= precise.inclusiveEnd)
        // Covers the dive-local calendar day, padded one day earlier so offset-recovery (camera
        // local-as-UTC) assets near local midnight are still fetched.
        let startOfDay = localCal.startOfDay(for: precise.inclusiveStart)
        let expectedStart = try #require(localCal.date(byAdding: .day, value: -1, to: startOfDay))
        #expect(fetch.inclusiveStart == expectedStart)
    }

    @Test func diveActivityMediaAttachWindow_usesDiveLocalCalendarWhenOffsetSet() throws {
        let tz = try #require(TimeZone(identifier: "America/Cancun"))
        let offset = tz.secondsFromGMT(for: Date(timeIntervalSince1970: 1_627_000_000))
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = tz
        var wall = DateComponents()
        wall.year = 2021
        wall.month = 7
        wall.day = 18
        wall.hour = 14
        wall.minute = 53
        wall.second = 45
        let start = try #require(localCal.date(from: wall))

        let activity = DiveActivity(
            source: .macDive,
            startTime: start,
            timeZoneOffsetSeconds: offset,
            durationMinutes: 60,
            maxDepthMeters: 12,
            bottomTimeSeconds: 3_600
        )
        let window = DiveActivityMediaAttachWindow.window(for: activity, paddingSeconds: 0)

        var duringWall = wall
        duringWall.minute = 55
        let duringDive = try #require(localCal.date(from: duringWall))
        #expect(window.contains(duringDive))

        var afterWall = wall
        afterWall.hour = 16
        afterWall.minute = 0
        let afterDive = try #require(localCal.date(from: afterWall))
        #expect(!window.contains(afterDive))
    }

    @Test func diveActivityMediaAttachWindow_resolvedTimeZone_prefersLinkedSiteIdentifier() throws {
        let site = DiveSite(
            siteName: "Reef",
            timeZoneIdentifier: "America/Cancun",
            timeZoneOffsetSeconds: -5 * 3600
        )
        let activity = DiveActivity(
            source: .macDive,
            startTime: Date(),
            timeZoneOffsetSeconds: -4 * 3600,
            durationMinutes: 60,
            maxDepthMeters: 10
        )
        activity.diveSite = site
        let tz = DiveActivityMediaAttachWindow.resolvedTimeZone(for: activity)
        #expect(tz.identifier == "America/Cancun")
    }

    @Test func diveActivityMediaAttachWindow_prefersBottomTimeOverSessionDuration() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let activity = DiveActivity(
            source: .garminMK3,
            startTime: start,
            durationMinutes: 60,
            maxDepthMeters: 18,
            bottomTimeSeconds: 2_400
        )
        let window = DiveActivityMediaAttachWindow.window(for: activity, paddingSeconds: 0)
        #expect(window.inclusiveStart == start)
        #expect(window.inclusiveEnd == start.addingTimeInterval(2_400))
    }

    @Test func diveActivityMediaAttachWindow_containsCaptureDateWithPadding() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let activity = DiveActivity(
            source: .garminMK3,
            startTime: start,
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        let window = DiveActivityMediaAttachWindow.window(for: activity)
        let duringDive = start.addingTimeInterval(600)
        let justBefore = start.addingTimeInterval(-DiveActivityMediaAttachWindow.defaultPaddingSeconds + 1)
        let tooEarly = start.addingTimeInterval(-DiveActivityMediaAttachWindow.defaultPaddingSeconds - 1)
        #expect(window.contains(duringDive))
        #expect(window.contains(justBefore))
        #expect(!window.contains(tooEarly))
    }

    @Test func diveActivityMediaAttachWindow_bestMatchingActivity_prefersNarrowestWindow() {
        let capture = Date(timeIntervalSince1970: 3_000_600)
        let narrow = DiveActivity(
            source: .garminMK3,
            startTime: Date(timeIntervalSince1970: 3_000_000),
            durationMinutes: 20,
            maxDepthMeters: 10
        )
        let wide = DiveActivity(
            source: .garminMK3,
            startTime: Date(timeIntervalSince1970: 2_999_000),
            durationMinutes: 120,
            maxDepthMeters: 20
        )
        let match = DiveActivityMediaAttachWindow.bestMatchingActivity(for: capture, among: [wide, narrow])
        #expect(match?.id == narrow.id)
    }

    @Test func diveActivityMediaAttachWindow_unknownDurationUsesFallback() {
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 4_000_000),
            durationMinutes: 0,
            maxDepthMeters: 0
        )
        #expect(
            DiveActivityMediaAttachWindow.diveDurationSeconds(for: activity)
                == DiveActivityMediaAttachWindow.defaultUnknownDiveDurationSeconds
        )
    }

    @Test func appUserSettings_autoUploadMediaKey_isDefined() {
        #expect(!AppUserSettings.autoUploadMediaToActivitiesKey.isEmpty)
    }

    @Test func diveLibraryMediaAutoAttach_shouldRequestPhotoAccess_onlyWhenEnabledAndUnresolved() {
        #expect(
            DiveLibraryMediaAutoAttach.shouldRequestPhotoAccessForAutoUpload(
                autoUploadEnabled: true,
                authorizationResolved: false
            )
        )
        #expect(
            !DiveLibraryMediaAutoAttach.shouldRequestPhotoAccessForAutoUpload(
                autoUploadEnabled: true,
                authorizationResolved: true
            )
        )
        #expect(
            !DiveLibraryMediaAutoAttach.shouldRequestPhotoAccessForAutoUpload(
                autoUploadEnabled: false,
                authorizationResolved: false
            )
        )
    }

    @Test func appUserSettings_registerDefaultValues_defaultsTogglesOnWhenUnset() throws {
        let suiteName = "GoDiveSettingsDefaults-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AppUserSettings.registerDefaultValues(in: defaults)

        #expect(defaults.bool(forKey: AppUserSettings.automaticallyRenumberDivesKey))
        #expect(defaults.bool(forKey: AppUserSettings.useImperialDisplayUnitsKey))
        #expect(defaults.bool(forKey: AppUserSettings.autoUploadMediaToActivitiesKey))
    }

    @Test func appUserSettings_registerDefaultValues_doesNotOverrideSavedOffChoice() throws {
        let suiteName = "GoDiveSettingsDefaults-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: AppUserSettings.useImperialDisplayUnitsKey)
        AppUserSettings.registerDefaultValues(in: defaults)

        #expect(!defaults.bool(forKey: AppUserSettings.useImperialDisplayUnitsKey))
    }

    @Test func diveLibraryMediaAutoAttachPresentation_finishedMessage_whenDenied() {
        let outcome = DiveLibraryMediaAutoAttach.Outcome(
            attachedCount: 0,
            skippedAlreadyLinked: 0,
            skippedNoCaptureDate: 0,
            authorizationDenied: true
        )
        #expect(
            DiveLibraryMediaAutoAttachPresentation.finishedMessage(for: outcome)
                .contains("Photos access")
        )
    }

    @Test func diveLibraryMediaAutoAttachPresentation_progressFraction_clamps() {
        #expect(DiveLibraryMediaAutoAttachPresentation.progressFraction(completed: 2, total: 4) == 0.5)
        #expect(DiveLibraryMediaAutoAttachPresentation.progressFraction(completed: 0, total: 0) == 0)
    }

    @Test func diveLibraryMediaAutoAttachPresentation_stageCheckingDive_formatsIndex() {
        #expect(
            DiveLibraryMediaAutoAttachPresentation.stageCheckingDive(diveIndex: 3, diveCount: 10)
                == "Checking dive 3 of 10…"
        )
    }
    #endif
}

private func logbookRowsSortedForDisplay(_ rows: [DiveLogbookRowDisplayData]) -> [DiveLogbookRowDisplayData] {
    rows.sorted {
        if $0.startTime != $1.startTime { return $0.startTime > $1.startTime }
        return $0.id.uuidString < $1.id.uuidString
    }
}

private func logbookSnapshotSeed(
    id: UUID = UUID(),
    resolvedSiteNameLowercased: String?,
    activityTagNames: [String] = [],
    buddyDisplayNames: [String] = [],
    linkedTripID: UUID? = nil,
    startTime: Date = Date(timeIntervalSince1970: 0)
) -> LogbookActivitySnapshotSeed {
    LogbookActivitySnapshotSeed(
        id: id,
        sourceDiveId: nil,
        startTime: startTime,
        maxDepthMeters: 10,
        durationMinutes: 30,
        bottomTimeSeconds: nil,
        diveNumber: 1,
        diveNumberExplicitlyNone: false,
        displayName: resolvedSiteNameLowercased ?? "New Dive",
        formattedStartDateOnly: "Jan 1, 1970",
        resolvedSiteNameLowercased: resolvedSiteNameLowercased,
        activityTagNames: activityTagNames,
        buddyDisplayNames: buddyDisplayNames,
        previewMediaPhotoID: nil,
        linkedTripID: linkedTripID
    )
}

@MainActor
private struct FixedGeocodingTimeZoneResolver: GeocodingTimeZoneResolving {
    let timeZone: TimeZone

    func timeZone(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) async -> TimeZone? {
        timeZone
    }

    func timeZone(forLocationQuery query: String) async -> TimeZone? {
        timeZone
    }
}

@MainActor
private final class FailingGeocodingTimeZoneResolver: GeocodingTimeZoneResolving {
    private(set) var coordinateLookupCount = 0

    func timeZone(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) async -> TimeZone? {
        coordinateLookupCount += 1
        return nil
    }

    func timeZone(forLocationQuery query: String) async -> TimeZone? {
        return nil
    }
}
