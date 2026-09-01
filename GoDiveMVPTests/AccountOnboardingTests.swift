//
//  AccountOnboardingTests.swift
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


struct AccountOnboardingTests {
        @Test func userProfileStore_displayNameFromPersonNameComponents() {
            var components = PersonNameComponents()
            components.givenName = "Alex"
            components.familyName = "Diver"
            #expect(UserProfileStore.displayName(from: components) == "Alex Diver")
            #expect(UserProfileStore.displayName(from: nil) == nil)

            var givenOnly = PersonNameComponents()
            givenOnly.givenName = "Jamie"
            #expect(UserProfileStore.displayName(from: givenOnly) == "Jamie")
        }

        @Test func userProfileStore_cachedDisplayName_roundTrips() {
            let appleID = "apple-cache-test-\(UUID().uuidString)"
            defer { UserProfileStore.cacheDisplayName(nil, forAppleUserIdentifier: appleID) }

            #expect(UserProfileStore.cachedDisplayName(forAppleUserIdentifier: appleID) == nil)
            UserProfileStore.cacheDisplayName("Casey", forAppleUserIdentifier: appleID)
            #expect(UserProfileStore.cachedDisplayName(forAppleUserIdentifier: appleID) == "Casey")
            #expect(
                UserProfileStore.resolvedDisplayName(appleProvided: nil, appleUserIdentifier: appleID) == "Casey"
            )
            #expect(
                UserProfileStore.resolvedDisplayName(appleProvided: "Fresh", appleUserIdentifier: appleID) == "Fresh"
            )
        }

        @Test func returningAccountHints_treatAsNewAccount_falseWhenPriorAppleSession() {
            let suite = "returning-hints-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            GoDiveKeychainStore.testingStore = [:]
            defer {
                defaults.removePersistentDomain(forName: suite)
                GoDiveKeychainStore.testingStore = nil
            }
            let appleID = "apple-return-1"
            let profile = UserProfile(appleUserIdentifier: appleID, displayName: "Andre")
            ReturningAccountHints.remember(profile: profile, userDefaults: defaults)

            #expect(ReturningAccountHints.hasPriorSession(forAppleUserIdentifier: appleID, userDefaults: defaults))
            #expect(
                ReturningAccountHints.rememberedDisplayName(forAppleUserIdentifier: appleID, userDefaults: defaults)
                    == "Andre"
            )
            #expect(
                !ReturningAccountHints.treatAsNewAccount(
                    profileDidExistLocally: false,
                    mergedDuplicateCount: 0,
                    ownedDiveCount: 0,
                    appleUserIdentifier: appleID,
                    userDefaults: defaults
                )
            )
            #expect(
                ReturningAccountHints.treatAsNewAccount(
                    profileDidExistLocally: false,
                    mergedDuplicateCount: 0,
                    ownedDiveCount: 0,
                    appleUserIdentifier: "different-apple",
                    userDefaults: defaults
                )
            )
            #expect(
                !ReturningAccountHints.treatAsNewAccount(
                    profileDidExistLocally: true,
                    mergedDuplicateCount: 0,
                    ownedDiveCount: 0,
                    appleUserIdentifier: "brand-new",
                    userDefaults: defaults
                )
            )
        }

        @Test func returningAccountHints_clearAll_removesPriorSession() {
            let suite = "returning-hints-clear-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            GoDiveKeychainStore.testingStore = [:]
            defer {
                defaults.removePersistentDomain(forName: suite)
                GoDiveKeychainStore.testingStore = nil
            }
            let appleID = "apple-clear-1"
            let profile = UserProfile(appleUserIdentifier: appleID, displayName: "Andre")
            ReturningAccountHints.remember(profile: profile, userDefaults: defaults)
            #expect(ReturningAccountHints.hasPriorSession(forAppleUserIdentifier: appleID, userDefaults: defaults))

            ReturningAccountHints.clearAll(userDefaults: defaults)

            #expect(!ReturningAccountHints.hasPriorSession(forAppleUserIdentifier: appleID, userDefaults: defaults))
            #expect(
                ReturningAccountHints.rememberedDisplayName(forAppleUserIdentifier: appleID, userDefaults: defaults) == nil
            )
            #expect(
                ReturningAccountHints.rememberedProfileID(forAppleUserIdentifier: appleID, userDefaults: defaults) == nil
            )
        }

        @Test func accountDeletionPresentation_copyIsDestructive() {
            #expect(AccountDeletionPresentation.buttonTitle == "Delete Account")
            #expect(AccountDeletionPresentation.confirmButtonTitle == "Delete account")
            #expect(AccountDeletionPresentation.confirmationTitle.contains("Delete"))
            #expect(!AccountDeletionPresentation.confirmationMessage.isEmpty)
            #expect(AccountDeletionPresentation.isDeleteAccountEnabled(isConnected: true))
            #expect(!AccountDeletionPresentation.isDeleteAccountEnabled(isConnected: false))
            #expect(!AccountDeletionPresentation.offlineDisabledMessage.isEmpty)
        }

        @Test @MainActor
        func userProfileStore_applyRestoredDisplayNameIfNeeded_upgradesPlaceholderOnly() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let appleID = "apple-restore-\(UUID().uuidString)"
            let profile = try UserProfileStore.findOrCreateProfile(
                appleUserIdentifier: appleID,
                displayName: nil,
                modelContext: context
            )
            #expect(profile.displayName == UserProfileStore.defaultDisplayName)

            #expect(
                try UserProfileStore.applyRestoredDisplayNameIfNeeded(
                    to: profile,
                    restoredName: "Andre",
                    modelContext: context
                )
            )
            #expect(profile.displayName == "Andre")
            #expect(
                !(try UserProfileStore.applyRestoredDisplayNameIfNeeded(
                    to: profile,
                    restoredName: "Someone Else",
                    modelContext: context
                ))
            )
            #expect(profile.displayName == "Andre")
        }

        @Test @MainActor
        func userProfileStore_applyDisplayNameFromApple_writesFreshFullName() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let appleID = "apple-fresh-name-\(UUID().uuidString)"

            let profile = try UserProfileStore.findOrCreateProfile(
                appleUserIdentifier: appleID,
                displayName: nil,
                modelContext: context
            )
            #expect(profile.displayName == UserProfileStore.defaultDisplayName)

            try UserProfileStore.applyDisplayNameFromApple(
                to: profile,
                appleProvided: "Alex Diver",
                appleUserIdentifier: appleID,
                modelContext: context
            )
            #expect(profile.displayName == "Alex Diver")
        }

        @Test @MainActor
        func userProfileStore_applyCachedDisplayNameIfNeeded_upgradesPlaceholder() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let appleID = "apple-cache-upgrade-\(UUID().uuidString)"
            defer { UserProfileStore.cacheDisplayName(nil, forAppleUserIdentifier: appleID) }

            UserProfileStore.cacheDisplayName("Riley", forAppleUserIdentifier: appleID)
            let profile = try UserProfileStore.findOrCreateProfile(
                appleUserIdentifier: appleID,
                displayName: nil,
                modelContext: context
            )
            #expect(profile.displayName == UserProfileStore.defaultDisplayName)

            try UserProfileStore.applyCachedDisplayNameIfNeeded(to: profile, modelContext: context)
            #expect(profile.displayName == "Riley")
        }

        @Test func userProfileStore_sanitizedDanInsuranceNumber_trimsAndFilters() {
            #expect(UserProfileStore.sanitizedDanInsuranceNumber("") == nil)
            #expect(UserProfileStore.sanitizedDanInsuranceNumber("   ") == nil)
            #expect(UserProfileStore.sanitizedDanInsuranceNumber("  US-12345  ") == "US-12345")
            #expect(UserProfileStore.sanitizedDanInsuranceNumber("AB#12!") == "AB12")
        }

        @Test func appNewAccountWelcomePresentation_shouldPresentWelcome_onlyForNewNonUITestAccounts() {
            #expect(AppNewAccountWelcomePresentation.shouldPresentWelcome(forNewAccount: true))
            #expect(!AppNewAccountWelcomePresentation.shouldPresentWelcome(forNewAccount: false))
        }

        @Test func appNewAccountWelcomePresentation_welcomeTitle_usesDisplayNameWhenSet() {
            #expect(
                AppNewAccountWelcomePresentation.welcomeTitle(displayName: "Casey")
                    == "Welcome, Casey"
            )
            #expect(
                AppNewAccountWelcomePresentation.welcomeTitle(displayName: UserProfileStore.defaultDisplayName)
                    == "Welcome to GoDive"
            )
            #expect(
                AppNewAccountWelcomePresentation.welcomeTitle(displayName: nil)
                    == "Welcome to GoDive"
            )
        }

        @Test func appLoggedOutOnboardingPresentation_shouldPresentWhileLoggedOut() {
            #expect(AppLoggedOutOnboardingPresentation.shouldPresentOnboarding(isUITest: false))
            #expect(!AppLoggedOutOnboardingPresentation.shouldPresentOnboarding(isUITest: true))
        }

        @Test func appLoggedOutOnboardingPresentation_featurePages_filterByActivitySelection() {
            let scubaOnly = UserOnboardingActivitySelection(
                doesScubaDiving: true,
                doesFreeDiving: false,
                doesSnorkeling: false
            )
            let snorkelOnly = UserOnboardingActivitySelection(
                doesScubaDiving: false,
                doesFreeDiving: false,
                doesSnorkeling: true
            )
            let all = UserOnboardingActivitySelection(
                doesScubaDiving: true,
                doesFreeDiving: true,
                doesSnorkeling: true
            )

            #expect(
                AppLoggedOutOnboardingPresentation.featurePages(for: scubaOnly).map(\.kind) == [
                    .logEveryDive,
                    .exploreSites,
                    .shareWithFriends,
                    .monitorEquipment,
                    .marineSpecies,
                ]
            )
            #expect(
                AppLoggedOutOnboardingPresentation.featurePages(for: snorkelOnly).map(\.kind) == [
                    .trackSnorkeling,
                    .exploreSites,
                    .shareWithFriends,
                    .monitorEquipment,
                    .marineSpecies,
                ]
            )
            #expect(AppLoggedOutOnboardingPresentation.featurePages(for: all).count == 6)
            #expect(
                AppLoggedOutOnboardingPresentation.showsContinueButton(
                    featurePageIndex: 0,
                    featurePageCount: 3
                )
            )
            #expect(
                !AppLoggedOutOnboardingPresentation.showsContinueButton(
                    featurePageIndex: 2,
                    featurePageCount: 3
                )
            )
            #expect(
                AppLoggedOutOnboardingPresentation.showsSignInWithAppleOnLastFeatureSlide(
                    featurePageIndex: 2,
                    featurePageCount: 3
                )
            )
            #expect(
                !AppLoggedOutOnboardingPresentation.showsSignInWithAppleOnLastFeatureSlide(
                    featurePageIndex: 0,
                    featurePageCount: 3
                )
            )
            #expect(
                AppLoggedOutOnboardingPresentation.showsSkipButton(featurePageIndex: 0, featurePageCount: 3)
            )
            #expect(
                !AppLoggedOutOnboardingPresentation.showsSkipButton(featurePageIndex: 2, featurePageCount: 3)
            )
            #expect(
                !AppLoggedOutOnboardingPresentation.showsSkipButton(featurePageIndex: 0, featurePageCount: 0)
            )
            #expect(
                AppLoggedOutOnboardingPresentation.showsFeatureBackButton(featurePageCount: 3)
            )
            #expect(
                !AppLoggedOutOnboardingPresentation.showsFeatureBackButton(featurePageCount: 0)
            )
            #expect(
                AppLoggedOutOnboardingPresentation.featureBackReturnsToWelcome(featurePageIndex: 0)
            )
            #expect(
                !AppLoggedOutOnboardingPresentation.featureBackReturnsToWelcome(featurePageIndex: 1)
            )
        }

        @Test func loggedOutOnboardingFeatureSlidePresentation_allowsTwoLineTitles() {
            #expect(LoggedOutOnboardingFeatureSlidePresentation.titleLineLimit == 2)
            #expect(LoggedOutOnboardingFeatureSlidePresentation.demoMaxHeight < OnboardingDemoPhoneFrameMetrics.defaultMaxHeight)
            #expect(LoggedOutOnboardingFeatureSlidePresentation.bottomChromeTopPadding == 0)
            #expect(LoggedOutOnboardingFeatureSlidePresentation.bottomChromeStackSpacing == AppTheme.Spacing.sm)
            #expect(LoggedOutOnboardingFeatureSlidePresentation.bottomChromeBottomPadding == 14)
        }

        @Test @MainActor
        func userOnboardingActivitySelection_pendingRoundTrip() {
            let suiteName = "UserOnboardingActivitySelectionTests"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)

            let selection = UserOnboardingActivitySelection(
                doesScubaDiving: true,
                doesFreeDiving: false,
                doesSnorkeling: true
            )
            UserOnboardingActivitySelection.savePending(selection, userDefaults: defaults)
            #expect(UserOnboardingActivitySelection.loadPending(userDefaults: defaults) == selection)
            UserOnboardingActivitySelection.clearPending(userDefaults: defaults)
            #expect(UserOnboardingActivitySelection.loadPending(userDefaults: defaults) == nil)
        }

        @Test func userOnboardingActivitySelection_welcomeDefault_selectsScuba() {
            #expect(UserOnboardingActivitySelection.welcomeDefault.doesScubaDiving)
            #expect(!UserOnboardingActivitySelection.welcomeDefault.doesFreeDiving)
            #expect(!UserOnboardingActivitySelection.welcomeDefault.doesSnorkeling)
            #expect(UserOnboardingActivitySelection.welcomeDefault.hasAnySelection)
        }

        @Test func userOnboardingActivityKind_icons_matchWelcomeScreen() {
            #expect(UserOnboardingActivityKind.welcomePickerKinds == [.scubaDiving, .snorkeling])
            #expect(UserOnboardingActivityKind.scubaDiving.assetImageName == "ScubaTankTab")
            #expect(UserOnboardingActivityKind.scubaDiving.systemImage == nil)
            #expect(UserOnboardingActivityKind.freeDiving.systemImage == "water.waves.and.arrow.down")
            #expect(UserOnboardingActivityKind.snorkeling.systemImage == "figure.water.fitness")
        }

        @Test func onboardingLogEveryDiveDemoFixtures_supportMicroDemo() {
            let rows = OnboardingLogEveryDiveDemoFixtures.logbookRows
            #expect(rows.count == 5)
            #expect(rows.contains { $0.id == OnboardingLogEveryDiveDemoFixtures.focusedDiveID })
            #expect(OnboardingLogEveryDiveDemoFixtures.demoMediaPhotoID.uuidString.isEmpty == false)
            #expect(OnboardingLogEveryDiveDemoFixtures.depthSamples.count >= 2)
            #expect(OnboardingLogEveryDiveDemoFixtures.mapOverviewStatsLayout.leadingStats.count == 2)
            #expect(OnboardingLogEveryDiveDemoFixtures.mapRegion.centerLatitude == OnboardingLogEveryDiveDemoFixtures.diveCoordinate.latitude)
            #expect(OnboardingLogEveryDiveDemoFixtures.mapRegion.centerLongitude == OnboardingLogEveryDiveDemoFixtures.diveCoordinate.longitude)
            #expect(OnboardingLogEveryDiveDemoFixtures.mediaHeroVideoResourceName == "onboarding-log-every-dive-demo")
            #expect(OnboardingLogEveryDiveDemoFixtures.mediaHeroVideoResourceExtension == "mov")
            #expect(OnboardingLogEveryDiveDemoFixtures.taggedMediaSpeciesCommonName == "Red lionfish")
            #expect(OnboardingLogEveryDiveDemoFixtures.taggedMediaSpeciesScientificName == "Pterois volitans")
            #expect(!OnboardingLogEveryDiveDemoFixtures.taggedMediaSpeciesDescription.isEmpty)
            for resourceName in OnboardingLogEveryDiveDemoFixtures.demoMarineLifeSpeciesResourceNames {
                #expect(
                    FieldGuideMarineLifeBundledImagePresentation.bundledPhotoURL(resourceName: resourceName) != nil,
                    "Missing bundled marine life photo: \(resourceName)"
                )
            }
        }

        @Test func onboardingExploreSitesDemoFixtures_supportMicroDemo() {
            let sites = OnboardingExploreSitesDemoFixtures.plottedSites
            #expect(sites.count >= 5)
            #expect(sites.contains { $0.id == OnboardingExploreSitesDemoFixtures.focusedSiteID })
            #expect(sites.first { $0.id == OnboardingExploreSitesDemoFixtures.focusedSiteID }?.siteName == "Blue Hole")
            #expect(OnboardingExploreSitesDemoFixtures.demoRegionSequence.count == 4)
            #expect(
                OnboardingExploreSitesDemoFixtures.focusedSiteRegion.latitudeDelta
                    == DiveLocationMapPresentation.diveSiteLatitudeDelta
            )
            #expect(OnboardingExploreSitesDemoFixtures.worldOverviewRegion.latitudeDelta > 5)
            #expect(OnboardingExploreSitesDemoFixtures.plottedSites.map(\.id).count == Set(sites.map(\.id)).count)
        }

        @Test func onboardingMarineSpeciesDemoFixtures_supportMicroDemo() {
            #expect(OnboardingMarineSpeciesDemoFixtures.hubCategories.count >= 3)
            #expect(
                OnboardingMarineSpeciesDemoFixtures.hubCategories.contains {
                    $0.categoryID == OnboardingMarineSpeciesDemoFixtures.fishesCategoryID
                }
            )
            #expect(OnboardingMarineSpeciesDemoFixtures.fishesSubcategoryRows.count >= 3)
            #expect(OnboardingMarineSpeciesDemoFixtures.frenchAngelfishSnapshot.commonName == "French Angelfish")
            #expect(OnboardingMarineSpeciesDemoFixtures.frenchAngelfishSnapshot.scientificName == "Pomacanthus paru")
            #expect(
                OnboardingMarineSpeciesDemoFixtures.bundledPhotoURL() != nil,
                "Missing bundled French angelfish photo for onboarding demo"
            )
            #expect(OnboardingMarineSpeciesDemoFixtures.heroHeight > 260)
        }

        @Test func onboardingMonitorEquipmentDemoFixtures_supportMicroDemo() {
            #expect(OnboardingMonitorEquipmentDemoFixtures.lockerRows.count >= 3)
            #expect(
                OnboardingMonitorEquipmentDemoFixtures.lockerRows.contains {
                    $0.id == OnboardingMonitorEquipmentDemoFixtures.focusedItemID
                }
            )
            #expect(OnboardingMonitorEquipmentDemoFixtures.garminTitle == "Garmin Mk3i")
            #expect(OnboardingMonitorEquipmentDemoFixtures.garminGearTypeLabel == "Dive Computer")
            #expect(OnboardingMonitorEquipmentDemoFixtures.recurrenceLabel == "Every 1 year")
            #expect(!OnboardingMonitorEquipmentDemoFixtures.serviceNotes.isEmpty)
            #expect(OnboardingMonitorEquipmentDemoFixtures.heroHeight > 280)
            #expect(
                OnboardingMonitorEquipmentDemoFixtures.bundledPhotoURL(
                    resourceName: OnboardingMonitorEquipmentDemoFixtures.garminMk3iPhotoResourceName
                ) != nil
            )
            #expect(OnboardingMonitorEquipmentDemoFixtures.garminMk3iPhotoData != nil)
            #expect(OnboardingMonitorEquipmentDemoFixtures.garminMk3iHeroImage != nil)
        }

        @Test func onboardingShareWithFriendsDemoFixtures_supportMicroDemo() {
            #expect(OnboardingShareWithFriendsDemoFixtures.demoPages.count == 3)
            #expect(OnboardingShareWithFriendsDemoFixtures.statTiles.count == 4)
            #expect(OnboardingShareWithFriendsDemoFixtures.plannedSiteRows.count == 3)
            #expect(OnboardingShareWithFriendsDemoFixtures.taggedBuddies.count == 3)
            #expect(OnboardingShareWithFriendsDemoFixtures.shareCardMembers.count == 4)
            #expect(OnboardingShareWithFriendsDemoFixtures.tripTitle == "Belize 2026")
            let metrics = OnboardingShareWithFriendsDemoLayout.metrics()
            #expect(metrics.heroHeight >= 240)
            #expect(metrics.heroHeight <= 320)
            #expect(metrics.pagerHeight >= 180)
            #expect(metrics.buddyAvatarDiameter >= 48)
            let statsGrid = OnboardingShareWithFriendsDemoLayout.statsGridHeight(
                tileHeight: metrics.statTileHeight,
                spacing: metrics.statGridSpacing,
                tileCount: OnboardingShareWithFriendsDemoFixtures.statTiles.count
            )
            #expect(metrics.pagerHeight >= statsGrid + 8)
            #expect(metrics.shareCardFitSize.width <= metrics.phoneSize.width + 1)
            #expect(metrics.shareCardFitSize.height <= metrics.phoneSize.height + 1)
            #expect(OnboardingShareWithFriendsDemoFixtures.shareCardScaleForPhoneFrame() > 0.5)
            #expect(
                OnboardingShareWithFriendsDemoFixtures.bundledPhotoURL(
                    resourceName: OnboardingShareWithFriendsDemoFixtures.tripHeroPhotoResourceName
                ) != nil
            )
            #expect(OnboardingShareWithFriendsDemoFixtures.tripHeroPhotoData != nil)
            #expect(OnboardingShareWithFriendsDemoFixtures.tripHeroImage != nil)
            for resourceName in OnboardingShareWithFriendsDemoFixtures.demoBuddyPhotoResourceNames {
                #expect(
                    FieldGuideMarineLifeBundledImagePresentation.bundledPhotoURL(resourceName: resourceName) != nil,
                    "Missing bundled buddy demo photo: \(resourceName)"
                )
                #expect(OnboardingShareWithFriendsDemoFixtures.bundledJPEGData(named: resourceName) != nil)
            }
        }

        @Test @MainActor
        func onboardingShareWithFriendsDemoFixtures_rendersShareCardPreviewImage() {
            #expect(OnboardingShareWithFriendsDemoFixtures.renderShareCardPreviewImage() != nil)
        }

        @Test func onboardingDemoPhoneFrameMetrics_matchIPhonePortraitRatio() {
            #expect(OnboardingDemoPhoneFrameMetrics.defaultMaxHeight == 450)
            let size = OnboardingDemoPhoneFrameMetrics.portraitSize(
                maxHeight: OnboardingDemoPhoneFrameMetrics.defaultMaxHeight
            )
            #expect(size.height == 450)
            #expect(abs(size.width / size.height - OnboardingDemoPhoneFrameMetrics.widthOverHeight) < 0.001)
            #expect(size.width < size.height)
            let scale = OnboardingDemoPhoneFrameMetrics.contentScale(for: size)
            #expect(abs(scale - size.width / 393) < 0.001)
            #expect(scale > 0.4)
        }

        @Test func signInCelebrationPresentation_skipsUnderUITest() {
            #expect(!SignInCelebrationPresentation.shouldPresentCelebration(isUITest: true))
            #expect(SignInCelebrationPresentation.shouldPresentCelebration(isUITest: false))
            #expect(SignInCelebrationPresentation.durationNanoseconds == 3_000_000_000)
            #expect(SignInCelebrationPresentation.handoffFadeOutDuration == 0.2)
            #expect(SignInCelebrationPresentation.animationDuration == 3.0)
            #expect(SignInCelebrationPresentation.logoSpringResponse < 0.55)
        }

        @Test func signInCelebrationPresentation_hapticBurst_isSemiRandomAndSkippedUnderUITest() {
            #expect(!SignInCelebrationPresentation.shouldPlayCelebrationHaptics(isUITest: true))
            #expect(SignInCelebrationPresentation.shouldPlayCelebrationHaptics(isUITest: false))
            #expect(
                SignInCelebrationPresentation.hapticMinIntervalSeconds
                    < SignInCelebrationPresentation.hapticMaxIntervalSeconds
            )

            let first = SignInCelebrationPresentation.hapticWaitIntervalSeconds(index: 0)
            let second = SignInCelebrationPresentation.hapticWaitIntervalSeconds(index: 1)
            #expect(first >= SignInCelebrationPresentation.hapticMinIntervalSeconds)
            #expect(first <= SignInCelebrationPresentation.hapticMaxIntervalSeconds)
            #expect(second >= SignInCelebrationPresentation.hapticMinIntervalSeconds)
            #expect(second <= SignInCelebrationPresentation.hapticMaxIntervalSeconds)
            #expect(first != second)
            #expect(SignInCelebrationPresentation.hapticImpactIntensity(index: 0) > 0)
            #expect(
                SignInCelebrationPresentation.hapticImpactIntensity(index: 4)
                    > SignInCelebrationPresentation.hapticImpactIntensity(index: 1)
            )
        }

        @Test func postSignUpProfileSetupPresentation_shouldPresentSetup_onlyForNewNonUITestAccounts() {
            #expect(PostSignUpProfileSetupPresentation.shouldPresentSetup(isNewAccount: true, isUITest: false))
            #expect(!PostSignUpProfileSetupPresentation.shouldPresentSetup(isNewAccount: false, isUITest: false))
            #expect(!PostSignUpProfileSetupPresentation.shouldPresentSetup(isNewAccount: true, isUITest: true))
        }

        @Test @MainActor
        func postSignUpProfileSetupPresentation_steps_includeDiveStepsForScubaOrFreeDive() {
            let scuba = UserProfile(appleUserIdentifier: "a", displayName: "A", doesScubaDiving: true)
            let free = UserProfile(appleUserIdentifier: "b", displayName: "B", doesFreeDiving: true)
            let both = UserProfile(
                appleUserIdentifier: "c",
                displayName: "C",
                doesScubaDiving: true,
                doesFreeDiving: true
            )

            #expect(PostSignUpProfileSetupPresentation.steps(for: scuba) == [
                .profilePhoto, .danInsurance, .certification, .preview,
            ])
            #expect(PostSignUpProfileSetupPresentation.steps(for: free) == [
                .profilePhoto, .danInsurance, .certification, .preview,
            ])
            #expect(PostSignUpProfileSetupPresentation.steps(for: both) == [
                .profilePhoto, .danInsurance, .certification, .preview,
            ])
        }

        @Test @MainActor
        func postSignUpProfileSetupPresentation_steps_skipDiveStepsForSnorkelOnly() {
            let snorkelOnly = UserProfile(
                appleUserIdentifier: "d",
                displayName: "D",
                doesSnorkeling: true
            )
            #expect(PostSignUpProfileSetupPresentation.steps(for: snorkelOnly) == [
                .profilePhoto, .preview,
            ])
        }

        @Test func postSignUpProfileSetupPresentation_selectedInterestKinds_reflectsProfileFlags() {
            let profile = UserProfile(
                appleUserIdentifier: "e",
                displayName: "E",
                doesScubaDiving: true,
                doesSnorkeling: true
            )
            let kinds = PostSignUpProfileSetupPresentation.selectedInterestKinds(for: profile)
            #expect(kinds == [.scubaDiving, .snorkeling])
        }

        @Test func postSignUpProfileSetupPresentation_profilePhotoCopy_welcomesUserByName() {
            #expect(PostSignUpProfileSetupPresentation.stepTitle(.profilePhoto, displayName: "Alex") == "Welcome, Alex")
            #expect(PostSignUpProfileSetupPresentation.stepSubtitle(.profilePhoto) == "Add a profile photo")
            #expect(PostSignUpProfileSetupPresentation.skipTitle(for: .profilePhoto) == "Skip for now")
        }

        @Test func postSignUpProfileSetupPresentation_previewCopy_isWelcomeAndLetsDiveIn() {
            #expect(PostSignUpProfileSetupPresentation.stepTitle(.preview, displayName: "Alex") == "Welcome")
            #expect(PostSignUpProfileSetupPresentation.stepSubtitle(.preview) == "Let's Dive In")
            #expect(PostSignUpProfileSetupPresentation.continueTitle(for: .preview) == "Let's dive in")
            #expect(PostSignUpProfileSetupPresentation.skipTitle(for: .preview) == nil)
        }

        @Test func postSignUpProfileSetupPresentation_skipTitle_onOptionalProfileBuildingSteps() {
            #expect(PostSignUpProfileSetupPresentation.skipTitle(for: .danInsurance) == "Skip for now")
            #expect(PostSignUpProfileSetupPresentation.skipTitle(for: .certification) == "Skip for now")
            #expect(
                !PostSignUpProfileSetupPresentation.shouldPauseBubbleAnimation(for: .profilePhoto)
            )
            #expect(
                !PostSignUpProfileSetupPresentation.shouldPauseBubbleAnimation(for: .danInsurance)
            )
            #expect(
                PostSignUpProfileSetupPresentation.shouldPauseBubbleAnimation(for: .certification)
            )
            #expect(
                PostSignUpProfileSetupPresentation.usesFlatStepLayout(for: .danInsurance)
            )
            #expect(
                !PostSignUpProfileSetupPresentation.usesFlatStepLayout(for: .profilePhoto)
            )
            #expect(
                PostSignUpProfileSetupPresentation.bubblePauseDelayNanoseconds(whenEntering: .danInsurance) == nil
            )
            #expect(
                PostSignUpProfileSetupPresentation.bubblePauseDelayNanoseconds(whenEntering: .certification)
                    == PostSignUpProfileSetupPresentation.stepTransitionNanoseconds + 30_000_000
            )
        }

        @Test func postSignUpProfileSetupPresentation_showsContinueButton_onlyAfterStepInput() {
            #expect(
                !PostSignUpProfileSetupPresentation.showsContinueButton(
                    for: .profilePhoto,
                    hasProfilePhoto: false,
                    danShowsContinue: false,
                    certificationFormCanSave: false
                )
            )
            #expect(
                !PostSignUpProfileSetupPresentation.showsContinueButton(
                    for: .profilePhoto,
                    hasProfilePhoto: true,
                    danShowsContinue: false,
                    certificationFormCanSave: false
                )
            )
            #expect(
                !PostSignUpProfileSetupPresentation.showsContinueButton(
                    for: .danInsurance,
                    hasProfilePhoto: true,
                    danShowsContinue: false,
                    certificationFormCanSave: false
                )
            )
            #expect(
                PostSignUpProfileSetupPresentation.showsContinueButton(
                    for: .danInsurance,
                    hasProfilePhoto: true,
                    danShowsContinue: true,
                    certificationFormCanSave: false
                )
            )
            #expect(
                !PostSignUpProfileSetupPresentation.showsContinueButton(
                    for: .certification,
                    hasProfilePhoto: true,
                    danShowsContinue: false,
                    certificationFormCanSave: false
                )
            )
            #expect(
                PostSignUpProfileSetupPresentation.showsContinueButton(
                    for: .certification,
                    hasProfilePhoto: true,
                    danShowsContinue: false,
                    certificationFormCanSave: true
                )
            )
            #expect(
                PostSignUpProfileSetupPresentation.showsContinueButton(
                    for: .preview,
                    hasProfilePhoto: false,
                    danShowsContinue: false,
                    certificationFormCanSave: false
                )
            )
        }

        @Test @MainActor
        func postSignUpProfileSetupDanDraft_updatesContinueVisibilityOnlyOnBoundary() {
            let draft = PostSignUpProfileSetupDanDraft()
            draft.replaceText("a")
            #expect(draft.showsContinue)
            draft.replaceText("ab")
            #expect(draft.showsContinue)
            draft.replaceText("   ")
            #expect(!draft.showsContinue)
            #expect(draft.text == "   ")
        }

        @Test func postSignUpProfileSetupPresentation_certificationKeyboardChrome_hidesBottomSkipAndContinue() {
            #expect(
                !PostSignUpProfileSetupPresentation.showsSkipInBottomChrome(
                    for: .certification,
                    isCertificationKeyboardVisible: true
                )
            )
            #expect(
                PostSignUpProfileSetupPresentation.showsSkipInBottomChrome(
                    for: .certification,
                    isCertificationKeyboardVisible: false
                )
            )
            #expect(
                !PostSignUpProfileSetupPresentation.showsContinueInBottomChrome(
                    for: .certification,
                    hasProfilePhoto: true,
                    danShowsContinue: false,
                    certificationFormCanSave: true,
                    isCertificationKeyboardVisible: true
                )
            )
            #expect(
                PostSignUpProfileSetupPresentation.showsContinueInBottomChrome(
                    for: .certification,
                    hasProfilePhoto: true,
                    danShowsContinue: false,
                    certificationFormCanSave: true,
                    isCertificationKeyboardVisible: false
                )
            )
            #expect(
                PostSignUpProfileSetupPresentation.showsContinueInCertificationKeyboardToolbar(
                    certificationFormCanSave: true,
                    isCertificationKeyboardVisible: true
                )
            )
            #expect(
                !PostSignUpProfileSetupPresentation.showsContinueInCertificationKeyboardToolbar(
                    certificationFormCanSave: false,
                    isCertificationKeyboardVisible: true
                )
            )
        }

        @Test func postSignUpProfileSetupPresentation_showsBackButton_afterFirstStep() {
            #expect(!PostSignUpProfileSetupPresentation.showsBackButton(stepIndex: 0))
            #expect(PostSignUpProfileSetupPresentation.showsBackButton(stepIndex: 1))
            #expect(PostSignUpProfileSetupPresentation.backButtonAccessibilityIdentifier == "PostSignUpProfileSetup.Back")
        }

        @Test func postSignUpProfileSetupPresentation_certificationExpandedLayout_afterEntryOrFocus() {
            let empty = CertificationFormValues()
            #expect(!PostSignUpProfileSetupPresentation.certificationStepHasStartedEntry(form: empty))
            #expect(
                !PostSignUpProfileSetupPresentation.certificationStepUsesExpandedLayout(
                    form: empty,
                    isTextFieldFocused: false
                )
            )
            #expect(
                PostSignUpProfileSetupPresentation.certificationStepUsesExpandedLayout(
                    form: empty,
                    isTextFieldFocused: true
                )
            )

            var withPhoto = CertificationFormValues()
            withPhoto.certFrontPicture = Data([0x01])
            #expect(PostSignUpProfileSetupPresentation.certificationStepHasStartedEntry(form: withPhoto))
            #expect(
                PostSignUpProfileSetupPresentation.certificationStepUsesExpandedLayout(
                    form: withPhoto,
                    isTextFieldFocused: false
                )
            )

            var withAgency = CertificationFormValues()
            withAgency.agency = "PADI"
            #expect(PostSignUpProfileSetupPresentation.certificationStepHasStartedEntry(form: withAgency))
        }

        @Test func iCloudDiveLogReconnectPresentation_postSignInCopy() {
            #expect(ICloudDiveLogReconnectPresentation.postSignInAlertTitle == "Loading dive log from iCloud")
            #expect(ICloudDiveLogReconnectPresentation.postSignInAlertButtonTitle == "OK")
        }

        @Test func signInPresentation_showsBackButton_onlyWhenOnBackProvided() {
            #expect(SignInPresentation.showsBackButton(hasOnBack: true))
            #expect(!SignInPresentation.showsBackButton(hasOnBack: false))
            #expect(SignInPresentation.backButtonAccessibilityIdentifier == "SignIn.Back")
            #expect(SignInPresentation.loggedOutCrashReportsLinkTitle == "Diagnostic reports")
        }

        @Test func postSignUpInterestsPresentation_shouldPresent_onlyWithoutPendingWelcomeInterests() {
            #expect(
                PostSignUpInterestsPresentation.shouldPresent(
                    hadPendingWelcomeInterests: false,
                    isUITest: false
                )
            )
            #expect(
                !PostSignUpInterestsPresentation.shouldPresent(
                    hadPendingWelcomeInterests: true,
                    isUITest: false
                )
            )
            #expect(
                !PostSignUpInterestsPresentation.shouldPresent(
                    hadPendingWelcomeInterests: false,
                    isUITest: true
                )
            )
            #expect(PostSignUpInterestsPresentation.title == "What do you do in the water?")
            #expect(PostSignUpInterestsPresentation.continueTitle == "Continue")
            #expect(PostSignUpInterestsPresentation.rootAccessibilityIdentifier == "PostSignUpInterests.Root")
        }

        @Test func accountSessionMainShellPresentation_requiresSignedInPastPostSignUpGates() {
            #expect(
                !AccountSessionMainShellPresentation.showsMainAppShell(
                    isSignedIn: false,
                    showsNewAccountWelcome: false,
                    showsPostSignUpInterests: false,
                    showsPostSignUpProfileSetup: false,
                    showsPostSignUpPermissions: false,
                    showsPostSignUpImportOffer: false,
                    showsPostSignUpOnboardingImport: false,
                    showsSignInCelebration: false
                )
            )
            #expect(
                AccountSessionMainShellPresentation.showsMainAppShell(
                    isSignedIn: true,
                    showsNewAccountWelcome: false,
                    showsPostSignUpInterests: false,
                    showsPostSignUpProfileSetup: false,
                    showsPostSignUpPermissions: false,
                    showsPostSignUpImportOffer: false,
                    showsPostSignUpOnboardingImport: false,
                    showsSignInCelebration: false
                )
            )
            #expect(
                !AccountSessionMainShellPresentation.showsMainAppShell(
                    isSignedIn: true,
                    showsNewAccountWelcome: false,
                    showsPostSignUpInterests: true,
                    showsPostSignUpProfileSetup: false,
                    showsPostSignUpPermissions: false,
                    showsPostSignUpImportOffer: false,
                    showsPostSignUpOnboardingImport: false,
                    showsSignInCelebration: false
                )
            )
            #expect(
                !AccountSessionMainShellPresentation.showsMainAppShell(
                    isSignedIn: true,
                    showsNewAccountWelcome: false,
                    showsPostSignUpInterests: false,
                    showsPostSignUpProfileSetup: true,
                    showsPostSignUpPermissions: false,
                    showsPostSignUpImportOffer: false,
                    showsPostSignUpOnboardingImport: false,
                    showsSignInCelebration: false
                )
            )
            #expect(
                !AccountSessionMainShellPresentation.shouldMountMainAppShellUnderlay(
                    isRestoringSession: false,
                    isPopulatingRemoteAccountData: false,
                    isSignedIn: true,
                    showsNewAccountWelcome: false,
                    showsPostSignUpInterests: false,
                    showsPostSignUpProfileSetup: false,
                    showsPostSignUpPermissions: false,
                    showsPostSignUpImportOffer: false,
                    showsPostSignUpOnboardingImport: false,
                    showsSignInCelebration: true,
                    allowsCelebrationShellPrewarm: false
                )
            )
            #expect(
                AccountSessionMainShellPresentation.shouldMountMainAppShellUnderlay(
                    isRestoringSession: false,
                    isPopulatingRemoteAccountData: false,
                    isSignedIn: true,
                    showsNewAccountWelcome: false,
                    showsPostSignUpInterests: false,
                    showsPostSignUpProfileSetup: false,
                    showsPostSignUpPermissions: false,
                    showsPostSignUpImportOffer: false,
                    showsPostSignUpOnboardingImport: false,
                    showsSignInCelebration: true,
                    allowsCelebrationShellPrewarm: true
                )
            )
            #expect(
                !AccountSessionMainShellPresentation.shouldMountMainAppShellUnderlay(
                    isRestoringSession: false,
                    isPopulatingRemoteAccountData: true,
                    isSignedIn: true,
                    showsNewAccountWelcome: false,
                    showsPostSignUpInterests: false,
                    showsPostSignUpProfileSetup: false,
                    showsPostSignUpPermissions: false,
                    showsPostSignUpImportOffer: false,
                    showsPostSignUpOnboardingImport: false,
                    showsSignInCelebration: false,
                    allowsCelebrationShellPrewarm: false
                )
            )
            #expect(
                !AccountSessionMainShellPresentation.shouldMountMainAppShellUnderlay(
                    isRestoringSession: true,
                    isPopulatingRemoteAccountData: false,
                    isSignedIn: true,
                    showsNewAccountWelcome: false,
                    showsPostSignUpInterests: false,
                    showsPostSignUpProfileSetup: false,
                    showsPostSignUpPermissions: false,
                    showsPostSignUpImportOffer: false,
                    showsPostSignUpOnboardingImport: false,
                    showsSignInCelebration: false,
                    allowsCelebrationShellPrewarm: false
                )
            )
        }

        @Test @MainActor
        func accountSession_completePostSignUpProfileSetup_isNoOpWhenNotShowingSetup() {
            let session = AccountSession.shared
            session.signOut()
            session.completePostSignUpProfileSetup()
            #expect(!session.showsSignInCelebration)
            #expect(!session.showsPostSignUpImportOffer)
        }

        @Test @MainActor
        func accountSession_completePostSignUpInterests_isNoOpWhenNotShowingInterests() throws {
            let session = AccountSession.shared
            session.signOut()
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            try session.completePostSignUpInterests(
                selection: .welcomeDefault,
                modelContext: context
            )
            #expect(!session.showsPostSignUpProfileSetup)
            #expect(!session.showsPostSignUpInterests)
        }

        @Test @MainActor
        func postSignUpImportOfferPresentation_shouldPresent_forScubaOrFreeDiveOnly() {
            let scuba = UserProfile(appleUserIdentifier: "import-a", displayName: "A", doesScubaDiving: true)
            let snorkel = UserProfile(appleUserIdentifier: "import-b", displayName: "B", doesSnorkeling: true)
            #expect(PostSignUpImportOfferPresentation.shouldPresentImportOffer(for: scuba, isUITest: false))
            #expect(!PostSignUpImportOfferPresentation.shouldPresentImportOffer(for: snorkel, isUITest: false))
            #expect(!PostSignUpImportOfferPresentation.shouldPresentImportOffer(for: scuba, isUITest: true))
        }

        @Test func postSignUpPermissionsPresentation_shouldPresent_skipsUITest() {
            #expect(PostSignUpPermissionsPresentation.shouldPresent(isUITest: false))
            #expect(!PostSignUpPermissionsPresentation.shouldPresent(isUITest: true))
        }

        @Test func postSignUpPermissionsPresentation_copy_reusesOnboardingPermissionStrings() {
            #expect(PostSignUpPermissionsPresentation.contactsTitle == "Contacts")
            #expect(PostSignUpPermissionsPresentation.photosTitle == "Photos")
            #expect(!PostSignUpPermissionsPresentation.subtitle.isEmpty)
            #expect(PostSignUpPermissionsPresentation.continueButtonTitle == "Continue")
        }

        @Test @MainActor
        func accountSession_completePostSignUpPermissions_isNoOpWhenNotShowingPermissions() {
            let session = AccountSession.shared
            session.signOut()
            session.completePostSignUpPermissions()
            #expect(!session.showsPostSignUpImportOffer)
            #expect(!session.showsSignInCelebration)
        }

        @Test func postSignUpImportOfferPresentation_copy_mentionsMacDiveAndSkip() {
            #expect(PostSignUpImportOfferPresentation.title == "Bring your old dives")
            #expect(PostSignUpImportOfferPresentation.importButtonTitle == "Import dives")
            #expect(PostSignUpImportOfferPresentation.skipButtonTitle == "Skip for now")
            #expect(PostSignUpImportOfferPresentation.macDiveHintBody.contains("MacDive"))
        }

        @Test @MainActor
        func accountSession_completePostSignUpOnboardingImport_isNoOpWhenNotShowingImport() {
            let session = AccountSession.shared
            session.signOut()
            session.completePostSignUpOnboardingImport()
            #expect(!session.showsSignInCelebration)
        }

        @Test func postSignUpOnboardingImportPresentation_skipTitle_matchesImportOffer() {
            #expect(PostSignUpOnboardingImportPresentation.skipButtonTitle == "Skip")
            #expect(
                PostSignUpOnboardingImportPresentation.optionsAccessibilityIdentifier
                    == "PostSignUpOnboardingImport.Options"
            )
        }

        @Test @MainActor
        func accountSession_completePostSignUpImportOffer_isNoOpWhenNotShowingOffer() {
            let session = AccountSession.shared
            session.signOut()
            session.completePostSignUpImportOffer(choseImport: true)
            #expect(!session.showsPostSignUpOnboardingImport)
            session.completePostSignUpImportOffer(choseImport: false)
            #expect(!session.showsPostSignUpImportOffer)
        }

        @Test @MainActor
        func accountSession_completeNewAccountWelcome_isNoOpWhenNotShowingWelcome() {
            let session = AccountSession.shared
            session.signOut()
            #expect(!session.showsNewAccountWelcome)
            session.completeNewAccountWelcome()
            #expect(!session.showsNewAccountWelcome)
        }

        @Test @MainActor
        func userProfileStore_findOrCreateProfile_reusesAppleUser() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let first = try UserProfileStore.findOrCreateProfile(
                appleUserIdentifier: "apple-user-1",
                displayName: "Casey",
                modelContext: context
            )
            let second = try UserProfileStore.findOrCreateProfile(
                appleUserIdentifier: "apple-user-1",
                displayName: "Ignored",
                modelContext: context
            )

            #expect(first.id == second.id)
            #expect(second.displayName == "Casey")
            #expect(try context.fetchCount(FetchDescriptor<UserProfile>()) == 1)
        }

        @Test func goDiveFirestoreProfilePhotoRestore_needsLocalRestore_whenEmptyOrMissing() {
            let withPhoto = UserProfile(appleUserIdentifier: "a", displayName: "A")
            withPhoto.profilePhoto = Data([0xFF, 0xD8])
            #expect(!GoDiveFirestoreProfilePhotoRestore.needsLocalRestore(withPhoto))

            let empty = UserProfile(appleUserIdentifier: "b", displayName: "B")
            empty.profilePhoto = Data()
            #expect(GoDiveFirestoreProfilePhotoRestore.needsLocalRestore(empty))

            let missing = UserProfile(appleUserIdentifier: "c", displayName: "C")
            #expect(GoDiveFirestoreProfilePhotoRestore.needsLocalRestore(missing))
        }

        @Test @MainActor
        func userProfileStore_findOrCreateProfile_upgradesDefaultDisplayName() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let first = try UserProfileStore.findOrCreateProfile(
                appleUserIdentifier: "apple-user-2",
                displayName: nil,
                modelContext: context
            )
            #expect(first.displayName == UserProfileStore.defaultDisplayName)

            let second = try UserProfileStore.findOrCreateProfile(
                appleUserIdentifier: "apple-user-2",
                displayName: "Casey",
                modelContext: context
            )

            #expect(first.id == second.id)
            #expect(second.displayName == "Casey")
        }

        @Test func accountSession_signInFailureUserMessage_isGeneric() {
            #expect(AccountSession.signInFailureUserMessage.contains("could not be completed"))
            #expect(!AccountSession.signInFailureUserMessage.lowercased().contains("password"))
            #expect(!AccountSession.signInFailureUserMessage.lowercased().contains("username"))
        }

        @Test func accountSessionProfileResolution_launchImportTimeoutIsBoundedForSplash() {
            #expect(AccountSessionProfileResolution.launchImportTimeoutSeconds > 0)
            #expect(
                AccountSessionProfileResolution.launchImportTimeoutSeconds
                    < AccountSessionProfileResolution.defaultImportTimeoutSeconds
            )
        }

        @Test @MainActor func accountSessionProfileResolution_totalOwnedActivityCount_sumsAcrossProfiles() throws {
            let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
            let context = ModelContext(dual.container)

            let older = UserProfile(appleUserIdentifier: "ck-total", displayName: "Cloud")
            older.createdAt = Date(timeIntervalSince1970: 1_000)
            context.insert(older)
            let newer = UserProfile(appleUserIdentifier: "ck-total", displayName: "Local")
            newer.createdAt = Date(timeIntervalSince1970: 2_000)
            context.insert(newer)

            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 30, maxDepthMeters: 12)
            dive.owner = older
            dive.ownerProfileID = older.id
            context.insert(dive)
            try context.save()

            #expect(
                AccountSessionProfileResolution.totalOwnedActivityCount(
                    appleUserIdentifier: "ck-total",
                    modelContext: context
                ) == 1
            )
        }

        @Test func accountSessionLaunchRestorePresentation_skipsCloudKitWaitWhenLocalProfileExists() {
            #expect(
                !AccountSessionLaunchRestorePresentation.waitForCloudKitImportOnColdRestore(
                    localPreferredProfileExists: true
                )
            )
            #expect(
                AccountSessionLaunchRestorePresentation.waitForCloudKitImportOnColdRestore(
                    localPreferredProfileExists: false
                )
            )
        }

        @Test func accountSessionLaunchRestorePresentation_waitPolicyUsesOwnedAndStoreCounts() {
            #expect(
                !AccountSessionLaunchRestorePresentation.waitForCloudKitImportOnColdRestore(
                    localOwnedActivityCount: 3,
                    localPreferredProfileExists: true,
                    storeActivityCount: 3
                )
            )
            #expect(
                !AccountSessionLaunchRestorePresentation.waitForCloudKitImportOnColdRestore(
                    localOwnedActivityCount: 0,
                    localPreferredProfileExists: true,
                    storeActivityCount: 5
                )
            )
            #expect(
                !AccountSessionLaunchRestorePresentation.waitForCloudKitImportOnColdRestore(
                    localOwnedActivityCount: 0,
                    localPreferredProfileExists: true,
                    storeActivityCount: 0
                )
            )
            #expect(
                AccountSessionLaunchRestorePresentation.waitForCloudKitImportOnColdRestore(
                    localOwnedActivityCount: 0,
                    localPreferredProfileExists: false,
                    storeActivityCount: 0
                )
            )
        }

        @Test @MainActor
        func accountSessionProfileResolution_prefersOwningTwinWithoutCloudKitWait() async throws {
            let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
            let context = ModelContext(dual.container)

            let emptyPreferred = UserProfile(appleUserIdentifier: "ck-twin-home", displayName: "Preferred")
            emptyPreferred.createdAt = Date(timeIntervalSince1970: 2_000)
            context.insert(emptyPreferred)

            let owningTwin = UserProfile(appleUserIdentifier: "ck-twin-home", displayName: "Owner")
            owningTwin.createdAt = Date(timeIntervalSince1970: 1_000)
            context.insert(owningTwin)

            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 40, maxDepthMeters: 18)
            dive.owner = owningTwin
            dive.ownerProfileID = owningTwin.id
            context.insert(dive)
            try context.save()

            let resolved = await AccountSessionProfileResolution.resolve(
                preferredProfileID: emptyPreferred.id,
                appleUserIdentifier: "ck-twin-home",
                modelContext: context,
                waitForCloudKitImport: false
            )
            #expect(resolved?.id == owningTwin.id)
            #expect(resolved?.id != emptyPreferred.id)
        }

        @Test @MainActor
        func accountSessionLocalOwnershipHealing_claimsNilAndMissingOwnerUUIDs() throws {
            let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
            let context = ModelContext(dual.container)
            let owner = UserProfile(appleUserIdentifier: "heal-owner", displayName: "Healer")
            context.insert(owner)

            let nilOwned = DiveActivity(source: .manual, startTime: .now, durationMinutes: 20, maxDepthMeters: 10)
            nilOwned.ownerProfileID = nil
            context.insert(nilOwned)

            let missingOwnerID = UUID()
            let zombieOwned = DiveActivity(
                source: .manual,
                startTime: .now.addingTimeInterval(-3_600),
                durationMinutes: 30,
                maxDepthMeters: 14
            )
            zombieOwned.ownerProfileID = missingOwnerID
            context.insert(zombieOwned)
            try context.save()

            let healed = try AccountSessionLocalOwnershipHealing.healIfNeeded(
                for: owner,
                modelContext: context
            )
            #expect(healed >= 2)
            #expect(nilOwned.ownerProfileID == owner.id)
            #expect(zombieOwned.ownerProfileID == owner.id)
            #expect(
                AccountSessionProfileResolution.totalOwnedActivityCount(
                    appleUserIdentifier: "heal-owner",
                    modelContext: context
                ) == 2
            )
        }

        @Test @MainActor
        func accountSessionLocalOwnershipHealing_doesNotStealFromLiveOtherProfile() throws {
            let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
            let context = ModelContext(dual.container)
            let sessionOwner = UserProfile(appleUserIdentifier: "heal-a", displayName: "A")
            let other = UserProfile(appleUserIdentifier: "heal-b", displayName: "B")
            context.insert(sessionOwner)
            context.insert(other)

            let otherDive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 25, maxDepthMeters: 12)
            otherDive.owner = other
            otherDive.ownerProfileID = other.id
            context.insert(otherDive)
            try context.save()

            let healed = try AccountSessionLocalOwnershipHealing.healIfNeeded(
                for: sessionOwner,
                modelContext: context
            )
            #expect(healed == 0)
            #expect(otherDive.ownerProfileID == other.id)
        }

        @Test @MainActor
        func accountSessionLocalOwnershipHealing_adoptsStrandedTwinOwnedDives() throws {
            let dual = try AppSwiftDataDualStoreFactory.makeInMemorySplitContainer()
            let context = ModelContext(dual.container)
            let sessionOwner = UserProfile(appleUserIdentifier: "stranded-apple", displayName: "Session")
            let blankTwin = UserProfile(appleUserIdentifier: "", displayName: "Diver")
            context.insert(sessionOwner)
            context.insert(blankTwin)

            let stranded = DiveActivity(source: .manual, startTime: .now, durationMinutes: 35, maxDepthMeters: 16)
            stranded.owner = blankTwin
            stranded.ownerProfileID = blankTwin.id
            context.insert(stranded)
            try context.save()

            let healed = try AccountSessionLocalOwnershipHealing.healIfNeeded(
                for: sessionOwner,
                modelContext: context
            )
            #expect(healed >= 1)
            #expect(stranded.ownerProfileID == sessionOwner.id)
        }

            @Test func firestoreUserProfileMapping_trimsAndBuildsPublicFields() {
                let draft = GoDiveFirestoreUserProfileMapping.publicDraft(
                    displayName: "  Alex Diver  ",
                    handle: "  ",
                    photoURL: "  ",
                    interests: [" Scuba Diving ", "Scuba Diving", "  "],
                    discoverable: true
                )
                #expect(draft.displayName == "Alex Diver")
                #expect(draft.handle == "")
                #expect(draft.photoURL == "")
                #expect(draft.interests == ["Scuba Diving"])
                #expect(draft.discoverable == true)
                #expect(draft.schemaVersion == GoDiveFirestoreUserProfileMapping.schemaVersion)

                let fields = GoDiveFirestoreUserProfileMapping.publicFields(from: draft)
                #expect(fields["displayName"] as? String == "Alex Diver")
                #expect(fields["handle"] as? String == "")
                #expect(fields["photoURL"] as? String == "")
                #expect(fields["interests"] as? [String] == ["Scuba Diving"])
                #expect(fields["discoverable"] as? Bool == true)
                #expect(fields["schemaVersion"] as? Int == GoDiveFirestoreUserProfileMapping.schemaVersion)
                #expect(fields["createdAt"] == nil)
                #expect(fields["updatedAt"] == nil)

                let withoutPhoto = GoDiveFirestoreUserProfileMapping.publicFields(from: draft, includePhotoURL: false)
                #expect(withoutPhoto["photoURL"] == nil)
                #expect(withoutPhoto["interests"] as? [String] == ["Scuba Diving"])

                let uploaded = GoDiveFirestoreUserProfileMapping.photoURLMerge(
                    uploadedPhotoURL: "https://example.com/p.jpg",
                    photoUploadFailed: false,
                    preserveExistingPhotoURLIfNoUpload: false
                )
                #expect(uploaded.includePhotoURL)
                #expect(uploaded.photoURLValue == "https://example.com/p.jpg")
                let failed = GoDiveFirestoreUserProfileMapping.photoURLMerge(
                    uploadedPhotoURL: nil,
                    photoUploadFailed: true,
                    preserveExistingPhotoURLIfNoUpload: false
                )
                #expect(!failed.includePhotoURL)
                let skipPhoto = GoDiveFirestoreUserProfileMapping.photoURLMerge(
                    uploadedPhotoURL: nil,
                    photoUploadFailed: false,
                    preserveExistingPhotoURLIfNoUpload: false
                )
                #expect(skipPhoto.includePhotoURL)
                #expect(skipPhoto.photoURLValue == "")
            }
            @Test func firestoreUserProfileMapping_interestsFromActivityFlags() {
                #expect(
                    GoDiveFirestoreUserProfileMapping.interests(
                        doesScubaDiving: true,
                        doesFreeDiving: false,
                        doesSnorkeling: true
                    ) == ["Scuba Diving", "Snorkeling"]
                )
                #expect(
                    GoDiveFirestoreUserProfileMapping.interests(
                        doesScubaDiving: false,
                        doesFreeDiving: true,
                        doesSnorkeling: false
                    ) == ["Free Diving"]
                )
                #expect(GoDiveFirebaseProfilePhotoStorage.objectPath(uid: "abc") == "users/abc/profile.jpg")
                #expect(!GoDiveFirestoreProfilePublishGate.isDeferredUntilPhotoStep(userDefaults: UserDefaults(suiteName: "gate-test-\(UUID().uuidString)")!))
            }
            @Test func firestoreUserProfileMapping_buildsPrivateAppleLinkFields() {
                let draft = GoDiveFirestoreUserProfileMapping.privateDraft(appleUserIdentifier: "  apple.id.123  ")
                #expect(draft.appleUserIdentifier == "apple.id.123")
                let fields = GoDiveFirestoreUserProfileMapping.privateFields(from: draft)
                #expect(fields["appleUserIdentifier"] as? String == "apple.id.123")
                #expect(GoDiveFirestoreUserProfileMapping.privateAccountDocumentID == "account")
            }
            @Test func firebaseAppleNonce_sha256IsDeterministicHex() {
                let nonce = "GoDive-test-nonce-0123456789"
                let hash = GoDiveFirebaseAppleNonce.sha256Nonce(nonce)
                #expect(hash.count == 64)
                #expect(hash == GoDiveFirebaseAppleNonce.sha256Nonce(nonce))
                #expect(hash == hash.lowercased())
                #expect(GoDiveFirebaseAppleNonce.sha256Nonce(nonce + "x") != hash)

                let random = GoDiveFirebaseAppleNonce.randomNonce(length: 32)
                #expect(random.count == 32)
                let allowed = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
                #expect(random.unicodeScalars.allSatisfy { allowed.contains($0) })
            }
            @Test func goDiveFirestoreUserProfileMapping_firebaseUID_keychainRoundTrip() {
                let suite = "firebase-uid-\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suite)!
                GoDiveKeychainStore.testingStore = [:]
                defer {
                    defaults.removePersistentDomain(forName: suite)
                    GoDiveKeychainStore.testingStore = nil
                }
                defaults.set("legacy-uid", forKey: GoDiveFirestoreUserProfileMapping.firebaseUIDDefaultsKey)
                #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID(userDefaults: defaults) == "legacy-uid")
                #expect(defaults.string(forKey: GoDiveFirestoreUserProfileMapping.firebaseUIDDefaultsKey) == nil)
                GoDiveFirestoreUserProfileMapping.clearCachedFirebaseUID(userDefaults: defaults)
                #expect(GoDiveFirestoreUserProfileMapping.loadCachedFirebaseUID(userDefaults: defaults) == nil)
            }
}
