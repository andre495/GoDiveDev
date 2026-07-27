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
            mediaPreviews: [.init(photoID: "p1", previewURL: "https://example.com/p.jpg")]
        )

        let withoutOptIn = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: .init(includeNotes: false, includeMedia: false)
        )
        #expect(withoutOptIn["notes"] as? String == nil)
        #expect(withoutOptIn["mediaPreviews"] == nil)
        #expect(withoutOptIn["siteName"] as? String == "Blue Hole")
        #expect(withoutOptIn["activityKind"] as? String == FriendSharedActivityKind.scubaDive.rawValue)
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
        let chartSeries = GoDiveSharedDiveProjectionMapping.decodedDepthChartSeries(from: parsed)
        #expect(chartSeries.depthSamples.count >= 2)
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
            dive: baseDive
        )
        var withTrack = baseDive
        withTrack.profileTrackBase64 = "dHJhY2s="
        let right = LogbookBuddyFeedPresentation.Row(
            id: "friend_dive-1",
            friendUID: "friend",
            friendDisplayName: "Sam",
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
}
