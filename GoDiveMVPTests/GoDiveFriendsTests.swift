import FirebaseFirestore
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

    @Test func sharedDiveProjection_omitsNotesAndMediaByDefault() throws {
        let diveID = UUID()
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
        let snapshot = GoDiveSharedDiveProjectionMapping.DiveSnapshot(
            id: diveID,
            startTime: start,
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
            profileTrackData: profileTrack,
            swimTrackData: nil,
            mediaPreviews: [.init(photoID: "p1", previewURL: "https://example.com/p.jpg")],
            featuredMediaPhotoID: "p1"
        )

        let withoutOptIn = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: false, includeMedia: false)
        )
        #expect(withoutOptIn["notes"] as? String == nil)
        #expect(withoutOptIn["mediaItems"] == nil)
        #expect(withoutOptIn["mediaPreviews"] == nil)
        #expect(withoutOptIn["schemaVersion"] as? Int == 3)
        #expect(withoutOptIn["siteName"] as? String == "Blue Hole")
        #expect(withoutOptIn["activityKind"] as? String == FriendSharedActivityKind.scubaDive.rawValue)
        #expect((withoutOptIn["profileTrackBase64"] as? String)?.isEmpty == false)

        let withOptIn = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: true, notesText: "Secret note", includeMedia: true)
        )
        #expect(withOptIn["notes"] as? String == "Secret note")
        #expect(withOptIn["mediaItems"] != nil)
        #expect(withOptIn["mediaPreviews"] == nil)
        #expect(withOptIn["featuredMediaId"] as? String == "p1")

        let parsed = GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
            id: diveID.uuidString,
            data: withOptIn
        )
        #expect(parsed.siteName == "Blue Hole")
        #expect(parsed.notes == "Secret note")
        #expect(parsed.featuredMediaPhotoID == "p1")
        #expect(parsed.mediaItems.count == 1)
        #expect(parsed.mediaItems[0].thumbnailURL == "https://example.com/p.jpg")
        #expect(parsed.mediaPreviews.count == 1)
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
        let chartSeries = GoDiveSharedDiveProjectionMapping.decodedDepthChartSeries(from: parsed)
        #expect(chartSeries.depthSamples.count >= 2)
    }

    @Test func sharedDiveProjection_v3MediaItems_roundTrip() throws {
        let diveID = UUID()
        let mediaID = UUID()
        let snapshot = GoDiveSharedDiveProjectionMapping.DiveSnapshot(
            id: diveID,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            timeZoneOffsetSeconds: nil,
            durationMinutes: 30,
            maxDepthMeters: 12,
            averageDepthMeters: nil,
            bottomTimeSeconds: nil,
            diveNumber: 1,
            waterTempAvgCelsius: nil,
            waterTempMinCelsius: nil,
            waterTempMaxCelsius: nil,
            siteName: "Reef",
            locationName: nil,
            entryLatitude: nil,
            entryLongitude: nil,
            notes: nil,
            diveCurrentStrengthRaw: nil,
            surfaceCondition: nil,
            entryType: nil,
            diveVisibilityRaw: nil,
            diveOperatorName: nil,
            diveMasterName: nil,
            diveWaterTypeRaw: nil,
            diverWeightKilograms: nil,
            tankMaterial: nil,
            tankVolumeDescription: nil,
            tankPressureStartPSI: nil,
            tankPressureEndPSI: nil,
            gasType: nil,
            oxygenMix: nil,
            avgSAC: nil,
            avgRMV: nil,
            activityTagNames: [],
            sightings: [],
            taggedBuddies: [],
            equipmentSummary: [],
            profileTrackData: nil,
            swimTrackData: nil,
            mediaItems: [
                .init(
                    mediaID: mediaID.uuidString,
                    kind: .video,
                    thumbnailURL: "https://firebasestorage.googleapis.com/thumb.jpg",
                    contentURL: "https://firebasestorage.googleapis.com/video.mp4",
                    width: 1920,
                    height: 1080,
                    durationSeconds: 30,
                    contentBytes: 4_000_000
                ),
            ],
            mediaPreviews: [],
            featuredMediaPhotoID: mediaID.uuidString
        )

        let fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: false, includeMedia: true)
        )
        #expect(fields["schemaVersion"] as? Int == 3)
        let rows = fields["mediaItems"] as? [[String: Any]]
        #expect(rows?.count == 1)
        #expect(rows?[0]["kind"] as? String == "video")
        #expect(rows?[0]["durationSeconds"] as? Double == 30)

        let parsed = GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
            id: diveID.uuidString,
            data: fields
        )
        #expect(parsed.mediaItems.count == 1)
        #expect(parsed.mediaItems[0].kind == .video)
        #expect(parsed.mediaItems[0].contentURL?.contains("video.mp4") == true)
        #expect(parsed.mediaPreviews[0].previewURL.contains("thumb.jpg"))
    }

    @Test func sharedDiveProjection_v2MediaPreviews_fallbackParse() {
        let data: [String: Any] = [
            "mediaPreviews": [
                ["photoId": "legacy-photo", "previewURL": "https://example.com/legacy.jpg"],
            ],
            "featuredMediaPhotoId": "legacy-photo",
        ]
        let payload = GoDiveSharedDiveProjectionMapping.parseMediaPayload(from: data)
        #expect(payload.items.count == 1)
        #expect(payload.items[0].kind == .photo)
        #expect(payload.items[0].thumbnailURL == "https://example.com/legacy.jpg")
        #expect(payload.previews[0].photoID == "legacy-photo")
        #expect(payload.featuredMediaID == "legacy-photo")
    }

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

    @Test func sharedDiveProjection_applyOptOutFieldDeletes_clearsMediaAndNotes() {
        var fields: [String: Any] = [
            "notes": "secret",
            "mediaItems": [["mediaId": "x"]],
            "featuredMediaId": "x",
            "mediaPreviews": [["photoId": "x"]],
            "featuredMediaPhotoId": "x",
        ]
        GoDiveSharedDiveProjectionSync.applyOptOutFieldDeletes(
            to: &fields,
            options: .init(includeNotes: false, includeMedia: false)
        )
        #expect(fields["notes"] is FieldValue)
        #expect(fields["mediaItems"] is FieldValue)
        #expect(fields["featuredMediaId"] is FieldValue)
        #expect(fields["mediaPreviews"] is FieldValue)
        #expect(fields["featuredMediaPhotoId"] is FieldValue)
    }

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

    @Test func sharedDiveProjection_decodedDepthChartSeries_includesPressureBaseline() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let profileTrack = try #require(
            try DiveProfileTrackCodec.encode(
                samples: [
                    DiveProfileTrackSample(timestamp: start, depthMeters: 0, tankPressurePSI: 3000),
                    DiveProfileTrackSample(timestamp: start.addingTimeInterval(60), depthMeters: 12, tankPressurePSI: 2500),
                    DiveProfileTrackSample(timestamp: start.addingTimeInterval(120), depthMeters: 18, tankPressurePSI: 2000),
                ],
                diveStartTime: start
            )
        )
        let fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: GoDiveSharedDiveProjectionMapping.DiveSnapshot(
                id: UUID(),
                startTime: start,
                timeZoneOffsetSeconds: nil,
                durationMinutes: 45,
                maxDepthMeters: 18,
                averageDepthMeters: nil,
                bottomTimeSeconds: nil,
                diveNumber: 1,
                waterTempAvgCelsius: nil,
                waterTempMinCelsius: nil,
                waterTempMaxCelsius: nil,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                diveCurrentStrengthRaw: nil,
                surfaceCondition: nil,
                entryType: nil,
                diveVisibilityRaw: nil,
                diveOperatorName: nil,
                diveMasterName: nil,
                diveWaterTypeRaw: nil,
                diverWeightKilograms: nil,
                tankMaterial: nil,
                tankVolumeDescription: nil,
                tankPressureStartPSI: 3000,
                tankPressureEndPSI: 2000,
                gasType: nil,
                oxygenMix: nil,
                avgSAC: nil,
                avgRMV: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                profileTrackData: profileTrack,
                mediaPreviews: []
            ),
            options: .init(includeNotes: false, includeMedia: false)
        )
        let parsed = GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
            id: UUID().uuidString,
            data: fields
        )
        let chartSeries = GoDiveSharedDiveProjectionMapping.decodedDepthChartSeries(from: parsed)
        #expect(chartSeries.depthSamples.count >= 2)
        #expect(!chartSeries.pressureSamples.isEmpty)
        #expect(chartSeries.pressureBaselinePSI == 2000)
    }

    @Test func sharedDiveProjection_parseFriendVisibleDive_readsFirestoreTimestamp() throws {
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
        let fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: GoDiveSharedDiveProjectionMapping.DiveSnapshot(
                id: UUID(),
                startTime: start,
                timeZoneOffsetSeconds: nil,
                durationMinutes: 40,
                maxDepthMeters: 12,
                averageDepthMeters: nil,
                bottomTimeSeconds: nil,
                diveNumber: 1,
                waterTempAvgCelsius: nil,
                waterTempMinCelsius: nil,
                waterTempMaxCelsius: nil,
                siteName: "Reef",
                locationName: nil,
                entryLatitude: nil,
                entryLongitude: nil,
                notes: nil,
                diveCurrentStrengthRaw: nil,
                surfaceCondition: nil,
                entryType: nil,
                diveVisibilityRaw: nil,
                diveOperatorName: nil,
                diveMasterName: nil,
                diveWaterTypeRaw: nil,
                diverWeightKilograms: nil,
                tankMaterial: nil,
                tankVolumeDescription: nil,
                tankPressureStartPSI: nil,
                tankPressureEndPSI: nil,
                gasType: nil,
                oxygenMix: nil,
                avgSAC: nil,
                avgRMV: nil,
                activityTagNames: [],
                sightings: [],
                taggedBuddies: [],
                equipmentSummary: [],
                profileTrackData: profileTrack,
                mediaPreviews: []
            ),
            options: .init(includeNotes: false, includeMedia: false)
        )
        var firestoreFields = fields
        firestoreFields["startTime"] = Timestamp(date: start)

        let parsed = GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
            id: UUID().uuidString,
            data: firestoreFields
        )
        #expect(parsed.startTime == start)
        let chartSeries = GoDiveSharedDiveProjectionMapping.decodedDepthChartSeries(from: parsed)
        #expect(chartSeries.depthSamples.count >= 2)
    }

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

    @Test @MainActor
    func friendShareProjection_profileTrackDataForSharing_encodesFromFetchedPoints() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let dive = DiveActivity(
            source: .manual,
            startTime: start,
            durationMinutes: 40,
            maxDepthMeters: 20
        )
        context.insert(dive)

        let pointA = DiveProfilePoint(timestamp: start, depthMeters: 0)
        pointA.diveActivityID = dive.id
        let pointB = DiveProfilePoint(timestamp: start.addingTimeInterval(90), depthMeters: 20)
        pointB.diveActivityID = dive.id
        context.insert(pointA)
        context.insert(pointB)
        try context.save()

        dive.profileTrackData = nil
        dive.profilePoints = []

        let encoded = try DiveProfilePointStore.profileTrackDataForSharing(
            activity: dive,
            modelContext: context
        )
        #expect(encoded != nil)
        #expect(!(encoded?.isEmpty ?? true))
        #expect(dive.profileTrackData != nil)
    }

    @Test @MainActor
    func friendShareProfileTrackRepublish_schedulesOnce() throws {
        let defaults = UserDefaults(suiteName: "GoDiveFriendShareProfileTrackRepublishTests")!
        defaults.removePersistentDomain(forName: "GoDiveFriendShareProfileTrackRepublishTests")
        defer { defaults.removePersistentDomain(forName: "GoDiveFriendShareProfileTrackRepublishTests") }
        GoDiveFriendShareProfileTrackRepublish.resetCompletedFlag(defaults: defaults)
        defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)

        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let ownerID = UUID()

        GoDiveFriendShareProfileTrackRepublish.scheduleOneTimeRepublishIfNeeded(
            ownerProfileID: ownerID,
            modelContext: context,
            userDefaults: defaults
        )
        #expect(defaults.bool(forKey: GoDiveFriendShareProfileTrackRepublish.completedDefaultsKey))

        GoDiveFriendShareProfileTrackRepublish.scheduleOneTimeRepublishIfNeeded(
            ownerProfileID: ownerID,
            modelContext: context,
            userDefaults: defaults
        )
    }

    @Test @MainActor
    func friendShareProjection_encodesProfileTrackFromLocalPoints() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let ownerID = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let dive = DiveActivity(
            source: .manual,
            startTime: start,
            durationMinutes: 40,
            maxDepthMeters: 20
        )
        dive.ownerProfileID = ownerID
        context.insert(dive)

        let pointA = DiveProfilePoint(timestamp: start, depthMeters: 0)
        pointA.diveActivityID = dive.id
        let pointB = DiveProfilePoint(timestamp: start.addingTimeInterval(90), depthMeters: 20)
        pointB.diveActivityID = dive.id
        context.insert(pointA)
        context.insert(pointB)
        try context.save()

        dive.profileTrackData = nil
        #expect(dive.profileTrackData == nil)

        try DiveProfilePointStore.ensurePointsLoaded(for: dive, modelContext: context)
        DiveProfilePointStore.syncTrackData(from: dive)
        #expect(dive.profileTrackData != nil)
        #expect(!(dive.profileTrackData?.isEmpty ?? true))
    }

    @Test @MainActor
    func friendShareProjection_encodesSwimTrackFromLocalPoints() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let snorkel = SnorkelActivity(
            startTime: start,
            durationMinutes: 30,
            swimDistanceMeters: 500
        )
        context.insert(snorkel)

        let pointA = SnorkelProfilePoint(timestamp: start, latitude: 12.1, longitude: -68.9)
        pointA.snorkelActivityID = snorkel.id
        let pointB = SnorkelProfilePoint(
            timestamp: start.addingTimeInterval(120),
            latitude: 12.11,
            longitude: -68.91
        )
        pointB.snorkelActivityID = snorkel.id
        context.insert(pointA)
        context.insert(pointB)
        try context.save()

        snorkel.swimTrackData = nil
        snorkel.profilePoints = []

        let encoded = try SnorkelProfilePointStore.swimTrackDataForSharing(
            activity: snorkel,
            modelContext: context
        )
        #expect(encoded != nil)
        #expect(!(encoded?.isEmpty ?? true))
        #expect(snorkel.swimTrackData != nil)
    }

    @Test @MainActor
    func friendShareAffectedDiveIDs_includesSnorkelMediaPhoto() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let ownerID = UUID()

        let snorkel = SnorkelActivity(
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 30,
            swimDistanceMeters: 400
        )
        snorkel.ownerProfileID = ownerID
        context.insert(snorkel)

        let media = SnorkelMediaPhoto(sortOrder: 0, mediaKind: .image, snorkelActivity: snorkel)
        context.insert(media)

        let ids = GoDiveFriendShareAffectedDiveIDs.diveIDs(
            fromModels: [media],
            ownerProfileID: ownerID
        )
        #expect(ids == [snorkel.id])
    }

    @Test func sharedDiveProjection_dropsOversizedProfileTrack() {
        let huge = Data(repeating: 0xAB, count: GoDiveSharedDiveProjectionMapping.maxProfileTrackBytes + 1)
        #expect(GoDiveSharedDiveProjectionMapping.cappedProfileTrack(huge) == nil)
        let ok = Data(repeating: 0x01, count: 10)
        #expect(GoDiveSharedDiveProjectionMapping.cappedProfileTrack(ok)?.count == 10)
        #expect(GoDiveSharedDiveProjectionMapping.cappedSwimTrack(huge) == nil)
        #expect(GoDiveSharedDiveProjectionMapping.cappedSwimTrack(ok)?.count == 10)
    }

    @Test func sharedSnorkelProjection_writesMediaItemsWhenMediaOptIn() {
        let mediaID = UUID()
        let snapshot = GoDiveSharedDiveProjectionMapping.DiveSnapshot(
            id: UUID(),
            startTime: Date(),
            timeZoneOffsetSeconds: nil,
            durationMinutes: 20,
            maxDepthMeters: 0,
            averageDepthMeters: nil,
            bottomTimeSeconds: nil,
            diveNumber: nil,
            waterTempAvgCelsius: nil,
            waterTempMinCelsius: nil,
            waterTempMaxCelsius: nil,
            siteName: "Bay",
            locationName: nil,
            entryLatitude: nil,
            entryLongitude: nil,
            notes: nil,
            diveCurrentStrengthRaw: nil,
            surfaceCondition: nil,
            entryType: nil,
            diveVisibilityRaw: nil,
            diveOperatorName: nil,
            diveMasterName: nil,
            diveWaterTypeRaw: nil,
            diverWeightKilograms: nil,
            tankMaterial: nil,
            tankVolumeDescription: nil,
            tankPressureStartPSI: nil,
            tankPressureEndPSI: nil,
            gasType: nil,
            oxygenMix: nil,
            avgSAC: nil,
            avgRMV: nil,
            activityTagNames: [],
            sightings: [],
            taggedBuddies: [],
            equipmentSummary: [],
            profileTrackData: nil,
            swimTrackData: nil,
            mediaItems: [
                .photoThumbnailOnly(
                    mediaID: mediaID.uuidString,
                    thumbnailURL: "https://firebasestorage.googleapis.com/thumb.jpg"
                ),
            ],
            mediaPreviews: [],
            featuredMediaPhotoID: mediaID.uuidString
        )

        let fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: false, includeMedia: true)
        )
        #expect((fields["mediaItems"] as? [[String: Any]])?.count == 1)
        #expect(fields["featuredMediaId"] as? String == mediaID.uuidString)
    }

    @Test func sharedSnorkelProjection_includesKindDistanceAndTracks() throws {
        let activityID = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let swimSamples = [
            SnorkelSwimTrackSample(
                timestamp: start,
                latitude: 12.1,
                longitude: -68.9
            ),
            SnorkelSwimTrackSample(
                timestamp: start.addingTimeInterval(120),
                latitude: 12.11,
                longitude: -68.91
            ),
        ]
        let swimTrack = try #require(
            try SnorkelSwimTrackCodec.encode(samples: swimSamples, activityStartTime: start)
        )

        let snapshot = GoDiveSharedDiveProjectionMapping.DiveSnapshot(
            id: activityID,
            activityKind: .snorkel,
            startTime: start,
            timeZoneOffsetSeconds: nil,
            durationMinutes: 32,
            maxDepthMeters: 2.5,
            averageDepthMeters: nil,
            bottomTimeSeconds: nil,
            diveNumber: nil,
            waterTempAvgCelsius: nil,
            waterTempMinCelsius: nil,
            waterTempMaxCelsius: nil,
            siteName: "Klein Bonaire",
            locationName: nil,
            region: "Bonaire",
            country: "Caribbean Netherlands",
            swimDistanceMeters: 840,
            entryLatitude: 12.1,
            entryLongitude: -68.9,
            notes: nil,
            diveCurrentStrengthRaw: nil,
            surfaceCondition: nil,
            entryType: nil,
            diveVisibilityRaw: nil,
            diveOperatorName: nil,
            diveMasterName: nil,
            diveWaterTypeRaw: nil,
            diverWeightKilograms: nil,
            tankMaterial: nil,
            tankVolumeDescription: nil,
            tankPressureStartPSI: nil,
            tankPressureEndPSI: nil,
            gasType: nil,
            oxygenMix: nil,
            avgSAC: nil,
            avgRMV: nil,
            activityTagNames: [],
            sightings: [],
            taggedBuddies: [],
            equipmentSummary: [],
            profileTrackData: nil,
            swimTrackData: swimTrack,
            mediaPreviews: []
        )

        let fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: false, includeMedia: false)
        )
        #expect(fields["activityKind"] as? String == FriendSharedActivityKind.snorkel.rawValue)
        #expect(fields["swimDistanceMeters"] as? Double == 840)
        #expect(fields["region"] as? String == "Bonaire")
        #expect((fields["swimTrackBase64"] as? String)?.isEmpty == false)

        let parsed = GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
            id: activityID.uuidString,
            data: fields
        )
        #expect(parsed.resolvedActivityKind == .snorkel)
        #expect(parsed.swimDistanceMeters == 840)
        #expect(GoDiveSharedDiveProjectionMapping.displayTitle(for: parsed) == "Klein Bonaire")
        let coordinates = GoDiveSharedDiveProjectionMapping.decodedSwimTrackCoordinates(from: parsed)
        #expect(coordinates.count == 2)
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

    @Test @MainActor
    func friendShareAffectedDiveIDs_includesSnorkelActivities() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let ownerID = UUID()

        let snorkel = SnorkelActivity(
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 30,
            swimDistanceMeters: 400
        )
        snorkel.ownerProfileID = ownerID
        context.insert(snorkel)

        let ids = GoDiveFriendShareAffectedDiveIDs.diveIDs(
            fromModels: [snorkel],
            ownerProfileID: ownerID
        )
        #expect(ids == [snorkel.id])
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

    @Test func diveBuddyContactSMSPresentation_emptyRecipientsWithoutContact() {
        #expect(DiveBuddyContactSMSPresentation.smsRecipients(contactsIdentifier: nil).isEmpty)
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

    // MARK: - Friend shared media Phase 4 (cache + presentation)

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

    @Test func friendSharedMediaFullscreen_presentationZoomAndChrome() {
        #expect(FriendSharedMediaFullscreenPresentation.clampedZoomScale(0.5) == 1)
        #expect(FriendSharedMediaFullscreenPresentation.clampedZoomScale(2.5) == 2.5)
        #expect(FriendSharedMediaFullscreenPresentation.clampedZoomScale(9) == 4)
        #expect(!FriendSharedMediaFullscreenPresentation.allowsPanGesture(atZoomScale: 1))
        #expect(FriendSharedMediaFullscreenPresentation.allowsPanGesture(atZoomScale: 1.5))
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
        #expect(FriendSharedMediaFullscreenPresentation.pageIndex(for: "b", in: items) == 1)
        #expect(FriendSharedMediaFullscreenPresentation.chromeTitle(pageIndex: 0, pageCount: 2) == "1 / 2")
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
    #endif

    @Test func goDiveSharedMediaExport_cappedVideoExportDuration_clampsAtThirtySeconds() {
        #expect(GoDiveSharedMediaExport.cappedVideoExportDurationSeconds(60) == 30)
        #expect(GoDiveSharedMediaExport.cappedVideoExportDurationSeconds(12.5) == 12.5)
        #expect(GoDiveSharedMediaExport.cappedVideoExportDurationSeconds(0) == 0)
        #expect(GoDiveSharedMediaExport.cappedVideoExportDurationSeconds(-4).isZero)
    }

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

    @Test func friendSharedActivityDetailPresentation_mapsReadOnlyMediaTagModels() {
        let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
            id: "tags",
            startTime: Date(),
            durationMinutes: 40,
            maxDepthMeters: 18,
            averageDepthMeters: nil,
            diveNumber: 2,
            siteName: "Wall",
            locationName: nil,
            entryLatitude: nil,
            entryLongitude: nil,
            notes: nil,
            activityTagNames: [],
            sightings: [
                .init(commonName: "French Angelfish", scientificName: "Pomacanthus paru", catalogUUID: "marine-life-french-angelfish"),
            ],
            taggedBuddies: [
                .init(displayName: "Alex", firebaseUID: "uid-alex"),
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
        let species = FriendSharedActivityDetailPresentation.displayMarineLife(from: dive)
        let buddies = FriendSharedActivityDetailPresentation.displayBuddies(from: dive)
        #expect(species.count == 1)
        #expect(species[0].commonName == "French Angelfish")
        #expect(species[0].uuid == "marine-life-french-angelfish")
        #expect(buddies.count == 1)
        #expect(buddies[0].displayName == "Alex")
        #expect(buddies[0].linkedFirebaseUID == "uid-alex")
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
            localRoster: [localAlex]
        )
        #expect(rows.count == 3)
        #expect(rows[0].displayName == "Alex Kim")
        #expect(rows[0].profilePhoto == Data([0x01, 0x02]))
        #expect(rows[1].displayName == "Sam Rivera")
        #expect(rows[1].profilePhoto == nil)
        #expect(rows[2].displayName == "Jamie")
        #expect(rows[2].profilePhoto == nil)
    }

    @Test func sharedDiveProjection_writesMediaBuddyTagsWhenMediaShared() {
        let mediaID = UUID()
        let snapshot = GoDiveSharedDiveProjectionMapping.DiveSnapshot(
            id: UUID(),
            startTime: Date(),
            timeZoneOffsetSeconds: nil,
            durationMinutes: 40,
            maxDepthMeters: 18,
            averageDepthMeters: nil,
            bottomTimeSeconds: nil,
            diveNumber: 1,
            waterTempAvgCelsius: nil,
            waterTempMinCelsius: nil,
            waterTempMaxCelsius: nil,
            siteName: "Reef",
            locationName: nil,
            entryLatitude: nil,
            entryLongitude: nil,
            notes: nil,
            diveCurrentStrengthRaw: nil,
            surfaceCondition: nil,
            entryType: nil,
            diveVisibilityRaw: nil,
            diveOperatorName: nil,
            diveMasterName: nil,
            diveWaterTypeRaw: nil,
            diverWeightKilograms: nil,
            tankMaterial: nil,
            tankVolumeDescription: nil,
            tankPressureStartPSI: nil,
            tankPressureEndPSI: nil,
            gasType: nil,
            oxygenMix: nil,
            avgSAC: nil,
            avgRMV: nil,
            activityTagNames: [],
            sightings: [],
            taggedBuddies: [],
            equipmentSummary: [],
            profileTrackData: nil,
            swimTrackData: nil,
            mediaItems: [
                .init(
                    mediaID: mediaID.uuidString,
                    kind: .photo,
                    thumbnailURL: "https://example.com/thumb.jpg",
                    contentURL: "https://example.com/photo.jpg",
                    width: nil,
                    height: nil,
                    durationSeconds: nil,
                    contentBytes: nil
                ),
            ],
            mediaBuddyTags: [
                .init(mediaID: mediaID.uuidString, displayName: "Alex", firebaseUID: "uid-alex"),
            ],
            mediaPreviews: [],
            featuredMediaPhotoID: mediaID.uuidString
        )

        let fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: false, includeMedia: true)
        )
        let tags = fields["mediaBuddyTags"] as? [[String: Any]]
        #expect(tags?.count == 1)
        #expect(tags?[0]["mediaId"] as? String == mediaID.uuidString)
        #expect(tags?[0]["displayName"] as? String == "Alex")

        let parsed = GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
            id: snapshot.id.uuidString,
            data: fields
        )
        #expect(parsed.mediaBuddyTags.count == 1)
        #expect(parsed.mediaBuddyTags[0].displayName == "Alex")
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

    @Test func activityFriendShareStatusPresentation_checklist_sharingOffReturnsNil() {
        let checklist = ActivityFriendShareStatusPresentation.shareStatusChecklist(
            shouldPublish: false,
            shareMediaEnabled: true,
            hasShareableMedia: true,
            notesExpected: true,
            hasPendingUpload: false,
            firestore: ActivityFriendShareStatusPresentation.FirestoreSnapshot(
                documentExists: true,
                hasIncompleteMediaRows: false,
                mediaItemCount: 3,
                hasNotesField: true
            )
        )
        #expect(checklist == nil)
    }

    @Test func activityFriendShareStatusPresentation_checklist_allSharedWhenComplete() {
        let checklist = ActivityFriendShareStatusPresentation.shareStatusChecklist(
            shouldPublish: true,
            shareMediaEnabled: true,
            hasShareableMedia: true,
            notesExpected: true,
            hasPendingUpload: false,
            firestore: ActivityFriendShareStatusPresentation.FirestoreSnapshot(
                documentExists: true,
                hasIncompleteMediaRows: false,
                mediaItemCount: 3,
                hasNotesField: true
            )
        )
        #expect(checklist?.activity == .shared)
        #expect(checklist?.media == .shared)
        #expect(checklist?.notes == .shared)
        #expect(checklist?.isUploading == false)
    }

    @Test func activityFriendShareStatusPresentation_checklist_uploadingWhileContentPending() {
        let incomplete = ActivityFriendShareStatusPresentation.FirestoreSnapshot(
            documentExists: true,
            hasIncompleteMediaRows: true,
            mediaItemCount: 3,
            hasNotesField: false
        )
        let checklist = ActivityFriendShareStatusPresentation.shareStatusChecklist(
            shouldPublish: true,
            shareMediaEnabled: true,
            hasShareableMedia: true,
            notesExpected: false,
            hasPendingUpload: false,
            firestore: incomplete
        )
        #expect(checklist?.activity == .shared)
        #expect(checklist?.media == .inProgress)
        #expect(checklist?.notes == .off)
        #expect(checklist?.isUploading == true)

        // Queue still busy keeps media in progress even when Firestore rows look complete.
        let queued = ActivityFriendShareStatusPresentation.shareStatusChecklist(
            shouldPublish: true,
            shareMediaEnabled: true,
            hasShareableMedia: true,
            notesExpected: false,
            hasPendingUpload: true,
            firestore: ActivityFriendShareStatusPresentation.FirestoreSnapshot(
                documentExists: true,
                hasIncompleteMediaRows: false,
                mediaItemCount: 3,
                hasNotesField: false
            )
        )
        #expect(queued?.media == .inProgress)
    }

    @Test func activityFriendShareStatusPresentation_checklist_missingDocumentIsInProgress() {
        let checklist = ActivityFriendShareStatusPresentation.shareStatusChecklist(
            shouldPublish: true,
            shareMediaEnabled: false,
            hasShareableMedia: false,
            notesExpected: true,
            hasPendingUpload: false,
            firestore: ActivityFriendShareStatusPresentation.FirestoreSnapshot(
                documentExists: false,
                hasIncompleteMediaRows: false,
                mediaItemCount: 0,
                hasNotesField: false
            )
        )
        #expect(checklist?.activity == .inProgress)
        #expect(checklist?.media == .off)
        #expect(checklist?.notes == .inProgress)
        #expect(checklist?.isUploading == true)
    }

    @Test func activityFriendShareStatusPresentation_checklist_mediaOffWhenDocumentHasNoMediaRows() {
        let checklist = ActivityFriendShareStatusPresentation.shareStatusChecklist(
            shouldPublish: true,
            shareMediaEnabled: true,
            hasShareableMedia: true,
            notesExpected: false,
            hasPendingUpload: false,
            hasLocalPendingUpload: false,
            firestore: ActivityFriendShareStatusPresentation.FirestoreSnapshot(
                documentExists: true,
                hasIncompleteMediaRows: false,
                mediaItemCount: 0,
                hasNotesField: false
            )
        )
        #expect(checklist?.activity == .shared)
        #expect(checklist?.media == .off)
        #expect(checklist?.isUploading == false)
    }

    @Test func activityFriendShareStatusPresentation_notesExpected_respectsModeAndText() {
        #expect(
            !ActivityFriendShareStatusPresentation.notesExpected(
                mode: .off,
                privateNotes: "deep dive",
                publicNotes: "hello"
            )
        )
        #expect(
            ActivityFriendShareStatusPresentation.notesExpected(
                mode: .privateNotes,
                privateNotes: "deep dive",
                publicNotes: nil
            )
        )
        #expect(
            !ActivityFriendShareStatusPresentation.notesExpected(
                mode: .privateNotes,
                privateNotes: "   ",
                publicNotes: "hello"
            )
        )
        #expect(
            ActivityFriendShareStatusPresentation.notesExpected(
                mode: .publicNotes,
                privateNotes: nil,
                publicNotes: "great vis"
            )
        )
        #expect(
            !ActivityFriendShareStatusPresentation.notesExpected(
                mode: .publicNotes,
                privateNotes: "secret",
                publicNotes: ""
            )
        )
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
        // Local-first publish checkpoint: new activities never auto-share, even with global share on.
        #expect(!dive.friendShareActivityEnabled)
        #expect(dive.friendSharePublishCheckpointPending)
        #expect(dive.friendShareMediaEnabled)
        #expect(dive.friendShareNotesModeRaw == ActivityFriendShareNotesMode.off.rawValue)
        #expect(!dive.friendShareBuddySettingsConfigured)
    }

    @Test func activityFriendSharePublishCheckpoint_seedNewSnorkelStaysLocalWithPendingFlag() {
        let suiteName = "GoDiveFriendsTests.publishCheckpointSnorkelSeed.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)
        defaults.set(true, forKey: AppUserSettings.shareMediaWithFriendsKey)

        let snorkel = SnorkelActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 25
        )
        ActivityFriendShareConfiguration.seedBuddyShareDefaultsOnNewActivity(snorkel, userDefaults: defaults)
        #expect(snorkel.friendShareBuddyDefaultsCaptured)
        #expect(!snorkel.friendShareActivityEnabled)
        #expect(snorkel.friendSharePublishCheckpointPending)
        #expect(snorkel.friendShareMediaEnabled)
    }

    @Test func activityFriendSharePublishCheckpoint_backfillDoesNotSetPendingFlag() {
        let suiteName = "GoDiveFriendsTests.publishCheckpointBackfill.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: AppUserSettings.shareDivesWithFriendsKey)

        let dive = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        ActivityFriendShareConfiguration.captureGlobalBuddyShareDefaultsIfNeeded(on: dive, userDefaults: defaults)
        #expect(dive.friendShareBuddyDefaultsCaptured)
        // Pre-existing activities keep the old auto-share behavior — no checkpoint banner.
        #expect(dive.friendShareActivityEnabled)
        #expect(!dive.friendSharePublishCheckpointPending)
    }

    @Test @MainActor func activityFriendSharePublishCheckpoint_applyConfiguredSettingsResolvesCheckpoint() {
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        dive.friendSharePublishCheckpointPending = true
        dive.friendShareBuddyDefaultsCaptured = true

        ActivityFriendShareConfiguration.applyConfiguredSettings(
            to: dive,
            shareActivityEnabled: true,
            shareMediaEnabled: false,
            selectedMediaIDs: [],
            notesMode: .off,
            publicNotes: nil
        )
        #expect(dive.friendShareBuddySettingsConfigured)
        #expect(dive.friendShareActivityEnabled)
        #expect(!dive.friendSharePublishCheckpointPending)

        let snorkel = SnorkelActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 25
        )
        snorkel.friendSharePublishCheckpointPending = true
        ActivityFriendShareConfiguration.applyConfiguredSettings(
            to: snorkel,
            shareActivityEnabled: false,
            shareMediaEnabled: false,
            selectedMediaIDs: [],
            notesMode: .off,
            publicNotes: nil
        )
        #expect(!snorkel.friendShareActivityEnabled)
        #expect(!snorkel.friendSharePublishCheckpointPending)
    }

    @Test func activityFriendSharePublishCheckpoint_showsBannerMatrix() {
        #expect(
            ActivityFriendSharePublishCheckpoint.showsBanner(
                checkpointPending: true,
                settingsConfigured: false,
                globalSharingEnabled: true,
                hasFriends: true
            )
        )
        #expect(
            !ActivityFriendSharePublishCheckpoint.showsBanner(
                checkpointPending: false,
                settingsConfigured: false,
                globalSharingEnabled: true,
                hasFriends: true
            )
        )
        #expect(
            !ActivityFriendSharePublishCheckpoint.showsBanner(
                checkpointPending: true,
                settingsConfigured: true,
                globalSharingEnabled: true,
                hasFriends: true
            )
        )
        #expect(
            !ActivityFriendSharePublishCheckpoint.showsBanner(
                checkpointPending: true,
                settingsConfigured: false,
                globalSharingEnabled: false,
                hasFriends: true
            )
        )
        // No buddy network — never prompt to share.
        #expect(
            !ActivityFriendSharePublishCheckpoint.showsBanner(
                checkpointPending: true,
                settingsConfigured: false,
                globalSharingEnabled: true,
                hasFriends: false
            )
        )
    }

    @Test func activityFriendSharePublishCheckpoint_visibleOnlyInLargeDetent() {
        #expect(
            ActivityFriendSharePublishCheckpoint.isVisibleInOverviewDetent(.large)
        )
        #expect(
            !ActivityFriendSharePublishCheckpoint.isVisibleInOverviewDetent(.minimized)
        )
    }

    @Test @MainActor func activityFriendSharePublishCheckpoint_dismissClearsPendingWithoutConfiguring() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let dive = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        dive.friendSharePublishCheckpointPending = true
        dive.friendShareBuddyDefaultsCaptured = true
        dive.friendShareActivityEnabled = false
        context.insert(dive)

        ActivityFriendSharePublishCheckpoint.dismiss(dive: dive, modelContext: context)
        #expect(!dive.friendSharePublishCheckpointPending)
        #expect(!dive.friendShareBuddySettingsConfigured)
        #expect(!dive.friendShareActivityEnabled)
    }

    @Test func activityFriendSharePublishCheckpoint_publishSelectedMediaIDs() {
        let galleryIDs = [UUID(), UUID(), UUID()]
        #expect(
            ActivityFriendSharePublishCheckpoint.publishSelectedMediaIDs(
                mediaEnabled: true,
                galleryIDs: galleryIDs
            ) == Set(galleryIDs)
        )
        #expect(
            ActivityFriendSharePublishCheckpoint.publishSelectedMediaIDs(
                mediaEnabled: false,
                galleryIDs: galleryIDs
            ).isEmpty
        )
    }

    @Test func activityPublishCheckpointBanner_promptCopyPerActivityKind() {
        #expect(
            ActivityPublishCheckpointBannerPresentation.promptTitle(activityKind: .scubaDive)
                == "This dive is local only"
        )
        #expect(
            ActivityPublishCheckpointBannerPresentation.promptTitle(activityKind: .snorkel)
                == "This snorkel is local only"
        )
        #expect(
            ActivityPublishCheckpointBannerPresentation.compactPromptLine(activityKind: .scubaDive)
                == "This dive is local only — share with buddies when ready."
        )
        #expect(
            ActivityPublishCheckpointBannerPresentation.compactPromptLine(activityKind: .snorkel)
                == "This snorkel is local only — share with buddies when ready."
        )
    }

    @Test func buddyActivityPushSignal_shouldRecordOnlyOnFirstProjectionCreate() {
        #expect(
            GoDiveBuddyActivityPushSignalSync.shouldRecordPushSignal(
                projectionAlreadyExisted: false,
                pushSignalAlreadyRecorded: false
            )
        )
        // Media / notes republish after projection exists — no second push.
        #expect(
            !GoDiveBuddyActivityPushSignalSync.shouldRecordPushSignal(
                projectionAlreadyExisted: true,
                pushSignalAlreadyRecorded: false
            )
        )
        // Projection recreated after signal already recorded — still no second push.
        #expect(
            !GoDiveBuddyActivityPushSignalSync.shouldRecordPushSignal(
                projectionAlreadyExisted: false,
                pushSignalAlreadyRecorded: true
            )
        )
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

    // MARK: - Buddy activity shared push notifications

    @Test func buddyActivityPush_target_parsesValidPayload() {
        let target = GoDiveBuddyActivityPushPresentation.target(fromUserInfo: [
            "type": "buddy_activity_shared",
            "friendUID": " friend-uid ",
            "activityID": "activity-123",
            "activityCount": "3",
        ])
        #expect(target?.friendUID == "friend-uid")
        #expect(target?.activityID == "activity-123")
    }

    @Test func buddyActivityPush_target_rejectsWrongTypeOrMissingKeys() {
        #expect(
            GoDiveBuddyActivityPushPresentation.target(fromUserInfo: [
                "type": "friend_invite_accepted",
                "friendUID": "friend-uid",
                "activityID": "activity-123",
            ]) == nil
        )
        #expect(
            GoDiveBuddyActivityPushPresentation.target(fromUserInfo: [
                "type": "buddy_activity_shared",
                "friendUID": "friend-uid",
            ]) == nil
        )
        #expect(
            GoDiveBuddyActivityPushPresentation.target(fromUserInfo: [
                "type": "buddy_activity_shared",
                "friendUID": "  ",
                "activityID": "activity-123",
            ]) == nil
        )
    }

    @Test func buddyActivityPush_notificationCopy_singleAndBatched() {
        #expect(
            GoDiveBuddyActivityPushPresentation.notificationBody(
                posterDisplayName: "Dre",
                activityCount: 1,
                singleActivityKind: .scubaDive
            ) == "Dre logged a new dive."
        )
        #expect(
            GoDiveBuddyActivityPushPresentation.notificationBody(
                posterDisplayName: "Dre",
                activityCount: 1,
                singleActivityKind: .snorkel
            ) == "Dre logged a new snorkel."
        )
        #expect(
            GoDiveBuddyActivityPushPresentation.notificationBody(
                posterDisplayName: "  ",
                activityCount: 4,
                singleActivityKind: .scubaDive
            ) == "A dive buddy shared 4 new activities."
        )
        #expect(GoDiveBuddyActivityPushPresentation.notificationTitle(activityCount: 1) == "New buddy activity")
        #expect(GoDiveBuddyActivityPushPresentation.notificationTitle(activityCount: 5) == "New buddy activities")
    }

    @Test func buddyActivityPush_taggedYouNotificationCopy_singleAndBatched() {
        #expect(
            GoDiveBuddyActivityPushPresentation.taggedYouNotificationBody(
                posterDisplayName: "Dre",
                taggedActivityCount: 1,
                singleActivityKind: .scubaDive
            ) == "Dre tagged you in a new dive."
        )
        #expect(
            GoDiveBuddyActivityPushPresentation.taggedYouNotificationBody(
                posterDisplayName: "Dre",
                taggedActivityCount: 1,
                singleActivityKind: .snorkel
            ) == "Dre tagged you in a new snorkel."
        )
        #expect(
            GoDiveBuddyActivityPushPresentation.taggedYouNotificationBody(
                posterDisplayName: "  ",
                taggedActivityCount: 3,
                singleActivityKind: .scubaDive
            ) == "A dive buddy tagged you in 3 new activities."
        )
        #expect(
            GoDiveBuddyActivityPushPresentation.taggedYouNotificationTitle(taggedActivityCount: 1)
                == "Tagged in a buddy activity"
        )
        #expect(
            GoDiveBuddyActivityPushPresentation.taggedYouNotificationTitle(taggedActivityCount: 2)
                == "Tagged in buddy activities"
        )
    }

    @Test func buddyActivityPush_latestActivityID_picksLatestStartTime() {
        let latest = GoDiveBuddyActivityPushPresentation.latestActivityID(from: [
            (id: "older", startTime: Date(timeIntervalSince1970: 1_700_000_000)),
            (id: "newest", startTime: Date(timeIntervalSince1970: 1_700_100_000)),
            (id: "middle", startTime: Date(timeIntervalSince1970: 1_700_050_000)),
        ])
        #expect(latest == "newest")

        // Missing start times lose to dated activities; later queue position wins ties.
        let withNil = GoDiveBuddyActivityPushPresentation.latestActivityID(from: [
            (id: "dated", startTime: Date(timeIntervalSince1970: 1_700_000_000)),
            (id: "undated", startTime: nil),
        ])
        #expect(withNil == "dated")
        #expect(GoDiveBuddyActivityPushPresentation.latestActivityID(from: []) == nil)
    }

    @Test func buddyActivityPush_buddyFeedContainsRow_matchesFriendAndDocument() {
        let dive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
            id: "shared-dive-1",
            activityKind: .scubaDive,
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
        let rows = [
            LogbookBuddyFeedPresentation.Row(
                id: "friend-a-shared-dive-1",
                friendUID: "friend-a",
                friendDisplayName: "Alex",
                friendPhotoURL: nil,
                dive: dive
            ),
        ]
        #expect(
            LogbookBuddyFeedPresentation.containsRow(
                in: rows,
                friendUID: "friend-a",
                diveDocumentID: "shared-dive-1"
            )
        )
        #expect(
            !LogbookBuddyFeedPresentation.containsRow(
                in: rows,
                friendUID: "friend-b",
                diveDocumentID: "shared-dive-1"
            )
        )
        #expect(
            !LogbookBuddyFeedPresentation.containsRow(
                in: rows,
                friendUID: "friend-a",
                diveDocumentID: "other-dive"
            )
        )
    }

    @Test @MainActor func buddyActivityPush_navigationStore_consumeClearsPending() {
        let store = GoDiveBuddyActivityPushNavigationStore.shared
        store.clear()
        #expect(store.consumePendingTarget() == nil)

        store.setPending(
            GoDiveBuddyActivityPushPresentation.Target(
                friendUID: "friend-a",
                activityID: "activity-1"
            )
        )
        let consumed = store.consumePendingTarget()
        #expect(consumed?.friendUID == "friend-a")
        #expect(consumed?.activityID == "activity-1")
        #expect(store.consumePendingTarget() == nil)
    }

    // MARK: - Home notifications page (bell)

    private func makeNotificationTestDive(
        id: String,
        kind: FriendSharedActivityKind = .scubaDive,
        startTime: Date?,
        updatedAt: Date? = nil,
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
            updatedAt: updatedAt
        )
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

    @Test func homeNotifications_activityDate_prefersUpdatedAtOverStartTime() {
        let updated = Date(timeIntervalSince1970: 1_700_200_000)
        let dive = makeNotificationTestDive(
            id: "d",
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: updated
        )
        #expect(HomeNotificationsPresentation.activityDate(for: dive) == updated)

        let startOnly = makeNotificationTestDive(
            id: "d2",
            startTime: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(
            HomeNotificationsPresentation.activityDate(for: startOnly)
                == Date(timeIntervalSince1970: 1_700_000_000)
        )
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

    @Test func buddyActivityPush_notifyPreferenceDefaultsOn() {
        let defaults = UserDefaults(suiteName: "buddyActivityPushPrefTests")!
        defaults.removePersistentDomain(forName: "buddyActivityPushPrefTests")
        #expect(AppUserSettings.notifyBuddyActivityShares(userDefaults: defaults))

        defaults.set(false, forKey: AppUserSettings.notifyBuddyActivitySharesKey)
        #expect(!AppUserSettings.notifyBuddyActivityShares(userDefaults: defaults))

        defaults.set(true, forKey: AppUserSettings.notifyBuddyActivitySharesKey)
        #expect(AppUserSettings.notifyBuddyActivityShares(userDefaults: defaults))
        defaults.removePersistentDomain(forName: "buddyActivityPushPrefTests")
    }

    @Test func buddyActivityPush_shouldNotifyFirstShareableProjection_matchesServerGate() {
        #expect(
            GoDiveBuddyActivityPushPresentation.shouldNotifyFirstShareableProjection(
                beforeActivityKindRaw: nil,
                afterActivityKindRaw: FriendSharedActivityKind.scubaDive.rawValue
            )
        )
        #expect(
            !GoDiveBuddyActivityPushPresentation.shouldNotifyFirstShareableProjection(
                beforeActivityKindRaw: nil,
                afterActivityKindRaw: nil
            )
        )
        #expect(
            !GoDiveBuddyActivityPushPresentation.shouldNotifyFirstShareableProjection(
                beforeActivityKindRaw: nil,
                afterActivityKindRaw: "unknown"
            )
        )
        #expect(
            !GoDiveBuddyActivityPushPresentation.shouldNotifyFirstShareableProjection(
                beforeActivityKindRaw: FriendSharedActivityKind.scubaDive.rawValue,
                afterActivityKindRaw: FriendSharedActivityKind.snorkel.rawValue
            )
        )
        // Media-only ghost doc later gains projection — recovery notify.
        #expect(
            GoDiveBuddyActivityPushPresentation.shouldNotifyFirstShareableProjection(
                beforeActivityKindRaw: nil,
                afterActivityKindRaw: FriendSharedActivityKind.snorkel.rawValue
            )
        )
    }

    @Test func sharedDiveProjection_taggedBuddiesFirestoreRows_mapsFirebaseUid() {
        let rows = GoDiveSharedDiveProjectionMapping.taggedBuddiesFirestoreRows(
            from: [
                GoDiveSharedDiveProjectionMapping.TaggedBuddySnapshot(
                    displayName: "Kathleen",
                    firebaseUID: "uid-kathleen"
                ),
                GoDiveSharedDiveProjectionMapping.TaggedBuddySnapshot(
                    displayName: "Local Buddy",
                    firebaseUID: nil
                ),
            ]
        )
        #expect(rows.count == 2)
        #expect(rows[0]["displayName"] as? String == "Kathleen")
        #expect(rows[0]["firebaseUid"] as? String == "uid-kathleen")
        #expect(rows[1]["firebaseUid"] == nil)
    }
}
