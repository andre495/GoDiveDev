//
//  GoDiveMVPMiscTests.swift
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


struct GoDiveMVPMiscTests {
            @Test func example() async throws {
                // Write your test here and use APIs like `#expect(...)` to check expected conditions.
            }
            @Test @MainActor func ownerDiveIndexSessionCache_reusesPublishedOwnerIndex() {
                OwnerDiveIndexSessionCache.resetForTesting()
                defer { OwnerDiveIndexSessionCache.resetForTesting() }

                let ownerID = UUID()
                let older = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 1_700_000_000),
                    durationMinutes: 40,
                    maxDepthMeters: 18
                )
                older.ownerProfileID = ownerID
                older.timeZoneOffsetSeconds = -18_000
                let newer = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 1_800_000_000),
                    durationMinutes: 50,
                    maxDepthMeters: 24
                )
                newer.ownerProfileID = ownerID

                OwnerDiveIndexSessionCache.publish(activities: [newer, older], ownerProfileID: ownerID)
                let cached = OwnerDiveIndexSessionCache.resolve(ownerProfileID: ownerID)

                #expect(cached?.numberingRows.count == 2)
                #expect(cached?.numberingRows[0].id == newer.id)
                #expect(cached?.timeZoneOffsetByActivityID[older.id] == -18_000)
            }
            @Test @MainActor
            func goDiveAccountDeletion_deleteAllLocalUserData_removesOwnedRows() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let appleID = "apple-delete-\(UUID().uuidString)"
                let profile = try UserProfileStore.findOrCreateProfile(
                    appleUserIdentifier: appleID,
                    displayName: "Delete Me",
                    modelContext: context
                )
                let ownerID = profile.id

                let dive = DiveActivity(
                    source: .manual,
                    startTime: .now,
                    durationMinutes: 30,
                    maxDepthMeters: 12
                )
                dive.ownerProfileID = ownerID
                dive.owner = profile
                context.insert(dive)

                let tag = ActivityTag(
                    name: "Reef",
                    normalizedName: "reef",
                    ownerProfileID: ownerID
                )
                context.insert(tag)
                try context.save()

                try GoDiveAccountDeletion.deleteAllLocalUserData(ownerProfileID: ownerID, modelContext: context)

                #expect(try UserProfileStore.profile(id: ownerID, modelContext: context) == nil)
                #expect(try context.fetch(FetchDescriptor<DiveActivity>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<ActivityTag>()).isEmpty)
            }
            @Test @MainActor
            func userProfile_persistsProfilePhoto() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let photo = Data([0xFF, 0xD8, 0xFF, 0xE0])
                let profile = UserProfile(
                    appleUserIdentifier: "apple-photo",
                    displayName: "Diver",
                    profilePhoto: photo
                )
                context.insert(profile)
                try context.save()

                let fetched = try UserProfileStore.profile(id: profile.id, modelContext: context)
                let stored = try #require(fetched)
                #expect(stored.profilePhoto == photo)

                stored.profilePhoto = nil
                try context.save()
                let clearedFetched = try UserProfileStore.profile(id: profile.id, modelContext: context)
                let cleared = try #require(clearedFetched)
                #expect(cleared.profilePhoto == nil)
            }
            @Test @MainActor
            func userProfile_persistsDanInsuranceNumber() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let profile = UserProfile(appleUserIdentifier: "apple-dan", displayName: "Diver")
                context.insert(profile)
                try context.save()

                profile.danInsuranceNumber = UserProfileStore.sanitizedDanInsuranceNumber("1234567")
                try context.save()

                let fetched = try UserProfileStore.profile(id: profile.id, modelContext: context)
                let stored = try #require(fetched)
                #expect(stored.danInsuranceNumber == "1234567")

                profile.danInsuranceNumber = nil
                try context.save()
                let cleared = try UserProfileStore.profile(id: profile.id, modelContext: context)
                #expect(cleared?.danInsuranceNumber == nil)
            }
            @Test @MainActor
            func appOnboardingPermissions_newAccountDetectedBeforeProfileInsert() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let appleID = "onboarding-permissions-new-user"

                #expect(try UserProfileStore.profile(appleUserIdentifier: appleID, modelContext: context) == nil)
                _ = try UserProfileStore.findOrCreateProfile(
                    appleUserIdentifier: appleID,
                    displayName: "Sam",
                    modelContext: context
                )
                #expect(try UserProfileStore.profile(appleUserIdentifier: appleID, modelContext: context) != nil)
            }
            @Test @MainActor func appSwiftUIImageRenderer_opaqueUIImage_omitsAlphaChannel() {
                let image = AppSwiftUIImageRenderer.opaqueUIImage(
                    content: Color.red.frame(width: 60, height: 34),
                    scale: 2
                )
                #expect(image != nil)
                if let cgImage = image?.cgImage {
                    switch cgImage.alphaInfo {
                    case .none, .noneSkipFirst, .noneSkipLast:
                        break
                    default:
                        Issue.record("Expected opaque CGImage alpha info, got \(cgImage.alphaInfo.rawValue)")
                    }
                }
                let pngData = image.flatMap { AppSwiftUIImageRenderer.opaquePNGData(from: $0) }
                #expect(pngData != nil)
            }
            @Test @MainActor func homeRootAppearPresentation_startsInitialRebuildDuringCelebrationPrewarm() {
                #expect(
                    HomeRootAppearPresentation.handleRootAppearAction(hasPerformedInitialHomeBuild: false)
                        == .scheduleImmediateInitialRebuild
                )
                #expect(
                    HomeRootAppearPresentation.handleRootAppearAction(hasPerformedInitialHomeBuild: true)
                        == .handleReturnToRoot
                )
            }
            @Test @MainActor
            func userProfileCloudKitIdentityMerge_adoptsCloudKitProfileOwnedSnorkels() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let appleID = "apple-merge-snorkel"

                let localEmpty = UserProfile(appleUserIdentifier: appleID, displayName: "Diver")
                let cloudKitAccount = UserProfile(appleUserIdentifier: appleID, displayName: "Andre Dugas")
                context.insert(localEmpty)
                context.insert(cloudKitAccount)

                let snorkel = SnorkelActivity(startTime: Date(), durationMinutes: 30)
                SnorkelActivityOwnership.assignOwner(cloudKitAccount, to: snorkel)
                context.insert(snorkel)
                try context.save()

                let outcome = try UserProfileCloudKitIdentityMerge.reconcile(
                    appleUserIdentifier: appleID,
                    preferredSessionProfileID: localEmpty.id,
                    modelContext: context
                )

                #expect(outcome.canonicalProfileID == cloudKitAccount.id)
                #expect(snorkel.ownerProfileID == cloudKitAccount.id)
            }
            @Test @MainActor
            func goDiveCloudKitDiveLogLocalStatus_countsSessionAndSplitProfiles() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let appleID = "apple-status"
                let session = UserProfile(appleUserIdentifier: appleID, displayName: "Session")
                let other = UserProfile(appleUserIdentifier: appleID, displayName: "Cloud")
                context.insert(session)
                context.insert(other)
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18,
                    siteName: "Reef"
                )
                DiveActivityOwnership.assignOwner(other, to: dive)
                context.insert(dive)
                try context.save()

                let snapshot = try GoDiveCloudKitDiveLogLocalStatus.snapshot(
                    sessionProfileID: session.id,
                    appleUserIdentifier: appleID,
                    modelContext: context,
                    defaults: UserDefaults(suiteName: "GoDiveCloudKitDiveLogLocalStatusTests")!
                )

                #expect(snapshot.sessionProfileDiveCount == 0)
                #expect(snapshot.totalDiveCount == 1)
                #expect(snapshot.appleIDProfileCount == 2)
                #expect(snapshot.activitiesOnOtherProfilesForSameAppleID == 1)
            }
            @Test @MainActor
            func userProfileCloudKitIdentityMerge_adoptsCloudKitProfileOwnedDives() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let appleID = "apple-merge-race"

                let localEmpty = UserProfile(appleUserIdentifier: appleID, displayName: "Diver")
                let cloudKitAccount = UserProfile(appleUserIdentifier: appleID, displayName: "Andre Dugas")
                context.insert(localEmpty)
                context.insert(cloudKitAccount)

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40,
                    maxDepthMeters: 18,
                    siteName: "Candyland"
                )
                DiveActivityOwnership.assignOwner(cloudKitAccount, to: dive)
                context.insert(dive)
                try context.save()

                let outcome = try UserProfileCloudKitIdentityMerge.reconcile(
                    appleUserIdentifier: appleID,
                    preferredSessionProfileID: localEmpty.id,
                    modelContext: context
                )

                #expect(outcome.canonicalProfileID == cloudKitAccount.id)
                #expect(outcome.mergedDuplicateCount == 1)
                #expect(outcome.didChangeCanonicalID)
                #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
                #expect(dive.ownerProfileID == cloudKitAccount.id)
                #expect(try UserProfileStore.profile(id: localEmpty.id, modelContext: context) == nil)
            }
            @Test @MainActor
            func userProfileCloudKitIdentityMerge_chooseCanonical_prefersDiveOwnerOverPlaceholder() {
                let empty = UserProfile(appleUserIdentifier: "a", displayName: "Diver")
                let named = UserProfile(appleUserIdentifier: "a", displayName: "Andre")
                let canonical = UserProfileCloudKitIdentityMerge.chooseCanonical(
                    profiles: [empty, named],
                    diveCounts: [empty.id: 0, named.id: 2],
                    preferredSessionProfileID: empty.id
                )
                #expect(canonical.id == named.id)
            }
            @Test @MainActor
            func userProfileCloudKitIdentityMerge_chooseCanonical_doesNotPreferEmptySessionTwin() {
                let localMint = UserProfile(appleUserIdentifier: "a", displayName: "Andre")
                localMint.createdAt = Date().addingTimeInterval(10)
                let cloudOlder = UserProfile(appleUserIdentifier: "a", displayName: "Andre")
                cloudOlder.createdAt = Date().addingTimeInterval(-1_000)
                let canonical = UserProfileCloudKitIdentityMerge.chooseCanonical(
                    profiles: [localMint, cloudOlder],
                    diveCounts: [localMint.id: 0, cloudOlder.id: 0],
                    preferredSessionProfileID: localMint.id
                )
                #expect(canonical.id == cloudOlder.id)
            }
            @Test @MainActor
            func userProfileCloudKitIdentityMerge_defersDeleteWhenNoOwnedActivitiesYet() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let appleID = "apple-merge-defer"
                let localMint = UserProfile(appleUserIdentifier: appleID, displayName: "Diver")
                localMint.createdAt = Date()
                let cloudProfile = UserProfile(appleUserIdentifier: appleID, displayName: "Andre")
                cloudProfile.createdAt = Date().addingTimeInterval(-86_400)
                context.insert(localMint)
                context.insert(cloudProfile)
                try context.save()

                let outcome = try UserProfileCloudKitIdentityMerge.reconcile(
                    appleUserIdentifier: appleID,
                    preferredSessionProfileID: localMint.id,
                    modelContext: context
                )

                #expect(outcome.mergedDuplicateCount == 0)
                #expect(outcome.canonicalProfileID == cloudProfile.id)
                #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 2)
            }
            @Test @MainActor
            func accountRemoteDataPopulation_shouldReconnectBeforeSignIn_whenStickyLocalEmpty() throws {
                let suite = "godive.reconnectBeforeSignIn.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suite)!
                defer { defaults.removePersistentDomain(forName: suite) }
                defaults.set(false, forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey)

                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                #expect(
                    AccountRemoteDataPopulation.shouldReconnectBeforeSignIn(
                        appleUserIdentifier: "apple-reconnect",
                        modelContext: context,
                        defaults: defaults
                    )
                )

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 30,
                    maxDepthMeters: 12,
                    siteName: "Local"
                )
                context.insert(dive)
                try context.save()
                #expect(
                    !AccountRemoteDataPopulation.shouldReconnectBeforeSignIn(
                        appleUserIdentifier: "apple-reconnect",
                        modelContext: context,
                        defaults: defaults
                    )
                )
            }
            @Test func settingsPresentation_exposesSettingTitlesAndInfoCopy() {
                #expect(SettingsPresentation.pageTitle == "Settings")
                #expect(SettingsPresentation.Preferences.sectionTitle == "Preferences")
                #expect(SettingsPresentation.ActivitySharing.sectionTitle == "Activity Sharing")
                #expect(SettingsPresentation.Advanced.sectionTitle == "Advanced")
                #expect(SettingsPresentation.ImperialUnits.title == "Units")
                #expect(SettingsPresentation.ImperialUnits.infoMessage.contains("feet"))
                #expect(SettingsPresentation.DefaultTank.title == "Default Tank Type")
                #expect(SettingsPresentation.AutomaticallyRenumberDives.title == "Automatically Renumber Dives")
                #expect(SettingsPresentation.DefaultDiverWeights.title == "Default Weights")
                #expect(SettingsPresentation.ShareNotesWithFriends.title == "Share Private notes with buddies")
                #expect(SettingsPresentation.ShareMediaOnWiFiOnly.title == "Upload media on wifi only")
                #expect(SettingsPresentation.NotifyAllNotifications.title == "All notifications")
                #expect(SettingsPresentation.CrashReports.settingsRowTitle == "View crash reports")
                #expect(SettingsPresentation.SecurityEvents.settingsRowTitle == "View diagnostic events")
                #expect(SettingsPresentation.Advanced.signOutTitle == "Sign Out")
                #expect(SettingsPresentation.VersionFooter.appLine == "GoDive v0.MVP")
                #expect(SettingsPresentation.VersionFooter.companyLine == "Primo Software LLC")
                #expect(
                    SettingsPresentation.infoAccessibilityLabel(forSettingTitle: "Units")
                        == "More information about Units"
                )
                #expect(SettingsPresentation.BulkUddfImport.attachMediaTitle == "Attach photos from library")
                #expect(SettingsPresentation.BulkUddfImport.attachMediaSubtitle.contains("few minutes"))
            }
            @Test func macDiveUddfImportPresentation_steps_endOnImportButtonPage() {
                #expect(MacDiveUddfImportPresentation.stepCount == 6)
                #expect(MacDiveUddfImportPresentation.importButtonTitle == "Import MacDive Data")
                #expect(MacDiveUddfImportPresentation.importButtonStepIndex() == 5)
                #expect(MacDiveUddfImportPresentation.step(at: 5)?.showsImportButton == true)
                #expect(MacDiveUddfImportPresentation.step(at: 0)?.showsImportButton == false)
                #expect(MacDiveUddfImportPresentation.isLastStep(index: 5))
                #expect(!MacDiveUddfImportPresentation.isLastStep(index: 0))
                #expect(MacDiveUddfImportPresentation.clampedStepIndex(99) == 5)
                #expect(MacDiveUddfImportPresentation.step(at: 0)?.screenshotAssetName == "MacDiveImportStep01")
                #expect(MacDiveUddfImportPresentation.step(at: 0)?.title == "Select your dive group")
                #expect(MacDiveUddfImportPresentation.step(at: 1)?.title == "Open dive list settings")
                #expect(MacDiveUddfImportPresentation.step(at: 2)?.title == "Export to UDDF")
                #expect(MacDiveUddfImportPresentation.step(at: 3)?.title == "Save to iCloud")
                #expect(MacDiveUddfImportPresentation.step(at: 4)?.title == "Save on your iPhone")
                #expect(
                    MacDiveUddfImportPresentation.step(at: 5)?.detail
                        == "Tap Import MacDive Data below and choose the UDDF file you just created and saved."
                )
                #expect(MacDiveUddfImportPresentation.Layout.screenshotMaxHeight == 600)
                #expect(ActivityUploadRoute.fitImportOptions != ActivityUploadRoute.uddfImportOptions)
                #expect(ActivityUploadRoute.macDiveImportGuide == ActivityUploadRoute.macDiveImportGuide)
            }
            @Test func appScrollUnderHeaderListLayout_usesLogbookHorizontalInsets() {
                #expect(AppScrollUnderHeaderListLayout.horizontalListRowInset == AppTheme.Spacing.lg)
                #expect(AppScrollUnderHeaderListLayout.listRowSpacing == AppTheme.Spacing.md)
            }
            @Test func appScrollUnderHeaderListLayout_listTopInset_matchesLogbookFormula() {
                #expect(
                    AppScrollUnderHeaderListLayout.listTopInset(safeAreaTop: 59, headerClearance: 72) == 131
                )
                #expect(
                    AppScrollUnderHeaderListLayout.listBottomInset(safeAreaBottom: 34) == 34 + AppTheme.Spacing.md
                )
                #expect(AppScrollUnderHeaderListLayout.resolvedSafeAreaTop(59) == 59)
            }
            @Test func appScrollUnderSearchChromePresentation_listTopInset_isChromeOnly() {
                #expect(AppScrollUnderSearchChromePresentation.listTopInset(chromeClearance: 68) == 68)
                #expect(AppScrollUnderSearchChromePresentation.listTopInset(chromeClearance: 72) == 72)
                #expect(
                    AppScrollUnderSearchChromePresentation.chromeClearanceFallback
                        == CollapsibleInlineTitleHeaderPresentation.chromeBandHeight
                )
                #expect(
                    AppScrollUnderSearchChromePresentation.scrimBandHeight(chromeClearance: 68)
                        == 68 + CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight
                )
                #expect(
                    AppScrollUnderSearchChromePresentation.listScrollFadeFeatherHeight
                        == CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight
                )
            }
            @Test func secondaryDestinationBackButton_defaultTapDimensionIsFortyFourPoints() {
                #expect(SecondaryDestinationChromeMetrics.backButtonMinimumTapDimension == 44)
            }
            @Test func appPortraitOrientationLockPolicy_listScreensStayPortrait() {
                let sampleID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
                let mediaID = UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!

                #expect(AppPortraitOrientationLockPolicy.locksHome(path: []))
                #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.profile]))
                #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.tripPlanner]))
                #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.tripDetail(sampleID)]))
                #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.diveSite(sampleID)]))
                #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.marineLife("species-uuid")]))
                #expect(AppPortraitOrientationLockPolicy.locksHome(path: [.diveBuddy(sampleID)]))
                #expect(!AppPortraitOrientationLockPolicy.locksHome(path: [.diveDetail(sampleID)]))
                #expect(!AppPortraitOrientationLockPolicy.locksHome(path: [.diveMedia(diveID: sampleID, mediaID: mediaID)]))

                #expect(AppPortraitOrientationLockPolicy.locksLogbook(path: []))
                #expect(AppPortraitOrientationLockPolicy.locksLogbook(path: [.tripDetail(sampleID)]))
                #expect(AppPortraitOrientationLockPolicy.locksLogbook(path: [.tripPlanner]))
                #expect(AppPortraitOrientationLockPolicy.locksLogbook(path: [.diveSite(sampleID)]))
                #expect(!AppPortraitOrientationLockPolicy.locksLogbook(path: [.diveDetail(sampleID)]))
                #expect(!AppPortraitOrientationLockPolicy.locksLogbook(path: [.diveMedia(sampleID, mediaID: mediaID)]))
                #expect(
                    !AppPortraitOrientationLockPolicy.locksLogbook(
                        path: [.buddySharedDive(friendUID: "friend-1", diveDocumentID: "dive-1")]
                    )
                )

                #expect(AppPortraitOrientationLockPolicy.locksFieldGuide(isShowingDiveDetail: false))
                #expect(!AppPortraitOrientationLockPolicy.locksFieldGuide(isShowingDiveDetail: true))

                #expect(AppPortraitOrientationLockPolicy.locksExplore(path: []))
                #expect(AppPortraitOrientationLockPolicy.locksExplore(path: [.siteDetail(sampleID)]))
                #expect(AppPortraitOrientationLockPolicy.locksExplore(path: [.speciesDetail("species-uuid")]))
                #expect(AppPortraitOrientationLockPolicy.locksExplore(path: [.tripPlanner]))
                #expect(!AppPortraitOrientationLockPolicy.locksExplore(path: [.diveDetail(sampleID)]))

                #expect(AppPortraitOrientationLockPolicy.locksTripDetail(showingLinkedDiveDetail: false))
                #expect(!AppPortraitOrientationLockPolicy.locksTripDetail(showingLinkedDiveDetail: true))

                #expect(
                    AppPortraitOrientationLockPolicy.supportedInterfaceOrientations(landscapeUnlockCount: 0) == .portrait
                )
                #expect(
                    AppPortraitOrientationLockPolicy.supportedInterfaceOrientations(landscapeUnlockCount: 1)
                        == [.portrait, .landscapeLeft, .landscapeRight]
                )
            }
            @Test func goDiveUITestConfiguration_launchArgument_matchesAppCheck() {
                #expect(GoDiveUITestConfiguration.launchArgument == "-GoDiveUITest")
                #expect(GoDiveUITestConfiguration.launchEnvironmentKey == "GoDiveUITest")
            }
            @Test @MainActor
            func userDiveSiteDuplicateConsolidation_mergesSameNameCustomSitesAndRelinksDives() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "test.owner.consolidate-sites", displayName: "Dre")
                context.insert(owner)

                let siteA = UserDiveSite(siteName: "Judy's Dream Belair", owner: owner)
                let siteB = UserDiveSite(siteName: "Judy's Dream Belair", owner: owner)
                context.insert(siteA)
                context.insert(siteB)

                let diveA = DiveActivity(
                    source: .macDive,
                    startTime: Date(timeIntervalSince1970: 1_000),
                    durationMinutes: 30,
                    maxDepthMeters: 12,
                    siteName: "Judy's Dream Belair"
                )
                diveA.ownerProfileID = owner.id
                diveA.diveSiteID = siteA.id
                context.insert(diveA)

                let diveB = DiveActivity(
                    source: .macDive,
                    startTime: Date(timeIntervalSince1970: 2_000),
                    durationMinutes: 35,
                    maxDepthMeters: 14,
                    siteName: "Judy's Dream Belair"
                )
                diveB.ownerProfileID = owner.id
                diveB.diveSiteID = siteB.id
                context.insert(diveB)
                try context.save()

                let result = try UserDiveSiteDuplicateConsolidation.consolidateIfNeeded(modelContext: context)
                #expect(result.mergedGroupCount == 1)
                #expect(result.deletedSiteCount == 1)
                #expect(result.relinkedDiveCount == 1)
                #expect(try context.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
                #expect(diveA.diveSiteID == diveB.diveSiteID)
                #expect(diveA.diveSiteID != nil)

                let fetched = ExploreDiveSiteDetailContentSnapshotBuilder.fetchSiteDiveActivities(
                    diveSiteID: diveA.diveSiteID!,
                    ownerProfileID: owner.id,
                    modelContext: context
                )
                #expect(fetched.count == 2)
            }
            @Test @MainActor
            func fitDiveFileImport_persistImportedActivity_createMissingDiveSitesFalse_stillLinksOpenDiveMapMatch() async throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "apple-fit-opendive", displayName: "Owner")
                context.insert(owner)
                try context.save()

                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 1_700_000_000),
                    timeZoneOffsetSeconds: 0,
                    durationMinutes: 30,
                    maxDepthMeters: 18,
                    siteName: "Salt Pier",
                    entryCoordinate: DiveCoordinate(latitude: 12.08316, longitude: -68.2833)
                )

                let outcome = await FitDiveFileImport.persistImportedActivity(
                    activity,
                    modelContext: context,
                    owner: owner,
                    attachMedia: false,
                    createMissingDiveSites: false
                )

                #expect(outcome.didSucceed)
                #expect(activity.diveSiteID != nil)
                #expect(activity.resolvedLinkedSite?.siteTags.contains(where: { $0.hasPrefix(DiveSiteCatalogMatcher.openDiveMapTagPrefix) }) == true)
            }
            @Test func diveSiteMapper_mapsOptionalPlaceFields() {
                let dto = DiveSiteDTO(
                    id: nil,
                    siteName: "Test Reef",
                    country: "Mexico",
                    region: nil,
                    bodyOfWater: "Gulf of California",
                    latCoords: 24.0,
                    longCoords: -110.0,
                    siteTags: nil,
                    siteRating: nil
                )
                let site = DiveSiteMapper.map(dto)
                #expect(site.country == "Mexico")
                #expect(site.region == "")
                #expect(site.bodyOfWater == "Gulf of California")
            }
            @Test func friendProfileActivityFilter_togglePresentationMatchesGlassSegmentChrome() {
                #expect(FriendProfileActivityListFilter.all.title == "All")
                #expect(FriendProfileActivityListFilter.together.title == "Together")
                #expect(FriendProfileActivityListFilter.all.systemImage == "list.bullet")
                #expect(FriendProfileActivityListFilter.together.systemImage == "person.2.fill")
                #expect(ExploreDiveSiteDetailContentPagerPresentation.showsPinnedPageHeaders)
                #expect(FieldGuideSpeciesDetailContentPagerPresentation.showsPinnedPageHeaders)
                #expect(ProfileDetailContentPagerPresentation.showsPinnedPageHeaders == false)
            }
            @Test func pageLayoutKind_includesSpeciesAndDiveSiteDetail() {
                #expect(PageLayoutKind.speciesDetail.displayName == "Species detail")
                #expect(PageLayoutKind.diveSiteDetail.displayName == "Dive site detail")
                #expect(PageLayoutKind.allCases.contains(.speciesDetail))
                #expect(PageLayoutKind.allCases.contains(.diveSiteDetail))
            }
            @Test func catalogSubstringSearch_matchesPrelowercasedHaystack() {
                let haystack = "salt pier bonaire caribbean"
                #expect(CatalogSubstringSearch.matchesPrelowercased(haystack, query: "bonaire"))
                #expect(!CatalogSubstringSearch.matchesPrelowercased(haystack, query: "belize"))
            }
            @Test func firestoreProfilePublishGate_defersUntilCleared() {
                let suite = "firestore-gate-\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suite)!
                defer { defaults.removePersistentDomain(forName: suite) }
                #expect(!GoDiveFirestoreProfilePublishGate.isDeferredUntilPhotoStep(userDefaults: defaults))
                GoDiveFirestoreProfilePublishGate.markDeferredUntilPhotoStep(userDefaults: defaults)
                #expect(GoDiveFirestoreProfilePublishGate.isDeferredUntilPhotoStep(userDefaults: defaults))
                #expect(
                    GoDiveFirestoreProfilePublishGate.shouldDeferDirectoryUpsert(
                        isPostSignUpSetupVisible: true,
                        userDefaults: defaults
                    )
                )
                #expect(
                    !GoDiveFirestoreProfilePublishGate.shouldDeferDirectoryUpsert(
                        isPostSignUpSetupVisible: false,
                        userDefaults: defaults
                    )
                )
                GoDiveFirestoreProfilePublishGate.clear(userDefaults: defaults)
                #expect(!GoDiveFirestoreProfilePublishGate.isDeferredUntilPhotoStep(userDefaults: defaults))
                #expect(
                    !GoDiveFirestoreProfilePublishGate.shouldDeferDirectoryUpsert(
                        isPostSignUpSetupVisible: true,
                        userDefaults: defaults
                    )
                )
            }
            @Test func firestoreProfileEditSync_skipsWhileSignupPhotoDeferred() {
                #expect(
                    GoDiveFirestoreProfileEditSync.shouldSyncEdits(
                        isDeferredUntilPhotoStep: false,
                        isPostSignUpSetupVisible: false
                    )
                )
                #expect(
                    GoDiveFirestoreProfileEditSync.shouldSyncEdits(
                        isDeferredUntilPhotoStep: false,
                        isPostSignUpSetupVisible: true
                    )
                )
                #expect(
                    !GoDiveFirestoreProfileEditSync.shouldSyncEdits(
                        isDeferredUntilPhotoStep: true,
                        isPostSignUpSetupVisible: true
                    )
                )
                #expect(
                    GoDiveFirestoreProfileEditSync.shouldSyncEdits(
                        isDeferredUntilPhotoStep: true,
                        isPostSignUpSetupVisible: false
                    )
                )
            }
            @Test func goDivePlainText_labeled_keepsAPIValueLiteral() {
                let line = GoDivePlainText.labeled("Fishial: ", value: "*evil*_name_")
                #expect(line == "Fishial: *evil*_name_")
            }
            @Test func goDiveCloudKitBackgroundSync_schedulesCellularFriendlyProcessing() {
                #expect(
                    GoDiveCloudKitBackgroundSyncPresentation.permittedTaskIdentifiers == [
                        "PrimoSoftware.GoDiveMVP.cloudkit-refresh",
                        "PrimoSoftware.GoDiveMVP.cloudkit-processing",
                    ]
                )
                #expect(GoDiveCloudKitBackgroundSyncPresentation.allowsCellularMaintenanceWindows())
                #expect(GoDiveCloudKitBackgroundSyncPresentation.processingRequiresNetworkConnectivity())
                #expect(!GoDiveCloudKitBackgroundSyncPresentation.processingRequiresExternalPower())
                #expect(GoDiveCloudKitBackgroundSync.appRefreshEarliestInterval == 15 * 60)
                #expect(GoDiveCloudKitBackgroundSync.processingEarliestInterval == 45 * 60)

                let suiteName = "GoDiveCloudKitBackgroundSync.tests." + UUID().uuidString
                let defaults = UserDefaults(suiteName: suiteName)!
                defer { defaults.removePersistentDomain(forName: suiteName) }
                #expect(GoDiveCloudKitBackgroundSync.shouldSchedule(defaults: defaults))
                defaults.set(false, forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey)
                #expect(!GoDiveCloudKitBackgroundSync.shouldSchedule(defaults: defaults))
                defaults.set(true, forKey: AppSwiftDataDualStoreFactory.lastCloudKitSyncEnabledDefaultsKey)
                #expect(GoDiveCloudKitBackgroundSync.shouldSchedule(defaults: defaults))
            }
            @Test func activityNotesPresentation_displayValue_emptyPlaceholderAndTrim() {
                #expect(ActivityNotesPresentation.displayValue(notes: nil) == "—")
                #expect(ActivityNotesPresentation.displayValue(notes: "   ") == "—")
                #expect(ActivityNotesPresentation.displayValue(notes: "  Saw a turtle  ") == "Saw a turtle")
                #expect(!ActivityNotesPresentation.hasContent(notes: nil))
                #expect(ActivityNotesPresentation.hasContent(notes: "Reef"))
            }
            @Test func activityNotesPresentation_sanitizedPersistMatchesDiveCap() {
                let blank = GoDiveInputSanitization.sanitizedNotes("  \n\t  ")
                #expect(blank == nil)

                let long = String(repeating: "n", count: DiveNotesValidation.maxCharacterCount + 40)
                let capped = GoDiveInputSanitization.sanitizedNotes(long)
                #expect(capped?.count == DiveNotesValidation.maxCharacterCount)
                #expect(DiveNotesValidation.cappedNotes(long).count == DiveNotesValidation.maxCharacterCount)
            }
            @Test func catalogAssetDiskCache_storesAndResolvesPhoto() throws {
                let name = "test-catalog-photo-\(UUID().uuidString)"
                let data = Data("fake-jpeg".utf8)
                let url = try CatalogAssetDiskCache.store(data: data, kind: .photo, resourceName: name)
                defer { try? FileManager.default.removeItem(at: url) }

                let cached = CatalogAssetDiskCache.cachedFileURL(kind: .photo, resourceName: name)
                #expect(cached == url)
                #expect(try Data(contentsOf: url) == data)

                let source = FieldGuideMarineLifeBundledImagePresentation.imageSource(
                    featureImageResourceName: name,
                    featureImageURL: "https://example.com/missing.jpg"
                )
                guard case .cachedFile(let cachedURL) = source else {
                    Issue.record("Expected disk cache image source")
                    return
                }
                #expect(cachedURL == url)
            }
            @Test func sightingGraphExport_anonymizedFieldsDateTruncationAndMissingSite() {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let midday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 14))!
                let night = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 2))!

                #expect(SightingGraphExport.sightingDateString(from: midday) == "2026-08-05")
                #expect(SightingGraphExport.timeOfDay(from: midday) == "day")
                #expect(SightingGraphExport.timeOfDay(from: night) == "night")

                // UTC 02:00 with UTC-4 offset → local 22:00 previous evening → night + local date 2026-08-04.
                let utcEarly = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 2))!
                #expect(
                    SightingGraphExport.timeOfDay(from: utcEarly, timeZoneOffsetSeconds: -4 * 3600) == "night"
                )
                #expect(
                    SightingGraphExport.sightingDateString(from: utcEarly, timeZoneOffsetSeconds: -4 * 3600)
                        == "2026-08-04"
                )
                // UTC 22:00 with UTC-4 → local 18:00 → crepuscular.
                let utcLate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 22))!
                #expect(
                    SightingGraphExport.timeOfDay(from: utcLate, timeZoneOffsetSeconds: -4 * 3600)
                        == "crepuscular"
                )

                let diveID = UUID()
                let payload = SightingGraphExport.payload(
                    sightingUUID: "local-sighting-1",
                    contributionId: "contrib-opaque-1",
                    marineLifeUUID: "marine-life-french-angelfish",
                    sightingDateTime: midday,
                    diveActivityID: diveID,
                    snorkelActivityID: nil,
                    diveSiteID: nil,
                    sightingDepthMeters: 12.5,
                    catalogSites: [],
                    siteReportId: "site-report-opaque-1"
                )
                #expect(payload != nil)
                guard let payload else { return }
                #expect(payload.marineLifeUUID == "marine-life-french-angelfish")
                #expect(payload.contributionId == "contrib-opaque-1")
                #expect(payload.siteReportId == "site-report-opaque-1")
                #expect(payload.activityKind == "dive")
                #expect(payload.sightingDate == "2026-08-05")
                #expect(payload.timeOfDay == "day")
                #expect(payload.sightingDepthM == 12.5)
                #expect(payload.odmSiteId == nil)
                #expect(payload.diveSiteCatalogUUID == nil)
                #expect(payload.status == "active")
                #expect(payload.schemaVersion == SightingGraphExport.schemaVersion)
                #expect(SightingGraphExport.schemaVersion == 3)

                let fields = SightingGraphExport.firestoreFields(from: payload)
                #expect(fields["marineLifeUUID"] as? String == "marine-life-french-angelfish")
                #expect(fields["contributionId"] as? String == "contrib-opaque-1")
                #expect(fields["siteReportId"] as? String == "site-report-opaque-1")
                #expect(fields["lat"] == nil)
                #expect(fields["lon"] == nil)
                #expect(fields["latitude"] == nil)
                #expect(fields["longitude"] == nil)
                #expect(fields["profileID"] == nil)
                #expect(fields["uid"] == nil)
                #expect(fields["sightingUUID"] == nil)
                #expect(fields["siteName"] == nil)

                let siteID = UUID()
                let site = DiveSite(
                    id: siteID,
                    siteName: "Salt Pier",
                    country: "Bonaire",
                    region: "Kralendijk",
                    bodyOfWater: "Caribbean Sea",
                    siteTags: [DiveSiteCatalogMatcher.openDiveMapSiteTag(referenceID: "s4g6dz")]
                )
                let withSite = SightingGraphExport.payload(
                    sightingUUID: "local-sighting-2",
                    contributionId: "contrib-opaque-2",
                    marineLifeUUID: "marine-life-french-angelfish",
                    sightingDateTime: midday,
                    diveActivityID: diveID,
                    snorkelActivityID: nil,
                    diveSiteID: siteID,
                    sightingDepthMeters: nil,
                    catalogSites: [site]
                )
                #expect(withSite?.odmSiteId == "s4g6dz")
                #expect(withSite?.diveSiteCatalogUUID == siteID.uuidString.lowercased())
                #expect(withSite?.waterBody == "Caribbean Sea")
                #expect(withSite?.country == "Bonaire")
                #expect(withSite?.region == "Kralendijk")
                #expect(withSite?.sightingDepthM == nil)
                #expect(SightingGraphExport.firestoreFields(from: withSite!).keys.contains("country"))

                // Activity site fallback when sighting.diveSiteID is nil.
                let fromActivitySite = SightingGraphExport.payload(
                    sightingUUID: "local-sighting-3",
                    contributionId: "contrib-opaque-3",
                    marineLifeUUID: "marine-life-french-angelfish",
                    sightingDateTime: utcLate,
                    diveActivityID: diveID,
                    snorkelActivityID: nil,
                    diveSiteID: nil,
                    sightingDepthMeters: 10,
                    catalogSites: [site],
                    activity: .init(diveSiteID: siteID, timeZoneOffsetSeconds: -4 * 3600)
                )
                #expect(fromActivitySite?.odmSiteId == "s4g6dz")
                #expect(fromActivitySite?.country == "Bonaire")
                #expect(fromActivitySite?.timeOfDay == "crepuscular")
                #expect(fromActivitySite?.sightingDate == "2026-08-05")

                let userSiteID = UUID()
                let catalogRef = UUID()
                let userSite = UserDiveSite(
                    id: userSiteID,
                    siteName: "Custom Reef",
                    country: "Curaçao",
                    region: "Westpunt",
                    bodyOfWater: "Caribbean Sea",
                    catalogDiveSiteID: catalogRef,
                    openDiveMapReferenceID: "odm-custom-1"
                )
                let fromUserSite = SightingGraphExport.payload(
                    sightingUUID: "local-sighting-4",
                    contributionId: "contrib-opaque-4",
                    marineLifeUUID: "marine-life-french-angelfish",
                    sightingDateTime: midday,
                    diveActivityID: diveID,
                    snorkelActivityID: nil,
                    diveSiteID: nil,
                    sightingDepthMeters: 8,
                    catalogSites: [],
                    userSites: [userSite],
                    activity: .init(diveSiteID: userSiteID, timeZoneOffsetSeconds: -4 * 3600)
                )
                #expect(fromUserSite?.odmSiteId == "odm-custom-1")
                #expect(fromUserSite?.diveSiteCatalogUUID == catalogRef.uuidString.lowercased())
                #expect(fromUserSite?.country == "Curaçao")

                #expect(
                    SightingGraphExport.payload(
                        sightingUUID: "x",
                        contributionId: "y",
                        marineLifeUUID: "marine-life-x",
                        sightingDateTime: midday,
                        diveActivityID: nil,
                        snorkelActivityID: nil,
                        diveSiteID: nil,
                        sightingDepthMeters: 1,
                        catalogSites: []
                    ) == nil
                )
            }
            @Test @MainActor func marineLife_initNormalizesCommonName() throws {
                let species = MarineLife(uuid: "marine-life-title-case-test", commonName: "queen angelfish")
                #expect(species.commonName == "Queen Angelfish")
            }
            @Test @MainActor func marineLife_subcategoryDefaultsEmptyForSwiftDataMigration() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let species = MarineLife(uuid: "marine-life-migration-test", commonName: "Test Species")
                context.insert(species)
                try context.save()
                #expect(species.subcategory == "")
            }
            @Test func sightingInstanceDateTimeResolution_prefersMediaCapturedAt() {
                let diveStart = Date(timeIntervalSince1970: 1_000_000)
                let mediaTime = Date(timeIntervalSince1970: 1_000_500)
                #expect(
                    SightingInstanceDateTimeResolution.resolvedUTCDateTime(
                        diveStartTime: diveStart,
                        mediaCapturedAt: mediaTime
                    ) == mediaTime
                )
                #expect(
                    SightingInstanceDateTimeResolution.resolvedUTCDateTime(
                        diveStartTime: diveStart,
                        mediaCapturedAt: nil
                    ) == diveStart
                )
            }
            @Test @MainActor func sightingInstanceCreation_insert_linksMarineLifeAndDive() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext

                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 2_000_000),
                    durationMinutes: 45,
                    maxDepthMeters: 18
                )
                let species = MarineLife(uuid: "marine-life-test-ray", commonName: "Spotted Eagle Ray")
                context.insert(dive)
                context.insert(species)

                let draft = SightingInstanceCreation.makeDraft(
                    marineLifeUUID: species.uuid,
                    dive: dive,
                    sightingDepthMeters: 12
                )
                let sighting = try SightingInstanceCreation.insert(
                    draft: draft,
                    dive: dive,
                    modelContext: context
                )

                #expect(sighting.marineLifeUUID == species.uuid)
                #expect(sighting.diveActivityID == dive.id)
                #expect(sighting.sightingDateTime == dive.startTime)
                #expect(sighting.sightingDepthMeters == 12)
                #expect(sighting.mediaPhotoID == nil)
            }
            @Test func expandableDetailSectionPresentation_collapsedByDefaultWithItems() {
                #expect(ExpandableDetailSectionPresentation.showsExpandControl(itemCount: 0) == false)
                #expect(ExpandableDetailSectionPresentation.showsExpandControl(itemCount: 3))
                #expect(
                    ExpandableDetailSectionPresentation.headerAccessibilityLabel(
                        title: "Dives together",
                        itemCount: 2,
                        isExpanded: false
                    ).contains("collapsed")
                )
                #expect(
                    ExpandableDetailSectionPresentation.headerAccessibilityLabel(
                        title: "Activities at this site",
                        itemCount: 1,
                        isExpanded: true
                    ).contains("expanded")
                )
            }
            @Test func appLaunchLayout_matchesStoryboardConstraints() {
                let safeMidY: CGFloat = 400
                let logoCenterY = AppLaunchLayout.logoCenterY(safeAreaMidY: safeMidY)
                #expect(logoCenterY == safeMidY - 48)

                let titleCenterY = AppLaunchLayout.titleCenterY(logoCenterY: logoCenterY)
                #expect(titleCenterY == logoCenterY + 64 + AppLaunchLayout.logoToTitleSpacing + AppLaunchLayout.titleLineHeight / 2)

                #expect(AppLaunchLayout.logoSize == 128)
                #expect(AppLaunchLayout.logoToTitleSpacing == 10)
                #if canImport(UIKit)
                let launchTitleFont = UIFont.boldSystemFont(
                    ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
                )
                #expect(AppLaunchLayout.titleFontSize == launchTitleFont.pointSize)
                #expect(AppLaunchLayout.titleLineHeight == ceil(launchTitleFont.lineHeight))
                #else
                #expect(AppLaunchLayout.titleFontSize == 34)
                #endif
                #expect(AppLaunchLayout.fixedBackgroundBlue == 0.09)
                #expect(AppLaunchLayout.fixedTitleRed == 0.64)
                #expect(AppLaunchLayout.fixedTitleGreen == 0.90)
                #expect(AppLaunchLayout.fixedTitleBlue == 1.0)
            }
            @Test @MainActor func diveTripDeletion_deletePermanentlyRemovesTrip() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let profile = UserProfile(appleUserIdentifier: "trip-delete", displayName: "Diver")
                context.insert(profile)

                let trip = DiveTrip(
                    startDate: .now,
                    endDate: .now,
                    countries: ["Bonaire"],
                    title: "Delete me",
                    owner: profile
                )
                context.insert(trip)
                try context.save()

                try DiveTripDeletion.deletePermanently(trip, modelContext: context)

                let remaining = try context.fetch(FetchDescriptor<DiveTrip>())
                #expect(remaining.isEmpty)
            }
            @Test @MainActor func diveTripShareOfferPresentation_onlyNewlyAddedLinkedFriends() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let profile = UserProfile(appleUserIdentifier: "trip-share-offer", displayName: "Diver")
                context.insert(profile)

                let friend = DiveBuddy(displayName: "Alex", owner: profile)
                friend.linkedFirebaseUID = "friend-uid"
                let local = DiveBuddy(displayName: "Local", owner: profile)
                context.insert(friend)
                context.insert(local)

                let trip = DiveTrip(
                    startDate: .now,
                    endDate: .now,
                    title: "Shared",
                    owner: profile
                )
                context.insert(trip)

                let roster = [friend.id: friend, local.id: local]
                let candidates = DiveTripShareOfferPresentation.candidates(
                    previousBuddyIDs: [],
                    newBuddyIDs: [friend.id, local.id],
                    rosterByID: roster,
                    trip: trip
                )
                #expect(candidates.map(\.friendUID) == ["friend-uid"])

                DiveTripShareLineagePresentation.recordSharedWithFriend(trip, friendUID: "friend-uid")
                let again = DiveTripShareOfferPresentation.candidates(
                    previousBuddyIDs: [],
                    newBuddyIDs: [friend.id],
                    rosterByID: roster,
                    trip: trip
                )
                #expect(again.isEmpty)
            }
            @Test @MainActor func diveTripShareMaterializer_createsPendingInviteeCopyAndLocksEdits() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let profile = UserProfile(appleUserIdentifier: "trip-share-materialize", displayName: "Recipient")
                context.insert(profile)

                let siteID = UUID()
                let start = Date(timeIntervalSince1970: 1_900_000_000)
                let end = Date(timeIntervalSince1970: 1_900_100_000)
                let shared = GoDiveTripShareMapping.SharedTripSnapshot(
                    tripID: "SOURCE-TRIP",
                    title: "Bonaire",
                    startDate: start,
                    endDate: end,
                    countries: ["Bonaire"],
                    plannedSiteIDs: [siteID.uuidString],
                    updatedAt: end,
                    createdAt: start,
                    schemaVersion: 1
                )
                let invite = GoDiveTripShareMapping.InviteSnapshot(
                    inviteID: "sharer_SOURCE-TRIP",
                    sharerUID: "sharer-uid",
                    tripID: "SOURCE-TRIP",
                    status: .pending,
                    title: "Bonaire",
                    sharerDisplayName: "Alex",
                    createdAt: start,
                    updatedAt: nil,
                    schemaVersion: 1
                )

                let result = GoDiveTripShareMaterializer.materializePending(
                    invite: invite,
                    sharedTrip: shared,
                    owner: profile,
                    modelContext: context
                )
                try context.save()
                #expect(result.created)
                let trip = try #require(
                    context.fetch(FetchDescriptor<DiveTrip>()).first { $0.id == result.tripID }
                )
                #expect(DiveTripShareLineagePresentation.isPendingInvite(trip))
                #expect(!DiveTripShareLineagePresentation.canEditSharedDetails(trip))
                #expect(trip.ownerProfileID == profile.id)
                #expect(trip.plannedSiteIDs == [siteID])
                #expect(trip.sharedFromFirebaseUID == "sharer-uid")

                var updatedShared = shared
                updatedShared.title = "Bonaire Reef"
                updatedShared.countries = ["Bonaire", "Curaçao"]
                updatedShared.updatedAt = end.addingTimeInterval(60)
                #expect(GoDiveTripShareMaterializer.applySyncedFields(updatedShared, to: trip))
                #expect(trip.title == "Bonaire Reef")
                #expect(trip.countries == ["Bonaire", "Curaçao"])
                #expect(!GoDiveTripShareMaterializer.applySyncedFields(updatedShared, to: trip))

                GoDiveTripShareMaterializer.markAccepted(trip)
                #expect(DiveTripShareLineagePresentation.isAcceptedInvite(trip))
                #expect(
                    TripPlannerPresentation.listRowDisplayData(for: trip, phase: .upcoming).inviteBadgeTitle
                        == nil
                )
                #expect(
                    DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).contains {
                        $0.linkedFirebaseUID == "sharer-uid"
                    }
                )
            }
            @Test func diveTripShareLineage_ordinaryTripCanEditSharedDetails() {
                let trip = DiveTrip(startDate: .now, endDate: .now, title: "Mine")
                #expect(DiveTripShareLineagePresentation.canEditSharedDetails(trip))
                #expect(!DiveTripShareLineagePresentation.isSharedInviteeCopy(trip))
            }
            @Test @MainActor func diveTripPlannedBuddyLinking_addsAndRemovesBuddies() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext

                let owner = UserProfile(appleUserIdentifier: "owner-planned-buddies", displayName: "Alex")
                let buddy = DiveBuddy(displayName: "Jordan", owner: owner)
                let trip = DiveTrip(
                    startDate: Date(timeIntervalSince1970: 2_000_000),
                    endDate: Date(timeIntervalSince1970: 2_086_400),
                    owner: owner
                )
                context.insert(owner)
                context.insert(buddy)
                context.insert(trip)

                #expect(DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).isEmpty)
                #expect(!DiveTripPlannedBuddyLinking.isBuddyOnTrip(buddyID: buddy.id, trip: trip))

                DiveTripPlannedBuddyLinking.addBuddy(buddy, to: trip, modelContext: context)
                #expect(DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).map(\.id) == [buddy.id])
                #expect(DiveTripPlannedBuddyLinking.isBuddyOnTrip(buddyID: buddy.id, trip: trip))

                DiveTripPlannedBuddyLinking.toggleBuddy(buddy, on: trip, modelContext: context)
                #expect(DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).isEmpty)
            }
            @Test @MainActor func diveTripPlannedBuddyDraftPresentation_apply_writesOnlyOnDoneDiff() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext

                let owner = UserProfile(appleUserIdentifier: "owner-planned-buddy-draft", displayName: "Alex")
                let jordan = DiveBuddy(displayName: "Jordan", owner: owner)
                let sam = DiveBuddy(displayName: "Sam", owner: owner)
                let trip = DiveTrip(
                    startDate: Date(timeIntervalSince1970: 2_000_000),
                    endDate: Date(timeIntervalSince1970: 2_086_400),
                    owner: owner
                )
                context.insert(owner)
                context.insert(jordan)
                context.insert(sam)
                context.insert(trip)

                DiveTripPlannedBuddyLinking.addBuddy(jordan, to: trip, modelContext: context)
                try context.save()

                let initial = DiveTripPlannedBuddyDraftPresentation.plannedBuddyIDs(on: trip)
                #expect(initial == [jordan.id])

                DiveTripPlannedBuddyDraftPresentation.apply(
                    draftBuddyIDs: [sam.id],
                    to: trip,
                    rosterByID: [jordan.id: jordan, sam.id: sam],
                    modelContext: context
                )
                try context.save()

                #expect(DiveTripPlannedBuddyDraftPresentation.plannedBuddyIDs(on: trip) == [sam.id])
                #expect(DiveTripPlannedBuddyLinking.plannedBuddies(for: trip).map(\.id) == [sam.id])
            }
            @Test @MainActor func diveTripPlannedBuddyDraftPresentation_rosterByID_fallsBackToModelContext() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let owner = UserProfile(appleUserIdentifier: "owner-roster-fallback", displayName: "Alex")
                let jordan = DiveBuddy(displayName: "Jordan", owner: owner)
                context.insert(owner)
                context.insert(jordan)
                try context.save()

                let map = DiveTripPlannedBuddyDraftPresentation.rosterByID(
                    ownedBuddies: [],
                    selectedBuddyIDs: [jordan.id],
                    modelContext: context
                )
                #expect(map[jordan.id]?.displayName == "Jordan")

                let selected = DiveTripPlannedBuddyDraftPresentation.selectedBuddies(
                    ownedBuddies: [],
                    selectedBuddyIDs: [jordan.id],
                    modelContext: context
                )
                #expect(selected.map(\.id) == [jordan.id])
            }
            @Test func goDiveLogoPin_assetResolvesDistinctImagesForLightAndDark() {
                #if canImport(UIKit)
                let lightTraits = UITraitCollection(userInterfaceStyle: .light)
                let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
                let lightImage = UIImage(
                    named: GoDiveLogoPinPresentation.assetName,
                    in: Bundle.main,
                    compatibleWith: lightTraits
                )
                let darkImage = UIImage(
                    named: GoDiveLogoPinPresentation.assetName,
                    in: Bundle.main,
                    compatibleWith: darkTraits
                )
                #expect(lightImage != nil)
                #expect(darkImage != nil)
                #expect(lightImage?.pngData() != darkImage?.pngData())
                let lightHasAlpha = lightImage?.cgImage.map { image in
                    switch image.alphaInfo {
                    case .none, .noneSkipFirst, .noneSkipLast:
                        false
                    default:
                        true
                    }
                } ?? false
                let darkHasAlpha = darkImage?.cgImage.map { image in
                    switch image.alphaInfo {
                    case .none, .noneSkipFirst, .noneSkipLast:
                        false
                    default:
                        true
                    }
                } ?? false
                #expect(lightHasAlpha)
                #expect(darkHasAlpha)
                #endif
            }
            @MainActor
            @Test func tripHeroMediaSession_reusesRandomPickForTrip() {
                TripHeroMediaSession.resetForTesting()
                let tripID = UUID()
                let first = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 100))
                let second = DiveMediaPhoto(capturedAt: Date(timeIntervalSince1970: 200))
                let photos = [first, second]

                let initial = TripHeroMediaSession.resolvedRandomHeroMediaID(
                    tripID: tripID,
                    in: photos
                )
                #expect(initial == first.id || initial == second.id)

                let again = TripHeroMediaSession.resolvedRandomHeroMediaID(
                    tripID: tripID,
                    in: photos
                )
                #expect(again == initial)

                TripHeroMediaSession.resetForTesting()
            }
            @Test @MainActor func tripStackNavigationRoutes_tripDetailPrecedesSiteOnStack() {
                let tripID = UUID()
                let siteID = UUID()
                let mediaID = UUID()

                let exploreStack: [ExploreRoute] = [
                    .tripPlanner,
                    .tripDetail(tripID),
                    .siteDetail(siteID),
                ]
                #expect(exploreStack.count == 3)
                #expect(exploreStack[1] == .tripDetail(tripID))

                let homeStack: [HomeRoute] = [
                    .profile,
                    .tripPlanner,
                    .tripDetail(tripID),
                    .diveSite(siteID),
                ]
                #expect(homeStack[2] == .tripDetail(tripID))

                let logbookStack: [LogbookRoute] = [
                    .tripDetail(tripID),
                    .diveSite(siteID),
                ]
                #expect(logbookStack[0] == .tripDetail(tripID))

                #expect(ExploreRoute.tripDetailMedia(tripID: tripID, mediaID: mediaID)
                    == ExploreRoute.tripDetailMedia(tripID: tripID, mediaID: mediaID))
            }
            @Test func diveSignatureDataFormatting_emptyOrMissingIsNotDisplayable() {
                #expect(!DiveSignatureDataFormatting.hasDisplayableContent(nil))
                #if canImport(PencilKit)
                #expect(!DiveSignatureDataFormatting.hasDisplayableContent(PKDrawing().dataRepresentation()))
                #endif
            }
            @Test func mapPushPinMetrics_mapAnnotationImage_tipIsVerticallyCentered() {
                #expect(MapPushPinMetrics.mapAnnotationImageHeight == MapPushPinMetrics.renderedHeight * 2)
                #expect(MapPushPinMetrics.tipYInMapAnnotationImage == MapPushPinMetrics.mapAnnotationImageHeight * 0.5)
                #expect(MapPushPinMetrics.tipYInAnnotationView == MapPushPinMetrics.renderedHeight)
            }
            @Test func diveSiteEditPresentation_accessibilityIdentifiers() {
                #expect(DiveSiteEditPresentation.cancelAccessibilityIdentifier == "DiveSiteEditSheet.Cancel")
                #expect(DiveSiteEditPresentation.doneAccessibilityIdentifier == "DiveSiteEditSheet.Done")
                #expect(DiveSiteEditPresentation.rootAccessibilityIdentifier == "DiveSiteEditSheet.Root")
            }
            @Test func diveMapCameraLayoutContext_equatable() {
                let a = DiveMapCameraLayoutContext(
                    coordinateIdentity: "1,2",
                    layoutHeight: 800,
                    bottomContentMargin: 400,
                    topObstructionHeight: 100,
                    sheetHeightFraction: 0.5,
                    largeRestingFraction: 0.62
                )
                let b = DiveMapCameraLayoutContext(
                    coordinateIdentity: "1,2",
                    layoutHeight: 800,
                    bottomContentMargin: 400,
                    topObstructionHeight: 100,
                    sheetHeightFraction: 0.5,
                    largeRestingFraction: 0.62
                )
                #expect(a == b)
                #expect(
                    DiveMapCameraLayoutContext(
                        coordinateIdentity: "1,2",
                        layoutHeight: 800,
                        bottomContentMargin: 400,
                        topObstructionHeight: 100,
                        sheetHeightFraction: 0.2,
                        largeRestingFraction: 0.62
                    ) != a
                )
            }
            @Test func appNetworkConnectivityPresentation_offlineSkipsCloudMedia() {
                #expect(AppNetworkConnectivityPresentation.allowsCloudMediaFetch(isConnected: true))
                #expect(!AppNetworkConnectivityPresentation.allowsCloudMediaFetch(isConnected: false))
                #expect(AppNetworkConnectivityPresentation.photoKitAllowsNetworkAccess(isConnected: true))
                #expect(!AppNetworkConnectivityPresentation.photoKitAllowsNetworkAccess(isConnected: false))
                #expect(
                    DiveMediaProgressivePresentation.shouldUpgradeToFullVideo(
                        isPlaybackActive: true,
                        isPausedByUserHold: false,
                        currentFidelity: .preview,
                        isNetworkAvailable: false
                    ) == false
                )
            }
            @Test func homeLaunchCarouselHeroPresentation_usesQuietHeroUntilResolved() {
                #expect(
                    HomeLaunchCarouselHeroPresentation.showsQuietUnresolvedHero(
                        hasResolvedLaunchCarousel: false,
                        hasLoggedActivities: true,
                        hasCarouselHighlights: false
                    )
                )
                #expect(
                    !HomeLaunchCarouselHeroPresentation.showsQuietUnresolvedHero(
                        hasResolvedLaunchCarousel: true,
                        hasLoggedActivities: true,
                        hasCarouselHighlights: false
                    )
                )
                #expect(
                    !HomeLaunchCarouselHeroPresentation.showsQuietUnresolvedHero(
                        hasResolvedLaunchCarousel: false,
                        hasLoggedActivities: true,
                        hasCarouselHighlights: true
                    )
                )
                #expect(
                    !HomeLaunchCarouselHeroPresentation.showsQuietUnresolvedHero(
                        hasResolvedLaunchCarousel: false,
                        hasLoggedActivities: false,
                        hasCarouselHighlights: false
                    )
                )
            }
            @Test func metricKitLaunchMetricsPresentation_formatsHistogramBuckets() {
                #expect(
                    MetricKitLaunchMetricsPresentation.formatBucketLine(
                        .init(startMilliseconds: 100, endMilliseconds: 200, count: 3)
                    ) == "100-200ms x3"
                )
                #expect(
                    MetricKitLaunchMetricsPresentation.formatHistogramSummary(name: "timeToFirstDraw", buckets: [])
                        == "timeToFirstDraw: (empty)"
                )
                #expect(
                    MetricKitLaunchMetricsPresentation.formatHistogramSummary(
                        name: "timeToFirstDraw",
                        buckets: [
                            .init(startMilliseconds: 200, endMilliseconds: 300, count: 2),
                            .init(startMilliseconds: 300, endMilliseconds: 400, count: 1),
                        ]
                    ) == "timeToFirstDraw: samples=3 [200-300ms x2, 300-400ms x1]"
                )
                let summary = MetricKitLaunchMetricsPresentation.summaryText(
                    timeStampEnd: Date(timeIntervalSince1970: 0),
                    appBuildVersion: "1",
                    osVersion: "26.0",
                    timeToFirstDraw: [.init(startMilliseconds: 400, endMilliseconds: 500, count: 1)],
                    optimizedTimeToFirstDraw: [],
                    applicationResumeTime: [],
                    extendedLaunch: []
                )
                #expect(summary.contains("timeToFirstDraw: samples=1 [400-500ms x1]"))
                #expect(summary.contains("optimizedTimeToFirstDraw: (empty)"))
                #expect(MetricKitLaunchMetricsPresentation.summaryFileName == "metrickit-launch-summary.txt")
                let ms = MetricKitLaunchMetricsPresentation.milliseconds(
                    from: Measurement(value: 0.25, unit: UnitDuration.seconds)
                )
                #expect(abs(ms - 250) < 0.001)
            }
            @Test func appListTileCardChrome_matchesLogbookActivityRowFillAndStroke() {
                #expect(AppListTileCardChrome.fill == AppTheme.Colors.surfaceElevated)
                #expect(AppListTileCardChrome.strokeWidth == 1)
            }
            @Test func rootStackReturnNavigationPresentation_tabBarRestoreAndLogbookSkip() {
                #expect(RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: 0))
                #expect(!RootStackReturnNavigationPresentation.isStackAtRoot(pathCount: 1))
                #expect(
                    RootStackReturnNavigationPresentation.shouldSkipLogbookCacheRefreshOnReturn(
                        hasPerformedInitialCacheBuild: true,
                        hasDisplayRows: true
                    )
                )
                #expect(
                    !RootStackReturnNavigationPresentation.shouldSkipLogbookCacheRefreshOnReturn(
                        hasPerformedInitialCacheBuild: false,
                        hasDisplayRows: true
                    )
                )
                #expect(
                    !RootStackReturnNavigationPresentation.shouldSkipLogbookCacheRefreshOnReturn(
                        hasPerformedInitialCacheBuild: true,
                        hasDisplayRows: false
                    )
                )
            }
            @Test func appPerformanceSignpost_intervalNamesAreStable() {
                #expect(AppPerformanceSignpost.Interval.launchContainerLoad.rawValue == "LaunchContainerLoad")
                #expect(AppPerformanceSignpost.Interval.launchSessionRestore.rawValue == "LaunchSessionRestore")
                #expect(AppPerformanceSignpost.Interval.launchSessionValidation.rawValue == "LaunchSessionValidation")
                #expect(AppPerformanceSignpost.Interval.launchEssentialMaintenance.rawValue == "LaunchEssentialMaintenance")
                #expect(AppPerformanceSignpost.Interval.launchMarineLifeSeed.rawValue == "LaunchMarineLifeSeed")
                #expect(AppPerformanceSignpost.Interval.homeOverviewRebuild.rawValue == "HomeOverviewRebuild")
                #expect(AppPerformanceSignpost.Interval.tripDetailContentRebuild.rawValue == "TripDetailContentRebuild")
            }
            @Test func appLaunchTimelineLog_eventNamesAreStable() {
                // Keep the console filter vocabulary documented for Xcode category **LaunchTimeline**.
                let names = [
                    "splash.container_load_begin",
                    "splash.container_ready",
                    "splash.restore_begin",
                    "splash.restore_end",
                    "splash.home_chrome_ready",
                    "splash.home_chrome_ready_failsafe",
                    "splash.overlay_hidden",
                    "splash.main_shell_visible",
                    "home.root_appear",
                    "home.rebuild_scheduled",
                    "home.stats_applied",
                    "home.carousel_previews_seeded",
                    "home.enrich_deferred_begin",
                    "home.carousel_warm_deferred_begin",
                    "home.catalog_names_deferred_begin",
                    "home.preview_persist_deferred_begin",
                    "home.rebuild_applied",
                    "home.query_dives_changed",
                    "home.ownership_healed",
                ]
                #expect(names.count == 19)
                #expect(Set(names).count == names.count)
                #expect(AppLaunchTimelineLog.elapsedMilliseconds() >= 0)
            }
            @Test func homeLaunchChromePresentation_marksUntilReady() {
                #expect(HomeLaunchChromePresentation.shouldMarkChromeReady(isAlreadyReady: false))
                #expect(!HomeLaunchChromePresentation.shouldMarkChromeReady(isAlreadyReady: true))
                #expect(AppLaunchPostOverlayPresentation.homeChromeReadyFailsafeNanoseconds == 8_000_000_000)
            }
            @Test @MainActor func homeDiveScalarSeeding_buddyTagSeeds_fallsBackWhenDiveActivityIDMissing() throws {
                let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
                let context = ModelContext(dual.container)
                let owner = UserProfile(
                    appleUserIdentifier: "buddy-tag-fallback",
                    displayName: "Owner"
                )
                context.insert(owner)
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 1_700_000_000),
                    durationMinutes: 40,
                    maxDepthMeters: 20
                )
                dive.owner = owner
                context.insert(dive)
                let buddy = DiveBuddy(displayName: "Alex")
                context.insert(buddy)
                let tag = DiveBuddyTag(buddy: buddy, dive: dive)
                // Simulate legacy / CloudKit row that never received denormalized diveActivityID.
                tag.diveActivityID = nil
                context.insert(tag)
                try context.save()

                let seeds = HomeDiveScalarSeeding.buddyTagSeeds(
                    ownerDiveIDs: [dive.id],
                    activities: [dive],
                    buddyRoster: [buddy],
                    modelContext: context
                )
                #expect(seeds.count == 1)
                #expect(seeds[0].buddyID == buddy.id)
                #expect(seeds[0].diveActivityID == dive.id)
                #expect(seeds[0].displayName == "Alex")

                let launch = HomeOverviewAggregateBuilder.buildLaunch(
                    activities: [dive],
                    buddyRoster: [buddy],
                    automaticallyRenumberDives: true,
                    ownerProfileID: owner.id,
                    ownerProfile: owner,
                    modelContext: context
                )
                #expect(launch.aggregate.buddyLeaderboard.count == 1)
                #expect(launch.aggregate.buddyLeaderboard[0].id == buddy.id)
            }
            @Test @MainActor func homeDiveScalarSeeding_sightingAndMediaBuddySeeds_fallBackWhenDiveActivityIDMissing() throws {
                let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
                let context = ModelContext(dual.container)
                let owner = UserProfile(
                    appleUserIdentifier: "sighting-fallback",
                    displayName: "Owner"
                )
                context.insert(owner)
                let dive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 1_700_000_100),
                    durationMinutes: 40,
                    maxDepthMeters: 20
                )
                dive.owner = owner
                context.insert(dive)
                let sighting = SightingInstance(
                    marineLifeUUID: "ml-uuid-1",
                    sightingDateTime: Date(timeIntervalSince1970: 1_700_000_110),
                    diveActivity: dive
                )
                // Simulate legacy / CloudKit row that never received denormalized diveActivityID.
                sighting.diveActivityID = nil
                context.insert(sighting)
                let buddy = DiveBuddy(displayName: "Sam")
                context.insert(buddy)
                let media = DiveMediaPhoto(sortOrder: 0, dive: dive)
                context.insert(media)
                let mediaTag = DiveMediaBuddyTag(buddy: buddy, mediaPhoto: media, diveActivity: dive)
                mediaTag.diveActivityID = nil
                context.insert(mediaTag)
                try context.save()

                let sightings = HomeDiveScalarSeeding.sightingSeeds(
                    ownerDiveIDs: [dive.id],
                    activities: [dive],
                    commonNameByUUID: ["ml-uuid-1": "Manta"],
                    modelContext: context
                )
                #expect(sightings.count == 1)
                #expect(sightings[0].marineLifeUUID == "ml-uuid-1")
                #expect(sightings[0].commonName == "Manta")
                #expect(sightings[0].diveActivityID == dive.id)

                let mediaBuddyTags = HomeDiveScalarSeeding.mediaBuddyTagSeeds(
                    ownerDiveIDs: [dive.id],
                    activities: [dive],
                    modelContext: context
                )
                #expect(mediaBuddyTags.count == 1)
                #expect(mediaBuddyTags[0].buddyID == buddy.id)
                #expect(mediaBuddyTags[0].diveActivityID == dive.id)

                let instances = HomeDiveScalarSeeding.fetchSightingInstances(
                    ownerDiveIDs: [dive.id],
                    activities: [dive],
                    modelContext: context
                )
                #expect(instances.count == 1)
                #expect(instances[0].marineLifeUUID == "ml-uuid-1")
            }
            @Test func appLaunchSessionRestorePresentation_persistedProfileID_parsesStoredUUID() {
                let id = UUID()
                #expect(
                    AppLaunchSessionRestorePresentation.persistedProfileID(storedUUIDString: id.uuidString) == id
                )
                #expect(AppLaunchSessionRestorePresentation.persistedProfileID(storedUUIDString: nil) == nil)
                #expect(AppLaunchSessionRestorePresentation.persistedProfileID(storedUUIDString: "not-a-uuid") == nil)
            }
            @Test func appLaunchSessionRestorePresentation_keychainRoundTripAndLegacyMigration() {
                let suite = "session-restore-\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suite)!
                GoDiveKeychainStore.testingStore = [:]
                defer {
                    defaults.removePersistentDomain(forName: suite)
                    GoDiveKeychainStore.testingStore = nil
                }
                let id = UUID()
                defaults.set(id.uuidString, forKey: AppLaunchSessionRestorePresentation.currentProfileIDUserDefaultsKey)

                let loaded = AppLaunchSessionRestorePresentation.loadPersistedProfileID(userDefaults: defaults)
                #expect(loaded == id)
                #expect(defaults.string(forKey: AppLaunchSessionRestorePresentation.currentProfileIDUserDefaultsKey) == nil)
                #expect(GoDiveKeychainStore.string(for: .currentProfileID) == id.uuidString)

                AppLaunchSessionRestorePresentation.clearPersistedProfileID(userDefaults: defaults)
                #expect(AppLaunchSessionRestorePresentation.loadPersistedProfileID(userDefaults: defaults) == nil)
            }
            @Test func snorkelSwimTrackCodec_roundTripsGPSAndHeartRateSamples() throws {
                let start = Date(timeIntervalSinceReferenceDate: 700_000)
                let samples = [
                    SnorkelSwimTrackSample(
                        timestamp: start,
                        latitude: 21.3069,
                        longitude: -157.8583,
                        heartRateBPM: 92
                    ),
                    SnorkelSwimTrackSample(
                        timestamp: start.addingTimeInterval(45),
                        latitude: 21.3071,
                        longitude: -157.8580,
                        heartRateBPM: nil
                    ),
                ]
                let data = try #require(try SnorkelSwimTrackCodec.encode(samples: samples, activityStartTime: start))
                let decoded = try SnorkelSwimTrackCodec.decode(data, activityStartTime: start)
                #expect(decoded.count == 2)
                #expect(decoded[0].heartRateBPM == 92)
                #expect(abs(decoded[1].latitude - 21.3071) < 0.0001)
                #expect(decoded[1].heartRateBPM == nil)
            }
            @Test @MainActor
            func snorkelProfilePointStore_materializesLocalRowsFromSwimTrackBlob() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)

                let profile = UserProfile(appleUserIdentifier: "snorkel-track", displayName: "Diver")
                context.insert(profile)
                let snorkel = SnorkelActivity(startTime: Date(), durationMinutes: 25)
                SnorkelActivityOwnership.assignOwner(profile, to: snorkel)
                snorkel.profilePoints = [
                    SnorkelProfilePoint(
                        timestamp: snorkel.startTime,
                        latitude: 20.0,
                        longitude: -155.0,
                        heartRateBPM: 88,
                        snorkelActivityID: snorkel.id
                    ),
                ]
                SnorkelProfilePointStore.syncTrackData(from: snorkel)
                #expect(snorkel.swimTrackData != nil)
                snorkel.profilePoints = []
                context.insert(snorkel)
                try context.save()

                let inserted = try SnorkelProfilePointStore.materializeFromTrackIfNeeded(
                    activity: snorkel,
                    modelContext: context
                )
                #expect(inserted == 1)
                let fetched = try SnorkelProfilePointStore.fetchPoints(for: snorkel.id, modelContext: context)
                #expect(fetched.count == 1)
                #expect(fetched.first?.heartRateBPM == 88)
            }
            @Test func appLaunchSessionValidationPolicy_offlineFirstKeepsSessionWhenCredentialCheckFails() {
                #expect(!AppLaunchSessionValidationPolicy.shouldSignOut(credentialState: nil, checkFailed: true))
            }
            @Test func appLaunchSessionValidationPolicy_signsOutWhenCredentialRevoked() {
                #expect(
                    AppLaunchSessionValidationPolicy.shouldSignOut(
                        credentialState: .revoked,
                        checkFailed: false
                    )
                )
                #expect(
                    !AppLaunchSessionValidationPolicy.shouldSignOut(
                        credentialState: .authorized,
                        checkFailed: false
                    )
                )
            }
            @Test func homeRootViewportPresentation_frozenHeightWhilePushed() {
                let resolution = HomeRootViewportPresentation.resolvedViewportHeight(
                    geometryHeight: 852,
                    isNavigationStackAtRoot: false,
                    frozenRootViewportHeight: 803
                )
                #expect(resolution.height == 803)
                #expect(resolution.frozenRootViewportHeight == 803)
                let latched = HomeRootViewportPresentation.resolvedViewportHeight(
                    geometryHeight: 852,
                    isNavigationStackAtRoot: true,
                    frozenRootViewportHeight: 803
                )
                #expect(latched.height == 852)
                #expect(latched.frozenRootViewportHeight == 852)
            }
            @Test func appSessionBootstrapPresentation_showsLaunchOverlayWhileRestoringOrPopulating() {
                #expect(
                    AppSessionBootstrapPresentation.showsLaunchOverlay(
                        isRestoringSession: true,
                        isPopulatingRemoteAccountData: false
                    )
                )
                #expect(
                    AppSessionBootstrapPresentation.showsLaunchOverlay(
                        isRestoringSession: false,
                        isPopulatingRemoteAccountData: true
                    )
                )
                #expect(
                    !AppSessionBootstrapPresentation.showsLaunchOverlay(
                        isRestoringSession: false,
                        isPopulatingRemoteAccountData: false
                    )
                )
                // Main shell mounted but Home first paint (stats + carousel) not ready — keep splash up.
                #expect(
                    AppSessionBootstrapPresentation.showsLaunchOverlay(
                        isRestoringSession: false,
                        isPopulatingRemoteAccountData: false,
                        showsMainAppShell: true,
                        isHomeLaunchChromeReady: false
                    )
                )
                #expect(
                    !AppSessionBootstrapPresentation.showsLaunchOverlay(
                        isRestoringSession: false,
                        isPopulatingRemoteAccountData: false,
                        showsMainAppShell: true,
                        isHomeLaunchChromeReady: true
                    )
                )
                // Celebration / post-sign-up gates — shell not showing; do not pin splash on Home chrome.
                #expect(
                    !AppSessionBootstrapPresentation.showsLaunchOverlay(
                        isRestoringSession: false,
                        isPopulatingRemoteAccountData: false,
                        showsMainAppShell: false,
                        isHomeLaunchChromeReady: false
                    )
                )
                // Shell under splash (including fade) must not steal carousel / tab hits.
                #expect(
                    !AppSessionBootstrapPresentation.launchOverlayAllowsHitTesting(
                        showsMainAppShell: true,
                        isHomeLaunchChromeReady: false
                    )
                )
                #expect(
                    !AppSessionBootstrapPresentation.launchOverlayAllowsHitTesting(
                        showsMainAppShell: true,
                        isHomeLaunchChromeReady: true
                    )
                )
                #expect(
                    AppSessionBootstrapPresentation.launchOverlayAllowsHitTesting(
                        showsMainAppShell: false
                    )
                )
            }
            @Test func goDiveCloudKitPrivateImportNotification_defaultPollIntervalIsResponsive() {
                #expect(GoDiveCloudKitPrivateImportNotification.defaultPollIntervalMilliseconds == 150)
                #expect(GoDiveCloudKitPrivateImportNotification.defaultPollIntervalMilliseconds < 500)
            }
            @Test func appLaunchPostOverlayPresentation_defersHeavyWorkAfterFirstFrame() {
                #expect(AppLaunchPostOverlayPresentation.initialHomeRebuildDeferNanoseconds == 0)
                #expect(AppLaunchPostOverlayPresentation.postChromeHomeEnrichDeferNanoseconds == 500_000_000)
                #expect(AppLaunchPostOverlayPresentation.postChromeCarouselWarmDeferNanoseconds == 750_000_000)
                #expect(AppLaunchPostOverlayPresentation.postChromeCatalogBindDeferNanoseconds == 2_000_000_000)
                #expect(AppLaunchPostOverlayPresentation.postChromePreviewPersistDeferNanoseconds == 1_000_000_000)
                #expect(AppLaunchPostOverlayPresentation.deferredMaintenanceDelaySeconds == 2)
                #expect(AppLaunchPostOverlayPresentation.deferredPhotoKitMaintenanceDelaySeconds == 8)
                #expect(AppLaunchPostOverlayPresentation.deferredMapWarmupDelaySeconds == 2.5)
            }
            @Test func lazyRootTabPresentation_gatesCatalogLoadsBySelection() {
                #expect(
                    LazyRootTabPresentation.catalogBindStart(
                        isTabSelected: true,
                        isHomeLaunchChromeReady: false
                    ) == .immediate
                )
                #expect(
                    LazyRootTabPresentation.catalogBindStart(
                        isTabSelected: false,
                        isHomeLaunchChromeReady: false
                    ) == .waitUntilChromeOrSelected
                )
                #expect(
                    LazyRootTabPresentation.catalogBindStart(
                        isTabSelected: false,
                        isHomeLaunchChromeReady: true
                    ) == .afterChromeQuietWindow
                )
                // Empty catalogs still count as loaded — do not re-scan SwiftData forever.
                #expect(
                    !LazyRootTabPresentation.shouldFetchCatalog(
                        hasLoadedCatalog: true,
                        force: false
                    )
                )
                #expect(
                    LazyRootTabPresentation.shouldFetchCatalog(
                        hasLoadedCatalog: false,
                        force: false
                    )
                )
                #expect(
                    LazyRootTabPresentation.shouldFetchCatalog(
                        hasLoadedCatalog: true,
                        force: true
                    )
                )
                #expect(LazyRootTabPresentation.emptyCatalogRetryNanoseconds == 2_000_000_000)
                #expect(
                    AppLaunchPostOverlayPresentation.postChromeIdleTabCatalogBindDeferNanoseconds
                        == 1_000_000_000
                )
                #expect(
                    AppLaunchPostOverlayPresentation.postChromeLaunchCarouselDeferNanoseconds == 0
                )
                #expect(
                    AppLaunchPostOverlayPresentation.postChromeCloudKitKickDeferNanoseconds
                        == 500_000_000
                )
                #expect(AppLaunchPostOverlayPresentation.deferredDiveSitesPrewarmDelaySeconds == 2.5)
                #expect(
                    HomeLaunchChromePresentation.shouldMarkChromeReadyAfterLaunchStats(
                        isAlreadyReady: false
                    )
                )
                #expect(
                    !HomeLaunchChromePresentation.shouldMarkChromeReadyAfterLaunchStats(
                        isAlreadyReady: true
                    )
                )
                #expect(RootTabBarSelectionSync.rootTab(forTabBarIndex: 0) == .home)
                #expect(RootTabBarSelectionSync.rootTab(forTabBarIndex: 1) == .logbook)
                #expect(RootTabBarSelectionSync.rootTab(forTabBarIndex: 2) == .fieldGuide)
                #expect(RootTabBarSelectionSync.rootTab(forTabBarIndex: 3) == .explore)
                #expect(RootTabBarSelectionSync.rootTab(forTabBarIndex: 4) == .search)
                #expect(RootTabBarSelectionSync.rootTab(forTabBarIndex: 99) == nil)
                #expect(
                    RootTabSelectionPresentation.shouldPauseBubbles(for: .logbook, selected: .home)
                )
                #expect(
                    !RootTabSelectionPresentation.shouldPauseBubbles(for: .logbook, selected: .logbook)
                )
            }
            @Test @MainActor
            func ownerDiveActivityLookup_fetchesDiveAndSnorkelByID() throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 30, maxDepthMeters: 18)
                let snorkel = SnorkelActivity(startTime: .now.addingTimeInterval(-3_600), durationMinutes: 40)
                context.insert(dive)
                context.insert(snorkel)
                try context.save()

                #expect(OwnerDiveActivityLookup.dive(id: dive.id, modelContext: context)?.id == dive.id)
                #expect(OwnerDiveActivityLookup.snorkel(id: snorkel.id, modelContext: context)?.id == snorkel.id)
                #expect(OwnerDiveActivityLookup.dive(id: UUID(), modelContext: context) == nil)
                #expect(OwnerDiveActivityLookup.snorkel(id: UUID(), modelContext: context) == nil)
            }
            @Test func homeSheetPanelBottomScrim_screenBottomAnchoredBandCenterY_pinsBandBottomToPhysicalScreen() {
                let layoutHeight: CGFloat = 818
                let safeBottom: CGFloat = 34
                let bandHeight = HomeOverviewLayout.pushedPanelBottomScrollFadeHeight(safeAreaBottom: safeBottom)
                let centerY = HomeSheetPanelBottomScrimPresentation.screenBottomAnchoredBandCenterY(
                    layoutHeight: layoutHeight,
                    safeAreaBottom: safeBottom,
                    bandHeight: bandHeight
                )
                #expect(centerY + bandHeight / 2 == layoutHeight + safeBottom)
            }
            @Test @MainActor func diveVideoSource_identityKey_distinguishesFileAndAsset() {
                let fileURL = URL(fileURLWithPath: "/tmp/clip.mov")
                #expect(DiveVideoSource.file(fileURL).identityKey == "file:\(fileURL.absoluteString)")
                #expect(DiveVideoSource.libraryAsset("ABC").identityKey == "asset:ABC")
                #expect(DiveVideoSource.file(fileURL) != DiveVideoSource.libraryAsset("ABC"))
            }
            @Test func diveMutedVideoAudioSession_usesAmbientMixWithOthers() {
                #expect(DiveMutedVideoAudioSession.categoryRawValueForTesting == "AVAudioSessionCategoryAmbient")
                #expect(DiveMutedVideoAudioSession.includesMixWithOthersForTesting)
            }
            @Test func appTheme_sheet_sharedPresentationChrome_isTranslucent() {
                #expect(AppTheme.Sheet.cornerRadius == 20)
                #expect(AppTheme.Sheet.backgroundMaterialOpacity > 0)
                #expect(AppTheme.Sheet.backgroundMaterialOpacity < 1)
                #expect(AppTheme.Sheet.backgroundMaterialOpacity < 0.75)
            }
            @Test func pushedDetailHeroModeTogglePresentation_compactChromeWidth() {
                #expect(PushedDetailHeroModeTogglePresentation.segmentSize == 44)
                #expect(PushedDetailHeroModeTogglePresentation.chromeWidth == 100)
            }
            @Test func appButtonChrome_standaloneIconMinTapDimension_matchesBackButton() {
                #expect(AppButtonChrome.standaloneIconMinTapDimension == SecondaryDestinationChromeMetrics.backButtonMinimumTapDimension)
                #expect(AppButtonChrome.standaloneIconMinTapDimension == AppToolbarIconButtonMetrics.tapDimension)
                #expect(AppToolbarIconButtonMetrics.tapDimension == AppTheme.Layout.glassChromeControlHeight)
            }
            @Test func googleMapsBootstrap_shouldWarmUpAtLaunch_respectsEngineAndUITestFlag() {
                #expect(
                    GoogleMapsBootstrap.shouldWarmUpAtLaunch
                        == (!GoDiveUITestConfiguration.isActive && GoDiveMapEngine.active == .googleMaps && GoogleMapsBootstrap.loadAPIKey() != nil)
                )
            }
            @Test @MainActor func activityWeatherConditionsPresentation_eligibilityAndFormatting() {
                let coordinate = DiveCoordinate(latitude: 21.3, longitude: -157.8)
                #expect(
                    ActivityWeatherConditionsPresentation.unavailableReason(
                        mapCoordinate: nil,
                        activityStart: Date(timeIntervalSince1970: 1_700_000_000)
                    ) == .noMapCoordinate
                )
                #expect(
                    ActivityWeatherConditionsPresentation.unavailableReason(
                        mapCoordinate: coordinate,
                        activityStart: Date(timeIntervalSince1970: 1_000_000_000)
                    ) == .beforeHistoryWindow
                )
                let referenceNow = Date(timeIntervalSince1970: 1_700_000_000)
                let farFuture = referenceNow.addingTimeInterval(11 * 86_400)
                #expect(
                    ActivityWeatherConditionsPresentation.unavailableReason(
                        mapCoordinate: coordinate,
                        activityStart: farFuture,
                        referenceNow: referenceNow
                    ) == .beyondForecastHorizon
                )
                let candidates = [
                    Date(timeIntervalSince1970: 100),
                    Date(timeIntervalSince1970: 500),
                    Date(timeIntervalSince1970: 900),
                ]
                let closest = ActivityWeatherConditionsPresentation.closestHourDate(
                    to: Date(timeIntervalSince1970: 480),
                    candidates: candidates
                )
                #expect(closest == Date(timeIntervalSince1970: 500))
                #expect(ActivityWeatherConditionsPresentation.humidityDisplay(fraction: 0.62) == "62% humidity")
                #expect(
                    ActivityWeatherConditionsPresentation.windDisplay(metersPerSecond: 5, displayUnits: .metric)
                    == "Wind 18 km/h"
                )
                #expect(
                    ActivityWeatherConditionsPresentation.dailyHighLowDisplay(
                        highCelsius: 30,
                        lowCelsius: 24,
                        displayUnits: .metric
                    )?.contains("High") == true
                )
                #expect(ActivityWeatherConditionsPresentation.normalizedHumidityFraction(0.55) == 0.55)
                #expect(ActivityWeatherConditionsPresentation.normalizedHumidityFraction(55) == 0.55)
                let range = ActivityWeatherConditionsPresentation.weatherQueryRange(
                    activityStart: Date(timeIntervalSince1970: 1_700_000_000),
                    timeZoneOffsetSeconds: -10 * 3600
                )
                #expect(range.end > range.start)

                let jwtError = NSError(
                    domain: "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors",
                    code: 2
                )
                #expect(
                    ActivityWeatherKitErrorMapping.failureReason(for: jwtError) == .permissionDenied
                )
                let urlError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
                #expect(ActivityWeatherKitErrorMapping.failureReason(for: urlError) == .network)
            }
            @Test func activityWeatherPersistedSnapshot_codecRoundTrips() throws {
                let referenceHour = Date(timeIntervalSince1970: 1_700_000_000)
                let capturedAt = Date(timeIntervalSince1970: 1_700_000_100)
                let snapshot = ActivityWeatherPersistedSnapshot(
                    conditionDescription: "Partly Cloudy",
                    symbolName: "cloud.sun.fill",
                    temperatureCelsius: 27.5,
                    humidityFraction: 0.62,
                    windMetersPerSecond: 5.2,
                    dailyHighCelsius: 30,
                    dailyLowCelsius: 24,
                    referenceHour: referenceHour,
                    usesDailyFallback: false,
                    capturedAt: capturedAt
                )
                let data = try ActivityWeatherPersistedSnapshotCodec.encode(snapshot)
                let decoded = try ActivityWeatherPersistedSnapshotCodec.decode(data)
                #expect(decoded == snapshot)
            }
            @Test func activityWeatherSnapshotStorage_rebuildsDisplayForUnits() {
                let activityStart = Date(timeIntervalSince1970: 1_700_000_000)
                let persisted = ActivityWeatherPersistedSnapshot(
                    conditionDescription: "Clear",
                    symbolName: "sun.max.fill",
                    temperatureCelsius: 28,
                    humidityFraction: 0.55,
                    windMetersPerSecond: 5,
                    dailyHighCelsius: 31,
                    dailyLowCelsius: 25,
                    referenceHour: activityStart,
                    usesDailyFallback: false,
                    capturedAt: activityStart
                )
                let data = try? ActivityWeatherPersistedSnapshotCodec.encode(persisted)
                let metric = ActivityWeatherSnapshotStorage.displaySnapshot(
                    from: data,
                    activityStart: activityStart,
                    timeZoneOffsetSeconds: -10 * 3_600,
                    displayUnits: .metric
                )
                let imperial = ActivityWeatherSnapshotStorage.displaySnapshot(
                    from: data,
                    activityStart: activityStart,
                    timeZoneOffsetSeconds: -10 * 3_600,
                    displayUnits: .imperial
                )
                #expect(metric?.conditionDescription == "Clear")
                #expect(metric?.temperatureDisplay.contains("28") == true)
                #expect(imperial?.temperatureDisplay.contains("°F") == true)
                #expect(metric?.humidityLine == "55% humidity")
            }
            @Test
            func fitFileImport_readFitFileData_nonFileURL_throws() {
                // `startAccessingSecurityScopedResource()` is not guaranteed to return `false` for sandbox temp
                // file URLs across OS versions; a non-file URL never gains scope, so import must throw.
                let url = URL(string: "https://example.com/godive-read-fit-test.fit")!
                #expect(throws: (any Error).self) {
                    try FitDiveFileImport.readFitFileData(from: url)
                }
            }
            @Test @MainActor
            func fitFileImport_emptyData_returnsOutcomeWithEmptyFileMessage() async throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])
                let context = ModelContext(container)
                let outcome = await FitDiveFileImport.importFitData(Data(), modelContext: context)
                #expect(outcome.userMessage == FitDecodeError.emptyFile.localizedDescription)
                #expect(outcome.primaryInsertedDiveId == nil)
            }
            @Test func diveSiteTimeZoneResolution_uddfHoursIfPersisted_readsStoredSiteTimezone() throws {
                let site = DiveSite(
                    siteName: "Cedar Pass",
                    timeZoneIdentifier: "America/Cancun",
                    timeZoneOffsetSeconds: -5 * 3600
                )
                let instant = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant("2021-07-18T14:53:45"))
                #expect(DiveSiteTimeZoneResolution.uddfHoursIfPersisted(from: site, at: instant) == -5.0)
            }
            @Test @MainActor
            func diveGeographicTimeZoneLookup_uddfHoursFromSite_usesPersistedCatalogSiteWithoutNetwork() async throws {
                let site = DiveSite(
                    siteName: "Cedar Pass",
                    latCoords: 20.37539,
                    longCoords: -87.0398,
                    timeZoneIdentifier: "America/Cancun",
                    timeZoneOffsetSeconds: -5 * 3600
                )
                let instant = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant("2021-07-18T14:53:45"))
                let resolver = FailingGeocodingTimeZoneResolver()
                let hours = await DiveGeographicTimeZoneLookup.uddfHoursFromSite(
                    latitude: site.latCoords,
                    longitude: site.longCoords,
                    locationName: site.siteName,
                    catalogSite: site,
                    at: instant,
                    resolver: resolver
                )
                #expect(hours == -5.0)
                #expect(resolver.coordinateLookupCount == 0)
            }
            @Test func diveGeographicTimeZoneLookup_uddfHoursFromSite_prefersNetworkOverOffline() async throws {
                let tz = try #require(TimeZone(identifier: "America/Cancun"))
                let resolver = FixedGeocodingTimeZoneResolver(timeZone: tz)
                let instant = try #require(DiveDateTimeParsing.parseNaiveWallTimeAsUtcInstant("2021-07-18T14:53:45"))
                let hours = await DiveGeographicTimeZoneLookup.uddfHoursFromSite(
                    latitude: 39.59303,
                    longitude: -104.8778,
                    locationName: nil,
                    at: instant,
                    resolver: resolver
                )
                #expect(hours == Double(tz.secondsFromGMT(for: instant)) / 3600.0)
            }
            @Test @MainActor
            func diveGeographicTimeZoneLookup_offsetSeconds_atInstant() async throws {
                let tz = try #require(TimeZone(identifier: "America/Kralendijk"))
                let resolver = FixedGeocodingTimeZoneResolver(timeZone: tz)
                let coord = DiveGeographicTimeZoneLookup.CoordinateInput(latitude: 12.12201, longitude: -68.29050)
                var comps = DateComponents()
                comps.calendar = Calendar(identifier: .gregorian)
                comps.timeZone = TimeZone(secondsFromGMT: 0)
                comps.year = 2024
                comps.month = 8
                comps.day = 23
                comps.hour = 22
                comps.minute = 22
                comps.second = 27
                let instant = try #require(comps.date)
                let offset = await DiveGeographicTimeZoneLookup.offsetSeconds(
                    for: coord,
                    at: instant,
                    resolver: resolver
                )
                #expect(offset == -4 * 3600)
                var localCal = Calendar(identifier: .gregorian)
                localCal.timeZone = tz
                #expect(localCal.component(.hour, from: instant) == 18)
            }
            @Test @MainActor
            func fitDiveFileImport_persistImportedActivity_createMissingDiveSitesFalse_doesNotCreateSite() async throws {
                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "apple-fit-sites", displayName: "Owner")
                context.insert(owner)
                try context.save()

                let activity = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 1_700_000_000),
                    timeZoneOffsetSeconds: 0, // avoid network timezone resolution in the test
                    durationMinutes: 30,
                    maxDepthMeters: 18,
                    siteName: "Totally Unmatched Reef XYZ"
                )

                let outcome = await FitDiveFileImport.persistImportedActivity(
                    activity,
                    modelContext: context,
                    owner: owner,
                    attachMedia: false,
                    createMissingDiveSites: false
                )

                #expect(outcome.didSucceed)
                // Unmatched import name + createMissingDiveSites false → no new catalog site, dive left unlinked.
                let sites = try context.fetch(FetchDescriptor<DiveSite>())
                #expect(sites.isEmpty)
                #expect(activity.diveSiteID == nil)
                #expect(activity.siteName == "Totally Unmatched Reef XYZ")
            }
            @Test func profileAvatarImageCachePresentation_cacheKey_isStableForSameData() {
                let data = Data([0x01, 0x02, 0x03, 0x04])
                let keyA = ProfileAvatarImageCachePresentation.cacheKey(for: data)
                let keyB = ProfileAvatarImageCachePresentation.cacheKey(for: data)
                #expect(keyA == keyB)
                #expect(keyA != ProfileAvatarImageCachePresentation.cacheKey(for: Data([0x05])))
            }
            @Test func homeRoute_diveBuddy_usesRosterBuddyIDForNavigation() {
                let buddyID = UUID()
                let route = HomeRoute.diveBuddy(buddyID)
                if case .diveBuddy(let resolvedID) = route {
                    #expect(resolvedID == buddyID)
                } else {
                    Issue.record("Expected diveBuddy route case")
                }
            }
            @Test func appTheme_logbookSearchFieldHeight_matchesInlineChromeRow() {
                #expect(AppTheme.Layout.logbookSearchFieldHeight == AppTheme.Layout.glassChromeControlHeight)
                #expect(AppTheme.Layout.glassChromeControlHeight == 44)
            }
            @Test func collapsibleInlineTitleHeaderPresentation_scrollOffsetCollapseLogic() {
                #expect(CollapsibleInlineTitleHeaderPresentation.collapseScrollOffsetThreshold == 8)
                #expect(!CollapsibleInlineTitleHeaderPresentation.isCollapsed(forScrollOffset: 0))
                #expect(!CollapsibleInlineTitleHeaderPresentation.isCollapsed(forScrollOffset: 8))
                #expect(CollapsibleInlineTitleHeaderPresentation.isCollapsed(forScrollOffset: 8.1))
                #expect(CollapsibleInlineTitleHeaderPresentation.chromeBandHeight == 68)
                #expect(CollapsibleInlineTitleHeaderPresentation.listScrollFadeFeatherHeight == 128)
                #expect(CollapsibleInlineTitleHeaderPresentation.sideControlWidth == 44)
                #expect(CollapsibleInlineTitleHeaderPresentation.minimumTitleScaleFactor == 0.5)
                #expect(CollapsibleInlineTitleHeaderPresentation.browseTitleMinimumScaleFactor == 0.45)
                #expect(CollapsibleInlineTitleHeaderPresentation.topObstructionHeight(safeAreaTop: 59) == 127)
                #expect(CollapsibleInlineTitleHeaderPresentation.scrimBandHeight(safeAreaTop: 59) == 255)
                // Page titles (Activity Log, Field Guide, Notifications, …) use **`.title`**, not brand **`.largeTitle`**.
                #expect(CollapsibleInlineTitleHeaderPresentation.expandedTitleTextStyle == .title1)
                #expect(
                    UIFont.preferredFont(forTextStyle: .title1).pointSize
                        < UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
                )
            }
            @Test @MainActor
            func headerChromeIconForeground_alignsWithProfileAvatarRingAndBackButton() {
                // Adaptive `Color` wrappers are distinct instances; compare resolved UIColors.
                let light = UITraitCollection(userInterfaceStyle: .light)
                let dark = UITraitCollection(userInterfaceStyle: .dark)
                #expect(
                    UIColor(AppTheme.Colors.backButtonForeground).resolvedColor(with: light)
                        == UIColor(AppTheme.Colors.headerChromeIconForeground).resolvedColor(with: light)
                )
                #expect(
                    UIColor(AppTheme.Colors.backButtonForeground).resolvedColor(with: dark)
                        == UIColor(AppTheme.Colors.headerChromeIconForeground).resolvedColor(with: dark)
                )
                #expect(AppTheme.Colors.iconPrimary == AppTheme.Colors.accentDeep)
            }
            @Test func defaultTankSize_specifications() {
                #expect(DefaultTankSize.al80.ratedVolumeCubicFeet == 80)
                #expect(DefaultTankSize.al80.materialLabel == "aluminum")
                #expect(DefaultTankSize.al80.settingsPickerTitle == "AL80")
                #expect(DefaultTankSize.al80.settingsPickerMaterialLabel == "Aluminum")
                #expect(DefaultTankSize.al63.ratedVolumeCubicFeet == 63)
                #expect(DefaultTankSize.st100.materialLabel == "steel")
                #expect(DefaultTankSize.st120.ratedVolumeCubicFeet == 120)
                #expect(DefaultTankSize.st120.specification.storedDescription == "120 cu ft (ST120)")
            }
            @Test func diveSite_resolvedWaterType_defaultsToSaltwaterWhenUnset() {
                let site = DiveSite(siteName: "Reef")
                #expect(site.waterType == nil)
                #expect(site.resolvedWaterType == .saltwater)
                site.waterType = .freshwater
                #expect(site.resolvedWaterType == .freshwater)
            }
            @Test func diveBackgroundRenumberingWorker_partialRenumberOnlyTouchesTail() async throws {
                let schema = Schema([
                    DiveActivity.self,
                    DiveBuddy.self,
                    DiveBuddyTag.self,
                    DiveProfilePoint.self,
                    DiveSite.self,
                ])
                let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                let container = try ModelContainer(for: schema, configurations: [configuration])

                let t0 = Date(timeIntervalSince1970: 0)
                let t1 = Date(timeIntervalSince1970: 86_400)
                let t2 = Date(timeIntervalSince1970: 172_800)
                let deletedId = try await MainActor.run { () throws -> UUID in
                    let context = ModelContext(container)
                    let a = DiveActivity(source: .manual, startTime: t0, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 1)
                    let b = DiveActivity(source: .manual, startTime: t1, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 2)
                    let c = DiveActivity(source: .manual, startTime: t2, durationMinutes: 1, maxDepthMeters: 1, diveNumber: 99)
                    context.insert(a)
                    context.insert(b)
                    context.insert(c)
                    try context.save()
                    return b.id
                }

                try await DiveBackgroundRenumberingWorker(modelContainer: container)
                    .renumberDivesNewerThanDeleted(deletedStartTime: t1, deletedId: deletedId)

                let numbers = try await MainActor.run { () throws -> [Int?] in
                    let context = ModelContext(container)
                    let all = try context.fetch(FetchDescriptor<DiveActivity>())
                    let sorted = all.sorted { $0.startTime < $1.startTime }
                    return sorted.map(\.diveNumber)
                }
                #expect(numbers == [1, 2, 2])
            }
            @Test func appStatusBarEdgeScrim_brandHeaderFeatherIsTallerThanListChrome() {
                let brand = AppStatusBarEdgeScrimMetrics.brandHeaderFeatherHeight
                let list = AppStatusBarEdgeScrimMetrics.listChromeFeatherHeight
                #expect(brand == 40)
                #expect(list == 22)
                #expect(brand > list)
                #expect(brand / list > 1.3)
                #expect(AppStatusBarEdgeScrimMetrics.brandHeaderMaxScrimOpacity == 0.60)
            }
            @Test @MainActor
            func navigation_popGestureDelegateAllowsBeginWhenStackHasMoreThanOne() {
                let nav = UINavigationController(rootViewController: UIViewController())
                guard let pop = nav.interactivePopGestureRecognizer else {
                    Issue.record("Expected interactivePopGestureRecognizer on UINavigationController")
                    return
                }
                pop.delegate = nav
                #expect(nav.gestureRecognizerShouldBegin(pop) == false)

                nav.pushViewController(UIViewController(), animated: false)
                #expect(nav.gestureRecognizerShouldBegin(pop) == true)
            }
            @Test @MainActor
            func navigation_popGestureAllowsSimultaneousRecognitionWithScrollPan() {
                let nav = UINavigationController(rootViewController: UIViewController())
                nav.pushViewController(UIViewController(), animated: false)
                guard let pop = nav.interactivePopGestureRecognizer else {
                    Issue.record("Expected interactivePopGestureRecognizer on UINavigationController")
                    return
                }
                pop.delegate = nav
                let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
                let scrollPan = scroll.panGestureRecognizer
                #expect(nav.gestureRecognizer(pop, shouldRecognizeSimultaneouslyWith: scrollPan))
                #expect(nav.gestureRecognizer(scrollPan, shouldRecognizeSimultaneouslyWith: pop))
            }
}
