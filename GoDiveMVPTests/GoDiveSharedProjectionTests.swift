//
//  GoDiveSharedProjectionTests.swift
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


struct GoDiveSharedProjectionTests {
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

        @Test func activityFriendSharePublishCheckpoint_seedNewSnorkelInheritsGlobalShare() {
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
            #expect(snorkel.friendShareActivityEnabled)
            #expect(!snorkel.friendSharePublishCheckpointPending)
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

        @Test func buddyActivityPush_deepLink_resolvesFeedOrDirectFetch() {
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
                LogbookBuddyFeedPushDeepLinkPresentation.row(
                    friendUID: "friend-a",
                    friendDisplayName: "Alex",
                    friendPhotoURL: nil,
                    dive: dive
                ),
            ]
            #expect(
                LogbookBuddyFeedPushDeepLinkPresentation.resolveAfterFeedLoad(
                    rows: rows,
                    friendUID: "friend-a",
                    diveDocumentID: "shared-dive-1"
                ) == .readyInFeed
            )
            #expect(
                LogbookBuddyFeedPushDeepLinkPresentation.resolveAfterFeedLoad(
                    rows: rows,
                    friendUID: "friend-a",
                    diveDocumentID: "missing"
                ) == .fetchDirectProjection
            )
            #expect(
                LogbookBuddyFeedPushDeepLinkPresentation.shouldRetryAfterMiss(
                    attemptIndex: 0,
                    maxAttempts: 5
                )
            )
            #expect(
                !LogbookBuddyFeedPushDeepLinkPresentation.shouldRetryAfterMiss(
                    attemptIndex: 4,
                    maxAttempts: 5
                )
            )
        }

        @Test func buddyActivityPush_deepLink_insertsRowAndExpandsDisplayedCount() {
            let older = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "older",
                activityKind: .scubaDive,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18,
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
            let newer = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                id: "newer",
                activityKind: .snorkel,
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 30,
                maxDepthMeters: 5,
                averageDepthMeters: nil,
                diveNumber: nil,
                siteName: "B",
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
            let existing = LogbookBuddyFeedPushDeepLinkPresentation.row(
                friendUID: "friend-a",
                friendDisplayName: "Alex",
                friendPhotoURL: nil,
                dive: older
            )
            let incoming = LogbookBuddyFeedPushDeepLinkPresentation.row(
                friendUID: "friend-a",
                friendDisplayName: "Alex",
                friendPhotoURL: nil,
                dive: newer
            )
            let merged = LogbookBuddyFeedPresentation.inserting(incoming, into: [existing])
            #expect(merged.count == 2)
            #expect(merged.first?.dive.id == "newer")
            #expect(
                LogbookBuddyFeedPresentation.displayedCountMakingTargetVisible(
                    rows: merged,
                    friendUID: "friend-a",
                    diveDocumentID: "older",
                    currentDisplayedCount: 1
                ) == 2
            )
            #expect(
                LogbookBuddyFeedPresentation.displayedCountMakingTargetVisible(
                    rows: merged,
                    friendUID: "friend-a",
                    diveDocumentID: "newer",
                    currentDisplayedCount: 1
                ) == 1
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

        @Test func sharedDiveProjection_shareTimestampPolicy_protectsFirstShareTime() {
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let start = Date(timeIntervalSince1970: 1_700_000_000)
            let priorUpdate = Date(timeIntervalSince1970: 1_750_000_000)

            var firstCreate: [String: Any] = ["updatedAt": Date(timeIntervalSince1970: 1)]
            GoDiveSharedDiveProjectionMapping.applyShareTimestampPolicy(
                to: &firstCreate,
                projectionAlreadyExists: false,
                bumpUpdatedAt: true,
                existingData: nil,
                activityStartTime: start,
                now: now
            )
            #expect(firstCreate["sharedAt"] as? Date == now)
            #expect(firstCreate["updatedAt"] as? Date == now)

            var republish: [String: Any] = ["updatedAt": now, "siteName": "Reef"]
            GoDiveSharedDiveProjectionMapping.applyShareTimestampPolicy(
                to: &republish,
                projectionAlreadyExists: true,
                bumpUpdatedAt: false,
                existingData: ["updatedAt": priorUpdate],
                activityStartTime: start,
                now: now
            )
            #expect(republish["updatedAt"] == nil)
            #expect(republish["sharedAt"] as? Date == start)

            var alreadyShared: [String: Any] = ["updatedAt": now]
            let originalShared = Date(timeIntervalSince1970: 1_720_000_000)
            GoDiveSharedDiveProjectionMapping.applyShareTimestampPolicy(
                to: &alreadyShared,
                projectionAlreadyExists: true,
                bumpUpdatedAt: false,
                existingData: ["sharedAt": originalShared, "updatedAt": priorUpdate],
                activityStartTime: start,
                now: now
            )
            #expect(alreadyShared["sharedAt"] == nil)
            #expect(alreadyShared["updatedAt"] == nil)
        }

        @Test func buddyActivityPush_notifyPreferenceDefaultsOn() {
            let defaults = UserDefaults(suiteName: "buddyActivityPushPrefTests")!
            defaults.removePersistentDomain(forName: "buddyActivityPushPrefTests")
            #expect(AppUserSettings.notifyBuddyActivityShares(userDefaults: defaults))

            defaults.set(false, forKey: AppUserSettings.notifyBuddyActivitySharesKey)
            #expect(!AppUserSettings.notifyBuddyActivityShares(userDefaults: defaults))

            defaults.set(true, forKey: AppUserSettings.notifyBuddyActivitySharesKey)
            #expect(AppUserSettings.notifyBuddyActivityShares(userDefaults: defaults))

            defaults.set(false, forKey: AppUserSettings.notifyAllNotificationsKey)
            #expect(!AppUserSettings.notifyBuddyActivityShares(userDefaults: defaults))
            #expect(AppUserSettings.notifyBuddyActivitySharesPreference(userDefaults: defaults))
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
            func friendShareProjection_encodesProfileTrackOffMainViaBackgroundContext() async throws {
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
                try context.save()

                let encoded = await DiveProfilePointStore.encodeMissingTrackBlobForSharing(
                    activityID: dive.id,
                    container: container
                )
                #expect(encoded != nil)
                #expect(!(encoded?.isEmpty ?? true))
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
            func friendShareProjection_encodesSwimTrackOffMainViaBackgroundContext() async throws {
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
                try context.save()

                let encoded = await SnorkelProfilePointStore.encodeMissingTrackBlobForSharing(
                    activityID: snorkel.id,
                    container: container
                )
                #expect(encoded != nil)
                #expect(!(encoded?.isEmpty ?? true))
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
            @Test func buddyActivityLikedPush_targetAndCopy() {
                let activityID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
                let info: [AnyHashable: Any] = [
                    "type": "buddy_activity_liked",
                    "friendUID": "liker-1",
                    "activityID": activityID.uuidString,
                    "activityKind": "snorkel",
                ]
                let target = GoDiveBuddyActivityLikedPushPresentation.target(fromUserInfo: info)
                #expect(target?.likerUID == "liker-1")
                #expect(target?.activityID == activityID)
                #expect(target?.activityKind == .snorkel)
                #expect(
                    GoDiveBuddyActivityLikedPushPresentation.logbookRoute(for: target!)
                        == .snorkelDetail(activityID)
                )
                #expect(
                    GoDiveBuddyActivityLikedPushPresentation.notificationBody(
                        likerDisplayName: "Sam",
                        activityKind: .scubaDive
                    ) == "Sam liked your dive."
                )
                #expect(
                    GoDiveBuddyActivityLikedPushPresentation.target(fromUserInfo: [
                        "type": "buddy_activity_shared",
                        "friendUID": "x",
                        "activityID": activityID.uuidString,
                    ]) == nil
                )
            }
            @Test func buddyActivityCommentsSheetTarget_keyboardFlagAffectsIdentity() {
                let base = BuddyActivityCommentsSheetTarget(
                    ownerUID: "owner",
                    activityID: "act",
                    seedCommentCount: 2,
                    activatesKeyboard: false
                )
                let withKeyboard = BuddyActivityCommentsSheetTarget(
                    ownerUID: "owner",
                    activityID: "act",
                    seedCommentCount: 2,
                    activatesKeyboard: true
                )
                #expect(base.id != withKeyboard.id)
                #expect(base.id.hasSuffix("_view"))
                #expect(withKeyboard.id.hasSuffix("_kb"))
                #expect(
                    BuddyActivityCommentsPresentation.composePlaceholder == "Add a comment…"
                )
                #expect(BuddyActivityCommentsPresentation.keyboardActivationDelayMilliseconds > 0)
                #expect(
                    BuddyActivityCommentsPresentation.openCommentsAfterNavigationDelayMilliseconds > 0
                )
                #expect(
                    BuddyActivityCommentsPresentation.shouldPresentCommentsOnAppear(
                        opensCommentsOnAppear: true,
                        alreadyConsumed: false
                    )
                )
                #expect(
                    !BuddyActivityCommentsPresentation.shouldPresentCommentsOnAppear(
                        opensCommentsOnAppear: true,
                        alreadyConsumed: true
                    )
                )
                #expect(
                    !BuddyActivityCommentsPresentation.shouldPresentCommentsOnAppear(
                        opensCommentsOnAppear: false,
                        alreadyConsumed: false
                    )
                )
                // Parent one-shot consume must block remounts (Map tab leave/return).
                #expect(
                    !BuddyActivityCommentsPresentation.shouldPresentCommentsOnAppear(
                        opensCommentsOnAppear: false,
                        alreadyConsumed: true
                    )
                )
            }
            @Test func buddyActivityMentionedPush_targetOwnedVsSharedRoutes() {
                let activityID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
                let info: [AnyHashable: Any] = [
                    "type": "buddy_activity_mentioned",
                    "friendUID": "author-1",
                    "ownerUID": "owner-9",
                    "activityID": activityID.uuidString,
                    "activityKind": "snorkel",
                ]
                let target = GoDiveBuddyActivityMentionedPushPresentation.target(fromUserInfo: info)
                #expect(target?.authorUID == "author-1")
                #expect(target?.ownerUID == "owner-9")
                #expect(target?.activityID == activityID)
                #expect(target?.activityKind == .snorkel)
                #expect(
                    !GoDiveBuddyActivityMentionedPushPresentation.isOwnedActivity(
                        target: target!,
                        currentFirebaseUID: "someone-else"
                    )
                )
                #expect(
                    GoDiveBuddyActivityMentionedPushPresentation.isOwnedActivity(
                        target: target!,
                        currentFirebaseUID: "owner-9"
                    )
                )
                #expect(
                    GoDiveBuddyActivityMentionedPushPresentation.sharedLogbookRoute(for: target!)
                        == .buddySharedDive(
                            friendUID: "owner-9",
                            diveDocumentID: activityID.uuidString,
                            opensComments: true
                        )
                )
                #expect(
                    GoDiveBuddyActivityMentionedPushPresentation.ownedLogbookRoute(for: target!)
                        == .snorkelDetail(activityID)
                )
                #expect(
                    GoDiveBuddyActivityMentionedPushPresentation.notificationBody(
                        authorDisplayName: "Sam",
                        commentText: "  hey @you  "
                    ) == "Sam mentioned you in a comment: hey @you"
                )
                #expect(
                    GoDiveBuddyActivityMentionedPushPresentation.target(fromUserInfo: [
                        "type": "buddy_activity_commented",
                        "friendUID": "x",
                        "ownerUID": "y",
                        "activityID": activityID.uuidString,
                    ]) == nil
                )
            }
            @Test func buddyActivityCommentedPush_targetAndCopy() {
                let activityID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
                let info: [AnyHashable: Any] = [
                    "type": "buddy_activity_commented",
                    "friendUID": "author-1",
                    "activityID": activityID.uuidString,
                    "activityKind": "scubaDive",
                ]
                let target = GoDiveBuddyActivityCommentedPushPresentation.target(fromUserInfo: info)
                #expect(target?.authorUID == "author-1")
                #expect(target?.activityID == activityID)
                #expect(target?.activityKind == .scubaDive)
                #expect(
                    GoDiveBuddyActivityCommentedPushPresentation.logbookRoute(for: target!)
                        == .diveDetail(activityID)
                )
                #expect(
                    GoDiveBuddyActivityCommentedPushPresentation.notificationBody(
                        authorDisplayName: "Sam",
                        activityKind: .snorkel
                    ) == "Sam commented on your snorkel."
                )
                #expect(
                    GoDiveBuddyActivityCommentedPushPresentation.notificationBody(
                        authorDisplayName: "Sam",
                        activityKind: .scubaDive,
                        commentText: "  Nice   reef  "
                    ) == "Sam commented on your dive: Nice reef"
                )
                let longComment = String(
                    repeating: "a",
                    count: GoDiveBuddyActivityCommentedPushPresentation.commentPreviewMaxCharacters + 10
                )
                let preview = GoDiveBuddyActivityCommentedPushPresentation.commentNotificationPreview(
                    longComment
                )
                #expect(preview?.count == GoDiveBuddyActivityCommentedPushPresentation.commentPreviewMaxCharacters)
                #expect(preview?.hasSuffix("…") == true)
                #expect(
                    GoDiveBuddyActivityCommentedPushPresentation.notificationBody(
                        authorDisplayName: "Sam",
                        activityKind: .scubaDive,
                        commentText: longComment
                    ).contains(": \(preview!)")
                )
                let likedCompatible = GoDiveBuddyActivityCommentedPushPresentation.likedPushCompatibleTarget(
                    for: target!
                )
                #expect(likedCompatible.likerUID == "author-1")
                #expect(likedCompatible.activityID == activityID)
                #expect(
                    GoDiveBuddyActivityCommentedPushPresentation.target(fromUserInfo: [
                        "type": "buddy_activity_liked",
                        "friendUID": "x",
                        "activityID": activityID.uuidString,
                    ]) == nil
                )
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

                let slugSightings = GoDiveSharedDiveProjectionMapping.sightingSnapshotsForShare(
                    marineLifeUUIDs: ["marine-life-caribbean-reef-shark", ""],
                    commonNameByUUID: ["marine-life-caribbean-reef-shark": "Caribbean Reef Shark"],
                    scientificNameByUUID: ["marine-life-caribbean-reef-shark": "Carcharhinus perezii"]
                )
                #expect(slugSightings.count == 1)
                #expect(slugSightings[0].commonName == "Caribbean Reef Shark")
                #expect(slugSightings[0].scientificName == "Carcharhinus perezii")
                #expect(slugSightings[0].catalogUUID == "marine-life-caribbean-reef-shark")

                #expect(
                    GoDiveSharedDiveProjectionMapping.resolvedSightingCommonName(
                        storedCommonName: "marine-life-caribbean-reef-shark",
                        catalogUUID: "marine-life-caribbean-reef-shark",
                        commonNameByUUID: ["marine-life-caribbean-reef-shark": "Caribbean Reef Shark"]
                    ) == "Caribbean Reef Shark"
                )
                #expect(
                    GoDiveSharedDiveProjectionMapping.resolvedSightingCommonName(
                        storedCommonName: "marine-life-caribbean-reef-shark",
                        catalogUUID: "marine-life-caribbean-reef-shark",
                        commonNameByUUID: [:]
                    ) == "Species"
                )
                #expect(
                    GoDiveSharedDiveProjectionMapping.looksLikeMarineLifeCatalogUUID(
                        "marine-life-caribbean-reef-shark"
                    )
                )

                let slugDiveID = UUID()
                let slugDive = GoDiveSharedDiveProjectionMapping.FriendVisibleDive(
                    id: slugDiveID.uuidString,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18,
                    diveNumber: 1,
                    siteName: "Reef",
                    locationName: nil,
                    activityTagNames: [],
                    sightings: [
                        .init(
                            commonName: "marine-life-caribbean-reef-shark",
                            scientificName: nil,
                            catalogUUID: "marine-life-caribbean-reef-shark"
                        ),
                    ],
                    taggedBuddies: [],
                    equipmentSummary: [],
                    mediaPreviews: [],
                    profileTrackBase64: nil
                )
                let resolved = GoDiveSharedDiveProjectionMapping.withResolvedSightingNames(
                    slugDive,
                    commonNameByUUID: ["marine-life-caribbean-reef-shark": "Caribbean Reef Shark"]
                )
                #expect(resolved.sightings[0].commonName == "Caribbean Reef Shark")
                #expect(
                    FriendSharedActivityDetailPresentation.displayMarineLife(
                        from: slugDive,
                        commonNameByUUID: ["marine-life-caribbean-reef-shark": "Caribbean Reef Shark"]
                    ).first?.commonName == "Caribbean Reef Shark"
                )
                let stats = FriendProfileLifetimeStatsPresentation.build(
                    from: [slugDive],
                    commonNameByUUID: ["marine-life-caribbean-reef-shark": "Caribbean Reef Shark"]
                )
                #expect(stats.topSpecies?.commonName == "Caribbean Reef Shark")
            }
            @Test func sharedDiveRepublish_doesNotWipeWhenSharingOnButFriendsUnavailable() {
                #expect(
                    GoDiveSharedDiveProjectionSync.republishDecision(
                        shareDivesWithFriendsEnabled: false,
                        canPublishToFriends: false
                    ) == .wipeAllBecauseSharingDisabled
                )
                #expect(
                    GoDiveSharedDiveProjectionSync.republishDecision(
                        shareDivesWithFriendsEnabled: true,
                        canPublishToFriends: false
                    ) == .skipLeavingRemoteIntact
                )
                #expect(
                    GoDiveSharedDiveProjectionSync.republishDecision(
                        shareDivesWithFriendsEnabled: true,
                        canPublishToFriends: true
                    ) == .publishOwned
                )
            }
            @Test func sharedDivePushSignal_hydratesLocalFlagFromExistingRemoteProjections() {
                let sharedID = UUID()
                let localOnlyID = UUID()
                let alreadyFlaggedID = UUID()
                let needing = GoDiveSharedDiveProjectionSync.activityIDsNeedingPushSignalHydration(
                    remoteProjectionIDs: [sharedID, alreadyFlaggedID],
                    localActivities: [
                        (sharedID, false),
                        (localOnlyID, false),
                        (alreadyFlaggedID, true),
                    ]
                )
                #expect(needing == [sharedID])
            }
}
