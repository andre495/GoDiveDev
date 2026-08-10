//
//  BuddyFeedTests.swift
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


struct BuddyFeedTests {
        @Test func buddyFeed_rowsEqual_comparesProfileTrackPayload() {
            let baseDive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-1",
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                siteName: "Reef",
                locationName: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil
            )
            let left = LogbookBuddyFeedPresentation.Row(
                id: "friend_dive-1",
                friendUID: "friend",
                friendDisplayName: "Sam",
                friendPhotoURL: nil,
                dive: baseDive
            )
            var withTrack = baseDive
            withTrack.profileTrackBase64 = "dHJhY2s="
            let right = LogbookBuddyFeedPresentation.Row(
                id: "friend_dive-1",
                friendUID: "friend",
                friendDisplayName: "Sam",
                friendPhotoURL: nil,
                dive: withTrack
            )
            #expect(!LogbookBuddyFeedPresentation.rowsEqual([left], [right]))
        }

        @Test func buddyFeed_tileStatsLine_formatsDiveAndSnorkel() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-1",
                activityKind: .scubaDive,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 3,
                siteName: "Reef",
                locationName: nil,
                region: "Bonaire",
                country: "Caribbean Netherlands",
                swimDistanceMeters: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                swimTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            let diveLine = LogbookBuddyFeedPresentation.tileStatsLine(for: dive, unitSystem: .metric)
            #expect(diveLine.contains("#3"))
            #expect(diveLine.contains("18.0 m"))
            #expect(diveLine.contains("40 min"))

            let snorkel = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "snorkel-1",
                activityKind: .snorkel,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 25,
                maxDepthMeters: nil,
                averageDepthMeters: nil,
                diveNumber: nil,
                siteName: nil,
                locationName: "Kralendijk, Bonaire, Caribbean Netherlands",
                region: nil,
                country: nil,
                swimDistanceMeters: 500,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                swimTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            let snorkelLine = LogbookBuddyFeedPresentation.tileStatsLine(for: snorkel, unitSystem: .metric)
            #expect(snorkelLine.contains("25 min"))
            #expect(snorkelLine.contains("500 m"))
            #expect(
                GoDiveSharedDiveProjectionMapping.regionCountryDisplayLine(for: snorkel)?
                    .contains("Bonaire") == true
            )
        }

        @Test func buddyFeed_postTimestampText_formatsCompactRelativeUnits() {
            let now = Date(timeIntervalSince1970: 1_700_000_000)
            func dive(start: Date) -> GoDiveSharedDiveProjectionMapping.FriendVisibleDive {
                GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                    id: "ts",
                    activityKind: .scubaDive,
                    startTime: start,
                    durationMinutes: nil,
                    maxDepthMeters: nil,
                    averageDepthMeters: nil,
                    diveNumber: nil,
                    siteName: "Reef",
                    locationName: nil,
                    region: nil,
                    country: nil,
                    swimDistanceMeters: nil,
                    entryLatitude: nil,
                    entryLongitude: nil,
                    notes: nil,
                    activityTagNames: [],
                    sightings: [],
                    taggedBuddies: [],
                    equipmentSummary: [],
                    mediaPreviews: [],
                    profileTrackBase64: nil,
                    swimTrackBase64: nil,
                    gasType: nil,
                    oxygenMix: nil,
                    tankVolumeDescription: nil,
                    waterTempMinCelsius: nil,
                    bottomTimeSeconds: nil
                )
            }

            #expect(
                LogbookBuddyFeedPresentation.postTimestampText(
                    for: dive(start: now.addingTimeInterval(-30)),
                    now: now
                ) == "now"
            )
            #expect(
                LogbookBuddyFeedPresentation.postTimestampText(
                    for: dive(start: now.addingTimeInterval(-5 * 60)),
                    now: now
                ) == "5m"
            )
            #expect(
                LogbookBuddyFeedPresentation.postTimestampText(
                    for: dive(start: now.addingTimeInterval(-3 * 3_600)),
                    now: now
                ) == "3h"
            )
            #expect(
                LogbookBuddyFeedPresentation.postTimestampText(
                    for: dive(start: now.addingTimeInterval(-2 * 86_400)),
                    now: now
                ) == "2d"
            )
            #expect(
                LogbookBuddyFeedPresentation.postTimestampText(
                    for: dive(start: now.addingTimeInterval(-14 * 86_400)),
                    now: now
                ) == "2w"
            )
            #expect(
                LogbookBuddyFeedPresentation.postTimestampText(
                    for: dive(start: now),
                    now: now
                ) == "now"
            )
        }

        @Test func buddyFeed_postSocialChrome_taggedBuddiesNotesAndLikeCopy() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "social-1",
                activityKind: .scubaDive,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 3,
                siteName: "Reef",
                locationName: nil,
                region: nil,
                country: nil,
                swimDistanceMeters: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: "  Crystal clear day  ",
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [
                    .init(displayName: "Alex Rivera", firebaseUID: "uid-alex"),
                    .init(displayName: "Sam Lee", firebaseUID: nil),
                    .init(displayName: "Pat", firebaseUID: "uid-pat"),
                    .init(displayName: "Jordan Kim", firebaseUID: "uid-jordan"),
                    .init(displayName: "Casey", firebaseUID: "uid-casey"),
                ],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                swimTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )

            #expect(LogbookBuddyFeedPresentation.postActivityVerb(for: dive) == "logged a dive")
            #expect(LogbookBuddyFeedPresentation.postNotesPreview(for: dive) == "Crystal clear day")
            #expect(LogbookBuddyFeedPresentation.feedTaggedBuddies(for: dive).count == 5)
            #expect(LogbookBuddyFeedPresentation.visibleFeedTaggedBuddies(for: dive).count == 4)
            #expect(LogbookBuddyFeedPresentation.overflowTaggedBuddyCount(for: dive) == 1)
            #expect(LogbookBuddyFeedPresentation.withTaggedBuddyNamesLine(for: dive) == nil)

            let twoBuddies = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "social-2",
                activityKind: .snorkel,
                startTime: nil,
                durationMinutes: nil,
                maxDepthMeters: nil,
                averageDepthMeters: nil,
                diveNumber: nil,
                siteName: nil,
                locationName: "Bay",
                region: nil,
                country: nil,
                swimDistanceMeters: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: "   ",
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [
                    .init(displayName: "Alex Rivera", firebaseUID: "uid-alex"),
                    .init(displayName: "Sam Lee", firebaseUID: nil),
                ],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                swimTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            #expect(LogbookBuddyFeedPresentation.postActivityVerb(for: twoBuddies) == "logged a snorkel")
            #expect(LogbookBuddyFeedPresentation.postNotesPreview(for: twoBuddies) == nil)
            #expect(LogbookBuddyFeedPresentation.withTaggedBuddyNamesLine(for: twoBuddies) == "Alex & Sam")
            #expect(
                !LogbookBuddyFeedPresentation.feedTaggedBuddies(for: twoBuddies)[0].showsGoDiveUserPin
            )
            #expect(
                !LogbookBuddyFeedPresentation.feedTaggedBuddies(for: twoBuddies)[1].showsGoDiveUserPin
            )
            #expect(!LogbookBuddyFeedPresentation.feedTaggedBuddyShowsGoDiveUserPin)
            #expect(LogbookBuddyFeedPresentation.likeEmoji == "👌")
            #expect(
                LogbookBuddyFeedPresentation.feedTaggedBuddies(for: twoBuddies)[0].firebaseUID == "uid-alex"
            )
            #expect(
                LogbookBuddyFeedPresentation.shouldScrollToTaggedBuddiesOnAppear(
                    scrollToTaggedBuddiesOnAppear: true,
                    alreadyConsumed: false
                )
            )
            #expect(
                !LogbookBuddyFeedPresentation.shouldScrollToTaggedBuddiesOnAppear(
                    scrollToTaggedBuddiesOnAppear: true,
                    alreadyConsumed: true
                )
            )
            #expect(
                !LogbookBuddyFeedPresentation.taggedBuddiesPanelScrollSectionID.isEmpty
            )
            #expect(LogbookBuddyFeedPresentation.likeAccessibilityLabel(isLiked: false) == "Like")
            #expect(LogbookBuddyFeedPresentation.likeAccessibilityLabel(isLiked: true) == "Unlike")
            #expect(LogbookBuddyFeedPresentation.likeCountLabel(count: 0, isLikedByCurrentUser: false) == nil)
            #expect(LogbookBuddyFeedPresentation.likeCountLabel(count: 0, isLikedByCurrentUser: true) == "1")
            #expect(LogbookBuddyFeedPresentation.likeCountLabel(count: 3, isLikedByCurrentUser: false) == "3")
        }

        @Test func buddyFeedAvatarLookup_resolvesMeLocalAndFriendRemote() {
            let meJPEG = Data([0xFF, 0xD8, 0xFF, 0x01])
            let friends = [
                GoDiveFriendGraphService.friendEdge(
                    friendUID: "uid-alex",
                    displayName: "Alex",
                    photoURL: "https://firebasestorage.googleapis.com/v0/b/t/o/alex.jpg?alt=media"
                ),
            ]
            let lookup = BuddyFeedAvatarLookup.make(
                currentFirebaseUID: "uid-me",
                currentLocalProfilePhoto: meJPEG,
                currentRemotePhotoURL: "https://firebasestorage.googleapis.com/v0/b/t/o/stale.jpg?alt=media",
                friends: friends
            )

            let me = BuddyFeedAvatarPresentation.resolve(firebaseUID: "uid-me", lookup: lookup)
            #expect(me.localProfilePhoto == meJPEG)
            #expect(me.photoURL == nil)

            let friend = BuddyFeedAvatarPresentation.resolve(firebaseUID: "uid-alex", lookup: lookup)
            #expect(friend.photoURL?.contains("alex.jpg") == true)
            #expect(friend.localProfilePhoto == nil)

            let unknown = BuddyFeedAvatarPresentation.resolve(firebaseUID: "uid-other", lookup: lookup)
            #expect(unknown.photoURL == nil)
            #expect(unknown.localProfilePhoto == nil)

            let meRemoteOnly = BuddyFeedAvatarLookup.make(
                currentFirebaseUID: "uid-me",
                currentLocalProfilePhoto: nil,
                currentRemotePhotoURL: "https://firebasestorage.googleapis.com/v0/b/t/o/me.jpg?alt=media",
                friends: []
            )
            let meFallback = BuddyFeedAvatarPresentation.resolve(
                firebaseUID: "uid-me",
                lookup: meRemoteOnly
            )
            #expect(meFallback.localProfilePhoto == nil)
            #expect(meFallback.photoURL?.contains("me.jpg") == true)

            let seed = BuddyFeedAvatarLookup.make(
                currentFirebaseUID: nil,
                currentLocalProfilePhoto: nil,
                friends: friends
            )
            let session = BuddyFeedAvatarLookup.make(
                currentFirebaseUID: "uid-me",
                currentLocalProfilePhoto: meJPEG,
                friends: []
            )
            let merged = BuddyFeedAvatarLookup.merging(seed: seed, session: session)
            #expect(merged.currentFirebaseUID == "uid-me")
            #expect(merged.currentLocalProfilePhoto == meJPEG)
            #expect(merged.friendPhotoURLByUID["uid-alex"] != nil)
            #expect(!merged.equatableFingerprint.isEmpty)

            let taggedDive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "avatar-prefetch-1",
                activityKind: .scubaDive,
                startTime: nil,
                durationMinutes: nil,
                maxDepthMeters: nil,
                averageDepthMeters: nil,
                diveNumber: nil,
                siteName: "Reef",
                locationName: nil,
                region: nil,
                country: nil,
                swimDistanceMeters: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [
                    .init(displayName: "Alex Rivera", firebaseUID: "uid-alex"),
                ],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                swimTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            let prefetch = GoDiveRemoteAvatarPresentation.buddyFeedAvatarPrefetchURLs(
                rows: [
                    LogbookBuddyFeedPresentation.Row(
                        id: "r1",
                        friendUID: "uid-owner",
                        friendDisplayName: "Owner",
                        friendPhotoURL: "https://firebasestorage.googleapis.com/v0/b/t/o/owner.jpg?alt=media",
                        dive: taggedDive
                    ),
                ],
                startIndex: 0,
                avatarLookup: lookup
            )
            #expect(prefetch.contains(where: { $0.contains("owner.jpg") }))
            #expect(prefetch.contains(where: { $0.contains("alex.jpg") }))
        }

        @Test func buddyFeed_rowApplyingLikeToggle_updatesTallyOptimistically() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "liked-1",
                activityKind: .scubaDive,
                startTime: nil,
                durationMinutes: nil,
                maxDepthMeters: nil,
                averageDepthMeters: nil,
                diveNumber: nil,
                siteName: "Reef",
                locationName: nil,
                region: nil,
                country: nil,
                swimDistanceMeters: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                swimTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil,
                likeCount: 2
            )
            let row = LogbookBuddyFeedPresentation.Row(
                id: "friend_liked-1",
                friendUID: "friend",
                friendDisplayName: "Blake",
                friendPhotoURL: nil,
                dive: dive,
                currentUserHasLiked: false
            )
            let liked = LogbookBuddyFeedPresentation.rowApplyingLikeToggle(row, liked: true)
            #expect(liked.currentUserHasLiked)
            #expect(liked.likeCount == 3)

            let unliked = LogbookBuddyFeedPresentation.rowApplyingLikeToggle(liked, liked: false)
            #expect(!unliked.currentUserHasLiked)
            #expect(unliked.likeCount == 2)

            let enriched = LogbookBuddyFeedPresentation.enrichingRows(
                [row],
                likedRowIDs: ["friend_liked-1"]
            )
            #expect(enriched[0].currentUserHasLiked)

            #expect(
                GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
                    id: "x",
                    data: ["likeCount": 4, "activityKind": "scubaDive"]
                ).likeCount == 4
            )
            #expect(
                GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
                    id: "x",
                    data: ["likeCount": -2, "activityKind": "scubaDive"]
                ).likeCount == 0
            )
        }

        @Test func buddyFeed_commentCountParseAndOptimisticDelta() {
            #expect(
                GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
                    id: "x",
                    data: ["commentCount": 5, "activityKind": "scubaDive"]
                ).commentCount == 5
            )
            #expect(
                GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
                    id: "x",
                    data: ["commentCount": -3, "activityKind": "scubaDive"]
                ).commentCount == 0
            )
            #expect(LogbookBuddyFeedPresentation.commentCountLabel(count: 0) == nil)
            #expect(LogbookBuddyFeedPresentation.commentCountLabel(count: 2) == "2")

            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "cmt-1",
                activityKind: .scubaDive,
                startTime: nil,
                durationMinutes: nil,
                maxDepthMeters: nil,
                averageDepthMeters: nil,
                diveNumber: nil,
                siteName: "Reef",
                locationName: nil,
                region: nil,
                country: nil,
                swimDistanceMeters: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: nil,
                swimTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil,
                likeCount: 0,
                commentCount: 1
            )
            let row = LogbookBuddyFeedPresentation.Row(
                id: "friend_cmt-1",
                friendUID: "friend",
                friendDisplayName: "Blake",
                friendPhotoURL: nil,
                dive: dive
            )
            let bumped = LogbookBuddyFeedPresentation.rowApplyingCommentCountDelta(row, delta: 1)
            #expect(bumped.commentCount == 2)
            let floored = LogbookBuddyFeedPresentation.rowApplyingCommentCountDelta(row, delta: -5)
            #expect(floored.commentCount == 0)

            let now = Date()
            #expect(
                LogbookBuddyFeedPresentation.commentTimestampText(
                    createdAt: now.addingTimeInterval(-120),
                    now: now
                ) == "2m"
            )
        }

        @Test func buddyFeed_mergesAndSortsNewestFirst() {
            let friends = [
                GoDiveFriendGraphService.FriendEdge(
                    friendUID: "friend-a",
                    friendshipID: "a_b",
                    displayName: "Alex",
                    photoURL: nil,
                    since: nil
                ),
                GoDiveFriendGraphService.FriendEdge(
                    friendUID: "friend-b",
                    friendshipID: "b_c",
                    displayName: "Blake",
                    photoURL: nil,
                    since: nil
                ),
            ]
            let older = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-old",
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
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
                mediaPreviews: [],
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            let newer = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-new",
                startTime: Date(timeIntervalSince1970: 1_800_000_000),
                durationMinutes: 50,
                maxDepthMeters: 22,
                averageDepthMeters: nil,
                diveNumber: 2,
                siteName: "Wall",
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
            let rows = LogbookBuddyFeedPresentation.rows(
                friends: friends,
                divesByFriendUID: [
                    "friend-a": [older],
                    "friend-b": [newer],
                ]
            )
            #expect(rows.count == 2)
            #expect(rows[0].dive.id == "dive-new")
            #expect(rows[1].dive.id == "dive-old")
            #expect(rows[0].friendDisplayName == "Blake")
        }

        @Test func buddyFeed_sortsSameDayActivitiesByStartTime() {
            let day = Date(timeIntervalSince1970: 1_700_000_000)
            let morning = Self.makeBuddyFeedDive(id: "morning", startTime: day.addingTimeInterval(9 * 3600))
            let afternoon = Self.makeBuddyFeedDive(id: "afternoon", startTime: day.addingTimeInterval(15 * 3600))
            let friends = [
                GoDiveFriendGraphService.FriendEdge(
                    friendUID: "friend-a",
                    friendshipID: "a_b",
                    displayName: "Alex",
                    photoURL: nil,
                    since: nil
                ),
                GoDiveFriendGraphService.FriendEdge(
                    friendUID: "friend-b",
                    friendshipID: "b_c",
                    displayName: "Blake",
                    photoURL: nil,
                    since: nil
                ),
            ]
            let rows = LogbookBuddyFeedPresentation.rows(
                friends: friends,
                divesByFriendUID: [
                    "friend-a": [morning],
                    "friend-b": [afternoon],
                ]
            )
            #expect(rows.map(\.dive.id) == ["afternoon", "morning"])
        }

        @Test func buddyFeed_sortFriendVisibleDives_fallsBackToUpdatedAt() {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let newerSync = Self.makeBuddyFeedDive(id: "synced", startTime: nil, updatedAt: start.addingTimeInterval(3600))
            let olderSync = Self.makeBuddyFeedDive(id: "stale", startTime: nil, updatedAt: start)
            let sorted = LogbookBuddyFeedPresentation.sortFriendVisibleDivesNewestFirst([olderSync, newerSync])
            #expect(sorted.map(\.id) == ["synced", "stale"])
        }

        @Test @MainActor func buddyFeed_emptyKind_whenNoFriends() {
            let kind = LogbookBuddyFeedPresentation.emptyKind(
                friends: [],
                rows: [],
                firebaseConfigured: true,
                isSignedIn: true
            )
            #expect(kind == .noFriends)
        }

        @Test func buddyFeed_pullToRefreshPresentation_exposesSpinnerChrome() {
            #expect(
                LogbookBuddyFeedPullToRefreshPresentation.spinnerAccessibilityIdentifier
                    == "Logbook.BuddyFeed.RefreshSpinner"
            )
            #expect(
                LogbookBuddyFeedPullToRefreshPresentation.spinnerAccessibilityLabel
                    == "Refreshing buddy feed"
            )
            #expect(LogbookBuddyFeedPullToRefreshPresentation.spinnerTopPadding == AppTheme.Spacing.sm)
            #expect(LogbookBuddyFeedPullToRefreshPresentation.spinnerAppearScale > 0)
            #expect(LogbookBuddyFeedPullToRefreshPresentation.spinnerAppearScale < 1)
            #expect(LogbookBuddyFeedPullToRefreshPresentation.spinnerAnimationDuration > 0)
            #expect(LogbookBuddyFeedPullToRefreshPresentation.minimumHoldDurationSeconds > 0)
            #expect(LogbookBuddyFeedPullToRefreshPresentation.refreshHapticIntensity > 0)
            #expect(LogbookBuddyFeedPullToRefreshPresentation.refreshHapticIntensity <= 1)
            #expect(
                LogbookBuddyFeedPullToRefreshPresentation.symbolName
                    == GoDiveRotateLoadingPresentation.symbolName
            )
            #expect(LogbookBuddyFeedPullToRefreshPresentation.symbolRotateSpeed > 0)
            #expect(
                GoDiveRotateLoadingPresentation.symbolName == "arrow.trianglehead.2.clockwise"
            )
            #expect(GoDiveRotateLoadingPresentation.rotateSpeed > 0)
        }

        @Test func buddyFeed_autoRefreshOnlyOnRootBuddyFeedSegment() {
            #expect(
                LogbookBuddyFeedPresentation.shouldAutoRefreshBuddyFeedList(
                    feedScope: .buddyFeed,
                    navigationPathCount: 0,
                    isLogbookTabSelected: true
                )
            )
            #expect(
                !LogbookBuddyFeedPresentation.shouldAutoRefreshBuddyFeedList(
                    feedScope: .myActivities,
                    navigationPathCount: 0,
                    isLogbookTabSelected: true
                )
            )
            #expect(
                !LogbookBuddyFeedPresentation.shouldAutoRefreshBuddyFeedList(
                    feedScope: .buddyFeed,
                    navigationPathCount: 1,
                    isLogbookTabSelected: true
                )
            )
            #expect(
                !LogbookBuddyFeedPresentation.shouldAutoRefreshBuddyFeedList(
                    feedScope: .buddyFeed,
                    navigationPathCount: 0,
                    isLogbookTabSelected: false
                )
            )
        }

        @Test func buddyFeed_emptyState_openFriendsButtonTitles() {
            #expect(LogbookBuddyFeedPresentation.openFriendsButtonTitle(for: .noFriends) == "Add friends")
            #expect(LogbookBuddyFeedPresentation.openFriendsButtonTitle(for: .noSharedDives) == "View friends")
            #expect(LogbookBuddyFeedPresentation.openFriendsButtonTitle(for: .unavailable) == nil)
            #expect(LogbookBuddyFeedPresentation.showsOpenFriendsButton(for: .noFriends))
            #expect(!LogbookBuddyFeedPresentation.showsOpenFriendsButton(for: .unavailable))
        }

        @Test func buddyFeed_rowsEqual_comparesMediaPayload() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-media",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 3,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [.init(photoID: "p1", previewURL: "https://example.com/1.jpg")],
                featuredMediaPhotoID: "p1",
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            let left = LogbookBuddyFeedPresentation.Row(
                id: "friend_dive-media",
                friendUID: "friend",
                friendDisplayName: "Alex",
                friendPhotoURL: nil,
                dive: dive
            )
            var changedMedia = dive
            changedMedia.mediaPreviews = [.init(photoID: "p2", previewURL: "https://example.com/2.jpg")]
            let right = LogbookBuddyFeedPresentation.Row(
                id: "friend_dive-media",
                friendUID: "friend",
                friendDisplayName: "Alex",
                friendPhotoURL: nil,
                dive: changedMedia
            )
            #expect(!LogbookBuddyFeedPresentation.rowsEqual([left], [right]))
        }

        @Test func buddyFeed_heroPager_pageSizeFillsContainerAndClipsOverflow() {
            let size = CGSize(width: 320, height: LogbookBuddyFeedTileLayout.heroHeight)
            #expect(
                LogbookBuddyFeedHeroPagerPresentation.pageSize(containerSize: size)
                    == size
            )
            #expect(
                LogbookBuddyFeedHeroPagerPresentation.pageSize(
                    containerSize: CGSize(width: -10, height: -10)
                ) == .zero
            )
            #expect(LogbookBuddyFeedHeroPagerPresentation.clipsOverflowingPageContent)
        }

        @Test func buddyFeed_heroPages_featuredMediaFirstThenChart() throws {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let profileTrack = try #require(
                try DiveProfileTrackCodec.encode(
                    samples: [
                        DiveProfileTrackSample(timestamp: start, depthMeters: 0),
                        DiveProfileTrackSample(timestamp: start.addingTimeInterval(120), depthMeters: 18.5),
                    ],
                    diveStartTime: start
                )
            )
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "dive-hero",
                startTime: start,
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 3,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [
                    .init(photoID: "secondary", previewURL: "https://example.com/secondary.jpg"),
                    .init(photoID: "featured", previewURL: "https://example.com/featured.jpg"),
                ],
                featuredMediaPhotoID: "featured",
                profileTrackBase64: profileTrack.base64EncodedString(),
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )

            #expect(LogbookBuddyFeedPresentation.tileFeaturedMediaPreview(for: dive)?.photoID == "featured")

            let pages = LogbookBuddyFeedPresentation.heroPages(for: dive)
            #expect(pages.count == 2)
            if case .media(let item) = pages[0] {
                #expect(item.mediaID == "featured")
            } else {
                Issue.record("Expected featured media page first")
            }
            #expect(pages[1] == .activityVisualization)
            #expect(LogbookBuddyFeedPresentation.showsHeroPager(for: dive))
        }

        @Test func buddyFeed_heroPages_mediaOnlyWithoutDepthData() {
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "media-only",
                startTime: Date(),
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 3,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [.init(photoID: "p1", previewURL: "https://example.com/p.jpg")],
                profileTrackBase64: nil,
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            let expectedItem = FriendSharedMediaPresentation.DisplayItem(
                mediaID: "p1",
                kind: .photo,
                thumbnailURL: "https://example.com/p.jpg",
                contentURL: nil
            )
            #expect(LogbookBuddyFeedPresentation.heroPages(for: dive) == [.media(expectedItem)])
            #expect(!LogbookBuddyFeedPresentation.showsHeroPager(for: dive))
        }

        @Test func buddyFeed_heroPages_chartOnlyWithoutMedia() throws {
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let profileTrack = try #require(
                try DiveProfileTrackCodec.encode(
                    samples: [
                        DiveProfileTrackSample(timestamp: start, depthMeters: 0),
                        DiveProfileTrackSample(timestamp: start.addingTimeInterval(60), depthMeters: 12),
                    ],
                    diveStartTime: start
                )
            )
            let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "chart-only",
                startTime: start,
                durationMinutes: 40,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                diveNumber: 3,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                mediaPreviews: [],
                profileTrackBase64: profileTrack.base64EncodedString(),
                gasType: nil,
                oxygenMix: nil,
                tankVolumeDescription: nil,
                waterTempMinCelsius: nil,
                bottomTimeSeconds: nil
            )
            #expect(LogbookBuddyFeedPresentation.heroPages(for: dive) == [.activityVisualization])
            #expect(!LogbookBuddyFeedPresentation.showsHeroPager(for: dive))
        }

        @Test func buddyFeed_heroPages_placeholderWhenNoMediaOrDepthData() {
            let dive = Self.makeBuddyFeedDive(id: "empty-hero", startTime: Date())
            #expect(LogbookBuddyFeedPresentation.heroPages(for: dive) == [.placeholder])
            #expect(!LogbookBuddyFeedPresentation.showsHeroPager(for: dive))
        }

        @Test func buddyFeed_pagination_loadsTwentyAtATime() {
            let rows = (0..<45).map { index in
                LogbookBuddyFeedPresentation.Row(
                    id: "friend_dive-\(index)",
                    friendUID: "friend",
                    friendDisplayName: "Alex",
                    friendPhotoURL: nil,
                    dive: Self.makeBuddyFeedDive(id: "dive-\(index)", startTime: Date(timeIntervalSince1970: Double(index)))
                )
            }

            #expect(LogbookBuddyFeedPresentation.initialDisplayedCount(for: rows.count) == 20)
            #expect(LogbookBuddyFeedPresentation.visibleRows(from: rows, displayedCount: 20).count == 20)
            #expect(LogbookBuddyFeedPresentation.visibleRows(from: rows, displayedCount: 20).first?.dive.id == "dive-0")

            let afterFirstLoadMore = LogbookBuddyFeedPresentation.nextDisplayedCount(current: 20, totalRowCount: rows.count)
            #expect(afterFirstLoadMore == 40)
            #expect(LogbookBuddyFeedPresentation.visibleRows(from: rows, displayedCount: afterFirstLoadMore).count == 40)

            let afterSecondLoadMore = LogbookBuddyFeedPresentation.nextDisplayedCount(current: 40, totalRowCount: rows.count)
            #expect(afterSecondLoadMore == 45)
            #expect(!LogbookBuddyFeedPresentation.hasMoreRows(totalRowCount: rows.count, displayedCount: afterSecondLoadMore))

            #expect(
                LogbookBuddyFeedPresentation.shouldLoadNextPage(
                    rowIndex: 19,
                    visibleRowCount: 20,
                    totalRowCount: rows.count,
                    displayedCount: 20
                )
            )
            #expect(
                !LogbookBuddyFeedPresentation.shouldLoadNextPage(
                    rowIndex: 10,
                    visibleRowCount: 20,
                    totalRowCount: rows.count,
                    displayedCount: 20
                )
            )
        }

        @Test func buddyFeed_rows_carryFriendPhotoURL() {
            let friend = GoDiveFriendGraphService.FriendEdge(
                friendUID: "friend-1",
                friendshipID: "ship-1",
                displayName: "Alex",
                photoURL: "https://example.com/avatar.jpg",
                profileHeroURL: nil,
                profileHeroMediaKind: nil,
                totalDiveCount: nil,
                since: nil
            )
            let dive = Self.makeBuddyFeedDive(id: "dive-1", startTime: Date())
            let rows = LogbookBuddyFeedPresentation.rows(
                friends: [friend],
                divesByFriendUID: [friend.friendUID: [dive]]
            )
            #expect(rows.count == 1)
            #expect(rows[0].friendPhotoURL == "https://example.com/avatar.jpg")
        }

        @Test func buddyFeedAvatarLookup_rosterFallbacksFillMissingFriendPhotoURL() {
            let owner = UserProfile(appleUserIdentifier: "roster-avatar-fallback", displayName: "Viewer")
            let roster = DiveBuddy(displayName: "Alex", owner: owner)
            roster.linkedFirebaseUID = "uid-alex"
            roster.linkedPhotoURL =
                "https://firebasestorage.googleapis.com/v0/b/t/o/roster-alex.jpg?alt=media"
            roster.profilePhoto = Data([0xAA, 0xBB])

            let friendsWithoutPhoto = [
                GoDiveFriendGraphService.friendEdge(
                    friendUID: "uid-alex",
                    displayName: "Alex",
                    photoURL: nil
                ),
            ]
            let lookup = BuddyFeedAvatarLookup.make(
                currentFirebaseUID: "uid-me",
                currentLocalProfilePhoto: nil,
                friends: friendsWithoutPhoto,
                rosterBuddies: [roster]
            )
            let resolved = BuddyFeedAvatarPresentation.resolve(
                firebaseUID: "uid-alex",
                lookup: lookup
            )
            #expect(resolved.localProfilePhoto == Data([0xAA, 0xBB]))
            #expect(resolved.photoURL?.contains("roster-alex.jpg") == true)
        }

        @Test func homeNotifications_items_mergeAndSortNewestFirst() {
            let friend = GoDiveFriendGraphService.friendEdge(
                friendUID: "friend-a",
                displayName: "Alex",
                photoURL: "https://firebasestorage.googleapis.com/a.jpg",
                since: Date(timeIntervalSince1970: 1_700_050_000)
            )
            let rows = [
                LogbookBuddyFeedPresentation.Row(
                    id: "friend-a-older",
                    friendUID: "friend-a",
                    friendDisplayName: "Alex",
                    friendPhotoURL: nil,
                    dive: makeNotificationTestDive(
                        id: "older",
                        startTime: Date(timeIntervalSince1970: 1_700_000_000),
                        siteName: "Blue Hole"
                    )
                ),
                LogbookBuddyFeedPresentation.Row(
                    id: "friend-a-newest",
                    friendUID: "friend-a",
                    friendDisplayName: "Alex",
                    friendPhotoURL: nil,
                    dive: makeNotificationTestDive(
                        id: "newest",
                        kind: .snorkel,
                        startTime: Date(timeIntervalSince1970: 1_700_000_000),
                        updatedAt: Date(timeIntervalSince1970: 1_700_100_000)
                    )
                ),
            ]

            let items = HomeNotificationsPresentation.items(friends: [friend], activityRows: rows)
            #expect(items.count == 3)
            #expect(items[0].id == "activity-friend-a-newest")
            #expect(items[0].message == "Alex logged a new snorkel")
            #expect(items[1].id == "friend-friend-a")
            #expect(items[1].message == "Alex is now your dive buddy")
            #expect(items[2].id == "activity-friend-a-older")
            #expect(items[2].message == "Alex logged a new dive")
            #expect(items[2].detail == "Blue Hole")
        }

        @Test func homeNotifications_items_addTaggedYouRowWhenCurrentUserTagged() {
            let taggedDive = makeNotificationTestDive(
                id: "tagged-dive",
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                siteName: "Reef",
                taggedBuddies: [
                    GoDiveSharedDiveProjectionMapping.TaggedBuddySnapshot(
                        displayName: "Me",
                        firebaseUID: "my-firebase-uid"
                    ),
                ]
            )
            let row = LogbookBuddyFeedPresentation.Row(
                id: "friend-a-tagged",
                friendUID: "friend-a",
                friendDisplayName: "Alex",
                friendPhotoURL: nil,
                dive: taggedDive
            )

            let items = HomeNotificationsPresentation.items(
                friends: [],
                activityRows: [row],
                currentFirebaseUID: "my-firebase-uid"
            )
            #expect(items.count == 2)
            #expect(items[0].id == "activity-tag-friend-a-tagged")
            #expect(items[0].message == "Alex tagged you in a new dive")
            #expect(items[1].id == "activity-friend-a-tagged")
            #expect(items[1].message == "Alex logged a new dive")

            let withoutUID = HomeNotificationsPresentation.items(
                friends: [],
                activityRows: [row],
                currentFirebaseUID: nil
            )
            #expect(withoutUID.count == 1)
            #expect(withoutUID[0].id == "activity-friend-a-tagged")
        }

        @Test func homeNotifications_items_skipFriendWithoutSinceDate() {
            let friend = GoDiveFriendGraphService.friendEdge(
                friendUID: "friend-b",
                displayName: "Sam"
            )
            let items = HomeNotificationsPresentation.items(friends: [friend], activityRows: [])
            #expect(items.isEmpty)
        }

        @Test func homeNotifications_items_includeOwnedLikesAndComments() {
            let activityID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
            let friend = GoDiveFriendGraphService.FriendEdge(
                friendUID: "friend-sam",
                friendshipID: "f1",
                displayName: "Sam",
                photoURL: "https://firebasestorage.googleapis.com/v0/b/t/o/sam.jpg?alt=media",
                profileHeroURL: nil,
                profileHeroMediaKind: nil,
                totalDiveCount: nil,
                since: Date(timeIntervalSince1970: 1_600_000_000)
            )
            let likeEvent = HomeNotificationsOwnedSocialSync.Event(
                id: "like-\(activityID.uuidString)-friend-sam",
                kind: .like,
                activityID: activityID,
                activityKind: .scubaDive,
                actorUID: "friend-sam",
                actorDisplayName: "Sam",
                createdAt: Date(timeIntervalSince1970: 1_700_300_000),
                siteName: "Blue Hole",
                commentText: nil
            )
            let commentEvent = HomeNotificationsOwnedSocialSync.Event(
                id: "comment-\(activityID.uuidString)-c1",
                kind: .comment,
                activityID: activityID,
                activityKind: .snorkel,
                actorUID: "friend-sam",
                actorDisplayName: "Sam",
                createdAt: Date(timeIntervalSince1970: 1_700_400_000),
                siteName: "Bay",
                commentText: "  Crystal clear water today  "
            )

            let items = HomeNotificationsPresentation.items(
                friends: [friend],
                activityRows: [],
                ownedSocialEvents: [likeEvent, commentEvent]
            )
            #expect(items.count == 3)
            #expect(items[0].id == commentEvent.id)
            #expect(items[0].message == "Sam commented on Bay")
            #expect(items[0].detail == "Crystal clear water today")
            #expect(items[0].friendPhotoURL?.contains("sam.jpg") == true)
            if case .buddyActivityCommented(let target) = items[0].kind {
                #expect(target.activityID == activityID)
                #expect(target.activityKind == .snorkel)
                #expect(target.opensComments)
            } else {
                Issue.record("Expected commented kind")
            }

            #expect(items[1].id == likeEvent.id)
            #expect(items[1].message == "Blue Hole has new likes")
            #expect(items[1].detail == "Sam liked your dive")
            if case .buddyActivityLiked(let target) = items[1].kind {
                #expect(target.activityID == activityID)
                #expect(!target.opensComments)
            } else {
                Issue.record("Expected liked kind")
            }

            #expect(items[2].id == "friend-friend-sam")
            #expect(
                HomeNotificationsPresentation.activityLikedMessage(
                    activityKind: .scubaDive,
                    siteName: "Blue Hole"
                ) == "Blue Hole has new likes"
            )
            #expect(
                HomeNotificationsPresentation.activityLikedMessage(
                    activityKind: .scubaDive
                ) == "your dive has new likes"
            )
            #expect(
                HomeNotificationsPresentation.activityLikedDetail(
                    displayName: "Sam",
                    activityKind: .scubaDive
                ) == "Sam liked your dive"
            )
            #expect(
                HomeNotificationsPresentation.activityLikedDetail(
                    displayName: "Sam",
                    activityKind: .snorkel
                ) == "Sam liked your snorkel"
            )
            #expect(
                HomeNotificationsPresentation.activityCommentedMessage(
                    displayName: "Sam",
                    activityKind: .scubaDive,
                    siteName: "Blue Hole"
                ) == "Sam commented on Blue Hole"
            )
            #expect(
                HomeNotificationsPresentation.activityCommentedMessage(
                    displayName: "Sam",
                    activityKind: .scubaDive
                ) == "Sam commented on your dive"
            )
            #expect(
                HomeNotificationsPresentation.commentNotificationPreviewDetail(
                    commentText: "  Great dive  "
                ) == "Great dive"
            )
            #expect(
                HomeNotificationsPresentation.commentNotificationPreviewDetail(
                    commentText: "   "
                ) == nil
            )
            #expect(
                HomeNotificationsPresentation.commentedNotificationDetail(
                    commentText: "   ",
                    siteName: "Blue Hole"
                ) == "Blue Hole"
            )
            #expect(
                GoDiveBuddyActivityCommentedPushPresentation.notificationBody(
                    authorDisplayName: "Sam",
                    activityKind: .scubaDive,
                    commentText: "Nice reef"
                ) == "Sam commented on your dive: Nice reef"
            )
        }

        @Test func homeNotifications_activityDate_prefersSharedAtThenUpdatedAtThenStartTime() {
            let shared = Date(timeIntervalSince1970: 1_700_100_000)
            let updated = Date(timeIntervalSince1970: 1_700_200_000)
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let withShared = makeNotificationTestDive(
                id: "d",
                startTime: start,
                updatedAt: updated,
                sharedAt: shared
            )
            #expect(HomeNotificationsPresentation.activityDate(for: withShared) == shared)

            let updatedOnly = makeNotificationTestDive(
                id: "d1",
                startTime: start,
                updatedAt: updated
            )
            #expect(HomeNotificationsPresentation.activityDate(for: updatedOnly) == updated)

            let startOnly = makeNotificationTestDive(
                id: "d2",
                startTime: start
            )
            #expect(HomeNotificationsPresentation.activityDate(for: startOnly) == start)
        }

        @Test func homeNotifications_hasUnread_gatesOnLastSeen() {
            let item = HomeNotificationsPresentation.Item(
                id: "friend-x",
                kind: .friendConnected(
                    GoDiveFriendGraphService.friendEdge(friendUID: "x", displayName: "X")
                ),
                date: Date(timeIntervalSince1970: 1_700_000_000),
                friendDisplayName: "X",
                friendPhotoURL: nil,
                message: "X is now your dive buddy",
                detail: nil
            )
            #expect(HomeNotificationsPresentation.hasUnread(items: [item], lastSeenAt: nil))
            #expect(
                HomeNotificationsPresentation.hasUnread(
                    items: [item],
                    lastSeenAt: Date(timeIntervalSince1970: 1_699_000_000)
                )
            )
            #expect(
                !HomeNotificationsPresentation.hasUnread(
                    items: [item],
                    lastSeenAt: Date(timeIntervalSince1970: 1_700_000_001)
                )
            )
            #expect(!HomeNotificationsPresentation.hasUnread(items: [], lastSeenAt: nil))
        }

        @Test func homeNotifications_isUnreadAndReadRowStyle_useLastSeenWatermark() {
            let newer = Date(timeIntervalSince1970: 1_700_000_100)
            let older = Date(timeIntervalSince1970: 1_700_000_000)
            let seenAt = Date(timeIntervalSince1970: 1_700_000_050)

            #expect(HomeNotificationsPresentation.isUnread(itemDate: newer, lastSeenAt: nil))
            #expect(HomeNotificationsPresentation.isUnread(itemDate: older, lastSeenAt: nil))
            #expect(HomeNotificationsPresentation.isUnread(itemDate: newer, lastSeenAt: seenAt))
            #expect(!HomeNotificationsPresentation.isUnread(itemDate: older, lastSeenAt: seenAt))
            #expect(!HomeNotificationsPresentation.isUnread(itemDate: seenAt, lastSeenAt: seenAt))

            #expect(HomeNotificationsPresentation.rowOpacity(isUnread: true) == 1)
            #expect(HomeNotificationsPresentation.rowOpacity(isUnread: false) == 0.48)
            #expect(HomeNotificationsPresentation.usesSemiboldTitle(isUnread: true))
            #expect(!HomeNotificationsPresentation.usesSemiboldTitle(isUnread: false))
            #expect(HomeNotificationsPresentation.titleLineLimit == 2)
            #expect(HomeNotificationsPresentation.detailAndTimeLineLimit == 1)
        }

        @Test func homeNotifications_sections_newIsUnreadAndRecent_olderIncludesAllPastTwoWeeks() {
            let now = Date(timeIntervalSince1970: 2_000_000_000)
            let seenAt = now.addingTimeInterval(-3 * 24 * 60 * 60)
            let unreadRecent = HomeNotificationsPresentation.Item(
                id: "unread-recent",
                kind: .friendConnected(
                    GoDiveFriendGraphService.friendEdge(friendUID: "a", displayName: "A")
                ),
                date: now.addingTimeInterval(-1 * 24 * 60 * 60),
                friendDisplayName: "A",
                friendPhotoURL: nil,
                message: "A is now your dive buddy",
                detail: nil
            )
            let readRecent = HomeNotificationsPresentation.Item(
                id: "read-recent",
                kind: .friendConnected(
                    GoDiveFriendGraphService.friendEdge(friendUID: "b", displayName: "B")
                ),
                date: now.addingTimeInterval(-5 * 24 * 60 * 60),
                friendDisplayName: "B",
                friendPhotoURL: nil,
                message: "B is now your dive buddy",
                detail: nil
            )
            let unreadOlderThanTwoWeeks = HomeNotificationsPresentation.Item(
                id: "unread-old",
                kind: .friendConnected(
                    GoDiveFriendGraphService.friendEdge(friendUID: "c", displayName: "C")
                ),
                date: now.addingTimeInterval(-20 * 24 * 60 * 60),
                friendDisplayName: "C",
                friendPhotoURL: nil,
                message: "C is now your dive buddy",
                detail: nil
            )
            let readOlderThanTwoWeeks = HomeNotificationsPresentation.Item(
                id: "read-old",
                kind: .friendConnected(
                    GoDiveFriendGraphService.friendEdge(friendUID: "d", displayName: "D")
                ),
                date: now.addingTimeInterval(-30 * 24 * 60 * 60),
                friendDisplayName: "D",
                friendPhotoURL: nil,
                message: "D is now your dive buddy",
                detail: nil
            )

            #expect(
                HomeNotificationsPresentation.belongsInNewSection(
                    itemDate: unreadRecent.date,
                    lastSeenAt: seenAt,
                    now: now
                )
            )
            #expect(
                !HomeNotificationsPresentation.belongsInNewSection(
                    itemDate: readRecent.date,
                    lastSeenAt: seenAt,
                    now: now
                )
            )
            #expect(
                !HomeNotificationsPresentation.belongsInNewSection(
                    itemDate: unreadOlderThanTwoWeeks.date,
                    lastSeenAt: seenAt,
                    now: now
                )
            )
            #expect(
                !HomeNotificationsPresentation.belongsInNewSection(
                    itemDate: readOlderThanTwoWeeks.date,
                    lastSeenAt: seenAt,
                    now: now
                )
            )

            let split = HomeNotificationsPresentation.sections(
                items: [
                    unreadRecent,
                    readRecent,
                    unreadOlderThanTwoWeeks,
                    readOlderThanTwoWeeks,
                ],
                lastSeenAt: seenAt,
                now: now
            )
            #expect(split.newItems.map(\.id) == ["unread-recent"])
            #expect(split.older.map(\.id) == ["read-recent", "unread-old", "read-old"])

            #expect(HomeNotificationsPresentation.newSectionTitle == "New")
            #expect(HomeNotificationsPresentation.olderSectionTitle == "Older")
            #expect(HomeNotificationsPresentation.newSectionRecency == 14 * 24 * 60 * 60)
        }

        @Test func homeNotifications_lastSeenStore_roundTrip() {
            let suite = "homeNotificationsLastSeenTests"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let profileID = UUID()

            #expect(HomeNotificationsLastSeenStore.lastSeenAt(ownerProfileID: profileID, userDefaults: defaults) == nil)

            let seenAt = Date(timeIntervalSince1970: 1_700_000_000)
            HomeNotificationsLastSeenStore.markSeen(ownerProfileID: profileID, at: seenAt, userDefaults: defaults)
            #expect(
                HomeNotificationsLastSeenStore.lastSeenAt(ownerProfileID: profileID, userDefaults: defaults) == seenAt
            )
            defaults.removePersistentDomain(forName: suite)
        }

        @Test func homeNotificationsPresentation_includesTripShareInvite() {
            let invite = GoDiveTripShareMapping.InviteSnapshot(
                inviteID: "sharer_trip",
                sharerUID: "sharer",
                tripID: "trip",
                status: .pending,
                title: "Bonaire 2026",
                sharerDisplayName: "Alex",
                createdAt: Date(timeIntervalSince1970: 2_000),
                updatedAt: nil,
                schemaVersion: 1
            )
            let localID = UUID()
            let items = HomeNotificationsPresentation.items(
                friends: [],
                activityRows: [],
                tripShareInvites: [invite],
                localTripIDByInviteID: [invite.inviteID: localID]
            )
            #expect(items.count == 1)
            #expect(items[0].message == HomeNotificationsPresentation.tripShareInviteMessage(displayName: "Alex"))
            #expect(items[0].detail == "Bonaire 2026")
            if case .tripShareInvite(let target) = items[0].kind {
                #expect(target.localTripID == localID)
                #expect(target.inviteID == invite.inviteID)
            } else {
                Issue.record("Expected tripShareInvite kind")
            }
        }

    private static func makeBuddyFeedDive(
        id: String,
        startTime: Date?,
        updatedAt: Date? = nil,
        diveNumber: Int? = nil
    ) -> GoDiveSharedDiveProjectionMapping.FriendVisibleDive {
        GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
            id: id,
            startTime: startTime,
            durationMinutes: 40,
            maxDepthMeters: 18,
            averageDepthMeters: nil,
            diveNumber: diveNumber,
            siteName: "Reef",
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
            bottomTimeSeconds: nil,
            updatedAt: updatedAt
        )
    }

    private func makeNotificationTestDive(
        id: String,
        kind: FriendSharedActivityKind = .scubaDive,
        startTime: Date?,
        updatedAt: Date? = nil,
        sharedAt: Date? = nil,
        siteName: String? = nil,
        taggedBuddies: [GoDiveSharedDiveProjectionMapping.TaggedBuddySnapshot] = []
    ) -> GoDiveSharedDiveProjectionMapping.FriendVisibleDive {
        GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
            id: id,
            activityKind: kind,
            startTime: startTime,
            durationMinutes: nil,
            maxDepthMeters: nil,
            averageDepthMeters: nil,
            diveNumber: nil,
            siteName: siteName,
            locationName: nil,
            entryLatitude: nil,
            entryLongitude: nil,
            notes: nil,
            activityTagNames: [],
            sightings: [],
            taggedBuddies: taggedBuddies,
            equipmentSummary: [],
            mediaPreviews: [],
            profileTrackBase64: nil,
            gasType: nil,
            oxygenMix: nil,
            tankVolumeDescription: nil,
            waterTempMinCelsius: nil,
            bottomTimeSeconds: nil,
            updatedAt: updatedAt,
            sharedAt: sharedAt
        )
    }
}
