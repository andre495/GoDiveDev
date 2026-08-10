//
//  ProfilePresentationTests.swift
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


struct ProfilePresentationTests {
        @Test func profilePresentation_taggedMediaIDsFingerprint_isStableForSameIDs() {
            let a = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            let b = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
            #expect(
                ProfilePresentation.taggedMediaIDsFingerprint([a, b])
                    == "\(a.uuidString),\(b.uuidString)"
            )
            #expect(ProfilePresentation.taggedMediaIDsFingerprint([]) == "")
        }

        @Test func profilePresentation_danInsuranceLabel_formatsMemberNumber() {
            #expect(ProfilePresentation.danInsuranceLabel("1234567") == "DAN 1234567")
        }

        @Test func profilePresentation_editSheetAccessibilityIdentifiers() {
            #expect(ProfilePresentation.editSheetCancelAccessibilityIdentifier == "ProfileEditSheet.Cancel")
            #expect(ProfilePresentation.editSheetDoneAccessibilityIdentifier == "ProfileEditSheet.Done")
        }

        @Test func profilePresentation_signOutConfirmation_copyIsNonEmpty() {
            #expect(!ProfilePresentation.signOutConfirmationTitle.isEmpty)
            #expect(ProfilePresentation.signOutConfirmationMessage.contains("Are you sure"))
            #expect(ProfilePresentation.signOutConfirmButtonTitle == "Sign out")
            #expect(ProfilePresentation.signOutCancelButtonTitle == "Cancel")
        }

        @Test func profilePresentation_diveActivityCountLabel_pluralizes() {
            #expect(ProfilePresentation.diveActivityCountLabel(0) == "No dives logged")
            #expect(ProfilePresentation.diveActivityCountLabel(1) == "1 dive")
            #expect(ProfilePresentation.diveActivityCountLabel(12) == "12 dives")
        }

        @Test func profilePresentation_profileActivityAccentLabel_formatsDivesAndSnorkels() {
            #expect(ProfilePresentation.profileActivityAccentLabel(diveCount: 0, snorkelCount: 0) == nil)
            #expect(ProfilePresentation.profileActivityAccentLabel(diveCount: 3, snorkelCount: 0) == "3 Dives")
            #expect(ProfilePresentation.profileActivityAccentLabel(diveCount: 0, snorkelCount: 2) == "2 Snorkels")
            #expect(ProfilePresentation.profileActivityAccentLabel(diveCount: 1, snorkelCount: 1) == "1 Dive | 1 Snorkel")
            #expect(ProfilePresentation.profileActivityAccentLabel(diveCount: 5, snorkelCount: 3) == "5 Dives | 3 Snorkels")
            #expect(ProfilePresentation.profileActivityAccentLabel(diveCount: 1, snorkelCount: 0) == "1 Dive")
            #expect(ProfilePresentation.profileActivityAccentLabel(diveCount: 0, snorkelCount: 1) == "1 Snorkel")
        }

        @Test func profilePresentation_certificationAndEquipmentCountLabels_pluralize() {
            #expect(ProfilePresentation.certificationCountLabel(0) == "No certifications")
            #expect(ProfilePresentation.certificationCountLabel(1) == "1 certification")
            #expect(ProfilePresentation.certificationCountLabel(3) == "3 certifications")
            #expect(ProfilePresentation.equipmentItemCountLabel(0) == "No gear")
            #expect(ProfilePresentation.equipmentItemCountLabel(1) == "1 item")
            #expect(ProfilePresentation.equipmentItemCountLabel(5) == "5 items")
            #expect(ProfilePresentation.tripCountLabel(0) == "No trips")
            #expect(ProfilePresentation.tripCountLabel(1) == "1 trip")
            #expect(ProfilePresentation.tripCountLabel(4) == "4 trips")
        }

        @Test func profilePresentation_sideMenuTitles_arePageTitlesOnly() {
            #expect(ProfilePresentation.editProfileAccessibilityLabel == "Edit Profile")
            #expect(ProfilePresentation.editProfileAccessibilityIdentifier == "Profile.EditButton")
            #expect(ProfilePresentation.menuSettingsTitle == "Settings")
            #expect(ProfilePresentation.menuCertificationsTitle == "Certifications")
            #expect(ProfilePresentation.menuEquipmentTitle == "Equipment Locker")
            #expect(ProfilePresentation.menuBuddiesTitle == "Buddies")
            #expect(ProfilePresentation.menuTripsTitle == "Trips")
            #expect(ProfilePresentation.menuSignOutTitle == "Sign out")
            #expect(ProfilePresentation.menuInviteBuddyTitle == "Invite a buddy")
            #expect(ProfilePresentation.menuInviteBuddySystemImage == "qrcode")
            #expect(ProfilePresentation.menuInviteBuddyAccessibilityIdentifier == "Profile.InviteBuddy")
            #expect(ProfilePresentation.menuIconPointSize == 28)
            #expect(ProfilePresentation.sideMenuWidthFraction == CGFloat(2.0 / 3.0))
            #expect(ProfilePresentation.sideMenuItemTitles == [
                "Trips",
                "Certifications",
                "Equipment Locker",
                "Buddies",
                "Settings",
            ])
            #expect(!ProfilePresentation.sideMenuItemTitles.contains("Edit Profile"))
            #expect(!ProfilePresentation.sideMenuItemTitles.contains("My tagged media"))
            #expect(!ProfilePresentation.sideMenuItemTitles.contains("Sign out"))
            #expect(!ProfilePresentation.sideMenuItemTitles.contains("Invite a buddy"))
        }

        @Test @MainActor func profileDetailContentPagerPresentation_diverStatsAndTaggedMediaPages() {
            #expect(ProfileDetailContentPagerPresentation.pageCount == 2)
            #expect(
                ProfileDetailContentPagerPresentation.pages == [
                    .diverStats,
                    .taggedMedia,
                ]
            )
            #expect(ProfileDetailContentPagerPresentation.defaultPage == .diverStats)
            #expect(ProfileDetailContentPagerPresentation.showsBuddyLeaderboardOnDiverStats == false)
            #expect(ProfileDetailContentPagerPresentation.showsLifetimeSummaryOnDiverStats == false)
            #expect(ProfileDetailContentPagerPresentation.pageTitle(for: .diverStats) == "Diver stats")
            #expect(
                ProfileDetailContentPagerPresentation.pageTitle(for: .taggedMedia)
                    == DiveBuddyTaggedMediaPresentation.sectionTitle
            )
            #expect(!ProfileDetailContentPagerPresentation.usesStaticPagerLayout(for: .diverStats))
            #expect(!ProfileDetailContentPagerPresentation.usesStaticPagerLayout(for: .taggedMedia))
            #expect(ProfileDetailContentPagerPresentation.formattedDanMemberNumberForDisplay("1234567") == "#1234567")
            #expect(ProfileDetailContentPagerPresentation.formattedDanMemberNumberForDisplay("#999") == "#999")
            #expect(ProfileDetailContentPagerPresentation.formattedDanMemberNumberForDisplay(nil) == "#")
            #expect(ProfileDetailContentPagerPresentation.formattedDanMemberNumberForDisplay("  ") == "#")
            #expect(ProfileDetailContentPagerPresentation.usesBlueSheetDetailHorizontalPaddingOnly)
            #expect(
                BlueSheetDetailPagePinnedSummaryPresentation.horizontalPadding == AppTheme.Spacing.lg
            )
            #expect(ProfileDetailContentPagerPresentation.danWebsiteURL.absoluteString == "https://dan.org/")
            #expect(
                ProfileDetailContentPagerPresentation.accessibilityIdentifier(for: .diverStats)
                    == "Profile.ContentPager.DiverStats"
            )
            #expect(
                ProfileDetailContentPagerPresentation.accessibilityIdentifier(for: .taggedMedia)
                    == "Profile.ContentPager.TaggedMedia"
            )
            #expect(ProfileDetailContentPagerPresentation.showsPinnedPageHeaders == false)
            #expect(
                ProfileDetailContentPagerPresentation.emptyStateMessage(for: .taggedMedia)
                    .contains("tagged with you")
            )
        }

        @Test func profileTaggedMediaPresentation_mediaCountLabel() {
            #expect(ProfileTaggedMediaPresentation.mediaCountLabel(0) == "No tagged media")
            #expect(ProfileTaggedMediaPresentation.mediaCountLabel(1) == "1 photo or video")
            #expect(ProfileTaggedMediaPresentation.mediaCountLabel(4) == "4 photos and videos")
        }

        @Test func profileTaggedMediaPresentation_uniqueTaggedMediaCount_dedupesByPhoto() {
            let buddy = DiveBuddy(displayName: "You")
            let buddyID = buddy.id
            let diveID = UUID()
            let mediaA = UUID()
            let mediaB = UUID()
            let otherDiveID = UUID()

            func makeTag(mediaID: UUID, diveID: UUID) -> DiveMediaBuddyTag {
                let tag = DiveMediaBuddyTag(buddy: buddy)
                tag.mediaPhotoID = mediaID
                tag.diveActivityID = diveID
                return tag
            }

            let tags = [
                makeTag(mediaID: mediaA, diveID: diveID),
                makeTag(mediaID: mediaA, diveID: diveID),
                makeTag(mediaID: mediaB, diveID: diveID),
                makeTag(mediaID: UUID(), diveID: otherDiveID),
            ]
            let count = ProfileTaggedMediaPresentation.uniqueTaggedMediaCount(
                tags: tags,
                buddyID: buddyID,
                ownerDiveActivityIDs: [diveID]
            )
            #expect(count == 2)
        }

        @Test func profileDestinationTilePresentation_usesUniformTileHeight() {
            #expect(ProfileDestinationTilePresentation.tileHeight == 54)
            #expect(ProfileDestinationTilePresentation.iconPointSize == 22)
            #expect(ProfileDestinationTilePresentation.iconSlotWidth == 28)
        }

        @Test func profilePhotoCropRenderer_baseFillScale_coversViewport() {
            let imageSize = CGSize(width: 800, height: 600)
            let cropDiameter: CGFloat = 280
            let scale = ProfilePhotoCropRenderer.baseFillScale(
                imageSize: imageSize,
                cropDiameter: cropDiameter
            )
            // Must use CGFloat division — `280 / 600` (Int) is 0.
            let expectedScale = CGFloat(280) / CGFloat(600)
            #expect(scale == expectedScale)
            #expect(expectedScale > 0)
        }

        @Test func profilePhotoCropRenderer_clampedOffset_keepsCropInsideImage() {
            let drawSize = CGSize(width: 400, height: 400)
            let cropDiameter: CGFloat = 280
            let clamped = ProfilePhotoCropRenderer.clampedOffset(
                CGSize(width: 500, height: -500),
                drawSize: drawSize,
                cropDiameter: cropDiameter
            )
            #expect(clamped.width == 60)
            #expect(clamped.height == -60)
        }

        @Test func profilePhotoCropRenderer_croppedJPEGData_returnsBytes() {
            #if canImport(UIKit)
            let size = CGSize(width: 200, height: 300)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.systemBlue.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            let data = ProfilePhotoCropRenderer.croppedJPEGData(
                from: image,
                cropDiameter: 280,
                gestureScale: 1,
                offset: .zero
            )
            #expect(data != nil)
            #expect(data?.isEmpty == false)
            #else
            #expect(Bool(true))
            #endif
        }
}
