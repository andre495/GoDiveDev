//
//  ExploreMapTests.swift
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


struct ExploreMapTests {
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
            DiveActivitySiteAssociation.link(ownerDive, to: site)

            let otherDive = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 3_000),
                durationMinutes: 35,
                maxDepthMeters: 15
            )
            otherDive.ownerProfileID = otherOwnerID
            DiveActivitySiteAssociation.link(otherDive, to: site)

            // Relationship inverse removed — UUID-only site links. Helper returns empty by design.
            let filtered = ExploreDiveSiteDetailContentSnapshotBuilder.siteActivitiesFromRelationships(
                site: site,
                ownerProfileID: ownerID
            )
            #expect(filtered.isEmpty)
        }

        @Test func diveLocationMapPresentation_mapViewIdentity_changesWithCoordinate() {
            let diveID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let coord = DiveCoordinate(latitude: 12.08, longitude: -68.28)
            let without = DiveLocationMapPresentation.mapViewIdentity(activityID: diveID, coordinate: nil)
            let withCoord = DiveLocationMapPresentation.mapViewIdentity(activityID: diveID, coordinate: coord)
            #expect(without == "\(diveID.uuidString)-none")
            #expect(withCoord == "\(diveID.uuidString)-12.08,-68.28")
        }

        @Test func diveSitePresentation_listRecord_usesLoggedDiveCountForPinnedLabel() {
            let site = DiveSite(siteName: "Judy's Dream Belair", country: "Bonaire")
            let record = DiveSitePresentation.listRecord(for: site, loggedDiveCount: 12)
            #expect(record.divesLogged == "12")
            #expect(record.pinnedDiveCountLabel == "12 dives")

            let userSite = UserDiveSite(siteName: "Judy's Dream Belair", country: "Bonaire")
            let userRecord = DiveSitePresentation.listRecord(for: userSite, loggedDiveCount: 1)
            #expect(userRecord.divesLogged == "1")
            #expect(userRecord.pinnedDiveCountLabel == "1 dive")
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
            #expect(activity.diveSiteID == taggedSite.id)
        }

        @Test func diveSiteReferenceCatalog_prewarmBundledReference_populatesCache() {
            DiveSiteReferenceCatalog.resetCacheForTesting()
            DiveSiteReferenceCatalog.prewarmBundledReference()
            let count = DiveSiteReferenceCatalog.bundledReference().count
            #expect(count > 0)
            #expect(DiveSiteReferenceCatalog.bundledReferenceByID().count == count)
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

        @Test @MainActor func exploreReferenceSiteDetailContentPagerPresentation_singleTab() {
            #expect(ExploreReferenceSiteDetailContentPagerPresentation.pageCount == 1)
            #expect(ExploreReferenceSiteDetailContentPagerPresentation.defaultPage == .details)
        }

        @Test @MainActor func diveSiteCatalogLoader_loadsSortedCatalogOffMainActor() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let site = DiveSite(siteName: "Test Reef")
            context.insert(site)
            try context.save()

            let persistentIDs = await DiveSiteCatalogLoader.fetchSortedPersistentIDs(container: container)
            #expect(persistentIDs.count == 1)

            let bound = DiveSiteCatalogLoader.bindModels(persistentIDs: persistentIDs, modelContext: context)
            #expect(bound.count == 1)
            #expect(bound.first?.siteName == "Test Reef")
        }

        @Test func diveSiteReferenceCatalog_usesBundledDiveSitesResourceName() {
            #expect(DiveSiteReferenceCatalog.bundledResourceName == "dive_sites")
        }

        @Test @MainActor func diveSiteReferenceCDNCache_prefersDiskOverBundle() throws {
            DiveSiteReferenceCDNCache.removeForTesting()
            defer { DiveSiteReferenceCDNCache.removeForTesting() }

            let snapshots = [
                DiveSiteReferenceSnapshot(
                    id: "cdn-site-1",
                    name: "CDN Reef",
                    country: "Belize",
                    countryCode: "BZ",
                    latitude: 17.0,
                    longitude: -88.0,
                    maxDepthMeters: 30,
                    entry: "boat",
                    environment: "ocean",
                    topologies: [],
                    seaName: "Caribbean"
                ),
            ]
            let data = try JSONEncoder().encode(snapshots)
            try DiveSiteReferenceCDNCache.store(data: data)

            let loaded = DiveSiteReferenceCatalog.bundledReference()
            #expect(loaded.count == 1)
            #expect(loaded.first?.id == "cdn-site-1")
            #expect(loaded.first?.name == "CDN Reef")
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

        @Test func exploreDiveSiteListSearch_matchesNameAndPlace() {
            let site = DiveSite(siteName: "Salt Pier", country: "Bonaire", region: "Caribbean")
            #expect(ExploreDiveSiteListSearch.matches(site, query: "salt"))
            #expect(ExploreDiveSiteListSearch.matches(site, query: "bonaire"))
            #expect(ExploreDiveSiteListSearch.matches(site, query: "caribbean"))
            #expect(!ExploreDiveSiteListSearch.matches(site, query: "aruba"))
            #expect(ExploreDiveSiteListSearch.filtering([site], query: "pier").count == 1)
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

        @Test func exploreCatalogMapCameraFitPresentation_refitsOnlyWhenSiteIDSetChanges() {
            let a = UUID()
            let b = UUID()
            #expect(
                ExploreCatalogMapCameraFitPresentation.shouldRefitCamera(
                    previousSiteIDs: [],
                    nextSiteIDs: [a, b]
                )
            )
            #expect(
                !ExploreCatalogMapCameraFitPresentation.shouldRefitCamera(
                    previousSiteIDs: [a, b],
                    nextSiteIDs: [a, b]
                )
            )
            #expect(
                ExploreCatalogMapCameraFitPresentation.shouldRefitCamera(
                    previousSiteIDs: [a, b],
                    nextSiteIDs: [a]
                )
            )
        }

        @Test func exploreSiteScopeSessionCache_prewarmProducesNonEmptyAllSitesSnapshot() {
            ExploreSiteScopeSessionCache.resetForTesting()
            DiveSiteReferenceCatalog.resetCacheForTesting()
            ExploreSiteScopeSessionCache.prewarmReferenceSnapshot()
            let warm = ExploreSiteScopeSessionCache.cachedReferenceSnapshot()
            #expect(warm != nil)
            #expect((warm?.allSitesPlottableSites.count ?? 0) > 0)
            ExploreSiteScopeSessionCache.resetForTesting()
            DiveSiteReferenceCatalog.resetCacheForTesting()
        }

        @Test func exploreCatalogMapPinDensity_degenerateViewportYieldsNoPins_untilCoveredBySiteBounds() {
            let sites = (0..<40).map { index in
                ExploreCatalogMapPresentation.PlottedSite(
                    id: UUID(),
                    siteName: "Site \(index)",
                    coordinate: DiveCoordinate(
                        latitude: 10 + Double(index % 8) * 0.2,
                        longitude: -60 + Double(index / 8) * 0.2
                    )
                )
            }
            let degenerate = ExploreCatalogMapViewport(
                center: DiveCoordinate(latitude: 0, longitude: 0),
                latitudeSpan: 0,
                longitudeSpan: 0
            )
            #expect(ExploreCatalogMapPinDensity.visibleSiteIDs(sites: sites, viewport: degenerate).isEmpty)

            let coveringRegion = ExploreCatalogMapPresentation.boundingRegion(for: sites)
            #expect(coveringRegion != nil)
            let covering = ExploreCatalogMapViewport(
                center: DiveCoordinate(
                    latitude: coveringRegion!.centerLatitude,
                    longitude: coveringRegion!.centerLongitude
                ),
                latitudeSpan: coveringRegion!.latitudeDelta,
                longitudeSpan: coveringRegion!.longitudeDelta
            )
            #expect(!ExploreCatalogMapPinDensity.visibleSiteIDs(sites: sites, viewport: covering).isEmpty)
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
            #expect(ExploreCatalogMapPinLabelPolicy.policy(for: .logbook) == .progressiveZoomReveal)
            #expect(ExploreCatalogMapPinLabelPolicy.policy(for: .allSites) == .pinOnlyAlways)
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

            let rows = ExploreDiveSiteListDisplay.rowData(for: [rated, unrated])

            #expect(rows.count == 2)
            #expect(rows[0].displayName == "Salt Pier")
            #expect(rows[0].diveCountLabel == nil)
            #expect(rows[0].coordinateLine.contains("12.083"))
            #expect(rows[0].placeLine == "Bonaire · Caribbean")
            #expect(rows[1].diveCountLabel == nil)
            #expect(rows[1].coordinateLine == DiveSitePresentation.missingValue)
            #expect(rows[1].placeLine == "🇧🇿 Belize")
        }

        @Test func exploreDiveSiteListDisplay_plannedTripRow_omitsDiveCount() {
            let rated = DiveSite(
                siteName: "Salt Pier",
                country: "Bonaire",
                region: "Caribbean",
                siteRating: 4
            )
            let unrated = DiveSite(siteName: "Mystery Reef", country: "Belize")

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

        @Test func exploreSiteScopeCacheBackgroundBuild_matchesDirectMake() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let siteID = UUID()
            let linkedSite = DiveSite(id: siteID, siteName: "Salt Pier", latCoords: 12.08, longCoords: -68.28)
            context.insert(linkedSite)
            try context.save()

            let logbookIDs: Set<UUID> = [siteID]
            let direct = ExploreSiteScopeCache.make(
                catalog: [linkedSite],
                userSites: [],
                logbookSiteIDs: logbookIDs
            )
            let background = ExploreSiteScopeCacheBackgroundBuild.makeSnapshot(
                container: container,
                catalogPersistentIDs: [linkedSite.persistentModelID],
                userSitePersistentIDs: [],
                logbookSiteIDs: logbookIDs
            )
            #expect(background.hasLogbookSites == direct.hasLogbookSites)
            #expect(background.logbookPlottableSites.map(\.id) == direct.logbookPlottableSites.map(\.id))
            #expect(background.logbookListRows.map(\.displayName) == direct.logbookListRows.map(\.displayName))

            let owner = UserProfile(appleUserIdentifier: "explore-scope-fallback", displayName: "Explorer")
            context.insert(owner)
            let activity = DiveActivity(
                source: .manual,
                startTime: .now,
                durationMinutes: 30,
                maxDepthMeters: 12
            )
            activity.ownerProfileID = owner.id
            activity.diveSiteID = siteID
            context.insert(activity)
            try context.save()

            let fromOwnerFallback = ExploreSiteScopeCacheBackgroundBuild.makeSnapshot(
                container: container,
                catalogPersistentIDs: [linkedSite.persistentModelID],
                userSitePersistentIDs: [],
                logbookSiteIDs: [],
                ownerProfileID: owner.id
            )
            #expect(fromOwnerFallback.hasLogbookSites)
            #expect(fromOwnerFallback.logbookPlottableSites.contains(where: { $0.id == siteID }))
        }

        @Test func exploreCatalogMapPresentation_deduplicatingPlottableSites_keepsFirstOnDuplicateIDs() {
            let id = UUID()
            let first = ExploreCatalogMapPresentation.PlottedSite(
                id: id,
                siteName: "First",
                coordinate: DiveCoordinate(latitude: 12, longitude: -68),
                isVisited: true
            )
            let duplicate = ExploreCatalogMapPresentation.PlottedSite(
                id: id,
                siteName: "Duplicate",
                coordinate: DiveCoordinate(latitude: 13, longitude: -69),
                isVisited: false
            )
            let other = ExploreCatalogMapPresentation.PlottedSite(
                id: UUID(),
                siteName: "Other",
                coordinate: DiveCoordinate(latitude: 14, longitude: -70),
                isVisited: false
            )
            let deduped = ExploreCatalogMapPresentation.deduplicatingPlottableSites([first, duplicate, other])
            #expect(deduped.count == 2)
            #expect(deduped[0].siteName == "First")
            #expect(deduped[1].siteName == "Other")
            // Building a sitesByID map must not trap (Explore map sync path).
            let byID = Dictionary(godiveUniquingKeysWithValues: [first, duplicate, other].map { ($0.id, $0) })
            #expect(byID.count == 2)
            #expect(byID[id]?.siteName == "Duplicate")
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
            #expect(ExploreSiteScopePresentation.defaultScope(hasLoggedActivities: false) == .allSites)
            #expect(ExploreSiteScopePresentation.defaultScope(hasLoggedActivities: true) == .logbook)
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
                    == "🇧🇶 Caribbean Netherlands · Caribbean Sea"
            )
            #expect(ExploreDiveSiteListPresentation.listCountry(from: snapshot) == "Caribbean Netherlands")
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
            #expect(ExploreDiveSiteListDisplay.cityCountryLine(country: "Belize", region: "") == "🇧🇿 Belize")
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
            #expect(bonaire.pinnedLocationLine == "🇧🇶 Bonaire, Caribbean Netherlands")
            #expect(bonaire.pinnedDiveCountLabel == "0 dives")

            let belizeOnly = DiveSitePresentation.listRecord(
                for: DiveSite(siteName: "Blue Hole", country: "Belize")
            )
            #expect(belizeOnly.pinnedLocationLine == "🇧🇿 Belize")
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

        @Test func diveSiteCatalogMatcher_isUserEditableCatalogSite_excludesOpenDiveMapTagged() {
            let local = DiveSite(siteName: "My Spot")
            #expect(DiveSiteCatalogMatcher.isUserEditableCatalogSite(local))
            #expect(DiveSiteCatalogMatcher.isUserEditableCatalogSite(siteTags: []))

            let linked = DiveSite(
                siteName: "OpenDive Reef",
                siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "odm-123")]
            )
            #expect(!DiveSiteCatalogMatcher.isUserEditableCatalogSite(linked))
            #expect(
                !DiveSiteCatalogMatcher.isUserEditableCatalogSite(
                    siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "odm-123")]
                )
            )
        }

        @Test func exploreDiveSiteAddPresentation_chromeCopy() {
            #expect(ExploreDiveSiteAddPresentation.sheetTitle == "New dive site")
            #expect(ExploreDiveSiteAddPresentation.chromeAccessibilityLabel == "Add dive site")
            #expect(ExploreDiveSiteAddPresentation.chromeSystemImage == "plus")
            #expect(ExploreDiveSiteAddPresentation.chromeAccessibilityIdentifier == "Explore.AddDiveSite")
            #expect(ExploreDiveSiteAddPresentation.cancelAccessibilityIdentifier == "Explore.AddDiveSiteSheet.Cancel")
            #expect(ExploreDiveSiteAddPresentation.doneAccessibilityIdentifier == "Explore.AddDiveSiteSheet.Done")
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
            #expect(
                ExploreDiveSiteDetailContentPagerPresentation.pageSubtitle(for: .diveDetails)
                    == "Dive Details"
            )
            #expect(
                ExploreDiveSiteDetailContentPagerPresentation.pageSubtitle(for: .divesHere) == "Dives Here"
            )
            #expect(
                ExploreDiveSiteDetailContentPagerPresentation.pageSubtitle(for: .marineLifeHere)
                    == "Marine Life Here"
            )
            #expect(
                ExploreDiveSiteDetailContentPagerPresentation.pageSubtitle(for: .taggedMedia)
                    == "Tagged Media"
            )
            #expect(
                ExploreDiveSiteDetailContentPagerPresentation
                    .pageSubtitleAccessibilityIdentifier(for: .divesHere)
                    == "Explore.DiveSiteDetail.DivesHere.Subtitle"
            )
            #expect(
                ExploreReferenceSiteDetailContentPagerPresentation.pageSubtitle(for: .details) == "Details"
            )
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

        @Test func diveLocationMapPresentation_cameraDistanceMeters_interpolatesWithSheetHeight() {
            let large = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let minF = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let wide = DiveLocationMapPresentation.cameraDistanceMeters(
                sheetHeightFraction: minF,
                largeRestingFraction: large
            )
            let tight = DiveLocationMapPresentation.cameraDistanceMeters(
                sheetHeightFraction: large,
                largeRestingFraction: large
            )
            let mid = DiveLocationMapPresentation.cameraDistanceMeters(
                sheetHeightFraction: (minF + large) / 2,
                largeRestingFraction: large
            )
            #expect(wide > mid)
            #expect(mid > tight)
            #expect(abs(wide - DiveLocationMapPresentation.minimizedCameraDistanceMeters) < 1)
            #expect(abs(tight - DiveLocationMapPresentation.mediumCameraDistanceMeters) < 1)
        }

        @Test func diveLocationMapPresentation_cameraDistanceMeters_detentZoomSteps() {
            #expect(DiveLocationMapPresentation.minimizedCameraDistanceMeters == 6_200)
            #expect(DiveLocationMapPresentation.mediumCameraDistanceMeters == 1_200)
            #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .minimized) > DiveLocationMapPresentation.referenceCameraDistanceMeters)
            #expect(
                DiveLocationMapPresentation.cameraDistanceMeters(for: .minimized)
                    > DiveLocationMapPresentation.cameraDistanceMeters(for: .large)
            )
            #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .large) < DiveLocationMapPresentation.referenceCameraDistanceMeters)
            #expect(DiveLocationMapPresentation.cameraDistanceMeters(for: .large) == DiveLocationMapPresentation.cameraDistanceMeters(for: .large))
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
                cameraLayoutDetent: .large
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
                detent: .large,
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

        @Test func exploreScopeCacheAppearPresentation_skipsWarmUnchangedToken() {
            #expect(
                ExploreScopeCacheAppearPresentation.shouldRebuildScopeCacheOnAppear(
                    isCacheEmpty: true,
                    appliedSyncToken: nil,
                    currentSyncToken: "a"
                )
            )
            #expect(
                ExploreScopeCacheAppearPresentation.shouldRebuildScopeCacheOnAppear(
                    isCacheEmpty: false,
                    appliedSyncToken: nil,
                    currentSyncToken: "a"
                )
            )
            #expect(
                !ExploreScopeCacheAppearPresentation.shouldRebuildScopeCacheOnAppear(
                    isCacheEmpty: false,
                    appliedSyncToken: "a",
                    currentSyncToken: "a"
                )
            )
            #expect(
                ExploreScopeCacheAppearPresentation.shouldRebuildScopeCacheOnAppear(
                    isCacheEmpty: false,
                    appliedSyncToken: "a",
                    currentSyncToken: "b"
                )
            )
        }

        @Test @MainActor func exploreScopeCacheRebuildPresentation_allowsRebuildBeforeLiveDiveSnapshot() {
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldScheduleScopeCacheRebuild(
                    isExploreTabSelected: true
                )
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldScheduleScopeCacheRebuild(
                    isExploreTabSelected: false
                )
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldApplyDefaultSiteScope(
                    hasAppliedDefaultSiteScope: false,
                    hasReceivedLiveDiveSnapshot: false
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldApplyDefaultSiteScope(
                    hasAppliedDefaultSiteScope: false,
                    hasReceivedLiveDiveSnapshot: true
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldDeferDefaultLogbookScope(
                    desiredScope: .logbook,
                    logbookPlottableCount: 0
                )
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldDeferDefaultLogbookScope(
                    desiredScope: .logbook,
                    logbookPlottableCount: 2
                )
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldDeferDefaultLogbookScope(
                    desiredScope: .allSites,
                    logbookPlottableCount: 0
                )
            )
            // Latch wins over a transient empty live snapshot (do not flash All Sites).
            #expect(
                ExploreScopeCacheRebuildPresentation.hasLoggedActivities(
                    shouldMountLiveDiveQuery: true,
                    hasReceivedLiveDiveSnapshot: false,
                    liveActivityCount: 0,
                    latchedHasLoggedActivities: true
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.hasLoggedActivities(
                    shouldMountLiveDiveQuery: true,
                    hasReceivedLiveDiveSnapshot: true,
                    liveActivityCount: 0,
                    latchedHasLoggedActivities: true
                )
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldPaintAllSitesSessionSeed(
                    prefersLogbookDefault: true
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldPaintAllSitesSessionSeed(
                    prefersLogbookDefault: false
                )
            )
            // Prefer My Sites: wait only while rebuild in flight AND logbook pins are expected.
            #expect(
                ExploreScopeCacheRebuildPresentation.plottableSitesForDisplay(
                    siteScope: .logbook,
                    scopedSitesCount: 0,
                    allSitesCount: 10,
                    currentlyDisplayingSites: false,
                    prefersLogbookDefault: true,
                    isScopeCacheRebuildInFlight: true,
                    expectsLogbookPins: true
                ) == .keepWaitingForLogbook
            )
            // No logbook site links yet — fall back immediately (do not spin forever).
            #expect(
                ExploreScopeCacheRebuildPresentation.plottableSitesForDisplay(
                    siteScope: .logbook,
                    scopedSitesCount: 0,
                    allSitesCount: 10,
                    currentlyDisplayingSites: false,
                    prefersLogbookDefault: true,
                    isScopeCacheRebuildInFlight: true,
                    expectsLogbookPins: false
                ) == .useAllSitesFallback
            )
            // After rebuild finishes with empty My Sites, fall back — never hang on spinner.
            #expect(
                ExploreScopeCacheRebuildPresentation.plottableSitesForDisplay(
                    siteScope: .logbook,
                    scopedSitesCount: 0,
                    allSitesCount: 10,
                    currentlyDisplayingSites: false,
                    prefersLogbookDefault: true,
                    isScopeCacheRebuildInFlight: false,
                    expectsLogbookPins: true
                ) == .useAllSitesFallback
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldFallbackToAllSitesWhileLogbookEmpty(
                    prefersLogbookDefault: true,
                    isScopeCacheRebuildInFlight: true,
                    expectsLogbookPins: true
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldFallbackToAllSitesWhileLogbookEmpty(
                    prefersLogbookDefault: true,
                    isScopeCacheRebuildInFlight: true,
                    expectsLogbookPins: false
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldFallbackToAllSitesWhileLogbookEmpty(
                    prefersLogbookDefault: true,
                    isScopeCacheRebuildInFlight: false,
                    expectsLogbookPins: true
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldClearRebuildInFlight(
                    taskGeneration: 3,
                    activeGeneration: 3
                )
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldClearRebuildInFlight(
                    taskGeneration: 2,
                    activeGeneration: 3
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldShowMapLoadingPlaceholder(
                    displayedPlottableCount: 0,
                    isScopeCacheRebuildInFlight: true,
                    isCacheEmpty: false
                )
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldShowMapLoadingPlaceholder(
                    displayedPlottableCount: 0,
                    isScopeCacheRebuildInFlight: false,
                    isCacheEmpty: false
                )
            )
            // Empty cache alone must not spin forever when nothing is rebuilding.
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldShowMapLoadingPlaceholder(
                    displayedPlottableCount: 0,
                    isScopeCacheRebuildInFlight: false,
                    isCacheEmpty: true
                )
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldApplyScopePresentation(isCacheEmpty: true)
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.plottableSitesForDisplay(
                    siteScope: .logbook,
                    scopedSitesCount: 0,
                    allSitesCount: 10,
                    currentlyDisplayingSites: false
                ) == .useAllSitesFallback
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.plottableSitesForDisplay(
                    siteScope: .logbook,
                    scopedSitesCount: 0,
                    allSitesCount: 10,
                    currentlyDisplayingSites: true
                ) == .keepCurrentDisplay
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.plottableSitesForDisplay(
                    siteScope: .logbook,
                    scopedSitesCount: 3,
                    allSitesCount: 10,
                    currentlyDisplayingSites: false
                ) == .useScopedSites
            )
            #expect(
                !ExploreScopeCacheRebuildPresentation.shouldReplaceDisplayedPlottableSites(
                    incomingSitesEmpty: true,
                    currentlyDisplayingSites: true,
                    appliedSyncToken: "old",
                    currentSyncToken: "new"
                )
            )
            #expect(
                ExploreScopeCacheRebuildPresentation.shouldReplaceDisplayedPlottableSites(
                    incomingSitesEmpty: true,
                    currentlyDisplayingSites: true,
                    appliedSyncToken: "same",
                    currentSyncToken: "same"
                )
            )
        }

        @Test func diveSiteReferenceMatchIndex_exactName_matchesLinearScan() {
            let reference = [
                DiveSiteReferenceSnapshot(
                    id: "a",
                    name: "Salt Pier",
                    country: "BQ",
                    countryCode: "BQ",
                    latitude: 12.0835,
                    longitude: -68.283,
                    maxDepthMeters: 30,
                    entry: "shore",
                    environment: "ocean",
                    topologies: [],
                    seaName: ""
                ),
                DiveSiteReferenceSnapshot(
                    id: "b",
                    name: "Something Else",
                    country: "US",
                    countryCode: "US",
                    latitude: 25.0,
                    longitude: -80.0,
                    maxDepthMeters: 20,
                    entry: "boat",
                    environment: "ocean",
                    topologies: [],
                    seaName: ""
                ),
            ]
            let index = DiveSiteReferenceMatchIndex(reference: reference)
            let indexed = DiveSiteCatalogMatcher.bestReferenceMatch(
                importName: "Salt Pier",
                importCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833),
                index: index
            )
            let linear = DiveSiteCatalogMatcher.bestReferenceMatch(
                importName: "Salt Pier",
                importCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833),
                reference: reference
            )
            #expect(indexed?.snapshot.id == linear?.snapshot.id)
            #expect(indexed?.snapshot.id == "a")
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

        @Test func diveLocationMapPresentation_adjustedMapCenter_medium_shiftsSouthOfPin() {
            let coordinate = DiveCoordinate(latitude: 12, longitude: -68)
            let layoutHeight: CGFloat = 800
            let center = DiveLocationMapPresentation.adjustedMapCenter(
                for: coordinate,
                layoutHeight: layoutHeight,
                topObstructionHeight: 100,
                bottomContentMargin: layoutHeight * DiveActivityOverviewPanelMetrics.mediumHeightFraction,
                mapCameraDetent: .large
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
                mapCameraDetent: .large
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
                mapCameraDetent: .large
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

        @Test @MainActor func mapKitWarmup_shouldWarmUp_matchesUITestLaunchFlag() {
            #expect(MapKitWarmup.shouldWarmUp == !GoDiveUITestConfiguration.isActive)
        }

        @Test @MainActor func mapKitWarmup_warmUpIfNeeded_doesNotBlockCallerSynchronously() {
            guard MapKitWarmup.shouldWarmUp else { return }
            MapKitWarmup.resetForTesting()
            MapKitWarmup.warmUpIfNeeded()
            // Scheduling must not create / insert MKMapView on the caller's stack (tab-select path).
            #expect(!MapKitWarmup.didWarmUp)
        }

        @Test func diveSiteReferenceCatalog_bundledReferenceByID_keysMatchBundledReference() {
            DiveSiteReferenceCatalog.resetCacheForTesting()
            let list = DiveSiteReferenceCatalog.bundledReference()
            let byID = DiveSiteReferenceCatalog.bundledReferenceByID()
            // O(1) lookup dictionary must cover every reference row exactly once.
            #expect(byID.count == Set(list.map(\.id)).count)
            for snapshot in list {
                #expect(byID[snapshot.id]?.id == snapshot.id)
            }
            // Second call reuses the cached mapping.
            #expect(DiveSiteReferenceCatalog.bundledReferenceByID().count == byID.count)
        }

        @Test func diveSiteReferenceCatalog_concurrentAccessReturnsConsistentRows() async {
            // The search-index prewarm decodes the reference JSON off the main actor while other
            // callers may read the shared cache — concurrent access must stay consistent (lock-guarded).
            DiveSiteReferenceCatalog.resetCacheForTesting()
            let counts = await withTaskGroup(of: Int.self) { group in
                for _ in 0..<8 {
                    group.addTask {
                        DiveSiteReferenceCatalog.bundledReferenceByID().count
                    }
                }
                var results: [Int] = []
                for await count in group { results.append(count) }
                return results
            }
            #expect(Set(counts).count == 1)
            #expect(counts.first == DiveSiteReferenceCatalog.bundledReference().count)
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

        @Test func exploreMapChromeScrim_usesDeepOceanBaseInLightMode() {
            #expect(AppTheme.Colors.mapChromeScrimBase == AppTheme.Colors.surfaceGradientBottom)
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
                #expect(zoom < 4)
                #expect(DiveSiteCoordinatePickerPresentation.pickerLatitudeDelta >= 90)
            }
            @Test func diveSiteFormPresentation_countryPickerChrome() {
                #expect(DiveSiteFormPresentation.countryPlaceholder == "Select country")
                #expect(DiveSiteFormPresentation.countryFieldAccessibilityIdentifier == "DiveSiteForm.Country")
                #expect(DiveSiteFormPresentation.countryPickerCancelAccessibilityIdentifier == "DiveSiteForm.CountryPicker.Cancel")
                #expect(DiveSiteFormPresentation.countryPickerDoneAccessibilityIdentifier == "DiveSiteForm.CountryPicker.Done")
            }
            @Test func siteReportGraphExport_oneToOneWithActivityAndConditions() {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 9, minute: 40))!

                let siteID = UUID()
                let site = DiveSite(
                    id: siteID,
                    siteName: "SS Yongala",
                    country: "Australia",
                    region: "Queensland",
                    bodyOfWater: "Coral Sea",
                    siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "yongala")]
                )
                let dive = DiveActivity(
                    source: .manual,
                    startTime: start,
                    timeZoneOffsetSeconds: 10 * 3600,
                    durationMinutes: 42,
                    maxDepthMeters: 28,
                    waterTempAvgCelsius: 27.5,
                    diveCurrentStrength: .low,
                    diveVisibility: .great,
                    diveWaterType: .saltwater
                )
                dive.diveSiteID = siteID

                let reportId = "site-report-opaque-yongala"
                let payload = SiteReportGraphExport.payload(
                    from: dive,
                    contributionId: reportId,
                    catalogSites: [site]
                )
                #expect(payload != nil)
                guard let payload else { return }
                #expect(payload.contributionId == reportId)
                #expect(payload.activityKind == "dive")
                #expect(payload.reportedMaxDepthM == 28)
                #expect(payload.reportedCurrent == "low")
                #expect(payload.reportedVisibility == "great")
                #expect(payload.reportedWaterTempC == 27.5)
                #expect(payload.reportedWaterType == "saltwater")
                #expect(payload.country == "Australia")
                #expect(payload.waterBody == "Coral Sea")
                #expect(payload.odmSiteId == "yongala")
                #expect(payload.schemaVersion == SiteReportGraphExport.schemaVersion)

                let fields = SiteReportGraphExport.firestoreFields(from: payload)
                #expect(fields["kind"] as? String == "siteReport")
                #expect(fields["reportedMaxDepthM"] as? Double == 28)
                #expect(fields["siteName"] == nil)
                #expect(fields["uid"] == nil)

                let suiteName = "GoDiveSiteReportIds-\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                let activityUUID = dive.id
                let first = OntologySiteReportContributionSync.contributionId(
                    forActivityUUID: activityUUID,
                    userDefaults: defaults
                )
                let second = OntologySiteReportContributionSync.contributionId(
                    forActivityUUID: activityUUID,
                    userDefaults: defaults
                )
                #expect(first == second)
                #expect(first != reportId)

                // Sighting payload links to the same opaque SiteReport id.
                let sightingPayload = SightingGraphExport.payload(
                    sightingUUID: "s-1",
                    contributionId: "sight-contrib",
                    marineLifeUUID: "marine-life-tiger-shark",
                    sightingDateTime: start,
                    diveActivityID: activityUUID,
                    snorkelActivityID: nil,
                    diveSiteID: siteID,
                    sightingDepthMeters: 24,
                    catalogSites: [site],
                    siteReportId: first
                )
                #expect(sightingPayload?.siteReportId == first)
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
                        diveSiteID: siteID
                    ),
                    SightingInstance(
                        marineLifeUUID: angelfishUUID,
                        sightingDateTime: Date(timeIntervalSince1970: 1_000_100)),
                    SightingInstance(
                        marineLifeUUID: rayUUID,
                        sightingDateTime: Date(timeIntervalSince1970: 1_000_200)),
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
            @Test func diveSiteFormValidation_sanitizedPlaceField_trimsWhitespace() {
                #expect(DiveSiteFormValidation.sanitizedPlaceField("  Bonaire  ") == "Bonaire")
                #expect(DiveSiteFormValidation.sanitizedPlaceField("   ") == "")
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
            @Test func goDiveMapEngine_defaultsToMapKit_withoutLaunchArgumentOrSecrets() {
                #expect(
                    GoDiveMapEngine.resolved(activeLaunchArguments: [], hasGoogleMapsAPIKey: false) == .mapKit
                )
                #expect(
                    GoDiveMapEngine.resolved(activeLaunchArguments: ["-GoDiveUITest"], hasGoogleMapsAPIKey: false)
                        == .mapKit
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
            @Test func goDiveMapPointOfInterestSuppression_googleStyleJSON_parses() {
                let data = Data(GoDiveMapPointOfInterestSuppression.googleMapsSuppressPOIStyleJSON.utf8)
                let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                #expect(json != nil)
                #expect(json?.contains { ($0["featureType"] as? String) == "poi.business" } == true)
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
            @Test func diveSiteCountryPresentation_flagEmoji_mapsCommonCatalogCountries() {
                #expect(DiveSiteCountryPresentation.flagEmoji(forCountryName: "United States") == "🇺🇸")
                #expect(DiveSiteCountryPresentation.flagEmoji(forISORegionCode: "US") == "🇺🇸")
                #expect(DiveSiteCountryPresentation.flagEmoji(forCountryName: "Caribbean Netherlands") == "🇧🇶")
                #expect(DiveSiteCountryPresentation.prefixedWithFlagEmoji("Midway, Utah, United States", countryName: "United States")
                    == "🇺🇸 Midway, Utah, United States")
            }
            @Test func diveSiteCountryPresentation_selectableCountries_includesFlagMappedISORegions() {
                let countries = DiveSiteCountryPresentation.selectableCountries()
                #expect(countries.count > 100)
                #expect(countries.contains(where: { $0.name == "United States" && $0.flagEmoji == "🇺🇸" }))
                #expect(countries.contains(where: {
                    $0.name == DiveSiteCountryPresentation.caribbeanNetherlands && $0.flagEmoji == "🇧🇶"
                }))
                #expect(countries.map(\.name) == countries.map(\.name).sorted {
                    $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
                })

                #expect(
                    DiveSiteCountryPresentation.matchesSelectableCountry(
                        DiveSiteSelectableCountry(
                            name: DiveSiteCountryPresentation.caribbeanNetherlands,
                            isoRegionCode: "BQ",
                            flagEmoji: "🇧🇶"
                        ),
                        query: "dutch"
                    )
                )
                #expect(
                    DiveSiteCountryPresentation.matchesSelectableCountry(
                        DiveSiteSelectableCountry(
                            name: DiveSiteCountryPresentation.caribbeanNetherlands,
                            isoRegionCode: "BQ",
                            flagEmoji: "🇧🇶"
                        ),
                        query: "bonaire"
                    )
                )

                let withLegacy = DiveSiteCountryPresentation.selectableCountries(
                    includingSelected: ["Bonaire Reef Week"]
                )
                #expect(withLegacy.contains(where: { $0.name == "Bonaire Reef Week" }))
            }
            @Test func diveSiteFormValidation_parsedOptionalMaxDepthMeters() {
                #expect(DiveSiteFormValidation.parsedOptionalMaxDepthMeters("") == .none)
                #expect(DiveSiteFormValidation.parsedOptionalMaxDepthMeters("  ") == .none)
                #expect(DiveSiteFormValidation.parsedOptionalMaxDepthMeters("18") == .value(18))
                #expect(DiveSiteFormValidation.parsedOptionalMaxDepthMeters("-1") == .invalid)
                #expect(DiveSiteFormValidation.parsedOptionalMaxDepthMeters("abc") == .invalid)
                #expect(!DiveSiteFormValidation.canSave(draft: DiveSiteFormDraft(
                    siteName: "Reef",
                    country: "",
                    region: "",
                    bodyOfWater: "",
                    latitudeText: "",
                    longitudeText: "",
                    maxDepthMetersText: "nope"
                )))
            }
            @Test func diveMapCoordinateResolver_rejectsNullIsland() {
                #expect(!DiveMapCoordinateResolver.isUsable(DiveCoordinate(latitude: 0, longitude: 0)))
            }
}
