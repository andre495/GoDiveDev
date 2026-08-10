//
//  FriendSharedMediaTests.swift
//  GoDiveMVPTests
//

import CloudKit
import Contacts
import AuthenticationServices
import CoreGraphics
import CoreLocation
import Foundation
import FirebaseFirestore
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


struct FriendSharedMediaTests {
        @Test func goDiveSharedMediaStorage_objectPaths_useTieredLayout() {
            let ownerUID = "owner-uid"
            let activityID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let mediaID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

            #expect(
                GoDiveSharedMediaStorage.objectPath(
                    ownerUID: ownerUID,
                    activityID: activityID,
                    mediaID: mediaID,
                    tier: .thumb
                ) == "users/owner-uid/sharedMedia/00000000-0000-0000-0000-000000000001/00000000-0000-0000-0000-000000000002/thumb.jpg"
            )
            #expect(
                GoDiveSharedMediaStorage.objectPath(
                    ownerUID: ownerUID,
                    activityID: activityID,
                    mediaID: mediaID,
                    tier: .photo
                ).hasSuffix("/photo.jpg")
            )
            #expect(
                GoDiveSharedMediaStorage.objectPath(
                    ownerUID: ownerUID,
                    activityID: activityID,
                    mediaID: mediaID,
                    tier: .video
                ).hasSuffix("/video.mp4")
            )
            #expect(
                GoDiveSharedMediaStorage.legacyPreviewObjectPath(
                    ownerUID: ownerUID,
                    activityID: activityID,
                    mediaID: mediaID
                ).hasSuffix("00000000-0000-0000-0000-000000000002.jpg")
            )
        }

        @Test func goDiveSharedMediaLimits_capsMatchDesign() {
            #expect(GoDiveSharedMediaLimits.maxPhotosPerActivity == 20)
            #expect(GoDiveSharedMediaLimits.maxVideosPerActivity == 10)
            #expect(GoDiveSharedMediaLimits.maxSharedVideoDurationSeconds == 30)
        }

        @Test func goDiveSharedMediaSelection_capsPhotosAndVideosInGalleryOrder() {
            let base = Date(timeIntervalSince1970: 1_700_000_000)
            var candidates: [GoDiveSharedMediaSelection.ShareCandidate] = []
            for index in 0 ..< 25 {
                candidates.append(
                    .init(
                        id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", index))!,
                        kind: .image,
                        capturedAt: base.addingTimeInterval(Double(index)),
                        sortOrder: index
                    )
                )
            }
            for index in 25 ..< 40 {
                candidates.append(
                    .init(
                        id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012x", index))!,
                        kind: .video,
                        capturedAt: base.addingTimeInterval(Double(index)),
                        sortOrder: index
                    )
                )
            }

            let filtered = GoDiveSharedMediaSelection.filteredForShare(candidates: candidates)
            #expect(filtered.filter { $0.kind == .image }.count == 20)
            #expect(filtered.filter { $0.kind == .video }.count == 10)
            #expect(filtered.count == 30)
            #expect(filtered.first?.kind == .image)
            #expect(filtered[19].kind == .image)
            #expect(filtered[20].kind == .video)
        }

        @Test @MainActor func goDiveSharedMediaSelection_uploadOrder_putsFeaturedFirst() {
            let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let featured = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            let third = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

            struct StubMedia: ActivityOverviewGalleryMedia {
                let id: UUID
                var capturedAt: Date? = nil
                var sortOrder: Int = 0
                var previewJPEGData: Data? = nil
                var fishialConfirmedSpeciesName: String = ""
                var photosLocalIdentifier: String = ""
                var mediaKind: String = DiveMediaKind.image.rawValue
            }

            let selected = [
                StubMedia(id: first),
                StubMedia(id: featured),
                StubMedia(id: third),
            ]
            let ordered = GoDiveSharedMediaSelection.uploadOrder(selected: selected, featuredID: featured)
            #expect(ordered.map(\.id) == [featured, first, third])
        }

        @Test func goDiveSharedMediaPublishState_tracksRemovedMediaIDs() {
            let activity = GoDiveSharedMediaPublishState.ActivityRecord(items: [
                .init(
                    mediaID: "a",
                    kind: "photo",
                    sourceFingerprint: "fp-a",
                    exportFingerprint: nil,
                    thumbnailURL: "https://example.com/a.jpg",
                    contentURL: nil,
                    width: nil,
                    height: nil,
                    durationSeconds: nil,
                    contentBytes: nil
                ),
                .init(
                    mediaID: "b",
                    kind: "photo",
                    sourceFingerprint: "fp-b",
                    exportFingerprint: nil,
                    thumbnailURL: "https://example.com/b.jpg",
                    contentURL: nil,
                    width: nil,
                    height: nil,
                    durationSeconds: nil,
                    contentBytes: nil
                ),
            ])
            let removed = GoDiveSharedMediaPublishState.removedMediaIDs(
                previous: activity,
                currentMediaIDs: ["a"]
            )
            #expect(removed == ["b"])
        }

        @Test func goDiveSharedMediaPublishState_sha256Hex_changesWithContent() {
            let photo = Data([0x01, 0x02, 0x03])
            let video = Data([0x04, 0x05, 0x06])
            let first = GoDiveSharedMediaPublishState.sha256Hex(photo)
            let second = GoDiveSharedMediaPublishState.sha256Hex(video)
            #expect(first != second)
            #expect(first == GoDiveSharedMediaPublishState.sha256Hex(photo))
            #expect(first.count == 64)
        }

        @Test func friendProfileHeroMediaKind_parsesFirestore() {
            #expect(GoDiveProfileHeroMediaKind.fromFirestoreValue("image") == .image)
            #expect(GoDiveProfileHeroMediaKind.fromFirestoreValue("video") == .video)
            #expect(GoDiveProfileHeroMediaKind.fromFirestoreValue("other") == nil)
        }

        @Test func friendProfileHero_firebaseStorageURLGate() {
            let url = "https://firebasestorage.googleapis.com/v0/b/test/o/users%2Fuid%2FprofileHero.jpg?alt=media"
            #expect(GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: url) != nil)
            #expect(GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: "http://evil.com/x") == nil)
        }

        @Test func friendProfile_remoteHeroClipsOverflowingMedia() {
            #expect(FriendProfilePresentation.clipsOverflowingHeroMedia)
        }

        @Test func friendProfileHero_prefersAccountHeroAndInfersKind() {
            let url = "https://firebasestorage.googleapis.com/v0/b/test/o/users%2Fuid%2FprofileHero.jpg?alt=media"
            let hero = FriendProfileHeroPresentation.resolvedHero(
                profileHeroURL: url,
                profileHeroMediaKind: nil
            )
            #expect(hero?.kind == .image)
            #expect(hero?.url.absoluteString.contains("profileHero.jpg") == true)
            #expect(
                FriendProfileHeroPresentation.hasAssociatedMedia(
                    profileHeroURL: url,
                    profileHeroMediaKind: nil
                )
            )
            #expect(FriendProfileHeroPresentation.inferredKind(fromURLString: url) == .image)
            #expect(
                FriendProfileHeroPresentation.inferredKind(
                    fromURLString: "https://firebasestorage.googleapis.com/v0/b/test/o/users%2Fuid%2FprofileHero.mp4?alt=media"
                ) == .video
            )
        }

        @Test func friendProfileHero_fallsBackToNewestSharedDiveFeaturedMedia() {
            let older = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "older",
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "Old Reef",
                locationName: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [
                    GoDiveSharedDiveProjectionMapping.MediaItemSnapshot(
                        mediaID: "old-photo",
                        kind: .photo,
                        thumbnailURL: "https://firebasestorage.googleapis.com/v0/b/test/o/old.jpg?alt=media",
                        contentURL: "https://firebasestorage.googleapis.com/v0/b/test/o/old-full.jpg?alt=media",
                        width: nil,
                        height: nil,
                        durationSeconds: nil,
                        contentBytes: nil
                    ),
                ],
                mediaPreviews: [],
                featuredMediaPhotoID: "old-photo",
                profileTrackBase64: nil
            )
            let newer = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "newer",
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "New Reef",
                locationName: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [
                    GoDiveSharedDiveProjectionMapping.MediaItemSnapshot(
                        mediaID: "new-video",
                        kind: .video,
                        thumbnailURL: "https://firebasestorage.googleapis.com/v0/b/test/o/new.jpg?alt=media",
                        contentURL: "https://firebasestorage.googleapis.com/v0/b/test/o/new.mp4?alt=media",
                        width: nil,
                        height: nil,
                        durationSeconds: nil,
                        contentBytes: nil
                    ),
                ],
                mediaPreviews: [],
                featuredMediaPhotoID: "new-video",
                profileTrackBase64: nil
            )
            let hero = FriendProfileHeroPresentation.resolvedHero(
                profileHeroURL: nil,
                profileHeroMediaKind: nil,
                sharedDives: [older, newer]
            )
            #expect(hero?.kind == .video)
            #expect(hero?.url.absoluteString.contains("new.mp4") == true)
        }

        @Test @MainActor func friendProfileLifetimeStats_buildsHighlightTilesFromSharedDives() {
            let deepID = UUID()
            let longID = UUID()
            let deep = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: deepID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 40,
                diveNumber: 1,
                siteName: "Blue Hole",
                locationName: nil,
                activityTagNames: [],
                sightings: [
                    .init(commonName: "Eagle Ray", scientificName: nil, catalogUUID: "ray-1"),
                    .init(commonName: "Eagle Ray", scientificName: nil, catalogUUID: "ray-1"),
                ],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let long = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: longID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 90,
                maxDepthMeters: 18,
                diveNumber: 2,
                siteName: "Blue Hole",
                locationName: nil,
                activityTagNames: [],
                sightings: [
                    .init(commonName: "Turtle", scientificName: nil, catalogUUID: "turtle-1"),
                ],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let stats = FriendProfileLifetimeStatsPresentation.build(from: [deep, long])
            #expect(stats.diveCount == 2)
            #expect(stats.deepestDive?.id == deepID)
            #expect(stats.deepestMaxDepthMeters == 40)
            #expect(stats.longestDive?.id == longID)
            #expect(stats.longestDurationMinutes == 90)
            #expect(stats.mostVisitedSite?.name == "Blue Hole")
            #expect(stats.mostVisitedSite?.visitCount == 2)
            #expect(stats.topSpecies?.commonName == "Eagle Ray")
            #expect(stats.topSpecies?.sightingCount == 2)

            let tiles = HomeLifetimeStatsPresentation.highlightStatTileDescriptors(
                stats: stats,
                unitSystem: .metric,
                opensLeaderboards: false,
                emptyFootnotes: .friendShared
            )
            #expect(tiles.count == 4)
            #expect(tiles.allSatisfy { $0.leaderboardKind == nil })
            #expect(
                FriendProfileContentPagerPresentation.pages
                    == [.diverStats, .sharedActivities, .sharedMedia]
            )
            #expect(FriendProfileContentPagerPresentation.defaultPage == .diverStats)
        }

        @Test func friendProfileMapPins_sharedBlueTogetherRedTogetherWins() {
            let sharedID = UUID()
            let togetherID = UUID()
            let sharedOnly = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: sharedID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "Shared Reef",
                locationName: nil,
                entryLatitude: 17.3,
                entryLongitude: -87.5,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let togetherShared = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: togetherID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 45,
                maxDepthMeters: 20,
                siteName: "Together Reef",
                locationName: nil,
                entryLatitude: 18.1,
                entryLongitude: -88.2,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [.init(displayName: "Me", firebaseUID: "me-uid")],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let pins = FriendProfileSharedDiveMapPresentation.pins(
                sharedDives: [sharedOnly, togetherShared],
                togetherDives: [],
                togetherActivityIDs: [togetherID],
                catalogSites: [],
                currentFirebaseUID: "me-uid"
            )
            #expect(pins.count == 2)
            let byTitle = Dictionary(uniqueKeysWithValues: pins.map { ($0.title, $0.kind) })
            #expect(byTitle["Shared Reef"] == .friendShared)
            #expect(byTitle["Together Reef"] == .friendTogether)
            #expect(TripDetailMapPinKind.friendShared.markerTintColor == .systemBlue)
            #expect(TripDetailMapPinKind.friendTogether.markerTintColor == .systemRed)

            let sameCoordShared = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: UUID().uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_200_000),
                durationMinutes: 30,
                maxDepthMeters: 12,
                siteName: "Overlap Site",
                locationName: nil,
                entryLatitude: 19.0,
                entryLongitude: -89.0,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let sameCoordTogether = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: UUID().uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_300_000),
                durationMinutes: 35,
                maxDepthMeters: 14,
                siteName: "Overlap Site",
                locationName: nil,
                entryLatitude: 19.0,
                entryLongitude: -89.0,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [.init(displayName: "Me", firebaseUID: "me-uid")],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let overlapPins = FriendProfileSharedDiveMapPresentation.pins(
                sharedDives: [sameCoordShared, sameCoordTogether],
                togetherDives: [],
                togetherActivityIDs: [],
                catalogSites: [],
                currentFirebaseUID: "me-uid"
            )
            #expect(overlapPins.count == 1)
            #expect(overlapPins.first?.kind == .friendTogether)
        }

        @Test func friendProfileActivityFilter_togetherUsesTaggedOrLocalIDs() {
            let togetherID = UUID()
            let otherID = UUID()
            let together = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: togetherID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "A",
                locationName: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let other = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: otherID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "B",
                locationName: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let filtered = FriendProfileSharedDiveListPresentation.filteredDives(
                [together, other],
                filter: .together,
                togetherActivityIDs: [togetherID],
                currentFirebaseUID: nil
            )
            #expect(filtered.map(\.id) == [togetherID.uuidString])
            #expect(
                FriendProfileSharedMediaListPresentation.displayItems(from: []).isEmpty
            )
        }

        @Test func friendProfileSharedDiveList_mapsLogbookRowsNewestFirst() {
            let olderID = UUID()
            let newerID = UUID()
            let older = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: olderID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                diveNumber: 3,
                siteName: "Old Reef",
                locationName: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let newer = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: newerID.uuidString,
                activityKind: .snorkel,
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 55,
                maxDepthMeters: nil,
                siteName: "Lagoon",
                locationName: nil,
                swimDistanceMeters: 1200,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let rows = FriendProfileSharedDiveListPresentation.logbookRows(
                from: [older, newer],
                unitSystem: .imperial
            )
            #expect(rows.map(\.id) == [newerID, olderID])
            #expect(rows[0].activityKind == .snorkel)
            #expect(rows[0].diveNumberLabel == LogbookActivityRowPresentation.snorkelChipTitle)
            #expect(rows[1].diveNumberLabel == "#3")
            #expect(rows[1].detailLine.contains("ft"))
            #expect(
                FriendProfileSharedDiveListPresentation.dive(matching: olderID, in: [older, newer])?.id
                    == olderID.uuidString
            )
            #expect(FriendProfileSharedDiveListPresentation.sectionTitle == "Activities")
        }

        @Test func friendProfile_mediaMapToggle_requiresHeroAndPins() {
            let heroURL = "https://firebasestorage.googleapis.com/v0/b/test/o/users%2Fuid%2FprofileHero.jpg?alt=media"
            let hasMedia = FriendProfileHeroPresentation.hasAssociatedMedia(
                profileHeroURL: heroURL,
                profileHeroMediaKind: .image
            )
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-1",
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "Blue Hole",
                locationName: nil,
                entryLatitude: 17.3,
                entryLongitude: -87.5,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let pins = FriendProfileSharedDiveMapPresentation.pins(
                sharedDives: [dive],
                togetherDives: [],
                togetherActivityIDs: [],
                catalogSites: [],
                currentFirebaseUID: nil
            )
            #expect(pins.count == 1)
            #expect(
                PushedDetailHeroModePresentation.showsModeToggle(
                    hasAssociatedMedia: hasMedia,
                    hasMapContent: !pins.isEmpty
                )
            )
            #expect(
                !PushedDetailHeroModePresentation.showsModeToggle(
                    hasAssociatedMedia: hasMedia,
                    hasMapContent: false
                )
            )
        }

        @Test func pushedDetailHeroModePresentation_toggleAndDefaults() {
            #expect(
                PushedDetailHeroModePresentation.showsModeToggle(
                    hasAssociatedMedia: true,
                    hasMapContent: true
                )
            )
            #expect(
                !PushedDetailHeroModePresentation.showsModeToggle(
                    hasAssociatedMedia: false,
                    hasMapContent: true
                )
            )
            #expect(
                PushedDetailHeroModePresentation.resolvedMode(
                    hasAssociatedMedia: true,
                    hasMapContent: true
                ) == .media
            )
            #expect(
                PushedDetailHeroModePresentation.resolvedMode(
                    hasAssociatedMedia: false,
                    hasMapContent: true
                ) == .map
            )
        }

        @Test func pushedDetailHeroModePresentation_mapFallback_onlyWhenMediaExistsAndMapReady() {
            #expect(
                !PushedDetailHeroModePresentation.shouldFallBackFromMapToMedia(
                    mapPinCount: 0,
                    currentMode: .map,
                    isMapContentReady: false,
                    hasAssociatedMedia: false
                )
            )
            #expect(
                !PushedDetailHeroModePresentation.shouldFallBackFromMapToMedia(
                    mapPinCount: 0,
                    currentMode: .map,
                    isMapContentReady: true,
                    hasAssociatedMedia: false
                )
            )
            #expect(
                PushedDetailHeroModePresentation.shouldFallBackFromMapToMedia(
                    mapPinCount: 0,
                    currentMode: .map,
                    isMapContentReady: true,
                    hasAssociatedMedia: true
                )
            )
            #expect(
                !PushedDetailHeroModePresentation.shouldFallBackFromMapToMedia(
                    mapPinCount: 2,
                    currentMode: .map,
                    isMapContentReady: true,
                    hasAssociatedMedia: true
                )
            )
        }

        @Test func pushedDetailHeroModePresentation_keepsMediaMountedAndPlayingAcrossMapToggle() {
            #expect(
                PushedDetailHeroModePresentation.keepsMediaMountedDuringMapMode(hasAssociatedMedia: true)
            )
            #expect(
                !PushedDetailHeroModePresentation.keepsMediaMountedDuringMapMode(hasAssociatedMedia: false)
            )
            #expect(
                PushedDetailHeroModePresentation.isHeroVideoPlaybackActive(shouldAutoPlaySelectedVideo: true)
            )
            #expect(
                !PushedDetailHeroModePresentation.isHeroVideoPlaybackActive(shouldAutoPlaySelectedVideo: false)
            )
            #expect(PushedDetailHeroModePresentation.mediaLayerOpacity(selectedMode: .media) == 1)
            #expect(PushedDetailHeroModePresentation.mediaLayerOpacity(selectedMode: .map) == 0)
        }

        @Test func buddiesListPresentation_friendTotalDivesLabel_usesTotalCopy() {
            #expect(BuddiesListPresentation.friendTotalDivesLabel(0) == "0 total dives")
            #expect(BuddiesListPresentation.friendTotalDivesLabel(1) == "1 total dive")
            #expect(BuddiesListPresentation.friendTotalDivesLabel(12) == "12 total dives")
        }

        @Test func buddiesListPresentation_showsGoDiveUserPin_forFriendsOnly() {
            #expect(BuddiesListPresentation.showsGoDiveUserPin(isFriend: true))
            #expect(!BuddiesListPresentation.showsGoDiveUserPin(isFriend: false))
            #expect(BuddiesListPresentation.friendBadgeAccessibilityLabel == "GoDive user")
            #expect(GoDiveUserAvatarPinPresentation.showsGoDiveUserPin(isFriend: true))
            #expect(!GoDiveUserAvatarPinPresentation.showsGoDiveUserPin(isFriend: false))
            #expect(GoDiveUserAvatarPinPresentation.accessibilityLabel == "GoDive user")
            #expect(GoDiveUserAvatarPinPresentation.assetName == "GoDiveUserAvatarPin")
            #expect(GoDiveUserAvatarPinPresentation.pinSideLengthFraction == 0.76)
            #expect(GoDiveUserAvatarPinPresentation.pinSideLengthMinimum == 28)
            #expect(
                GoDiveUserAvatarPinPresentation.pinSideLength(forAvatarDiameter: 48)
                    == 48 * GoDiveUserAvatarPinPresentation.pinSideLengthFraction
            )
            // Profile / buddy identity avatar (120) keeps the same pin:avatar ratio as list chips.
            #expect(
                GoDiveUserAvatarPinPresentation.pinSideLength(forAvatarDiameter: 120)
                    == 120 * GoDiveUserAvatarPinPresentation.pinSideLengthFraction
            )
            #expect(GoDiveUserAvatarPinPresentation.pinSideLength(forAvatarDiameter: 30) == 28)
            let edge120 = GoDiveUserAvatarPinPresentation.pinEdgeOverlapOffset(forAvatarDiameter: 120)
            let pin120 = GoDiveUserAvatarPinPresentation.pinSideLength(forAvatarDiameter: 120)
            #expect(edge120.width == pin120 * GoDiveUserAvatarPinPresentation.pinEdgeOutwardFraction)
            #expect(edge120.height == pin120 * GoDiveUserAvatarPinPresentation.pinEdgeOutwardFraction)
            #expect(
                BuddiesListPresentation.goDiveUserPinSideLength(forAvatarDiameter: 48)
                    == GoDiveUserAvatarPinPresentation.pinSideLength(forAvatarDiameter: 48)
            )
            let pin48 = GoDiveUserAvatarPinPresentation.pinSideLength(forAvatarDiameter: 48)
            let edge48 = GoDiveUserAvatarPinPresentation.pinEdgeOverlapOffset(forAvatarDiameter: 48)
            let outwardFraction = GoDiveUserAvatarPinPresentation.pinEdgeOutwardFraction
            #expect(outwardFraction == 0.32)
            #expect(edge48.width == pin48 * outwardFraction)
            #expect(edge48.height == pin48 * outwardFraction)
            #expect(UIImage(named: GoDiveUserAvatarPinPresentation.assetName) != nil)
            let lightTraits = UITraitCollection(userInterfaceStyle: .light)
            let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
            let lightPin = UIImage(
                named: GoDiveUserAvatarPinPresentation.assetName,
                in: nil,
                compatibleWith: lightTraits
            )
            let darkPin = UIImage(
                named: GoDiveUserAvatarPinPresentation.assetName,
                in: nil,
                compatibleWith: darkTraits
            )
            #expect(lightPin != nil)
            #expect(darkPin != nil)
            #expect(lightPin?.pngData() != darkPin?.pngData())
        }

        @Test func buddiesListPresentation_mergedRows_combinesRosterAndFriendOnly() {
            let owner = UserProfile(appleUserIdentifier: "merge-owner", displayName: "Diver")
            let localBuddy = DiveBuddy(displayName: "Casey", owner: owner)
            let linkedBuddy = DiveBuddy(displayName: "Alex", owner: owner)
            linkedBuddy.linkedFirebaseUID = "uid-alex"

            let alexEdge = GoDiveFriendGraphService.friendEdge(
                friendUID: "uid-alex",
                friendshipID: "ship-alex",
                displayName: "Alex Rivera",
                totalDiveCount: 42
            )
            let remoteOnly = GoDiveFriendGraphService.friendEdge(
                friendUID: "uid-sam",
                friendshipID: "ship-sam",
                displayName: "Sam"
            )

            let rows = BuddiesListPresentation.mergedRows(
                friends: [alexEdge, remoteOnly],
                rosterBuddies: [localBuddy, linkedBuddy],
                sharedDiveCount: { _ in 3 }
            )

            #expect(rows.count == 3)
            #expect(rows.map(\.displayName) == ["Alex", "Casey", "Sam"])
            #expect(rows.first(where: { $0.displayName == "Alex" })?.isFriend == true)
            #expect(rows.first(where: { $0.displayName == "Alex" })?.friendTotalDiveCount == 42)
            #expect(rows.first(where: { $0.displayName == "Alex" })?.divesTogetherSubtitle == "3 dives together")
            #expect(rows.first(where: { $0.displayName == "Casey" })?.isFriend == false)
            #expect(rows.first(where: { $0.displayName == "Sam" })?.buddy == nil)
        }

        @Test func buddiesListPresentation_smsBody_includesFirstNameAndURL() {
            let url = URL(string: "https://links.godiveios.com/invite/abc")!
            let body = BuddiesListPresentation.smsBody(
                inviteURL: url,
                buddyDisplayName: "Jamie Rivera"
            )
            #expect(body.contains("Hey Jamie —"))
            #expect(!body.contains("Rivera"))
            #expect(body.contains(url.absoluteString))
            let emptyName = BuddiesListPresentation.smsBody(inviteURL: url, buddyDisplayName: "  ")
            #expect(emptyName.hasPrefix("Connect with me on GoDive:"))
        }

        @Test func friendSharedDetail_diveNumberChip_nilForSnorkel() {
            let snorkel = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "snorkel-1",
                activityKind: .snorkel,
                startTime: Date(),
                durationMinutes: 30,
                maxDepthMeters: 2,
                averageDepthMeters: nil,
                diveNumber: 5,
                siteName: "Lagoon",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            #expect(FriendSharedActivityDetailPresentation.diveNumberChip(for: snorkel) == nil)
            #expect(FriendSharedActivityDetailPresentation.diveNumberPlainLabel(for: snorkel) == "#5")
        }

        @Test func friendSharedDetail_mapLargeDetent_placesSocialAboveReadOnlySections() {
            #expect(
                FriendSharedActivityDetailPresentation.mapLargeDetentDetailsBlockOrder
                    == [.social, .readOnlySections]
            )
        }

        @Test func friendSharedDetail_tankHeroPresentation_matchesOwnedDiveRules() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-tank",
                activityKind: .scubaDive,
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 3,
                siteName: "Salt Pier",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                gasType: "Nitrox",
                oxygenMix: 32,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil,
                tankPressureStartPSI: 3_000,
                tankPressureEndPSI: 1_500
            )
            #expect(
                FriendSharedActivityDetailPresentation.tankHeroGasMixLabel(for: dive)
                    == DiveGasMixImport.tankHeroLabel(gasType: "Nitrox", oxygenMix: 32)
            )
            #expect(
                abs(
                    FriendSharedActivityDetailPresentation.tankHeroPressureFillFraction(for: dive)
                        - 0.5
                ) < 0.001
            )

            let layoutSize = CGSize(width: 390, height: 640)
            let layoutHeight: CGFloat = 844
            let topObstruction: CGFloat = 100
            let minimizedMargin = layoutHeight * DiveActivityOverviewPanelMetrics.minimizedHeightFraction
            let largeMargin = layoutHeight * DiveActivityOverviewPanelMetrics.referenceLargeHeightFraction
            let friendMinimized = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: minimizedMargin,
                isLandscape: false,
                detent: .minimized,
                chartSizingBottomContentMargin: largeMargin
            )
            let ownedMinimized = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: minimizedMargin,
                isLandscape: false,
                detent: .minimized,
                chartSizingBottomContentMargin: largeMargin
            )
            let ownedLarge = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: layoutSize,
                layoutHeight: layoutHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: largeMargin,
                isLandscape: false,
                detent: .large,
                chartSizingBottomContentMargin: largeMargin
            )
            #expect(friendMinimized == ownedMinimized)
            #expect(friendMinimized.height > ownedLarge.height + 1)
            #expect(friendMinimized.height > layoutHeight * 0.4)

            let landscapeSize = CGSize(width: 844, height: 390)
            let landscapeHeight: CGFloat = 390
            let landscapeBottomInset: CGFloat = 21
            let friendLandscape = FriendSharedActivityDetailPresentation.landscapeTankProfileChartFrame(
                layoutSize: landscapeSize,
                layoutHeight: landscapeHeight,
                topObstructionHeight: topObstruction,
                bottomSafeInset: landscapeBottomInset
            )
            let ownedLandscape = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
                layoutSize: landscapeSize,
                layoutHeight: landscapeHeight,
                topObstructionHeight: topObstruction,
                bottomContentMargin: landscapeBottomInset,
                isLandscape: true
            )
            #expect(friendLandscape == ownedLandscape)
            #expect(abs(friendLandscape.minX) < 0.5)
            #expect(abs(friendLandscape.width - landscapeSize.width) < 0.5)
            #expect(abs(friendLandscape.minY) < 0.5)
            #expect(abs(friendLandscape.maxY - (landscapeHeight - landscapeBottomInset)) < 0.5)
            #expect(
                DiveTankOverviewHeroPresentation.showsProfileChart(
                    for: .minimized,
                    depthSampleCount: 4,
                    isLandscape: true
                )
            )
            #expect(
                DiveTankOverviewHeroPresentation.showsProfileChart(
                    for: .large,
                    depthSampleCount: 4,
                    isLandscape: true
                )
            )
            #expect(
                !DiveTankOverviewHeroPresentation.showsTankCylinderHero(
                    for: .minimized,
                    isLandscape: true
                )
            )
            #expect(
                DiveActivityOverviewLandscapePresentation.hidesOverviewPanel(isLandscape: true)
            )
            #expect(FriendSharedActivityDetailPresentation.tankMinimizedEntranceMatchesOwnedDive)
        }

        @Test func friendSharedDetail_mapCoordinate_rejectsInvalid() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-1",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 3,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: 0,
                entryLongitude: 0,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            #expect(FriendSharedActivityDetailPresentation.mapCoordinate(from: dive) == nil)
        }

        @Test func friendSharedDetail_snorkelDerivedSnapshot_decodesSwimTrack() throws {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let samples = [
                SnorkelSwimTrackSample(
                    timestamp: start,
                    latitude: 21.3,
                    longitude: -157.8,
                    heartRateBPM: 90
                ),
                SnorkelSwimTrackSample(
                    timestamp: start.addingTimeInterval(60),
                    latitude: 21.31,
                    longitude: -157.79,
                    heartRateBPM: 110
                ),
            ]
            let trackData = try #require(try SnorkelSwimTrackCodec.encode(samples: samples, activityStartTime: start))
            let snorkel = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "snorkel-track",
                activityKind: .snorkel,
                startTime: start,
                durationMinutes: 25,
                maxDepthMeters: 1.5,
                averageDepthMeters: nil,
                diveNumber: nil,
                siteName: "Bay",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                swimTrackBase64: trackData.base64EncodedString(),
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            let snapshot = FriendSharedActivityDetailPresentation.snorkelDerivedSnapshot(from: snorkel)
            #expect(snapshot.trackCoordinates.count == 2)
            #expect(snapshot.heartRateSamples.count >= 2)
            #expect(snapshot.avgHeartRateBPM == 100)
            #expect(snapshot.maxHeartRateBPM == 110)
            #expect(FriendSharedActivityDetailPresentation.swimTrackCoordinates(from: snorkel).count == 2)
        }

        @Test func friendSharedMedia_displayItems_prefersV3Rows() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "v3",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 1,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [
                    .init(
                        mediaID: "m1",
                        kind: .video,
                        thumbnailURL: "https://firebasestorage.googleapis.com/v0/b/t/o/thumb.jpg?alt=media",
                        contentURL: "https://firebasestorage.googleapis.com/v0/b/t/o/video.mp4?alt=media",
                        width: 1920,
                        height: 1080,
                        durationSeconds: 30,
                        contentBytes: 1_000
                    ),
                ],
                mediaPreviews: [.init(photoID: "legacy", previewURL: "https://example.com/legacy.jpg")],
                featuredMediaPhotoID: "m1",
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            let items = FriendSharedMediaPresentation.displayItems(for: dive)
            #expect(items.count == 1)
            #expect(items[0].kind == .video)
            #expect(items[0].mediaID == "m1")
        }

        @Test func friendSharedMedia_displayItems_v2Fallback() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "v2",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 1,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [],
                mediaPreviews: [.init(photoID: "p1", previewURL: "https://firebasestorage.googleapis.com/v0/b/t/o/p.jpg?alt=media")],
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            #expect(FriendSharedMediaPresentation.displayItems(for: dive)[0].mediaID == "p1")
            #expect(FriendSharedMediaPresentation.displayItems(for: dive)[0].kind == .photo)
        }

        @Test func friendSharedMedia_urlPolicy_rejectsNonFirebaseHosts() {
            let firebase = "https://firebasestorage.googleapis.com/v0/b/t/o/p.jpg?alt=media"
            let evil = "https://evil.example.com/p.jpg"
            #expect(FriendSharedMediaPresentation.sanitizedThumbnailURL(from: firebase) != nil)
            #expect(FriendSharedMediaPresentation.sanitizedThumbnailURL(from: evil) == nil)
            #expect(GoDiveSharedMediaCache.streamingURL(from: evil) == nil)
        }

        @Test func friendSharedMedia_allowsContentDownload_wifiAndLowDataGates() {
            #expect(
                FriendSharedMediaPresentation.allowsContentDownload(
                    isConnected: true,
                    usesWiFi: false,
                    wifiOnly: false,
                    allowsConstrainedNetworkAccess: true
                )
            )
            #expect(
                !FriendSharedMediaPresentation.allowsContentDownload(
                    isConnected: true,
                    usesWiFi: false,
                    wifiOnly: true,
                    allowsConstrainedNetworkAccess: true
                )
            )
            #expect(
                !FriendSharedMediaPresentation.allowsContentDownload(
                    isConnected: true,
                    usesWiFi: true,
                    wifiOnly: false,
                    allowsConstrainedNetworkAccess: false
                )
            )
        }

        @Test func friendSharedMedia_buddyFeedPrefetch_skipsInvalidURLs() {
            let rows = [
                LogbookBuddyFeedPresentation.Row(
                    id: "r1",
                    friendUID: "u1",
                    friendDisplayName: "Alex",
                    friendPhotoURL: nil,
                    dive: .init(
                        id: "d1",
                        startTime: Date(),
                        durationMinutes: 40,
                        maxDepthMeters: 18,
                        averageDepthMeters: nil,
                        diveNumber: 1,
                        siteName: "Reef",
                        locationName: nil,
                        entryLatitude: nil,
                        entryLongitude: nil,
                        notes: nil,
                        activityTagNames: [],
                        sightings: [],
                        taggedBuddies: [],
                        equipmentSummary: [],
                        mediaItems: [
                            .photoThumbnailOnly(
                                mediaID: "m1",
                                thumbnailURL: "https://firebasestorage.googleapis.com/v0/b/t/o/t.jpg?alt=media"
                            ),
                        ],
                        mediaPreviews: [],
                        profileTrackBase64: nil,
                        gasType: nil,
                        oxygenMix: nil,
                        tankVolumeDescription: nil,
                        waterTempMinCelsius: nil,
                        bottomTimeSeconds: nil
                    )
                ),
            ]
            let urls = FriendSharedMediaPresentation.buddyFeedThumbnailPrefetchURLs(rows: rows, startIndex: 0, count: 3)
            #expect(urls.count == 1)
            #expect(urls[0].contains("firebasestorage.googleapis.com"))
        }

        @Test func goDiveSharedMediaCache_storesAndReadsThumb() async throws {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            GoDiveSharedMediaCache.testingRootDirectory = root
            defer {
                GoDiveSharedMediaCache.testingRootDirectory = nil
                try? FileManager.default.removeItem(at: root)
            }

            let url = "https://firebasestorage.googleapis.com/v0/b/t/o/unique-\(UUID().uuidString).jpg?alt=media"
            let cache = GoDiveSharedMediaCache(fileManager: .default, session: .shared)
            let payload = Data([0xFF, 0xD8, 0xFF, 0xD9])
            _ = try await cache.storeForTesting(data: payload, remoteURLString: url, tier: .thumb)
            let cached = await cache.cachedFileURL(remoteURLString: url, tier: .thumb)
            #expect(cached != nil)
            let readBack = try Data(contentsOf: try #require(cached))
            #expect(readBack == payload)
        }

        @Test func goDiveSharedMediaCache_resolvedPlaybackURL_prefersCachedFile() async throws {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            GoDiveSharedMediaCache.testingRootDirectory = root
            defer {
                GoDiveSharedMediaCache.testingRootDirectory = nil
                try? FileManager.default.removeItem(at: root)
            }

            let remote = "https://firebasestorage.googleapis.com/v0/b/t/o/clip-\(UUID().uuidString).mp4?alt=media"
            let cache = GoDiveSharedMediaCache(fileManager: .default, session: .shared)
            _ = try await cache.storeForTesting(data: Data([0x00, 0x00, 0x00, 0x18]), remoteURLString: remote, tier: .content)

            let resolved = await cache.resolvedPlaybackURL(remoteURLString: remote, tier: .content)
            #expect(resolved?.isFileURL == true)
            #expect(resolved?.path.contains("content") == true)
        }

        @Test func goDiveSharedMediaCache_resolvedPlaybackURL_fallsBackToRemote() async {
            let remote = "https://firebasestorage.googleapis.com/v0/b/t/o/missing-\(UUID().uuidString).mp4?alt=media"
            let cache = GoDiveSharedMediaCache(fileManager: .default, session: .shared)
            let resolved = await cache.resolvedPlaybackURL(remoteURLString: remote, tier: .content)
            #expect(resolved?.isFileURL == false)
            #expect(resolved?.absoluteString == remote)
        }

        @Test @MainActor func friendSharedMedia_resolvedVideoPlaybackURL_usesCacheWhenPresent() async throws {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            GoDiveSharedMediaCache.testingRootDirectory = root
            defer {
                GoDiveSharedMediaCache.testingRootDirectory = nil
                try? FileManager.default.removeItem(at: root)
            }

            let remote = "https://firebasestorage.googleapis.com/v0/b/t/o/hero-\(UUID().uuidString).mp4?alt=media"
            _ = try await GoDiveSharedMediaCache.shared.storeForTesting(
                data: Data([0x00, 0x00, 0x00, 0x20]),
                remoteURLString: remote,
                tier: .content
            )
            let resolved = await FriendSharedMediaPresentation.resolvedVideoPlaybackURL(for: remote)
            #expect(resolved?.isFileURL == true)
        }

        @Test func friendSharedMediaFullscreen_presentationAdjacentAndPositionLabel() {
            let items = [
                FriendSharedMediaPresentation.DisplayItem(
                    mediaID: "a",
                    kind: .photo,
                    thumbnailURL: nil,
                    contentURL: nil
                ),
                FriendSharedMediaPresentation.DisplayItem(
                    mediaID: "b",
                    kind: .photo,
                    thumbnailURL: nil,
                    contentURL: nil
                ),
            ]
            #expect(
                FriendSharedMediaFullscreenPresentation.adjacentMediaID(
                    selectedID: "a",
                    in: items,
                    offset: 1
                ) == "b"
            )
            #expect(
                FriendSharedMediaFullscreenPresentation.adjacentMediaID(
                    selectedID: "b",
                    in: items,
                    offset: -1
                ) == "a"
            )
            #expect(
                FriendSharedMediaFullscreenPresentation.adjacentMediaID(
                    selectedID: "a",
                    in: items,
                    offset: -1
                ) == nil
            )
            #expect(
                FriendSharedMediaFullscreenPresentation.mediaPositionLabel(
                    selectedID: "b",
                    in: items
                ) == "2 of 2"
            )
            #expect(
                FriendSharedMediaFullscreenPresentation.mediaPositionLabel(
                    selectedID: "a",
                    in: items
                ) == "1 of 2"
            )
            #expect(
                FriendSharedMediaFullscreenPresentation.openActivityAccessibilityIdentifier
                    == "FriendSharedMedia.Fullscreen.OpenActivity"
            )
            #expect(
                FriendSharedMediaFullscreenPresentation.playbackToggleAccessibilityIdentifier
                    == "FriendSharedMedia.Fullscreen.PlaybackToggle"
            )
        }

        @Test func friendProfileSharedMedia_diveByMediaID_mapsNewestOwningActivity() {
            let olderID = UUID()
            let newerID = UUID()
            let older = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: olderID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                diveNumber: 3,
                siteName: "Old Reef",
                locationName: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [
                    GoDiveSharedDiveProjectionMapping.MediaItemSnapshot(
                        mediaID: "shared-photo",
                        kind: .photo,
                        thumbnailURL: "https://example.com/t.jpg",
                        contentURL: "https://example.com/c.jpg"
                    ),
                ],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let newer = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: newerID.uuidString,
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 45,
                maxDepthMeters: 20,
                diveNumber: 7,
                siteName: "New Reef",
                locationName: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [
                    GoDiveSharedDiveProjectionMapping.MediaItemSnapshot(
                        mediaID: "shared-photo",
                        kind: .photo,
                        thumbnailURL: "https://example.com/t2.jpg",
                        contentURL: "https://example.com/c2.jpg"
                    ),
                    GoDiveSharedDiveProjectionMapping.MediaItemSnapshot(
                        mediaID: "other-photo",
                        kind: .photo,
                        thumbnailURL: "https://example.com/t3.jpg",
                        contentURL: "https://example.com/c3.jpg"
                    ),
                ],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let map = FriendProfileSharedMediaListPresentation.diveByMediaID(from: [older, newer])
            #expect(map["shared-photo"]?.id == newerID.uuidString)
            #expect(map["other-photo"]?.id == newerID.uuidString)
            #expect(FriendSharedMediaFullscreenPresentation.diveNumberLabel(for: newer) == "#7")
            #expect(FriendSharedMediaFullscreenPresentation.siteDisplayName(for: newer) == "New Reef")
        }

        #if canImport(UIKit)
        @Test func goDiveSharedMediaExport_sharePhotoJPEG_respectsSizeCap() {
            let edge = GoDiveSharedMediaLimits.photoContentMaxPixelEdge
            let size = CGSize(width: edge * 2, height: edge)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.orange.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            guard let data = GoDiveSharedMediaExport.sharePhotoJPEG(from: image) else {
                Issue.record("Expected share JPEG export")
                return
            }
            #expect(data.count <= GoDiveSharedMediaLimits.photoContentMaxBytes)
            let dimensions = GoDiveSharedMediaExport.jpegDimensions(data)
            #expect(dimensions?.width ?? 0 <= edge)
            #expect(dimensions?.height ?? 0 <= edge)
        }

        @Test func goDiveSharedMediaExport_sharePhotoJPEG_doesNotEmbedGPSMetadata() {
            let edge = GoDiveSharedMediaLimits.photoContentMaxPixelEdge
            let size = CGSize(width: edge, height: edge / 2)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.blue.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            guard let data = GoDiveSharedMediaExport.sharePhotoJPEG(from: image) else {
                Issue.record("Expected share JPEG export")
                return
            }
            #if canImport(ImageIO)
            #expect(!GoDiveSharedMediaExport.jpegContainsGPSMetadata(data))
            #endif
        }

        @Test func goDiveSharedMediaExport_cappedVideoExportDuration_clampsAtThirtySeconds() {
            #expect(GoDiveSharedMediaExport.cappedVideoExportDurationSeconds(60) == 30)
            #expect(GoDiveSharedMediaExport.cappedVideoExportDurationSeconds(12.5) == 12.5)
            #expect(GoDiveSharedMediaExport.cappedVideoExportDurationSeconds(0) == 0)
            #expect(GoDiveSharedMediaExport.cappedVideoExportDurationSeconds(-4).isZero)
        }

        @Test func goDiveSharedMediaExport_thumbnailFromPreviewBytes_returnsWithoutPhotoKit() async {
            let size = CGSize(width: 64, height: 48)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.green.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            guard let preview = image.jpegData(compressionQuality: 0.9), !preview.isEmpty else {
                Issue.record("Expected preview JPEG bytes")
                return
            }
            let exported = await GoDiveSharedMediaExport.exportThumbnailJPEG(
                previewJPEGData: preview,
                photosLocalIdentifier: nil
            )
            #expect(exported == preview)
        }
        #endif

        @Test func goDiveSharedMediaSelection_twelveVideos_capsAtTen() {
            let base = Date(timeIntervalSince1970: 1_700_000_000)
            let candidates = (0 ..< 12).map { index in
                GoDiveSharedMediaSelection.ShareCandidate(
                    id: UUID(uuidString: String(format: "20000000-0000-0000-0000-%012x", index))!,
                    kind: .video,
                    capturedAt: base.addingTimeInterval(Double(index)),
                    sortOrder: index
                )
            }
            let filtered = GoDiveSharedMediaSelection.filteredForShare(candidates: candidates)
            #expect(filtered.count == 10)
            #expect(filtered.allSatisfy { $0.kind == .video })
            let summary = GoDiveSharedMediaSelection.capTrimSummary(candidates: candidates, shared: filtered)
            #expect(summary.droppedVideoCount == 2)
            #expect(GoDiveSharedMediaSelection.trimNoticeMessage(summary)?.contains("2 videos") == true)
        }

        @Test func goDiveSharedMediaSelection_preservesGalleryOrderAfterCaps() {
            let base = Date(timeIntervalSince1970: 1_700_000_000)
            var candidates: [GoDiveSharedMediaSelection.ShareCandidate] = []
            for index in 0 ..< 22 {
                candidates.append(
                    .init(
                        id: UUID(uuidString: String(format: "30000000-0000-0000-0000-%012x", index))!,
                        kind: index.isMultiple(of: 3) ? .video : .image,
                        capturedAt: base.addingTimeInterval(Double(index)),
                        sortOrder: index
                    )
                )
            }
            let filtered = GoDiveSharedMediaSelection.filteredForShare(candidates: candidates)
            #expect(GoDiveSharedMediaSelection.preservesGalleryOrder(candidates: candidates, filtered: filtered))
        }

        @Test func goDiveSharedMediaCache_evictsOldestWhenOverCapacity() async throws {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            GoDiveSharedMediaCache.testingRootDirectory = root
            GoDiveSharedMediaCache.testingTierMaxBytes = [.thumb: 100]
            defer {
                GoDiveSharedMediaCache.testingRootDirectory = nil
                GoDiveSharedMediaCache.testingTierMaxBytes = nil
                try? FileManager.default.removeItem(at: root)
            }

            let cache = GoDiveSharedMediaCache(fileManager: .default, session: .shared)
            let firstURL = "https://firebasestorage.googleapis.com/v0/b/t/o/first-\(UUID().uuidString).jpg?alt=media"
            let secondURL = "https://firebasestorage.googleapis.com/v0/b/t/o/second-\(UUID().uuidString).jpg?alt=media"
            _ = try await cache.storeForTesting(data: Data(repeating: 0x01, count: 60), remoteURLString: firstURL, tier: .thumb)
            try await Task.sleep(nanoseconds: 10_000_000)
            _ = try await cache.storeForTesting(data: Data(repeating: 0x02, count: 60), remoteURLString: secondURL, tier: .thumb)

            #expect(await cache.cachedFileURL(remoteURLString: secondURL, tier: .thumb) != nil)
            #expect(await cache.cachedFileURL(remoteURLString: firstURL, tier: .thumb) == nil)
        }

        @Test func friendSharedMediaPanelPresentation_resolvedFeaturedMediaID() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "featured",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 1,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [
                    .init(
                        mediaID: "m1",
                        kind: .photo,
                        thumbnailURL: "https://firebasestorage.googleapis.com/v0/b/t/o/thumb.jpg?alt=media",
                        contentURL: nil,
                        width: nil,
                        height: nil,
                        durationSeconds: nil,
                        contentBytes: nil
                    ),
                ],
                mediaPreviews: [],
                featuredMediaPhotoID: "m1",
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            #expect(FriendSharedMediaPresentation.resolvedFeaturedMediaID(for: dive) == "m1")
            #expect(
                DiveActivityMediaPresentation.showsMediaCarouselInSheet(for: .minimized)
            )
            #expect(
                DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: .large)
            )
        }

        @Test func friendSharedDetail_displayBuddies_filtersByMediaID() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-media-buddies",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 1,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [
                    .init(displayName: "Activity Buddy", firebaseUID: "uid-activity"),
                ],
                equipmentSummary: [],
                mediaItems: [],
                mediaBuddyTags: [
                    .init(mediaID: "media-a", displayName: "Alex", firebaseUID: "uid-alex"),
                    .init(mediaID: "media-b", displayName: "Sam", firebaseUID: "uid-sam"),
                    .init(mediaID: "media-a", displayName: "Jamie", firebaseUID: "uid-jamie"),
                ],
                mediaPreviews: [],
                featuredMediaPhotoID: nil,
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )

            let mediaABuddies = FriendSharedActivityDetailPresentation.displayBuddies(
                from: dive,
                mediaID: "media-a"
            )
            #expect(mediaABuddies.map(\.displayName) == ["Alex", "Jamie"])
            #expect(FriendSharedActivityDetailPresentation.displayBuddies(from: dive, mediaID: "media-b").count == 1)
            #expect(FriendSharedActivityDetailPresentation.displayBuddies(from: dive, mediaID: "missing").isEmpty)
            #expect(FriendSharedActivityDetailPresentation.displayBuddies(from: dive).count == 1)
        }

        @Test func friendSharedDetail_mapTaggedBuddyDisplayRows_prefersLocalRosterMatch() {
            let owner = UserProfile(appleUserIdentifier: "friend-map-buddy-rows", displayName: "Viewer")
            let localAlex = DiveBuddy(displayName: "Alex Kim", owner: owner)
            localAlex.linkedFirebaseUID = "uid-alex"
            localAlex.profilePhoto = Data([0x01, 0x02])

            let localSam = DiveBuddy(displayName: "Sam Rivera", owner: owner)
            localSam.linkedFirebaseUID = "uid-sam"
            localSam.linkedPhotoURL =
                "https://firebasestorage.googleapis.com/v0/b/t/o/sam.jpg?alt=media"

            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "map-buddies",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 1,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [
                    .init(displayName: "Alex", firebaseUID: "uid-alex"),
                    .init(displayName: "Sam Rivera", firebaseUID: "uid-sam"),
                    .init(displayName: "Jamie", firebaseUID: nil),
                ],
                equipmentSummary: [],
                mediaItems: [],
                mediaPreviews: [],
                featuredMediaPhotoID: nil,
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )

            let rows = FriendSharedActivityDetailPresentation.mapTaggedBuddyDisplayRows(
                from: dive,
                localRoster: [localAlex, localSam]
            )
            #expect(rows.count == 3)
            #expect(rows[0].displayName == "Alex Kim")
            #expect(rows[0].profilePhoto == Data([0x01, 0x02]))
            #expect(rows[0].photoURL == nil)
            #expect(rows[0].showsGoDiveUserPin)
            #expect(rows[1].displayName == "Sam Rivera")
            #expect(rows[1].profilePhoto == nil)
            #expect(rows[1].photoURL?.contains("sam.jpg") == true)
            #expect(rows[1].showsGoDiveUserPin)
            #expect(rows[2].displayName == "Jamie")
            #expect(rows[2].profilePhoto == nil)
            #expect(rows[2].photoURL == nil)
            #expect(!rows[2].showsGoDiveUserPin)
        }

        @Test func friendSharedMedia_allVideoContentPrefetchURLs_filtersVideosOnly() {
            let items: [FriendSharedMediaPresentation.DisplayItem] = [
                .init(mediaID: "p1", kind: .photo, thumbnailURL: "https://firebasestorage.googleapis.com/a/p1.jpg", contentURL: "https://firebasestorage.googleapis.com/a/p1-full.jpg"),
                .init(mediaID: "v1", kind: .video, thumbnailURL: "https://firebasestorage.googleapis.com/a/v1.jpg", contentURL: "https://firebasestorage.googleapis.com/a/v1.mp4"),
                .init(mediaID: "v2", kind: .video, thumbnailURL: nil, contentURL: "https://firebasestorage.googleapis.com/a/v2.mp4"),
            ]
            let urls = FriendSharedMediaPresentation.allVideoContentPrefetchURLs(items: items)
            #expect(urls == [
                "https://firebasestorage.googleapis.com/a/v1.mp4",
                "https://firebasestorage.googleapis.com/a/v2.mp4",
            ])
        }

        @Test func friendSharedMedia_allPhotoContentPrefetchURLs_filtersPhotosOnly() {
            let items: [FriendSharedMediaPresentation.DisplayItem] = [
                .init(mediaID: "p1", kind: .photo, thumbnailURL: "https://firebasestorage.googleapis.com/a/p1.jpg", contentURL: "https://firebasestorage.googleapis.com/a/p1-full.jpg"),
                .init(mediaID: "p2", kind: .photo, thumbnailURL: "https://firebasestorage.googleapis.com/a/p2.jpg", contentURL: nil),
                .init(mediaID: "v1", kind: .video, thumbnailURL: "https://firebasestorage.googleapis.com/a/v1.jpg", contentURL: "https://firebasestorage.googleapis.com/a/v1.mp4"),
            ]
            let urls = FriendSharedMediaPresentation.allPhotoContentPrefetchURLs(items: items)
            #expect(urls == ["https://firebasestorage.googleapis.com/a/p1-full.jpg"])
        }

        @Test func friendSharedMedia_buddyFeedFeaturedPhotoContentPrefetchURL_usesFeaturedStill() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "feed-photo",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 1,
                siteName: "Wall",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [
                    .init(
                        mediaID: "photo",
                        kind: .photo,
                        thumbnailURL: "https://firebasestorage.googleapis.com/a/p.jpg",
                        contentURL: "https://firebasestorage.googleapis.com/a/p-full.jpg",
                        width: nil,
                        height: nil,
                        durationSeconds: nil,
                        contentBytes: nil
                    ),
                ],
                mediaPreviews: [],
                featuredMediaPhotoID: "photo"
            )
            #expect(
                FriendSharedMediaPresentation.buddyFeedFeaturedPhotoContentPrefetchURL(for: dive)
                    == "https://firebasestorage.googleapis.com/a/p-full.jpg"
            )
        }

        @Test func friendSharedMedia_buddyFeedFeaturedVideoContentPrefetchURL_usesFeaturedClip() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "feed-video",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 1,
                siteName: "Wall",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaItems: [
                    .init(
                        mediaID: "photo",
                        kind: .photo,
                        thumbnailURL: "https://firebasestorage.googleapis.com/a/p.jpg",
                        contentURL: nil,
                        width: nil,
                        height: nil,
                        durationSeconds: nil,
                        contentBytes: nil
                    ),
                    .init(
                        mediaID: "clip",
                        kind: .video,
                        thumbnailURL: "https://firebasestorage.googleapis.com/a/v.jpg",
                        contentURL: "https://firebasestorage.googleapis.com/a/v.mp4",
                        width: nil,
                        height: nil,
                        durationSeconds: 12,
                        contentBytes: nil
                    ),
                ],
                mediaPreviews: [],
                featuredMediaPhotoID: "clip",
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            #expect(
                FriendSharedMediaPresentation.buddyFeedFeaturedVideoContentPrefetchURL(for: dive)
                    == "https://firebasestorage.googleapis.com/a/v.mp4"
            )
        }

        @Test func goDiveSharedMediaPublishState_photosLocalIdentifierFromFingerprint() {
            let fingerprint = GoDiveSharedMediaPublishState.sourceFingerprint(
                mediaKind: DiveMediaKind.image.rawValue,
                photosLocalIdentifier: "ABC-123",
                capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
                sortOrder: 2
            )
            #expect(
                GoDiveSharedMediaPublishState.photosLocalIdentifier(fromSourceFingerprint: fingerprint)
                    == "ABC-123"
            )
        }

        @Test func goDiveSharedMediaPublishState_pendingContentJobs_skipsCompleteRows() {
            let ownerUID = "owner-test"
            let activityID = UUID()
            let mediaID = UUID()
            GoDiveSharedMediaPublishState.saveActivityRecord(
                ownerUID: ownerUID,
                activityID: activityID,
                record: .init(items: [
                    .init(
                        mediaID: mediaID.uuidString,
                        kind: FriendSharedMediaKind.photo.rawValue,
                        sourceFingerprint: "image|LOCAL-ID|0|0",
                        exportFingerprint: nil,
                        thumbnailURL: "https://example.com/thumb.jpg",
                        contentURL: nil,
                        width: nil,
                        height: nil,
                        durationSeconds: nil,
                        contentBytes: nil
                    ),
                    .init(
                        mediaID: UUID().uuidString,
                        kind: FriendSharedMediaKind.photo.rawValue,
                        sourceFingerprint: "image|DONE|0|1",
                        exportFingerprint: "abc",
                        thumbnailURL: "https://example.com/thumb2.jpg",
                        contentURL: "https://example.com/photo.jpg",
                        width: 100,
                        height: 100,
                        durationSeconds: nil,
                        contentBytes: 100
                    ),
                ])
            )
            defer { GoDiveSharedMediaPublishState.clearActivity(ownerUID: ownerUID, activityID: activityID) }

            let jobs = GoDiveSharedMediaUpload.pendingContentJobs(
                ownerUID: ownerUID,
                activityID: activityID
            )
            #expect(jobs.count == 1)
            #expect(jobs[0].mediaID == mediaID)
            #expect(jobs[0].photosLocalIdentifier == "LOCAL-ID")
            #expect(jobs[0].kind == .photo)
        }

        @Test func tripShareMapping_inviteDocumentID_isDeterministic() {
            let id = GoDiveTripShareMapping.inviteDocumentID(
                sharerUID: "sharer",
                tripID: "TRIP-1"
            )
            #expect(id == "sharer_TRIP-1")
            #expect(
                GoDiveTripShareMapping.inviteDocumentID(sharerUID: " sharer ", tripID: " TRIP-1 ")
                    == id
            )
        }

        @Test func tripShareMapping_roundTripsSharedTripAndInvite() {
            let start = Date(timeIntervalSince1970: 1_800_000_000)
            let end = Date(timeIntervalSince1970: 1_800_100_000)
            let shared = GoDiveTripShareMapping.SharedTripSnapshot(
                tripID: "AAAA-BBBB",
                title: "Bonaire 2026",
                startDate: start,
                endDate: end,
                countries: ["Bonaire"],
                plannedSiteIDs: ["11111111-1111-1111-1111-111111111111"],
                updatedAt: end,
                createdAt: start,
                schemaVersion: GoDiveTripShareMapping.schemaVersion
            )
            let sharedData = GoDiveTripShareMapping.firestoreData(for: shared)
            let decodedShared = GoDiveTripShareMapping.sharedTripSnapshot(
                tripID: shared.tripID,
                data: sharedData
            )
            #expect(decodedShared?.title == "Bonaire 2026")
            #expect(decodedShared?.countries == ["Bonaire"])
            #expect(decodedShared?.plannedSiteIDs.count == 1)
            #expect(
                GoDiveTripShareMapping.syncedFieldsFingerprint(shared)
                    == GoDiveTripShareMapping.syncedFieldsFingerprint(decodedShared!)
            )

            let invite = GoDiveTripShareMapping.InviteSnapshot(
                inviteID: "sharer_AAAA-BBBB",
                sharerUID: "sharer",
                tripID: "AAAA-BBBB",
                status: .pending,
                title: "Bonaire 2026",
                sharerDisplayName: "Alex",
                createdAt: start,
                updatedAt: nil,
                schemaVersion: GoDiveTripShareMapping.schemaVersion
            )
            let inviteData = GoDiveTripShareMapping.firestoreData(for: invite, includeCreatedAt: true)
            // Rules require `createdAt == request.time` — must be a server timestamp sentinel.
            #expect(inviteData["createdAt"] is FieldValue)
            var decodeData = inviteData
            decodeData["createdAt"] = Timestamp(date: start)
            let decodedInvite = GoDiveTripShareMapping.inviteSnapshot(
                inviteID: invite.inviteID,
                data: decodeData
            )
            #expect(decodedInvite?.status == .pending)
            #expect(decodedInvite?.sharerDisplayName == "Alex")
            #expect(decodedInvite?.tripID == "AAAA-BBBB")
        }
}
