//
//  HomePresentationTests.swift
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


struct HomePresentationTests {
        @Test @MainActor func homeOverviewPushedLayoutPresentation_pushedPageSeamInputs_usesDefaultBandWithoutStoreScan() {
            HomeOverviewLayoutAnchor.resetForTesting()
            defer { HomeOverviewLayoutAnchor.resetForTesting() }
            let inputs = HomeOverviewPushedLayoutPresentation.pushedPageSeamInputs()
            let expected = HomeTabRootLayoutPresentation.defaultLifetimeGridSeamInputs
            #expect(inputs.statsPanelContentHeight == expected.statsPanelContentHeight)
            #expect(inputs.showsBuddyLeaderboard == expected.showsBuddyLeaderboard)
            #expect(inputs.showsBuddyLeaderboard)
        }

        @Test func celebrationShellPrewarmPresentation_bulkImportUsesLongerDelay() {
            #expect(
                CelebrationShellPrewarmPresentation.postBulkImportDelayNanoseconds
                    > CelebrationShellPrewarmPresentation.defaultDelayNanoseconds
            )
            #expect(CelebrationShellPrewarmPresentation.postBulkImportDelayNanoseconds == 1_500_000_000)
        }

        @Test func homeOverviewRebuildPresentation_skipsIncidentalRebuildUntilInitialBuildDuringPrewarm() {
            #expect(
                HomeOverviewRebuildPresentation.shouldSkipSchedule(
                    isCelebrationShellPrewarmActive: true,
                    hasPerformedInitialHomeBuild: false,
                    source: .incidental
                )
            )
            #expect(
                !HomeOverviewRebuildPresentation.shouldSkipSchedule(
                    isCelebrationShellPrewarmActive: true,
                    hasPerformedInitialHomeBuild: false,
                    source: .initialRootAppear
                )
            )
            #expect(
                !HomeOverviewRebuildPresentation.shouldSkipSchedule(
                    isCelebrationShellPrewarmActive: true,
                    hasPerformedInitialHomeBuild: true,
                    source: .incidental
                )
            )
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

            // Seed must reshuffle when the day or owner changes (FNV-1a over owner + year + day-of-year).
            let nextDay = day.addingTimeInterval(86_400)
            #expect(HomeMediaHighlightPresentation.dailySeed(ownerProfileID: ownerID, referenceDate: nextDay) != seedA)
            let otherOwner = UUID(uuidString: "B1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
            #expect(HomeMediaHighlightPresentation.dailySeed(ownerProfileID: otherOwner, referenceDate: day) != seedA)

            // Launch shuffle salts the daily seed so cold launches pick a new set within the same day.
            let launchSeed = HomeMediaHighlightPresentation.carouselShuffleSeed(
                ownerProfileID: ownerID,
                referenceDate: day
            )
            #expect(launchSeed == seedA &+ HomeMediaHighlightPresentation.processLaunchNonceForTesting)
            #expect(launchSeed != seedA)

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

        @Test @MainActor func homeMediaHighlightSessionCache_evictsOldestImageBeyondCarouselLimit() {
            #if canImport(UIKit)
            HomeMediaHighlightSessionCache.shared.clear()
            defer { HomeMediaHighlightSessionCache.shared.clear() }

            let image = solidTestImage(edge: 480)
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

            let image = solidTestImage(edge: 480)
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

        @Test func homeMediaHighlightWarmupPresentation_softJPEGDoesNotSatisfyPreviewEdge() {
            #expect(
                HomeMediaHighlightWarmupPresentation.sessionCachedImageSatisfiesRequestedEdge(
                    pixelWidth: DiveMediaPreviewPersistence.storedPreviewEdge,
                    pixelHeight: DiveMediaPreviewPersistence.storedPreviewEdge,
                    requestedEdge: DiveMediaPreviewPersistence.storedPreviewEdge
                )
            )
            #expect(
                !HomeMediaHighlightWarmupPresentation.sessionCachedImageSatisfiesRequestedEdge(
                    pixelWidth: DiveMediaPreviewPersistence.storedPreviewEdge,
                    pixelHeight: DiveMediaPreviewPersistence.storedPreviewEdge,
                    requestedEdge: HomeMediaHighlightWarmupPresentation.previewImageEdge
                )
            )
            #expect(
                HomeMediaHighlightWarmupPresentation.sessionCachedImageSatisfiesRequestedEdge(
                    pixelWidth: HomeMediaHighlightWarmupPresentation.previewImageEdge,
                    pixelHeight: HomeMediaHighlightWarmupPresentation.previewImageEdge,
                    requestedEdge: HomeMediaHighlightWarmupPresentation.previewImageEdge
                )
            )
            #expect(
                HomeMediaHighlightWarmupPresentation.storedPreviewSessionEdge
                    == DiveMediaPreviewPersistence.storedPreviewEdge
            )
            #expect(
                HomeMediaHighlightWarmupPresentation.storedPreviewSessionEdge
                    < HomeMediaHighlightWarmupPresentation.previewImageEdge
            )
        }

        @Test @MainActor func homeMediaHighlightSessionCache_rejectsSoftFrameUnderPreviewEdgeKey() {
            #if canImport(UIKit)
            HomeMediaHighlightSessionCache.shared.clear()
            defer { HomeMediaHighlightSessionCache.shared.clear() }

            let soft = solidTestImage(edge: DiveMediaPreviewPersistence.storedPreviewEdge)
            let preview = solidTestImage(edge: HomeMediaHighlightWarmupPresentation.previewImageEdge)
            let id = "soft-vs-preview"

            // Legacy bug: soft JPEG stored under the 480 key must not short-circuit preview/hero loads.
            HomeMediaHighlightSessionCache.shared.storeImage(
                soft,
                localIdentifier: id,
                edge: HomeMediaHighlightWarmupPresentation.previewImageEdge
            )
            #expect(
                HomeMediaHighlightSessionCache.shared.image(
                    for: id,
                    edge: HomeMediaHighlightWarmupPresentation.previewImageEdge
                ) == nil
            )

            HomeMediaHighlightSessionCache.shared.storeImage(
                soft,
                localIdentifier: id,
                edge: HomeMediaHighlightWarmupPresentation.storedPreviewSessionEdge
            )
            #expect(
                HomeMediaHighlightSessionCache.shared.image(
                    for: id,
                    edge: HomeMediaHighlightWarmupPresentation.storedPreviewSessionEdge
                ) != nil
            )
            #expect(
                HomeMediaHighlightSessionCache.shared.image(
                    for: id,
                    edge: HomeMediaHighlightWarmupPresentation.previewImageEdge
                ) == nil
            )

            HomeMediaHighlightSessionCache.shared.storeImage(
                preview,
                localIdentifier: id,
                edge: HomeMediaHighlightWarmupPresentation.previewImageEdge
            )
            #expect(
                HomeMediaHighlightSessionCache.shared.image(
                    for: id,
                    edge: HomeMediaHighlightWarmupPresentation.previewImageEdge
                ) != nil
            )
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
            #expect(HomeMediaCarouselEmptyPresentation.headline(for: .noMediaYet) == "Add Media to your Dives")
            #expect(HomeMediaCarouselEmptyPresentation.message(for: .noMediaYet).contains("Logbook"))
            #expect(HomeMediaCarouselEmptyPresentation.headline(for: .noLoggedActivities) == "Log Your First Dive")
            #expect(HomeMediaCarouselEmptyPresentation.message(for: .noLoggedActivities).contains("Logbook"))
            #expect(HomeMediaCarouselEmptyPresentation.frameOffsetAmplitude(index: 2) > HomeMediaCarouselEmptyPresentation.frameOffsetAmplitude(index: 0))
            #expect(HomeMediaCarouselEmptyPresentation.contentDownshift == 48)
            #expect(HomeMediaCarouselEmptyPresentation.ctaBottomLift == 96)
            #expect(
                HomeMediaCarouselEmptyPresentation.ctaBottomInset
                    == HomeOverviewLayout.panelOverlap - AppTheme.Spacing.md
                    + HomeMediaCarouselEmptyPresentation.ctaBottomLift
            )
        }

        @Test func homeMediaCarouselEmptyPlaceholder_usesSameSlideHeightAsPopulatedCarousel() {
            let width: CGFloat = 393
            let topInset: CGFloat = 59
            let heroBand = HomeMediaCarouselLayout.heroHeight(width: width, topSafeAreaInset: topInset)
            let expected = HomeMediaCarouselLayout.carouselContentHeight(
                heroBandHeight: heroBand,
                topSafeAreaInset: topInset,
                appliesOwnTopSafeAreaBleed: false
            )
            #expect(expected > heroBand)
            #expect(
                HomeMediaCarouselLayout.carouselContentHeight(
                    heroBandHeight: heroBand,
                    topSafeAreaInset: topInset,
                    appliesOwnTopSafeAreaBleed: false
                ) == expected
            )
        }

        @Test @MainActor
        func homeLifetimeStatsPresentation_highlightStatTileDescriptors_alwaysReturnsFourTiles() {
            let emptyStats = HomeLifetimeStatsPresentation.build(dives: [], sightings: [])
            let tiles = HomeLifetimeStatsPresentation.highlightStatTileDescriptors(
                stats: emptyStats,
                unitSystem: .metric
            )
            #expect(tiles.count == HomeLifetimeStatsTilesLayout.highlightStatTileCount)
            #expect(tiles.allSatisfy { $0.value == HomeLifetimeStatsPresentation.emptyStatValue })
            #expect(tiles.allSatisfy { $0.leaderboardKind == nil })
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

        @Test func homeMediaCarouselPresentation_stableImageLoadWidth_bucketsAgainstGeometryJitter() {
            #expect(HomeMediaCarouselPresentation.imageLoadWidthBucketPoints == 8)
            #expect(HomeMediaCarouselPresentation.stableImageLoadWidth(390) == 392)
            #expect(HomeMediaCarouselPresentation.stableImageLoadWidth(391) == 392)
            #expect(HomeMediaCarouselPresentation.stableImageLoadWidthKey(390)
                == HomeMediaCarouselPresentation.stableImageLoadWidthKey(391))
            #expect(HomeMediaCarouselPresentation.stableImageLoadWidthKey(388)
                != HomeMediaCarouselPresentation.stableImageLoadWidthKey(396))
            #expect(HomeMediaCarouselPresentation.stableImageLoadWidth(0) == 0)
        }

        @Test func homeReturnNavigationPresentation_skipsRedundantRebuildWhenAggregateWarm() {
            #expect(
                HomeReturnNavigationPresentation.shouldSkipFullRebuildOnReturn(
                    hasPerformedInitialBuild: true,
                    hasWarmAggregate: true
                )
            )
            #expect(
                !HomeReturnNavigationPresentation.shouldSkipFullRebuildOnReturn(
                    hasPerformedInitialBuild: false,
                    hasWarmAggregate: true
                )
            )
            #expect(
                !HomeReturnNavigationPresentation.shouldSkipFullRebuildOnReturn(
                    hasPerformedInitialBuild: true,
                    hasWarmAggregate: false
                )
            )
            #expect(
                HomeReturnNavigationPresentation.hasWarmAggregate(hasPerformedInitialBuild: true)
            )
            #expect(
                !HomeReturnNavigationPresentation.hasWarmAggregate(hasPerformedInitialBuild: false)
            )
        }

        @Test func homeReturnNavigationPresentation_skipsForegroundRebuildWhenAggregateWarm() {
            #expect(
                HomeReturnNavigationPresentation.shouldSkipFullRebuildOnForegroundActivation(
                    hasPerformedInitialBuild: true,
                    hasWarmAggregate: true
                )
            )
            #expect(
                !HomeReturnNavigationPresentation.shouldSkipFullRebuildOnForegroundActivation(
                    hasPerformedInitialBuild: true,
                    hasWarmAggregate: false
                )
            )
        }

        @Test func homeOverviewAggregateComputer_aggregatesOwnerMediaAndSightings() {
            let diveID = UUID()
            let mediaID = UUID()
            let siteID = UUID()
            let activitySeed = LogbookActivitySnapshotSeed(
                id: diveID,
                kind: .scubaDive,
                sourceDiveId: nil,
                sourceActivityId: nil,
                startTime: Date(timeIntervalSinceReferenceDate: 0),
                maxDepthMeters: 18,
                swimDistanceMeters: nil,
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
                linkedTripID: nil,
                previewMediaIsSnorkel: false
            )
            let input = HomeOverviewBuildInput(
                activitySeeds: [activitySeed],
                tripSeeds: [],
                diveSiteIDByActivityID: [diveID: siteID],
                linkedSiteDisplayNameByID: [siteID: "Blue Hole"],
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
                kind: .scubaDive,
                sourceDiveId: nil,
                sourceActivityId: nil,
                startTime: Date(timeIntervalSinceReferenceDate: 0),
                maxDepthMeters: 12,
                swimDistanceMeters: nil,
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
                linkedTripID: nil,
                previewMediaIsSnorkel: false
            )
            let input = HomeOverviewBuildInput(
                activitySeeds: [activitySeed],
                tripSeeds: [],
                diveSiteIDByActivityID: [ownerDiveID: nil],
                linkedSiteDisplayNameByID: [:],
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

        @Test func homeOverviewAggregateComputer_build_toleratesDuplicateSightingMarineLifeUUIDs() {
            let diveID = UUID()
            let activitySeed = LogbookActivitySnapshotSeed(
                id: diveID,
                kind: .scubaDive,
                sourceDiveId: nil,
                sourceActivityId: nil,
                startTime: Date(timeIntervalSinceReferenceDate: 0),
                maxDepthMeters: 18,
                swimDistanceMeters: nil,
                durationMinutes: 40,
                bottomTimeSeconds: nil,
                diveNumber: 1,
                diveNumberExplicitlyNone: false,
                displayName: "Wall",
                formattedStartDateOnly: "Jan 3",
                resolvedSiteNameLowercased: "wall",
                activityTagNames: [],
                buddyDisplayNames: [],
                previewMediaPhotoID: nil,
                linkedTripID: nil,
                previewMediaIsSnorkel: false
            )
            let input = HomeOverviewBuildInput(
                activitySeeds: [activitySeed],
                tripSeeds: [],
                diveSiteIDByActivityID: [diveID: nil],
                linkedSiteDisplayNameByID: [:],
                buddyTagSeeds: [],
                mediaPhotoSeeds: [],
                sightingSeeds: [
                    HomeOverviewSightingSeed(
                        mediaPhotoID: UUID(),
                        diveActivityID: diveID,
                        marineLifeUUID: "turtle-uuid",
                        commonName: "Green sea turtle"
                    ),
                    HomeOverviewSightingSeed(
                        mediaPhotoID: UUID(),
                        diveActivityID: diveID,
                        marineLifeUUID: "turtle-uuid",
                        commonName: "Green sea turtle"
                    ),
                ],
                mediaBuddyTagSeeds: [],
                automaticallyRenumberDives: false,
                displayUnits: .metric,
                ownerProfileID: UUID(),
                selfBuddyID: nil,
                referenceDate: Date(timeIntervalSinceReferenceDate: 0)
            )

            // Launch path previously trapped here via Dictionary(uniqueKeysWithValues:).
            let resolvedNames = Dictionary(
                godiveUniquingKeysWithValues: input.sightingSeeds.map { ($0.marineLifeUUID, $0.commonName) }
            )
            #expect(resolvedNames.count == 1)
            #expect(resolvedNames["turtle-uuid"] == "Green sea turtle")

            let result = HomeOverviewAggregateComputer.build(from: input)
            #expect(result.sightingCountInputs.count == 2)
            #expect(result.lifetimeStats.diveCount == 1)
        }

        @Test func homeOverviewFirstPaintPresentation_twoPhaseWhenInitialAndHasDives() {
            #expect(
                HomeOverviewFirstPaintPresentation.shouldUseTwoPhaseInitialRebuild(
                    hasPerformedInitialHomeBuild: false,
                    ownerDiveActivityCount: 3
                )
            )
            #expect(
                !HomeOverviewFirstPaintPresentation.shouldUseTwoPhaseInitialRebuild(
                    hasPerformedInitialHomeBuild: false,
                    ownerDiveActivityCount: 0
                )
            )
            #expect(
                !HomeOverviewFirstPaintPresentation.shouldUseTwoPhaseInitialRebuild(
                    hasPerformedInitialHomeBuild: true,
                    ownerDiveActivityCount: 3
                )
            )
        }

        @Test @MainActor
        func homeOverviewAggregateBuilder_launchPath_includesTopSpeciesAndBuddiesWithoutMediaJPEG() throws {
            let schema = Schema([
                DiveActivity.self,
                DiveMediaPhoto.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveTrip.self,
                DiveTripActivityLink.self,
                SightingInstance.self,
                MarineLife.self,
                UserProfile.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let owner = UserProfile(
                appleUserIdentifier: "launch-path-\(UUID().uuidString)",
                displayName: "Launch Path"
            )
            context.insert(owner)
            let dive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSinceReferenceDate: 100),
                durationMinutes: 40,
                maxDepthMeters: 22,
                diveNumber: 1
            )
            dive.ownerProfileID = owner.id
            dive.owner = owner
            dive.siteName = "Blue Hole"
            context.insert(dive)
            let media = DiveMediaPhoto(
                sortOrder: 0,
                mediaKind: .image,
                photosLocalIdentifier: "ph-launch-path"
            )
            media.diveActivityID = dive.id
            media.dive = dive
            context.insert(media)
            let manta = MarineLife(uuid: "ml-launch-manta", commonName: "Manta Ray")
            context.insert(manta)
            let sighting = SightingInstance(
                marineLifeUUID: manta.uuid,
                sightingDateTime: Date(timeIntervalSinceReferenceDate: 110),
                diveActivity: dive
            )
            sighting.diveActivityID = dive.id
            context.insert(sighting)
            let buddy = DiveBuddy(displayName: "Alex Dive")
            buddy.ownerProfileID = owner.id
            context.insert(buddy)
            let tag = DiveBuddyTag(buddy: buddy, dive: dive)
            tag.diveActivityID = dive.id
            tag.buddyID = buddy.id
            context.insert(tag)
            try context.save()

            let launch = HomeOverviewAggregateBuilder.buildLaunch(
                activities: [dive],
                buddyRoster: [buddy],
                automaticallyRenumberDives: true,
                ownerProfileID: owner.id,
                ownerProfile: owner,
                modelContext: context
            )
            #expect(launch.aggregate.diveStatsInputs.count == 1)
            #expect(launch.aggregate.lifetimeStats.diveCount == 1)
            #expect(launch.aggregate.ownerMediaPhotos.isEmpty)
            #expect(launch.aggregate.ownerSightings.isEmpty)
            #expect(launch.aggregate.diveStatsInputs[0].siteDisplayName == "Blue Hole")
            #expect(launch.aggregate.lifetimeStats.topSpecies?.commonName == "Manta Ray")
            #expect(launch.aggregate.lifetimeStats.topSpecies?.sightingCount == 1)
            #expect(launch.aggregate.sightingCountInputs.count == 1)
            #expect(launch.aggregate.buddyLeaderboard.count == 1)
            #expect(launch.aggregate.buddyLeaderboard[0].displayName == "Alex Dive")
            #expect(launch.commonNameByUUID[manta.uuid] == "Manta Ray")

            let mediaSeeds = HomeDiveScalarSeeding.mediaPhotoSeeds(
                ownerDiveIDs: [dive.id],
                activities: [dive],
                modelContext: context
            )
            #expect(mediaSeeds.count == 1)
            #expect(mediaSeeds[0].id == media.id)

            let sources = HomeMediaHighlightWarmup.highlightSources(from: mediaSeeds)
            #expect(sources.count == 1)
            #expect(sources[0].videoDurationSeconds == nil)

            let pickPhotos = HomeDiveScalarSeeding.fetchMediaPhotos(ids: [media.id], modelContext: context)
            #expect(pickPhotos.count == 1)
            let withMedia = launch.aggregate.withCarouselMedia(pickPhotos)
            #expect(withMedia.ownerMediaPhotos.count == 1)
            #expect(withMedia.mediaByID[media.id] != nil)
        }

        @Test @MainActor
        func homeOverviewAggregateBuilder_buildAsync_offMainCaptureBindsOnlyCarouselPicks() async throws {
            let schema = Schema([
                DiveActivity.self,
                DiveMediaPhoto.self,
                DiveBuddy.self,
                DiveBuddyTag.self,
                DiveTrip.self,
                DiveTripActivityLink.self,
                SightingInstance.self,
                UserProfile.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            let owner = UserProfile(
                appleUserIdentifier: "enrich-picks-\(UUID().uuidString)",
                displayName: "Enrich Picks"
            )
            context.insert(owner)
            let dive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSinceReferenceDate: 200),
                durationMinutes: 45,
                maxDepthMeters: 18,
                diveNumber: 1
            )
            dive.ownerProfileID = owner.id
            dive.owner = owner
            context.insert(dive)
            var mediaIDs: [UUID] = []
            for index in 0 ..< 5 {
                let media = DiveMediaPhoto(
                    sortOrder: index,
                    mediaKind: .image,
                    photosLocalIdentifier: "ph-enrich-\(index)"
                )
                media.diveActivityID = dive.id
                media.dive = dive
                context.insert(media)
                mediaIDs.append(media.id)
            }
            try context.save()

            let built = await HomeOverviewAggregateBuilder.buildAsync(
                activities: [dive],
                commonNameByUUID: [:],
                automaticallyRenumberDives: true,
                ownerProfileID: owner.id,
                ownerProfile: owner,
                modelContext: context
            )

            // Full media index survives as Sendable seeds; only today's picks are bound rows.
            #expect(built.mediaPhotoSeeds.count == 5)
            #expect(built.mediaByID.count == HomeMediaHighlightPresentation.carouselLimit)
            #expect(built.ownerMediaPhotos.count == HomeMediaHighlightPresentation.carouselLimit)
            #expect(built.lifetimeStats.diveCount == 1)
            let boundIDs = Set(built.mediaByID.keys)
            #expect(boundIDs.isSubset(of: Set(mediaIDs)))

            // Bound rows match the deterministic in-session daily picks Home renders.
            let candidates = HomeMediaHighlightPresentation.buildCandidates(
                mediaPhotos: HomeMediaHighlightWarmup.highlightSources(from: built.mediaPhotoSeeds),
                dives: built.diveStatsInputs
            )
            let expectedPickIDs = HomeMediaHighlightPresentation.highlightsForOwner(
                ownerProfileID: owner.id,
                candidates: candidates
            ).map(\.mediaID)
            #expect(boundIDs == Set(expectedPickIDs))

            // withCarouselMedia keeps the media index when no replacement seeds are passed.
            let rebound = built.withCarouselMedia(Array(built.ownerMediaPhotos.prefix(1)))
            #expect(rebound.mediaPhotoSeeds.count == 5)
            #expect(rebound.ownerMediaPhotos.count == 1)
        }

        @Test func homeOverviewRebuildPresentation_skipsIncidentalUntilInitialBuild() {
            #expect(
                HomeOverviewRebuildPresentation.shouldSkipSchedule(
                    isCelebrationShellPrewarmActive: false,
                    hasPerformedInitialHomeBuild: false,
                    source: .incidental
                )
            )
            #expect(
                !HomeOverviewRebuildPresentation.shouldSkipSchedule(
                    isCelebrationShellPrewarmActive: false,
                    hasPerformedInitialHomeBuild: true,
                    source: .incidental
                )
            )
            #expect(
                !HomeOverviewRebuildPresentation.shouldSkipSchedule(
                    isCelebrationShellPrewarmActive: false,
                    hasPerformedInitialHomeBuild: false,
                    source: .initialRootAppear
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
            let belowSeam = HomeMediaCarouselPresentation.slideChromeDistanceBelowSeam
            #expect(belowSeam == 56)
            #expect(
                inset
                    == HomeLifetimeStatsLayout.panelOverlap - belowSeam
            )
            #expect(inset < HomeLifetimeStatsLayout.panelOverlap)
            #expect(inset >= AppTheme.Spacing.md)
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

        @Test func homeMediaCarouselPresentation_featuredMediaBandRect_endsAtSheetSeam() {
            let viewportHeight: CGFloat = 500
            let rect = HomeMediaCarouselPresentation.featuredMediaBandRect(
                viewportWidth: 390,
                viewportHeight: viewportHeight
            )
            // Bleed equals panel overlap → media fills to the hero floor (no black gap above the sheet).
            #expect(
                HomeMediaCarouselPresentation.featuredMediaBleedBelowSeam
                    == HomeOverviewLayout.panelOverlap
            )
            let expectedHeight = viewportHeight
            #expect(rect.origin.x == 0)
            #expect(rect.origin.y == 0)
            #expect(rect.width == 390)
            #expect(abs(rect.height - expectedHeight) < 0.001)
            #expect(
                abs(
                    HomeMediaCarouselPresentation.featuredMediaBottomYFromTop(
                        viewportHeight: viewportHeight
                    ) - viewportHeight
                ) < 0.001
            )
            // Always use laid-out page height (do not max with a taller geometry — that clips seam bleed).
            #expect(
                HomeMediaCarouselPresentation.featuredMediaLayoutViewportHeight(
                    geometryHeight: 440,
                    carouselContentHeight: 500
                ) == 500
            )
            #expect(
                HomeMediaCarouselPresentation.featuredMediaLayoutViewportHeight(
                    geometryHeight: 520,
                    carouselContentHeight: 500
                ) == 500
            )
            #expect(
                HomeMediaCarouselPresentation.featuredMediaLayoutViewportHeight(
                    geometryHeight: 440,
                    carouselContentHeight: 0
                ) == 440
            )
            #expect(HomeMediaCarouselPresentation.usesTapGestureForOpenMediaOnScrollPage)
            #expect(HomeMediaCarouselPresentation.usesSimultaneousTapGestureForOpenMediaOnScrollPage)
            #expect(HomeMediaCarouselScrollInteractionPresentation.usesUIKitScrollViewTapInstaller)
            #expect(HomeMediaCarouselScrollInteractionPresentation.usesEagerHorizontalStackForPaging)
        }

        @Test func homeMediaCarouselPresentation_slideChromePanelHitPassThroughHeight_coversControlRow() {
            let height = HomeMediaCarouselPresentation.slideChromePanelHitPassThroughHeight(
                controlHeight: 48
            )
            #expect(height == HomeMediaCarouselPresentation.slideChromeDistanceBelowSeam + 48 + 8)
            #expect(height > HomeMediaCarouselPresentation.slideChromeDistanceBelowSeam)
            let shape = HomeLifetimeStatsPanelMediaChromePassThroughHitShape(passThroughTop: 100)
            let path = shape.path(in: CGRect(x: 0, y: 0, width: 200, height: 400))
            #expect(path.boundingRect.origin.y == 100)
            #expect(path.boundingRect.height == 300)
            let full = HomeLifetimeStatsPanelMediaChromePassThroughHitShape(passThroughTop: 0)
                .path(in: CGRect(x: 0, y: 0, width: 200, height: 400))
            #expect(full.boundingRect.height == 400)
        }

        @Test func homeMediaCarouselScrollInteraction_openMediaTapYieldsToChromeControls() {
            #expect(
                HomeMediaCarouselScrollInteractionPresentation.viewClassNameExcludesOpenMediaTap(
                    "SwiftUI.Button"
                )
            )
            #expect(
                HomeMediaCarouselScrollInteractionPresentation.viewClassNameExcludesOpenMediaTap(
                    "UIButton"
                )
            )
            #expect(
                !HomeMediaCarouselScrollInteractionPresentation.viewClassNameExcludesOpenMediaTap(
                    "UIScrollView"
                )
            )
            #expect(
                HomeMediaCarouselScrollInteractionPresentation.shouldIgnoreOpenMediaTap(
                    touchingViewClassNames: ["SwiftUI.ButtonPlatformView"],
                    encounteredNestedScrollView: false,
                    hasCompetingTapRecognizer: false
                )
            )
            #expect(
                HomeMediaCarouselScrollInteractionPresentation.shouldIgnoreOpenMediaTap(
                    touchingViewClassNames: ["UIView"],
                    encounteredNestedScrollView: true,
                    hasCompetingTapRecognizer: false
                )
            )
            #expect(
                HomeMediaCarouselScrollInteractionPresentation.shouldIgnoreOpenMediaTap(
                    touchingViewClassNames: ["UIView"],
                    encounteredNestedScrollView: false,
                    hasCompetingTapRecognizer: true
                )
            )
            #expect(
                !HomeMediaCarouselScrollInteractionPresentation.shouldIgnoreOpenMediaTap(
                    touchingViewClassNames: ["UIView", "UIImageView"],
                    encounteredNestedScrollView: false,
                    hasCompetingTapRecognizer: false
                )
            )
            #expect(
                HomeMediaCarouselScrollInteractionPresentation.openMediaTapShouldRequireFailure(
                    ofOtherGestureClassName: "UITapGestureRecognizer",
                    otherIsTapGesture: true,
                    otherIsPanGesture: false,
                    otherViewIsPagingScrollView: false
                )
            )
            #expect(
                !HomeMediaCarouselScrollInteractionPresentation.openMediaTapShouldRequireFailure(
                    ofOtherGestureClassName: "UIPanGestureRecognizer",
                    otherIsTapGesture: false,
                    otherIsPanGesture: true,
                    otherViewIsPagingScrollView: false
                )
            )
            #expect(
                !HomeMediaCarouselScrollInteractionPresentation.openMediaTapShouldRequireFailure(
                    ofOtherGestureClassName: "UITapGestureRecognizer",
                    otherIsTapGesture: true,
                    otherIsPanGesture: false,
                    otherViewIsPagingScrollView: true
                )
            )
        }

        @Test func homeMediaCarouselPresentation_nextIndex_wrapsAndRequiresMultipleSlides() {
            #expect(HomeMediaCarouselPresentation.nextIndex(after: 0, count: 3) == 1)
            #expect(HomeMediaCarouselPresentation.nextIndex(after: 2, count: 3) == 0)
            // Scroll paging is 1:1 with highlights (no duplicate wrap page).
            #expect(HomeMediaCarouselPresentation.loopingPagerSlideCount(slideCount: 3) == 3)
            #expect(HomeMediaCarouselPresentation.loopingPagerSlideCount(slideCount: 1) == 1)
            #expect(HomeMediaCarouselPresentation.logicalSlideIndex(pagerIndex: 2, slideCount: 3) == 2)
            #expect(HomeMediaCarouselPresentation.logicalSlideIndex(pagerIndex: 9, slideCount: 3) == 2)
            #expect(HomeMediaCarouselPresentation.nextLoopingPagerIndex(after: 2, slideCount: 3) == 0)
            #expect(HomeMediaCarouselPresentation.nextLoopingPagerIndex(after: 0, slideCount: 3) == 1)
            #expect(!HomeMediaCarouselPresentation.shouldResetLoopingPagerIndex(pagerIndex: 3, slideCount: 3))
            #expect(
                HomeMediaCarouselPresentation.shouldDisableAnimationForAutoAdvanceWrap(
                    fromIndex: 2,
                    toIndex: 0,
                    slideCount: 3
                )
            )
            #expect(
                !HomeMediaCarouselPresentation.shouldDisableAnimationForAutoAdvanceWrap(
                    fromIndex: 0,
                    toIndex: 1,
                    slideCount: 3
                )
            )
            #expect(HomeMediaCarouselPresentation.clampedPagerIndex(nil, slideCount: 3) == 0)
            #expect(HomeMediaCarouselPresentation.clampedPagerIndex(5, slideCount: 3) == 2)
            #expect(HomeMediaCarouselPresentation.nextIndex(after: 0, count: 0) == 0)
            #expect(HomeMediaCarouselPresentation.shouldAutoAdvance(slideCount: 1) == false)
            #expect(HomeMediaCarouselPresentation.shouldAutoAdvance(slideCount: 2) == true)
            #expect(HomeMediaCarouselPresentation.shouldRestartClipAfterPlaybackFinished(slideCount: 0) == true)
            #expect(HomeMediaCarouselPresentation.shouldRestartClipAfterPlaybackFinished(slideCount: 1) == true)
            #expect(HomeMediaCarouselPresentation.shouldRestartClipAfterPlaybackFinished(slideCount: 3) == false)
            #expect(HomeMediaCarouselPresentation.photoDisplaySeconds == 10)
            #expect(HomeMediaCarouselPresentation.shouldLoopCarouselVideo(isPagePlaybackActive: true))
            #expect(!HomeMediaCarouselPresentation.shouldLoopCarouselVideo(isPagePlaybackActive: false))
            #expect(
                HomeMediaCarouselPresentation.videoAutoAdvanceSeconds(
                    assetDurationSeconds: 4.5,
                    slideCount: 3
                ) == 4.5
            )
            #expect(
                HomeMediaCarouselPresentation.videoAutoAdvanceSeconds(
                    assetDurationSeconds: nil,
                    slideCount: 3
                ) == HomeMediaCarouselPresentation.videoDisplayFallbackSeconds
            )
            #expect(
                HomeMediaCarouselPresentation.videoAutoAdvanceSeconds(
                    assetDurationSeconds: 12,
                    slideCount: 1
                ) == nil
            )
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
                ) == max(
                    overlayHeight
                        - HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorTopInsetFromTop(
                            sheetSeamYFromTop: templateSeam
                        )
                        - HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorDotSize,
                    HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam
                )
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
                ) == max(
                    overlayHeight
                        - pageIndicatorTopInset
                        - HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorDotSize,
                    HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam
                )
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
                    == TripDetailMediaGalleryPresentation.marineLifeOverlayMediaScrimOpacity
            )
            #expect(
                DiveActivityMediaFrostedOverlayPresentation.mediaScrimOpacity
                    == HomeMediaCarouselPresentation.marineLifeCarouselOverlayMediaScrimOpacity
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

        @Test func homeMediaCarouselPresentation_taggedBuddyHorizontalOffsetX_fansLeftWhenExpanded() {
            let diameter: CGFloat = 40
            let spacing: CGFloat = 8
            #expect(
                HomeMediaCarouselPresentation.taggedBuddyHorizontalOffsetX(
                    distanceFromIcon: 0,
                    avatarDiameter: diameter,
                    avatarSpacing: spacing,
                    isExpanded: false
                ) == 0
            )
            #expect(
                HomeMediaCarouselPresentation.taggedBuddyHorizontalOffsetX(
                    distanceFromIcon: 0,
                    avatarDiameter: diameter,
                    avatarSpacing: spacing,
                    isExpanded: true
                ) == 0
            )
            #expect(
                HomeMediaCarouselPresentation.taggedBuddyHorizontalOffsetX(
                    distanceFromIcon: 1,
                    avatarDiameter: diameter,
                    avatarSpacing: spacing,
                    isExpanded: true
                ) == -48
            )
            #expect(
                HomeMediaCarouselPresentation.taggedBuddyHorizontalOffsetX(
                    distanceFromIcon: 2,
                    avatarDiameter: diameter,
                    avatarSpacing: spacing,
                    isExpanded: true
                ) == -96
            )
            #expect(
                HomeMediaCarouselPresentation.taggedBuddyHorizontalStripWidth(
                    buddyCount: 2,
                    avatarDiameter: diameter,
                    avatarSpacing: spacing
                ) == 88
            )
        }

        @Test func homeMediaCarouselPresentation_taggedBuddyExpandedStripViewport_andPagerLock() {
            let diameter: CGFloat = 40
            let spacing: CGFloat = 8
            let padding: CGFloat = 24
            let containerWidth: CGFloat = 390

            let maxVisible = HomeMediaCarouselPresentation.taggedBuddyExpandedMaxVisibleWidth(
                containerWidth: containerWidth,
                horizontalPadding: padding,
                iconDiameter: diameter,
                iconToStripSpacing: spacing
            )
            #expect(maxVisible == containerWidth - 2 * padding - diameter - spacing)

            let twoBuddyStrip = HomeMediaCarouselPresentation.taggedBuddyHorizontalStripWidth(
                buddyCount: 2,
                avatarDiameter: diameter,
                avatarSpacing: spacing
            )
            #expect(
                !HomeMediaCarouselPresentation.taggedBuddyHorizontalNeedsScroll(
                    stripWidth: twoBuddyStrip,
                    maxVisibleWidth: maxVisible
                )
            )

            let sevenBuddyStrip = HomeMediaCarouselPresentation.taggedBuddyHorizontalStripWidth(
                buddyCount: 7,
                avatarDiameter: diameter,
                avatarSpacing: spacing
            )
            #expect(
                HomeMediaCarouselPresentation.taggedBuddyHorizontalNeedsScroll(
                    stripWidth: sevenBuddyStrip,
                    maxVisibleWidth: maxVisible
                )
            )

            // Expanded buddy strip must not lock Home carousel paging (felt like dead swipes).
            #expect(
                !HomeMediaCarouselPresentation.taggedBuddyPagerScrollDisabled(
                    hasExpandedBuddyList: true
                )
            )
            #expect(
                HomeMediaCarouselPresentation.taggedBuddyPagerScrollDisabled(
                    hasExpandedBuddyList: false,
                    showsMarineLifeOverlay: true
                )
            )
            #expect(
                HomeMediaCarouselPresentation.taggedBuddyPagerScrollDisabled(
                    hasExpandedBuddyList: true,
                    showsMarineLifeOverlay: true
                )
            )
            #expect(
                !HomeMediaCarouselPresentation.taggedBuddyPagerScrollDisabled(
                    hasExpandedBuddyList: false,
                    showsMarineLifeOverlay: false
                )
            )
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
            #expect(height > AppTheme.Layout.glassChromeControlHeight)
        }

        @Test func homeMediaCarouselPresentation_slideChromeTrailingControls_fishLeadsBuddy() {
            #expect(
                HomeMediaCarouselPresentation.slideChromeTrailingControls(
                    hasTaggedSpecies: false,
                    hasTaggedBuddies: false
                ).isEmpty
            )
            #expect(
                HomeMediaCarouselPresentation.slideChromeTrailingControls(
                    hasTaggedSpecies: true,
                    hasTaggedBuddies: false
                ) == [.species]
            )
            #expect(
                HomeMediaCarouselPresentation.slideChromeTrailingControls(
                    hasTaggedSpecies: false,
                    hasTaggedBuddies: true
                ) == [.buddies]
            )
            #expect(
                HomeMediaCarouselPresentation.slideChromeTrailingControls(
                    hasTaggedSpecies: true,
                    hasTaggedBuddies: true
                ) == [.species, .buddies]
            )
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

        @Test func homeMediaCarouselDiveLinkChrome_openDiveHaptic_skipsUnderUITest() {
            #expect(!HomeMediaCarouselDiveLinkChromePresentation.shouldPlayOpenDiveHaptic(isUITest: true))
            #expect(HomeMediaCarouselDiveLinkChromePresentation.shouldPlayOpenDiveHaptic(isUITest: false))
        }

        @Test func homeMediaCarouselPresentation_marineLifeOverlayCloseTopInset_alignsWithHomeHeaderProfileRow() {
            let topSafeAreaInset: CGFloat = 59
            let headerClearance: CGFloat = 112
            #expect(HomeMediaCarouselPresentation.marineLifeCarouselOverlayCloseTopOffsetFromHeaderAlignment == 0)
            #expect(HomeMediaCarouselPresentation.showsCloseControlInHomeTopChrome)
            #expect(HomeMediaCarouselPresentation.marineLifeOverlayUsesClearCloseHitTarget())
            #expect(
                !HomeMediaCarouselPresentation.marineLifeOverlayUsesClearCloseHitTarget(
                    showsCloseControlInHomeTopChrome: false
                )
            )
            #expect(
                HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesContentTopOffsetFromCloseButton
                    == 75
            )
            #expect(
                HomeMediaCarouselPresentation.marineLifeOverlayCloseLeadingInset == AppTheme.Spacing.lg
            )
            #expect(HomeMediaCarouselPresentation.shouldShowHomeNotificationsBell(showsMarineLifeOverlay: false))
            #expect(!HomeMediaCarouselPresentation.shouldShowHomeNotificationsBell(showsMarineLifeOverlay: true))
            #expect(
                HomeMediaCarouselPresentation.allowsHomeTopChromeHitTesting(
                    showsMarineLifeOverlay: true,
                    homeHeroInteractionOverlayActive: true
                )
            )
            #expect(
                HomeMediaCarouselPresentation.allowsHomeTopChromeHitTesting(
                    showsMarineLifeOverlay: false,
                    homeHeroInteractionOverlayActive: true
                )
            )
            #expect(
                HomeMediaCarouselPresentation.allowsHomeTopChromeHitTesting(
                    showsMarineLifeOverlay: false,
                    homeHeroInteractionOverlayActive: false
                )
            )
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
            #expect(
                HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesContentTopInset(
                    closeTopInset: inset
                )
                    == inset
                        + HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesContentTopOffsetFromCloseButton
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
            // Species band sits 75 pt below the header-aligned × — fewer description lines than the
            // old close-tied layout, but still room for several lines above page dots.
            #expect(limit >= 4)
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
            #expect(
                speciesTopInset
                    == closeInset
                        + HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesContentTopOffsetFromCloseButton
            )
            let speciesNameTopInset = HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesNameTopInset(
                closeTopInset: closeInset
            )
            #expect(
                speciesNameTopInset
                    == speciesTopInset
                        + HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop
            )
            let pageIndicatorTopInset = HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorTopInsetFromTop(
                sheetSeamYFromTop: HomeMediaCarouselPresentation.marineLifeCarouselOverlaySheetSeamYFromTop(
                    heroBandHeight: heroBandHeight,
                    topSafeAreaInset: topSafeAreaInset,
                    panelOverlap: panelOverlap
                )
            )
            let heroBandBottomY = HomeMediaCarouselPresentation.marineLifeCarouselOverlayHeroBandBottomYFromTop(
                heroBandHeight: heroBandHeight,
                topSafeAreaInset: topSafeAreaInset
            )
            let pageIndicatorColumnHeight = HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnHeight(
                closeTopInset: closeInset,
                pageIndicatorTopInset: pageIndicatorTopInset,
                speciesRowHeight: speciesRowHeight
            )
            #expect(
                pageIndicatorColumnHeight
                    == pageIndicatorTopInset - closeInset
                        - HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesToPageIndicatorSpacing
                        - HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnBottomLift
            )
            #expect(
                HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnHeight(
                    closeTopInset: closeInset,
                    pageIndicatorTopInset: pageIndicatorTopInset,
                    heroBandBottomYFromTop: heroBandBottomY,
                    speciesRowHeight: speciesRowHeight
                )
                    == heroBandBottomY - closeInset
                        - HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnBottomLift
            )
            #expect(HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnBottomLift == 126)
            #expect(HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnTopCrop == 103)
            #expect(HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnVerticalOffset == -83)
            #expect(HomeMediaCarouselPresentation.marineLifeCarouselOverlaySpeciesNameTopOffsetFromFeatureImageTop == 21)
            let settledColumnLayout = HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageColumnLayout(
                closeTopInset: closeInset,
                featureImageColumnHeight: 200
            )
            #expect(settledColumnLayout.topInset == closeInset + 103)
            #expect(settledColumnLayout.height == 97)
            #expect(
                HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorBottomInset(
                    overlayHeight: previewHeight,
                    heroBandHeight: heroBandHeight,
                    topSafeAreaInset: topSafeAreaInset,
                    panelOverlap: panelOverlap
                ) == max(
                    previewHeight
                        - pageIndicatorTopInset
                        - HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorDotSize,
                    HomeMediaCarouselPresentation.marineLifeCarouselOverlayPageIndicatorClearanceAboveSeam
                )
            )
        }

        @Test func homeLifetimeStatsLayout_usesTwoColumnFixedHeightTiles() {
            #expect(HomeLifetimeStatsLayout.gridColumnCount == 2)
            #expect(HomeLifetimeStatsLayout.highlightStatTileCount == 4)
            #expect(HomeLifetimeStatsLayout.rowCount(tileCount: 4) == 2)
            #expect(HomeLifetimeStatsLayout.rowCount(tileCount: 3) == 2)
            #expect(HomeLifetimeStatsLayout.statTileHeight == 90)
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

        @Test func homeLifetimeStatsTilesLayout_homePinsSummaryAboveCenteredTiles() {
            let panelHeight: CGFloat = 400
            let summaryBand = HomeLifetimeStatsTilesLayout.lifetimeSummaryBandHeight()
            let tilesAvailable = HomeLifetimeStatsTilesLayout.homeCenteredTilesAvailableHeight(
                panelHeight: panelHeight,
                includesLifetimeSummaryHeader: true
            )
            #expect(tilesAvailable == panelHeight - summaryBand)

            let tileMin = HomeLifetimeStatsTilesLayout.scrollContentHeight(
                statRowCount: 2,
                showsBuddyLeaderboard: true,
                includesLifetimeSummaryHeader: false
            )
            let insets = HomeLifetimeStatsTilesLayout.resolvedVerticalEdgeInsets(
                totalHeight: tilesAvailable,
                statRowCount: 2,
                showsBuddyLeaderboard: true,
                includesLifetimeSummaryHeader: false
            )
            let summaryTopSlack = HomeLifetimeStatsTilesLayout.homeLifetimeSummaryTopSlack(
                tileCenteringTopInset: insets.top
            )
            #expect(HomeLifetimeStatsTilesLayout.homeLifetimeSummaryTopSlackFraction == 0.5)
            #expect(abs(summaryTopSlack - insets.top * 0.5) < 0.001)
            // Halfway between seam-pinned and old fully-centered summary; tiles stay at full top slack.
            let summaryTopFromSeam = summaryTopSlack + HomeLifetimeStatsTilesLayout.lifetimeSummaryTopInset
            let tilesTopFromSeam = summaryTopSlack + summaryBand + (insets.top - summaryTopSlack)
            #expect(summaryTopFromSeam < tilesTopFromSeam)
            #expect(abs(tilesTopFromSeam - (summaryBand + insets.top)) < 0.001)
            #expect(abs(tilesAvailable - tileMin - insets.top - insets.bottom) < 0.001)
        }

        @Test func homeLifetimeStatsTilesLayout_resolvedVerticalEdgeInsets_rejectsNonFiniteHeight() {
            let insets = HomeLifetimeStatsTilesLayout.resolvedVerticalEdgeInsets(
                totalHeight: .infinity,
                statRowCount: 2,
                showsBuddyLeaderboard: false
            )
            #expect(insets.top == 0)
            #expect(insets.bottom == 0)

            let nanInsets = HomeLifetimeStatsTilesLayout.resolvedVerticalEdgeInsets(
                totalHeight: .nan,
                statRowCount: 2,
                showsBuddyLeaderboard: true
            )
            #expect(nanInsets.top == 0)
            #expect(nanInsets.bottom == 0)
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
            let minGrid = HomeLifetimeStatsTilesLayout.gridHeight(
                tileCount: HomeLifetimeStatsTilesLayout.highlightStatTileCount
            )
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
            #expect(atMinimum.grid >= minGrid - 0.001)
            #expect(atMinimum.buddy >= minBuddy - 0.001)

            let expanded = HomeLifetimeStatsTilesLayout.resolvedFlexibleSectionHeights(
                totalHeight: minTotal + 84,
                showsBuddyLeaderboard: true
            )
            #expect(expanded.grid > atMinimum.grid)
            #expect(expanded.buddy > atMinimum.buddy)
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
                HomeLifetimeStatsTilesLayout.scrollContentHeight(showsBuddyLeaderboard: true)
                    == 340 + HomeLifetimeStatsTilesLayout.lifetimeSummaryBandHeight()
            )
        }

        @Test func homeOverviewAggregate_myActivitiesSummary_matchesLogbookPresentation() {
            let seed = LogbookActivitySnapshotSeed(
                id: UUID(),
                kind: .scubaDive,
                sourceDiveId: nil,
                sourceActivityId: nil,
                startTime: Date(timeIntervalSinceReferenceDate: 0),
                maxDepthMeters: 20,
                swimDistanceMeters: nil,
                durationMinutes: 45,
                bottomTimeSeconds: 3_600,
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
            )
            let summary = LogbookMyActivitiesSummaryPresentation.summary(from: [seed])
            #expect(summary.diveCount == 1)
            #expect(summary.totalBottomTimeSeconds == 3_600)
            #expect(
                LogbookMyActivitiesSummaryPresentation.headerLine(for: summary)
                    == "1 Dive | 1 hr Bottom Time"
            )
        }

        @Test func homeLifetimeStatsPanelLayout_matchesVisualGridAndPadding() {
            let fourTileGrid = HomeLifetimeStatsLayout.gridHeight(tileCount: 4)
            let summaryBand = HomeLifetimeStatsTilesLayout.lifetimeSummaryBandHeight()
            #expect(
                abs(
                    HomeLifetimeStatsPanelLayout.estimatedScrollContentHeight(showsBuddyLeaderboard: false)
                        - (fourTileGrid + summaryBand)
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
            defer { HomeOverviewLayoutAnchor.resetForTesting() }
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
            // Empty Home still reserves the Top buddies band.
            #expect(
                HomeOverviewPushedLayoutPresentation.statsPanelContentHeightMatchingHome(activities: [])
                    == HomeLifetimeStatsLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: true)
            )
        }

        @Test @MainActor func homeOverviewPushedLayoutPresentation_statsPanelContentHeightMatchingHome_usesDiveBuddyTagsWhenRelationshipsUnset() {
            HomeOverviewLayoutAnchor.resetForTesting()
            defer { HomeOverviewLayoutAnchor.resetForTesting() }
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
            // Home always reserves Top buddies even when no tags are present yet.
            #expect(
                viaActivitiesOnly
                    == HomeLifetimeStatsLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: true)
            )
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

        @Test func homeOverviewRebuildPresentation_initialLaunchUsesPostOverlayDefer() {
            #expect(
                HomeOverviewRebuildPresentation.initialLaunchDebounceNanoseconds(
                    immediate: true,
                    source: .initialRootAppear
                ) == AppLaunchPostOverlayPresentation.initialHomeRebuildDeferNanoseconds
            )
            #expect(
                HomeOverviewRebuildPresentation.initialLaunchDebounceNanoseconds(
                    immediate: true,
                    source: .incidental
                ) == 0
            )
            #expect(
                HomeOverviewRebuildPresentation.initialLaunchDebounceNanoseconds(
                    immediate: false,
                    source: .initialRootAppear
                ) == 0
            )
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

        @Test func homeBuddyLeaderboard_shouldShow_alwaysReservesBand() {
            let entry = HomeBuddyLeaderboardEntry(
                id: UUID(),
                displayName: "Pat",
                profilePhoto: nil,
                diveCount: 1,
                rank: 1
            )
            #expect(HomeBuddyLeaderboardPresentation.shouldShow(diveCount: 1, entries: [entry]))
            #expect(HomeBuddyLeaderboardPresentation.shouldShow(diveCount: 0, entries: [entry]))
            #expect(HomeBuddyLeaderboardPresentation.shouldShow(diveCount: 3, entries: []))
            #expect(HomeBuddyLeaderboardPresentation.shouldShow(diveCount: 0, entries: []))
            #expect(HomeBuddyLeaderboardPresentation.displayEntries(from: []).isEmpty)
            #expect(HomeBuddyLeaderboardPresentation.displayEntries(from: [entry]).count == 1)
            #expect(HomeBuddyLeaderboardPresentation.emptySlotLabel == "—")
        }

        @Test func homeLifetimeStatsLeaderboardPresentation_rankedDiveIDs_limitsToTenAndSorts() {
            let dives = (1...12).map { index in
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
            #expect(deepest.count == 10)
            #expect(deepest.first == dives[11].id)

            let longest = HomeLifetimeStatsLeaderboardPresentation.rankedDiveIDs(
                dives: dives,
                kind: .longestDives
            )
            #expect(longest.count == 10)
            #expect(longest.first == dives[11].id)
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

        @Test func homeLifetimeStatsLeaderboardPresentation_topSites_mergesSameNameAcrossDifferentSiteIDs() {
            let siteA = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
            let siteB = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
            let dives = [
                HomeDiveStatsInput(
                    id: UUID(),
                    maxDepthMeters: 10,
                    durationMinutes: 40,
                    diveSiteID: siteA,
                    diveNumberLabel: "#1",
                    siteDisplayName: "Judy's Dream Belair"
                ),
                HomeDiveStatsInput(
                    id: UUID(),
                    maxDepthMeters: 12,
                    durationMinutes: 42,
                    diveSiteID: siteB,
                    diveNumberLabel: "#2",
                    siteDisplayName: "judy's dream belair"
                ),
                HomeDiveStatsInput(
                    id: UUID(),
                    maxDepthMeters: 8,
                    durationMinutes: 35,
                    diveSiteID: siteB,
                    diveNumberLabel: "#3",
                    siteDisplayName: "Judy's Dream Belair"
                ),
                HomeDiveStatsInput(
                    id: UUID(),
                    maxDepthMeters: 9,
                    durationMinutes: 30,
                    diveSiteID: UUID(),
                    diveNumberLabel: "#4",
                    siteDisplayName: "Salt Pier"
                ),
            ]

            let topSites = HomeLifetimeStatsLeaderboardPresentation.topSites(dives: dives)
            #expect(topSites.count == 2)
            #expect(topSites[0].name.lowercased() == "judy's dream belair")
            #expect(topSites[0].visitCount == 3)
            #expect(topSites[0].siteID == siteA || topSites[0].siteID == siteB)
            #expect(topSites[1].name == "Salt Pier")
            #expect(topSites[1].visitCount == 1)
        }

        @Test func homeLifetimeStatsPresentation_mostVisitedSite_mergesSameNameAcrossDifferentSiteIDs() {
            let siteA = UUID()
            let siteB = UUID()
            let dives = [
                HomeDiveStatsInput(
                    id: UUID(),
                    maxDepthMeters: 10,
                    durationMinutes: 40,
                    diveSiteID: siteA,
                    diveNumberLabel: "#1",
                    siteDisplayName: "Judy's Dream Belair"
                ),
                HomeDiveStatsInput(
                    id: UUID(),
                    maxDepthMeters: 12,
                    durationMinutes: 42,
                    diveSiteID: siteB,
                    diveNumberLabel: "#2",
                    siteDisplayName: "Judy's Dream Belair"
                ),
            ]
            let stats = HomeLifetimeStatsPresentation.build(dives: dives, sightings: [])
            #expect(stats.mostVisitedSite?.name == "Judy's Dream Belair")
            #expect(stats.mostVisitedSite?.visitCount == 2)
        }

        @Test func homeLifetimeStatsLeaderboardPresentation_topSpecies_limitsToTen() {
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
                    == "Deepest Dives"
            )
            #expect(
                HomeLifetimeStatsLeaderboardPresentation.pageTitle(for: .longestDives)
                    == "Longest Activities"
            )
            #expect(
                HomeLifetimeStatsLeaderboardPresentation.pageTitle(for: .topSites)
                    == "Top Sites"
            )
            #expect(
                HomeLifetimeStatsLeaderboardPresentation.pageTitle(for: .topSpecies)
                    == "Top Species"
            )
            // Top 10 pages use Logbook-style collapsible chrome (title inline with back; shrinks on scroll).
            #expect(HomeLifetimeStatsLeaderboardPresentation.usesCollapsibleInlineTitleHeader)
        }

        @Test func homeLifetimeStatsLeaderboardLayout_podiumSlots_ordersClassicPodium() {
            #expect(HomeLifetimeStatsLeaderboardLayout.podiumSlots(entryCount: 1).map(\.rank) == [1])
            #expect(HomeLifetimeStatsLeaderboardLayout.podiumSlots(entryCount: 2).map(\.rank) == [2, 1])
            #expect(HomeLifetimeStatsLeaderboardLayout.podiumSlots(entryCount: 3).map(\.rank) == [2, 1, 3])
            #expect(HomeLifetimeStatsLeaderboardLayout.podiumSlots(entryCount: 0).isEmpty)
        }

        @Test func homeLifetimeStatsLeaderboardLayout_pedestalHeights_stepDownFromFirst() {
            #expect(
                HomeLifetimeStatsLeaderboardLayout.pedestalHeight(for: 1)
                    > HomeLifetimeStatsLeaderboardLayout.pedestalHeight(for: 2)
            )
            #expect(
                HomeLifetimeStatsLeaderboardLayout.pedestalHeight(for: 2)
                    > HomeLifetimeStatsLeaderboardLayout.pedestalHeight(for: 3)
            )
        }

        @Test func homeLifetimeStatsLeaderboardPresentation_divePodiumMetricLabel_formatsDepthAndDuration() {
            let dive = HomeDiveStatsInput(
                id: UUID(),
                maxDepthMeters: 30.48,
                durationMinutes: 52,
                diveSiteID: nil,
                diveNumberLabel: "#12",
                siteDisplayName: "Salt Pier"
            )

            let depth = HomeLifetimeStatsLeaderboardPresentation.divePodiumMetricLabel(
                dive: dive,
                kind: .deepestDives,
                unitSystem: .imperial
            )
            #expect(depth.contains("100"))

            let duration = HomeLifetimeStatsLeaderboardPresentation.divePodiumMetricLabel(
                dive: dive,
                kind: .longestDives,
                unitSystem: .imperial
            )
            #expect(duration == "52 min")
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

        @Test func homeLifetimeStatsLeaderboardPresentation_siteRowDisplayData_usesUserDiveSite() {
            let userSite = UserDiveSite(
                siteName: "Custom Reef",
                country: "Belize",
                region: "Lighthouse",
                bodyOfWater: "Caribbean Sea",
                latCoords: 17.2,
                longCoords: -87.5
            )
            let entry = HomeLifetimeStatsLeaderboardPresentation.SiteEntry(
                id: userSite.id.uuidString,
                rank: 1,
                siteID: userSite.id,
                name: "Custom Reef",
                visitCount: 3
            )

            let row = HomeLifetimeStatsLeaderboardPresentation.siteRowDisplayData(
                entry: entry,
                site: nil,
                userSite: userSite
            )
            #expect(row.displayName == "Custom Reef")
            #expect(row.country.contains("Belize") || row.listCountry.contains("Belize"))
            #expect(row.diveCountLabel == HomeLifetimeStatsPresentation.siteVisitLabel(count: 3))
            #expect(row.coordinateLine.contains("17"))
        }

        @Test func homeOverviewAggregateComputer_prefersLinkedUserSiteNameOverNewDiveDisplayName() {
            let diveID = UUID()
            let userSiteID = UUID()
            let activitySeed = LogbookActivitySnapshotSeed(
                id: diveID,
                kind: .scubaDive,
                sourceDiveId: nil,
                sourceActivityId: nil,
                startTime: Date(timeIntervalSinceReferenceDate: 0),
                maxDepthMeters: 18,
                swimDistanceMeters: nil,
                durationMinutes: 40,
                bottomTimeSeconds: nil,
                diveNumber: 1,
                diveNumberExplicitlyNone: false,
                displayName: "New Dive",
                formattedStartDateOnly: "Jan 1",
                resolvedSiteNameLowercased: nil,
                activityTagNames: [],
                buddyDisplayNames: [],
                previewMediaPhotoID: nil,
                linkedTripID: nil,
                previewMediaIsSnorkel: false
            )
            let input = HomeOverviewBuildInput(
                activitySeeds: [activitySeed],
                tripSeeds: [],
                diveSiteIDByActivityID: [diveID: userSiteID],
                linkedSiteDisplayNameByID: [userSiteID: "Custom Reef"],
                buddyTagSeeds: [],
                mediaPhotoSeeds: [],
                sightingSeeds: [],
                mediaBuddyTagSeeds: [],
                automaticallyRenumberDives: false,
                displayUnits: .metric,
                ownerProfileID: UUID(),
                selfBuddyID: nil,
                referenceDate: Date(timeIntervalSinceReferenceDate: 0)
            )

            let result = HomeOverviewAggregateComputer.build(from: input)
            #expect(result.diveStatsInputs[0].siteDisplayName == "Custom Reef")
            #expect(result.diveStatsInputs[0].diveSiteID == userSiteID)
            let topSites = HomeLifetimeStatsLeaderboardPresentation.topSites(dives: result.diveStatsInputs)
            #expect(topSites.count == 1)
            #expect(topSites[0].name == "Custom Reef")
            #expect(topSites[0].siteID == userSiteID)
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

        @Test func waterBubbleTimelineMode_pausedIsStaticFrame_unpausedIsAnimating() {
            #expect(WaterBubbleTimelineMode.resolve(reduceMotion: false, animationPaused: true) == .staticFrame)
            #expect(WaterBubbleTimelineMode.resolve(reduceMotion: false, animationPaused: false) == .animating)
        }

        @Test func waterBubbleTimelineMode_reduceMotionHidesBubbles() {
            #expect(WaterBubbleTimelineMode.resolve(reduceMotion: true, animationPaused: false) == .hidden)
            #expect(WaterBubbleTimelineMode.resolve(reduceMotion: true, animationPaused: true) == .hidden)
        }

        @Test func waterBubbleTimelineMode_description_matchesDiagnosticsTokens() {
            #expect(WaterBubbleTimelineMode.hidden.description == "hidden")
            #expect(WaterBubbleTimelineMode.staticFrame.description == "staticFrame")
            #expect(WaterBubbleTimelineMode.animating.description == "animating")
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
            @Test func homeCarouselLaunchPreload_matchesOwnerAndDailySeed() {
                let owner = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
                let seed = HomeMediaHighlightPresentation.dailySeed(ownerProfileID: owner)

                // Cross-launch preload is intentionally disabled so each launch can reshuffle.
                #expect(
                    !HomeCarouselLaunchPreloadPresentation.shouldPreloadStoredPicks(
                        storedOwnerProfileID: owner,
                        currentOwnerProfileID: owner,
                        storedSeed: seed,
                        currentSeed: seed
                    )
                )
                #expect(
                    !HomeCarouselLaunchPreloadPresentation.shouldPreloadStoredPicks(
                        storedOwnerProfileID: nil,
                        currentOwnerProfileID: owner,
                        storedSeed: nil,
                        currentSeed: seed
                    )
                )
            }
            @Test func homeCarouselLaunchPreload_entriesKeepPointersAndKinds() {
                let entries = HomeCarouselLaunchPreloadPresentation.entries(
                    from: [
                        (mediaKind: .video, libraryIdentifier: "VID/L0/001"),
                        (mediaKind: .image, libraryIdentifier: " IMG/L0/002 "),
                        (mediaKind: .video, libraryIdentifier: nil),
                        (mediaKind: .image, libraryIdentifier: "   "),
                    ]
                )
                #expect(entries.count == 2)
                #expect(entries[0] == .init(libraryIdentifier: "VID/L0/001", isVideo: true))
                #expect(entries[1] == .init(libraryIdentifier: "IMG/L0/002", isVideo: false))
            }
            @Test @MainActor
            func homeTabRootLayoutPresentation_defaultLifetimeGridSeam_includesBuddyBand() {
                let emptyLog = HomeTabRootLayoutPresentation.defaultLifetimeGridSeamInputs
                let withBuddies = HomeTabRootLayoutPresentation.seamInputs(showsBuddyLeaderboard: true)
                #expect(emptyLog == withBuddies)
                #expect(emptyLog.showsBuddyLeaderboard)
                #expect(
                    emptyLog.statsPanelContentHeight
                        == HomeLifetimeStatsPanelLayout.estimatedPanelContentHeight(showsBuddyLeaderboard: true)
                )
            }
}
