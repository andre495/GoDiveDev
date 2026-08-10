//
//  ImportDecoderTests.swift
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


struct ImportDecoderTests {
        @Test func diveImportedLocationParsing_splitsCommaSeparatedRegionAndCountry() {
            let fields = DiveImportedLocationParsing.placeFields(
                fromLocationName: " Bonaire , Caribbean Netherlands "
            )
            #expect(fields.region == "Bonaire")
            #expect(fields.country == "Caribbean Netherlands")
        }

        @Test func diveImportedLocationParsing_singleSegmentIsRegion() {
            let fields = DiveImportedLocationParsing.placeFields(fromLocationName: "Bonaire")
            #expect(fields.region == "Bonaire")
            #expect(fields.country == "")
        }

        @Test func diveImportedLocationParsing_uddfCityStateCountry_splitsOnRecognizedCountry() {
            let fields = DiveImportedLocationParsing.placeFields(
                fromLocationName: "Greenwood Village, Colorado, United States"
            )
            #expect(fields.region == "Greenwood Village, Colorado")
            #expect(fields.country == "United States")
        }

        @Test func diveImportedLocationParsing_uddfStateInCountryField() {
            let fields = DiveImportedLocationParsing.placeFields(
                fromLocationName: "Colorado, United States"
            )
            #expect(fields.region == "Colorado")
            #expect(fields.country == "United States")
        }

        @Test func diveImportedLocationParsing_singleSegmentRecognizedCountry() {
            let fields = DiveImportedLocationParsing.placeFields(fromLocationName: "United States")
            #expect(fields.region == "")
            #expect(fields.country == "United States")
        }

        @Test @MainActor
        func uddfImportGeocodeBatch_collectLookupKeys_dedupesSameCoordinate() {
            let owner = UserProfile(appleUserIdentifier: "geo-batch", displayName: "Geo")
            let a = DiveActivity(
                source: .macDive,
                startTime: Date(timeIntervalSince1970: 1_700_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            a.entryCoordinate = DiveCoordinate(latitude: 12.0835, longitude: -68.283)
            a.uddfImportDatetimeRaw = "2024-01-01T10:00:00"
            let b = DiveActivity(
                source: .macDive,
                startTime: Date(timeIntervalSince1970: 1_700_100_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            b.entryCoordinate = DiveCoordinate(latitude: 12.0835, longitude: -68.283)
            b.uddfImportDatetimeRaw = "2024-01-02T10:00:00"
            DiveActivityOwnership.assignOwner(owner, to: a)
            DiveActivityOwnership.assignOwner(owner, to: b)
            let keys = UddfImportGeocodeBatch.collectLookupKeys(from: [a, b])
            let coordinateKeys = keys.filter {
                if case .coordinate = $0.kind { return true }
                return false
            }
            #expect(coordinateKeys.count == 1)
        }

        @Test func fitDecoder_emptyData_throwsEmptyFile() {
            var caughtEmptyFile = false
            do {
                _ = try FitDiveFileDecoder.buildDiveActivity(from: Data())
            } catch FitDecodeError.emptyFile {
                caughtEmptyFile = true
            } catch {
                Issue.record("Expected FitDecodeError.emptyFile, got \(error)")
            }
            #expect(caughtEmptyFile)
        }

        @Test func fitDecoder_nonFitBytes_throwsContentTypeMismatch() {
            let data = Data(repeating: 0xAB, count: 64)
            #expect(throws: DiveFileImportLimits.Error.contentTypeMismatch(.fit)) {
                try FitDiveFileDecoder.buildDiveActivity(from: data)
            }
        }

        @Test func fitTankFieldImport_psiFromBar() throws {
            let twoBarPSI = try #require(FitTankFieldImport.psi(fromBar: 2.0))
            #expect(abs(twoBarPSI - 29.0075476014) < 0.0001)
            #expect(FitTankFieldImport.psi(fromBar: nil) == nil)
            #expect(FitTankFieldImport.psi(fromBar: 0) == nil)
        }

        @Test func fitTankFieldImport_validateDistinct_throwsWhenMoreThanTwoSensors() {
            #expect(throws: FitDecodeError.self) {
                try FitTankFieldImport.validateDistinctTankSensorCount(3)
            }
        }

        @Test func fitTankFieldImport_validateDistinct_acceptsZeroThroughTwo() throws {
            try FitTankFieldImport.validateDistinctTankSensorCount(0)
            try FitTankFieldImport.validateDistinctTankSensorCount(1)
            try FitTankFieldImport.validateDistinctTankSensorCount(2)
        }

        @Test func fitTankFieldImport_nearestPressurePSI_matchesClosestSortedSample() throws {
            let t0 = Date(timeIntervalSince1970: 1_000_000)
            let samples: [(Date, Double)] = [
                (t0.addingTimeInterval(-10), 200.0),
                (t0.addingTimeInterval(2), 180.0),
                (t0.addingTimeInterval(20), 170.0),
            ]
            let psiNear = try #require(FitTankFieldImport.nearestTankPressurePSI(
                recordTime: t0,
                sortedSamples: samples,
                maxTimeDelta: 5.0
            ))
            let expected = try #require(FitTankFieldImport.psi(fromBar: 180.0))
            #expect(abs(psiNear - expected) < 0.001)
        }

        @Test func fitTankFieldImport_nearestPressurePSI_returnsNilOutsideWindow() {
            let t0 = Date(timeIntervalSince1970: 1_000_000)
            let samples: [(Date, Double)] = [(t0.addingTimeInterval(-30), 200.0)]
            #expect(FitTankFieldImport.nearestTankPressurePSI(
                recordTime: t0,
                sortedSamples: samples,
                maxTimeDelta: 5.0
            ) == nil)
        }

        @Test func fitTankFieldImport_volumeUsedDescription() {
            #expect(FitTankFieldImport.volumeUsedDescription(volumeUsedLiters: 12.26) == "12 L used (~0.4 ft³) (FIT)")
            #expect(FitTankFieldImport.volumeUsedDescription(volumeUsedLiters: 1347.87)?.contains("1348") == true)
            #expect(FitTankFieldImport.volumeUsedDescription(volumeUsedLiters: 1347.87)?.contains("47.6") == true)
            #expect(FitTankFieldImport.volumeUsedDescription(volumeUsedLiters: nil) == nil)
        }

        @Test func fitDecoder_singleGasSample_matchesVerifiedReference() throws {
            let fitURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("SingleGasDiveSample.fit", isDirectory: false)
            let data = try Data(contentsOf: fitURL)
            let a = try FitDiveFileDecoder.buildDiveActivity(from: data)
            let start = try #require(a.tankPressureStartPSI)
            let end = try #require(a.tankPressureEndPSI)
            #expect(abs(start - 3081) < 2.0)
            #expect(abs(end - 1294) < 2.0)
            #expect(a.tankVolumeDescription == DefaultTankSize.al80.specification.storedDescription)
            #expect(a.gasDetailsTankVolumeLine(displayUnits: .imperial) == "80 cu ft")
            #expect(a.gasDetailsTankTypeLine() == "aluminum")
            let c = try #require(a.entryCoordinate)
            #expect(abs(c.latitude - 12.035237) < 1e-4)
            #expect(abs(c.longitude - (-68.262683)) < 1e-4)
            #expect(a.profilePoints.contains { $0.tankPressurePSI != nil })
            let sac = try #require(a.avgSAC)
            #expect(sac > 0)
            let rmv = try #require(a.avgRMV)
            #expect(rmv > 0)
        }

        @Test func uddfDiveNumberFields_zero_isExplicitlyNone() {
            let resolved = UddfDiveFileDecoder.diveNumberFields(fromUddfDiveNumber: 0)
            #expect(resolved.diveNumber == nil)
            #expect(resolved.diveNumberExplicitlyNone == true)
        }

        @Test func uddfDiveNumberFields_positive_preservesNumber() {
            let resolved = UddfDiveFileDecoder.diveNumberFields(fromUddfDiveNumber: 146)
            #expect(resolved.diveNumber == 146)
            #expect(resolved.diveNumberExplicitlyNone == false)
        }

        @Test func uddfDecoder_divenumberZero_showsDashInLogbook() throws {
            let xml = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
            <generator><name>TestGen</name><version>1</version></generator>
            <profiledata><repetitiongroup id="rg">
            <dive id="d-zero">
                <informationbeforedive>
                    <datetime>2025-05-09T11:26:28</datetime>
                    <divenumber>0</divenumber>
                </informationbeforedive>
                <informationafterdive>
                    <greatestdepth>10</greatestdepth>
                    <diveduration>60</diveduration>
                </informationafterdive>
                <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
            </dive>
            </repetitiongroup></profiledata>
            </uddf>
            """
            let dive = try UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first
            let activity = try #require(dive)
            #expect(activity.diveNumber == nil)
            #expect(activity.diveNumberExplicitlyNone == true)
            #expect(activity.diveNumberLogbookLabel == "-")
        }

        @Test func uddfDecoder_minimal_buildsOneDive() throws {
            let data = Data(UddfTestXML.oneDive.utf8)
            let dives = try UddfDiveFileDecoder.buildDiveActivities(from: data)
            #expect(dives.count == 1)
            let d = try #require(dives.first)
            #expect(d.source == .macDive)
            #expect(d.sourceDiveId == "d1-uuid")
            #expect(d.siteName == "Test Wall")
            #expect(d.locationName == "Bonaire")
            #expect(d.maxDepthMeters >= 21.5)
            #expect(d.durationMinutes == 2)
            #expect(d.buddies.count == 1)
            #expect(d.buddies[0].displayName == "Ann Bee")
            #expect(d.rawImportVersion?.contains("UDDF-3.2.1") == true)
            #expect(d.rawImportVersion?.contains("TestGen") == true)
            #expect(d.profilePoints.count == 2)
            #expect(d.bottomTimeSeconds == 120)
            #expect(d.surfaceIntervalSeconds == 3600)
            let minW = try #require(d.waterTempMinCelsius)
            #expect(abs(minW - 26.0) < 0.05)
            let secondPoint = try #require(d.profilePoints.sorted { $0.timestamp < $1.timestamp }.last)
            #expect(secondPoint.depthMeters == 10)
            let temp = try #require(secondPoint.temperatureCelsius)
            #expect(abs(temp - 28.0) < 0.1)
            #expect(secondPoint.tankPressurePSI == nil)
        }

        @Test func uddfDecoder_oneDiveWithTank_mapsTankFieldsAndWaypointPressure() throws {
            let data = Data(UddfTestXML.oneDiveWithTank.utf8)
            let dives = try UddfDiveFileDecoder.buildDiveActivities(from: data)
            let d = try #require(dives.first)
            #expect(d.gasType == "Nitrox")
            #expect(d.oxygenMix == 33)
            #expect(d.tankHeroGasMixLabel == "Nitrox 33%")
            #expect(d.tankMaterial == "steel")
            #expect(d.tankVolumeDescription == DefaultTankSize.al80.specification.storedDescription)
            #expect(d.tankMaterial == "steel")
            let startExpected = try #require(UddfTankPressureConversion.psi(fromPascals: 21_242_747.21))
            let endExpected = try #require(UddfTankPressureConversion.psi(fromPascals: 8_921_815.93))
            let waypointExpected = try #require(UddfTankPressureConversion.psi(fromPascals: 21_241_999.83))
            let startPSI = try #require(d.tankPressureStartPSI)
            let endPSI = try #require(d.tankPressureEndPSI)
            #expect(abs(startPSI - startExpected) < 1e-6)
            #expect(abs(endPSI - endExpected) < 1e-6)
            let sorted = d.profilePoints.sorted { $0.timestamp < $1.timestamp }
            #expect(sorted[0].tankPressurePSI == nil)
            let p1psi = try #require(sorted[1].tankPressurePSI)
            #expect(abs(p1psi - waypointExpected) < 1e-6)
            let sac = try #require(d.avgSAC)
            #expect(sac > 0)
            let rmv = try #require(d.avgRMV)
            #expect(rmv > 0)
        }

        @Test func uddfTankPressureConversion_macDiveSamplePascals() throws {
            let pascals = 21_242_747.21
            let psi = try #require(UddfTankPressureConversion.psi(fromPascals: pascals))
            #expect(abs(psi - 3080.999998513114) < 0.0001)
            #expect(UddfTankPressureConversion.psi(fromPascals: nil) == nil)
            #expect(UddfTankPressureConversion.psi(fromPascals: -1) == nil)
        }

        @Test func uddfTankVolumeFormatting_sample() {
            #expect(UddfTankVolumeFormatting.volumeDescription(fromCubicMeters: 0.080) == "80 L (0.080 m³)")
            #expect(UddfTankVolumeFormatting.volumeDescription(fromCubicMeters: nil) == nil)
        }

        @Test func uddfDecoder_twoDives_sortedOldestFirst() throws {
            let data = Data(UddfTestXML.twoDives.utf8)
            let dives = try UddfDiveFileDecoder.buildDiveActivities(from: data)
            #expect(dives.count == 2)
            #expect(dives[0].startTime < dives[1].startTime)
            #expect(dives[0].sourceDiveId == "d-older")
            #expect(dives[1].sourceDiveId == "d-newer")
            #expect(dives[0].bottomTimeSeconds == 60)
            #expect(dives[1].bottomTimeSeconds == 60)
        }

        @Test func uddfDecoder_empty_throws() {
            #expect(throws: UddfDecodeError.self) {
                try UddfDiveFileDecoder.buildDiveActivities(from: Data())
            }
        }

        @Test func uddfParseDate_parsesNaiveISO() throws {
            let d = try #require(UddfDiveFileDecoder.parseUddfDate("2025-05-09T11:26:28"))
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            #expect(cal.component(.year, from: d) == 2025)
            #expect(cal.component(.month, from: d) == 5)
            #expect(cal.component(.day, from: d) == 9)
        }

        @Test func diveDateTimeParsing_zuluStoresZeroOffset() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime("2025-05-09T14:00:00Z")
            #expect(parsed?.timeZoneOffsetSeconds == 0)
            #expect(parsed?.instant != nil)
        }

        @Test func diveDateTimeParsing_explicitOffsetFromDatetime() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime("2025-05-09T11:26:28+07:00")
            #expect(parsed?.timeZoneOffsetSeconds == 7 * 3600)
        }

        @Test func diveDateTimeParsing_naiveMacDiveDatetime_isUTC_instant() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime("2024-08-23T22:22:27")
            #expect(parsed?.timeZoneOffsetSeconds == nil)
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            #expect(cal.component(.hour, from: parsed!.instant) == 22)
        }

        @Test func diveDateTimeParsing_naiveDatetime_withSiteTimezone_interpretsWallClockAsLocal() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime("2024-08-23T22:22:27", siteTimeZoneHours: -4)
            #expect(parsed?.timeZoneOffsetSeconds == -4 * 3600)
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
            #expect(localCal.component(.hour, from: parsed!.instant) == 22)
            #expect(localCal.component(.minute, from: parsed!.instant) == 22)
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            #expect(utcCal.component(.day, from: parsed!.instant) == 24)
            #expect(utcCal.component(.hour, from: parsed!.instant) == 2)
        }

        @Test func diveDateTimeParsing_naiveWithSiteTimeZoneHours_convertsToUTCInstant() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime("2025-05-09T11:26:28", siteTimeZoneHours: -4)
            #expect(parsed?.timeZoneOffsetSeconds == -4 * 3600)
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            #expect(utcCal.component(.hour, from: parsed!.instant) == 15)
            #expect(utcCal.component(.minute, from: parsed!.instant) == 26)
        }

        @Test @MainActor
        func uddfMacDiveImportDatetimeNetworkNormalization_realignsLocalWallUsingNetworkTimezone() async throws {
            let raw = "2021-07-18T14:53:45"
            let offlineMisparse = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(raw))
            let activity = DiveActivity(
                source: .macDive,
                startTime: offlineMisparse,
                durationMinutes: 60,
                maxDepthMeters: 10,
                siteName: "Cedar Pass",
                locationName: "Cozumel",
                entryCoordinate: DiveCoordinate(latitude: 20.37539, longitude: -87.0398)
            )
            activity.uddfImportDatetimeRaw = raw
            activity.uddfWatchNaiveDatetimeSemantics = .diveLocalWallTime

            let tz = try #require(TimeZone(identifier: "America/Cancun"))
            await UddfMacDiveImportDatetimeNetworkNormalization.apply(
                [activity],
                resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
            )

            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = tz
            #expect(localCal.component(.hour, from: activity.startTime) == 14)
            #expect(localCal.component(.minute, from: activity.startTime) == 53)
            #expect(activity.timeZoneOffsetSeconds == tz.secondsFromGMT(for: activity.startTime))
        }

        @Test func diveDateTimeParsing_cozumelCoordinates_inferAmericaCancun() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime(
                "2021-07-18T14:53:45",
                siteLatitude: 20.37539,
                siteLongitude: -87.0398
            )
            #expect(parsed?.timeZoneOffsetSeconds == -5 * 3600)
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = TimeZone(identifier: "America/Cancun") ?? .gmt
            #expect(localCal.component(.hour, from: parsed!.instant) == 14)
        }

        @Test func diveDateTimeParsing_cozumelLocationName_withoutCoordinates_interpretsLocalWall() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime(
                "2021-07-22T16:10:31",
                siteLocationName: "Cozumel"
            )
            #expect(parsed?.timeZoneOffsetSeconds == -5 * 3600)
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = TimeZone(identifier: "America/Cancun") ?? .gmt
            #expect(localCal.component(.hour, from: parsed!.instant) == 16)
        }

        @Test func diveDateTimeParsing_naiveWithBonaireSiteCoordinates_interpretsMacDiveWallAsLocal() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime(
                "2024-04-27T15:55:55",
                siteTimeZoneHours: nil,
                siteLatitude: 12.10325,
                siteLongitude: -68.28845
            )
            #expect(parsed?.timeZoneOffsetSeconds == -4 * 3600)
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
            #expect(localCal.component(.hour, from: parsed!.instant) == 15)
            #expect(localCal.component(.minute, from: parsed!.instant) == 55)
        }

        @Test func uddfNaiveDatetimeStartTimeCorrection_isUtcWallClockInstant_detectsUtcMisparse() throws {
            let raw = "2024-04-27T15:55:55"
            let utcMisparse = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(raw))
            #expect(
                UddfNaiveDatetimeStartTimeCorrection.isUtcWallClockInstant(
                    startTime: utcMisparse,
                    rawDatetime: raw
                )
            )
            let localParsed = try #require(
                DiveDateTimeParsing.parseUddfDateTime(
                    raw,
                    siteLatitude: 12.10325,
                    siteLongitude: -68.28845
                )
            )
            #expect(
                !UddfNaiveDatetimeStartTimeCorrection.isUtcWallClockInstant(
                    startTime: localParsed.instant,
                    rawDatetime: raw
                )
            )
        }

        @Test @MainActor
        func uddfNaiveDatetimeStartTimeCorrection_realignsUtcMisparseUsingImportRaw() async throws {
            let raw = "2024-04-27T15:55:55"
            let utcMisparse = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant(raw))
            let activity = DiveActivity(
                source: .macDive,
                startTime: utcMisparse,
                timeZoneOffsetSeconds: -4 * 3600,
                durationMinutes: 72,
                maxDepthMeters: 18,
                bottomTimeSeconds: 4_351,
                entryCoordinate: DiveCoordinate(latitude: 12.10325, longitude: -68.28845)
            )
            activity.uddfImportDatetimeRaw = raw
            let profilePoint = DiveProfilePoint(
                timestamp: utcMisparse,
                depthMeters: 5,
                dive: activity
            )
            activity.profilePoints = [profilePoint]

            let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
            await UddfNaiveDatetimeStartTimeCorrection.reconcile(
                [activity],
                resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
            )

            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = tz
            #expect(localCal.component(.hour, from: activity.startTime) == 15)
            #expect(localCal.component(.minute, from: activity.startTime) == 55)
            #expect(activity.startTime.timeIntervalSince(profilePoint.timestamp) == 0)
        }

        @Test func uddfMacDiveWatchDatetimeSemantics_classifiesGarminDescentAndSuuntoComputer() {
            let garminDescent = UddfEquipmentCatalogItem(
                id: "g1",
                kind: "variouspieces",
                name: "Garmin Descent Mk3i 43mm",
                model: "Descent Mk3i 43mm",
                manufacturerName: "Garmin"
            )
            let suuntoComputer = UddfEquipmentCatalogItem(
                id: "s1",
                kind: "divecomputer",
                name: "Suunto D4i",
                model: "D4i",
                manufacturerName: "Suunto"
            )
            let suuntoTransmitter = UddfEquipmentCatalogItem(
                id: "t1",
                kind: "variouspieces",
                name: "Suunto Tank Pressure Transmitter",
                model: "Tank Pressure Transmitter",
                manufacturerName: "Suunto"
            )
            let catalog = [garminDescent.id: garminDescent, suuntoComputer.id: suuntoComputer, suuntoTransmitter.id: suuntoTransmitter]

            #expect(
                UddfMacDiveWatchDatetimeSemanticsResolver.classify(
                    equipmentUsedRefs: [garminDescent.id],
                    catalog: catalog
                ) == .utcWallClock
            )
            #expect(
                UddfMacDiveWatchDatetimeSemanticsResolver.classify(
                    equipmentUsedRefs: [suuntoComputer.id],
                    catalog: catalog
                ) == .diveLocalWallTime
            )
            #expect(
                UddfMacDiveWatchDatetimeSemanticsResolver.classify(
                    equipmentUsedRefs: [suuntoTransmitter.id],
                    catalog: catalog
                ) == nil
            )
        }

        @Test func diveDateTimeParsing_macDiveGarminSemantics_parsesNaiveAsUtcInstant() {
            let parsed = DiveDateTimeParsing.parseUddfDateTime(
                "2026-05-02T00:43:02",
                siteLatitude: 12.12201,
                siteLongitude: -68.29028,
                macDiveNaiveSemantics: .utcWallClock
            )
            #expect(parsed?.timeZoneOffsetSeconds == nil)
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            #expect(utcCal.component(.hour, from: parsed!.instant) == 0)
            #expect(utcCal.component(.minute, from: parsed!.instant) == 43)
        }

        @Test @MainActor
        func uddfNaiveDatetimeStartTimeCorrection_garminUtcWallClock_doesNotShiftStartTime() async throws {
            let raw = "2026-04-30T18:07:53"
            let utcInstant = try #require(DiveDateTimeParsing.parseUddfDateTime(
                raw,
                macDiveNaiveSemantics: .utcWallClock
            )?.instant)
            let activity = DiveActivity(
                source: .macDive,
                startTime: utcInstant,
                durationMinutes: 63,
                maxDepthMeters: 15.88,
                bottomTimeSeconds: 3_811,
                locationName: "Bonaire",
                entryCoordinate: DiveCoordinate(latitude: 12.03342, longitude: -68.26169)
            )
            activity.uddfImportDatetimeRaw = raw
            activity.uddfWatchNaiveDatetimeSemantics = .utcWallClock

            let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
            await UddfNaiveDatetimeStartTimeCorrection.reconcile(
                [activity],
                resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
            )

            #expect(abs(activity.startTime.timeIntervalSince(utcInstant)) < 1.0)
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            #expect(utcCal.component(.hour, from: activity.startTime) == 18)
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = tz
            #expect(localCal.component(.hour, from: activity.startTime) == 14)
        }

        @Test @MainActor
        func uddfImportedDiveNormalization_garminBonaire_keepsUtcInstantAndLocalDisplay() async throws {
            let xml = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
            <generator><name>MacDive</name><version>1.4.13</version></generator>
            <diver><owner id="o1"><equipment>
                <variouspieces id="dc-garmin">
                    <name>Garmin Descent Mk3i 43mm</name>
                    <manufacturer><name>Garmin</name></manufacturer>
                    <model>Descent Mk3i 43mm</model>
                </variouspieces>
            </equipment></owner></diver>
            <divesite><site id="s1"><name>Sweet Dreams</name>
                <geography><location>Bonaire</location>
                    <latitude>12.03342</latitude><longitude>-68.26169</longitude>
                </geography>
            </site></divesite>
            <profiledata><repetitiongroup id="rg"><dive id="d1">
                <informationbeforedive><link ref="s1"/><datetime>2026-04-30T18:07:53</datetime></informationbeforedive>
                <informationafterdive>
                    <greatestdepth>15.88</greatestdepth><diveduration>3811.59</diveduration>
                    <equipmentused><link ref="dc-garmin"/></equipmentused>
                </informationafterdive>
                <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
            </dive></repetitiongroup></profiledata>
            </uddf>
            """
            let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
            let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
            await UddfImportedDiveNormalization.normalizeBeforePersist(
                [activity],
                resolver: FixedGeocodingTimeZoneResolver(timeZone: tz)
            )

            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            #expect(utcCal.component(.hour, from: activity.startTime) == 18)
            #expect(utcCal.component(.minute, from: activity.startTime) == 7)

            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = tz
            #expect(localCal.component(.hour, from: activity.startTime) == 14)
            #expect(localCal.component(.minute, from: activity.startTime) == 7)
            #expect(activity.timeZoneOffsetSeconds == tz.secondsFromGMT(for: activity.startTime))
        }

        @Test func uddfDecoder_garminMacDiveExport_keepsNaiveDatetimeAsUtcInstant() throws {
            let xml = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
            <generator><name>MacDive</name><version>1.4.13</version></generator>
            <diver><owner id="o1"><equipment>
                <variouspieces id="dc-garmin">
                    <name>Garmin Descent Mk3i 43mm</name>
                    <manufacturer><name>Garmin</name></manufacturer>
                    <model>Descent Mk3i 43mm</model>
                </variouspieces>
            </equipment></owner></diver>
            <divesite><site id="s1"><name>Reef</name>
                <geography><latitude>12.12201</latitude><longitude>-68.29028</longitude></geography>
            </site></divesite>
            <profiledata><repetitiongroup id="rg"><dive id="d1">
                <informationbeforedive><link ref="s1"/><datetime>2026-05-02T00:43:02</datetime></informationbeforedive>
                <informationafterdive>
                    <greatestdepth>10</greatestdepth><diveduration>60</diveduration>
                    <equipmentused><link ref="dc-garmin"/></equipmentused>
                </informationafterdive>
                <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
            </dive></repetitiongroup></profiledata>
            </uddf>
            """
            let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
            #expect(activity.uddfWatchNaiveDatetimeSemantics == .utcWallClock)
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            #expect(utcCal.component(.hour, from: activity.startTime) == 0)
            #expect(utcCal.component(.minute, from: activity.startTime) == 43)
        }

        @Test func uddfDecoder_suuntoMacDiveExport_parsesNaiveDatetimeAsDiveLocal() throws {
            let xml = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
            <generator><name>MacDive</name><version>1.4.13</version></generator>
            <diver><owner id="o1"><equipment>
                <divecomputer id="dc-suunto">
                    <name>Suunto D4i</name>
                    <manufacturer><name>Suunto</name></manufacturer>
                    <model>D4i</model>
                </divecomputer>
            </equipment></owner></diver>
            <divesite><site id="s1"><name>Cedar Pass</name>
                <geography><timezone>-4.0</timezone><latitude>20.37539</latitude><longitude>-71.0</longitude></geography>
            </site></divesite>
            <profiledata><repetitiongroup id="rg"><dive id="d1">
                <informationbeforedive><link ref="s1"/><datetime>2021-07-18T14:53:45</datetime></informationbeforedive>
                <informationafterdive>
                    <greatestdepth>10</greatestdepth><diveduration>60</diveduration>
                    <equipmentused><link ref="dc-suunto"/></equipmentused>
                </informationafterdive>
                <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
            </dive></repetitiongroup></profiledata>
            </uddf>
            """
            let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
            #expect(activity.uddfWatchNaiveDatetimeSemantics == .diveLocalWallTime)
            #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
            #expect(localCal.component(.hour, from: activity.startTime) == 14)
            #expect(localCal.component(.minute, from: activity.startTime) == 53)
        }

        @Test func uddfDecoder_angelCityMacDiveExport_parsesNaiveDatetimeAsBonaireLocal() throws {
            let xml = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
            <generator><name>MacDive</name><version>1.4.13</version></generator>
            <divesite>
                <site id="s1">
                    <name>Angel City</name>
                    <geography>
                        <location>Bonaire</location>
                        <latitude>12.10325</latitude>
                        <longitude>-68.28845</longitude>
                    </geography>
                </site>
            </divesite>
            <profiledata><repetitiongroup id="rg">
            <dive id="d1">
                <informationbeforedive><link ref="s1"/><datetime>2024-04-27T15:55:55</datetime></informationbeforedive>
                <informationafterdive><greatestdepth>10</greatestdepth><diveduration>60</diveduration></informationafterdive>
                <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
            </dive>
            </repetitiongroup></profiledata>
            </uddf>
            """
            let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
            #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
            #expect(localCal.component(.hour, from: activity.startTime) == 15)
            #expect(localCal.component(.minute, from: activity.startTime) == 55)
        }

        @Test func uddfDecoder_naiveDatetimeWithSiteTimezone_storesLocalWallAsUTCInstant() throws {
            let xml = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
            <generator><name>TestGen</name><version>1</version></generator>
            <divesite>
                <site id="s1">
                    <name>Reef</name>
                    <geography><timezone>-4.0</timezone></geography>
                </site>
            </divesite>
            <profiledata><repetitiongroup id="rg">
            <dive id="d1">
                <informationbeforedive><link ref="s1"/><datetime>2024-08-23T22:22:27</datetime></informationbeforedive>
                <informationafterdive><greatestdepth>10</greatestdepth><diveduration>60</diveduration></informationafterdive>
                <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
            </dive>
            </repetitiongroup></profiledata>
            </uddf>
            """
            let activity = try #require(UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first)
            #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
            var localCal = Calendar(identifier: .gregorian)
            localCal.timeZone = TimeZone(secondsFromGMT: -4 * 3600) ?? .gmt
            #expect(localCal.component(.hour, from: activity.startTime) == 22)
        }

        @Test func uddfDecoder_siteGeographyTimeZone_setsActivityOffset() throws {
            let xml = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
            <generator><name>TestGen</name><version>1</version></generator>
            <divesite>
                <site id="s1">
                    <name>Reef</name>
                    <geography>
                        <latitude>12.1</latitude>
                        <longitude>-68.29</longitude>
                        <timezone>-4.0</timezone>
                    </geography>
                </site>
            </divesite>
            <profiledata><repetitiongroup id="rg">
            <dive id="d1">
                <informationbeforedive><link ref="s1"/><datetime>2025-05-09T11:26:28</datetime></informationbeforedive>
                <informationafterdive><greatestdepth>10</greatestdepth><diveduration>60</diveduration></informationafterdive>
                <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
            </dive>
            </repetitiongroup></profiledata>
            </uddf>
            """
            let dive = try UddfDiveFileDecoder.buildDiveActivities(from: Data(xml.utf8)).first
            let activity = try #require(dive)
            #expect(activity.timeZoneOffsetSeconds == -4 * 3600)
        }

        @Test func uddfProfilePoint_timestamps_followParsedStartInstant() throws {
            let dive = try UddfDiveFileDecoder.buildDiveActivities(from: Data(UddfTestXML.oneDive.utf8)).first
            let activity = try #require(dive)
            let sorted = activity.profilePoints.sorted { $0.timestamp < $1.timestamp }
            let first = try #require(sorted.first)
            let last = try #require(sorted.last)
            #expect(first.timestamp == activity.startTime)
            #expect(last.timestamp > activity.startTime)
        }

        @Test func uddfImportSummary_message_listsCounts() {
            let summary = UddfImportSummary(
                imported: 143,
                duplicates: 5,
                diveSitesCreated: 12,
                primaryInsertedDiveId: nil
            )
            let message = UddfImportSummary.message(for: summary)
            #expect(message.contains("143 dives imported"))
            #expect(message.contains("5 duplicate dives found"))
            #expect(message.contains("12 dive sites created"))
        }

        @Test @MainActor
        func uddfImport_onProgress_reportsInsertedAndProcessed() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "test-uddf-progress", displayName: "Progress")
            context.insert(owner)
            try context.save()
            let activities = try UddfDiveFileDecoder.buildDiveActivities(from: Data(UddfTestXML.twoDives.utf8))
            var snapshots: [(Int, Int, Int, Int)] = []
            _ = await UddfDiveFileImport.persistImportedActivities(
                activities,
                modelContext: context,
                owner: owner
            ) { imported, duplicates, processed, total in
                snapshots.append((imported, duplicates, processed, total))
            }
            #expect(snapshots.count == 2)
            #expect(snapshots[0] == (1, 0, 1, 2))
            #expect(snapshots[1] == (2, 0, 2, 2))
        }

        @Test @MainActor
        func uddfImport_skipsWhenGarminFingerprintAlreadyInLog() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "test-cross-fmt", displayName: "Cross")
            context.insert(owner)
            let start = Date(timeIntervalSince1970: 1_750_000_000)
            let garmin = DiveActivity(
                source: .garminMK3,
                sourceDiveId: "garmin-fit-abc",
                startTime: start,
                durationMinutes: 76,
                maxDepthMeters: 13.18,
                bottomTimeSeconds: 4561
            )
            DiveActivityOwnership.assignOwner(owner, to: garmin)
            context.insert(garmin)
            try context.save()

            let mac = DiveActivity(
                source: .macDive,
                sourceDiveId: "5B4EE0E4-1075-45A2-AF0A-BB08B0635051",
                startTime: start.addingTimeInterval(45),
                durationMinutes: 76,
                maxDepthMeters: 13.0,
                bottomTimeSeconds: 4560
            )
            let outcome = await UddfDiveFileImport.persistImportedActivities(
                [mac],
                modelContext: context,
                owner: owner
            )
            #expect(!outcome.didSucceed)
            #expect(outcome.insertedCount == 0)
            #expect(outcome.skippedDuplicateCount == 1)
            let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
            #expect(fetched.count == 1)
            #expect(fetched.first?.source == .garminMK3)
        }

        @Test @MainActor
        func uddfImport_bulk_skipsDuplicateAgainstExistingLog() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "test-uddf-bulk-dup", displayName: "Bulk Dup")
            context.insert(owner)
            try context.save()
            let data = Data(UddfTestXML.twoDives.utf8)
            let first = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
            #expect(first.didSucceed)
            #expect(first.insertedCount == 2)
            let second = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
            #expect(!second.didSucceed)
            #expect(second.insertedCount == 0)
            #expect(second.skippedDuplicateCount == 2)
            #expect(second.totalInFile == 2)
            #expect(second.userMessage.contains("2 duplicate dives found"))
            let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
            #expect(fetched.count == 2)
        }

        @Test @MainActor
        func uddfImport_withoutOwner_returnsSignInMessage() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let data = Data(UddfTestXML.oneDive.utf8)
            let outcome = await UddfDiveFileImport.importUddfData(data, modelContext: context)
            #expect(!outcome.didSucceed)
            #expect(outcome.userMessage == "Sign in to import dives.")
        }

        @Test @MainActor
        func uddfImport_twoDives_insertsBoth() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "test-uddf-import", displayName: "Import Test")
            context.insert(owner)
            try context.save()
            let data = Data(UddfTestXML.twoDives.utf8)
            let outcome = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
            #expect(outcome.didSucceed)
            let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
            #expect(fetched.count == 2)
            let newer = try #require(fetched.first { $0.sourceDiveId == "d-newer" })
            #expect(outcome.primaryInsertedDiveId == newer.id)
        }

        @Test @MainActor
        func uddfImport_secondImportOfSameFile_blockedAsDuplicate() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let owner = UserProfile(appleUserIdentifier: "test-uddf-dup", displayName: "Dup Test")
            context.insert(owner)
            try context.save()
            let data = Data(UddfTestXML.oneDive.utf8)
            let first = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
            #expect(first.didSucceed)
            let second = await UddfDiveFileImport.importUddfData(data, modelContext: context, owner: owner)
            #expect(!second.didSucceed)
            #expect(second.userMessage.contains("already in your log") || second.userMessage.contains("duplicate"))
            let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
            #expect(fetched.count == 1)
        }

            @Test func diveFileImportOptionsPresentation_copyForFitAndUddf() {
                #expect(DiveFileImportOptionsPresentation.pageTitle(for: .fit) == "Garmin FIT import")
                #expect(DiveFileImportOptionsPresentation.pageTitle(for: .uddf) == "UDDF import")
                #expect(DiveFileImportOptionsPresentation.chooseFileTitle(for: .fit) == "Choose FIT file")
                #expect(DiveFileImportOptionsPresentation.chooseFileTitle(for: .uddf) == "Choose UDDF file")
                #expect(DiveFileImportOptionsPresentation.accessibilityPrefix(for: .fit) == "ActivityUpload.FitImport")
                #expect(DiveFileImportOptionsPresentation.accessibilityPrefix(for: .uddf) == "ActivityUpload.BulkUddf")
            }
            @Test func catalogCDNManifestCodec_decodesV1Manifest() throws {
                let json = """
                {
                  "schemaVersion": 1,
                  "catalogVersion": 42,
                  "minimumAppVersion": "1.0",
                  "generatedAt": "2026-07-17T00:00:00Z",
                  "marineLife": {
                    "format": "full",
                    "path": "catalog/v1/marine_life.json",
                    "sha256": "abc123",
                    "itemCount": 3
                  },
                  "diveSites": {
                    "format": "full",
                    "path": "catalog/v1/dive_sites.json",
                    "sha256": "def456",
                    "itemCount": 3123
                  }
                }
                """
                let manifest = try CatalogCDNManifestCodec.decode(Data(json.utf8))
                #expect(manifest.schemaVersion == 1)
                #expect(manifest.catalogVersion == 42)
                #expect(manifest.minimumAppVersion == "1.0")
                #expect(manifest.marineLife?.format == "full")
                #expect(manifest.marineLife?.path == "catalog/v1/marine_life.json")
                #expect(manifest.marineLife?.sha256 == "abc123")
                #expect(manifest.marineLife?.itemCount == 3)
                #expect(manifest.diveSites?.path == "catalog/v1/dive_sites.json")
                #expect(manifest.diveSites?.itemCount == 3123)
            }
            @Test func catalogCDNRefreshPolicy_versionAndMinAppGates() {
                #expect(CatalogCDNRefreshPolicy.shouldApply(remoteCatalogVersion: 2, appliedCatalogVersion: 1))
                #expect(!CatalogCDNRefreshPolicy.shouldApply(remoteCatalogVersion: 2, appliedCatalogVersion: 2))
                #expect(!CatalogCDNRefreshPolicy.shouldApply(remoteCatalogVersion: 1, appliedCatalogVersion: 2))
                #expect(CatalogCDNRefreshPolicy.meetsMinimumAppVersion(appVersion: "1.2", minimumAppVersion: "1.0"))
                #expect(CatalogCDNRefreshPolicy.meetsMinimumAppVersion(appVersion: "1.0.0", minimumAppVersion: "1.0"))
                #expect(!CatalogCDNRefreshPolicy.meetsMinimumAppVersion(appVersion: "0.9", minimumAppVersion: "1.0"))
                #expect(CatalogCDNRefreshPolicy.compareDottedVersions("2.0", "1.9") == .orderedDescending)
            }
            @Test func catalogCDNChecksum_sha256HexMatchesKnownFixture() {
                let data = Data("GoDive catalog".utf8)
                let hex = CatalogCDNChecksum.sha256Hex(data)
                #expect(hex.count == 64)
                #expect(CatalogCDNChecksum.matches(data: data, expectedHex: hex))
                #expect(CatalogCDNChecksum.matches(data: data, expectedHex: hex.uppercased()))
                #expect(!CatalogCDNChecksum.matches(data: data, expectedHex: "deadbeef"))
                #expect(!CatalogCDNChecksum.matches(data: data, expectedHex: ""))
                // Fail-closed gate used by CatalogCDNRefresh → `.skippedChecksumMismatch`.
                #expect(!CatalogCDNChecksum.matches(data: data, expectedHex: CatalogCDNChecksum.sha256Hex(Data("tampered".utf8))))
            }
            @Test func catalogCDNSecretsBootstrap_rejectsPlaceholderAndEmpty() {
                #expect(CatalogCDNSecretsBootstrap.validatedBaseURL("") == nil)
                #expect(CatalogCDNSecretsBootstrap.validatedBaseURL("YOUR_FIREBASE_HOSTING_BASE_URL") == nil)
                #expect(CatalogCDNSecretsBootstrap.validatedBaseURL("ftp://example.com") == nil)
                #expect(CatalogCDNSecretsBootstrap.validatedBaseURL("http://godive-catalog.web.app") == nil)
                #expect(
                    CatalogCDNSecretsBootstrap.validatedBaseURL("https://godive-catalog.web.app")?.absoluteString
                        == "https://godive-catalog.web.app"
                )
            }
            @Test func catalogCDNPathValidation_allowsCatalogV1Only() {
                #expect(CatalogCDNPathValidation.isAllowedRelativePath("catalog/v1/manifest.json"))
                #expect(CatalogCDNPathValidation.isAllowedRelativePath("/catalog/v1/marine-life.json"))
                #expect(CatalogCDNPathValidation.isAllowedRelativePath("catalog/v1/species_similarity.json"))
                #expect(CatalogCDNPathValidation.isAllowedRelativePath("catalog/v1/species_similarity.meta.json"))
                #expect(!CatalogCDNPathValidation.isAllowedRelativePath("../catalog/v1/x.json"))
                #expect(!CatalogCDNPathValidation.isAllowedRelativePath("catalog/v2/x.json"))
                #expect(!CatalogCDNPathValidation.isAllowedRelativePath("https://evil.example/catalog/v1/x.json"))
            }
            @Test func catalogCDNClient_url_rejectsTraversalRelativePaths() {
                #expect(CatalogCDNClient.url(base: URL(string: "https://example.web.app")!, relativePath: "../etc/passwd") == nil)
            }
            @Test func diveFileImportLimits_rejectsOversizedAndWrongContent() throws {
                #expect(throws: DiveFileImportLimits.Error.fileTooLarge(maxBytes: DiveFileImportLimits.maxFileBytes)) {
                    try DiveFileImportLimits.enforceFileSize(byteCount: DiveFileImportLimits.maxFileBytes + 1)
                }
                #expect(throws: DiveFileImportLimits.Error.contentTypeMismatch(.fit)) {
                    try DiveFileImportLimits.validateContent(Data("not-a-fit-file".utf8), kind: .fit)
                }
                #expect(throws: DiveFileImportLimits.Error.contentTypeMismatch(.uddf)) {
                    try DiveFileImportLimits.validateContent(Data("<html></html>".utf8), kind: .uddf)
                }
                #expect(throws: DiveFileImportLimits.Error.contentTypeMismatch(.uddf)) {
                    try DiveFileImportLimits.validateContent(Data("<!DOCTYPE uddf><uddf></uddf>".utf8), kind: .uddf)
                }
                try DiveFileImportLimits.validateContent(Data("<uddf version=\"3.2\"></uddf>".utf8), kind: .uddf)
                #expect(DiveFileImportLimits.maxFileBytes == 100 * 1024 * 1024)
                #expect(DiveFileImportLimits.parseTimeoutSeconds == 600)
                try DiveFileImportLimits.enforceFileSize(byteCount: DiveFileImportLimits.maxFileBytes)
                #expect(throws: DiveFileImportLimits.Error.parseTimeout) {
                    try DiveFileImportLimits.enforceParseDeadline(
                        startedAt: Date(timeIntervalSinceNow: -(DiveFileImportLimits.parseTimeoutSeconds + 1))
                    )
                }
                try DiveFileImportLimits.enforceParseDeadline(startedAt: Date())
            }
            @Test func catalogCDNClient_buildsManifestURL() {
                let base = URL(string: "https://example.web.app")!
                #expect(
                    CatalogCDNClient.url(base: base, relativePath: CatalogCDNClient.manifestRelativePath)?
                        .absoluteString == "https://example.web.app/catalog/v1/manifest.json"
                )
                #expect(CatalogCDNClient.url(base: base, relativePath: "") == nil)
            }
            @Test @MainActor func catalogCDNRefresh_skippedWhenNotConfigured() async throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let outcome = await CatalogCDNRefresh.refreshMarineLifeIfNeeded(
                    modelContext: container.mainContext,
                    baseURL: nil
                )
                #expect(outcome == .skippedNotConfigured)
            }
            @Test func diveImportMilestone_labels_matchSimplifiedDialogCopy() {
                #expect(DiveImportMilestone.readingFile.label == "Reading File")
                #expect(DiveImportMilestone.parsingFile.label == "Parsing File")
                #expect(DiveImportMilestone.creatingDiveLogs.label == "Creating Dive Logs")
                #expect(DiveImportMilestone.addingMedia.label == "Adding Media")
            }
            @Test func diveImportMilestone_fractions_advanceMonotonicallyAcrossMilestones() {
                // Each milestone's bar segment is contiguous and forward-moving.
                #expect(DiveImportMilestone.readingFile.endFraction == DiveImportMilestone.parsingFile.startFraction)
                #expect(DiveImportMilestone.parsingFile.endFraction == DiveImportMilestone.creatingDiveLogs.startFraction)
                #expect(DiveImportMilestone.creatingDiveLogs.endFraction == DiveImportMilestone.addingMedia.startFraction)
                #expect(DiveImportMilestone.readingFile.startFraction < DiveImportMilestone.readingFile.endFraction)
                #expect(DiveImportMilestone.addingMedia.endFraction == 1.0)
            }
            @Test func diveImportMilestone_fraction_interpolatesWithinSegmentAndClamps() {
                let milestone = DiveImportMilestone.creatingDiveLogs
                #expect(milestone.fraction(completed: 0, total: 4) == milestone.startFraction)
                #expect(milestone.fraction(completed: 4, total: 4) == milestone.endFraction)
                let midpoint = milestone.startFraction + (milestone.endFraction - milestone.startFraction) * 0.5
                #expect(abs(milestone.fraction(completed: 2, total: 4) - midpoint) < 0.0001)
                // Guards against divide-by-zero and out-of-range work counts.
                #expect(milestone.fraction(completed: 1, total: 0) == milestone.startFraction)
                #expect(milestone.fraction(completed: 9, total: 4) == milestone.endFraction)
            }
            @Test func diveImportWaterTemperatureSummary_mergeSessionAndRecords() {
                let m = DiveImportWaterTemperatureSummary.mergedAvgMaxMinCelsius(
                    sessionAvg: 28,
                    sessionMax: 29,
                    sessionMin: 27,
                    recordTemps: [28.0, 30.0]
                )
                #expect(m.avg == 28)
                #expect(m.max == 30)
                #expect(m.min == 27)
            }
            @Test func diveImportWaterTemperatureSummary_recordsOnly() {
                let m = DiveImportWaterTemperatureSummary.mergedAvgMaxMinCelsius(
                    sessionAvg: nil,
                    sessionMax: nil,
                    sessionMin: nil,
                    recordTemps: [26.0, 28.0]
                )
                #expect(m.avg.map { abs($0 - 27.0) < 0.001 } == true)
                #expect(m.min == 26)
                #expect(m.max == 28)
            }
            @Test func diveImportFitUInt32Seconds_toOptionalInt() {
                #expect(DiveImportFitUInt32Seconds.toOptionalInt(nil) == nil)
                #expect(DiveImportFitUInt32Seconds.toOptionalInt(72) == 72)
            }
            @Test func diveGasMixImport_tankYellowFillFraction_usesOxygenOrAirDefault() {
                #expect(DiveGasMixImport.tankYellowFillFraction(oxygenMixPercent: 33) == 0.33)
                #expect(DiveGasMixImport.tankYellowFillFraction(oxygenMixPercent: nil) == 0.21)
                #expect(DiveGasMixImport.tankYellowFillFraction(oxygenMixPercent: 21) == 0.21)
            }
            @Test func diveGasMixImport_gasType_airAt21_nitroxOtherwise() {
                #expect(DiveGasMixImport.gasType(forOxygenPercent: 21) == "Air")
                #expect(DiveGasMixImport.gasType(forOxygenPercent: 21.0) == "Air")
                #expect(DiveGasMixImport.gasType(forOxygenPercent: 32) == "Nitrox")
                let fromUddf = DiveGasMixImport.resolved(fromUddfO2: 0.21)
                #expect(fromUddf.oxygenMix == 21)
                #expect(fromUddf.gasType == "Air")
                let fromFit = DiveGasMixImport.resolved(fromFitOxygenContent: 32)
                #expect(fromFit.oxygenMix == 32)
                #expect(fromFit.gasType == "Nitrox")
            }
            @Test func diveFileImporterPresentation_pickerMode_allowedTypes() {
                // Each mode is restricted to exactly its extension type — no broad `.data` / `.xml` that would
                // leave every document selectable in the picker.
                #expect(DiveFileImporterPresentation.PickerMode.fit.allowedContentTypes == [.goDiveFit])
                #expect(DiveFileImporterPresentation.PickerMode.uddf.allowedContentTypes == [.goDiveUddf])
                #expect(!DiveFileImporterPresentation.PickerMode.fit.allowedContentTypes.contains(.data))
                #expect(!DiveFileImporterPresentation.PickerMode.uddf.allowedContentTypes.contains(.data))
                #expect(!DiveFileImporterPresentation.PickerMode.uddf.allowedContentTypes.contains(.xml))
                #expect(DiveFileImporterPresentation.PickerMode.uddf.isUddf)
                #expect(!DiveFileImporterPresentation.PickerMode.fit.isUddf)
            }
            @Test func diveFileImporterPresentation_isUserCancellation_recognizesPickerCancel() {
                let cocoaCancel = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
                #expect(DiveFileImporterPresentation.isUserCancellation(cocoaCancel))
                #expect(DiveFileImporterPresentation.isUserCancellation(CancellationError()))
                #expect(DiveFileImporterPresentation.isUserCancellation(URLError(.cancelled)))
                let other = NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
                #expect(!DiveFileImporterPresentation.isUserCancellation(other))
            }
            @Test func diveFileImportSuccess_matchesFitAndMultiUddf() {
                #expect(DiveFileImportSuccess.matches("\(FitDiveFileImport.importSuccessMessagePrefix) starting test."))
                #expect(DiveFileImportSuccess.matches("Imported 3 dives."))
                #expect(DiveFileImportSuccess.matches("Imported 143 dives. 5 duplicate dives found."))
                #expect(!DiveFileImportSuccess.matches("Could not read UDDF XML: broken"))
            }
            @Test func diveFileImportOutcome_didSucceed_matchesDiveFileImportSuccess() {
                let msg = "\(FitDiveFileImport.importSuccessMessagePrefix) starting today."
                let outcome = DiveFileImportOutcome(userMessage: msg, primaryInsertedDiveId: UUID())
                #expect(outcome.didSucceed == DiveFileImportSuccess.matches(msg))
                let fail = DiveFileImportOutcome(userMessage: "nope", primaryInsertedDiveId: nil)
                #expect(fail.didSucceed == DiveFileImportSuccess.matches("nope"))
            }
            @Test func diveFileImportInterruption_userMessage_isNonEmptyAndNotSuccess() {
                #expect(!DiveFileImportInterruption.userMessage.isEmpty)
                #expect(!DiveFileImportSuccess.matches(DiveFileImportInterruption.userMessage))
            }
            @Test @MainActor
            func diveFileImportAutosaveScope_restoresPriorAutosaveFlag() async throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                context.autosaveEnabled = true
                _ = await DiveFileImportAutosaveScope.withAutosaveDisabled(modelContext: context) {
                    #expect(context.autosaveEnabled == false)
                    return true
                }
                #expect(context.autosaveEnabled == true)
            }
            @Test @MainActor
            func diveFileImportInterruption_rollbackDiscardsPendingInserts() async throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                context.autosaveEnabled = false
                let owner = UserProfile(appleUserIdentifier: "import-rollback", displayName: "Rollback")
                context.insert(owner)
                let activity = DiveActivity(
                    source: .macDive,
                    sourceDiveId: "rollback-test",
                    startTime: Date(timeIntervalSince1970: 1_700_000_000),
                    durationMinutes: 40,
                    maxDepthMeters: 18
                )
                DiveActivityOwnership.assignOwner(owner, to: activity)
                context.insert(activity)
                let outcome = DiveFileImportInterruption.rollbackAndMakeOutcome(modelContext: context)
                #expect(!outcome.didSucceed)
                #expect(outcome.userMessage == DiveFileImportInterruption.userMessage)
                let fetched = try context.fetch(FetchDescriptor<DiveActivity>())
                #expect(fetched.isEmpty)
            }

    private enum UddfTestXML {
        static let oneDive = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>9</version></generator>
        <divesite>
            <site id="s1">
                <name>Test Wall</name>
                <geography>
                    <location>Bonaire</location>
                    <latitude>12.1</latitude>
                    <longitude>-68.29</longitude>
                </geography>
            </site>
        </divesite>
        <diver>
            <buddy id="b1"><personal><firstname>Ann</firstname><lastname>Bee</lastname></personal></buddy>
        </diver>
        <profiledata>
            <repetitiongroup id="rg1">
            <dive id="d1-uuid">
                <informationbeforedive>
                    <link ref="s1"/>
                    <link ref="b1"/>
                    <surfaceintervalbeforedive>
                        <passedtime>3600</passedtime>
                    </surfaceintervalbeforedive>
                    <datetime>2025-05-09T11:26:28</datetime>
                </informationbeforedive>
                <informationafterdive>
                    <greatestdepth>21.5</greatestdepth>
                    <diveduration>120.0</diveduration>
                    <lowesttemperature>299.15</lowesttemperature>
                </informationafterdive>
                <samples>
                    <waypoint><depth>0</depth><divetime>0</divetime></waypoint>
                    <waypoint><depth>10</depth><divetime>60</divetime><temperature>301.15</temperature></waypoint>
                </samples>
            </dive>
            </repetitiongroup>
        </profiledata>
        </uddf>
        """

        /// **`tankdata`** + waypoint **`tankpressure`** (MacDive-style Pa values).
        static let oneDiveWithTank = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>9</version></generator>
        <divesite>
            <site id="s1">
                <name>Test Wall</name>
                <geography>
                    <location>Bonaire</location>
                    <latitude>12.1</latitude>
                    <longitude>-68.29</longitude>
                </geography>
            </site>
        </divesite>
        <diver>
            <buddy id="b1"><personal><firstname>Ann</firstname><lastname>Bee</lastname></personal></buddy>
        </diver>
        <gasdefinitions>
            <mix id="mix-1">
                <name>EAN33</name>
                <o2>0.33</o2>
                <n2>0.67</n2>
                <he>0.00</he>
            </mix>
        </gasdefinitions>
        <profiledata>
            <repetitiongroup id="rg1">
            <dive id="d1-uuid">
                <informationbeforedive>
                    <link ref="s1"/>
                    <link ref="b1"/>
                    <datetime>2025-05-09T11:26:28</datetime>
                </informationbeforedive>
                <informationafterdive>
                    <greatestdepth>21.5</greatestdepth>
                    <diveduration>120.0</diveduration>
                    <lowesttemperature>299.15</lowesttemperature>
                </informationafterdive>
                <tankdata>
                    <link ref="mix-1"/>
                    <tankmaterial>steel</tankmaterial>
                    <tankvolume>0.080</tankvolume>
                    <tankpressurebegin>21242747.21</tankpressurebegin>
                    <tankpressureend>8921815.93</tankpressureend>
                </tankdata>
                <samples>
                    <waypoint><depth>0</depth><divetime>0</divetime></waypoint>
                    <waypoint><depth>10</depth><divetime>60</divetime><temperature>301.15</temperature><tankpressure>21241999.83</tankpressure></waypoint>
                </samples>
            </dive>
            </repetitiongroup>
        </profiledata>
        </uddf>
        """

        static let twoDives = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
        <generator><name>TestGen</name><version>1</version></generator>
        <divesite><site id="s1"><name>Site</name><geography><latitude>1</latitude><longitude>2</longitude></geography></site></divesite>
        <profiledata><repetitiongroup id="rg">
        <dive id="d-newer">
            <informationbeforedive><link ref="s1"/><datetime>2025-06-01T12:00:00</datetime></informationbeforedive>
            <informationafterdive><greatestdepth>5</greatestdepth><diveduration>60</diveduration></informationafterdive>
            <samples><waypoint><depth>5</depth><divetime>0</divetime></waypoint></samples>
        </dive>
        <dive id="d-older">
            <informationbeforedive><link ref="s1"/><datetime>2025-05-01T12:00:00</datetime></informationbeforedive>
            <informationafterdive><greatestdepth>4</greatestdepth><diveduration>60</diveduration></informationafterdive>
            <samples><waypoint><depth>4</depth><divetime>0</divetime></waypoint></samples>
        </dive>
        </repetitiongroup></profiledata>
        </uddf>
        """
    }
}
