import Foundation
import SwiftData
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import GoDiveMVP

struct GoDiveFriendsTests {
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

    @Test func sharedDiveProjection_omitsNotesAndMediaByDefault() {
        let diveID = UUID()
        let snapshot = GoDiveSharedDiveProjectionMapping.DiveSnapshot(
            id: diveID,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            timeZoneOffsetSeconds: nil,
            durationMinutes: 45,
            maxDepthMeters: 18.5,
            averageDepthMeters: 12,
            bottomTimeSeconds: 2400,
            diveNumber: 7,
            waterTempAvgCelsius: nil,
            waterTempMinCelsius: 24,
            waterTempMaxCelsius: nil,
            siteName: "Blue Hole",
            locationName: nil,
            entryLatitude: 17.3,
            entryLongitude: -87.5,
            notes: "Secret note",
            diveCurrentStrengthRaw: nil,
            surfaceCondition: nil,
            entryType: nil,
            diveVisibilityRaw: nil,
            diveOperatorName: nil,
            diveMasterName: nil,
            diveWaterTypeRaw: nil,
            diverWeightKilograms: nil,
            tankMaterial: nil,
            tankVolumeDescription: "AL80",
            tankPressureStartPSI: nil,
            tankPressureEndPSI: nil,
            gasType: "Air",
            oxygenMix: 21,
            avgSAC: nil,
            avgRMV: nil,
            activityTagNames: ["Reef"],
            sightings: [.init(commonName: "Turtle", scientificName: nil, catalogUUID: "t1")],
            taggedBuddies: [.init(displayName: "Sam", firebaseUID: "uid-sam")],
            equipmentSummary: ["Scubapro regulator"],
            profileTrackData: Data([1, 2, 3]),
            mediaPreviews: [.init(photoID: "p1", previewURL: "https://example.com/p.jpg")]
        )

        let withoutOptIn = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: false, includeMedia: false)
        )
        #expect(withoutOptIn["notes"] as? String == nil)
        #expect(withoutOptIn["mediaPreviews"] == nil)
        #expect(withoutOptIn["siteName"] as? String == "Blue Hole")
        #expect((withoutOptIn["profileTrackBase64"] as? String)?.isEmpty == false)

        let withOptIn = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: true, includeMedia: true)
        )
        #expect(withOptIn["notes"] as? String == "Secret note")
        #expect(withOptIn["mediaPreviews"] != nil)

        let parsed = GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
            id: diveID.uuidString,
            data: withOptIn
        )
        #expect(parsed.siteName == "Blue Hole")
        #expect(parsed.notes == "Secret note")
        #expect(
            GoDiveSharedDiveProjectionMapping.wasCurrentUserTagged(
                dive: parsed,
                currentFirebaseUID: "uid-sam"
            )
        )
        #expect(
            !GoDiveSharedDiveProjectionMapping.wasCurrentUserTagged(
                dive: parsed,
                currentFirebaseUID: "other"
            )
        )
    }

    @Test func sharedDiveProjection_dropsOversizedProfileTrack() {
        let huge = Data(repeating: 0xAB, count: GoDiveSharedDiveProjectionMapping.maxProfileTrackBytes + 1)
        #expect(GoDiveSharedDiveProjectionMapping.cappedProfileTrack(huge) == nil)
        let ok = Data(repeating: 0x01, count: 10)
        #expect(GoDiveSharedDiveProjectionMapping.cappedProfileTrack(ok)?.count == 10)
    }

    @Test func friendsPresentation_friendCountLabel() {
        #expect(GoDiveFriendsPresentation.friendCountLabel(0) == "0 friends")
        #expect(GoDiveFriendsPresentation.friendCountLabel(1) == "1 friend")
        #expect(GoDiveFriendsPresentation.friendCountLabel(2) == "2 friends")
    }

    @Test @MainActor
    func friendShareAffectedDiveIDs_resolvesDiveAndRelatedModels() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let ownerID = UUID()
        let otherOwnerID = UUID()

        let ownedDive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 40,
            maxDepthMeters: 18
        )
        ownedDive.ownerProfileID = ownerID
        let otherDive = DiveActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 1_700_000_100),
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        otherDive.ownerProfileID = otherOwnerID
        context.insert(ownedDive)
        context.insert(otherDive)

        let media = DiveMediaPhoto(
            sortOrder: 0,
            mediaKind: .image,
            dive: ownedDive
        )
        context.insert(media)

        let fromDive = GoDiveFriendShareAffectedDiveIDs.diveIDs(
            fromModels: [ownedDive, otherDive],
            ownerProfileID: ownerID
        )
        #expect(fromDive == [ownedDive.id])

        let fromMedia = GoDiveFriendShareAffectedDiveIDs.diveIDs(
            fromModels: [media],
            ownerProfileID: ownerID
        )
        #expect(fromMedia == [ownedDive.id])
    }

    @Test func friendShareChangeNotification_carriesDiveID() {
        let diveID = UUID()
        let expectation = diveID
        let note = Notification(
            name: .diveLogForFriendShareDidChange,
            object: nil,
            userInfo: [DiveLogForFriendShareChangeNotification.diveIDUserInfoKey: diveID]
        )
        #expect(DiveLogForFriendShareChangeNotification.diveID(from: note) == expectation)
        let empty = Notification(name: .diveLogForFriendShareDidChange, object: nil, userInfo: nil)
        #expect(DiveLogForFriendShareChangeNotification.diveID(from: empty) == nil)
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

    @Test @MainActor func buddyFeed_emptyKind_whenNoFriends() {
        let kind = LogbookBuddyFeedPresentation.emptyKind(
            friends: [],
            rows: [],
            firebaseConfigured: true,
            isSignedIn: true
        )
        #expect(kind == .noFriends)
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

    @Test func friendInviteShareSheet_usesMediumDetentLayoutTokens() {
        #expect(FriendInviteShareSheetPresentation.qrDisplaySize == 196)
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

    @Test func buddiesListPresentation_friendTotalDivesLabel_usesTotalCopy() {
        #expect(BuddiesListPresentation.friendTotalDivesLabel(0) == "0 total dives")
        #expect(BuddiesListPresentation.friendTotalDivesLabel(1) == "1 total dive")
        #expect(BuddiesListPresentation.friendTotalDivesLabel(12) == "12 total dives")
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

    @Test func buddiesListPresentation_smsBody_includesNameAndURL() {
        let url = URL(string: "https://links.godiveios.com/invite/abc")!
        let body = BuddiesListPresentation.smsBody(inviteURL: url, buddyDisplayName: "Jamie")
        #expect(body.contains("Jamie"))
        #expect(body.contains(url.absoluteString))
    }

    @Test func diveBuddyContactSMSPresentation_emptyRecipientsWithoutContact() {
        #expect(DiveBuddyContactSMSPresentation.smsRecipients(contactsIdentifier: nil).isEmpty)
    }
}
