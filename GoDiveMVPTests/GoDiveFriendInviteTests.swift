//
//  GoDiveFriendInviteTests.swift
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


struct GoDiveFriendInviteTests {
        @Test func friendInviteToken_isOpaqueHex() {
            let token = GoDiveFriendInviteMapping.makeToken(byteCount: 16)
            #expect(token.count == 32)
            #expect(token.allSatisfy { $0.hexDigitValue != nil })
        }

        @Test func friendshipID_isOrderIndependent() {
            let a = GoDiveFriendInviteMapping.friendshipID(uidA: "bbb", uidB: "aaa")
            let b = GoDiveFriendInviteMapping.friendshipID(uidA: "aaa", uidB: "bbb")
            #expect(a == b)
            #expect(a == "aaa_bbb")
        }

        @Test func inviteURL_parsesCustomSchemeAndHTTPS() {
            let token = "abcdef0123456789abcdef0123456789"
            let custom = GoDiveFriendInviteURL.customSchemeInviteURL(token: token)
            let https = GoDiveFriendInviteURL.httpsInviteURL(token: token)
            #expect(custom != nil)
            #expect(https != nil)
            #expect(GoDiveFriendInviteURL.inviteToken(from: custom!) == token)
            #expect(GoDiveFriendInviteURL.inviteToken(from: https!) == token)
        }

        @Test func preferredInviteURL_usesLinksSubdomainHTTPS() {
            let token = "abcdef0123456789abcdef0123456789"
            let preferred = GoDiveFriendInviteURL.preferredInviteURL(token: token)
            let https = GoDiveFriendInviteURL.httpsInviteURL(token: token)
            #expect(preferred == https)
            #expect(preferred?.host?.lowercased() == GoDiveFriendInviteURL.httpsInviteHost)
        }

        @Test func inviteURL_parsesLegacyMarketingHost() throws {
            let token = "abcdef0123456789abcdef0123456789"
            let legacy = try #require(URL(string: "https://godiveios.com/invite/\(token)"))
            #expect(GoDiveFriendInviteURL.inviteToken(from: legacy) == token)
        }

        @Test func redeemValidation_rejectsSelfInviteAndExpired() {
            let now = Date(timeIntervalSince1970: 1_700_000_000)
            let selfResult = GoDiveFriendInviteMapping.validateRedeem(
                inviteFromUid: "me",
                inviteStatus: GoDiveFriendInviteMapping.inviteStatusOpen,
                inviteExpiresAt: now.addingTimeInterval(3600),
                redeemingUid: "me",
                alreadyFriends: false,
                currentFriendCount: 0,
                now: now
            )
            #expect(selfResult == .failure(.selfInvite))

            let expired = GoDiveFriendInviteMapping.validateRedeem(
                inviteFromUid: "them",
                inviteStatus: GoDiveFriendInviteMapping.inviteStatusOpen,
                inviteExpiresAt: now.addingTimeInterval(-1),
                redeemingUid: "me",
                alreadyFriends: false,
                currentFriendCount: 0,
                now: now
            )
            #expect(expired == .failure(.inviteExpired))

            let ok = GoDiveFriendInviteMapping.validateRedeem(
                inviteFromUid: "them",
                inviteStatus: GoDiveFriendInviteMapping.inviteStatusOpen,
                inviteExpiresAt: now.addingTimeInterval(3600),
                redeemingUid: "me",
                alreadyFriends: false,
                currentFriendCount: 0,
                now: now
            )
            #expect(ok == .success("them"))
        }

        @Test func redeemValidation_enforcesFriendCap() {
            let now = Date()
            let capped = GoDiveFriendInviteMapping.validateRedeem(
                inviteFromUid: "them",
                inviteStatus: GoDiveFriendInviteMapping.inviteStatusOpen,
                inviteExpiresAt: now.addingTimeInterval(3600),
                redeemingUid: "me",
                alreadyFriends: false,
                currentFriendCount: GoDiveFriendInviteMapping.maxFriendsPerUser,
                now: now
            )
            #expect(capped == .failure(.friendCapReached))
        }

        @Test @MainActor func friendInviteQRRenderer_producesImageForPreferredURL() {
            let token = "abcdef0123456789abcdef0123456789"
            guard let url = GoDiveFriendInviteURL.preferredInviteURL(token: token) else {
                Issue.record("Expected preferred invite URL")
                return
            }
            let image = GoDiveFriendInviteQRCodeRenderer.image(for: url)
            #expect(image != nil)
            #expect((image?.size.width ?? 0) > 0)
        }

        @Test func friendInviteShareSheet_usesBluePanelLayoutTokens() {
            #expect(FriendInviteShareSheetPresentation.qrDisplaySize == 196)
            #expect(
                FriendInviteShareSheetPresentation.cancelAccessibilityIdentifier
                    == "FriendInviteShare.Cancel"
            )
            #expect(GoDiveFriendsPresentation.inviteExpiresFooter.contains("24 hours"))
        }

        @Test func friendInviteMapping_storesFromDisplayNameOnInvite() {
            let draft = GoDiveFriendInviteMapping.inviteDraft(
                fromUid: "uid-a",
                token: "abc123",
                fromDisplayName: "  Jane Doe  "
            )
            #expect(draft.fromDisplayName == "Jane Doe")
            let fields = GoDiveFriendInviteMapping.inviteFields(from: draft)
            #expect(fields["fromDisplayName"] as? String == "Jane Doe")

            let empty = GoDiveFriendInviteMapping.inviteDraft(
                fromUid: "uid-a",
                token: "def456",
                fromDisplayName: "   "
            )
            #expect(empty.fromDisplayName == nil)
            #expect(GoDiveFriendInviteMapping.inviteFields(from: empty)["fromDisplayName"] == nil)

            let placeholder = GoDiveFriendInviteMapping.inviteDraft(
                fromUid: "uid-a",
                token: "ghi789",
                fromDisplayName: UserProfileStore.defaultDisplayName
            )
            #expect(placeholder.fromDisplayName == nil)
            #expect(GoDiveFriendInviteMapping.inviteFields(from: placeholder)["fromDisplayName"] == nil)
        }

        @Test func friendInviteMapping_publisherNameSkipsPlaceholderThenUsesAuthOrCache() {
            #expect(
                GoDiveFriendInviteMapping.resolvedPublisherDisplayName(
                    localProfileName: UserProfileStore.defaultDisplayName,
                    authDisplayName: "Andre Dugas"
                ) == "Andre Dugas"
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedPublisherDisplayName(
                    localProfileName: "  Diver  ",
                    authDisplayName: nil,
                    cachedAppleName: "Andre Dugas"
                ) == "Andre Dugas"
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedPublisherDisplayName(
                    localProfileName: UserProfileStore.defaultDisplayName,
                    authDisplayName: UserProfileStore.defaultDisplayName,
                    cachedAppleName: "  ",
                    returningHintName: "Susu Dugas"
                ) == "Susu Dugas"
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedPublisherDisplayName(
                    localProfileName: UserProfileStore.defaultDisplayName
                ) == nil
            )
        }

        @Test func friendInviteMapping_resolvedDisplayNamePrefersDirectoryThenInviteSnapshot() {
            #expect(
                GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                    directoryDisplayName: "Alex Rivera",
                    inviteFromDisplayName: "Stale Name"
                ) == "Alex Rivera"
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                    directoryDisplayName: UserProfileStore.defaultDisplayName,
                    inviteFromDisplayName: "Jane Doe"
                ) == "Jane Doe"
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                    directoryDisplayName: nil,
                    inviteFromDisplayName: "  Pat Lee  "
                ) == "Pat Lee"
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                    directoryDisplayName: nil,
                    inviteFromDisplayName: nil
                ) == UserProfileStore.defaultDisplayName
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                    directoryDisplayName: UserProfileStore.defaultDisplayName,
                    inviteFromDisplayName: UserProfileStore.defaultDisplayName
                ) == UserProfileStore.defaultDisplayName
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                    directoryDisplayName: UserProfileStore.defaultDisplayName,
                    inviteFromDisplayName: nil
                ) == UserProfileStore.defaultDisplayName
            )
        }

        @Test func friendInviteMapping_storesMemberDisplayNamesOnFriendshipAndOmitsPlaceholder() {
            let draft = GoDiveFriendInviteMapping.friendshipDraft(
                uidA: "uid-b",
                uidB: "uid-a",
                inviteToken: "abc123",
                displayNameA: "  Susu Dugas  ",
                displayNameB: UserProfileStore.defaultDisplayName
            )
            #expect(draft.memberDisplayNames["uid-a"] == nil)
            #expect(draft.memberDisplayNames["uid-b"] == "Susu Dugas")
            let fields = GoDiveFriendInviteMapping.friendshipFields(from: draft)
            let names = fields["memberDisplayNames"] as? [String: String]
            #expect(names == ["uid-b": "Susu Dugas"])
            #expect(
                GoDiveFriendInviteMapping.memberDisplayName(
                    for: "uid-b",
                    in: ["uid-b": "Susu Dugas", "uid-a": UserProfileStore.defaultDisplayName]
                ) == "Susu Dugas"
            )
            #expect(
                GoDiveFriendInviteMapping.memberDisplayName(
                    for: "uid-a",
                    in: ["uid-a": UserProfileStore.defaultDisplayName]
                ) == nil
            )
            #expect(
                GoDiveFriendInviteMapping.resolvedInviteDisplayName(
                    directoryDisplayName: UserProfileStore.defaultDisplayName,
                    inviteFromDisplayName: GoDiveFriendInviteMapping.memberDisplayName(
                        for: "uid-b",
                        in: names
                    )
                ) == "Susu Dugas"
            )
        }

        @Test func friendInviteMapping_hasActiveFriendshipUsesMemberListsNotMissingDocGet() {
            let lists = [
                ["me", "friend-a"],
                ["friend-b", "me"],
            ]
            #expect(GoDiveFriendInviteMapping.hasActiveFriendship(with: "friend-a", memberLists: lists))
            #expect(GoDiveFriendInviteMapping.hasActiveFriendship(with: " friend-b ", memberLists: lists))
            #expect(!GoDiveFriendInviteMapping.hasActiveFriendship(with: "friend-c", memberLists: lists))
            #expect(!GoDiveFriendInviteMapping.hasActiveFriendship(with: "friend-a", memberLists: []))
        }

        @Test func friendInviteMapping_expiresAfter24Hours() {
            #expect(GoDiveFriendInviteMapping.inviteTimeToLiveSeconds == 24 * 60 * 60)
            let now = Date(timeIntervalSince1970: 1_700_000_000)
            let draft = GoDiveFriendInviteMapping.inviteDraft(
                fromUid: "uid-a",
                token: "abc123",
                now: now
            )
            #expect(draft.expiresAt == now.addingTimeInterval(24 * 60 * 60))
            #expect(
                GoDiveFriendInviteMapping.isInviteOpen(
                    status: GoDiveFriendInviteMapping.inviteStatusOpen,
                    expiresAt: draft.expiresAt,
                    now: now.addingTimeInterval(23 * 60 * 60)
                )
            )
            #expect(
                !GoDiveFriendInviteMapping.isInviteOpen(
                    status: GoDiveFriendInviteMapping.inviteStatusOpen,
                    expiresAt: draft.expiresAt,
                    now: now.addingTimeInterval(25 * 60 * 60)
                )
            )
        }

        @Test func friendInvitePushTrigger_firesOnRedeemTransitionOnly() {
            #expect(
                GoDiveFriendInvitePushTrigger.shouldNotifyInviteAccepted(
                    beforeStatus: GoDiveFriendInviteMapping.inviteStatusOpen,
                    afterStatus: GoDiveFriendInviteMapping.inviteStatusRedeemed
                )
            )
            #expect(
                !GoDiveFriendInvitePushTrigger.shouldNotifyInviteAccepted(
                    beforeStatus: GoDiveFriendInviteMapping.inviteStatusRedeemed,
                    afterStatus: GoDiveFriendInviteMapping.inviteStatusRedeemed
                )
            )
            #expect(
                !GoDiveFriendInvitePushTrigger.shouldNotifyInviteAccepted(
                    beforeStatus: GoDiveFriendInviteMapping.inviteStatusOpen,
                    afterStatus: GoDiveFriendInviteMapping.inviteStatusOpen
                )
            )
        }

        @Test func friendInvitePush_fcmDeviceDocumentID() {
            let id = GoDiveFirebaseCloudMessaging.pushDeviceDocumentID(installationID: "ABC")
            #expect(id == "fcm_ABC")
            #expect(GoDiveFirebaseCloudMessaging.isPushDeviceDocumentID(id))
            #expect(!GoDiveFirebaseCloudMessaging.isPushDeviceDocumentID("appleLink"))
        }

        @Test @MainActor func friendInvitePostRedeemNavigation_storesFriendEdge() {
            GoDiveFriendInvitePostRedeemNavigationStore.shared.clear()
            let profile = GoDiveFriendGraphService.PublicProfileSummary(
                uid: "uid-a",
                displayName: "Alex",
                photoURL: "https://example.com/p.jpg",
                profileHeroURL: nil,
                profileHeroMediaKind: nil
            )
            GoDiveFriendInvitePostRedeemNavigationStore.shared.setPending(profile)
            let edge = GoDiveFriendInvitePostRedeemNavigationStore.shared.consumePendingFriend()
            #expect(edge?.friendUID == "uid-a")
            #expect(edge?.displayName == "Alex")
            #expect(GoDiveFriendInvitePostRedeemNavigationStore.shared.consumePendingFriend() == nil)
        }
}
