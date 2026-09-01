//
//  DiveActivityMediaTests.swift
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


struct DiveActivityMediaTests {
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
                    detent: .large,
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

        @Test @MainActor func diveActivityMediaPresentation_resolvedSelectedPhotoID_prefersDeepLinkTarget() {
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

        @Test func diveActivityMediaPresentation_showsMarineLifeTagOnHero_isDisabled() {
            #expect(!DiveActivityMediaPresentation.showsMarineLifeTagOnHero(for: .minimized))
            #expect(!DiveActivityMediaPresentation.showsMarineLifeTagOnHero(for: .large))
            #expect(!DiveActivityMediaPresentation.showsMarineLifeTagOnHero(for: .large))
        }

        @Test func diveActivityMediaPresentation_showsMarineLifeTagInCarousel_onlyAtMinimized() {
            #expect(DiveActivityMediaPresentation.showsMarineLifeTagInCarousel(for: .minimized))
            #expect(!DiveActivityMediaPresentation.showsMarineLifeTagInCarousel(for: .large))
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

        @Test func diveActivityMediaPresentation_mediaTab_usesFullBleedHeroAndOpaquePanelAtAllDetents() {
            for detent in [DiveActivityOverviewDetent.minimized, .large] {
                #expect(DiveActivityMediaPresentation.usesFullBleedMediaHero(for: detent))
                #expect(!DiveActivityMediaPresentation.usesTranslucentOverviewPanel(for: detent))
            }
        }

        @Test func diveActivityMediaPresentation_panelTopScrollFadeHeight_outerAlwaysZero() {
            #expect(
                DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                    detent: .large,
                    isMediaTabSelected: true
                ) == 0
            )
            #expect(
                DiveActivityMediaPresentation.panelTopScrollFadeHeight(
                    detent: .large,
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

        @Test func diveActivityMediaPresentation_pinnedChromeScrollFade_coversToggleBand() {
            let fade = DiveActivityMediaPresentation.largeDetentPinnedChromeScrollFadeHeight
            #expect(fade > DiveActivityMediaPresentation.largeDetentTagOverviewChromeHeight)
            #expect(
                fade == DiveActivityMediaPresentation.largeDetentTagOverviewChromeHeight
                    + DiveActivityOverviewPanelMetrics.mediaLargeDetentPinnedChromeFadeExtra
            )
        }

        @Test func diveActivityMediaPresentation_showsHeroTopChromeScrim_onlyOnMapAndTank() {
            #expect(!DiveActivityMediaPresentation.showsHeroTopChromeScrim(isMediaTabSelected: true))
            #expect(DiveActivityMediaPresentation.showsHeroTopChromeScrim(isMediaTabSelected: false))
        }

        @Test func diveActivityMediaPresentation_panelTopScrollUsesOpaqueFadeAtLargeMediaTab() {
            #expect(
                DiveActivityMediaPresentation.panelTopScrollUsesOpaqueFadeBackground(
                    detent: .large,
                    isMediaTabSelected: true
                )
            )
            #expect(
                !DiveActivityMediaPresentation.panelTopScrollUsesOpaqueFadeBackground(
                    detent: .minimized,
                    isMediaTabSelected: true
                )
            )
            #expect(DiveActivityMediaPresentation.largeDetentPinnedChromeScrollFadeHeight > 0)
        }

        @Test @MainActor func diveActivityMediaPresentation_speciesWasFishialIdentified_matchesScientificName() {
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

        @Test @MainActor func diveActivityMediaPresentation_speciesWasFishialIdentified_matchesAnyConfirmedName() {
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
                    detent: .large,
                    taggedSpeciesCount: 2
                )
            )
            #expect(
                !DiveActivityMediaPresentation.opensMarineLifeDetailOnTaggedChipTap(
                    detent: .large,
                    taggedSpeciesCount: 0
                )
            )
        }

        @Test func diveActivityMediaPresentation_opensMarineLifeDetailOnSheetFishTap_onlyAtMedium() {
            #expect(DiveActivityMediaPresentation.opensMarineLifeDetailOnSheetFishTap(detent: .large))
            #expect(!DiveActivityMediaPresentation.opensMarineLifeDetailOnSheetFishTap(detent: .minimized))
        }

        @Test func diveActivityMediaPresentation_opensBuddyOverviewOnSheetBuddyTap_onlyAtMedium() {
            #expect(DiveActivityMediaPresentation.opensBuddyOverviewOnSheetBuddyTap(detent: .large))
            #expect(!DiveActivityMediaPresentation.opensBuddyOverviewOnSheetBuddyTap(detent: .minimized))
        }

        @Test func diveActivityMediaPresentation_showsMarineLifeTagInSheet_onlyAtMedium() {
            #expect(!DiveActivityMediaPresentation.showsMarineLifeTagInSheet(for: .minimized))
            #expect(DiveActivityMediaPresentation.showsMarineLifeTagInSheet(for: .large))
        }

        @Test func diveActivityMediaPresentation_showsBuddyTagInSheet_onlyAtMedium() {
            #expect(!DiveActivityMediaPresentation.showsBuddyTagInSheet(for: .minimized))
            #expect(DiveActivityMediaPresentation.showsBuddyTagInSheet(for: .large))
        }

        @Test func diveActivityMediaPresentation_buddyTagControlIsActive_whenTagged() {
            #expect(!DiveActivityMediaPresentation.buddyTagControlIsActive(taggedBuddyCount: 0))
            #expect(DiveActivityMediaPresentation.buddyTagControlIsActive(taggedBuddyCount: 1))
        }

        @Test func diveActivityMediaPresentation_showsMarineLifeTagSummary_onlyAtMedium() {
            #expect(!DiveActivityMediaPresentation.showsMarineLifeTagSummaryInSheet(for: .minimized))
            #expect(DiveActivityMediaPresentation.showsMarineLifeTagSummaryInSheet(for: .large))
            #expect(!DiveActivityMediaPresentation.showsDiveIdentityHeaderInSheet(for: .minimized))
            #expect(DiveActivityMediaPresentation.showsDiveIdentityHeaderInSheet(for: .large))
            #expect(
                DiveActivityMediaPresentation.largeDetentSpeciesHeroTopFadeOpaqueStop
                    == HomeMediaCarouselPresentation.marineLifeCarouselOverlayFeatureImageFadeOpaqueStop
            )
        }

        @Test func diveActivityMediaPresentation_showsBuddyTagSummary_andBottomPinsCarouselAtMedium() {
            #expect(!DiveActivityMediaPresentation.showsBuddyTagSummaryInSheet(for: .minimized))
            #expect(DiveActivityMediaPresentation.showsBuddyTagSummaryInSheet(for: .large))
            #expect(DiveActivityMediaPresentation.pinsMediaCarouselToSheetBottom(for: .large))
            #expect(!DiveActivityMediaPresentation.pinsMediaCarouselToSheetBottom(for: .minimized))
            #expect(DiveActivityMediaPresentation.mediumCarouselBottomPadding == 8)
            #expect(DiveMediaBuddyTagPresentation.mediumSectionTitle == "Buddies")
            #expect(DiveMediaBuddyTagPresentation.mediumAvatarDiameter == 48)
        }

        @Test func diveActivityMediaPresentation_showsMarineLifeDetail_onlyAtLarge() {
            #expect(!DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: .minimized))
            #expect(DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: .large))
        }

        @Test func diveActivityMediaPresentation_showsMediaSheetChromeActions_alwaysOff() {
            #expect(!DiveActivityMediaPresentation.showsMediaSheetChromeActions(for: .minimized))
            #expect(!DiveActivityMediaPresentation.showsMediaSheetChromeActions(for: .large))
            #expect(DiveActivityMediaPresentation.showsMediumDetentTrailingTagChrome(for: .large))
            #expect(!DiveActivityMediaPresentation.showsMediumDetentTrailingTagChrome(for: .minimized))
        }

        @Test func diveActivityMediaPresentation_carouselFeaturedStarVisibilityAndScale() {
            #expect(
                DiveActivityMediaPresentation.showsCarouselFeaturedStar(isSelected: true, isFeatured: false)
            )
            #expect(
                DiveActivityMediaPresentation.showsCarouselFeaturedStar(isSelected: false, isFeatured: true)
            )
            #expect(
                DiveActivityMediaPresentation.showsCarouselFeaturedStar(isSelected: true, isFeatured: true)
            )
            #expect(
                !DiveActivityMediaPresentation.showsCarouselFeaturedStar(isSelected: false, isFeatured: false)
            )
            #expect(DiveActivityMediaPresentation.carouselFeaturedStarUsesAccent(isFeatured: true))
            #expect(!DiveActivityMediaPresentation.carouselFeaturedStarUsesAccent(isFeatured: false))
            #expect(
                DiveActivityMediaPresentation.carouselFeaturedStarFontSize(isSelected: true)
                    > DiveActivityMediaPresentation.carouselFeaturedStarFontSize(isSelected: false)
            )
        }

        @Test func diveActivityMediaPresentation_showsLargeDetentAddMarineLifeControl_onlyAtLarge() {
            #expect(!DiveActivityMediaPresentation.showsLargeDetentAddMarineLifeControl(for: .minimized))
            #expect(DiveActivityMediaPresentation.showsLargeDetentAddMarineLifeControl(for: .large))
        }

        @Test func diveActivityMediaPresentation_showsLargeDetentAddBuddyControl_onlyAtLarge() {
            #expect(!DiveActivityMediaPresentation.showsLargeDetentAddBuddyControl(for: .minimized))
            #expect(DiveActivityMediaPresentation.showsLargeDetentAddBuddyControl(for: .large))
            #expect(DiveActivityMediaPresentation.showsLargeDetentTagOverviewChrome(for: .large))
            #expect(
                DiveActivityMediaPresentation.largeDetentTagOverviewChromeHeight
                    == PushedDetailHeroModeTogglePresentation.segmentSize
                    + (PushedDetailHeroModeTogglePresentation.shellPadding * 2)
            )
            #expect(DiveActivityMediaLargeDetentMode.marineLife.systemImage == "fish.fill")
            #expect(DiveActivityMediaLargeDetentMode.buddies.systemImage == "person.2.fill")
        }

        @Test func diveActivityMediaPresentation_largeDetentChrome_placesTagActionsLeadingAndUploadTrailing() {
            #expect(DiveActivityMediaPresentation.placesLargeDetentTagActionsLeading(for: .large))
            #expect(!DiveActivityMediaPresentation.placesLargeDetentTagActionsLeading(for: .minimized))
            #expect(DiveActivityMediaPresentation.placesLargeDetentAddMediaControlTrailing(for: .large))
            #expect(!DiveActivityMediaPresentation.placesLargeDetentAddMediaControlTrailing(for: .minimized))
            #expect(DiveActivityMediaPresentation.placesLargeDetentDeleteMediaControlLeadingAddMedia(for: .large))
            #expect(!DiveActivityMediaPresentation.placesLargeDetentDeleteMediaControlLeadingAddMedia(for: .minimized))
            #expect(
                DiveActivityMediaPresentation.showsLargeDetentDeleteMediaControl(
                    for: .large,
                    hasSelectedMedia: true
                )
            )
            #expect(
                !DiveActivityMediaPresentation.showsLargeDetentDeleteMediaControl(
                    for: .large,
                    hasSelectedMedia: false
                )
            )
            #expect(
                !DiveActivityMediaPresentation.showsLargeDetentDeleteMediaControl(
                    for: .minimized,
                    hasSelectedMedia: true
                )
            )
        }

        @Test func diveActivityMediaPresentation_deleteMediaCopy_matchesPhotoAndVideo() {
            #expect(DiveActivityMediaPresentation.deleteMediaOverflowSystemImage == "ellipsis")
            #expect(DiveActivityMediaPresentation.deleteMediaConfirmationButtonTitle == "Delete")
            #expect(DiveActivityMediaPresentation.deleteMediaOverflowAccessibilityIdentifier == "DiveOverview.MediaDelete")
            #expect(DiveActivityMediaPresentation.deleteMediaConfirmationTitle(kind: .image) == "Delete this photo?")
            #expect(DiveActivityMediaPresentation.deleteMediaConfirmationTitle(kind: .video) == "Delete this video?")
            #expect(DiveActivityMediaPresentation.deleteMediaAccessibilityLabel(kind: .image) == "Delete this photo")
            #expect(DiveActivityMediaPresentation.deleteMediaAccessibilityLabel(kind: .video) == "Delete this video")
        }

        @Test func diveActivityMediaPresentation_selectedPhotoIDAfterRemoving_prefersNextThenPrevious() {
            let first = UUID()
            let middle = UUID()
            let last = UUID()
            let ordered = [first, middle, last]

            #expect(
                DiveActivityMediaPresentation.selectedPhotoIDAfterRemoving(
                    mediaID: middle,
                    selectedID: middle,
                    orderedIDs: ordered
                ) == last
            )
            #expect(
                DiveActivityMediaPresentation.selectedPhotoIDAfterRemoving(
                    mediaID: last,
                    selectedID: last,
                    orderedIDs: ordered
                ) == middle
            )
            #expect(
                DiveActivityMediaPresentation.selectedPhotoIDAfterRemoving(
                    mediaID: first,
                    selectedID: last,
                    orderedIDs: ordered
                ) == last
            )
            #expect(
                DiveActivityMediaPresentation.selectedPhotoIDAfterRemoving(
                    mediaID: first,
                    selectedID: first,
                    orderedIDs: [first]
                ) == nil
            )
        }

        @Test func marineLifeMediaTagPresentation_taggedRows_listsUniqueSpeciesOnMedia() {
            let taggedMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_000_000))
            let otherMedia = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 4_000_200))
            let angelfish = MarineLife(uuid: "marine-life-row-angelfish", commonName: "Zebra Angelfish")
            let ray = MarineLife(uuid: "marine-life-row-ray", commonName: "Spotted Eagle Ray")

            let sightingOnMedia = SightingInstance(
                marineLifeUUID: angelfish.uuid,
                sightingDateTime: Date(timeIntervalSince1970: 4_000_000),
                mediaPhoto: taggedMedia
            )
            let duplicateOnMedia = SightingInstance(
                marineLifeUUID: angelfish.uuid,
                sightingDateTime: Date(timeIntervalSince1970: 4_000_100),
                mediaPhoto: taggedMedia
            )
            let otherMediaSighting = SightingInstance(
                marineLifeUUID: ray.uuid,
                sightingDateTime: Date(timeIntervalSince1970: 4_000_200),
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
                mediaPhoto: taggedMedia
            )
            let raySighting = SightingInstance(
                marineLifeUUID: ray.uuid,
                sightingDateTime: Date(timeIntervalSince1970: 4_100_200),
                mediaPhoto: taggedMedia
            )
            let turtleSighting = SightingInstance(
                marineLifeUUID: turtle.uuid,
                sightingDateTime: Date(timeIntervalSince1970: 4_100_300),
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
            #expect(
                FishialVideoScrubPresentation.formattedScrubTimestamp(durationSeconds: 125, fraction: 0.5)
                    == "1:02.5"
            )
            #expect(FishialVideoScrubPresentation.formattedDuration(durationSeconds: 125) == "2:05")
        }

        @Test func fishialVideoScrubFrameRequestCoalescer_runsFirstRequestImmediately() {
            var coalescer = FishialVideoScrubFrameRequestCoalescer()
            #expect(coalescer.requestFraction(0.25) == 0.25)
        }

        @Test func fishialVideoScrubFrameRequestCoalescer_clampsRequestedFraction() {
            var coalescer = FishialVideoScrubFrameRequestCoalescer()
            #expect(coalescer.requestFraction(1.8) == 1)
        }

        @Test func fishialVideoScrubFrameRequestCoalescer_queuesLatestWhileGenerating() {
            var coalescer = FishialVideoScrubFrameRequestCoalescer()
            #expect(coalescer.requestFraction(0.1) == 0.1)
            // Further requests while a decode is in flight do not start a new decode...
            #expect(coalescer.requestFraction(0.4) == nil)
            // ...and only the newest requested fraction is retained.
            #expect(coalescer.requestFraction(0.7) == nil)
            // On completion the newest pending fraction runs next (live scrub keeps up).
            #expect(coalescer.completeGeneration() == 0.7)
            // No further pending work once caught up.
            #expect(coalescer.completeGeneration() == nil)
        }

        @Test func fishialVideoScrubFrameRequestCoalescer_resetClearsPendingWork() {
            var coalescer = FishialVideoScrubFrameRequestCoalescer()
            #expect(coalescer.requestFraction(0.3) == 0.3)
            #expect(coalescer.requestFraction(0.6) == nil)
            coalescer.reset()
            // After reset the next request starts fresh instead of queueing behind stale state.
            #expect(coalescer.requestFraction(0.9) == 0.9)
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
            #expect(FishialMediaSelectionPresentation.videoScrubPreviewMaxEdge == 1_024)
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
            DiveActivitySiteAssociation.link(activity, to: site)

            #expect(
                FishialObservationLocation.resolvedCoordinate(for: activity, catalogSites: [site])?.latitude
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

        @Test @MainActor func fishialAPIClient_recognizeJPEG_enforcesMinimumRecognizeInterval() async throws {
            let jpegData = Data("fake-jpeg-bytes".utf8)
            let credentials = FishialSecretsBootstrap.Credentials(
                clientID: "test-client-id",
                clientSecret: "test-client-secret"
            )
            let okBody = """
            {
              "ok": true,
              "queryToken": "query-token",
              "objects": [],
              "definitions": {}
            }
            """
            let session = MockFishialURLSession(handlers: [
                { request in
                    MockFishialURLSession.jsonResponse(
                        statusCode: 200,
                        body: #"{"access_token":"token-123"}"#,
                        url: request.url!
                    )
                },
                { request in
                    MockFishialURLSession.jsonResponse(statusCode: 200, body: okBody, url: request.url!)
                },
                { request in
                    MockFishialURLSession.jsonResponse(statusCode: 200, body: okBody, url: request.url!)
                },
            ])
            var configuration = FishialAPIClient.Configuration(credentials: credentials)
            configuration.minimumRecognizeInterval = 0.08
            let client = FishialAPIClient(configuration: configuration, session: session)
            let started = ContinuousClock.now
            _ = try await client.recognizeJPEG(jpegData)
            _ = try await client.recognizeJPEG(jpegData)
            let elapsed = started.duration(to: .now)
            #expect(elapsed >= .milliseconds(80))
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

        @Test @MainActor func diveActivityMediaPresentation_sortedPhotos_withoutCaptureDate_respectsSortOrder() {
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

        @Test @MainActor func diveActivityMediaPresentation_sortedPhotos_ordersByCapturedAt_oldestFirst() {
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

        @Test @MainActor func diveActivityMediaPresentation_oldestGalleryPhotoID_returnsFirstInGalleryOrder() {
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

        @Test @MainActor func diveActivityMediaPresentation_featuredPhotoID_prefersExplicitThenFallsBackToOldest() {
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
            #expect(DiveActivityMediaPresentation.featuredPhotoID(in: [DiveMediaPhoto](), explicitFeaturedID: UUID()) == nil)
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

        @Test @MainActor func diveActivityMediaStorage_removeMedia_deletesItemAndClearsRelatedState() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let owner = UserProfile(appleUserIdentifier: "remove-media-owner", displayName: "Diver")
            let activity = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 5_100_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            activity.owner = owner
            activity.ownerProfileID = owner.id
            let keep = DiveMediaPhoto(
                sortOrder: 0,
                mediaKind: .image,
                capturedAt: Date(timeIntervalSince1970: 5_100_100),
                dive: activity
            )
            let remove = DiveMediaPhoto(
                sortOrder: 1,
                mediaKind: .video,
                capturedAt: Date(timeIntervalSince1970: 5_100_200),
                dive: activity
            )
            keep.link(to: activity)
            remove.link(to: activity)
            activity.mediaPhotos = [keep, remove]
            activity.featuredMediaPhotoID = remove.id
            activity.friendShareBuddySettingsConfigured = true
            activity.friendShareMediaSelectedIDsJSON = ActivityFriendShareConfiguration.encodeMediaIDs(
                [keep.id, remove.id]
            )
            let species = MarineLife(uuid: "marine-life-remove-media", commonName: "Removed Fish")
            let buddy = DiveBuddy(displayName: "Jamie", owner: owner)
            context.insert(owner)
            context.insert(activity)
            context.insert(keep)
            context.insert(remove)
            context.insert(species)
            context.insert(buddy)
            try context.save()

            _ = try MarineLifeSightingRecorder.tagSpecies(
                species,
                on: remove,
                dive: activity,
                captureContext: nil,
                owner: owner,
                modelContext: context
            )
            _ = try DiveMediaBuddyAssociation.tagBuddy(
                buddy,
                on: remove,
                dive: activity,
                modelContext: context
            )

            try DiveActivityMediaStorage.removeMedia(
                remove,
                from: activity,
                owner: owner,
                modelContext: context
            )

            #expect(Set(activity.mediaPhotos.map(\.id)) == [keep.id])
            #expect(activity.featuredMediaPhotoID == nil)
            #expect(
                ActivityFriendShareConfiguration.decodeMediaIDs(
                    from: activity.friendShareMediaSelectedIDsJSON
                ) == [keep.id]
            )
            #expect(
                try MarineLifeSightingRecorder.sightings(
                    forMediaPhotoID: remove.id,
                    modelContext: context
                ).isEmpty
            )
            #expect(
                try DiveMediaBuddyAssociation.tags(
                    forMediaPhotoID: remove.id,
                    modelContext: context
                ).isEmpty
            )
            #expect(Set(try context.fetch(FetchDescriptor<DiveMediaPhoto>()).map(\.id)) == [keep.id])
        }

        @Test func diveActivityMediaPresentation_overviewUsesPreviewVideoQuality() {
            #expect(DiveActivityMediaPresentation.overviewLibraryVideoQuality == .homeCarousel)
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
                    forHeightFraction: DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
                )
            )
            #expect(
                DiveActivityMediaEmptyHeroPresentation.showsHeroGhostFrames(
                    forHeightFraction: DiveActivityOverviewPanelMetrics.minimizedHeightFraction
                )
            )
        }

        @Test func diveActivityMediaHeroPresentation_fullBleedProgress_tracksSheetDrag() {
            let context = DiveActivityOverviewSheetLayoutContext.presentationReference
            let large = DiveActivityOverviewPanelMetrics.largeHeightFraction(in: context)
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            #expect(
                abs(
                    DiveActivityMediaHeroPresentation.fullBleedProgress(
                        sheetHeightFraction: large,
                        layoutContext: context
                    )
                ) < 0.001
            )
            #expect(
                abs(
                    DiveActivityMediaHeroPresentation.fullBleedProgress(
                        sheetHeightFraction: minimized,
                        layoutContext: context
                    ) - 1
                ) < 0.001
            )
            let midpoint = (large + minimized) / 2
            let midProgress = DiveActivityMediaHeroPresentation.fullBleedProgress(
                sheetHeightFraction: midpoint,
                layoutContext: context
            )
            #expect(midProgress > 0.4 && midProgress < 0.6)
        }

        @Test func diveActivityMediaHeroPresentation_resolvedFitFillProgress_matchesOwnerAndBuddyHeroGates() {
            let context = DiveActivityOverviewSheetLayoutContext.presentationReference
            let large = DiveActivityOverviewPanelMetrics.largeHeightFraction(in: context)
            let minimized = DiveActivityOverviewPanelMetrics.minimizedHeightFraction

            #expect(
                abs(
                    DiveActivityMediaHeroPresentation.resolvedFitFillProgress(
                        sheetHeightFraction: large,
                        layoutHeight: context.layoutHeight,
                        screenWidth: context.screenWidth,
                        isLandscape: false,
                        topSafeInset: context.topSafeInset,
                        bottomSafeInset: context.bottomSafeInset
                    )
                ) < 0.001
            )
            #expect(
                abs(
                    DiveActivityMediaHeroPresentation.resolvedFitFillProgress(
                        sheetHeightFraction: minimized,
                        layoutHeight: context.layoutHeight,
                        screenWidth: context.screenWidth,
                        isLandscape: false,
                        topSafeInset: context.topSafeInset,
                        bottomSafeInset: context.bottomSafeInset
                    ) - 1
                ) < 0.001
            )
            #expect(
                DiveActivityMediaHeroPresentation.resolvedFitFillProgress(
                    sheetHeightFraction: large,
                    layoutHeight: context.layoutHeight,
                    screenWidth: context.screenWidth,
                    isLandscape: true,
                    topSafeInset: context.topSafeInset,
                    bottomSafeInset: context.bottomSafeInset
                ) == 1
            )
            #expect(
                DiveActivityMediaHeroPresentation.resolvedFitFillProgress(
                    sheetHeightFraction: large,
                    layoutHeight: 0,
                    screenWidth: context.screenWidth,
                    isLandscape: false,
                    topSafeInset: context.topSafeInset,
                    bottomSafeInset: context.bottomSafeInset
                ) == 1
            )
        }

        @Test func diveActivityMediaHeroPresentation_interpolatedSize_fillsBandAtZeroProgress() {
            let band = CGRect(x: 0, y: 0, width: 390, height: 280)
            let viewport = CGSize(width: 390, height: 844)
            let size = DiveActivityMediaHeroPresentation.interpolatedMediaSize(
                mediaAspect: 4 / 3,
                band: band,
                viewport: viewport,
                progress: 0
            )
            #expect(size.width >= band.width - 0.5)
            #expect(size.height >= band.height - 0.5)
            #expect(abs(size.width / size.height - 4 / 3) < 0.02)
        }

        @Test func diveActivityMediaHeroPresentation_interpolatedSize_fillsViewportAtFullProgress() {
            let band = CGRect(x: 0, y: 0, width: 390, height: 280)
            let viewport = CGSize(width: 390, height: 844)
            let expected = DiveActivityMediaHeroPresentation.aspectFillSize(
                mediaAspect: 16 / 9,
                in: viewport
            )
            let size = DiveActivityMediaHeroPresentation.interpolatedMediaSize(
                mediaAspect: 16 / 9,
                band: band,
                viewport: viewport,
                progress: 1
            )
            #expect(abs(size.width - expected.width) < 0.5)
            #expect(abs(size.height - expected.height) < 0.5)
        }

        @Test func diveActivityMediaHeroPresentation_heroBandRect_fillsToScreenTop() {
            let band = DiveActivityMediaHeroPresentation.heroBandRect(
                viewportSize: CGSize(width: 390, height: 844),
                layoutHeight: 844,
                sheetHeightFraction: DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction,
                bottomSafeInset: 34,
                topObstructionHeight: 100
            )
            #expect(abs(band.minY) < 0.001)
            #expect(band.width == 390)
            #expect(band.height > 200)
        }

        @Test func diveActivityMediaHeroPresentation_heroBandRect_bleedsBelowSheetSeam() {
            let layoutHeight: CGFloat = 844
            let bottomSafeInset: CGFloat = 34
            let fraction = DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let seamY = DiveActivityMediaHeroPresentation.sheetSeamY(
                layoutHeight: layoutHeight,
                sheetHeightFraction: fraction,
                bottomSafeInset: bottomSafeInset
            )
            let band = DiveActivityMediaHeroPresentation.heroBandRect(
                viewportSize: CGSize(width: 390, height: layoutHeight),
                layoutHeight: layoutHeight,
                sheetHeightFraction: fraction,
                bottomSafeInset: bottomSafeInset,
                topObstructionHeight: 0
            )
            #expect(band.maxY == seamY + DiveActivityMediaHeroPresentation.sheetSeamCornerBleed)
        }

        @Test func diveActivityMediaHeroPresentation_interpolatedCenterY_bottomAlignsToBandAtZeroProgress() {
            let band = CGRect(x: 0, y: 0, width: 390, height: 300)
            let centerY = DiveActivityMediaHeroPresentation.interpolatedMediaCenterY(
                band: band,
                viewportHeight: 844,
                mediaAspect: 16 / 9,
                progress: 0
            )
            let fillHeight = DiveActivityMediaHeroPresentation.aspectFillSize(
                mediaAspect: 16 / 9,
                in: band.size
            ).height
            #expect(abs(centerY + fillHeight / 2 - band.maxY) < 0.5)
        }

        @Test func diveActivityMediaEmptyHeroPresentation_emptySheetReusesPopulatedLayout() {
            // Upload copy lives only in the hero; the sheet renders the standard Media layout when empty.
            #expect(!DiveActivityMediaEmptyHeroPresentation.showsUploadPromptTextInSheet(for: .minimized))
            #expect(!DiveActivityMediaEmptyHeroPresentation.showsUploadPromptTextInSheet(for: .large))
            #expect(!DiveActivityMediaEmptyHeroPresentation.showsUploadPromptTextInSheet(for: .large))
        }

        @Test func diveActivityMediaEmptyHeroPresentation_reusesHomeHighlightTitle() {
            #expect(DiveActivityMediaEmptyHeroPresentation.title == HomeMediaCarouselEmptyPresentation.title)
            #expect(DiveActivityMediaEmptyHeroPresentation.uploadMediaCTATitle == "Upload Media")
            #expect(
                DiveActivityMediaEmptyHeroPresentation.showsUploadMediaCTA(
                    forHeightFraction: DiveActivityOverviewPanelMetrics.minimizedHeightFraction
                )
            )
            #expect(
                !DiveActivityMediaEmptyHeroPresentation.showsUploadMediaCTA(
                    forHeightFraction: DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
                )
            )
        }

        @Test func diveActivityMediaEmptyHeroPresentation_pinsUploadCTABelowAnimationInHeroBand() {
            let layoutHeight: CGFloat = 844
            let bottomSafeInset: CGFloat = 34
            let topObstruction: CGFloat = 100
            let fraction = DiveActivityOverviewPanelMetrics.minimizedHeightFraction

            let band = DiveActivityMediaEmptyHeroPresentation.visibleHeroBand(
                layoutHeight: layoutHeight,
                sheetHeightFraction: fraction,
                bottomSafeInset: bottomSafeInset,
                topObstructionHeight: topObstruction
            )
            let animationY = DiveActivityMediaEmptyHeroPresentation.ghostFramesCenterY(
                layoutHeight: layoutHeight,
                sheetHeightFraction: fraction,
                bottomSafeInset: bottomSafeInset,
                topObstructionHeight: topObstruction
            )
            let ctaY = DiveActivityMediaEmptyHeroPresentation.uploadMediaCTACenterY(
                layoutHeight: layoutHeight,
                sheetHeightFraction: fraction,
                bottomSafeInset: bottomSafeInset,
                topObstructionHeight: topObstruction
            )

            #expect(ctaY > animationY)
            #expect(ctaY < band.top + band.height)
            #expect(ctaY > band.top)
            let animationBandHeight = max(
                0,
                band.height - DiveActivityMediaEmptyHeroPresentation.uploadMediaCTAReservedHeight(
                    forHeightFraction: fraction
                )
            )
            let centeredWithoutDownshift = band.top + animationBandHeight / 2
            #expect(animationY > centeredWithoutDownshift)
            #expect(
                DiveActivityMediaEmptyHeroPresentation.uploadMediaCTAReservedHeight(
                    forHeightFraction: fraction
                ) > DiveActivityMediaEmptyHeroPresentation.uploadMediaCTAHeight
            )
            #expect(
                DiveActivityMediaEmptyHeroPresentation.uploadMediaCTAReservedHeight(
                    forHeightFraction: DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
                ) == 0
            )
        }

        @Test func diveActivityMediaPresentation_emptyStateMessage() {
            #expect(DiveActivityMediaPresentation.emptyStateMessage == "No media added")
            #expect(DiveActivityMediaPresentation.mediaCountLabel(photoCount: 0) == "No media added")
            #expect(DiveActivityMediaPresentation.mediaCountLabel(photoCount: 2) == "2 items")
        }

        @Test @MainActor func diveActivityMediaPresentation_nextSortOrder_increments() {
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
            for detent in [DiveActivityOverviewDetent.minimized, .large] {
                #expect(DiveActivityMediaPresentation.showsBackgroundPhotos(for: detent))
            }
        }

        @Test func linkedMediaGridPresentation_matchesBuddyGridMetrics() {
            #expect(LinkedMediaGridPresentation.columnCount == 3)
            #expect(LinkedMediaGridPresentation.spacing == AppTheme.Spacing.sm)
            #expect(
                LinkedMediaGridPresentation.cornerRadius
                    == DiveActivityMediaPresentation.carouselThumbnailCornerRadius
            )
            #expect(LinkedMediaGridPresentation.showsTagIcon(hasTags: true))
            #expect(!LinkedMediaGridPresentation.showsTagIcon(hasTags: false))
            #expect(LinkedMediaGridPresentation.showsTagCountBadge(tagCount: 0) == false)
            #expect(LinkedMediaGridPresentation.showsTagCountBadge(tagCount: 1) == false)
            #expect(LinkedMediaGridPresentation.showsTagCountBadge(tagCount: 2))
            #expect(MediaTagCountBadgePresentation.homeOverflowTop == 4)
            #expect(MediaTagCountBadgePresentation.homeOverflowTrailing == 4)
            #expect(
                !MediaTagCountBadgePresentation.clipsHomeChromeChipWhenCollapsed(isCollapsed: false)
            )
            #expect(
                MediaTagCountBadgePresentation.clipsHomeChromeChipWhenCollapsed(isCollapsed: true)
            )
            #expect(
                LinkedMediaGridPresentation.tagOverviewMode(isBuddyBadge: false) == .marineLife
            )
            #expect(
                LinkedMediaGridPresentation.tagOverviewMode(isBuddyBadge: true) == .buddies
            )
            #expect(LinkedMediaGridPresentation.tagIconEdgePadding == 6)
            #expect(LinkedMediaGridPresentation.gridThumbnailPointSize == 180)
            #expect(LinkedMediaGridPresentation.photoKitRequestEdge == 360)
            #expect(LinkedMediaGridPresentation.cellAspectRatio == 1)
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
            #expect(
                LinkedMediaFullscreenPresentation.topChromeControlHeight
                    == AppToolbarIconButtonMetrics.tapDimension
            )
            #expect(
                LinkedMediaFullscreenPresentation.topChromeControlHeight
                    == SecondaryDestinationChromeMetrics.backButtonMinimumTapDimension
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

        @Test func linkedMediaFullscreenPresentation_shouldDismissTagOverview_usesGrabberThreshold() {
            let threshold = LinkedMediaFullscreenPresentation.tagOverviewGrabberDismissThreshold
            #expect(
                LinkedMediaFullscreenPresentation.shouldDismissTagOverview(
                    verticalTranslation: threshold,
                    predictedEndTranslation: 0
                )
            )
            #expect(
                LinkedMediaFullscreenPresentation.shouldDismissTagOverview(
                    verticalTranslation: threshold - 1,
                    predictedEndTranslation: threshold * 1.25
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.shouldDismissTagOverview(
                    verticalTranslation: threshold - 1,
                    predictedEndTranslation: threshold
                )
            )
        }

        @Test func linkedMediaFullscreenPresentation_playbackChrome_hidesOnToggleAndShowsCenterControlForVideo() {
            #expect(
                LinkedMediaFullscreenPresentation.playbackChromeOpacity(
                    dismissProgress: 0,
                    showsPlaybackChrome: true
                ) == 1
            )
            #expect(
                LinkedMediaFullscreenPresentation.playbackChromeOpacity(
                    dismissProgress: 0,
                    showsPlaybackChrome: false
                ) == 0
            )
            #expect(
                LinkedMediaFullscreenPresentation.playbackChromeOpacity(
                    dismissProgress: 1,
                    showsPlaybackChrome: true
                ) == 0.65
            )
            #expect(
                LinkedMediaFullscreenPresentation.showsCenterPlaybackControl(
                    isVideo: true,
                    showsPlaybackChrome: true
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.showsCenterPlaybackControl(
                    isVideo: true,
                    showsPlaybackChrome: false
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.showsCenterPlaybackControl(
                    isVideo: false,
                    showsPlaybackChrome: true
                )
            )
            #expect(
                LinkedMediaFullscreenPresentation.isVideoPausedByUserInteraction(
                    isHoldingPause: false,
                    isTogglePaused: true
                )
            )
            #expect(
                LinkedMediaFullscreenPresentation.isVideoPausedByUserInteraction(
                    isHoldingPause: true,
                    isTogglePaused: false
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.isVideoPausedByUserInteraction(
                    isHoldingPause: false,
                    isTogglePaused: false
                )
            )
            #expect(LinkedMediaFullscreenPresentation.centerPlaybackControlDiameter == 64)
        }

        @Test func linkedMediaFullscreenPresentation_shouldPresentMediaTagSheet_requiresButtonsAndLinkedDive() {
            #expect(
                LinkedMediaFullscreenPresentation.shouldPresentMediaTagSheet(
                    showsMediaTagButtons: true,
                    hasLinkedDive: true
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.shouldPresentMediaTagSheet(
                    showsMediaTagButtons: true,
                    hasLinkedDive: false
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.shouldPresentMediaTagSheet(
                    showsMediaTagButtons: false,
                    hasLinkedDive: true
                )
            )
            #expect(LinkedMediaFullscreenPresentation.isMediaTagControlActive(hasTags: true))
            #expect(!LinkedMediaFullscreenPresentation.isMediaTagControlActive(hasTags: false))
            #expect(
                !LinkedMediaFullscreenPresentation.shouldPauseVideoForPresentedTagChrome(
                    isTaggingSheetPresented: false
                )
            )
            #expect(
                LinkedMediaFullscreenPresentation.shouldPauseVideoForPresentedTagChrome(
                    isTaggingSheetPresented: true
                )
            )
            #expect(
                DiveActivityMediaFrostedOverlayPresentation.mediaScrimOpacity
                    == HomeMediaCarouselPresentation.marineLifeCarouselOverlayMediaScrimOpacity
            )
            #expect(DiveActivityMediaFrostedOverlayPresentation.forcesDarkAppearance)
            #expect(
                LinkedMediaFullscreenPresentation.tagOverviewPanelHeight(
                    layoutHeight: 800,
                    bottomSafeInset: 34
                )
                    == DiveActivityOverviewDetent.sheetHeight(
                        for: .large,
                        layoutHeight: 800,
                        bottomSafeInset: 34
                    )
            )
            let landscapeContext = DiveActivityOverviewSheetLayoutContext(
                layoutHeight: 390,
                screenWidth: 844,
                topSafeInset: 0,
                bottomSafeInset: 21
            )
            #expect(
                LinkedMediaFullscreenPresentation.tagOverviewPanelHeight(in: landscapeContext)
                    == DiveActivityOverviewDetent.sheetHeight(
                        for: .large,
                        layoutHeight: landscapeContext.layoutHeight,
                        bottomSafeInset: landscapeContext.bottomSafeInset,
                        screenWidth: landscapeContext.screenWidth,
                        topSafeInset: landscapeContext.topSafeInset
                    )
            )
            #expect(
                LinkedMediaFullscreenDiveLinkPresentation.diveNumberLabel(
                    for: nil,
                    useChronologicalNumbers: false,
                    chronologicalIndexByDiveID: [:]
                ) == "-"
            )
        }

        @Test @MainActor func linkedMediaFullscreenDiveLinkPresentation_siteDisplayName_defaultsWhenDiveMissing() {
            #expect(LinkedMediaFullscreenDiveLinkPresentation.siteDisplayName(for: nil) == "New Dive")
            #expect(LinkedMediaFullscreenDiveLinkPresentation.linkedTripTitle(for: nil) == nil)
        }

        @Test @MainActor func linkedMediaFullscreenPresentation_bottomLeadingCaptureTimestampLabels_usesOverlayLines() {
            let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
            let media = DiveMediaPhoto(
                capturedAt: capturedAt,
                photosLocalIdentifier: "test-photo"
            )
            let context = DiveMediaCaptureContext(elapsedSeconds: 720, depthMeters: 13.7)
            let labels = LinkedMediaFullscreenPresentation.bottomLeadingCaptureTimestampLabels(
                media: media,
                captureContext: context,
                timeZoneOffsetSeconds: nil,
                displayUnits: .imperial
            )
            #expect(labels != nil)
            #expect(labels?.secondary?.contains("into the dive") == true)
        }

        @Test @MainActor func linkedMediaFullscreenPresentation_bottomLeadingCaptureTimestampLabels_fallsBackWhenNoCaptureDate() {
            let media = DiveMediaPhoto(
                photosLocalIdentifier: "test-photo"
            )
            let labels = LinkedMediaFullscreenPresentation.bottomLeadingCaptureTimestampLabels(
                media: media,
                captureContext: nil,
                timeZoneOffsetSeconds: nil,
                displayUnits: .metric
            )
            #expect(labels?.primary == DiveActivityMediaPresentation.captureDateUnknownMessage)
            #expect(labels?.secondary == nil)
        }

        @Test @MainActor func linkedMediaFullscreenViewConfiguration_diveDepthChart_usesCaptureTimestampChrome() {
            #expect(LinkedMediaFullscreenView.Configuration.diveDepthChart.bottomLeadingChrome == .captureTimestamp)
        }

        @Test func linkedMediaFullscreenPresentation_shouldPresentTaggedMarineLifeSheet_requiresButtonAndTags() {
            #expect(
                LinkedMediaFullscreenPresentation.shouldPresentTaggedMarineLifeSheet(
                    showsMarineLifeTagButton: true,
                    hasTaggedSpecies: true
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.shouldPresentTaggedMarineLifeSheet(
                    showsMarineLifeTagButton: true,
                    hasTaggedSpecies: false
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.shouldPresentTaggedMarineLifeSheet(
                    showsMarineLifeTagButton: false,
                    hasTaggedSpecies: true
                )
            )
        }

        @Test func linkedMediaFullscreenPresentation_shouldPresentTaggedBuddiesSheet_requiresButtonsAndTags() {
            #expect(
                LinkedMediaFullscreenPresentation.shouldPresentTaggedBuddiesSheet(
                    showsMediaTagButtons: true,
                    hasTaggedBuddies: true
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.shouldPresentTaggedBuddiesSheet(
                    showsMediaTagButtons: true,
                    hasTaggedBuddies: false
                )
            )
            #expect(
                !LinkedMediaFullscreenPresentation.shouldPresentTaggedBuddiesSheet(
                    showsMediaTagButtons: false,
                    hasTaggedBuddies: true
                )
            )
            #expect(LinkedMediaTaggedBuddiesSheetPresentation.columnCount == 3)
            #expect(LinkedMediaTaggedBuddiesSheetPresentation.avatarDiameter == 64)
            #expect(
                !LinkedMediaTaggedOverviewSheetPresentation.showsAddTagsControl(
                    media: nil,
                    dive: nil
                )
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
            for detent in [DiveActivityOverviewDetent.minimized, .large] {
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
                    detent: .large
                )
            )
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
            #expect(
                DiveActivityVideoPlaybackPolicy.shouldOwnHoldToPauseInParent(mediaHitTestingEnabled: false)
            )
            #expect(
                !DiveActivityVideoPlaybackPolicy.shouldOwnHoldToPauseInParent(mediaHitTestingEnabled: true)
            )
        }

        @Test func diveActivityMediaPresentation_shouldPlayBackgroundVideo_mediaTabAtEveryDetent() {
            for detent in [DiveActivityOverviewDetent.minimized, .large] {
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
                    detent: .large
                )
            )
        }

        @Test func diveActivityMediaPresentation_mountsVideoPlayerOnlyWhenPlaybackActive() {
            #expect(DiveActivityMediaPresentation.mountsVideoPlayerForActivePlayback(true))
            #expect(!DiveActivityMediaPresentation.mountsVideoPlayerForActivePlayback(false))
        }

        @Test func diveActivityVideoPlaybackPolicy_settledMountRequiresActiveAndDelay() {
            #expect(
                DiveActivityVideoPlaybackPolicy.shouldMountSettledVideoPlayer(
                    isVideoPlaybackActive: true,
                    hasCompletedSettleDelay: true
                )
            )
            #expect(
                !DiveActivityVideoPlaybackPolicy.shouldMountSettledVideoPlayer(
                    isVideoPlaybackActive: true,
                    hasCompletedSettleDelay: false
                )
            )
            #expect(
                !DiveActivityVideoPlaybackPolicy.shouldMountSettledVideoPlayer(
                    isVideoPlaybackActive: false,
                    hasCompletedSettleDelay: true
                )
            )
            #expect(DiveActivityVideoPlaybackPolicy.videoPlayerMountSettleDelayNanoseconds >= 200_000_000)
        }

        @Test @MainActor func diveActivityMediaPresentation_resolvedSelectedPhotoID() {
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
                DiveActivityMediaPresentation.resolvedSelectedPhotoID(selectedID: first, in: [DiveMediaPhoto]()) == first
            )
            #expect(DiveActivityMediaPresentation.resolvedSelectedPhotoID(selectedID: nil, in: [DiveMediaPhoto]()) == nil)
        }

        @Test @MainActor func diveActivityMediaPresentation_adjacentPhotoID_stepsThroughGalleryOrder() {
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
            #expect(!DiveActivityMediaPresentation.showsCaptureDateOnHero(for: .large))
            #expect(!DiveActivityMediaPresentation.showsCaptureDateOnHero(for: .large))
        }

        @Test func diveActivityMediaPresentation_liquidGlassCaptureOverlay_matchesMinimizedHero() {
            #expect(
                DiveActivityMediaPresentation.usesLiquidGlassCaptureOverlayOnHero(for: .minimized)
                    == DiveActivityMediaPresentation.showsCaptureDateOnHero(for: .minimized)
            )
            #expect(!DiveActivityMediaPresentation.usesLiquidGlassCaptureOverlayOnHero(for: .large))
        }

        @Test func diveActivityMediaPresentation_landscapeGridStyleChrome_requiresLandscapeAndMedia() {
            #expect(
                DiveActivityMediaPresentation.showsLandscapeGridStyleMediaChrome(
                    isLandscape: true,
                    hasMedia: true
                )
            )
            #expect(
                !DiveActivityMediaPresentation.showsLandscapeGridStyleMediaChrome(
                    isLandscape: false,
                    hasMedia: true
                )
            )
            #expect(
                !DiveActivityMediaPresentation.showsLandscapeGridStyleMediaChrome(
                    isLandscape: true,
                    hasMedia: false
                )
            )
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
                    detent: .large,
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
                detent: .large
            )
            #expect(
                DiveActivityMediaPresentation.mediaCarouselPinnedStackHeight(
                    layoutHeight: layoutHeight,
                    detent: .large
                ) == inset + DiveActivityMediaPresentation.carouselRowHeight
            )
        }

        @Test func diveActivityMediaPresentation_disablesPanelScroll_mediaTabAllDetents() {
            #expect(
                DiveActivityMediaPresentation.disablesPanelScroll(
                    isMediaTabSelected: true,
                    detent: .minimized
                )
            )
            #expect(
                DiveActivityMediaPresentation.disablesPanelScroll(
                    isMediaTabSelected: true,
                    detent: .large
                )
            )
            #expect(
                DiveActivityMediaPresentation.disablesPanelScroll(
                    isMediaTabSelected: true,
                    detent: .large
                )
            )
            #expect(
                !DiveActivityMediaPresentation.disablesPanelScroll(
                    isMediaTabSelected: false,
                    detent: .large
                )
            )
        }

        @Test func diveActivityMediaPresentation_sheetBodyHeightAboveMediaCarousel_matchesMapTankHeaderBand() {
            let layoutHeight: CGFloat = 800
            let mediumInset = DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
                layoutHeight: layoutHeight,
                detent: .large
            )
            #expect(
                DiveActivityMediaPresentation.sheetBodyHeightAboveMediaCarousel(
                    layoutHeight: layoutHeight,
                    detent: .large
                ) == mediumInset
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

        @Test func marineLifeMediaTagPresentation_largeDetentUntaggedPrompt_directsUserToAddTag() {
            #expect(
                MarineLifeMediaTagPresentation.largeDetentUntaggedPrompt
                    .contains("Tap +")
            )
            #expect(
                !MarineLifeMediaTagPresentation.largeDetentUntaggedPrompt
                    .contains("medium height")
            )
            #expect(MarineLifeMediaTagPresentation.learnMoreLabel == "Learn More")
        }

        @Test func diveActivityMediaPresentation_showsMediaCarouselInSheet_atMinimizedOnly() {
            #expect(DiveActivityMediaPresentation.showsMediaCarouselInSheet(for: .minimized))
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

        @Test @MainActor func diveActivityMediaPresentation_mediaPositionLabel_usesSelectedItem() {
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
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
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
            context.insert(site)
            context.insert(activity)
            DiveActivitySiteAssociation.link(activity, to: site)
            try context.save()
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

            @Test func diveActivityMarineLifeOverviewPresentation_avatarKindPrefersModelThenPhoto() {
                #expect(
                    DiveActivityMarineLifeOverviewPresentation.resolvedAvatarKind(
                        featureModelResourceName: "BarredHamlet",
                        featureImageResourceName: "marine-life-barred-hamlet",
                        featureImageURL: "https://example.com/x.jpg"
                    ) == .model3D(resourceName: "BarredHamlet")
                )
                #expect(
                    DiveActivityMarineLifeOverviewPresentation.resolvedAvatarKind(
                        featureModelResourceName: "",
                        featureImageResourceName: "marine-life-barred-hamlet",
                        featureImageURL: ""
                    ) == .photo(resourceName: "marine-life-barred-hamlet", imageURL: "")
                )
                #expect(
                    DiveActivityMarineLifeOverviewPresentation.resolvedAvatarKind(
                        featureModelResourceName: "  ",
                        featureImageResourceName: "",
                        featureImageURL: ""
                    ) == .fishIcon
                )
            }
            @Test func diveActivityMarineLifeOverviewPresentation_compactAvatarConfigMaximizesModelAndDropsGlow() {
                let config = DiveActivityMarineLifeOverviewPresentation.compactModelSceneConfiguration(
                    resourceName: "BarredHamlet",
                    minSizeMeters: 0.05,
                    maxSizeMeters: 0.1
                )
                // Avatar uses the fixed max fit (not the tiny species-size hero fit) and no glow plate,
                // centered vertically with drag disabled.
                #expect(config.fitExtent == DiveActivityMarineLifeOverviewPresentation.avatarModelFitExtent)
                #expect(config.showsGlow == false)
                #expect(config.modelVerticalOffset == 0)
                #expect(config.allowsDragRotation == false)
            }
            @Test func diveActivityMarineLifeOverviewPresentation_uniqueSpeciesChips_dedupesByUUID() {
                let diveID = UUID()
                let first = SightingInstance(
                    sightingUUID: "s1",
                    marineLifeUUID: "marine-life-a",
                    sightingDateTime: Date(timeIntervalSince1970: 100)
                )
                first.diveActivityID = diveID
                let second = SightingInstance(
                    sightingUUID: "s2",
                    marineLifeUUID: "marine-life-a",
                    sightingDateTime: Date(timeIntervalSince1970: 200)
                )
                second.diveActivityID = diveID
                let third = SightingInstance(
                    sightingUUID: "s3",
                    marineLifeUUID: "marine-life-b",
                    sightingDateTime: Date(timeIntervalSince1970: 150)
                )
                third.diveActivityID = diveID

                let catalog = [
                    MarineLife(uuid: "marine-life-b", commonName: "Zebra"),
                    MarineLife(uuid: "marine-life-a", commonName: "Alpha"),
                ]
                let chips = DiveActivityMarineLifeOverviewPresentation.uniqueSpeciesChips(
                    sightings: [first, second, third],
                    catalog: catalog
                )
                #expect(chips.map(\.marineLifeUUID) == ["marine-life-a", "marine-life-b"])
                #expect(chips.map(\.commonName) == ["Alpha", "Zebra"])
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
            @Test func diveMarineLifeTagSheetPresentation_identifySheetAccessibilityIdentifiers() {
                #expect(
                    DiveMarineLifeTagSheetPresentation.identifySheetCancelAccessibilityIdentifier
                        == "DiveMediaFishialIdentify.Cancel"
                )
                #expect(
                    DiveMarineLifeTagSheetPresentation.identifySheetDoneAccessibilityIdentifier
                        == "DiveMediaFishialIdentify.Done"
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
            @Test func diveMarineLifeTagPickerPresentation_doneConfirmChrome_allowsInteractiveDismiss() {
                #expect(DiveMarineLifeTagPickerPresentation.doneButtonTitle == "Done")
                #expect(DiveMarineLifeTagPickerPresentation.doneAccessibilityIdentifier == "DiveMarineLifeTagPicker.Done")
                #expect(DiveMarineLifeTagPickerPresentation.cancelAccessibilityIdentifier == "DiveMarineLifeTagPicker.Cancel")
                #expect(DiveMarineLifeTagPickerPresentation.addSpeciesAccessibilityIdentifier == "DiveMarineLifeTagPicker.AddSpecies")
                #expect(DiveMarineLifeTagPickerPresentation.blocksInteractiveDismiss(pendingTagCount: 0) == true)
                #expect(DiveMarineLifeTagPickerPresentation.blocksInteractiveDismiss(pendingTagCount: 1) == true)
            }
            @Test func diveMediaBuddyTagPresentation_toolbarChromeIdentifiers() {
                #expect(DiveMediaBuddyTagPresentation.sheetTitle == "Tag buddy")
                #expect(DiveMediaBuddyTagPresentation.doneButtonTitle == "Done")
                #expect(DiveMediaBuddyTagPresentation.doneAccessibilityIdentifier == "DiveMediaBuddyTagPicker.Done")
                #expect(DiveMediaBuddyTagPresentation.cancelAccessibilityIdentifier == "DiveMediaBuddyTagPicker.Cancel")
                #expect(DiveMediaBuddyTagPresentation.addBuddyAccessibilityIdentifier == "DiveMediaBuddyTagPicker.AddBuddy")
                #expect(DiveMediaBuddyTagPresentation.addBuddyAccessibilityLabel == "Add buddy")
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
            @Test @MainActor func diveMediaFishialIdentificationStorage_saveConfirmedSpecies_persistsOnMedia() throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveMediaPhoto.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
            #if canImport(Photos)
            @Test func diveMediaReferenceLoader_videoRequestOptions_useFullResolutionPlayback() {
                let options = DiveMediaReferenceLoader.makeVideoRequestOptions()
                // Highest-quality original (download from iCloud when needed) rather than a transcoded/automatic stream.
                #expect(options.deliveryMode == .highQualityFormat)
                #expect(options.isNetworkAccessAllowed)
            }

            @Test func diveMediaReferenceLoader_homeCarouselVideoOptions_streamMediumRendition() {
                let options = DiveMediaReferenceLoader.makeVideoRequestOptions(quality: .homeCarousel)
                // `.automatic` resolved to full-quality downloads on optimized-storage libraries and timed out.
                #expect(options.deliveryMode == .mediumQualityFormat)
                #expect(DiveMediaVideoRequestQuality.homeCarousel.photoKitDeliveryMode == .mediumQualityFormat)
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

            @Test @MainActor func diveMediaPreviewStorage_storedPreviewImage_reusesDecodedInstance() {
                // Scroll perf: grid cells read the stored preview in `body`, so repeated calls must
                // return the cached decode (same instance) instead of re-decoding JPEG data each time.
                let media = DiveMediaPhoto(
                    sortOrder: 0,
                    photosLocalIdentifier: "preview-decode-cache-test"
                )
                media.previewJPEGData = DiveMediaPreviewPersistence.encodePreviewJPEG(solidTestImage(edge: 64))
                let first = DiveMediaPreviewStorage.storedPreviewImage(for: media)
                let second = DiveMediaPreviewStorage.storedPreviewImage(for: media)
                #expect(first != nil)
                #expect(first === second)

                let missing = DiveMediaPhoto(
                    sortOrder: 1,
                    photosLocalIdentifier: "preview-decode-cache-missing"
                )
                #expect(DiveMediaPreviewStorage.storedPreviewImage(for: missing) == nil)
            }

            @Test @MainActor func diveMediaPreviewStorage_cachedStoredPreviewImage_skipsDecodeUntilLoaded() async {
                let media = DiveMediaPhoto(
                    sortOrder: 0,
                    photosLocalIdentifier: "preview-cache-only-test"
                )
                media.previewJPEGData = DiveMediaPreviewPersistence.encodePreviewJPEG(solidTestImage(edge: 48))
                #expect(DiveMediaPreviewStorage.cachedStoredPreviewImage(for: media) == nil)
                let loaded = await DiveMediaPreviewStorage.loadStoredPreviewImage(for: media)
                #expect(loaded != nil)
                #expect(DiveMediaPreviewStorage.cachedStoredPreviewImage(for: media) === loaded)
            }

            @Test func goDiveDecodedImageCachePresentation_cacheKeysAreStable() {
                let data = Data([0x01, 0x02, 0x03, 0x04])
                let keyA = GoDiveDecodedImageCachePresentation.cacheKey(for: data)
                let keyB = GoDiveDecodedImageCachePresentation.cacheKey(for: data)
                #expect(keyA == keyB)
                #expect(keyA != GoDiveDecodedImageCachePresentation.cacheKey(for: Data([0x99])))
                let fileURL = URL(fileURLWithPath: "/tmp/catalog-photo.jpg")
                #expect(
                    GoDiveDecodedImageCachePresentation.cacheKey(fileURL: fileURL, maxPixelEdge: 160)
                        == GoDiveDecodedImageCachePresentation.cacheKey(fileURL: fileURL, maxPixelEdge: 160)
                )
                #expect(
                    GoDiveDecodedImageCachePresentation.cacheKey(fileURL: fileURL, maxPixelEdge: 160)
                        != GoDiveDecodedImageCachePresentation.cacheKey(fileURL: fileURL, maxPixelEdge: 480)
                )
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
            @Test func diveMediaVideoLoad_timeout_isPositive() {
                #expect(DiveMediaVideoLoad.timeoutSeconds > 0)
                #expect(DiveMediaVideoRequestQuality.homeCarousel.usesPlayerItemRequest)
                #expect(!DiveMediaVideoRequestQuality.fullQuality.usesPlayerItemRequest)
                #expect(DiveMediaVideoLoad.softTimeoutSeconds == 15)
                #expect(DiveMediaVideoLoad.hardTimeoutSeconds == 90)
                #expect(!DiveMediaVideoLoad.shouldExtractAssetInPlayerItemCallback())
                #expect(
                    DiveMediaVideoLoad.shouldFailVideoRequest(
                        elapsedSeconds: 15,
                        hasSeenProgress: false
                    )
                )
                #expect(
                    !DiveMediaVideoLoad.shouldFailVideoRequest(
                        elapsedSeconds: 15,
                        hasSeenProgress: true
                    )
                )
                #expect(
                    DiveMediaVideoLoad.shouldFailVideoRequest(
                        elapsedSeconds: 90,
                        hasSeenProgress: true
                    )
                )
                #expect(
                    HomeCarouselVideoPresentation.shouldPreloadLibraryIdentifier(
                        mediaKind: .video,
                        localIdentifier: "ABC/L0/001"
                    )
                )
                #expect(
                    !HomeCarouselVideoPresentation.shouldPreloadLibraryIdentifier(
                        mediaKind: .image,
                        localIdentifier: "ABC/L0/001"
                    )
                )
                #expect(
                    HomeCarouselVideoPresentation.libraryIdentifiersForPreload(
                        from: [],
                        limit: 3
                    ).isEmpty
                )
                #expect(
                    DiveMediaVideoLoad.requestFailureDetail(
                        timedOut: true,
                        networkAllowed: true,
                        elapsedSeconds: 30,
                        isInCloud: true,
                        errorDescription: nil
                    ).contains("timedOut")
                )
                #expect(
                    DiveMediaVideoLoad.requestFailureDetail(
                        timedOut: false,
                        networkAllowed: false,
                        elapsedSeconds: 0.2,
                        isInCloud: true,
                        errorDescription: "denied"
                    ).contains("net=0")
                )
                #expect(
                    DiveMediaVideoLoad.preferredAssetAfterRequest(
                        requestedAssetResolved: false,
                        sessionCachedAvailable: true
                    )
                )
                #expect(
                    !DiveMediaVideoLoad.preferredAssetAfterRequest(
                        requestedAssetResolved: false,
                        sessionCachedAvailable: false
                    )
                )
                #expect(
                    HomeMediaHighlightWarmupPresentation.shouldSkipStillPhotoKitLoadWhileVideoResolves(
                        isVideo: true,
                        hasDisplayablePoster: true
                    )
                )
                #expect(
                    !HomeMediaHighlightWarmupPresentation.shouldSkipStillPhotoKitLoadWhileVideoResolves(
                        isVideo: true,
                        hasDisplayablePoster: false
                    )
                )
                #expect(
                    !HomeMediaHighlightWarmupPresentation.shouldSkipStillPhotoKitLoadWhileVideoResolves(
                        isVideo: false,
                        hasDisplayablePoster: true
                    )
                )
                #expect(
                    DiveMediaVideoPhotoKitGatePresentation.shouldEnsureCarouselVideoReady(
                        isSlidePlaybackActive: true
                    )
                )
                #expect(
                    !DiveMediaVideoPhotoKitGatePresentation.shouldEnsureCarouselVideoReady(
                        isSlidePlaybackActive: false
                    )
                )
                #expect(
                    DiveMediaVideoPhotoKitGatePresentation.shouldEnsureCarouselVideoReady(
                        isSlidePlaybackActive: false,
                        isAdjacentToActive: true
                    )
                )
                #expect(
                    !DiveMediaVideoPhotoKitGatePresentation.shouldEnsureCarouselVideoReady(
                        isSlidePlaybackActive: true,
                        isLaunchWarmOwningGate: true
                    )
                )
                #expect(
                    !DiveMediaVideoPhotoKitGatePresentation.shouldEnsureCarouselVideoReady(
                        isSlidePlaybackActive: false,
                        isAdjacentToActive: true,
                        isLaunchWarmOwningGate: true
                    )
                )
                #expect(
                    DiveMediaVideoPhotoKitGatePresentation.adjacentLogicalIndices(
                        activeLogicalIndex: 0,
                        slideCount: 3
                    ) == [2, 1]
                )
                // Active + forward neighbor only — wrap-previous of 0 must NOT prepare (starved slide 0).
                #expect(
                    DiveMediaVideoPhotoKitGatePresentation.shouldPrepareCarouselVideo(
                        logicalIndex: 0,
                        activeLogicalIndex: 0,
                        slideCount: 3
                    )
                )
                #expect(
                    DiveMediaVideoPhotoKitGatePresentation.shouldPrepareCarouselVideo(
                        logicalIndex: 1,
                        activeLogicalIndex: 0,
                        slideCount: 3
                    )
                )
                #expect(
                    !DiveMediaVideoPhotoKitGatePresentation.shouldPrepareCarouselVideo(
                        logicalIndex: 2,
                        activeLogicalIndex: 0,
                        slideCount: 3
                    )
                )
                #expect(
                    !DiveMediaVideoPhotoKitGatePresentation.shouldPrepareCarouselVideo(
                        logicalIndex: 0,
                        activeLogicalIndex: 1,
                        slideCount: 3
                    )
                )
                #expect(
                    HomeMediaCarouselPresentation.isPagerPagePlaybackActive(
                        pagerIndex: 0,
                        selectedPagerIndex: 0
                    )
                )
                #expect(
                    !HomeMediaCarouselPresentation.isPagerPagePlaybackActive(
                        pagerIndex: 3,
                        selectedPagerIndex: 0
                    )
                )
                #expect(
                    HomeMediaCarouselPresentation.shouldRemountCarouselPlayerWhenBecomingActive(
                        isBecomingActive: true,
                        hasPreparedPlayer: true
                    )
                )
                #expect(
                    !HomeMediaCarouselPresentation.shouldRemountCarouselPlayerWhenBecomingActive(
                        isBecomingActive: true,
                        hasPreparedPlayer: false
                    )
                )
                #expect(
                    HomeMediaHighlightWarmupPresentation.shouldSkipStillPhotoKitLoadWhileVideoResolves(
                        isVideo: true,
                        hasDisplayablePoster: true,
                        isVideoPrepareInFlightOrReady: true
                    )
                )
                #expect(
                    !HomeMediaHighlightWarmupPresentation.shouldSkipStillPhotoKitLoadWhileVideoResolves(
                        isVideo: true,
                        hasDisplayablePoster: true,
                        isVideoPrepareInFlightOrReady: false
                    )
                )
                let priority = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
                let ordered = DiveMediaVideoPhotoKitGatePresentation.prioritizedVideoMediaIDs(
                    mediaIDs: [
                        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                        priority,
                        UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                    ],
                    priorityMediaID: priority
                )
                #expect(ordered.first == priority)
            }
            @Test func diveMediaStillLoad_timesOutToDegradedFallbackWithoutCaching() {
                #expect(DiveMediaStillLoad.requestTimeoutSeconds > 0)
                #expect(DiveMediaStillLoad.shouldCacheFetchedImage(isFinal: true))
                #expect(!DiveMediaStillLoad.shouldCacheFetchedImage(isFinal: false))
                #expect(DiveMediaStillLoad.timeoutFallbackImage(latestDegraded: "degraded") == "degraded")
                #expect(DiveMediaStillLoad.timeoutFallbackImage(latestDegraded: String?.none) == nil)
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
            @Test func diveMediaVideoRequestQuality_cachesInSession() {
                #expect(DiveMediaVideoRequestQuality.fullQuality.cachesInSession)
                #expect(DiveMediaVideoRequestQuality.homeCarousel.cachesInSession)
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
                #expect(
                    DiveMediaProgressivePresentation.allowsFullQualityUpgrade(for: .fullQuality)
                )
                #expect(
                    DiveMediaProgressivePresentation.allowsFullQualityUpgrade(for: .homeCarousel)
                )
                #expect(
                    !DiveMediaProgressivePresentation.allowsBackgroundFullVideoUpgrade(for: .homeCarousel)
                )
                #expect(
                    !DiveMediaProgressivePresentation.allowsBackgroundFullVideoUpgrade(for: .fullQuality)
                )
                #expect(
                    DiveMediaProgressivePresentation.shouldScheduleFullVideoUpgrade(
                        isPlaybackActive: true,
                        isPausedByUserHold: false,
                        currentFidelity: .preview,
                        isPreviewDisplayReady: true
                    )
                )
                #expect(
                    !DiveMediaProgressivePresentation.shouldScheduleFullVideoUpgrade(
                        isPlaybackActive: true,
                        isPausedByUserHold: false,
                        currentFidelity: .preview,
                        isPreviewDisplayReady: false
                    )
                )
                #expect(
                    DiveMediaProgressivePresentation.preferredStillImage(
                        progressive: "sharp",
                        sessionCached: "soft",
                        storedPreview: "jpeg"
                    ) == "sharp"
                )
                #expect(
                    DiveMediaProgressivePresentation.preferredStillImage(
                        progressive: String?.none,
                        sessionCached: "soft",
                        storedPreview: "jpeg"
                    ) == "soft"
                )
                #if canImport(UIKit)
                func solidImage(width: CGFloat, height: CGFloat) -> UIImage {
                    let size = CGSize(width: width, height: height)
                    let renderer = UIGraphicsImageRenderer(size: size)
                    return renderer.image { context in
                        UIColor.gray.setFill()
                        context.fill(CGRect(origin: .zero, size: size))
                    }
                }
                let soft = solidImage(width: 32, height: 32)
                let sharp = solidImage(width: 128, height: 128)
                #expect(
                    DiveMediaProgressivePresentation.preferredStillImage(
                        progressive: sharp,
                        sessionCached: soft,
                        storedPreview: soft
                    ) === sharp
                )
                #expect(
                    DiveMediaProgressivePresentation.preferredStillImage(
                        progressive: soft,
                        sessionCached: sharp,
                        storedPreview: soft
                    ) === sharp
                )
                #expect(
                    DiveMediaProgressivePresentation.pixelArea(sharp) > DiveMediaProgressivePresentation.pixelArea(soft)
                )
                #endif
                #expect(
                    HomeMediaHighlightWarmupPresentation.bootstrapStillQuality(isVideo: false) == .preview
                )
                #expect(
                    HomeMediaHighlightWarmupPresentation.bootstrapStillQuality(isVideo: true) == .preview
                )
                #expect(
                    HomeMediaHighlightWarmupPresentation.upgradeStillQuality(isVideo: false) == .full
                )
                #expect(
                    HomeMediaHighlightWarmupPresentation.upgradeStillQuality(isVideo: true) == nil
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
            @Test func diveMediaReferenceLoader_existingLocalIdentifiers_ignoresBlankIDs() {
                #expect(DiveMediaReferenceLoader.existingLocalIdentifiers(in: []) == [])
                #expect(DiveMediaReferenceLoader.existingLocalIdentifiers(in: ["", "  "]) == [])
            }
            @Test func diveMediaImportProgressPresentation_progressFraction_clampsToUnitInterval() {
                #expect(DiveMediaImportProgressPresentation.progressFraction(completed: 2, total: 5) == 0.4)
                #expect(DiveMediaImportProgressPresentation.progressFraction(completed: 5, total: 5) == 1.0)
                #expect(DiveMediaImportProgressPresentation.progressFraction(completed: 0, total: 0) == 0)
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
            @Test func diveMediaCloudIdentifierPolicy_needsCapture_whenLocalPresentAndCloudMissing() {
                #expect(
                    DiveMediaCloudIdentifierPolicy.needsCloudIdentifierCapture(
                        localIdentifier: "LOCAL/1",
                        cloudIdentifier: ""
                    )
                )
                #expect(
                    !DiveMediaCloudIdentifierPolicy.needsCloudIdentifierCapture(
                        localIdentifier: "LOCAL/1",
                        cloudIdentifier: "cloud/abc"
                    )
                )
                #expect(
                    !DiveMediaCloudIdentifierPolicy.needsCloudIdentifierCapture(
                        localIdentifier: nil,
                        cloudIdentifier: ""
                    )
                )
            }
            @Test func diveMediaCloudIdentifierPolicy_shouldAttemptResolve_whenLocalMissingAndCloudPresent() {
                #expect(
                    DiveMediaCloudIdentifierPolicy.shouldAttemptCloudResolve(
                        localAssetExists: false,
                        cloudIdentifier: "cloud/abc"
                    )
                )
                #expect(
                    !DiveMediaCloudIdentifierPolicy.shouldAttemptCloudResolve(
                        localAssetExists: true,
                        cloudIdentifier: "cloud/abc"
                    )
                )
                #expect(
                    !DiveMediaCloudIdentifierPolicy.shouldAttemptCloudResolve(
                        localAssetExists: false,
                        cloudIdentifier: "  "
                    )
                )
            }
            @Test func diveMediaCloudIdentifierPolicy_shouldPrune_waitsForCloudResolve() {
                // Cloud ID present but resolve not attempted yet → keep (Device B race).
                #expect(
                    !DiveMediaCloudIdentifierPolicy.shouldPrune(
                        hasLocalIdentifier: true,
                        hasCloudIdentifier: true,
                        hasFullAuthorization: true,
                        localAssetExists: false,
                        cloudResolve: nil
                    )
                )
                // Cloud resolve says deleted → prune.
                #expect(
                    DiveMediaCloudIdentifierPolicy.shouldPrune(
                        hasLocalIdentifier: true,
                        hasCloudIdentifier: true,
                        hasFullAuthorization: true,
                        localAssetExists: false,
                        cloudResolve: .notFound
                    )
                )
                // Remapped ID still missing from Photos (reinstall + deleted original) → prune.
                #expect(
                    DiveMediaCloudIdentifierPolicy.shouldPrune(
                        hasLocalIdentifier: true,
                        hasCloudIdentifier: true,
                        hasFullAuthorization: true,
                        localAssetExists: false,
                        cloudResolve: .resolved(localIdentifier: "OTHER/1")
                    )
                )
                // Unavailable → keep (PhotoKit not ready / transient).
                #expect(
                    !DiveMediaCloudIdentifierPolicy.shouldPrune(
                        hasLocalIdentifier: false,
                        hasCloudIdentifier: true,
                        hasFullAuthorization: true,
                        localAssetExists: false,
                        cloudResolve: .unavailable
                    )
                )
                // No cloud ID, local missing under full auth → prune (legacy pointer).
                #expect(
                    DiveMediaCloudIdentifierPolicy.shouldPrune(
                        hasLocalIdentifier: true,
                        hasCloudIdentifier: false,
                        hasFullAuthorization: true,
                        localAssetExists: false,
                        cloudResolve: nil
                    )
                )
            }
            @Test func diveMediaCloudIdentifierStorage_normalized_trimsAndDetectsPresence() {
                #expect(DiveMediaCloudIdentifierStorage.normalized("  abc  ") == "abc")
                #expect(DiveMediaCloudIdentifierStorage.isPresent(" cloud "))
                #expect(!DiveMediaCloudIdentifierStorage.isPresent("   "))
                #expect(!DiveMediaCloudIdentifierStorage.isPresent(nil))
            }
            @Test func diveMediaPhoto_libraryCloudIdentifier_trimsAndNilsWhenBlank() {
                let blank = DiveMediaPhoto(photosCloudIdentifier: "  ")
                #expect(blank.libraryCloudIdentifier == nil)
                let present = DiveMediaPhoto(photosCloudIdentifier: " cloud/1 ")
                #expect(present.libraryCloudIdentifier == "cloud/1")
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
}
