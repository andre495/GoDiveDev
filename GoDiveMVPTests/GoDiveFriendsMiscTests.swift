//
//  GoDiveFriendsMiscTests.swift
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


struct GoDiveFriendsMiscTests {
            @Test func appNetworkConnectivityPresentation_friendShareContentUpload_wifiOnlyOnCellular() {
                #expect(
                    AppNetworkConnectivityPresentation.allowsFriendShareContentUpload(
                        isConnected: true,
                        usesWiFi: false,
                        wifiOnly: true
                    ) == false
                )
                #expect(
                    AppNetworkConnectivityPresentation.allowsFriendShareContentUpload(
                        isConnected: true,
                        usesWiFi: true,
                        wifiOnly: true
                    )
                )
                #expect(
                    AppNetworkConnectivityPresentation.allowsFriendShareContentUpload(
                        isConnected: true,
                        usesWiFi: false,
                        wifiOnly: false
                    )
                )
            }
            @Test func sharedActivityLike_pathAndDisplayNameHelpers() {
                #expect(
                    GoDiveSharedActivityLikeSync.likeDocumentPath(
                        ownerUID: "owner",
                        activityID: "act",
                        likerUID: "liker"
                    ) == "users/owner/sharedDives/act/likes/liker"
                )
                #expect(
                    GoDiveSharedActivityLikeSync.rowID(
                        fromLikeDocumentPath: "users/owner/sharedDives/act/likes/liker"
                    ) == "owner_act"
                )
                #expect(
                    GoDiveSharedActivityLikeSync.rowID(fromLikeDocumentPath: "users/owner/sharedDives/act")
                        == nil
                )
                #expect(GoDiveSharedActivityLikeSync.sanitizedLikeDisplayName("  Alex  ") == "Alex")
                #expect(GoDiveSharedActivityLikeSync.sanitizedLikeDisplayName("   ") == "A dive buddy")
                let long = String(repeating: "a", count: 100)
                #expect(GoDiveSharedActivityLikeSync.sanitizedLikeDisplayName(long).count == 80)
            }
            @Test func sharedActivityComment_sanitizeAndParseHelpers() {
                #expect(
                    GoDiveSharedActivityCommentSync.commentsCollectionPath(
                        ownerUID: "owner",
                        activityID: "act"
                    ) == "users/owner/sharedDives/act/comments"
                )
                #expect(GoDiveSharedActivityCommentSync.sanitizedCommentDisplayName("  Alex  ") == "Alex")
                #expect(GoDiveSharedActivityCommentSync.sanitizedCommentDisplayName("   ") == "A dive buddy")
                let longName = String(repeating: "a", count: 100)
                #expect(GoDiveSharedActivityCommentSync.sanitizedCommentDisplayName(longName).count == 80)

                #expect(GoDiveSharedActivityCommentSync.sanitizedCommentText("  Nice dive  ") == "Nice dive")
                #expect(GoDiveSharedActivityCommentSync.sanitizedCommentText("   ") == nil)
                let longText = String(
                    repeating: "b",
                    count: GoDiveSharedActivityCommentSync.maxCommentTextLength + 20
                )
                #expect(
                    GoDiveSharedActivityCommentSync.sanitizedCommentText(longText)?.count
                        == GoDiveSharedActivityCommentSync.maxCommentTextLength
                )

                let parsed = GoDiveSharedActivityCommentSync.parseComment(
                    id: "c1",
                    data: [
                        "authorUid": "author-1",
                        "displayName": "Blake",
                        "text": "Looks great!",
                        "createdAt": Date(timeIntervalSince1970: 1_700_000_000),
                        "mentionedUids": ["uid-a", "author-1", "uid-a", "  uid-b  "],
                    ]
                )
                #expect(parsed?.id == "c1")
                #expect(parsed?.authorUID == "author-1")
                #expect(parsed?.displayName == "Blake")
                #expect(parsed?.text == "Looks great!")
                #expect(parsed?.mentionedUIDs == ["uid-a", "uid-b"])

                #expect(
                    GoDiveSharedActivityCommentSync.parseComment(
                        id: "empty",
                        data: ["authorUid": "a", "displayName": "B", "text": "  "]
                    ) == nil
                )
            }
            @Test func logbookRoute_buddySharedDive_opensCommentsFlagIsPartOfIdentity() {
                let viewOnly = LogbookRoute.buddySharedDive(
                    friendUID: "friend-1",
                    diveDocumentID: "dive-1"
                )
                let withComments = LogbookRoute.buddySharedDive(
                    friendUID: "friend-1",
                    diveDocumentID: "dive-1",
                    opensComments: true
                )
                let withBuddies = LogbookRoute.buddySharedDive(
                    friendUID: "friend-1",
                    diveDocumentID: "dive-1",
                    scrollToTaggedBuddies: true
                )
                #expect(viewOnly != withComments)
                #expect(viewOnly != withBuddies)
                #expect(withComments != withBuddies)
                if case .buddySharedDive(_, _, let opens, let scrollBuddies) = withComments {
                    #expect(opens)
                    #expect(!scrollBuddies)
                } else {
                    Issue.record("Expected buddySharedDive")
                }
                if case .buddySharedDive(_, _, let opens, let scrollBuddies) = viewOnly {
                    #expect(!opens)
                    #expect(!scrollBuddies)
                } else {
                    Issue.record("Expected buddySharedDive")
                }
                if case .buddySharedDive(_, _, let opens, let scrollBuddies) = withBuddies {
                    #expect(!opens)
                    #expect(scrollBuddies)
                } else {
                    Issue.record("Expected buddySharedDive")
                }
            }
            @Test func mentionPresentation_activeInsertExtractAndSanitize() {
                let alex = GoDiveFriendGraphService.friendEdge(
                    friendUID: "uid-alex",
                    displayName: "Alex Smith"
                )
                let sam = GoDiveFriendGraphService.friendEdge(
                    friendUID: "uid-sam",
                    displayName: "Sam"
                )
                let friends = [alex, sam]

                let typing = "Saw @Al"
                let active = GoDiveMentionPresentation.activeMention(
                    in: typing,
                    utf16Caret: (typing as NSString).length,
                    friends: friends
                )
                #expect(active?.query == "Al")
                let matches = GoDiveMentionPresentation.matchingFriends(query: "Al", friends: friends)
                #expect(matches.map(\.friendUID) == ["uid-alex"])

                let inserted = GoDiveMentionPresentation.insertMention(
                    displayName: "Alex Smith",
                    into: typing,
                    active: active!
                )
                #expect(inserted.text == "Saw @Alex Smith ")
                #expect(
                    GoDiveMentionPresentation.activeMention(
                        in: inserted.text,
                        utf16Caret: inserted.caretUTF16,
                        friends: friends
                    ) == nil
                )

                let body = "Dive with @Alex Smith and @Sam today"
                #expect(
                    GoDiveMentionPresentation.mentionedUIDs(in: body, friends: friends)
                        == ["uid-alex", "uid-sam"]
                )
                #expect(
                    GoDiveMentionPresentation.mentionedUIDs(
                        in: body,
                        friends: friends,
                        excludingUID: "uid-sam"
                    ) == ["uid-alex"]
                )
                #expect(
                    GoDiveMentionPresentation.sanitizedMentionedUIDs(
                        [" uid-alex ", "uid-alex", "", "uid-me"],
                        excludingUID: "uid-me"
                    ) == ["uid-alex"]
                )
                #expect(
                    GoDiveNotesMentionTagging.friendUIDsNeedingTag(
                        notes: "Hello @Sam",
                        friends: friends,
                        alreadyTaggedFirebaseUIDs: []
                    ) == ["uid-sam"]
                )
                #expect(
                    GoDiveNotesMentionTagging.friendUIDsNeedingTag(
                        notes: "Hello @Sam",
                        friends: friends,
                        alreadyTaggedFirebaseUIDs: ["uid-sam"]
                    ).isEmpty
                )
                let midAt = "a@b"
                let atIndex = midAt.index(midAt.startIndex, offsetBy: 1)
                #expect(!GoDiveMentionPresentation.isValidMentionStart(midAt, at: atIndex))
                #expect(GoDiveMentionPresentation.isValidMentionStart("@Sam", at: "@Sam".startIndex))
                #expect(
                    GoDiveMentionAttributedTextPresentation.mentionSubstrings(
                        in: "Hi @Alex Smith and @Sam!",
                        knownDisplayNames: ["Alex Smith", "Sam"]
                    ) == ["@Alex Smith", "@Sam"]
                )
                #expect(
                    GoDiveMentionAttributedTextPresentation.displayedMentionNames(
                        in: "Hi @Alex Smith and @Sam!",
                        knownDisplayNames: ["Alex Smith", "Sam"]
                    ) == ["Alex Smith", "Sam"]
                )
                #expect(
                    GoDiveMentionAttributedTextPresentation.displayedMentionNames(
                        in: "solo @Blake token",
                        knownDisplayNames: []
                    ) == ["Blake"]
                )
                // Other devices may lack the mentioned friend in `knownDisplayNames` — still color
                // the full Capitalized multi-word name (not only the first token).
                #expect(
                    GoDiveMentionAttributedTextPresentation.displayedMentionNames(
                        in: "Hi @Alex Smith thanks",
                        knownDisplayNames: []
                    ) == ["Alex Smith"]
                )
                #expect(
                    GoDiveMentionAttributedTextPresentation.displayedMentionNames(
                        in: "Hi @Alex went diving",
                        knownDisplayNames: []
                    ) == ["Alex"]
                )
                #expect(
                    GoDiveMentionAttributedTextPresentation.mentionSubstrings(
                        in: "Ping @Mary-Jane O’Neil!",
                        knownDisplayNames: []
                    ) == ["@Mary-Jane O’Neil"]
                )
                let styled = GoDiveMentionAttributedTextPresentation.attributedString(
                    text: "Hi @Sam",
                    knownDisplayNames: ["Sam"],
                    baseForeground: .primary,
                    mentionForeground: .blue
                )
                #expect(String(styled.characters) == "Hi Sam")
            }
            @Test func friendsPresentation_friendCountLabel() {
                #expect(GoDiveFriendsPresentation.friendCountLabel(0) == "0 friends")
                #expect(GoDiveFriendsPresentation.friendCountLabel(1) == "1 friend")
                #expect(GoDiveFriendsPresentation.friendCountLabel(2) == "2 friends")
            }
            @Test @MainActor func profileHeroFeaturedMediaSync_skipsNonSelfBuddy() {
                let container = try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "test-self-buddy-gate", displayName: "Dre")
                context.insert(owner)
                let otherBuddy = DiveBuddy(displayName: "Sam", owner: owner)
                context.insert(otherBuddy)
                try? context.save()

                GoDiveProfileHeroFirestoreSync.resetSessionSyncStateForTesting()
                GoDiveProfileHeroFeaturedMediaSync.scheduleSyncForSelfBuddyHeader(
                    buddy: otherBuddy,
                    owner: owner,
                    sessionRandomHeroMediaID: nil,
                    modelContext: context
                )
                #expect(!DiveBuddySelfRepresentation.isSelfBuddy(otherBuddy, owner: owner))
            }
            @Test @MainActor func friendBuddyLinking_fuzzyMatchesExistingRosterBuddy() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "friend-link-owner", displayName: "Diver")
                context.insert(owner)

                let existing = DiveBuddy(displayName: "Pat", owner: owner)
                context.insert(existing)
                try context.save()

                let linked = GoDiveFriendBuddyLinking.upsertRosterBuddy(
                    friendUID: "firebase-pat",
                    displayName: "Pat Lee",
                    photoURL: "https://example.com/pat.jpg",
                    owner: owner,
                    modelContext: context
                )

                let buddies = try context.fetch(FetchDescriptor<DiveBuddy>())
                #expect(buddies.count == 1)
                #expect(linked?.id == existing.id)
                #expect(existing.linkedFirebaseUID == "firebase-pat")
            }
            @Test @MainActor func friendBuddyLinking_doesNotReplaceRealNameWithPlaceholder() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "friend-placeholder-owner", displayName: "Susu Dugas")
                context.insert(owner)

                let existing = DiveBuddy(displayName: "Andre Dugas", owner: owner)
                existing.linkedFirebaseUID = "firebase-andre"
                context.insert(existing)
                try context.save()

                let linked = GoDiveFriendBuddyLinking.upsertRosterBuddy(
                    friendUID: "firebase-andre",
                    displayName: UserProfileStore.defaultDisplayName,
                    photoURL: nil,
                    owner: owner,
                    modelContext: context
                )

                #expect(linked?.id == existing.id)
                #expect(existing.displayName == "Andre Dugas")
            }
            @Test @MainActor func friendBuddyLinking_mergesDuplicateNameRows() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "friend-merge-owner", displayName: "Diver")
                context.insert(owner)

                let canonical = DiveBuddy(displayName: "Jordan Kim", owner: owner)
                let duplicate = DiveBuddy(displayName: "Jordan", owner: owner)
                context.insert(canonical)
                context.insert(duplicate)

                let activity = DiveActivity(
                    source: .manual,
                    startTime: .now,
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                context.insert(activity)
                _ = DiveBuddyActivityAssociation.tagBuddy(duplicate, on: activity, modelContext: context)
                try context.save()

                _ = GoDiveFriendBuddyLinking.upsertRosterBuddy(
                    friendUID: "firebase-jordan",
                    displayName: "Jordan Kim",
                    photoURL: nil,
                    owner: owner,
                    modelContext: context
                )

                let buddies = try context.fetch(FetchDescriptor<DiveBuddy>())
                #expect(buddies.count == 1)
                #expect(buddies[0].linkedFirebaseUID == "firebase-jordan")
                #expect(DiveBuddyActivityAssociation.isBuddyTagged(buddyID: buddies[0].id, on: activity))
            }
            @Test func diveBuddyFriendLinkPresentation_friendEdgeWhenLinked() {
                let buddy = DiveBuddy(displayName: "Sam")
                buddy.linkedFirebaseUID = "uid-sam"
                buddy.linkedPhotoURL = "https://example.com/sam.jpg"
                let edge = DiveBuddyFriendLinkPresentation.friendEdge(for: buddy)
                #expect(edge?.friendUID == "uid-sam")
                #expect(edge?.displayName == "Sam")
                #expect(edge?.photoURL == "https://example.com/sam.jpg")
                #expect(DiveBuddyFriendLinkPresentation.friendEdge(for: DiveBuddy(displayName: "No Link")) == nil)
            }
            @Test func friendBuddyAutoLink_resolvedFriendEdge_requiresUniqueTopScore() {
                let friends = [
                    GoDiveFriendGraphService.friendEdge(friendUID: "a", displayName: "Pat Lee"),
                    GoDiveFriendGraphService.friendEdge(friendUID: "b", displayName: "Pat Smith"),
                ]
                #expect(
                    GoDiveFriendBuddyLinking.resolvedFriendEdge(
                        buddyDisplayName: "Pat",
                        friends: friends,
                        reservedFriendUIDs: []
                    ) == nil
                )
                let patLee = GoDiveFriendGraphService.friendEdge(friendUID: "a", displayName: "Pat Lee")
                #expect(
                    GoDiveFriendBuddyLinking.resolvedFriendEdge(
                        buddyDisplayName: "Pat Lee",
                        friends: [patLee],
                        reservedFriendUIDs: []
                    )?.friendUID == "a"
                )
                #expect(
                    GoDiveFriendBuddyLinking.resolvedFriendEdge(
                        buddyDisplayName: "Pat Lee",
                        friends: [patLee],
                        reservedFriendUIDs: ["a"]
                    ) == nil
                )
            }
            @Test @MainActor func friendBuddyAutoLink_linksBuddyAfterDiveTag() async throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "friend-tag-owner", displayName: "Diver")
                context.insert(owner)

                GoDiveFriendBuddyLinking.seedCachedFriendEdgesForTesting([
                    GoDiveFriendGraphService.friendEdge(friendUID: "firebase-alex", displayName: "Alex Rivera"),
                ])

                let rosterBuddy = DiveBuddy(displayName: "Alex", owner: owner)
                context.insert(rosterBuddy)
                let activity = DiveActivity(
                    source: .manual,
                    startTime: .now,
                    durationMinutes: 40,
                    maxDepthMeters: 15
                )
                context.insert(activity)
                _ = DiveBuddyActivityAssociation.tagBuddy(rosterBuddy, on: activity, modelContext: context)
                try context.save()

                await GoDiveFriendBuddyLinking.autoLinkUnlinkedBuddies(
                    owner: owner,
                    modelContext: context,
                    buddyIDs: [rosterBuddy.id]
                )

                #expect(rosterBuddy.linkedFirebaseUID == "firebase-alex")
            }
            @Test @MainActor func buddiesListFriendShareRepublishGate_throttlesListOpenSlots() {
                BuddiesListFriendShareRepublishGate.resetForTesting()
                defer { BuddiesListFriendShareRepublishGate.resetForTesting() }

                let t0 = Date(timeIntervalSince1970: 1_700_000_000)
                #expect(
                    BuddiesListFriendShareRepublishGate.consumeListOpenRepublishSlot(
                        now: t0,
                        minimumInterval: 60
                    )
                )
                #expect(
                    !BuddiesListFriendShareRepublishGate.consumeListOpenRepublishSlot(
                        now: t0.addingTimeInterval(30),
                        minimumInterval: 60
                    )
                )
                #expect(
                    BuddiesListFriendShareRepublishGate.consumeListOpenRepublishSlot(
                        now: t0.addingTimeInterval(60),
                        minimumInterval: 60
                    )
                )
                #expect(BuddiesListPresentation.listOpenRepublishMinimumInterval == 60)
            }
            @Test func friendBuddyLinking_rosterLinksAlreadyCurrent_matchesLinkedMetadata() {
                let friends = [
                    GoDiveFriendGraphService.friendEdge(
                        friendUID: "uid-a",
                        displayName: "Alex",
                        photoURL: "https://example.com/a.jpg"
                    )
                ]
                #expect(
                    GoDiveFriendBuddyLinking.rosterLinksAlreadyCurrent(
                        friends: friends,
                        linkedBuddies: [("uid-a", "Alex", "https://example.com/a.jpg")]
                    )
                )
                #expect(
                    !GoDiveFriendBuddyLinking.rosterLinksAlreadyCurrent(
                        friends: friends,
                        linkedBuddies: [("uid-a", "Alex", nil)]
                    )
                )
                #expect(
                    !GoDiveFriendBuddyLinking.rosterLinksAlreadyCurrent(
                        friends: friends,
                        linkedBuddies: []
                    )
                )
                let fingerprint = GoDiveFriendBuddyLinking.friendsRosterSyncFingerprint(friends)
                #expect(fingerprint.contains("uid-a"))
                #expect(fingerprint.contains("Alex"))
            }
            @Test @MainActor func friendBuddyLinking_syncRosterLinks_skipsNoOpSecondPass() throws {
                GoDiveFriendBuddyLinking.resetSessionSyncStateForTesting()
                defer { GoDiveFriendBuddyLinking.resetSessionSyncStateForTesting() }

                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "link-noop-owner", displayName: "Diver")
                context.insert(owner)

                let friends = [
                    GoDiveFriendGraphService.friendEdge(
                        friendUID: "uid-noop",
                        displayName: "Casey",
                        photoURL: nil
                    )
                ]
                GoDiveFriendBuddyLinking.syncRosterLinks(
                    friends: friends,
                    owner: owner,
                    modelContext: context
                )
                let afterFirst = try context.fetch(FetchDescriptor<DiveBuddy>())
                #expect(afterFirst.count == 1)
                #expect(afterFirst[0].linkedFirebaseUID == "uid-noop")

                GoDiveFriendBuddyLinking.syncRosterLinks(
                    friends: friends,
                    owner: owner,
                    modelContext: context
                )
                let afterSecond = try context.fetch(FetchDescriptor<DiveBuddy>())
                #expect(afterSecond.count == 1)
                #expect(afterSecond[0].id == afterFirst[0].id)
            }
            @Test func firestoreUserProfileMapping_parsesTotalDiveCount() {
                #expect(
                    GoDiveFirestoreUserProfileMapping.totalDiveCount(from: ["totalDiveCount": 8]) == 8
                )
                #expect(
                    GoDiveFirestoreUserProfileMapping.totalDiveCount(from: ["totalDiveCount": Int64(3)]) == 3
                )
                #expect(GoDiveFirestoreUserProfileMapping.totalDiveCount(from: [:]) == nil)
            }
            @Test @MainActor func buddiesListRow_navigationRoute_prefersFriendOverRosterBuddy() {
                let owner = UserProfile(appleUserIdentifier: "route-owner", displayName: "Diver")
                let buddy = DiveBuddy(displayName: "Alex", owner: owner)
                let edge = GoDiveFriendGraphService.friendEdge(
                    friendUID: "uid-alex",
                    friendshipID: "ship-alex",
                    displayName: "Alex Rivera"
                )
                let linkedRow = BuddiesListRow(
                    id: "buddy-\(buddy.id.uuidString)",
                    displayName: buddy.displayName,
                    buddy: buddy,
                    friendEdge: edge,
                    sharedDiveCount: 2,
                    friendTotalDiveCount: 10
                )
                #expect(linkedRow.navigationRoute == .friend(edge))

                let rosterRow = BuddiesListRow(
                    id: "buddy-\(buddy.id.uuidString)",
                    displayName: buddy.displayName,
                    buddy: buddy,
                    friendEdge: nil,
                    sharedDiveCount: 2,
                    friendTotalDiveCount: nil
                )
                if case .rosterBuddy(let id) = rosterRow.navigationRoute {
                    #expect(id == buddy.id)
                } else {
                    Issue.record("Expected roster buddy route")
                }
            }
            @Test func diveBuddyContactSMSPresentation_emptyRecipientsWithoutContact() {
                #expect(DiveBuddyContactSMSPresentation.smsRecipients(contactsIdentifier: nil).isEmpty)
            }
            @Test func diveBuddyInviteSMSPresentation_avatarBadgeMatchesProfileCameraScale() {
                #expect(
                    DiveBuddyInviteSMSPresentation.detailAccessibilityIdentifier == "DiveBuddyDetails.Invite"
                )
                #expect(DiveBuddyInviteSMSPresentation.plusSystemImage == "plus")
                #expect(
                    DiveBuddyInviteSMSPresentation.avatarPlusBadgeSideLength(avatarDiameter: 120)
                        == max(32, 120 * 0.27)
                )
                #expect(
                    DiveBuddyInviteSMSPresentation.avatarPlusBadgeSideLength(avatarDiameter: 80) == 32
                )
            }
            @Test @MainActor
            func diveBuddyInviteSMSPresentation_failsClosedWhenOffline() async {
                let outcome = await DiveBuddyInviteSMSPresentation.presentInviteSMS(
                    buddyDisplayName: "Jamie",
                    contactsIdentifier: nil,
                    isNetworkConnected: false
                )
                #expect(outcome == .failed(message: GoDiveFriendsPresentation.firebaseUnavailableMessage))
            }
            @Test func diveActivityMapOverviewHeaderPresentation_usesBuddyOwnerLayout_whenNamePresent() {
                #expect(
                    DiveActivityMapOverviewHeaderPresentation.usesBuddyOwnerLayout(
                        sharedByDisplayName: "Alex"
                    )
                )
                #expect(
                    !DiveActivityMapOverviewHeaderPresentation.usesBuddyOwnerLayout(
                        sharedByDisplayName: "   "
                    )
                )
                #expect(
                    !DiveActivityMapOverviewHeaderPresentation.usesBuddyOwnerLayout(
                        sharedByDisplayName: nil
                    )
                )
                #expect(
                    DiveActivityMapOverviewHeaderPresentation.showsOpenFriendProfileControl(
                        onOpenSharedBy: {}
                    )
                )
                #expect(
                    !DiveActivityMapOverviewHeaderPresentation.showsOpenFriendProfileControl(
                        onOpenSharedBy: nil
                    )
                )
                let edge = FriendSharedActivityDetailPresentation.friendEdgeForProfileNavigation(
                    friendUID: "uid-alex",
                    displayName: "Alex",
                    photoURL: "https://example.com/a.jpg"
                )
                #expect(edge?.friendUID == "uid-alex")
                #expect(edge?.displayName == "Alex")
                #expect(
                    FriendSharedActivityDetailPresentation.friendEdgeForProfileNavigation(
                        friendUID: "  ",
                        displayName: "Alex",
                        photoURL: nil
                    ) == nil
                )
            }
            @Test func ownedActivityMapSocial_showsOnlyWhenPublishedAndSignedIn() {
                #expect(
                    OwnedActivityMapSocialPresentation.shouldShowSocial(
                        isPublishedWithFriends: true,
                        firebaseUID: "uid-1"
                    )
                )
                #expect(
                    !OwnedActivityMapSocialPresentation.shouldShowSocial(
                        isPublishedWithFriends: false,
                        firebaseUID: "uid-1"
                    )
                )
                #expect(
                    !OwnedActivityMapSocialPresentation.shouldShowSocial(
                        isPublishedWithFriends: true,
                        firebaseUID: nil
                    )
                )
                #expect(
                    !OwnedActivityMapSocialPresentation.shouldShowSocial(
                        isPublishedWithFriends: true,
                        firebaseUID: "   "
                    )
                )
                #expect(!OwnedActivityMapSocialPresentation.allowsOwnerLiking)
            }
            @Test @MainActor func ownedActivityCommentsDeepLink_consumesMatchingActivityOnce() {
                let activityID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
                let otherID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
                let store = GoDiveOwnedActivityCommentsDeepLinkStore.shared
                store.clear()
                store.setPending(activityID: activityID)
                #expect(!store.consume(activityID: otherID))
                #expect(store.consume(activityID: activityID))
                #expect(!store.consume(activityID: activityID))
                #expect(GoDiveOwnedActivityCommentsDeepLinkPresentation.opensCommentsFromCommentPush)
            }
            @Test func rootPushDeepLinkFlush_requiresShellAndHomeChrome() {
                #expect(
                    !GoDiveRootPushDeepLinkFlushPresentation.canOpenPendingRoutes(
                        showsMainAppShell: false,
                        isHomeLaunchChromeReady: false
                    )
                )
                #expect(
                    !GoDiveRootPushDeepLinkFlushPresentation.canOpenPendingRoutes(
                        showsMainAppShell: true,
                        isHomeLaunchChromeReady: false
                    )
                )
                #expect(
                    !GoDiveRootPushDeepLinkFlushPresentation.canOpenPendingRoutes(
                        showsMainAppShell: false,
                        isHomeLaunchChromeReady: true
                    )
                )
                #expect(
                    GoDiveRootPushDeepLinkFlushPresentation.canOpenPendingRoutes(
                        showsMainAppShell: true,
                        isHomeLaunchChromeReady: true
                    )
                )
            }
            @Test @MainActor func ownedActivityPushTap_likeClearsComments_commentSetsComments() {
                let activityID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
                let comments = GoDiveOwnedActivityCommentsDeepLinkStore.shared
                let likedNav = GoDiveBuddyActivityLikedPushNavigationStore.shared
                comments.clear()
                likedNav.clear()

                // Stale comment deep link must not survive a like tap.
                comments.setPending(activityID: activityID)
                let likeInfo: [AnyHashable: Any] = [
                    "type": "buddy_activity_liked",
                    "friendUID": "liker-1",
                    "activityID": activityID.uuidString,
                    "activityKind": "scubaDive",
                ]
                GoDiveFirebaseCloudMessaging.handleNotificationResponse(userInfo: likeInfo)
                #expect(!comments.consume(activityID: activityID))
                let parsedLikeTarget = GoDiveBuddyActivityLikedPushPresentation.target(fromUserInfo: likeInfo)
                #expect(parsedLikeTarget?.activityID == activityID)
                #expect(
                    GoDiveBuddyActivityLikedPushPresentation.logbookRoute(for: parsedLikeTarget!)
                        == .diveDetail(activityID)
                )

                let commentInfo: [AnyHashable: Any] = [
                    "type": "buddy_activity_commented",
                    "friendUID": "author-1",
                    "activityID": activityID.uuidString,
                    "activityKind": "snorkel",
                ]
                GoDiveFirebaseCloudMessaging.handleNotificationResponse(userInfo: commentInfo)
                #expect(comments.consume(activityID: activityID))
                let parsedCommentTarget = GoDiveBuddyActivityCommentedPushPresentation.target(
                    fromUserInfo: commentInfo
                )
                let commentNavTarget = GoDiveBuddyActivityCommentedPushPresentation.likedPushCompatibleTarget(
                    for: parsedCommentTarget!
                )
                #expect(commentNavTarget.activityID == activityID)
                #expect(commentNavTarget.activityKind == .snorkel)
                #expect(
                    GoDiveBuddyActivityLikedPushPresentation.logbookRoute(for: commentNavTarget)
                        == .snorkelDetail(activityID)
                )

                comments.clear()
                likedNav.clear()
            }
            @Test func goDiveRemoteAvatarPresentation_buddyFeedPrefetch_dedupesSameFriend() {
                let photo = "https://firebasestorage.googleapis.com/v0/b/t/o/avatar.jpg?alt=media"
                let diveA = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                    id: "a",
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12,
                    averageDepthMeters: nil,
                    diveNumber: 1,
                    siteName: "A",
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
                var diveB = diveA
                diveB.id = "b"
                let rows: [LogbookBuddyFeedPresentation.Row] = [
                    .init(
                        id: "f_a",
                        friendUID: "friend",
                        friendDisplayName: "Pat",
                        friendPhotoURL: photo,
                        dive: diveA
                    ),
                    .init(
                        id: "f_b",
                        friendUID: "friend",
                        friendDisplayName: "Pat",
                        friendPhotoURL: photo,
                        dive: diveB
                    ),
                ]
                let urls = GoDiveRemoteAvatarPresentation.buddyFeedAvatarPrefetchURLs(
                    rows: rows,
                    startIndex: 0,
                    count: 12
                )
                #expect(urls == [photo])
                #expect(GoDiveRemoteAvatarPresentation.cacheKey(for: photo) == photo)
                #expect(GoDiveRemoteAvatarPresentation.cacheKey(for: "https://example.com/x.jpg") == nil)
            }
            @Test @MainActor func goDiveRemoteAvatarImageCache_memoryHitAfterDiskLoad() async throws {
                let root = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                GoDiveSharedMediaCache.testingRootDirectory = root
                GoDiveRemoteAvatarImageCache.shared.removeAllForTesting()
                defer {
                    GoDiveSharedMediaCache.testingRootDirectory = nil
                    GoDiveRemoteAvatarImageCache.shared.removeAllForTesting()
                    try? FileManager.default.removeItem(at: root)
                }

                let url = "https://firebasestorage.googleapis.com/v0/b/t/o/avatar-\(UUID().uuidString).jpg?alt=media"
                // Minimal valid 1×1 PNG
                let png = Data(
                    base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO5X1kUAAAAASUVORK5CYII="
                )!
                _ = try await GoDiveSharedMediaCache.shared.storeForTesting(
                    data: png,
                    remoteURLString: url,
                    tier: .thumb
                )

                let first = await GoDiveRemoteAvatarImageCache.shared.image(
                    for: url,
                    allowsNetworkFetch: false
                )
                #expect(first != nil)
                #expect(GoDiveRemoteAvatarImageCache.shared.cachedImage(for: url) != nil)
                let second = await GoDiveRemoteAvatarImageCache.shared.image(
                    for: url,
                    allowsNetworkFetch: false
                )
                #expect(second === first)
            }
            @Test func appNetworkConnectivityPresentation_friendSharedMediaContentDownload_mirrorsSelectionPolicy() {
                #expect(
                    AppNetworkConnectivityPresentation.allowsFriendSharedMediaContentDownload(
                        isConnected: true,
                        usesWiFi: false,
                        wifiOnly: true,
                        allowsConstrainedNetworkAccess: true
                    ) == false
                )
                #expect(
                    AppNetworkConnectivityPresentation.allowsFriendSharedMediaContentDownload(
                        isConnected: true,
                        usesWiFi: true,
                        wifiOnly: true,
                        allowsConstrainedNetworkAccess: true
                    )
                )
            }
            @Test func diveBuddyAvatarChip_sourcesPreferLocalThenLinkedURLThenLookup() {
                let jpeg = Data([0xFF, 0xD8, 0xFF, 0x01])
                let linkedURL = "https://firebasestorage.googleapis.com/v0/b/t/o/linked.jpg?alt=media"
                let graphURL = "https://firebasestorage.googleapis.com/v0/b/t/o/graph.jpg?alt=media"
                let lookup = BuddyFeedAvatarLookup.make(
                    currentFirebaseUID: "uid-me",
                    currentLocalProfilePhoto: nil,
                    friends: [
                        GoDiveFriendGraphService.friendEdge(
                            friendUID: "uid-graph",
                            displayName: "Graph",
                            photoURL: graphURL
                        ),
                    ]
                )

                let localFirst = DiveBuddyAvatarChipPresentation.sources(
                    profilePhoto: jpeg,
                    linkedPhotoURL: linkedURL,
                    firebaseUID: "uid-graph",
                    lookup: lookup
                )
                #expect(localFirst.localProfilePhoto == jpeg)
                #expect(localFirst.photoURL == nil)

                let linkedFallback = DiveBuddyAvatarChipPresentation.sources(
                    profilePhoto: nil,
                    linkedPhotoURL: linkedURL,
                    firebaseUID: "uid-graph",
                    lookup: lookup
                )
                #expect(linkedFallback.localProfilePhoto == nil)
                #expect(linkedFallback.photoURL == linkedURL)

                let graphFallback = DiveBuddyAvatarChipPresentation.sources(
                    profilePhoto: nil,
                    linkedPhotoURL: nil,
                    firebaseUID: "uid-graph",
                    lookup: lookup
                )
                #expect(graphFallback.photoURL == graphURL)
            }
            @Test @MainActor func activityFriendShareConfiguration_inheritsGlobalDefaultsUntilConfigured() {
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 45,
                    maxDepthMeters: 18
                )
                #expect(!ActivityFriendShareConfiguration.usesPerActivitySettings(on: dive))
                #expect(ActivityFriendShareConfiguration.shareActivityEnabled(on: dive))
                #expect(!ActivityFriendShareConfiguration.restrictsMediaToExplicitSelection(on: dive))
            }
            @Test func activityFriendShareConfiguration_encodesSelectedMediaIDs() {
                let id1 = UUID()
                let id2 = UUID()
                let encoded = ActivityFriendShareConfiguration.encodeMediaIDs([id1, id2])
                let decoded = ActivityFriendShareConfiguration.decodeMediaIDs(from: encoded)
                #expect(decoded == [id1, id2])
            }
            @Test func activityFriendShareNotesMode_sharePrivateNotesToggle_mapsOnOffAndLegacyPublic() {
                #expect(!ActivityFriendShareNotesMode.off.sharePrivateNotesToggleIsOn)
                #expect(ActivityFriendShareNotesMode.privateNotes.sharePrivateNotesToggleIsOn)
                #expect(ActivityFriendShareNotesMode.publicNotes.sharePrivateNotesToggleIsOn)
                #expect(ActivityFriendShareNotesMode.fromSharePrivateNotesToggle(true) == .privateNotes)
                #expect(ActivityFriendShareNotesMode.fromSharePrivateNotesToggle(false) == .off)
                #expect(
                    ActivityFriendSharePresentation.shareNotesTitle == "Share private notes with buddies"
                )
                #expect(ActivityFriendSharePresentation.statusNotesRowTitle == "Private Notes")
            }
            @Test @MainActor func activityFriendShareConfiguration_shareOptions_publicNotes() {
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                dive.friendShareBuddySettingsConfigured = true
                dive.friendShareActivityEnabled = true
                dive.friendShareNotesModeRaw = ActivityFriendShareNotesMode.publicNotes.rawValue
                dive.friendSharePublicNotes = "Saw a turtle!"
                let options = ActivityFriendShareConfiguration.shareOptions(for: dive)
                #expect(options.includeNotes)
                #expect(options.notesText == "Saw a turtle!")
            }
            @Test @MainActor func activityFriendShareConfiguration_shouldPublish_falseWhenActivityShareOff() {
                let suiteName = "GoDiveFriendsTests.activityFriendShareShouldPublish.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                dive.friendShareBuddySettingsConfigured = true
                dive.friendShareActivityEnabled = false
                #expect(!ActivityFriendShareConfiguration.shouldPublish(dive: dive, userDefaults: defaults))
            }

            @Test @MainActor func activityFriendShareConfiguration_shouldPublish_trueWhenSeededWithGlobalOn() {
                let suiteName = "GoDiveFriendsTests.activityFriendShareShouldPublishSeed.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                ActivityFriendShareConfiguration.seedBuddyShareDefaultsOnNewActivity(dive, userDefaults: defaults)
                #expect(ActivityFriendShareConfiguration.shouldPublish(dive: dive, userDefaults: defaults))
            }
            @Test @MainActor func activityFriendShareConfiguration_configuredOverridesGlobalMediaAndNotes() {
                let suiteName = "GoDiveFriendsTests.activityFriendShareOverrides.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)
                defaults.set(false, forKey: AppUserSettings.shareMediaWithFriendsKey)
                defaults.set(false, forKey: AppUserSettings.shareNotesWithFriendsKey)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                ActivityFriendShareConfiguration.applyConfiguredSettings(
                    to: dive,
                    shareActivityEnabled: true,
                    shareMediaEnabled: true,
                    selectedMediaIDs: [UUID()],
                    notesMode: .publicNotes,
                    publicNotes: "Hello buddies"
                )

                #expect(ActivityFriendShareConfiguration.shareMediaEnabled(on: dive, userDefaults: defaults))
                #expect(ActivityFriendShareConfiguration.notesMode(on: dive, userDefaults: defaults) == .publicNotes)
                let options = ActivityFriendShareConfiguration.shareOptions(for: dive, userDefaults: defaults)
                #expect(options.includeMedia)
                #expect(options.includeNotes)
                #expect(options.notesText == "Hello buddies")
            }
            @Test @MainActor func activityFriendShareConfiguration_unconfiguredFollowsGlobalUntilCaptured() {
                let suiteName = "GoDiveFriendsTests.activityFriendShareGlobals.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)
                defaults.set(true, forKey: AppUserSettings.shareMediaWithFriendsKey)
                defaults.set(true, forKey: AppUserSettings.shareNotesWithFriendsKey)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                #expect(!ActivityFriendShareConfiguration.usesPerActivitySettings(on: dive))
                #expect(!dive.friendShareBuddyDefaultsCaptured)
                #expect(ActivityFriendShareConfiguration.shareMediaEnabled(on: dive, userDefaults: defaults))
                #expect(ActivityFriendShareConfiguration.notesMode(on: dive, userDefaults: defaults) == .privateNotes)

                ActivityFriendShareConfiguration.captureGlobalBuddyShareDefaultsIfNeeded(on: dive, userDefaults: defaults)
                #expect(dive.friendShareBuddyDefaultsCaptured)
                #expect(dive.friendShareMediaEnabled)

                defaults.set(false, forKey: AppUserSettings.shareMediaWithFriendsKey)
                defaults.set(false, forKey: AppUserSettings.shareNotesWithFriendsKey)
                #expect(ActivityFriendShareConfiguration.shareMediaEnabled(on: dive, userDefaults: defaults))
                #expect(ActivityFriendShareConfiguration.notesMode(on: dive, userDefaults: defaults) == .privateNotes)
            }
            @Test func activityFriendShareConfiguration_seedBuddyShareDefaultsOnNewActivity() {
                let suiteName = "GoDiveFriendsTests.activityFriendShareSeed.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)
                defaults.set(true, forKey: AppUserSettings.shareMediaWithFriendsKey)
                defaults.set(false, forKey: AppUserSettings.shareNotesWithFriendsKey)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                ActivityFriendShareConfiguration.seedBuddyShareDefaultsOnNewActivity(dive, userDefaults: defaults)
                #expect(dive.friendShareBuddyDefaultsCaptured)
                #expect(dive.friendShareActivityEnabled)
                #expect(!dive.friendSharePublishCheckpointPending)
                #expect(dive.friendShareMediaEnabled)
                #expect(dive.friendShareNotesModeRaw == ActivityFriendShareNotesMode.off.rawValue)
                #expect(!dive.friendShareBuddySettingsConfigured)
            }

            @Test func activityFriendShareConfiguration_seedNewActivityFollowsGlobalShareOff() {
                let suiteName = "GoDiveFriendsTests.activityFriendShareSeedOff.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                defaults.set(false, forKey: AppUserSettings.shareDivesWithFriendsKey)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                ActivityFriendShareConfiguration.seedBuddyShareDefaultsOnNewActivity(dive, userDefaults: defaults)
                #expect(dive.friendShareBuddyDefaultsCaptured)
                #expect(!dive.friendShareActivityEnabled)
                #expect(!dive.friendSharePublishCheckpointPending)
            }

            @Test func activityFriendShareConfiguration_seedDoesNotOverwriteCapturedOff() {
                let suiteName = "GoDiveFriendsTests.activityFriendShareSeedKeepOff.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                dive.friendShareBuddyDefaultsCaptured = true
                dive.friendShareActivityEnabled = false
                ActivityFriendShareConfiguration.seedBuddyShareDefaultsOnNewActivity(dive, userDefaults: defaults)
                #expect(!dive.friendShareActivityEnabled)
                #expect(dive.friendShareBuddyDefaultsCaptured)
            }
            @Test func activityPublishCheckpointBanner_promptCopy() {
                #expect(
                    ActivityPublishCheckpointBannerPresentation.promptTitle == "Share with Buddies?"
                )
                #expect(
                    ActivityPublishCheckpointBannerPresentation.promptSubtitlePrefix
                        == "You can change the sharing setting anytime from"
                )
                #expect(
                    ActivityPublishCheckpointBannerPresentation.menuEllipsisSystemImage == "ellipsis"
                )
                #expect(
                    ActivityPublishCheckpointBannerPresentation.verticalPadding == 7
                )
            }
            @Test func activityPublishCheckpointBanner_exitDirectionsAreOpposites() {
                #expect(
                    ActivityPublishCheckpointBannerPresentation.removalEdge(for: .down) == .bottom
                )
                #expect(
                    ActivityPublishCheckpointBannerPresentation.removalEdge(for: .up) == .top
                )
            }
            @Test func goDiveBuddySharePendingWorkStore_roundTrip() {
                let profileID = UUID()
                let id1 = UUID()
                let id2 = UUID()
                defer {
                    GoDiveBuddySharePendingWorkStore.clearPendingUpserts(
                        ownerProfileID: profileID,
                        activityIDs: [id1, id2]
                    )
                    GoDiveBuddySharePendingWorkStore.clearFullRepublishPending(ownerProfileID: profileID)
                }

                GoDiveBuddySharePendingWorkStore.addPendingUpserts(
                    ownerProfileID: profileID,
                    activityIDs: [id1]
                )
                GoDiveBuddySharePendingWorkStore.addPendingUpserts(
                    ownerProfileID: profileID,
                    activityIDs: [id2]
                )
                #expect(
                    GoDiveBuddySharePendingWorkStore.pendingUpsertActivityIDs(ownerProfileID: profileID)
                        == [id1, id2]
                )

                GoDiveBuddySharePendingWorkStore.markFullRepublishPending(ownerProfileID: profileID)
                #expect(GoDiveBuddySharePendingWorkStore.isFullRepublishPending(ownerProfileID: profileID))

                GoDiveBuddySharePendingWorkStore.clearPendingUpserts(
                    ownerProfileID: profileID,
                    activityIDs: [id1]
                )
                #expect(
                    GoDiveBuddySharePendingWorkStore.pendingUpsertActivityIDs(ownerProfileID: profileID)
                        == [id2]
                )
            }
            @Test func goDiveBuddyShareBackgroundUploadPresentation_taskPolicy() {
                #expect(
                    GoDiveBuddyShareBackgroundUploadPresentation.permittedTaskIdentifiers == [
                        "PrimoSoftware.GoDiveMVP.buddy-share-upload",
                    ]
                )
                #expect(GoDiveBuddyShareBackgroundUploadPresentation.processingRequiresNetworkConnectivity())
                #expect(!GoDiveBuddyShareBackgroundUploadPresentation.processingRequiresExternalPower())
                #expect(GoDiveBuddyShareBackgroundUpload.processingEarliestInterval == 5 * 60)
            }
            @Test func tripSharePushPresentation_parsesUserInfo() {
                let target = GoDiveTripSharePushPresentation.target(
                    fromUserInfo: [
                        "type": GoDiveTripSharePushPresentation.notificationType,
                        "inviteId": "sharer_trip",
                        "sharerUid": "sharer",
                        "tripId": "trip",
                        "title": "Bonaire",
                    ]
                )
                #expect(target?.inviteID == "sharer_trip")
                #expect(target?.sharerUID == "sharer")
                #expect(target?.tripID == "trip")
                #expect(target?.title == "Bonaire")
                #expect(
                    GoDiveTripSharePushPresentation.target(fromUserInfo: ["type": "other"]) == nil
                )
            }
            @Test func tripShareInviteAcceptedPushPresentation_parsesUserInfoAndTrigger() {
                let tripID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
                let target = GoDiveTripShareInviteAcceptedPushPresentation.target(
                    fromUserInfo: [
                        "type": GoDiveTripShareInviteAcceptedPushPresentation.notificationType,
                        "inviteId": "sharer_trip",
                        "tripId": tripID.uuidString,
                        "friendUID": "recipient",
                        "title": "Bonaire",
                    ]
                )
                #expect(target?.tripID == tripID)
                #expect(target?.friendUID == "recipient")
                #expect(target?.title == "Bonaire")
                #expect(
                    GoDiveTripShareInviteAcceptedPushPresentation.notificationBody(
                        friendDisplayName: "Alex",
                        tripTitle: "Bonaire"
                    ) == "Alex joined Bonaire!"
                )
                #expect(
                    GoDiveTripShareInviteAcceptedPushTrigger.shouldNotify(
                        beforeStatus: "pending",
                        afterStatus: "accepted"
                    )
                )
                #expect(
                    !GoDiveTripShareInviteAcceptedPushTrigger.shouldNotify(
                        beforeStatus: "accepted",
                        afterStatus: "accepted"
                    )
                )
                #expect(
                    !GoDiveTripShareInviteAcceptedPushTrigger.shouldNotify(
                        beforeStatus: "pending",
                        afterStatus: "declined"
                    )
                )
            }
            @Test func diveTripShareLineage_recordAcceptedFriend() {
                let trip = DiveTrip(startDate: .now, endDate: .now, title: "Shared")
                DiveTripShareLineagePresentation.recordAcceptedFriend(trip, friendUID: "friend-a")
                #expect(DiveTripShareLineagePresentation.hasAcceptedFriend(trip, friendUID: "friend-a"))
                #expect(DiveTripShareLineagePresentation.hasSharedWithFriend(trip, friendUID: "friend-a"))
                DiveTripShareLineagePresentation.removeSharedWithFriend(trip, friendUID: "friend-a")
                #expect(!DiveTripShareLineagePresentation.hasAcceptedFriend(trip, friendUID: "friend-a"))
            }
}
