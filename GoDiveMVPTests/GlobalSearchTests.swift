//
//  GlobalSearchTests.swift
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


struct GlobalSearchTests {
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
                snorkels: [],
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
                    snorkels: [],
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

        @Test func globalSearchCatalogWarming_fingerprintReflectsOwnerAndCounts() {
            let ownerA = UUID()
            let ownerB = UUID()
            let baseline = GlobalSearchCatalogWarming.fingerprint(
                ownerProfileID: ownerA,
                dives: [],
                snorkels: [],
                diveSites: [],
                speciesCatalog: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: []
            )
            #expect(baseline == "\(ownerA.uuidString)|0|0|0|0|0|0|0|0|0")
            // No owner falls back to a stable sentinel rather than empty.
            let noOwner = GlobalSearchCatalogWarming.fingerprint(
                ownerProfileID: nil,
                dives: [],
                snorkels: [],
                diveSites: [],
                speciesCatalog: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: []
            )
            #expect(noOwner == "none|0|0|0|0|0|0|0|0|0")
            // A different owner changes the cache key so warmed catalogs never leak across profiles.
            #expect(baseline != GlobalSearchCatalogWarming.fingerprint(
                ownerProfileID: ownerB,
                dives: [],
                snorkels: [],
                diveSites: [],
                speciesCatalog: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: []
            ))
        }

        @MainActor
        @Test func globalSearchCatalogWarming_ensureCatalogCachesByFingerprint() {
            let store = GlobalSearchCatalogStore()
            #expect(store.catalog == nil)
            #expect(store.fingerprint.isEmpty)

            let ownerID = UUID()
            _ = GlobalSearchCatalogWarming.ensureCatalog(
                store: store,
                ownerProfileID: ownerID,
                dives: [],
                snorkels: [],
                diveSites: [],
                speciesCatalog: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: [],
                unitSystem: .metric
            )
            #expect(store.catalog != nil)
            let warmedFingerprint = store.fingerprint
            #expect(!warmedFingerprint.isEmpty)

            // A second call with identical inputs must reuse the warmed cache (fingerprint unchanged),
            // so a category tile tap after warming skips the expensive index rebuild.
            _ = GlobalSearchCatalogWarming.ensureCatalog(
                store: store,
                ownerProfileID: ownerID,
                dives: [],
                snorkels: [],
                diveSites: [],
                speciesCatalog: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: [],
                unitSystem: .metric
            )
            #expect(store.fingerprint == warmedFingerprint)
        }

        @MainActor
        @Test func globalSearchCatalogWarming_ensureCatalogAsyncCachesByFingerprint() async {
            let store = GlobalSearchCatalogStore()
            let ownerID = UUID()
            _ = await GlobalSearchCatalogWarming.ensureCatalogAsync(
                store: store,
                ownerProfileID: ownerID,
                dives: [],
                snorkels: [],
                diveSites: [],
                speciesCatalog: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: [],
                unitSystem: .metric
            )
            let warmedFingerprint = store.fingerprint
            #expect(store.catalog != nil)
            #expect(!warmedFingerprint.isEmpty)

            _ = await GlobalSearchCatalogWarming.ensureCatalogAsync(
                store: store,
                ownerProfileID: ownerID,
                dives: [],
                snorkels: [],
                diveSites: [],
                speciesCatalog: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: [],
                unitSystem: .metric
            )
            #expect(store.fingerprint == warmedFingerprint)
        }

        @Test func globalSearchCatalogBuild_fromCaptureInput_indexesDiveNotesAndSites() {
            let diveID = UUID()
            let siteID = UUID()
            let seed = LogbookActivitySnapshotSeed(
                id: diveID,
                kind: .scubaDive,
                sourceDiveId: nil,
                sourceActivityId: nil,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                maxDepthMeters: 18,
                swimDistanceMeters: nil,
                durationMinutes: 45,
                bottomTimeSeconds: nil,
                diveNumber: 7,
                diveNumberExplicitlyNone: false,
                displayName: "Salt Pier",
                formattedStartDateOnly: "Nov 14, 2023",
                resolvedSiteNameLowercased: "salt pier",
                activityTagNames: ["night"],
                buddyDisplayNames: ["Pat"],
                previewMediaPhotoID: nil,
                linkedTripID: nil,
                previewMediaIsSnorkel: false
            )
            let extras = GlobalSearchActivitySearchExtras(
                marineLifeCommonNames: ["French Angelfish"],
                tripTitles: ["Bonaire 2023"],
                countrySearchValue: "bonaire netherlands antilles",
                countryDisplay: "Bonaire",
                region: "Kralendijk",
                notes: "Saw a turtle at the pier"
            )
            let siteSeed = GlobalSearchDiveSiteSeed(
                id: siteID,
                siteName: "Salt Pier",
                country: "Bonaire",
                region: "Kralendijk",
                bodyOfWater: "Caribbean Sea",
                siteTags: []
            )
            let catalog = GlobalSearchCatalogBuild.build(
                from: GlobalSearchCatalogBuildInput(
                    ownerProfileID: UUID(),
                    diveSeeds: [seed],
                    diveExtrasByID: [diveID: extras],
                    snorkelSeeds: [],
                    snorkelExtrasByID: [:],
                    diveSites: [siteSeed],
                    logbookSiteIDs: [siteID],
                    speciesSnapshots: [],
                    buddies: [],
                    tags: [],
                    trips: [],
                    equipment: [],
                    certifications: []
                )
            )
            #expect(catalog.dives.count == 1)
            #expect(catalog.dives[0].searchHaystack.contains("turtle"))
            #expect(catalog.dives[0].searchHaystack.contains("french angelfish"))
            #expect(catalog.dives[0].matchFields.contains(where: { $0.label == "Notes" }))
            #expect(catalog.diveSites.contains(where: { $0.title == "Salt Pier" }))
        }

        @Test func globalSearchSiteIndexSeeding_entriesFromSeeds_matchModelPathCoverage() {
            let reference = DiveSiteReferenceSnapshot(
                id: "salt01",
                name: "Salt Pier",
                country: "Bonaire",
                countryCode: "BQ",
                latitude: 12.0835,
                longitude: -68.283,
                maxDepthMeters: 30,
                entry: "shore",
                environment: "ocean",
                topologies: [],
                seaName: "Caribbean Sea"
            )
            let catalogSiteID = UUID()
            let localOnlySiteID = UUID()
            let seeds = [
                GlobalSearchDiveSiteSeed(
                    id: catalogSiteID,
                    siteName: "Salt Pier (mine)",
                    country: "Bonaire",
                    region: "",
                    bodyOfWater: "",
                    siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt01")]
                ),
                GlobalSearchDiveSiteSeed(
                    id: localOnlySiteID,
                    siteName: "Secret Spot",
                    country: "",
                    region: "",
                    bodyOfWater: "",
                    siteTags: []
                ),
            ]
            let entries = GlobalSearchSiteIndexSeeding.entries(
                diveSites: seeds,
                logbookSiteIDs: [localOnlySiteID],
                reference: [reference]
            )
            #expect(entries.count == 2)
            #expect(
                entries.contains {
                    if case .diveSite(let siteID) = $0.destination {
                        return siteID == catalogSiteID && $0.title == "Salt Pier (mine)"
                    }
                    return false
                }
            )
            #expect(
                entries.contains {
                    if case .diveSite(let siteID) = $0.destination {
                        return siteID == localOnlySiteID && $0.title == "Secret Spot"
                    }
                    return false
                }
            )
        }

        @Test func globalSearchMediaBrowse_coreDataTokenStripsSpeciesComponent() {
            #expect(
                GlobalSearchMediaBrowsePresentation.coreDataToken(fromRefreshToken: "12|3|45|2|1318")
                    == "12|3|45|2"
            )
            // Empty components survive so `a||c|d|0` and `a|b|c|d|0` never collide after stripping.
            #expect(
                GlobalSearchMediaBrowsePresentation.coreDataToken(fromRefreshToken: "12||45|2|0")
                    == "12||45|2"
            )
        }

        @Test func globalSearchMediaBrowse_prewarmedSnapshotReuseRules() {
            // Exact token match always reuses.
            #expect(
                GlobalSearchMediaBrowsePresentation.canReusePrewarmedSnapshot(
                    storeToken: "12|3|45|2|1318",
                    currentToken: "12|3|45|2|1318",
                    isSpeciesCatalogLoaded: true
                )
            )
            // While the browse's species catalog is still loading, a core match (all counts except
            // species) reuses the warm snapshot — the warmer built it with species names included.
            #expect(
                GlobalSearchMediaBrowsePresentation.canReusePrewarmedSnapshot(
                    storeToken: "12|3|45|2|1318",
                    currentToken: "12|3|45|2|0",
                    isSpeciesCatalogLoaded: false
                )
            )
            // Once species are loaded, only an exact match reuses (species count is real data then).
            #expect(
                !GlobalSearchMediaBrowsePresentation.canReusePrewarmedSnapshot(
                    storeToken: "12|3|45|2|1318",
                    currentToken: "12|3|45|2|900",
                    isSpeciesCatalogLoaded: true
                )
            )
            // Underlying data changed (dive/media/tag counts differ) — never reuse.
            #expect(
                !GlobalSearchMediaBrowsePresentation.canReusePrewarmedSnapshot(
                    storeToken: "12|3|45|2|1318",
                    currentToken: "13|3|45|2|0",
                    isSpeciesCatalogLoaded: false
                )
            )
            // Nothing prewarmed yet.
            #expect(
                !GlobalSearchMediaBrowsePresentation.canReusePrewarmedSnapshot(
                    storeToken: "",
                    currentToken: "12|3|45|2|0",
                    isSpeciesCatalogLoaded: false
                )
            )
        }

        @Test @MainActor func globalSearchMediaSnapshotStore_holdsPrewarmedCacheForBrowseOpen() {
            let store = GlobalSearchMediaSnapshotStore()
            #expect(store.displayCache == nil)
            #expect(store.dataToken.isEmpty)

            let input = GlobalSearchMediaIndexSnapshotBuilder.CaptureInput(
                dives: [],
                buddyTags: [],
                sightings: [],
                catalogTagNames: [],
                catalogBuddyNames: [],
                catalogTrips: [],
                catalogSpeciesNames: []
            )
            let built = GlobalSearchMediaBrowsePresentation.displayCache(
                from: input,
                filter: GlobalSearchMediaBrowsePresentation.ResolvedFilter()
            )
            store.displayCache = built
            store.dataToken = "0|0|0|0|0"

            #expect(store.displayCache?.filterFingerprint == "")
            #expect(
                GlobalSearchMediaBrowsePresentation.canReusePrewarmedSnapshot(
                    storeToken: store.dataToken,
                    currentToken: "0|0|0|0|0",
                    isSpeciesCatalogLoaded: true
                )
            )
        }

        @Test func globalSearchTabLaunch_warmIndexMountWaitsOutTabMorphButUserActionsMountImmediately() {
            // Deferred warm mount must wait out the tab-open morph (a bare yield dropped opening frames)…
            #expect(GlobalSearchPresentation.searchIndexWarmMountDelayNanoseconds >= 300_000_000)
            // …while an active search or pushed detail still mounts the index immediately.
            #expect(
                GlobalSearchTabLaunchPresentation.shouldMountSearchIndexImmediately(
                    isSearchActive: true,
                    pathDepth: 0
                )
            )
            #expect(
                GlobalSearchTabLaunchPresentation.shouldMountSearchIndexImmediately(
                    isSearchActive: false,
                    pathDepth: 1
                )
            )
            #expect(
                !GlobalSearchTabLaunchPresentation.shouldMountSearchIndexImmediately(
                    isSearchActive: false,
                    pathDepth: 0
                )
            )
        }

        @MainActor
        @Test func globalSearchResultRowContentBuilder_tagHitUsesHitFieldsAndTagArtwork() {
            let hit = GlobalSearchPresentation.Hit(
                id: "tag-1",
                title: "Night dive",
                subtitle: "3 dives",
                systemImage: "tag.fill",
                destination: .tag(UUID()),
                accessibilityIdentifier: "GlobalSearch.Result.tag-1"
            )
            let contents = GlobalSearchResultRowContentBuilder.rowContents(
                hits: [hit],
                ownerProfileID: nil,
                ownerDives: [],
                ownerSnorkels: [],
                diveSites: [],
                speciesCatalog: [],
                ownerDiveBuddies: [],
                ownerTrips: [],
                ownerEquipment: [],
                ownerCertifications: [],
                unitSystem: .metric,
                useChronologicalNumbers: false
            )
            #expect(contents.count == 1)
            #expect(contents[0].id == "tag-1")
            #expect(contents[0].accessibilityIdentifier == "GlobalSearch.Result.tag-1")
            guard case .standard(let title, let subtitle, let artwork) = contents[0].kind else {
                Issue.record("Expected standard row kind")
                return
            }
            #expect(title == "Night dive")
            #expect(subtitle == "3 dives")
            #expect(artwork == .symbol("tag.fill"))
        }

        @MainActor
        @Test func globalSearchResultRowContentBuilder_missingModelFallsBackToHitFields() {
            // A buddy hit whose model isn't in the provided arrays must fall back to the hit's own
            // title/subtitle/symbol rather than dropping the row.
            let hit = GlobalSearchPresentation.Hit(
                id: "buddy-x",
                title: "Unknown Buddy",
                subtitle: "buddy subtitle",
                systemImage: "person.fill",
                destination: .buddy(UUID()),
                accessibilityIdentifier: "GlobalSearch.Result.buddy-x"
            )
            let contents = GlobalSearchResultRowContentBuilder.rowContents(
                hits: [hit],
                ownerProfileID: UUID(),
                ownerDives: [],
                ownerSnorkels: [],
                diveSites: [],
                speciesCatalog: [],
                ownerDiveBuddies: [],
                ownerTrips: [],
                ownerEquipment: [],
                ownerCertifications: [],
                unitSystem: .metric,
                useChronologicalNumbers: false
            )
            guard case .standard(let title, let subtitle, let artwork) = contents.first?.kind else {
                Issue.record("Expected standard fallback row kind")
                return
            }
            #expect(title == "Unknown Buddy")
            #expect(subtitle == "buddy subtitle")
            #expect(artwork == .symbol("person.fill"))
        }

        @Test func globalSearchPresentation_emptyQueryReturnsNoSections() {
            let catalog = GlobalSearchPresentation.Catalog(
                dives: [],
                snorkels: [],
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
                snorkels: [],
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
                snorkels: [],
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

        @Test func globalSearchPresentation_typedQueryReturnsAllMatchesNotCappedAtTwelve() {
            let matchingDives = (0..<15).map { index in
                GlobalSearchPresentation.DiveIndexEntry(
                    id: UUID(),
                    title: "Reef Dive #\(index)",
                    subtitle: "Blue Reef",
                    searchHaystack: "reef dive blue reef"
                )
            }
            let catalog = GlobalSearchPresentation.Catalog(
                dives: matchingDives,
                snorkels: [],
                diveSites: [
                    GlobalSearchPresentation.DiveSiteIndexEntry(
                        title: "Reef Wall",
                        subtitle: "Bonaire",
                        searchHaystacks: ["Reef Wall"],
                        destination: .diveSite(UUID())
                    ),
                ],
                species: [],
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: []
            )

            let results = GlobalSearchPresentation.search(catalog: catalog, query: "reef")
            let diveSection = results.sections.first { $0.kind == .dives }
            // Typed multi-category search no longer truncates dives at 12 — all 15 matches come back.
            #expect(diveSection?.hits.count == 15)
            #expect(results.sections.contains { $0.kind == .diveSites })
        }

        @Test func globalSearchPresentation_returnsAllMatchesBeyondFormerFiveHundredCap() {
            let siteCount = 501
            let speciesCount = 501
            let diveSites = (0..<siteCount).map { index in
                GlobalSearchPresentation.DiveSiteIndexEntry(
                    title: "Coral Site \(index)",
                    subtitle: "Test Region",
                    searchHaystacks: ["Coral Site \(index)"],
                    destination: .diveSite(UUID())
                )
            }
            let species = (0..<speciesCount).map { index in
                GlobalSearchPresentation.SpeciesIndexEntry(
                    uuid: "species-\(index)",
                    title: "Coral Fish \(index)",
                    subtitle: nil,
                    searchText: "coral fish \(index)"
                )
            }
            let catalog = GlobalSearchPresentation.Catalog(
                dives: [],
                snorkels: [],
                diveSites: diveSites,
                species: species,
                buddies: [],
                tags: [],
                trips: [],
                equipment: [],
                certifications: []
            )

            let results = GlobalSearchPresentation.search(catalog: catalog, query: "coral")
            let siteSection = results.sections.first { $0.kind == .diveSites }
            let speciesSection = results.sections.first { $0.kind == .species }
            #expect(siteSection?.hits.count == siteCount)
            #expect(speciesSection?.hits.count == speciesCount)
        }

        @Test func globalSearchResultsDismissPresentation_engagesOnlyForHorizontalEdgeSwipe() {
            // A vertical scroll that starts near the leading edge must NOT engage the slide-back (otherwise scroll freezes).
            #expect(!GlobalSearchResultsDismissPresentation.shouldEngageDismissDrag(
                startLocationX: 12,
                translation: CGSize(width: 4, height: 120)
            ))
            // A clearly horizontal, rightward swipe from the leading edge engages the dismiss.
            #expect(GlobalSearchResultsDismissPresentation.shouldEngageDismissDrag(
                startLocationX: 12,
                translation: CGSize(width: 90, height: 12)
            ))
            // A drag that begins away from the leading edge never engages.
            #expect(!GlobalSearchResultsDismissPresentation.shouldEngageDismissDrag(
                startLocationX: 220,
                translation: CGSize(width: 90, height: 12)
            ))
            // A leftward drag never engages.
            #expect(!GlobalSearchResultsDismissPresentation.shouldEngageDismissDrag(
                startLocationX: 12,
                translation: CGSize(width: -90, height: 12)
            ))
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
            // Pinned section headers center on the back-button row (even with the back arrow), not below the chrome band.
            let expectedTopMargin = layout.backButtonRowTopPadding
                + layout.backButtonTapWidth / 2
                - (layout.verticalPadding + layout.titleFontSize / 2)
            #expect(layout.scrollContentTopMargin() == expectedTopMargin)
            #expect(layout.scrollContentTopMargin() == 12)
            #expect(layout.scrollContentTopMargin() < layout.backButtonTapWidth)
            #expect(layout.scrollContentTopMarginBelowChrome(chromeHeight: 44) == 44)
            #expect(layout.scrollContentTopMarginBelowChrome(chromeHeight: 0) == 0)
            #expect(layout.scrollContentTopMarginBelowChrome(chromeHeight: -8) == 0)
            // Count-title chrome (Media / scoped) pins below the row; multi-category pins on the back button.
            #expect(layout.scrollContentTopMarginBelowChrome(chromeHeight: 44) > layout.scrollContentTopMargin())
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
            #expect(GlobalSearchPushedDestinationPresentation.attachesStackSearch(path: []))
            #expect(!GlobalSearchPushedDestinationPresentation.attachesStackSearch(path: [.dive(UUID())]))
            #expect(
                !GlobalSearchPushedDestinationPresentation.attachesStackSearch(
                    path: [.trip(UUID()), .dive(UUID())]
                )
            )
        }

        @Test func globalSearchPresentation_isMediaScopeOnlyForLoneMediaToken() {
            #expect(GlobalSearchPresentation.isMediaScope([.media]))
            #expect(!GlobalSearchPresentation.isMediaScope([]))
            #expect(!GlobalSearchPresentation.isMediaScope([.dives]))
            #expect(!GlobalSearchPresentation.isMediaScope([.media, .dives]))
        }

        @Test func globalSearchPushedDestinationPresentation_dismissesSearchBeforePathAppend() {
            #expect(
                GlobalSearchPushedDestinationPresentation.shouldDismissSearchBeforePathAppend(
                    destination: .dive(UUID()),
                    currentPathDepth: 0
                )
            )
            #expect(
                GlobalSearchPushedDestinationPresentation.shouldDismissSearchBeforePathAppend(
                    destination: .dive(UUID()),
                    currentPathDepth: 1
                )
            )
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

        @Test func globalSearchIndexLayer_onlyVisibleResultsLayerCancelsSharedSearchTaskOnDisappear() {
            // The hidden warmer shares the `searchTask` binding; if its unmount cancelled the task, the
            // refresh scheduled by the remounted results layer on pop-from-detail died and every text
            // section stayed empty (Media survived on per-instance tasks).
            #expect(
                GlobalSearchIndexLayerPresentation.cancelsSharedSearchTaskOnDisappear(rendersResultsBody: true)
            )
            #expect(
                !GlobalSearchIndexLayerPresentation.cancelsSharedSearchTaskOnDisappear(rendersResultsBody: false)
            )
        }

        @Test func globalSearchIndexLayer_keepsDisplayedResultsWhileDetailPushPreservesSession() {
            // `dismissSearch()` on a detail push transiently clears the query; the preserved session must
            // keep the results the user pops back to.
            #expect(
                !GlobalSearchIndexLayerPresentation.shouldClearResultsForInactiveSearch(
                    preservesResultsSessionForDetailPush: true
                )
            )
            #expect(
                GlobalSearchIndexLayerPresentation.shouldClearResultsForInactiveSearch(
                    preservesResultsSessionForDetailPush: false
                )
            )
        }

        @Test @MainActor func globalSearchIndexLayer_canPatchRowContentsMatchReasonsOnly_whenHitIDsStable() {
            let hitA = GlobalSearchPresentation.Hit(
                id: "dive-1",
                title: "Pier",
                subtitle: nil,
                systemImage: "water.waves",
                destination: .dive(UUID()),
                accessibilityIdentifier: "hit-1",
                matchReasons: [.init(label: "Buddy", text: "Pat")]
            )
            let hitB = GlobalSearchPresentation.Hit(
                id: "dive-1",
                title: "Pier",
                subtitle: nil,
                systemImage: "water.waves",
                destination: hitA.destination,
                accessibilityIdentifier: "hit-1",
                matchReasons: [.init(label: "Notes", text: "turtle")]
            )
            #expect(
                GlobalSearchIndexLayerPresentation.canPatchRowContentsMatchReasonsOnly(
                    existingIDs: ["dive-1"],
                    hits: [hitB]
                )
            )
            #expect(
                !GlobalSearchIndexLayerPresentation.canPatchRowContentsMatchReasonsOnly(
                    existingIDs: ["dive-1"],
                    hits: [hitA, hitB]
                )
            )
            let patched = GlobalSearchResultRowContent(
                id: "dive-1",
                destination: hitA.destination,
                accessibilityIdentifier: "hit-1",
                matchReasons: hitA.matchReasons,
                kind: .standard(title: "Pier", subtitle: nil, artwork: .symbol("water.waves"))
            ).replacingMatchReasons(hitB.matchReasons)
            #expect(patched.matchReasons == hitB.matchReasons)
            #expect(patched.kind == .standard(title: "Pier", subtitle: nil, artwork: .symbol("water.waves")))
        }

        @Test func globalSearchIndexLayer_keystrokeDebounce_isLongerThanCatalogListDebounce() {
            #expect(
                GlobalSearchIndexLayerPresentation.keystrokeDebounceNanoseconds
                    > CatalogSearchPresentation.debounceNanoseconds
            )
        }

        @Test func globalSearchPresentation_stackSearchRestoreDismissesKeyboardAfterPresentation() {
            // Popping back to results re-presents the morphed field (which focuses it); the keyboard
            // resign must wait out the presentation so the field stays open but unfocused.
            #expect(GlobalSearchPresentation.stackSearchRestoreKeyboardDismissDelayNanoseconds > 0)
            #expect(
                GlobalSearchPresentation.stackSearchRestoreKeyboardDismissDelayNanoseconds
                    >= GlobalSearchPresentation.stackSearchRestoreDelayNanoseconds
            )
        }

        @Test func globalSearchPresentation_stackSearchRestorePresentsAfterPopTransitionSettles() {
            // Presenting the morphed field mid pop-transition (nav pop + returning tab bar) is swallowed
            // by the toolbar machinery — the present must wait out the whole transition (~0.35 s pop).
            #expect(GlobalSearchPresentation.stackSearchRestoreAfterPopDelayNanoseconds >= 400_000_000)
            #expect(
                GlobalSearchPresentation.stackSearchRestoreAfterPopDelayNanoseconds
                    > GlobalSearchPresentation.stackSearchRestoreDelayNanoseconds
            )
        }

        @Test func globalSearchPushedDestinationPresentation_keepsResultsPanelThroughPreservedSessionBlips() {
            // `.searchable` dismiss/reattach around a detail push transiently clears the query — the
            // results panel must survive those blips while the session is preserved; a genuine user clear
            // (no preserved session) still dismisses it.
            #expect(
                GlobalSearchPushedDestinationPresentation.keepsResultsPanelThroughInactiveSearch(
                    preservedSessionIsActive: true
                )
            )
            #expect(
                !GlobalSearchPushedDestinationPresentation.keepsResultsPanelThroughInactiveSearch(
                    preservedSessionIsActive: false
                )
            )
        }

        @Test func globalSearchPresentation_contextTokens_coverMainConceptsInOrder() {
            let tokens = GlobalSearchPresentation.ContextToken.allCases
            #expect(tokens.count == 10)
            #expect(tokens.map(\.title) == [
                "Dives",
                "Snorkels",
                "Buddies",
                "Sites",
                "Marine life",
                "Tags",
                "Gear",
                "Trips",
                "Certifications",
                "Media",
            ])
            #expect(tokens.map(\.accessibilityIdentifier) == [
                "GlobalSearch.ContextToken.dives",
                "GlobalSearch.ContextToken.snorkels",
                "GlobalSearch.ContextToken.buddies",
                "GlobalSearch.ContextToken.sites",
                "GlobalSearch.ContextToken.marineLife",
                "GlobalSearch.ContextToken.tags",
                "GlobalSearch.ContextToken.gear",
                "GlobalSearch.ContextToken.trips",
                "GlobalSearch.ContextToken.certifications",
                "GlobalSearch.ContextToken.media",
            ])
        }

        @Test func globalSearchPresentation_contextTokens_useFieldGuideAccentCategories() {
            let accentIDs = GlobalSearchPresentation.ContextToken.allCases.map(\.fieldGuideAccentCategoryID)
            #expect(accentIDs.count == 10)
            #expect(accentIDs.contains("fishes"))
            #expect(accentIDs.contains("marine_mammals"))
            #expect(accentIDs.contains("reptiles"))
            #expect(accentIDs.contains("corals"))
            #expect(Set(accentIDs).count >= 6)
        }

        @Test func globalSearchPresentation_contextTokenScopesSnorkelsBrowseResultsWithoutQuery() {
            let snorkelID = UUID()
            let catalog = GlobalSearchPresentation.Catalog(
                dives: [
                    GlobalSearchPresentation.DiveIndexEntry(
                        id: UUID(),
                        title: "Salt Pier #12",
                        subtitle: "Salt Pier",
                        searchHaystack: "salt pier"
                    ),
                ],
                snorkels: [
                    GlobalSearchPresentation.DiveIndexEntry(
                        id: snorkelID,
                        title: "Blue Bay snorkel",
                        subtitle: "Blue Bay",
                        searchHaystack: "blue bay snorkel"
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

            let snorkelOnly = GlobalSearchPresentation.search(
                catalog: catalog,
                query: "",
                contextTokens: [.snorkels]
            )
            #expect(snorkelOnly.sections.count == 1)
            #expect(snorkelOnly.sections.first?.kind == .snorkels)
            #expect(snorkelOnly.sections.first?.hits.count == 1)
            #expect(snorkelOnly.sections.first?.hits.first?.title == "Blue Bay snorkel")
            if case .snorkel(let id) = snorkelOnly.sections.first?.hits.first?.destination {
                #expect(id == snorkelID)
            } else {
                Issue.record("Expected snorkel destination")
            }

            let filtered = GlobalSearchPresentation.search(
                catalog: catalog,
                query: "blue",
                contextTokens: [.snorkels]
            )
            #expect(filtered.sections.first?.hits.count == 1)
            #expect(filtered.sections.first?.hits.first?.title == "Blue Bay snorkel")
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
                snorkels: [],
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

        @Test func globalSearchPresentation_mediaSection_rendersSecondAfterBuddies() {
            let order = GlobalSearchPresentation.SectionKind.resultSectionDisplayOrder
            let buddiesIndex = order.firstIndex(of: .buddies)
            let mediaIndex = order.firstIndex(of: .media)
            #expect(buddiesIndex == 0)
            #expect(mediaIndex == 1)
            if let buddiesIndex, let mediaIndex {
                #expect(mediaIndex == buddiesIndex + 1)
            }
        }

        @Test func globalSearchDiveIndexing_dateSearchTokens_yieldsMonthNameAndYear() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let symbols = GlobalSearchDiveIndexing.monthSymbols(locale: Locale(identifier: "en_US"))
            let march2026 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!

            let tokens = GlobalSearchDiveIndexing.dateSearchTokens(
                for: march2026,
                calendar: calendar,
                monthSymbols: symbols
            )

            #expect(tokens.contains("2026"))
            #expect(tokens.contains("March"))
            // Year token has no grouping separator.
            #expect(!tokens.contains("2,026"))
        }

        @Test func globalSearchMatchReasoning_reasons_labelMatchedFieldsWithDisplayText() {
            let fields: [GlobalSearchPresentation.SearchField] = [
                .init(label: "Buddy", value: "Mike"),
                .init(label: "Country", value: "Mexico MX México", display: "Mexico"),
                .init(label: "Dive year", value: "2026"),
            ]

            // Alias match still surfaces the canonical display value.
            let countryReasons = GlobalSearchMatchReasoning.reasons(query: "mx", fields: fields)
            #expect(countryReasons == [GlobalSearchPresentation.MatchReason(label: "Country", text: "Mexico")])

            let buddyReasons = GlobalSearchMatchReasoning.reasons(query: "mike", fields: fields)
            #expect(buddyReasons == [GlobalSearchPresentation.MatchReason(label: "Buddy", text: "Mike")])

            // Blank query explains nothing.
            #expect(GlobalSearchMatchReasoning.reasons(query: "   ", fields: fields).isEmpty)
        }

        @Test func globalSearchMatchReasoning_reasons_capsAndOrdersByFieldOrder() {
            let fields: [GlobalSearchPresentation.SearchField] = [
                .init(label: "Buddy", value: "reef ranger"),
                .init(label: "Tag", value: "reef"),
                .init(label: "Trip", value: "reef week"),
                .init(label: "Notes", value: "beautiful reef dive", isSnippet: true),
            ]
            let reasons = GlobalSearchMatchReasoning.reasons(query: "reef", fields: fields, maxReasons: 3)
            #expect(reasons.count == 3)
            #expect(reasons.map(\.label) == ["Buddy", "Tag", "Trip"])
        }

        @Test func globalSearchMatchSnippet_windowsNotesAroundMatch() {
            let notes = "We descended slowly and then swam with dolphins for a while before the safety stop"

            let snippet = GlobalSearchMatchSnippet.snippet(from: notes, query: "dolphins", wordsAround: 2)
            #expect(snippet == "… swam with dolphins for a …")

            // Partial-word matches expand to the whole word.
            let partial = GlobalSearchMatchSnippet.snippet(from: notes, query: "dolph", wordsAround: 1)
            #expect(partial.contains("dolphins"))
            #expect(partial.hasPrefix("…"))
            #expect(partial.hasSuffix("…"))
        }

        @Test func globalSearchPresentation_tagsScopedBrowse_listsTagNamesNotDives() {
            let reefTagID = UUID()
            let wreckTagID = UUID()
            let catalog = GlobalSearchPresentation.Catalog(
                dives: [
                    GlobalSearchPresentation.DiveIndexEntry(
                        id: UUID(),
                        title: "Blue Hole morning dive",
                        subtitle: nil,
                        searchHaystack: "blue hole morning dive reef"
                    ),
                ],
                snorkels: [],
                diveSites: [],
                species: [],
                buddies: [],
                tags: [
                    GlobalSearchPresentation.TagIndexEntry(
                        id: reefTagID,
                        name: "Reef",
                        appliedDiveCount: 3,
                        searchHaystack: "reef"
                    ),
                    GlobalSearchPresentation.TagIndexEntry(
                        id: wreckTagID,
                        name: "Wreck",
                        appliedDiveCount: 1,
                        searchHaystack: "wreck"
                    ),
                ],
                trips: [],
                equipment: [],
                certifications: []
            )

            let browseAll = GlobalSearchPresentation.search(
                catalog: catalog,
                query: "",
                contextTokens: [.tags]
            )
            #expect(browseAll.sections.map(\.kind) == [.tags])
            #expect(browseAll.sections[0].hits.map(\.title) == ["Reef", "Wreck"])
            #expect(
                browseAll.sections[0].hits.allSatisfy { hit in
                    if case .tag = hit.destination { return true }
                    return false
                }
            )

            let filtered = GlobalSearchPresentation.search(
                catalog: catalog,
                query: "reef",
                contextTokens: [.tags]
            )
            #expect(filtered.sections.map(\.kind) == [.tags])
            #expect(filtered.sections[0].hits.count == 1)
            #expect(filtered.sections[0].hits[0].title == "Reef")
            if case .tag(let id) = filtered.sections[0].hits[0].destination {
                #expect(id == reefTagID)
            } else {
                Issue.record("Expected tag destination for scoped tag hit")
            }
            #expect(!filtered.sections.contains { $0.kind == .dives })
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
                ) == 5
            )
        }

        @Test func globalSearchMediaBrowsePresentation_freeTextFiltersAcrossAllMediaFields() {
            let snapshot = GlobalSearchMediaBrowsePresentation.IndexSnapshot(
                entries: [
                    GlobalSearchMediaBrowsePresentation.MediaEntry(
                        mediaID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                        diveActivityID: UUID(),
                        diveStartTime: Date(timeIntervalSince1970: 1_700_000_000),
                        capturedAt: nil,
                        sortOrder: 0,
                        mediaKind: .image,
                        siteName: "Blue Hole",
                        activityTagNames: ["Reef"],
                        mediaBuddyNames: ["Pat Lee"],
                        tripTitles: ["Bonaire 2026"],
                        speciesNames: ["Queen Angelfish"],
                    hasMarineLifeTag: false,
                    hasBuddyTag: false
                    ),
                    GlobalSearchMediaBrowsePresentation.MediaEntry(
                        mediaID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                        diveActivityID: UUID(),
                        diveStartTime: Date(timeIntervalSince1970: 1_700_000_000),
                        capturedAt: nil,
                        sortOrder: 1,
                        mediaKind: .video,
                        siteName: "Wreck Alley",
                        activityTagNames: ["Wreck"],
                        mediaBuddyNames: ["Jamie"],
                        tripTitles: ["Curaçao Week"],
                        speciesNames: ["Green Sea Turtle"],
                    hasMarineLifeTag: false,
                    hasBuddyTag: false
                    ),
                ],
                catalogTagNames: ["Reef", "Wreck"],
                catalogBuddyNames: ["Pat Lee", "Jamie"],
                catalogTrips: [],
                catalogSpeciesNames: ["Queen Angelfish", "Green Sea Turtle"]
            )

            func filtered(_ text: String) -> [UUID] {
                GlobalSearchMediaBrowsePresentation.filteredEntries(
                    from: snapshot,
                    filter: GlobalSearchMediaBrowsePresentation.resolveFilter(from: text)
                ).map(\.mediaID)
            }

            // Plain typed text matches media across every field — no `buddy:` / `tag:` / `trip:` / `species:` prefixes.
            #expect(filtered("blue") == [snapshot.entries[0].mediaID]) // site name
            #expect(filtered("pat") == [snapshot.entries[0].mediaID]) // tagged buddy
            #expect(filtered("wreck") == [snapshot.entries[1].mediaID]) // activity tag + site name
            #expect(filtered("bonaire") == [snapshot.entries[0].mediaID]) // trip title
            #expect(filtered("turtle") == [snapshot.entries[1].mediaID]) // tagged species

            // Prefix syntax is treated as literal text (consistent with other categories) and matches nothing here.
            #expect(filtered("buddy: Pat Lee").isEmpty)

            // Empty query returns the whole library.
            #expect(filtered("") == snapshot.entries.map(\.mediaID))
        }

        @Test func globalSearchMediaBrowsePresentation_displayCacheBuildsSnapshotAndFilterTogether() {
            let photoID = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
            let diveID = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
            let input = GlobalSearchMediaIndexSnapshotBuilder.CaptureInput(
                dives: [
                    .init(
                        id: diveID,
                        startTime: Date(timeIntervalSince1970: 1_800_000_000),
                        siteName: "Blue Hole",
                        activityTagNames: ["Reef"],
                        tripTitles: ["Bonaire 2026"],
                        mediaPhotos: [
                            .init(id: photoID, diveActivityID: diveID, capturedAt: nil, sortOrder: 0, mediaKind: .image),
                        ]
                    ),
                ],
                buddyTags: [],
                sightings: [],
                catalogTagNames: ["Reef"],
                catalogBuddyNames: [],
                catalogTrips: [],
                catalogSpeciesNames: []
            )
            let filter = GlobalSearchMediaBrowsePresentation.resolveFilter(from: "blue")

            let cache = GlobalSearchMediaBrowsePresentation.displayCache(from: input, filter: filter)

            #expect(cache.snapshot.entries.map(\.mediaID) == [photoID])
            #expect(cache.filteredMediaIDs == [photoID])
            #expect(cache.filterFingerprint == GlobalSearchMediaBrowsePresentation.filterFingerprint(filter))
            #expect(cache.mediaKindCounts == GlobalSearchMediaBrowsePresentation.MediaKindCounts(
                videoCount: 0,
                photoCount: 1
            ))
        }

        @Test func globalSearchMediaResultsGrid_collapsesToTwoRowsUntilExpanded() {
            typealias Grid = GlobalSearchMediaBrowsePresentation.ResultsSectionGrid
            #expect(Grid.collapsedItemLimit == 6)

            // Six or fewer matches fit in the collapsed two-row grid — no expand control.
            #expect(!Grid.showsExpandControl(total: 6))
            #expect(Grid.visibleCount(total: 6, isExpanded: false) == 6)
            #expect(Grid.hiddenCount(total: 6) == 0)

            // More than six shows the control; collapsed grid caps at six, expanded shows all.
            #expect(Grid.showsExpandControl(total: 10))
            #expect(Grid.visibleCount(total: 10, isExpanded: false) == 6)
            #expect(Grid.visibleCount(total: 10, isExpanded: true) == 10)
            #expect(Grid.hiddenCount(total: 10) == 4)

            // Empty stays empty.
            #expect(Grid.visibleCount(total: 0, isExpanded: false) == 0)
            #expect(!Grid.showsExpandControl(total: 0))
        }

        @Test func globalSearchMediaBrowsePresentation_pageTitleFormatsVideoAndPhotoCounts() {
            #expect(
                GlobalSearchMediaBrowsePresentation.pageTitle(
                    for: .init(videoCount: 0, photoCount: 0)
                ) == "0 videos, 0 photos"
            )
            #expect(
                GlobalSearchMediaBrowsePresentation.pageTitle(
                    for: .init(videoCount: 1, photoCount: 1)
                ) == "1 video, 1 photo"
            )
            #expect(
                GlobalSearchMediaBrowsePresentation.pageTitle(
                    for: .init(videoCount: 3, photoCount: 12)
                ) == "3 videos, 12 photos"
            )
            #expect(GlobalSearchMediaBrowsePresentation.pinsMonthSectionHeaders)
        }

        @Test func globalSearchContextToken_scopedResultsCountTitle_usesSingularAndPluralNouns() {
            #expect(GlobalSearchPresentation.ContextToken.buddies.scopedResultsCountTitle(12) == "12 Buddies")
            #expect(GlobalSearchPresentation.ContextToken.buddies.scopedResultsCountTitle(1) == "1 Buddy")
            #expect(GlobalSearchPresentation.ContextToken.dives.scopedResultsCountTitle(0) == "0 Dives")
            #expect(GlobalSearchPresentation.ContextToken.dives.scopedResultsCountTitle(1) == "1 Dive")
            #expect(GlobalSearchPresentation.ContextToken.snorkels.scopedResultsCountTitle(0) == "0 Snorkels")
            #expect(GlobalSearchPresentation.ContextToken.snorkels.scopedResultsCountTitle(1) == "1 Snorkel")
            #expect(GlobalSearchPresentation.ContextToken.sites.scopedResultsCountTitle(3) == "3 Sites")
            #expect(GlobalSearchPresentation.ContextToken.trips.scopedResultsCountTitle(1) == "1 Trip")
            #expect(GlobalSearchPresentation.ContextToken.tags.scopedResultsCountTitle(5) == "5 Tags")
            #expect(GlobalSearchPresentation.ContextToken.gear.scopedResultsCountTitle(1) == "1 Gear item")
            #expect(GlobalSearchPresentation.ContextToken.gear.scopedResultsCountTitle(4) == "4 Gear items")
            // "Species" is both singular and plural.
            #expect(GlobalSearchPresentation.ContextToken.marineLife.scopedResultsCountTitle(1) == "1 Species")
            #expect(GlobalSearchPresentation.ContextToken.marineLife.scopedResultsCountTitle(9) == "9 Species")
            #expect(
                GlobalSearchPresentation.ContextToken.certifications.scopedResultsCountTitle(1)
                    == "1 Certification"
            )
            #expect(
                GlobalSearchPresentation.ContextToken.certifications.scopedResultsCountTitle(2)
                    == "2 Certifications"
            )
        }

        @Test func globalSearchResultsCountTitlePresentation_fadesTitleAsListScrollsDown() {
            typealias Fade = GlobalSearchPresentation.ResultsCountTitlePresentation
            // At rest (or over-scrolled up) the title is fully visible.
            #expect(Fade.titleOpacity(scrollOffset: 0) == 1)
            #expect(Fade.titleOpacity(scrollOffset: -20) == 1)
            // Fully hidden once scrolled past the fade distance.
            #expect(Fade.titleOpacity(scrollOffset: Fade.fadeDistance) == 0)
            #expect(Fade.titleOpacity(scrollOffset: Fade.fadeDistance + 40) == 0)
            // Half faded at the midpoint.
            #expect(abs(Fade.titleOpacity(scrollOffset: Fade.fadeDistance / 2) - 0.5) < 0.000_001)
        }

        @Test func globalSearchMediaBrowsePresentation_displayCacheCountsFollowActiveFilter() {
            let photoID = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
            let videoID = UUID(uuidString: "00000000-0000-0000-0000-000000000502")!
            let diveID = UUID(uuidString: "00000000-0000-0000-0000-000000000503")!
            let snapshot = GlobalSearchMediaBrowsePresentation.IndexSnapshot(
                entries: [
                    .init(
                        mediaID: photoID,
                        diveActivityID: diveID,
                        diveStartTime: Date(timeIntervalSince1970: 1_700_000_000),
                        capturedAt: nil,
                        sortOrder: 0,
                        mediaKind: .image,
                        siteName: "Blue Hole",
                        activityTagNames: [],
                        mediaBuddyNames: [],
                        tripTitles: [],
                        speciesNames: [],
                        hasMarineLifeTag: false,
                        hasBuddyTag: false
                    ),
                    .init(
                        mediaID: videoID,
                        diveActivityID: diveID,
                        diveStartTime: Date(timeIntervalSince1970: 1_700_000_000),
                        capturedAt: nil,
                        sortOrder: 1,
                        mediaKind: .video,
                        siteName: "Wreck Alley",
                        activityTagNames: [],
                        mediaBuddyNames: [],
                        tripTitles: [],
                        speciesNames: [],
                        hasMarineLifeTag: false,
                        hasBuddyTag: false
                    ),
                ],
                catalogTagNames: [],
                catalogBuddyNames: [],
                catalogTrips: [],
                catalogSpeciesNames: []
            )

            let unfiltered = GlobalSearchMediaBrowsePresentation.displayCache(
                snapshot: snapshot,
                filter: .init(query: "")
            )
            #expect(unfiltered.mediaKindCounts == .init(videoCount: 1, photoCount: 1))

            let photoOnly = GlobalSearchMediaBrowsePresentation.displayCache(
                snapshot: snapshot,
                filter: GlobalSearchMediaBrowsePresentation.resolveFilter(from: "blue")
            )
            #expect(photoOnly.mediaKindCounts == .init(videoCount: 0, photoCount: 1))
        }

        @Test func globalSearchMediaBrowsePresentation_monthSections_groupsNewestMonthFirstUsingCaptureOrDiveDate() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let locale = Locale(identifier: "en_US_POSIX")
            let monthSymbols = GlobalSearchDiveIndexing.monthSymbols(locale: locale)

            let march2026 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
            let january2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
            let december2025 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 20))!

            let marchID = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
            let marchFallbackID = UUID(uuidString: "00000000-0000-0000-0000-000000000602")!
            let januaryID = UUID(uuidString: "00000000-0000-0000-0000-000000000603")!
            let decemberID = UUID(uuidString: "00000000-0000-0000-0000-000000000604")!
            let diveID = UUID(uuidString: "00000000-0000-0000-0000-000000000605")!

            func entry(
                mediaID: UUID,
                diveStartTime: Date,
                capturedAt: Date?,
                sortOrder: Int
            ) -> GlobalSearchMediaBrowsePresentation.MediaEntry {
                .init(
                    mediaID: mediaID,
                    diveActivityID: diveID,
                    diveStartTime: diveStartTime,
                    capturedAt: capturedAt,
                    sortOrder: sortOrder,
                    mediaKind: .image,
                    siteName: nil,
                    activityTagNames: [],
                    mediaBuddyNames: [],
                    tripTitles: [],
                    speciesNames: [],
                    hasMarineLifeTag: false,
                    hasBuddyTag: false
                )
            }

            let sections = GlobalSearchMediaBrowsePresentation.monthSections(
                from: [
                    entry(mediaID: marchID, diveStartTime: march2026, capturedAt: march2026, sortOrder: 0),
                    entry(mediaID: marchFallbackID, diveStartTime: march2026, capturedAt: nil, sortOrder: 1),
                    entry(mediaID: januaryID, diveStartTime: january2026, capturedAt: january2026, sortOrder: 0),
                    entry(mediaID: decemberID, diveStartTime: december2025, capturedAt: december2025, sortOrder: 0),
                ],
                calendar: calendar,
                locale: locale
            )

            #expect(sections.map(\.title) == [
                GlobalSearchMediaBrowsePresentation.monthYearTitle(year: 2026, month: 3, monthSymbols: monthSymbols),
                GlobalSearchMediaBrowsePresentation.monthYearTitle(year: 2026, month: 1, monthSymbols: monthSymbols),
                GlobalSearchMediaBrowsePresentation.monthYearTitle(year: 2025, month: 12, monthSymbols: monthSymbols),
            ])
            #expect(sections.map(\.mediaIDs) == [
                [marchID, marchFallbackID],
                [januaryID],
                [decemberID],
            ])

            let cache = GlobalSearchMediaBrowsePresentation.displayCache(
                snapshot: .init(
                    entries: [
                        entry(mediaID: marchID, diveStartTime: march2026, capturedAt: march2026, sortOrder: 0),
                        entry(mediaID: januaryID, diveStartTime: january2026, capturedAt: january2026, sortOrder: 0),
                    ],
                    catalogTagNames: [],
                    catalogBuddyNames: [],
                    catalogTrips: [],
                    catalogSpeciesNames: []
                ),
                filter: .init(query: "")
            )
            #expect(cache.monthSections.map(\.id) == ["2026-3", "2026-1"])
        }

        @Test func globalSearchMediaIndexSnapshotBuilder_buildsNewestDiveFirstGalleryOrder() {
            let olderDiveID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
            let newerDiveID = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
            let olderPhotoID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
            let newerPhotoID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
            let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
            let newerDate = Date(timeIntervalSince1970: 1_800_000_000)

            let input = GlobalSearchMediaIndexSnapshotBuilder.CaptureInput(
                dives: [
                    .init(
                        id: olderDiveID,
                        startTime: olderDate,
                        siteName: "Older Site",
                        activityTagNames: [],
                        tripTitles: [],
                        mediaPhotos: [
                            .init(
                                id: olderPhotoID,
                                diveActivityID: olderDiveID,
                                capturedAt: olderDate,
                                sortOrder: 0,
                                mediaKind: .image
                            ),
                        ]
                    ),
                    .init(
                        id: newerDiveID,
                        startTime: newerDate,
                        siteName: "Newer Site",
                        activityTagNames: [],
                        tripTitles: [],
                        mediaPhotos: [
                            .init(
                                id: newerPhotoID,
                                diveActivityID: newerDiveID,
                                capturedAt: newerDate,
                                sortOrder: 0,
                                mediaKind: .video
                            ),
                        ]
                    ),
                ],
                buddyTags: [],
                sightings: [],
                catalogTagNames: [],
                catalogBuddyNames: [],
                catalogTrips: [],
                catalogSpeciesNames: []
            )

            let built = GlobalSearchMediaIndexSnapshotBuilder.build(from: input)
            #expect(built.entries.map(\.mediaID) == [newerPhotoID, olderPhotoID])
            #expect(built.entries.map(\.siteName) == ["Newer Site", "Older Site"])
        }

        @Test func globalSearchResultListRowLayout_usesFullWidthHairlineAndCompactArtwork() {
            let layout = GlobalSearchResultListRowLayout.self
            #expect(layout.artworkSize == 30)
            #expect(layout.rowVerticalPadding == 10)
            #expect(layout.separatorHeight == 0.5)
            #expect(layout.compactScale == 0.6)
        }
}
