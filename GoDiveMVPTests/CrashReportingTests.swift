//
//  CrashReportingTests.swift
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

struct CrashReportingTests {

    private func makeInMemoryStore(cap: Int = 20) throws -> CrashReportStore {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        return CrashReportStore(container: container, maxStoredReports: cap)
    }

    private func makeReport(capturedAt: Date, reason: String = "SIGABRT") -> CrashReport {
        CrashReport(
            capturedAt: capturedAt,
            kind: .metricKitCrash,
            reason: reason,
            appVersion: "1.0 (42)",
            osVersion: "iOS 26.0",
            details: "stack"
        )
    }

    @Test func crashReportStore_saveLoadRoundTrip_newestFirst() throws {
        let store = try makeInMemoryStore()

        let older = makeReport(capturedAt: Date(timeIntervalSince1970: 100), reason: "older")
        let newer = makeReport(capturedAt: Date(timeIntervalSince1970: 200), reason: "newer")
        try store.save(older)
        try store.save(newer)

        let loaded = store.loadAll()
        #expect(loaded.count == 2)
        #expect(loaded.first?.reason == "newer")
        #expect(loaded.last == older)
    }

    @Test func crashReportStore_prunesToNewestReportsBeyondCap() throws {
        let store = try makeInMemoryStore(cap: 3)

        for second in 1...5 {
            try store.save(makeReport(capturedAt: Date(timeIntervalSince1970: Double(second)), reason: "r\(second)"))
        }

        let loaded = store.loadAll()
        #expect(loaded.count == 3)
        #expect(loaded.map(\.reason) == ["r5", "r4", "r3"])
    }

    @Test func crashReportStore_pendingCloudShareAndMarkShared() throws {
        let store = try makeInMemoryStore()
        let first = makeReport(capturedAt: Date(timeIntervalSince1970: 100), reason: "first")
        let second = makeReport(capturedAt: Date(timeIntervalSince1970: 200), reason: "second")
        try store.save(first)
        try store.save(second)

        // Pending uploads run oldest first.
        #expect(store.pendingCloudShare().map(\.reason) == ["first", "second"])

        let sharedAt = Date(timeIntervalSince1970: 300)
        store.markShared(id: first.id, at: sharedAt)
        #expect(store.pendingCloudShare().map(\.reason) == ["second"])
        #expect(store.loadAll().last?.sharedToCloudAt == sharedAt)
    }

    @Test func crashReportStore_deleteAllRemovesEverything() throws {
        let store = try makeInMemoryStore()
        try store.save(makeReport(capturedAt: Date(timeIntervalSince1970: 100)))
        try store.save(makeReport(capturedAt: Date(timeIntervalSince1970: 200)))

        store.deleteAll()
        #expect(store.loadAll().isEmpty)
    }

    @Test func securityEventStore_saveLoadRoundTrip_newestFirstAndOwnerScoped() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let store = SecurityEventStore(container: container, maxStoredEvents: 20)
        let ownerA = UUID()
        let ownerB = UUID()

        let older = SecurityEvent(
            capturedAt: Date(timeIntervalSince1970: 100),
            kindRaw: GoDiveSecurityEvent.Kind.authSucceeded.rawValue,
            detail: "apple",
            appVersion: "1.0",
            osVersion: "iOS 26",
            ownerProfileID: ownerA
        )
        let newer = SecurityEvent(
            capturedAt: Date(timeIntervalSince1970: 200),
            kindRaw: GoDiveSecurityEvent.Kind.importRejected.rawValue,
            detail: "fit.contentTypeMismatch",
            appVersion: "1.0",
            osVersion: "iOS 26",
            ownerProfileID: ownerA
        )
        let otherOwner = SecurityEvent(
            capturedAt: Date(timeIntervalSince1970: 300),
            kindRaw: GoDiveSecurityEvent.Kind.signOut.rawValue,
            appVersion: "1.0",
            osVersion: "iOS 26",
            ownerProfileID: ownerB
        )
        try store.save(older)
        try store.save(newer)
        try store.save(otherOwner)

        let loaded = store.loadAll(ownerProfileID: ownerA)
        #expect(loaded.count == 2)
        #expect(loaded.first?.kindRaw == newer.kindRaw)
        #expect(loaded.last?.id == older.id)
        #expect(store.loadAll(ownerProfileID: ownerB).map(\.id) == [otherOwner.id])
    }

    @Test func securityEventStore_prunesToNewestBeyondCap_perOwner() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let store = SecurityEventStore(container: container, maxStoredEvents: 3)
        let owner = UUID()

        for second in 1...5 {
            try store.save(
                SecurityEvent(
                    capturedAt: Date(timeIntervalSince1970: Double(second)),
                    kindRaw: GoDiveSecurityEvent.Kind.authFailed.rawValue,
                    detail: "e\(second)",
                    appVersion: "1.0",
                    osVersion: "iOS 26",
                    ownerProfileID: owner
                )
            )
        }

        let loaded = store.loadAll(ownerProfileID: owner)
        #expect(loaded.count == 3)
        #expect(loaded.compactMap(\.detail) == ["e5", "e4", "e3"])
    }

    @Test func securityEventStore_pendingCloudShareAndMarkShared() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let store = SecurityEventStore(container: container)
        let owner = UUID()
        let first = SecurityEvent(
            capturedAt: Date(timeIntervalSince1970: 100),
            kindRaw: GoDiveSecurityEvent.Kind.cdnChecksumMismatch.rawValue,
            detail: "marineLife",
            appVersion: "1.0",
            osVersion: "iOS 26",
            ownerProfileID: owner
        )
        let second = SecurityEvent(
            capturedAt: Date(timeIntervalSince1970: 200),
            kindRaw: GoDiveSecurityEvent.Kind.cdnRefreshFailed.rawValue,
            detail: "diveSites",
            appVersion: "1.0",
            osVersion: "iOS 26",
            ownerProfileID: owner
        )
        try store.save(first)
        try store.save(second)

        #expect(store.pendingCloudShare(ownerProfileID: owner).map(\.detail) == ["marineLife", "diveSites"])

        let sharedAt = Date(timeIntervalSince1970: 300)
        store.markShared(id: first.id, at: sharedAt)
        #expect(store.pendingCloudShare(ownerProfileID: owner).map(\.detail) == ["diveSites"])
        #expect(store.loadAll(ownerProfileID: owner).last?.sharedToCloudAt == sharedAt)
    }

    @Test func securityEventCloudUploader_makeRecord_mapsFieldsWithoutOwnerID() {
        let event = SecurityEvent(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            capturedAt: Date(timeIntervalSince1970: 100),
            kindRaw: GoDiveSecurityEvent.Kind.authFailed.rawValue,
            detail: "firebase",
            appVersion: "1.0 (42)",
            osVersion: "iOS 26.0",
            ownerProfileID: UUID()
        )
        let record = SecurityEventCloudUploader.makeRecord(for: event)
        #expect(record.recordType == SecurityEventCloudUploader.recordType)
        #expect(record.recordID.recordName == event.id.uuidString)
        #expect(record["capturedAt"] as? Date == event.capturedAt)
        #expect(record["kind"] as? String == event.kindRaw)
        #expect(record["detail"] as? String == "firebase")
        #expect(record["appVersion"] as? String == event.appVersion)
        #expect(record["osVersion"] as? String == event.osVersion)
        #expect(record["ownerProfileID"] == nil)
    }

    @Test func securityEventCloudUploader_makeRecord_scrubsPIIFromDetail() {
        let event = SecurityEvent(
            capturedAt: Date(timeIntervalSince1970: 100),
            kindRaw: GoDiveSecurityEvent.Kind.importRejected.rawValue,
            detail: "diver@example.com Authorization: Bearer abcdefghijklmnopqrstuvwxyz012345",
            appVersion: "1.0",
            osVersion: "iOS 26",
            ownerProfileID: UUID()
        )
        let record = SecurityEventCloudUploader.makeRecord(for: event)
        let detail = record["detail"] as? String ?? ""
        #expect(!detail.contains("diver@example.com"))
        #expect(!detail.contains("abcdefghijklmnopqrstuvwxyz012345"))
    }

    @Test func securityEventPresentation_exportTextIncludesKindAndSharedStatus() {
        let event = SecurityEvent(
            capturedAt: Date(timeIntervalSince1970: 100),
            kindRaw: GoDiveSecurityEvent.Kind.signOut.rawValue,
            appVersion: "1.0",
            osVersion: "iOS 26",
            ownerProfileID: UUID()
        )
        let text = SecurityEventPresentation.exportText(for: event)
        #expect(text.contains("Signed out"))
        #expect(text.contains("Not sent to developer"))
        #expect(SettingsPresentation.SecurityEvents.title == "Diagnostic Events")
        #expect(SettingsPresentation.ShareSecurityEvents.title == "Share diagnostic events")
    }

    @Test func crashReportCloudUploader_makeRecord_mapsFields() {
        let report = makeReport(capturedAt: Date(timeIntervalSince1970: 100), reason: "SIGSEGV")
        let record = CrashReportCloudUploader.makeRecord(for: report, detailsAssetFileURL: nil)

        #expect(record.recordType == CrashReportCloudUploader.recordType)
        #expect(record.recordID.recordName == report.id.uuidString)
        #expect(record["capturedAt"] as? Date == report.capturedAt)
        #expect(record["kind"] as? String == CrashReport.Kind.metricKitCrash.rawValue)
        #expect(record["reason"] as? String == "SIGSEGV")
        #expect(record["appVersion"] as? String == report.appVersion)
        #expect(record["osVersion"] as? String == report.osVersion)
        #expect(record["details"] as? String == "stack")
        #expect(record["detailsAsset"] == nil)
    }

    @Test func crashReportCloudUploader_makeRecord_scrubsPIIFromCloudPayload() {
        let report = CrashReport(
            capturedAt: Date(timeIntervalSince1970: 100),
            kind: .abnormalExit,
            reason: "lat: 12.345678 crash",
            appVersion: "1.0",
            osVersion: "iOS 26",
            details: """
            diver@example.com
            Authorization: Bearer abcdefghijklmnopqrstuvwxyz012345
            gps 12.345678, -68.210123
            notes: secret reef name
            path /Users/andrdugas/Library/foo.db
            """
        )
        let record = CrashReportCloudUploader.makeRecord(for: report, detailsAssetFileURL: nil)
        let reason = record["reason"] as? String ?? ""
        let details = record["details"] as? String ?? ""
        #expect(!reason.contains("12.345678"))
        #expect(!details.contains("diver@example.com"))
        #expect(!details.contains("abcdefghijklmnopqrstuvwxyz012345"))
        #expect(details.contains("Bearer <redacted>"))
        #expect(!details.contains("12.345678"))
        #expect(details.contains("notes: <redacted>"))
        #expect(!details.contains("/Users/andrdugas"))
    }

    @Test func crashReportPayloadScrubber_redactsSensitiveFragments() {
        let scrubbed = CrashReportPayloadScrubber.scrub(
            "email me@godive.test token Bearer secret-token-value-here coords 9.123456, -79.654321"
        )
        #expect(!scrubbed.contains("me@godive.test"))
        #expect(scrubbed.contains("Bearer <redacted>"))
        #expect(!scrubbed.contains("9.123456"))
    }

    @Test func crashReportCloudUploader_usesDetailsAsset_onlyForOversizedBodies() {
        var small = makeReport(capturedAt: Date(timeIntervalSince1970: 0))
        small.details = "short"
        #expect(!CrashReportCloudUploader.usesDetailsAsset(for: small))

        var large = small
        large.details = String(
            repeating: "x",
            count: CrashReportCloudUploader.inlineDetailsCharacterLimit + 1
        )
        #expect(CrashReportCloudUploader.usesDetailsAsset(for: large))
    }

    @Test func appUserSettings_shareCrashReports_defaultsOff() {
        let defaults = UserDefaults(suiteName: "CrashReportingTests-\(UUID().uuidString)")!
        #expect(GoDiveReleaseConfigurationGates.isCrashShareDefaultOff(userDefaults: defaults))
        AppUserSettings.registerDefaultValues(in: defaults)
        #expect(!AppUserSettings.shareCrashReports(userDefaults: defaults))
    }

    @Test func appUserSettings_shareSecurityEvents_defaultsOff() {
        let defaults = UserDefaults(suiteName: "SecurityEventShareTests-\(UUID().uuidString)")!
        #expect(GoDiveReleaseConfigurationGates.isSecurityEventShareDefaultOff(userDefaults: defaults))
        AppUserSettings.registerDefaultValues(in: defaults)
        #expect(!AppUserSettings.shareSecurityEvents(userDefaults: defaults))
    }

    @Test func goDiveReleaseConfigurationGates_uiTestInactiveWithoutFlags() {
        #expect(
            !GoDiveReleaseConfigurationGates.uiTestWouldBeActive(
                arguments: [],
                environment: [:]
            )
        )
        #expect(
            GoDiveReleaseConfigurationGates.uiTestWouldBeActive(
                arguments: [GoDiveUITestConfiguration.launchArgument],
                environment: [:]
            )
        )
    }

    @Test func tripShareTempFilePolicy_requiresTemporaryDirectory() {
        let url = TripShareCardPresentation.temporaryPNGURL(tripTitle: "Bonaire")
        #expect(TripShareTempFilePolicy.isUnderTemporaryDirectory(url))
        #expect(TripShareTempFilePolicy.shareItemIsFileURLNotPathString(url))
        #expect(!TripShareTempFilePolicy.isUnderTemporaryDirectory(URL(fileURLWithPath: "/System")))
    }

    @Test func goDiveFileBackupPolicy_excludesDiagnosticsFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoDiveBackupPolicy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("cloudkit-open-diagnostics.txt")
        try "probe".write(to: file, atomically: true, encoding: .utf8)
        GoDiveFileBackupPolicy.excludeFromBackup(file)
        let values = try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
        #expect(GoDiveDataProtectionPolicy.diagnosticsStoreExcludedFromBackup)
    }

    @Test func crashSessionMarker_abnormalExit_onlyWhenForeground() {
        let foreground = CrashSessionMarker.indicatesAbnormalExit(previousState: .foreground)
        let background = CrashSessionMarker.indicatesAbnormalExit(previousState: .background)
        let missing = CrashSessionMarker.indicatesAbnormalExit(previousState: nil)
        #expect(foreground)
        #expect(!background)
        #expect(!missing)
    }

    @Test func crashReportPresentation_metricKitReasonLine_namesSignalsAndExceptions() {
        #expect(
            CrashReportPresentation.metricKitReasonLine(
                exceptionType: 1,
                signal: 11,
                terminationReason: "Namespace SIGNAL"
            ) == "EXC_BAD_ACCESS · SIGSEGV · Namespace SIGNAL"
        )
        #expect(
            CrashReportPresentation.metricKitReasonLine(
                exceptionType: nil,
                signal: nil,
                terminationReason: nil
            ) == "Crash (no diagnostic detail)"
        )
        #expect(CrashReportPresentation.signalName(99) == "signal 99")
        #expect(CrashReportPresentation.machExceptionName(99) == "exception 99")
    }

    @Test func crashReportPresentation_exportText_coversEmptyAndPopulated() {
        #expect(CrashReportPresentation.exportText(for: []) == "No crash reports recorded.")

        let report = makeReport(capturedAt: Date(timeIntervalSince1970: 0), reason: "SIGSEGV")
        let text = CrashReportPresentation.exportText(for: report)
        #expect(text.contains("SIGSEGV"))
        #expect(text.contains("1.0 (42)"))
        #expect(text.contains("stack"))
    }

    @Test func crashReportPresentation_kindLabels() {
        #expect(CrashReportPresentation.kindLabel(.metricKitCrash) == "Crash")
        #expect(CrashReportPresentation.kindLabel(.abnormalExit) == "Abnormal exit")
    }

    @Test func crashReportPresentation_sharedStatusLabel() {
        #expect(CrashReportPresentation.sharedStatusLabel(sharedToCloudAt: nil) == "Not sent to developer")
        #expect(
            CrashReportPresentation.sharedStatusLabel(sharedToCloudAt: Date(timeIntervalSince1970: 0))
                == "Sent to developer"
        )
    }

    @Test func crashBreadcrumbTrail_keepsOnlyNewestEntries() {
        let defaults = UserDefaults(suiteName: "CrashBreadcrumbTrail-\(UUID().uuidString)")!
        CrashBreadcrumbTrail.resetForTests(userDefaults: defaults)

        for index in 1...(CrashBreadcrumbTrail.maxEntries + 5) {
            CrashBreadcrumbTrail.record("step \(index)", userDefaults: defaults)
        }

        let entries = CrashBreadcrumbTrail.loadEntriesForTests(userDefaults: defaults)
        #expect(entries.count == CrashBreadcrumbTrail.maxEntries)
        #expect(entries.first?.message == "step 6")
        #expect(entries.last?.message == "step \(CrashBreadcrumbTrail.maxEntries + 5)")
    }

    @Test func crashBreadcrumbTrail_freezePreservesPreviousSessionExport() {
        let defaults = UserDefaults(suiteName: "CrashBreadcrumbTrail-Freeze-\(UUID().uuidString)")!
        CrashBreadcrumbTrail.resetForTests(userDefaults: defaults)
        CrashBreadcrumbTrail.noteRootTab(.logbook, userDefaults: defaults)
        CrashBreadcrumbTrail.record("before freeze", userDefaults: defaults)

        CrashBreadcrumbTrail.freezePreviousSessionAndBeginNew(userDefaults: defaults)
        let frozen = CrashBreadcrumbTrail.previousSessionExportPlainText(userDefaults: defaults)
        #expect(frozen?.contains("rootTab → logbook") == true)
        #expect(frozen?.contains("before freeze") == true)
        #expect(CrashBreadcrumbTrail.loadEntriesForTests(userDefaults: defaults).isEmpty)
        #expect(CrashBreadcrumbTrail.loadContextForTests(userDefaults: defaults) == nil)

        CrashBreadcrumbTrail.record("after freeze", userDefaults: defaults)
        #expect(CrashBreadcrumbTrail.loadEntriesForTests(userDefaults: defaults).map(\.message) == ["after freeze"])
        #expect(
            CrashBreadcrumbTrail.previousSessionExportPlainText(userDefaults: defaults)?
                .contains("before freeze") == true
        )
        // Live export after freeze must not keep the dying session's UI context.
        let live = CrashBreadcrumbTrail.exportPlainText(userDefaults: defaults)
        #expect(!live.contains("rootTab: logbook"))
    }

    @Test func dictionary_godiveUniquingKeysWithValues_keepsLastOnDuplicateKeys() {
        let id = UUID()
        let first = DiveMediaPhoto(id: id, sortOrder: 0, mediaKind: .image, photosLocalIdentifier: "A")
        let second = DiveMediaPhoto(id: id, sortOrder: 1, mediaKind: .video, photosLocalIdentifier: "B")
        let map: [UUID: DiveMediaPhoto] = Dictionary(
            godiveUniquingKeysWithValues: [first, second].map { ($0.id, $0) }
        )
        #expect(map.count == 1)
        #expect(map[id]?.photosLocalIdentifier == "B")
        #expect(map[id]?.resolvedMediaKind == .video)
    }

    @Test func crashBreadcrumbTrail_formatExport_includesContextAndTrail() {
        let context = CrashBreadcrumbTrail.Context(
            rootTab: "logbook",
            screen: "diveOverview",
            diveActivityID: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            diveNumber: 12,
            diveActivityTab: "media",
            overviewDetent: "medium",
            presentedSheet: "tagBuddy",
            mediaCount: 4,
            selectedMediaID: "11111111-1111-1111-1111-111111111111",
            featuredMediaID: "22222222-2222-2222-2222-222222222222",
            selectedMediaKind: "image",
            overviewPanelPresented: true,
            orientation: "portrait",
            lastAction: "carouselSelect 11111111"
        )
        let entries = [
            CrashBreadcrumbTrail.Entry(at: Date(timeIntervalSince1970: 100), message: "rootTab → logbook"),
            CrashBreadcrumbTrail.Entry(at: Date(timeIntervalSince1970: 200), message: "action → carouselSelect 11111111"),
        ]
        let text = CrashBreadcrumbTrail.formatExport(
            context: context,
            entries: entries,
            processSnapshot: "uptimeSeconds: 1"
        )
        #expect(text.contains("## Last UI context"))
        #expect(text.contains("diveNumber: 12"))
        #expect(text.contains("diveActivityTab: media"))
        #expect(text.contains("mediaCount: 4"))
        #expect(text.contains("selectedMediaKind: image"))
        #expect(text.contains("orientation: portrait"))
        #expect(text.contains("lastAction: carouselSelect 11111111"))
        #expect(text.contains("presentedSheet: tagBuddy"))
        #expect(text.contains("action → carouselSelect 11111111"))
        #expect(text.contains("uptimeSeconds: 1"))
    }

    @Test func crashBreadcrumbTrail_noteDiveOverview_encodesMediaFields() {
        let defaults = UserDefaults(suiteName: "CrashBreadcrumbTrail-Dive-\(UUID().uuidString)")!
        CrashBreadcrumbTrail.resetForTests(userDefaults: defaults)
        let activityID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let selectedID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        CrashBreadcrumbTrail.noteDiveOverview(
            .init(
                activityID: activityID,
                diveNumber: 145,
                activityTab: .camera,
                detent: .large,
                mediaCount: 3,
                selectedMediaID: selectedID,
                featuredMediaID: selectedID,
                selectedMediaKind: "video",
                overviewPanelPresented: true,
                orientation: "portrait"
            ),
            userDefaults: defaults
        )
        let export = CrashBreadcrumbTrail.exportPlainText(userDefaults: defaults)
        #expect(export.contains("mediaCount: 3"))
        #expect(export.contains("selectedMediaKind: video"))
        #expect(export.contains("tab=media"))
        #expect(export.contains("kind=video"))
        #expect(export.contains("media=3"))
    }

    @Test func crashSessionMarker_lifecyclePreface_stopsBeforeSectionHeaders() {
        let details = """
        Last lifecycle state: foreground
        Marked at: 2026-07-15T20:44:01Z
        App version: 1.0 (1)

        ## Session context
        uptimeSeconds: 1
        """
        let preface = CrashSessionMarker.lifecyclePreface(from: details)
        #expect(preface.contains("Last lifecycle state: foreground"))
        #expect(preface.contains("Marked at:"))
        #expect(!preface.contains("## Session context"))
    }

    @Test func crashBreadcrumbTrail_labelHelpers() {
        #expect(CrashBreadcrumbTrail.rootTabLabel(.fieldGuide) == "fieldGuide")
        #expect(CrashBreadcrumbTrail.diveActivityTabLabel(.camera) == "media")
    }

    // MARK: - Hybrid cloud sync Phase 1

    @Test func appSwiftDataStorePartition_coversEveryModelExactlyOnce() {
        #expect(AppSwiftDataCloudKitCompatibility.partitionCoverageIssues().isEmpty)
        #expect(AppSwiftDataStorePartition.userModelTypeNames.contains("DiveActivity"))
        #expect(!AppSwiftDataStorePartition.userModelTypeNames.contains("DiveProfilePoint"))
        #expect(AppSwiftDataStorePartition.userLocalModelTypeNames.contains("DiveProfilePoint"))
        #expect(AppSwiftDataStorePartition.catalogModelTypeNames.contains("MarineLife"))
        #expect(AppSwiftDataStorePartition.catalogModelTypeNames.contains("DiveSite"))
        #expect(AppSwiftDataStorePartition.diagnosticsModelTypeNames.contains("CrashReportRecord"))
        #expect(AppSwiftDataStorePartition.catalogCDNVendor.contains("Firebase"))
    }

    @Test func appSwiftDataSchema_keepsCloudKitDisabled() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        #expect(container.configurations.count == 1)
        #expect(
            AppSwiftDataCloudKitCompatibility.removedUniqueAttributeKeys.contains("MarineLife.uuid")
        )
        #expect(
            AppSwiftDataCloudKitCompatibility.removedUniqueAttributeKeys.contains("SightingInstance.sightingUUID")
        )
        #expect(
            AppSwiftDataCloudKitCompatibility.removedCodableAttributeKeys.contains("DiveActivity.entryCoordinate")
        )
        #expect(AppSwiftDataCloudKitCompatibility.pendingCrossStoreRelationshipBreaks.isEmpty)
        #expect(AppSwiftDataStorePartition.userModelTypeNames.contains("UserMarineLife"))
        #expect(AppSwiftDataStorePartition.userModelTypeNames.contains("UserDiveSite"))
        #expect(AppSwiftDataStorePartition.userModelTypeNames.contains("UserPreferences"))
        #expect(AppSwiftDataStorePartition.userModelTypeNames.contains("SecurityEventRecord"))
        #expect(AppSwiftDataStorePartition.syncedPreferenceKeys.contains(AppUserSettings.useImperialDisplayUnitsKey))
        #expect(
            AppSwiftDataStorePartition.syncedPreferenceKeys.contains(
                AppUserSettings.contributeCommunitySightingsKey
            )
        )
        #expect(AppSwiftDataStorePartition.localOnlyPreferenceKeys.contains(AppUserSettings.shareCrashReportsKey))
        #expect(AppSwiftDataStorePartition.localOnlyPreferenceKeys.contains(AppUserSettings.shareSecurityEventsKey))
        #expect(
            AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier
                == CrashReportCloudUploader.containerIdentifier
        )
        #expect(
            SecurityEventCloudUploader.containerIdentifier
                == CrashReportCloudUploader.containerIdentifier
        )
        _ = container
    }

    @Test @MainActor
    func userPreferencesSync_seedsFromUserDefaultsAndPullsBack() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "prefs-sync", displayName: "Diver")
        context.insert(owner)

        let suite = "goDive.prefsSync.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        AppUserSettings.registerDefaultValues(in: defaults)
        defaults.set(false, forKey: AppUserSettings.useImperialDisplayUnitsKey)
        defaults.set(DefaultTankSize.st100.rawValue, forKey: AppUserSettings.defaultTankSizeKey)
        defaults.set(false, forKey: AppUserSettings.automaticallyRenumberDivesKey)

        let created = try UserPreferencesSync.findOrCreate(
            for: owner,
            modelContext: context,
            userDefaults: defaults
        )
        #expect(created.didCreate)
        try context.save()

        let prefs = try context.fetch(FetchDescriptor<UserPreferences>()).first
        #expect(prefs?.useImperialDisplayUnits == false)
        #expect(prefs?.defaultTankSizeRaw == DefaultTankSize.st100.rawValue)
        #expect(prefs?.automaticallyRenumberDives == false)

        defaults.set(true, forKey: AppUserSettings.useImperialDisplayUnitsKey)
        try UserPreferencesSync.syncForSignedInOwner(owner, modelContext: context, userDefaults: defaults)
        #expect(defaults.bool(forKey: AppUserSettings.useImperialDisplayUnitsKey) == false)
        #expect(defaults.string(forKey: AppUserSettings.defaultTankSizeKey) == DefaultTankSize.st100.rawValue)
    }

    @Test @MainActor
    func userPreferencesSync_pushUserDefaultsUpdatesStore() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "prefs-push", displayName: "Diver")
        context.insert(owner)

        let suite = "goDive.prefsPush.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        AppUserSettings.registerDefaultValues(in: defaults)
        _ = try UserPreferencesSync.findOrCreate(for: owner, modelContext: context, userDefaults: defaults)

        defaults.set(false, forKey: AppUserSettings.autoUploadMediaToActivitiesKey)
        defaults.set(DefaultTankSize.al63.rawValue, forKey: AppUserSettings.defaultTankSizeKey)
        defaults.set(false, forKey: AppUserSettings.notifyGearServiceRemindersKey)
        defaults.set(false, forKey: AppUserSettings.notifyTripRemindersKey)
        try UserPreferencesSync.pushUserDefaultsToStore(
            owner: owner,
            modelContext: context,
            userDefaults: defaults
        )

        let prefs = try context.fetch(FetchDescriptor<UserPreferences>()).first
        #expect(prefs?.autoUploadMediaToActivities == false)
        #expect(prefs?.defaultTankSizeRaw == DefaultTankSize.al63.rawValue)
        #expect(prefs?.notifyGearServiceReminders == false)
        #expect(prefs?.notifyTripReminders == false)
    }

    @Test func appSwiftDataDualStoreFactory_phase2UserPrivateCloudKitPolicy() throws {
        #expect(
            AppSwiftDataCloudKitCompatibility.usesPhase2DualStoreCloudKitPolicy(
                user: AppSwiftDataCloudKitCompatibility.privateUserCloudKitDatabase,
                catalog: AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase,
                diagnostics: AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase
            )
        )
        #expect(
            !AppSwiftDataCloudKitCompatibility.usesPhase2DualStoreCloudKitPolicy(
                user: .none,
                catalog: .none,
                diagnostics: .none
            )
        )
        #expect(
            AppSwiftDataCloudKitCompatibility.cloudKitDatabaseDescription(
                AppSwiftDataCloudKitCompatibility.privateUserCloudKitDatabase
            ).contains(AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier)
        )

        let local = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
        #expect(!local.enableUserCloudKitSync)
        #expect(!local.didFallBackFromCloudKit)
        #expect(
            AppSwiftDataCloudKitCompatibility.isLocalOnlyCloudKitDatabase(
                local.userConfiguration.cloudKitDatabase
            )
        )
        #expect(
            AppSwiftDataCloudKitCompatibility.isLocalOnlyCloudKitDatabase(
                local.catalogConfiguration.cloudKitDatabase
            )
        )

        // On-disk with sync off (tests / migration copy). Opening with sync **on** is device QA —
        // unit hosts may lack a signed-in iCloud account.
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoDiveCKOff-\(UUID().uuidString)", isDirectory: true)
        let offline = try AppSwiftDataDualStoreFactory.makeOnDiskSplitContainer(
            rootDirectory: temp,
            enableUserCloudKitSync: false
        )
        defer { try? FileManager.default.removeItem(at: temp) }
        #expect(!offline.enableUserCloudKitSync)
        #expect(
            AppSwiftDataCloudKitCompatibility.isLocalOnlyCloudKitDatabase(
                offline.userConfiguration.cloudKitDatabase
            )
        )
        #expect(
            AppSwiftDataCloudKitCompatibility.isLocalOnlyCloudKitDatabase(
                offline.catalogConfiguration.cloudKitDatabase
            )
        )
        #expect(
            AppSwiftDataCloudKitCompatibility.isLocalOnlyCloudKitDatabase(
                offline.diagnosticsConfiguration.cloudKitDatabase
            )
        )
    }

    @Test func diveActivity_entryCoordinate_persistsAsLatitudeLongitudePrimitives() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 12,
            entryCoordinate: DiveCoordinate(latitude: 17.3158, longitude: -87.5348)
        )
        context.insert(activity)
        try context.save()

        #expect(activity.entryLatitude == 17.3158)
        #expect(activity.entryLongitude == -87.5348)
        #expect(activity.entryCoordinate == DiveCoordinate(latitude: 17.3158, longitude: -87.5348))

        activity.entryCoordinate = nil
        try context.save()
        #expect(activity.entryLatitude == nil)
        #expect(activity.entryLongitude == nil)
        #expect(activity.entryCoordinate == nil)
    }

    @Test func appSwiftDataDualStoreFactory_cloudKitOpenProbes_writeDiagnostics() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoDiveCKProbes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        AppSwiftDataDualStoreFactory.runCloudKitOpenProbes(rootDirectory: temp)
        let path = temp.appendingPathComponent(AppSwiftDataDualStoreFactory.cloudKitDiagnosticsFileName)
        let text = try String(contentsOf: path, encoding: .utf8)
        #expect(text.contains("probeC_userOnlyLocal=success"))
        // Probes A/B may fail without a signed-in iCloud account; still must emit a result line.
        #expect(text.contains("probeA_userOnlyCloudKit="))
        #expect(text.contains("probeB_dualUserCloudKit="))
    }

    @Test func marineLifeOwnership_infersFromUUIDPrefix() {
        #expect(MarineLifeOwnership.inferred(fromUUID: "marine-life-french-angelfish") == .catalog)
        #expect(
            MarineLifeOwnership.inferred(fromUUID: "user-marine-life-\(UUID().uuidString)") == .userOwned
        )
        let catalog = MarineLife(uuid: "marine-life-phase1", commonName: "Phase One Fish")
        #expect(catalog.ownership == .catalog)
        let user = MarineLife(
            uuid: FieldGuideMarineLifeAddPresentation.makeUserCreatedUUID(),
            commonName: "My Fish"
        )
        #expect(user.ownership == .userOwned)
        #expect(FieldGuideMarineLifeAddPresentation.isUserEditable(user))
        #expect(!FieldGuideMarineLifeAddPresentation.isUserEditable(catalog))
    }

    @Test func diveSiteOwnership_infersFromOpenDiveMapTag() {
        let userSite = DiveSite(siteName: "Home Reef")
        #expect(userSite.ownership == .userOwned)
        #expect(DiveSiteCatalogMatcher.isUserEditableCatalogSite(userSite))

        let referenceSite = DiveSite(
            siteName: "Buddy Dive",
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "abc123")]
        )
        #expect(referenceSite.ownership == .catalogReference)
        #expect(!DiveSiteCatalogMatcher.isUserEditableCatalogSite(referenceSite))
    }

    @Test func diveMediaPhoto_persistsPhotosCloudIdentifier() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let media = DiveMediaPhoto(
            photosLocalIdentifier: "local/ABC",
            photosCloudIdentifier: "cloud/XYZ"
        )
        context.insert(media)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DiveMediaPhoto>())
        #expect(fetched.count == 1)
        #expect(fetched[0].photosLocalIdentifier == "local/ABC")
        #expect(fetched[0].photosCloudIdentifier == "cloud/XYZ")
    }

    @Test func appSwiftDataLogicalUniqueness_findsMarineLifeAndSightingByKey() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let species = MarineLife(uuid: "marine-life-unique-key", commonName: "Unique Key")
        context.insert(species)
        let sighting = SightingInstance(
            sightingUUID: "sighting-unique-key",
            marineLifeUUID: species.uuid,
            sightingDateTime: .now)
        context.insert(sighting)
        try context.save()

        let foundSpecies = try AppSwiftDataLogicalUniqueness.existingMarineLife(
            uuid: "marine-life-unique-key",
            modelContext: context
        )
        let foundSighting = try AppSwiftDataLogicalUniqueness.existingSighting(
            sightingUUID: "sighting-unique-key",
            modelContext: context
        )
        #expect(foundSpecies?.uuid == species.uuid)
        #expect(foundSighting?.sightingUUID == "sighting-unique-key")
    }

    @Test func appSwiftDataOwnershipBackfill_updatesLegacyRows() throws {
        let suiteName = "test.ownershipBackfill.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let species = MarineLife(uuid: "user-marine-life-backfill", commonName: "Backfill")
        species.ownershipRaw = MarineLifeOwnership.catalog.rawValue
        context.insert(species)

        let site = DiveSite(
            siteName: "Tagged",
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "ref1")]
        )
        site.ownershipRaw = DiveSiteOwnership.userOwned.rawValue
        context.insert(site)
        try context.save()

        try AppSwiftDataOwnershipBackfill.backfillIfNeeded(modelContext: context, userDefaults: defaults)
        #expect(species.ownership == .userOwned)
        #expect(site.ownership == .catalogReference)

        species.ownershipRaw = MarineLifeOwnership.catalog.rawValue
        try context.save()
        try AppSwiftDataOwnershipBackfill.backfillIfNeeded(modelContext: context, userDefaults: defaults)
        #expect(species.ownership == .catalog)
    }

    @Test func sightingInstanceCreation_dedupesBySightingUUID() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let owner = UserProfile(appleUserIdentifier: "phase1", displayName: "Phase")
        context.insert(owner)
        let dive = DiveActivity(
            source: .manual,
            startTime: .now,
            durationMinutes: 30,
            maxDepthMeters: 12
        )
        dive.owner = owner
        context.insert(dive)
        let species = MarineLife(uuid: "marine-life-dedupe", commonName: "Dedupe")
        context.insert(species)
        try context.save()

        let draft = SightingInstanceCreation.makeDraft(
            marineLifeUUID: species.uuid,
            dive: dive,
            sightingUUID: "shared-sighting-uuid"
        )
        let first = try SightingInstanceCreation.insert(
            draft: draft,
            dive: dive,
            modelContext: context
        )
        let second = try SightingInstanceCreation.insert(
            draft: draft,
            dive: dive,
            modelContext: context
        )
        #expect(first.sightingUUID == second.sightingUUID)
        #expect(first.persistentModelID == second.persistentModelID)
        let all = try context.fetch(FetchDescriptor<SightingInstance>())
        #expect(all.count == 1)
    }

    @Test @MainActor func marineLifeSightingRecorder_tagSpeciesOnSnorkel_dedupesWithMediaTag() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let owner = UserProfile(appleUserIdentifier: "owner-ml-snorkel", displayName: "Pat")
        let snorkel = SnorkelActivity(
            source: .manual,
            startTime: Date(timeIntervalSince1970: 2_200_000),
            durationMinutes: 45
        )
        snorkel.owner = owner
        let species = MarineLife(uuid: "marine-life-test-parrotfish", commonName: "Stoplight Parrotfish")
        let media = SnorkelMediaPhoto(sortOrder: 0, mediaKind: .image, photosLocalIdentifier: "ph-snorkel-1")
        snorkel.mediaPhotos = [media]
        context.insert(owner)
        context.insert(snorkel)
        context.insert(species)
        context.insert(media)
        try context.save()

        let mediaSighting = try MarineLifeSightingRecorder.tagSpecies(
            species,
            on: media,
            snorkel: snorkel,
            owner: owner,
            modelContext: context
        )
        let snorkelSighting = try MarineLifeSightingRecorder.tagSpeciesOnSnorkel(
            species,
            snorkel: snorkel,
            owner: owner,
            modelContext: context
        )
        #expect(snorkelSighting.sightingUUID == mediaSighting.sightingUUID)

        let all = try MarineLifeSightingRecorder.sightings(
            forSnorkelActivityID: snorkel.id,
            modelContext: context
        )
        #expect(all.count == 1)
    }

    // MARK: - Hybrid cloud sync Phase 1b

    @Test @MainActor
    func appSwiftDataHybridRowMigration_movesUserSpeciesAndSites() throws {
        let suiteName = "test.hybridMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let userSpecies = MarineLife(
            uuid: FieldGuideMarineLifeAddPresentation.makeUserCreatedUUID(),
            commonName: "My Goby"
        )
        let catalogSpecies = MarineLife(uuid: "marine-life-keep", commonName: "Keep Me")
        let userSite = DiveSite(siteName: "Home Reef", latCoords: 1, longCoords: 2)
        let referenceSite = DiveSite(
            siteName: "Buddy Dive",
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "ref-keep")]
        )
        context.insert(userSpecies)
        context.insert(catalogSpecies)
        context.insert(userSite)
        context.insert(referenceSite)
        try context.save()

        let result = try AppSwiftDataHybridRowMigration.migrateIfNeeded(
            modelContext: context,
            userDefaults: defaults
        )
        #expect(result.migratedSpeciesCount == 1)
        #expect(result.migratedSiteCount == 1)
        #expect(try context.fetchCount(FetchDescriptor<UserMarineLife>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MarineLife>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 1)
        #expect(
            try AppSwiftDataLogicalUniqueness.existingUserMarineLife(
                uuid: userSpecies.uuid,
                modelContext: context
            )?.commonName == "My Goby"
        )
    }

    @Test @MainActor
    func appSwiftDataDualStoreFactory_opensSplitInMemoryContainer() throws {
        let stores = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
        #expect(stores.container.configurations.count == 4)
        let context = ModelContext(stores.container)
        context.insert(UserMarineLife(commonName: "Split Species"))
        context.insert(DiveSite(siteName: "Catalog Only"))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<UserMarineLife>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 1)
    }

    @Test @MainActor
    func marineLifeSpeciesResolver_resolvesCatalogAndUserRows() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let catalog = MarineLife(uuid: "marine-life-resolver", commonName: "Catalog Fish")
        let user = UserMarineLife(commonName: "User Fish")
        context.insert(catalog)
        context.insert(user)
        try context.save()

        #expect(try MarineLifeSpeciesResolver.snapshot(uuid: catalog.uuid, modelContext: context)?.commonName == "Catalog Fish")
        #expect(try MarineLifeSpeciesResolver.snapshot(uuid: user.uuid, modelContext: context)?.commonName == "User Fish")
        let all = try MarineLifeSpeciesResolver.allCatalogSnapshots(modelContext: context)
        #expect(all.map(\.uuid).contains(catalog.uuid))
        #expect(all.map(\.uuid).contains(user.uuid))
    }

    @Test @MainActor
    func diveLinkedSiteResolver_resolvesCatalogAndUserRows() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let catalog = DiveSite(siteName: "Catalog Reef", latCoords: 10, longCoords: 20)
        let user = UserDiveSite(siteName: "User Reef", latCoords: 11, longCoords: 21)
        context.insert(catalog)
        context.insert(user)
        try context.save()

        #expect(try DiveLinkedSiteResolver.resolve(id: catalog.id, modelContext: context)?.siteName == "Catalog Reef")
        #expect(try DiveLinkedSiteResolver.resolve(id: user.id, modelContext: context)?.isUserOwned == true)
    }

    @Test @MainActor
    func fieldGuideMarineLifeAddPresentation_createsUserMarineLifeRow() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let form = FieldGuideMarineLifeAddPresentation.FormValues(
            commonName: "New User Tang",
            scientificName: "Acanthurus user",
            categoryID: "fishes"
        )
        let species = FieldGuideMarineLifeAddPresentation.makeUserMarineLife(from: form)
        context.insert(species)
        try context.save()
        #expect(FieldGuideMarineLifeAddPresentation.isUserCreated(uuid: species.uuid))
        #expect(try context.fetchCount(FetchDescriptor<UserMarineLife>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<MarineLife>()) == 0)
    }

    // MARK: - Hybrid cloud sync Phase 1c

    @Test @MainActor
    func appSwiftDataDualStoreMigrator_copiesUnifiedRowsIntoSplitContainer() throws {
        let sourceContainer = try AppSwiftDataSchema.makeUnifiedContainer(isStoredInMemoryOnly: true)
        let source = ModelContext(sourceContainer)

        let profile = UserProfile(appleUserIdentifier: "dual-mig", displayName: "Diver")
        source.insert(profile)
        let catalogSpecies = MarineLife(uuid: "marine-life-dual", commonName: "Catalog Fish")
        source.insert(catalogSpecies)
        let userSpecies = UserMarineLife(commonName: "My Fish", owner: profile)
        source.insert(userSpecies)
        let catalogSite = DiveSite(
            siteName: "Salt Pier",
            latCoords: 12.1,
            longCoords: -68.2,
            siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "salt")]
        )
        source.insert(catalogSite)
        let userSite = UserDiveSite(siteName: "Home Reef", latCoords: 1, longCoords: 2, owner: profile)
        source.insert(userSite)
        let dive = DiveActivity(
            source: .manual,
            startTime: .now,
            durationMinutes: 40,
            maxDepthMeters: 18,
            diveSiteID: userSite.id
        )
        dive.owner = profile
        dive.ownerProfileID = profile.id
        source.insert(dive)
        let media = DiveMediaPhoto(photosLocalIdentifier: "ph-dual", dive: dive)
        source.insert(media)
        let report = CrashReportRecord(
            kindRaw: CrashReport.Kind.abnormalExit.rawValue,
            reason: "test",
            appVersion: "1",
            osVersion: "18",
            details: "details"
        )
        source.insert(report)
        try source.save()

        let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
        #expect(dual.container.configurations.count == 4)
        let destination = ModelContext(dual.container)
        let result = try AppSwiftDataDualStoreMigrator.migrate(from: source, to: destination)

        #expect(result.catalogMarineLifeCount == 1)
        #expect(result.catalogDiveSiteCount == 1)
        #expect(result.diagnosticsCount == 1)
        #expect(result.userProfileCount == 1)
        #expect(result.diveActivityCount == 1)
        #expect(result.totalInsertedCount >= 7)

        #expect(try destination.fetchCount(FetchDescriptor<MarineLife>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<UserMarineLife>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<DiveSite>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<DiveActivity>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<DiveMediaPhoto>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<CrashReportRecord>()) == 1)

        let migratedDive = try destination.fetch(FetchDescriptor<DiveActivity>()).first
        #expect(migratedDive?.diveSiteID == userSite.id)
        #expect(migratedDive?.owner?.appleUserIdentifier == "dual-mig")
        #expect(migratedDive?.mediaPhotos.count == 1)
    }

    /// CloudKit mirroring requires an inverse for **`SnorkelActivity.owner`**; without it every
    /// CloudKit store open fails and the app silently falls back to local-only (no sync).
    /// The cascade assertion only holds when the inverse relationship exists on `UserProfile`.
    @Test @MainActor
    func userProfile_snorkelActivityOwnerInverse_cascadeDeletesOwnedSnorkels() throws {
        let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
        let context = ModelContext(dual.container)

        let profile = UserProfile(appleUserIdentifier: "snorkel-inverse", displayName: "Diver")
        context.insert(profile)
        let snorkel = SnorkelActivity(startTime: .now, durationMinutes: 30)
        snorkel.owner = profile
        snorkel.ownerProfileID = profile.id
        context.insert(snorkel)
        try context.save()

        #expect(profile.snorkelActivities.count == 1)
        #expect(profile.snorkelActivities.first?.id == snorkel.id)

        context.delete(profile)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SnorkelActivity>()) == 0)
    }

    @Test @MainActor
    func appSwiftDataDualStoreMigrator_copiesSnorkelRowsIntoSplitContainer() throws {
        let sourceContainer = try AppSwiftDataSchema.makeUnifiedContainer(isStoredInMemoryOnly: true)
        let source = ModelContext(sourceContainer)

        let profile = UserProfile(appleUserIdentifier: "snorkel-mig", displayName: "Snorkeler")
        source.insert(profile)
        let buddy = DiveBuddy(displayName: "Reef Pal", owner: profile)
        source.insert(buddy)
        let snorkel = SnorkelActivity(
            source: .garminMK3,
            sourceActivityId: "fit-1",
            startTime: .now,
            durationMinutes: 45,
            swimDistanceMeters: 800,
            maxDepthMeters: 3.5
        )
        snorkel.siteName = "Turtle Bay"
        snorkel.owner = profile
        snorkel.ownerProfileID = profile.id
        source.insert(snorkel)
        let media = SnorkelMediaPhoto(photosLocalIdentifier: "ph-snorkel", snorkelActivity: snorkel)
        source.insert(media)
        let buddyTag = SnorkelBuddyTag(buddy: buddy, snorkelActivity: snorkel)
        source.insert(buddyTag)
        let sighting = SightingInstance(
            marineLifeUUID: "turtle-uuid",
            sightingDateTime: .now,
            snorkelActivity: snorkel,
            snorkelMediaPhoto: media
        )
        source.insert(sighting)
        let point = SnorkelProfilePoint(
            timestamp: .now,
            latitude: 20.7,
            longitude: -156.4,
            heartRateBPM: 95,
            snorkelActivityID: snorkel.id
        )
        source.insert(point)
        try source.save()

        let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
        let destination = ModelContext(dual.container)
        let result = try AppSwiftDataDualStoreMigrator.migrate(from: source, to: destination)

        #expect(result.snorkelActivityCount == 1)

        let migrated = try destination.fetch(FetchDescriptor<SnorkelActivity>()).first
        #expect(migrated?.id == snorkel.id)
        #expect(migrated?.siteName == "Turtle Bay")
        #expect(migrated?.owner?.appleUserIdentifier == "snorkel-mig")
        #expect(migrated?.mediaPhotos.count == 1)
        #expect(migrated?.buddies.count == 1)
        #expect(migrated?.marineLifeSightings.count == 1)
        #expect(try destination.fetchCount(FetchDescriptor<SnorkelMediaPhoto>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<SnorkelBuddyTag>()) == 1)
        #expect(try destination.fetchCount(FetchDescriptor<SnorkelProfilePoint>()) == 1)
        let migratedPoint = try destination.fetch(FetchDescriptor<SnorkelProfilePoint>()).first
        #expect(migratedPoint?.snorkelActivityID == snorkel.id)
        #expect(migratedPoint?.heartRateBPM == 95)
        #expect(migrated?.swimTrackData != nil)
    }

    @Test @MainActor
    func appSwiftDataDualStoreBootstrap_opensFreshDualInTempDirectory() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoDiveDual-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let defaults = UserDefaults(suiteName: "GoDiveDualBootstrap.\(UUID().uuidString)")!
        defaults.removeObject(forKey: AppSwiftDataDualStoreBootstrap.migrationCompletedDefaultsKey)

        let opened = try AppSwiftDataDualStoreBootstrap.openProductionContainer(
            defaults: defaults,
            rootDirectory: temp
        )
        #expect(opened.container.configurations.count == 4)
        #expect(opened.openResult.enableUserCloudKitSync == false)
        #expect(defaults.bool(forKey: AppSwiftDataDualStoreBootstrap.migrationCompletedDefaultsKey))
        #expect(AppSwiftDataDualStoreFactory.dualStoreFilesExist(in: temp))
    }

    @Test func appSwiftDataDualStoreFactory_legacyUnifiedStoreURLIsDefaultStore() {
        let url = AppSwiftDataDualStoreFactory.legacyUnifiedStoreURL()
        #expect(url.lastPathComponent == "default.store")
        #expect(url.path.contains("Application Support") || url.path.contains("Application%20Support"))
    }

    @Test @MainActor
    func appSwiftDataDualStoreFactory_removeDualStoreFilesClearsTrio() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoDiveDualWipe-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        _ = try AppSwiftDataDualStoreFactory.makeOnDiskSplitContainer(
            rootDirectory: temp,
            enableUserCloudKitSync: false
        )
        #expect(AppSwiftDataDualStoreFactory.dualStoreFilesExist(in: temp))
        try AppSwiftDataDualStoreFactory.removeDualStoreFiles(in: temp)
        #expect(!AppSwiftDataDualStoreFactory.dualStoreFilesExist(in: temp))
    }

    @Test func appSwiftDataCloudKitArrayStorage_roundTripsUUIDAndStringLists() {
        let ids = [UUID(), UUID()]
        let encodedIDs = AppSwiftDataCloudKitArrayStorage.encodeUUIDList(ids)
        #expect(AppSwiftDataCloudKitArrayStorage.decodeUUIDList(encodedIDs) == ids)
        #expect(AppSwiftDataCloudKitArrayStorage.encodeUUIDList([]) == nil)
        #expect(AppSwiftDataCloudKitArrayStorage.decodeUUIDList(nil).isEmpty)

        let tags = ["open-dive-map:abc", "shore"]
        let encodedTags = AppSwiftDataCloudKitArrayStorage.encodeStringList(tags)
        #expect(AppSwiftDataCloudKitArrayStorage.decodeStringList(encodedTags) == tags)
        #expect(AppSwiftDataCloudKitArrayStorage.encodeStringList(["  ", ""]) == nil)
    }

    @Test func diveTrip_andMarineLifeUserRecord_persistListAttributesAsData() throws {
        let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let siteID = UUID()
        let diveID = UUID()
        let trip = DiveTrip(
            startDate: Date(),
            endDate: Date(),
            countries: ["Bonaire"],
            plannedSiteIDs: [siteID]
        )
        context.insert(trip)
        let record = MarineLifeUserRecord(
            marineLifeUUID: "marine-life-test",
            activitiesSightedOn: [diveID],
            sitesSightedOn: [siteID],
            userTaggedMedia: ["media:\(UUID().uuidString)"]
        )
        context.insert(record)
        let userSite = UserDiveSite(siteName: "Test Reef", siteTags: ["shore"])
        context.insert(userSite)
        try context.save()

        #expect(trip.countriesData != nil)
        #expect(trip.plannedSiteIDsData != nil)
        #expect(trip.countries == ["Bonaire"])
        #expect(trip.plannedSiteIDs == [siteID])
        #expect(record.activitiesSightedOnData != nil)
        #expect(record.activitiesSightedOn == [diveID])
        #expect(userSite.siteTagsData != nil)
        #expect(userSite.siteTags == ["shore"])
    }

    @Test func appSwiftDataDualStoreFactory_cloudKitReconnect_clearsStickyOnNextAttempt() {
        let defaults = UserDefaults(suiteName: "GoDiveCloudKitReconnectTests")!
        defer { defaults.removePersistentDomain(forName: "GoDiveCloudKitReconnectTests") }

        defaults.set(false, forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey)
        defaults.set("schema error", forKey: AppSwiftDataDualStoreFactory.lastCloudKitFallbackErrorDefaultsKey)
        AppSwiftDataDualStoreFactory.scheduleReconnectPrivateCloudKitOnNextLaunch(defaults: defaults)

        #expect(
            AppSwiftDataDualStoreFactory.shouldAttemptUserCloudKitSync(requested: true, defaults: defaults)
        )
        #expect(defaults.object(forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey) == nil)
        #expect(defaults.bool(forKey: AppSwiftDataDualStoreFactory.recreateDualStoresForCloudKitDefaultsKey))
    }

    @Test func appSwiftDataDualStoreFactory_cloudKitOpenPolicy_stickyLocalSkipsAttempt() {
        let suite = "godive.ckPolicy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(
            AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersion,
            forKey: AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersionKey
        )
        defaults.set(false, forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey)

        #expect(
            !AppSwiftDataDualStoreFactory.shouldAttemptUserCloudKitSync(requested: true, defaults: defaults)
        )
        #expect(
            !AppSwiftDataDualStoreFactory.shouldAttemptUserCloudKitSync(requested: false, defaults: defaults)
        )
    }

    @Test func appSwiftDataDualStoreFactory_cloudKitOpenPolicy_versionBumpClearsStickyOnce() {
        let suite = "godive.ckPolicyBump.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(1, forKey: AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersionKey)
        defaults.set(false, forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey)
        defaults.set("old-error", forKey: AppSwiftDataDualStoreFactory.lastCloudKitFallbackErrorDefaultsKey)

        #expect(
            AppSwiftDataDualStoreFactory.shouldAttemptUserCloudKitSync(requested: true, defaults: defaults)
        )
        #expect(defaults.object(forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey) == nil)
        #expect(defaults.bool(forKey: AppSwiftDataDualStoreFactory.recreateDualStoresForCloudKitDefaultsKey))
        #expect(
            defaults.integer(forKey: AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersionKey)
                == AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersion
        )
    }

    @Test func appSwiftDataDualStoreFactory_cloudKitOpenPolicy_v7RecreatesEvenWhenCloudKitWasEnabled() {
        let suite = "godive.ckPolicyV7.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(6, forKey: AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersionKey)
        defaults.set(true, forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey)

        #expect(
            AppSwiftDataDualStoreFactory.shouldAttemptUserCloudKitSync(requested: true, defaults: defaults)
        )
        #expect(defaults.bool(forKey: AppSwiftDataDualStoreFactory.recreateDualStoresForCloudKitDefaultsKey))
        #expect(
            defaults.integer(forKey: AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersionKey)
                == AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersion
        )
    }

    @Test func diveProfilePointStore_insertAndFetchByDiveActivityID() throws {
        let schema = Schema([DiveActivity.self, DiveProfilePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let activity = DiveActivity(
            source: .manual,
            startTime: Date(),
            durationMinutes: 30,
            maxDepthMeters: 18
        )
        let point = DiveProfilePoint(timestamp: activity.startTime, depthMeters: 12, dive: activity)
        activity.profilePoints = [point]
        context.insert(activity)
        DiveProfilePointStore.insertStagedPointsAndSyncTrack(for: activity, into: context)
        try context.save()

        let fetched = try DiveProfilePointStore.fetchPoints(for: activity.id, modelContext: context)
        #expect(fetched.count == 1)
        #expect(fetched.first?.depthMeters == 12)
        #expect(fetched.first?.diveActivityID == activity.id)
        #expect(activity.profileTrackData != nil)
        #expect(!(activity.profileTrackData?.isEmpty ?? true))
    }

    @Test func diveProfileTrackCodec_roundTripsSparseAndFullSamples() throws {
        let start = Date(timeIntervalSinceReferenceDate: 800_000)
        let samples = [
            DiveProfileTrackSample(timestamp: start, depthMeters: 1.5),
            DiveProfileTrackSample(
                timestamp: start.addingTimeInterval(60),
                depthMeters: 18.25,
                temperatureCelsius: 27.0,
                ascentRateMetersPerSecond: -0.1,
                ndlSeconds: 1200,
                timeToSurfaceSeconds: 180,
                tankPressurePSI: 2_400,
                heartRateBPM: 72,
                po2Bars: 1.4,
                n2Load: 100,
                cnsLoad: 12
            ),
            DiveProfileTrackSample(
                timestamp: start.addingTimeInterval(30),
                depthMeters: 10,
                tankPressurePSI: 2_800
            ),
        ]
        let data = try #require(try DiveProfileTrackCodec.encode(samples: samples, diveStartTime: start))
        #expect(!data.isEmpty)
        #expect(data[data.startIndex] == DiveProfileTrackCodec.codecVersion)

        let decoded = try DiveProfileTrackCodec.decode(data, diveStartTime: start)
        #expect(decoded.count == 3)
        #expect(decoded[0].depthMeters == 1.5)
        #expect(decoded[0].tankPressurePSI == nil)
        #expect(decoded[1].depthMeters == 10)
        #expect(decoded[1].tankPressurePSI == 2_800)
        #expect(decoded[2].depthMeters == 18.25)
        #expect(decoded[2].temperatureCelsius == 27.0)
        #expect(decoded[2].heartRateBPM == 72)
        #expect(decoded[2].cnsLoad == 12)
        #expect(abs(decoded[2].timestamp.timeIntervalSince(start.addingTimeInterval(60))) < 0.002)
    }

    @Test func diveProfileTrackCodec_encodeEmptyReturnsNil() throws {
        #expect(try DiveProfileTrackCodec.encode(samples: [], diveStartTime: Date()) == nil)
    }

    @Test func diveProfilePointStore_materializeFromTrackIfNeeded_isIdempotent() throws {
        let schema = Schema([DiveActivity.self, DiveProfilePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let start = Date(timeIntervalSinceReferenceDate: 900_000)
        let activity = DiveActivity(
            source: .manual,
            startTime: start,
            durationMinutes: 40,
            maxDepthMeters: 20
        )
        let track = try #require(
            try DiveProfileTrackCodec.encode(
                samples: [
                    DiveProfileTrackSample(timestamp: start, depthMeters: 3),
                    DiveProfileTrackSample(timestamp: start.addingTimeInterval(120), depthMeters: 20),
                ],
                diveStartTime: start
            )
        )
        activity.profileTrackData = track
        context.insert(activity)
        try context.save()

        let first = try DiveProfilePointStore.materializeFromTrackIfNeeded(
            activity: activity,
            modelContext: context
        )
        try context.save()
        #expect(first == 2)
        #expect(activity.profilePoints.count == 2)
        #expect(try DiveProfilePointStore.fetchPoints(for: activity.id, modelContext: context).count == 2)

        let second = try DiveProfilePointStore.materializeFromTrackIfNeeded(
            activity: activity,
            modelContext: context
        )
        #expect(second == 0)
        #expect(try DiveProfilePointStore.fetchPoints(for: activity.id, modelContext: context).count == 2)
    }

    @Test func diveProfileTrackBackfill_encodesMissingTrackDataOnce() throws {
        let schema = Schema([DiveActivity.self, DiveProfilePoint.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let suite = "godive.trackBackfill.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let start = Date()
        let activity = DiveActivity(
            source: .manual,
            startTime: start,
            durationMinutes: 25,
            maxDepthMeters: 15
        )
        activity.profilePoints = [
            DiveProfilePoint(timestamp: start, depthMeters: 5, dive: activity),
            DiveProfilePoint(timestamp: start.addingTimeInterval(60), depthMeters: 15, dive: activity),
        ]
        context.insert(activity)
        DiveProfilePointStore.insertStagedPoints(for: activity, into: context)
        #expect(activity.profileTrackData == nil)
        try context.save()

        try DiveProfileTrackBackfill.backfillIfNeeded(modelContext: context, defaults: defaults)
        #expect(activity.profileTrackData != nil)
        #expect(defaults.bool(forKey: DiveProfileTrackBackfill.completedDefaultsKey))

        activity.profileTrackData = nil
        try context.save()
        try DiveProfileTrackBackfill.backfillIfNeeded(modelContext: context, defaults: defaults)
        #expect(activity.profileTrackData == nil)
    }

    @Test func appSwiftDataStorePartition_excludesDiveProfilePointFromUserCloudKitTypes() {
        #expect(!AppSwiftDataStorePartition.userModelTypeNames.contains("DiveProfilePoint"))
        #expect(AppSwiftDataStorePartition.userLocalModelTypeNames.contains("DiveProfilePoint"))
        #expect(AppSwiftDataStorePartition.userModelTypeNames.contains("SnorkelActivity"))
        #expect(AppSwiftDataStorePartition.userLocalModelTypeNames.contains("SnorkelProfilePoint"))
    }

    @Test func diveImportPostCompletionNavigation_opensNewestWhenAnyImported() {
        let newest = UUID()
        #expect(
            DiveImportPostCompletionNavigation.importedDetailTargetID(
                importedCount: 12,
                primaryInsertedID: newest
            ) == newest
        )
        #expect(
            DiveImportPostCompletionNavigation.importedDetailTargetID(
                importedCount: 1,
                primaryInsertedID: newest
            ) == newest
        )
        #expect(
            DiveImportPostCompletionNavigation.importedDetailTargetID(
                importedCount: 0,
                primaryInsertedID: newest
            ) == nil
        )
        #expect(
            DiveImportPostCompletionNavigation.importedDetailTargetID(
                importedCount: 3,
                primaryInsertedID: nil
            ) == nil
        )
    }

    @Test func snorkelImportAlertPresentation_successAndFailureMessages() {
        let success = SnorkelImportAlertPresentation.payload(
            for: SnorkelFileImportOutcome(
                userMessage: "\(FitSnorkelFileImport.importSuccessMessagePrefix) starting Jan 1, 2026.",
                primaryInsertedActivityId: UUID()
            )
        )
        #expect(success.isSuccess)
        #expect(success.importedCount == 1)
        #expect(SnorkelImportAlertPresentation.title(for: success) == "Import complete")
        #expect(SnorkelImportAlertPresentation.message(for: success).contains("1 activity imported"))

        let failure = SnorkelImportAlertPresentation.failurePayload(message: "Duplicate session.")
        #expect(!failure.isSuccess)
        #expect(failure.importedCount == 0)
        #expect(SnorkelImportAlertPresentation.title(for: failure) == "Import failed")
        let failureMessage = SnorkelImportAlertPresentation.message(for: failure)
        #expect(failureMessage.contains("0 activities imported"))
        #expect(failureMessage.contains("Duplicate session."))
    }

    private nonisolated static func snorkelFitFixtureData(named filename: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(filename)")
        return try Data(contentsOf: url)
    }

    @Test func fitSnorkelDecoder_snorkelFixture_mapsSummaryAndDepth() throws {
        let data = try Self.snorkelFitFixtureData(named: "snorkel_garmin.fit")
        let activity = try FitSnorkelFileDecoder.buildSnorkelActivity(from: data)
        #expect(activity.swimDistanceMeters.map { $0 > 100 } == true)
        #expect(activity.totalCalories == 59)
        #expect(activity.avgHeartRateBPM == 77)
        #expect(activity.maxHeartRateBPM == 123)
        #expect(activity.avgTemperatureCelsius == 31)
        #expect(activity.maxDepthMeters.map { $0 > 0 } == true)
        #expect(!activity.profilePoints.isEmpty)
        #expect(activity.profilePoints.allSatisfy { $0.heartRateBPM != nil })
    }

    @Test func fitSnorkelDecoder_snorkelFixture_rejectsDiveImportPipeline() throws {
        let data = try Self.snorkelFitFixtureData(named: "snorkel_garmin.fit")
        #expect(throws: FitDecodeError.self) {
            _ = try FitDiveFileDecoder.buildDiveActivity(from: data)
        }
        do {
            _ = try FitDiveFileDecoder.buildDiveActivity(from: data)
        } catch let error as FitDecodeError {
            #expect(error.errorDescription?.contains("Snorkel Activity") == true)
        }
    }

    @Test func fitDecoder_singleGasSample_rejectsSnorkelImportPipeline() throws {
        let data = try Data(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("SingleGasDiveSample.fit", isDirectory: false)
        )
        #expect(throws: FitSnorkelDecodeError.self) {
            _ = try FitSnorkelFileDecoder.buildSnorkelActivity(from: data)
        }
        do {
            _ = try FitSnorkelFileDecoder.buildSnorkelActivity(from: data)
        } catch let error as FitSnorkelDecodeError {
            #expect(error.errorDescription?.contains("New Dive Activity") == true)
        }
    }

    @Test func fitSnorkelDecoder_openWaterFixture_omitsMaxDepth() throws {
        let data = try Self.snorkelFitFixtureData(named: "open_water_garmin.fit")
        let activity = try FitSnorkelFileDecoder.buildSnorkelActivity(from: data)
        #expect(activity.maxDepthMeters == nil)
        #expect(activity.totalCalories == 110)
        #expect(!activity.profilePoints.isEmpty)
    }

    @Test func snorkelDerivedDataBuilder_buildsHeartRateSeriesAndTrack() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshots = [
            SnorkelDerivedProfilePointSnapshot(
                timestamp: t0,
                latitude: 20.0,
                longitude: -156.0,
                heartRateBPM: 90
            ),
            SnorkelDerivedProfilePointSnapshot(
                timestamp: t0.addingTimeInterval(60),
                latitude: 20.001,
                longitude: -156.001,
                heartRateBPM: 110
            ),
        ]
        let built = SnorkelDerivedDataBuilder.build(from: snapshots)
        #expect(built.heartRateSamples.count == 2)
        #expect(built.heartRateSamples[1].heartRateBPM == 110)
        #expect(built.trackCoordinates.count == 2)
        #expect(built.heartRateStats.maxBPM == 110)
    }

    @Test func snorkelSwimTrackMapPresentation_fittingRegion_singlePointUsesDefaultSpan() {
        let region = SnorkelSwimTrackMapPresentation.fittingRegion(
            for: [DiveCoordinate(latitude: 20, longitude: -156)]
        )
        #expect(region != nil)
        #expect(region!.latitudeDelta == SnorkelSwimTrackMapPresentation.singlePointSpanDegrees)
    }

    @Test func snorkelSwimTrackMapPresentation_fittingMapRect_isTighterThanRegionPadding() {
        let coordinates = [
            DiveCoordinate(latitude: 12.1, longitude: -68.9),
            DiveCoordinate(latitude: 12.11, longitude: -68.905),
            DiveCoordinate(latitude: 12.108, longitude: -68.898),
        ]
        let loose = SnorkelSwimTrackMapPresentation.fittingRegion(for: coordinates)!.mkMapRect
        let tight = SnorkelSwimTrackMapPresentation.fittingMapRect(for: coordinates)!
        #expect(tight.size.width < loose.size.width)
        #expect(tight.size.height < loose.size.height)
    }

    @Test func snorkelSwimTrackMapPresentation_compactCameraPadding_isMinimal() {
        let padding = SnorkelSwimTrackMapPresentation.cameraEdgePadding(
            fitting: .compact,
            topObstructionHeight: 100,
            bottomContentMargin: 200
        )
        #expect(padding.top == 8)
        #expect(padding.bottom == 8)
    }

    @Test func snorkelHeartRateOverviewHeroPresentation_chartFrame_isEdgeToEdgeAboveSheetSeam() {
        let layoutSize = CGSize(width: 390, height: 844)
        let layoutHeight: CGFloat = 844
        let topObstruction: CGFloat = 100
        let bottomMargin: CGFloat = 200
        let frame = SnorkelHeartRateOverviewHeroPresentation.chartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: bottomMargin,
            sheetDetent: .large,
            isLandscape: false
        )
        let tankFrame = DiveTankOverviewHeroPresentation.minimizedProfileChartFrame(
            layoutSize: layoutSize,
            layoutHeight: layoutHeight,
            topObstructionHeight: topObstruction,
            bottomContentMargin: bottomMargin,
            isLandscape: false,
            detent: .large
        )
        #expect(frame == tankFrame)
        #expect(frame.minX == 0)
        #expect(frame.width == layoutSize.width)
        #expect(frame.maxY >= layoutHeight - bottomMargin)
    }

    @Test func snorkelHeartRateProfileChartPresentation_scrubLabels_matchDepthTimeAndBPM() {
        #expect(
            SnorkelHeartRateProfileChartPresentation.scrubTimeLabel(elapsedSeconds: 150)
                == "Time 2.5 min"
        )
        #expect(
            SnorkelHeartRateProfileChartPresentation.scrubHeartRateLabel(bpm: 128)
                == "Heart Rate 128 bpm"
        )
        #expect(
            SnorkelHeartRateProfileChartPresentation.heartRateAxisTopBufferFraction
                == DiveDepthProfileChartPresentation.depthAxisTopBufferFraction(for: .edgeToEdge)
        )
    }

    @Test func profileChartScrubHapticPresentation_firesOnNewSampleAndThrottles() {
        #expect(!ProfileChartScrubHapticPresentation.shouldPlayScrubHaptic(isUITest: true))
        #expect(ProfileChartScrubHapticPresentation.shouldPlayScrubHaptic(isUITest: false))
        #expect(ProfileChartScrubHapticPresentation.minimumIntervalSeconds > 0)

        #expect(
            ProfileChartScrubHapticPresentation.shouldFireHaptic(
                forSampleIndex: 3,
                previousSampleIndex: nil,
                elapsedSinceLastHapticSeconds: 1
            )
        )
        #expect(
            !ProfileChartScrubHapticPresentation.shouldFireHaptic(
                forSampleIndex: 3,
                previousSampleIndex: 3,
                elapsedSinceLastHapticSeconds: 1
            )
        )
        #expect(
            !ProfileChartScrubHapticPresentation.shouldFireHaptic(
                forSampleIndex: 4,
                previousSampleIndex: 3,
                elapsedSinceLastHapticSeconds: 0.01
            )
        )
        #expect(
            ProfileChartScrubHapticPresentation.shouldFireHaptic(
                forSampleIndex: 4,
                previousSampleIndex: 3,
                elapsedSinceLastHapticSeconds: ProfileChartScrubHapticPresentation.minimumIntervalSeconds
            )
        )
        #expect(
            !ProfileChartScrubHapticPresentation.shouldFireHaptic(
                forSampleIndex: nil,
                previousSampleIndex: 3,
                elapsedSinceLastHapticSeconds: 1
            )
        )
    }

    @Test func snorkelHeartRateProfileChartPresentation_plotPoint_keepsPeakBelowTopBuffer() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let maxBPM = 160.0
        let peak = SnorkelHeartRateProfileChartPresentation.plotPoint(
            sample: SnorkelHeartRateProfileSample(elapsedSeconds: 30, heartRateBPM: 160),
            in: rect,
            maxElapsed: 60,
            maxBPM: maxBPM
        )
        let floor = SnorkelHeartRateProfileChartPresentation.plotPoint(
            sample: SnorkelHeartRateProfileSample(elapsedSeconds: 0, heartRateBPM: 0),
            in: rect,
            maxElapsed: 60,
            maxBPM: maxBPM
        )
        let buffer = SnorkelHeartRateProfileChartPresentation.heartRateAxisTopBufferFraction
        #expect(abs(peak.y - (rect.minY + CGFloat(buffer) * rect.height)) < 0.5)
        #expect(abs(floor.y - rect.maxY) < 0.5)
        #expect(peak.y > rect.minY + 1)
    }

    @Test func snorkelHeartRateProfileChartPresentation_underCurveAreaPath_closesBelowPolyline() {
        let samples = [
            SnorkelHeartRateProfileSample(elapsedSeconds: 0, heartRateBPM: 90),
            SnorkelHeartRateProfileSample(elapsedSeconds: 60, heartRateBPM: 120),
            SnorkelHeartRateProfileSample(elapsedSeconds: 120, heartRateBPM: 100),
        ]
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let maxElapsed = SnorkelHeartRateProfileChartPresentation.chartMaxElapsed(samples: samples)
        let maxBPM = SnorkelHeartRateProfileChartPresentation.chartMaxBPM(samples: samples)
        let path = SnorkelHeartRateProfileChartPresentation.underCurveAreaPath(
            samples: samples,
            in: rect,
            maxElapsed: maxElapsed,
            maxBPM: maxBPM
        )
        #expect(!path.isEmpty)
        let bounds = path.boundingRect
        #expect(abs(bounds.maxY - rect.maxY) < 0.5)
        #expect(bounds.minY < rect.maxY - 1)
        let buffer = SnorkelHeartRateProfileChartPresentation.heartRateAxisTopBufferFraction
        #expect(bounds.minY >= rect.minY + CGFloat(buffer) * rect.height - 0.5)
    }

    @Test func snorkelHeartRateProfileChartPresentation_indexNearestElapsed_picksClosestSample() {
        let samples = [
            SnorkelHeartRateProfileSample(elapsedSeconds: 0, heartRateBPM: 80),
            SnorkelHeartRateProfileSample(elapsedSeconds: 30, heartRateBPM: 100),
            SnorkelHeartRateProfileSample(elapsedSeconds: 90, heartRateBPM: 110),
        ]
        #expect(
            SnorkelHeartRateProfileChartPresentation.indexNearestElapsed(
                samples: samples,
                targetElapsed: 28
            ) == 1
        )
        #expect(
            SnorkelHeartRateProfileChartPresentation.indexNearestElapsed(
                samples: samples,
                targetElapsed: 80
            ) == 2
        )
    }

    @Test func snorkelHeartRateProfileChartPresentation_scrubCalloutPosition_staysInsidePlot() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let nearEdge = CGPoint(x: 4, y: 10)
        let position = SnorkelHeartRateProfileChartPresentation.scrubCalloutPosition(
            point: nearEdge,
            in: rect
        )
        #expect(position.x >= 58)
        #expect(position.y >= 34)
        #expect(position.x <= rect.maxX - 58)
    }

    @Test @MainActor func snorkelDuplicateMatcher_blocksSameSourceActivityId() {
        let id = UUID()
        let a = SnorkelActivityDuplicateMatcher.Signature(
            id: id,
            sourceActivityId: "fit-1-2-3",
            startTime: Date(timeIntervalSince1970: 1_000),
            durationMinutes: 26
        )
        let b = SnorkelActivityDuplicateMatcher.Signature(
            sourceActivityId: "fit-1-2-3",
            startTime: Date(timeIntervalSince1970: 9_000),
            durationMinutes: 99
        )
        #expect(SnorkelActivityDuplicateMatcher.matchReason(candidate: a, existing: b) == .sameSourceActivityId)
    }

    @Test func appSwiftDataDualStoreFactory_cloudKitFailurePreservesExistingStoresWithoutWipe() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoDiveCKPreserve-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let suite = "godive.ckPreserve.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            AppSwiftDataDualStoreFactory.userCloudKitDatabaseOverrideForTests = nil
            AppSwiftDataDualStoreFactory.forceUserCloudKitOpenFailureForTests = false
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: temp)
        }

        _ = try AppSwiftDataDualStoreFactory.makeOnDiskSplitContainer(
            rootDirectory: temp,
            enableUserCloudKitSync: false,
            defaults: defaults
        )
        #expect(AppSwiftDataDualStoreFactory.dualStoreFilesExist(in: temp))
        let userStoreURL = AppSwiftDataDualStoreFactory.storeURL(
            named: AppSwiftDataDualStoreFactory.userStoreName,
            rootDirectory: temp
        )
        let markerURL = temp.appendingPathComponent("user-data-marker.txt")
        try Data("preserve-me".utf8).write(to: markerURL)

        defaults.set(
            AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersion,
            forKey: AppSwiftDataDualStoreFactory.cloudKitOpenPolicyVersionKey
        )
        defaults.removeObject(forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey)
        AppSwiftDataDualStoreFactory.forceUserCloudKitOpenFailureForTests = true

        let reopened = try AppSwiftDataDualStoreFactory.makeOnDiskSplitContainer(
            rootDirectory: temp,
            enableUserCloudKitSync: true,
            defaults: defaults
        )
        #expect(reopened.didFallBackFromCloudKit)
        #expect(!reopened.enableUserCloudKitSync)
        #expect(AppSwiftDataDualStoreFactory.dualStoreFilesExist(in: temp))
        #expect(FileManager.default.fileExists(atPath: userStoreURL.path))
        #expect(FileManager.default.fileExists(atPath: markerURL.path))

        let diagnostics = try String(
            contentsOf: temp.appendingPathComponent(AppSwiftDataDualStoreFactory.cloudKitDiagnosticsFileName),
            encoding: .utf8
        )
        #expect(diagnostics.contains("fallback-local-preserve-existing"))
        #expect(diagnostics.contains("openLocalOnlyWithoutWipe"))
        #expect(!diagnostics.contains("removeDualStoreFiles"))
        #expect(
            defaults.object(forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey) as? Bool
                == false
        )

        let sticky = try AppSwiftDataDualStoreFactory.makeOnDiskSplitContainer(
            rootDirectory: temp,
            enableUserCloudKitSync: true,
            defaults: defaults
        )
        #expect(sticky.didFallBackFromCloudKit)
        let stickyDiagnostics = try String(
            contentsOf: temp.appendingPathComponent(AppSwiftDataDualStoreFactory.cloudKitDiagnosticsFileName),
            encoding: .utf8
        )
        #expect(stickyDiagnostics.contains("sticky-local-skip-cloudkit"))
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
    }
}
