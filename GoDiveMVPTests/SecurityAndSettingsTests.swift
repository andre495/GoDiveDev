//
//  SecurityAndSettingsTests.swift
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


struct SecurityAndSettingsTests {
        @Test func goDiveSecurityEvent_formattedLineAndSanitizedDetail() {
            #expect(
                GoDiveSecurityEvent.formattedLine(kind: .authFailed)
                    == "security_event kind=auth.fail"
            )
            #expect(
                GoDiveSecurityEvent.formattedLine(kind: .importRejected, detail: "fit.contentTypeMismatch")
                    == "security_event kind=import.reject detail=fit.contentTypeMismatch"
            )
            #expect(
                GoDiveSecurityEvent.sanitizedDetail("diver@example.com")?.contains("@") != true
            )
            GoDiveSecurityEvent.testRecorder = []
            defer { GoDiveSecurityEvent.testRecorder = nil }
            GoDiveSecurityEvent.record(.cdnChecksumMismatch, detail: "marineLife")
            #expect(GoDiveSecurityEvent.testRecorder?.map(\.0) == [.cdnChecksumMismatch])
            #expect(GoDiveSecurityEvent.testRecorder?.first?.1 == "marineLife")
        }

        @Test func goDiveUserFacingError_importMessage_prefersLimitsCopy() {
            let limits = DiveFileImportLimits.Error.contentTypeMismatch(.fit)
            #expect(GoDiveUserFacingError.importUserMessage(for: limits) == limits.errorDescription)
            #expect(
                GoDiveUserFacingError.importUserMessage(for: NSError(domain: "Test", code: 1))
                    == GoDiveUserFacingError.importFailed
            )
            #expect(
                GoDiveAccountDeletion.DeletionError.firestoreFailed("secret stack").errorDescription
                    == GoDiveUserFacingError.accountDeletionFailed
            )
        }

        @Test func appUserSettings_automaticallyRenumberDivesKey_matchesAppStorage() {
            #expect(AppUserSettings.automaticallyRenumberDivesKey == "goDiveAutomaticallyRenumberDives")
        }

        @Test func appUserSettings_useImperialDisplayUnitsKey_matchesAppStorage() {
            #expect(AppUserSettings.useImperialDisplayUnitsKey == "goDiveUseImperialDisplayUnits")
        }

        @Test func goDiveSecretLogging_redactsAuthorizationAndDetectsSecretMaterial() {
            #expect(GoDiveSecretLogging.redactedAuthorizationDescription(nil) == "(none)")
            #expect(GoDiveSecretLogging.redactedAuthorizationDescription("   ") == "(none)")
            #expect(
                GoDiveSecretLogging.redactedAuthorizationDescription("Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig")
                    == "Bearer <redacted>"
            )
            #expect(GoDiveSecretLogging.looksLikeSecretMaterial("Bearer abcdefghijklmnop"))
            #expect(GoDiveSecretLogging.looksLikeSecretMaterial("client_secret=abcdefghijklmnop"))
            #expect(!GoDiveSecretLogging.looksLikeSecretMaterial("short"))
            #expect(!GoDiveSecretLogging.looksLikeSecretMaterial("normal display name text"))
        }

        @Test func appTransportSecurityPolicy_rejectsArbitraryLoads() {
            #expect(AppTransportSecurityPolicy.usesSystemDefaultATS(infoDictionary: [:]))
            #expect(!AppTransportSecurityPolicy.allowsArbitraryLoads(infoDictionary: [:]))
            #expect(
                !AppTransportSecurityPolicy.usesSystemDefaultATS(
                    infoDictionary: [AppTransportSecurityPolicy.appTransportSecurityKey: [:]]
                )
            )
            #expect(
                AppTransportSecurityPolicy.allowsArbitraryLoads(
                    infoDictionary: [
                        AppTransportSecurityPolicy.appTransportSecurityKey: [
                            AppTransportSecurityPolicy.allowsArbitraryLoadsKey: true,
                        ],
                    ]
                )
            )
            #expect(
                !AppTransportSecurityPolicy.allowsArbitraryLoads(
                    infoDictionary: [
                        AppTransportSecurityPolicy.appTransportSecurityKey: [
                            AppTransportSecurityPolicy.allowsArbitraryLoadsKey: false,
                        ],
                    ]
                )
            )
        }

        @Test func appTransportSecurityPolicy_productionInfoPlist_usesSystemDefaults() throws {
            let plistURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("GoDiveMVP/Info.plist", isDirectory: false)
            let data = try Data(contentsOf: plistURL)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            let dict = try #require(plist as? [String: Any])
            #expect(AppTransportSecurityPolicy.usesSystemDefaultATS(infoDictionary: dict))
            #expect(!AppTransportSecurityPolicy.allowsArbitraryLoads(infoDictionary: dict))
        }

        @Test func goDiveInputSanitization_stripsControlsAndCaps() {
            #expect(GoDiveInputSanitization.sanitizedDisplayName("  Alex\u{0000}  ") == "Alex")
            #expect(GoDiveInputSanitization.sanitizedDisplayName("") == nil)
            let longName = String(repeating: "a", count: GoDiveInputSanitization.maxDisplayNameLength + 10)
            #expect(GoDiveInputSanitization.sanitizedDisplayName(longName)?.count == GoDiveInputSanitization.maxDisplayNameLength)
            #expect(DiveSiteFormValidation.sanitizedSiteName("  Reef\u{000A}Wall  ") == "ReefWall")
            #expect(DiveNotesValidation.maxCharacterCount == 2_500)
        }

        @Test func appUserSettings_defaultTankSize_fallsBackToAL80() {
            let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DefaultTankFallback")!
            defaults.removePersistentDomain(forName: "GoDiveMVPTests.DefaultTankFallback")
            defaults.set("INVALID", forKey: AppUserSettings.defaultTankSizeKey)
            let spec = DiveActivityTankDefaults.resolvedSpecification(userDefaults: defaults)
            #expect(spec.size == .al80)
        }

        @Test func appUserSettings_defaultDiverWeights_storeAndReadKilograms() {
            let defaults = UserDefaults(suiteName: "GoDiveMVPTests.DefaultDiverWeights")!
            defaults.removePersistentDomain(forName: "GoDiveMVPTests.DefaultDiverWeights")
            #expect(AppUserSettings.defaultSaltwaterWeightKilograms(userDefaults: defaults) == nil)
            AppUserSettings.setDefaultSaltwaterWeightKilograms(5.0, userDefaults: defaults)
            AppUserSettings.setDefaultFreshwaterWeightKilograms(4.5, userDefaults: defaults)
            #expect(AppUserSettings.defaultSaltwaterWeightKilograms(userDefaults: defaults) == 5.0)
            #expect(AppUserSettings.defaultFreshwaterWeightKilograms(userDefaults: defaults) == 4.5)
            AppUserSettings.setDefaultSaltwaterWeightKilograms(nil, userDefaults: defaults)
            #expect(AppUserSettings.defaultSaltwaterWeightKilograms(userDefaults: defaults) == nil)
        }

        @Test func appUserSettings_autoUploadMediaKey_isDefined() {
            #expect(!AppUserSettings.autoUploadMediaToActivitiesKey.isEmpty)
        }

        @Test func appUserSettings_registerDefaultValues_defaultsTogglesOnWhenUnset() throws {
            let suiteName = "GoDiveSettingsDefaults-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }

            AppUserSettings.registerDefaultValues(in: defaults)

            #expect(defaults.bool(forKey: AppUserSettings.automaticallyRenumberDivesKey))
            #expect(defaults.bool(forKey: AppUserSettings.useImperialDisplayUnitsKey))
            #expect(defaults.bool(forKey: AppUserSettings.autoUploadMediaToActivitiesKey))
            #expect(defaults.bool(forKey: AppUserSettings.notifyAllNotificationsKey))
            #expect(defaults.bool(forKey: AppUserSettings.notifyBuddyActivitySharesKey))
            #expect(defaults.bool(forKey: AppUserSettings.notifyGearServiceRemindersKey))
            #expect(defaults.bool(forKey: AppUserSettings.notifyTripRemindersKey))
            #expect(defaults.bool(forKey: AppUserSettings.contributeCommunitySightingsKey))
            #expect(AppUserSettings.contributeCommunitySightings(userDefaults: defaults))
        }

        @Test func appUserSettings_notificationToggles_defaultOnUntilExplicitlyOff() throws {
            let suiteName = "GoDiveNotificationDefaults-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }

            #expect(AppUserSettings.notifyAllNotifications(userDefaults: defaults))
            #expect(AppUserSettings.notifyGearServiceReminders(userDefaults: defaults))
            #expect(AppUserSettings.notifyTripReminders(userDefaults: defaults))

            defaults.set(false, forKey: AppUserSettings.notifyGearServiceRemindersKey)
            defaults.set(false, forKey: AppUserSettings.notifyTripRemindersKey)
            #expect(!AppUserSettings.notifyGearServiceReminders(userDefaults: defaults))
            #expect(!AppUserSettings.notifyTripReminders(userDefaults: defaults))

            defaults.set(true, forKey: AppUserSettings.notifyGearServiceRemindersKey)
            defaults.set(true, forKey: AppUserSettings.notifyTripRemindersKey)
            defaults.set(false, forKey: AppUserSettings.notifyAllNotificationsKey)
            #expect(!AppUserSettings.notifyGearServiceReminders(userDefaults: defaults))
            #expect(!AppUserSettings.notifyTripReminders(userDefaults: defaults))
            #expect(AppUserSettings.notifyGearServiceRemindersPreference(userDefaults: defaults))
            #expect(AppUserSettings.notifyTripRemindersPreference(userDefaults: defaults))
        }

        @Test func appUserSettings_downloadFriendMediaOnWiFiOnly_alwaysAllowsCellular() throws {
            let suiteName = "GoDiveDownloadMediaWiFi-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }

            defaults.set(true, forKey: AppUserSettings.downloadFriendMediaOnWiFiOnlyKey)
            #expect(!AppUserSettings.downloadFriendMediaOnWiFiOnly(userDefaults: defaults))
            defaults.set(false, forKey: AppUserSettings.downloadFriendMediaOnWiFiOnlyKey)
            #expect(!AppUserSettings.downloadFriendMediaOnWiFiOnly(userDefaults: defaults))
        }

        @Test func appUserSettings_registerDefaultValues_doesNotOverrideSavedOffChoice() throws {
            let suiteName = "GoDiveSettingsDefaults-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }

            defaults.set(false, forKey: AppUserSettings.useImperialDisplayUnitsKey)
            AppUserSettings.registerDefaultValues(in: defaults)

            #expect(!defaults.bool(forKey: AppUserSettings.useImperialDisplayUnitsKey))
        }

            @Test func goDiveRemoteURLPolicy_catalogImage_requiresHTTPSPublicHost() {
                #expect(
                    GoDiveRemoteURLPolicy.sanitizedCatalogImageURL(from: "https://upload.wikimedia.org/foo.jpg")
                        != nil
                )
                #expect(GoDiveRemoteURLPolicy.sanitizedCatalogImageURL(from: "http://upload.wikimedia.org/foo.jpg") == nil)
                #expect(GoDiveRemoteURLPolicy.sanitizedCatalogImageURL(from: "file:///tmp/x.jpg") == nil)
                #expect(GoDiveRemoteURLPolicy.sanitizedCatalogImageURL(from: "https://localhost/x.jpg") == nil)
                #expect(GoDiveRemoteURLPolicy.sanitizedCatalogImageURL(from: "https://127.0.0.1/x.jpg") == nil)
                #expect(GoDiveRemoteURLPolicy.sanitizedCatalogImageURL(from: "https://user:pass@evil.example/x.jpg") == nil)
                #expect(GoDiveRemoteURLPolicy.sanitizedCatalogImageURL(from: "https://intranet/x.jpg") == nil)
            }
            @Test func goDiveRemoteURLPolicy_catalogDownload_allowsFirebaseAndCDNHostsOnly() {
                #expect(
                    GoDiveRemoteURLPolicy.sanitizedCatalogDownloadURL(
                        from: "https://firebasestorage.googleapis.com/v0/b/x/o/y",
                        cdnBaseHost: nil
                    ) != nil
                )
                #expect(
                    GoDiveRemoteURLPolicy.sanitizedCatalogDownloadURL(
                        from: "https://godive-1cff8.firebasestorage.app/o/y",
                        cdnBaseHost: nil
                    ) != nil
                )
                #expect(
                    GoDiveRemoteURLPolicy.sanitizedCatalogDownloadURL(
                        from: "https://cdn.example.web.app/models/a.usdz",
                        cdnBaseHost: "cdn.example.web.app"
                    ) != nil
                )
                #expect(
                    GoDiveRemoteURLPolicy.sanitizedCatalogDownloadURL(
                        from: "https://upload.wikimedia.org/foo.jpg",
                        cdnBaseHost: "cdn.example.web.app"
                    ) == nil
                )
                #expect(
                    GoDiveRemoteURLPolicy.isAllowedCatalogDownloadHost(
                        "myapp.firebaseapp.com",
                        cdnBaseHost: nil
                    )
                )
            }
}
