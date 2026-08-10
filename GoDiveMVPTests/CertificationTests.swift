//
//  CertificationTests.swift
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


struct CertificationTests {
        @Test @MainActor
        func certification_persistsFieldsAndOwner() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "apple-cert", displayName: "Diver")
            context.insert(owner)

            let attained = Date(timeIntervalSince1970: 1_600_000_000)
            let frontBytes = Data([0xFF, 0xD8, 0x01])
            let backBytes = Data([0xFF, 0xD8, 0x02])

            let cert = Certification(
                agency: "PADI",
                certName: "Rescue Diver",
                certNumber: "OW-12345",
                dateAttained: attained,
                instructor: "Jane Smith",
                instructorNumber: "INS-99",
                diveShop: "Blue Water Dive Center",
                cardType: .certification,
                certFrontPicture: frontBytes,
                certBackPicture: backBytes
            )
            CertificationOwnership.assignOwner(owner, to: cert)
            context.insert(cert)
            try context.save()

            let fetched = try CertificationOwnership.items(forOwnerProfileID: owner.id, modelContext: context)
            #expect(fetched.count == 1)
            let card = try #require(fetched.first)
            #expect(card.agency == "PADI")
            #expect(card.certName == "Rescue Diver")
            #expect(card.certNumber == "OW-12345")
            #expect(card.dateAttained == attained)
            #expect(card.instructor == "Jane Smith")
            #expect(card.instructorNumber == "INS-99")
            #expect(card.diveShop == "Blue Water Dive Center")
            #expect(card.cardType == .certification)
            #expect(card.certFrontPicture == frontBytes)
            #expect(card.certBackPicture == backBytes)
            #expect(card.ownerProfileID == owner.id)
            #expect(owner.certifications.count == 1)
        }

        @Test @MainActor
        func certificationDeletion_deletePermanently_removesRow() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "apple-cert-del", displayName: "Diver")
            context.insert(owner)

            let cert = Certification(agency: "SSI", certNumber: "ADV-1")
            CertificationOwnership.assignOwner(owner, to: cert)
            context.insert(cert)
            try context.save()

            try CertificationDeletion.deletePermanently(cert, modelContext: context)
            #expect(try CertificationOwnership.items(forOwnerProfileID: owner.id, modelContext: context).isEmpty)
        }

        @Test @MainActor
        func certificationOwnership_filtersByOwnerProfileID() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let a = UserProfile(appleUserIdentifier: "apple-cert-a", displayName: "A")
            let b = UserProfile(appleUserIdentifier: "apple-cert-b", displayName: "B")
            context.insert(a)
            context.insert(b)

            let certA = Certification(agency: "PADI", certNumber: "A-1")
            CertificationOwnership.assignOwner(a, to: certA)
            context.insert(certA)

            let certB = Certification(agency: "NAUI", certNumber: "B-1")
            CertificationOwnership.assignOwner(b, to: certB)
            context.insert(certB)
            try context.save()

            #expect(try CertificationOwnership.items(forOwnerProfileID: a.id, modelContext: context).count == 1)
            #expect(try CertificationOwnership.items(forOwnerProfileID: b.id, modelContext: context).count == 1)
            #expect(try CertificationOwnership.items(forOwnerProfileID: a.id, modelContext: context).first?.agency == "PADI")
        }

        @Test func certificationFormValues_canSave_requiresNameAgencyAndCertNumber() {
            var form = CertificationFormValues()
            #expect(form.canSave == false)
            form.certName = "Rescue Diver"
            #expect(form.canSave == false)
            form.agency = "PADI"
            #expect(form.canSave == false)
            form.certNumber = "OW-1"
            #expect(form.canSave == true)
        }

        @Test func certificationFormValues_makeCertification_mapsOptionalFields() {
            let attained = Date(timeIntervalSince1970: 1_500_000)
            var form = CertificationFormValues()
            form.agency = "  NAUI  "
            form.certName = "  Advanced Open Water  "
            form.certNumber = " ADV-99 "
            form.dateAttained = attained
            form.instructor = " Pat "
            form.instructorNumber = " INS-1 "
            form.diveShop = " Reef Shop "
            form.diveShopNumber = " 19956 "
            form.cardType = .specialty
            form.certFrontPicture = Data([0x01])
            form.certBackPicture = Data([0x02])
            let cert = form.makeCertification()
            #expect(cert.agency == "NAUI")
            #expect(cert.certName == "Advanced Open Water")
            #expect(cert.certNumber == "ADV-99")
            #expect(cert.dateAttained == attained)
            #expect(cert.instructor == "Pat")
            #expect(cert.instructorNumber == "INS-1")
            #expect(cert.diveShop == "Reef Shop")
            #expect(cert.diveShopNumber == "19956")
            #expect(cert.cardType == .specialty)
            #expect(cert.certFrontPicture == Data([0x01]))
            #expect(cert.certBackPicture == Data([0x02]))
        }

        @Test func certificationFormValues_apply_updatesExistingCertification() {
            let cert = Certification(agency: "Old", certNumber: "1", cardType: .certification)
            var form = CertificationFormValues()
            form.agency = "SSI"
            form.certName = "Divemaster"
            form.certNumber = "DM-2"
            form.diveShop = ""
            form.diveShopNumber = ""
            form.cardType = .specialty
            form.apply(to: cert)
            #expect(cert.agency == "SSI")
            #expect(cert.certName == "Divemaster")
            #expect(cert.certNumber == "DM-2")
            #expect(cert.diveShop == nil)
            #expect(cert.diveShopNumber == nil)
            #expect(cert.cardType == .specialty)
        }

        @Test func padiCertificationCardParser_parsesTypicalBackCardLines() {
            let lines = [
                "PADI",
                "JANE DOE",
                "Diver No. 12345678",
                "Cert Date 15-Jan-2024",
                "Instr. No. 987654",
                "ALEX RIVERA",
                "54321",
                "Aquatic Adventures",
                "Key Largo, FL USA",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed != nil)
            #expect(parsed?.agency == "PADI")
            #expect(parsed?.certNumber == "12345678")
            #expect(parsed?.instructorNumber == "987654")
            #expect(parsed?.instructor == "Alex Rivera")
            #expect(parsed?.diveShop == "Aquatic Adventures")
            #expect(parsed?.diveShopNumber == "54321")

            let components = PADICertificationCardParser.wallClockDateComponents(from: parsed!.dateAttained!)
            #expect(components.year == 2024)
            #expect(components.month == 1)
            #expect(components.day == 15)
        }

        @Test func padiCertificationCardParser_parseCertDate_inlineUsesLocalWallClockDay() {
            let lines = [
                "ANDRE B. DUGAS",
                "Diver No. 21040R0406",
                "Cert.Date 02-Dec-2021",
                "Instr.No. OWSI-396419",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            let components = PADICertificationCardParser.wallClockDateComponents(from: parsed!.dateAttained!)
            #expect(components.year == 2021)
            #expect(components.month == 12)
            #expect(components.day == 2)
        }

        @Test func padiCertificationCardParser_parsesSplitLabelAndValueLines() {
            let lines = [
                "PADI",
                "Diver No.",
                "87654321",
                "Cert Date",
                "03-Mar-2022",
                "Instr. No.",
                "112233",
                "SAM TAYLOR",
                "Blue Water Dive Center",
                "Honolulu, HI USA",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed?.certNumber == "87654321")
            #expect(parsed?.instructorNumber == "112233")
            #expect(parsed?.instructor == "Sam Taylor")
            #expect(parsed?.diveShop == "Blue Water Dive Center")
            #expect(parsed?.diveShopNumber == nil)
        }

        @Test func padiCertificationCardParser_parsesECardFrontLines() {
            let lines = [
                "Andre B Dugas",
                "BIRTHDATE",
                "24-April-1998",
                "edit photo",
                "CERTIFICATION",
                "Rescue Diver",
                "CERT. DATE PADI NO.",
                "12-August-2024 24080D5449",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed != nil)
            #expect(parsed?.agency == "PADI")
            #expect(parsed?.certName == "Rescue Diver")
            #expect(parsed?.certNumber == "24080D5449")
            #expect(parsed?.instructor == nil)
            #expect(parsed?.instructorNumber == nil)
            #expect(parsed?.diveShop == nil)

            let components = PADICertificationCardParser.wallClockDateComponents(from: parsed!.dateAttained!)
            #expect(components.year == 2024)
            #expect(components.month == 8)
            #expect(components.day == 12)
        }

        @Test func padiCertificationCardParser_parsesAdvancedOpenWaterFrontLines() {
            let lines = [
                "Advanced Open Water Diver",
                "PADI",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed?.certName == "Advanced Open Water Diver")
            #expect(parsed?.agency == "PADI")
        }

        @Test func padiCertificationCardParser_parsesAdvancedOpenWaterSplitFrontLines() {
            let lines = [
                "Advanced",
                "Open Water Diver",
                "PADI",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed?.certName == "Advanced Open Water Diver")
            #expect(parsed?.agency == "PADI")
            #expect(parsed?.agencyDetectedFromCard == true)
        }

        @Test func padiCertificationCardParser_infersPADIAgencyWhenFrontTitleWithoutAgencyLine() {
            let lines = [
                "ANDRE B. DUGAS",
                "Advanced Open Water Diver",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed?.certName == "Advanced Open Water Diver")
            #expect(parsed?.agency == "PADI")
            #expect(parsed?.agencyDetectedFromCard == true)
        }

        @Test func padiCertificationCardParser_parsesPhysicalFrontCardSplitOCRLines() {
            let lines = [
                "Open Water",
                "Diver",
                "PADI",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed != nil)
            #expect(parsed?.agency == "PADI")
            #expect(parsed?.agencyDetectedFromCard == true)
            #expect(parsed?.certName == "Open Water Diver")
        }

        @Test func padiCertificationCardParser_parsesPhysicalFrontCardVisionOCRLines() {
            let lines = [
                "Open Water Diver",
                "PADI",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed != nil)
            #expect(parsed?.agency == "PADI")
            #expect(parsed?.agencyDetectedFromCard == true)
            #expect(parsed?.certName == "Open Water Diver")
            #expect(parsed?.certNumber == nil)
            #expect(parsed?.instructor == nil)
            #expect(parsed?.diveShop == nil)
            #expect(parsed?.diveShopNumber == nil)
        }

        @Test func padiCertificationCardParser_parsesPhysicalFrontCardLines() {
            let lines = [
                "PADI",
                "ANDRE B. DUGAS",
                "OPEN WATER DIVER",
                "Professional Association of Diving Instructors",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed != nil)
            #expect(parsed?.agency == "PADI")
            #expect(parsed?.agencyDetectedFromCard == true)
            #expect(parsed?.certName == "Open Water Diver")
            #expect(parsed?.certNumber == nil)
            #expect(parsed?.dateAttained == nil)
            #expect(parsed?.instructor == nil)
            #expect(parsed?.diveShop == nil)
        }

        @Test func padiCertificationCardParser_parsesPhysicalBackCardAlphanumericLines() {
            let lines = [
                "ANDRE B. DUGAS",
                "Diver No. 21040R0406",
                "BirthDate 24-Apr-1998",
                "Cert. Date 27-Apr-2021",
                "Instr.No. OWSI-396419",
                "KIRIANA HOWLETT",
                "19956",
                "HOMESTEAD CRATER",
                "MIDWAY, UT",
                "435 657 3840",
                "www.padi.com",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed != nil)
            #expect(parsed?.certNumber == "21040R0406")
            #expect(parsed?.instructorNumber == "OWSI-396419")
            #expect(parsed?.instructor == "Kiriana Howlett")
            #expect(parsed?.diveShop == "Homestead Crater")
            #expect(parsed?.diveShopNumber == "19956")
            #expect(parsed?.agency == "PADI")
            #expect(parsed?.agencyDetectedFromCard == true)
            #expect(parsed?.certName == nil)

            let components = PADICertificationCardParser.wallClockDateComponents(from: parsed!.dateAttained!)
            #expect(components.year == 2021)
            #expect(components.month == 4)
            #expect(components.day == 27)
        }

        @Test func padiCertificationCardParser_parsesPhysicalBackCardVisionOCRLines() {
            let lines = [
                "ANDRE B. DUGAS",
                "Diver No. 21040R0406",
                "BirthDate 24-Apr-1998",
                "Cert.Date 27-Аpr-2021",
                "Instr.No. OWSI-396419",
                "KIRIANA HOWLETT",
                "19956",
                "HOMESTEAD CRATER",
                "MIDWAY, UT",
                "435 657 3840",
                "This qualification meets ISO 24801-2: Diver Level 2 - Autonomous Diver Standard",
                "This diver has satisfactorily met the standards",
                "for this certification level as set forth by PADI",
                "www.padi.com",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed != nil)
            #expect(parsed?.certNumber == "21040R0406")
            #expect(parsed?.instructorNumber == "OWSI-396419")
            #expect(parsed?.instructor == "Kiriana Howlett")
            #expect(parsed?.diveShop == "Homestead Crater")
            #expect(parsed?.diveShopNumber == "19956")

            let components = PADICertificationCardParser.wallClockDateComponents(from: parsed!.dateAttained!)
            #expect(components.year == 2021)
            #expect(components.month == 4)
            #expect(components.day == 27)
        }

        @Test func padiCertificationCardParser_stripsShopNumberFromMergedInstructorLine() {
            let lines = [
                "ANDRE B. DUGAS",
                "Diver No. 21040R0406",
                "Cert. Date 27-Apr-2021",
                "Instr.No. OWSI-396419",
                "KIRIANA HOWLETT 19956",
                "HOMESTEAD CRATER",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed?.instructor == "Kiriana Howlett")
            #expect(parsed?.diveShopNumber == "19956")
            #expect(parsed?.diveShop == "Homestead Crater")
        }

        @Test func certificationFormValues_applyPADIParseResult_setsCertNameWhenEmpty() {
            var form = CertificationFormValues()
            var parsed = PADICertificationCardParseResult()
            parsed.certName = "Rescue Diver"
            parsed.certNumber = "24080D5449"

            form.applyPADIParseResult(parsed)

            #expect(form.agency == "PADI")
            #expect(form.certName == "Rescue Diver")
            #expect(form.certNumber == "24080D5449")
        }

        @Test func certificationFormValues_applyPADIParseResult_setsAgencyWhenCertNameParsedWithoutAgencyFlag() {
            var form = CertificationFormValues()
            var parsed = PADICertificationCardParseResult()
            parsed.certName = "Advanced Open Water Diver"

            form.applyPADIParseResult(parsed)

            #expect(form.agency == "PADI")
            #expect(form.certName == "Advanced Open Water Diver")
        }

        @Test func padiCertificationCardParser_ignoresCardFooterBoilerplateForDiveShop() {
            let lines = [
                "ANDRE B. DUGAS",
                "Diver No. 21040R0406",
                "Cert. Date 27-Apr-2021",
                "Instr.No. OWSI-396419",
                "KIRIANA HOWLETT",
                "19956",
                "This diver has satisfactorily met the standards for this certification level",
                "This qualification meets ISO 24801-2: Diver Level 2 - Autonomous Diver Standard",
                "for this certification level as set forth by PADI",
                "www.padi.com",
            ]

            let parsed = PADICertificationCardParser.parse(recognizedLines: lines)
            #expect(parsed?.instructor == "Kiriana Howlett")
            #expect(parsed?.diveShopNumber == "19956")
            #expect(parsed?.diveShop == nil)
        }

        @Test func padiCertificationCardParser_returnsNilForUnrelatedText() {
            let parsed = PADICertificationCardParser.parse(recognizedLines: [
                "Random note",
                "Not a certification card",
            ])
            #expect(parsed == nil)
        }

        @Test func certificationFormValues_applyPADIParseResult_updatesFieldsWhenParsedValueDiffers() {
            var form = CertificationFormValues()
            form.agency = "NAUI"
            form.certNumber = "KEEP-ME"
            form.instructor = "Existing Instructor"

            var parsed = PADICertificationCardParseResult()
            parsed.certNumber = "12345678"
            parsed.instructorNumber = "987654"
            parsed.instructor = "Alex Rivera"
            parsed.diveShop = "Aquatic Adventures"
            parsed.diveShopNumber = "54321"
            parsed.dateAttained = PADICertificationCardParser.wallClockDate(year: 2021, month: 12, day: 2)

            form.applyPADIParseResult(parsed)

            #expect(form.agency == "PADI")
            #expect(form.certNumber == "12345678")
            #expect(form.instructor == "Alex Rivera")
            #expect(form.instructorNumber == "987654")
            #expect(form.diveShop == "Aquatic Adventures")
            #expect(form.diveShopNumber == "54321")

            let components = PADICertificationCardParser.wallClockDateComponents(from: form.dateAttained)
            #expect(components.year == 2021)
            #expect(components.month == 12)
            #expect(components.day == 2)
        }

        @Test func certificationFormValues_applyPADIParseResult_leavesFieldUnchangedWhenParsedValueMatches() {
            var form = CertificationFormValues()
            form.agency = "PADI"
            form.certNumber = "21040R0406"
            form.instructor = "Kiriana Howlett"
            form.dateAttained = PADICertificationCardParser.wallClockDate(year: 2021, month: 4, day: 27)!

            var parsed = PADICertificationCardParseResult()
            parsed.certNumber = "21040R0406"
            parsed.instructor = "Kiriana Howlett"
            parsed.dateAttained = PADICertificationCardParser.wallClockDate(year: 2021, month: 4, day: 27)
            parsed.instructorNumber = "OWSI-396419"

            form.applyPADIParseResult(parsed)

            #expect(form.agency == "PADI")
            #expect(form.certNumber == "21040R0406")
            #expect(form.instructor == "Kiriana Howlett")
            #expect(form.instructorNumber == "OWSI-396419")

            let components = PADICertificationCardParser.wallClockDateComponents(from: form.dateAttained)
            #expect(components.year == 2021)
            #expect(components.month == 4)
            #expect(components.day == 27)
        }

        @Test func certificationFormValues_applyPADIParseResult_leavesFieldUnchangedWhenParsedValueMissing() {
            var form = CertificationFormValues()
            form.agency = "PADI"
            form.certName = "Open Water Diver"
            form.certNumber = "21040R0406"
            form.instructor = "Kiriana Howlett"
            form.dateAttained = PADICertificationCardParser.wallClockDate(year: 2021, month: 4, day: 27)!

            var parsed = PADICertificationCardParseResult()
            parsed.certName = "Advanced Open Water Diver"

            form.applyPADIParseResult(parsed)

            #expect(form.agency == "PADI")
            #expect(form.certName == "Advanced Open Water Diver")
            #expect(form.certNumber == "21040R0406")
            #expect(form.instructor == "Kiriana Howlett")
            #expect(form.instructorNumber.isEmpty)
            #expect(form.diveShop.isEmpty)
            #expect(form.diveShopNumber.isEmpty)

            let components = PADICertificationCardParser.wallClockDateComponents(from: form.dateAttained)
            #expect(components.year == 2021)
            #expect(components.month == 4)
            #expect(components.day == 27)
        }

        @Test func certificationFormValues_initFromCertification_restoresFields() {
            let attained = Date(timeIntervalSince1970: 2_000_000)
            let cert = Certification(
                agency: "PADI",
                certName: "Open Water",
                certNumber: "OW-1",
                dateAttained: attained,
                instructor: "Alex",
                instructorNumber: "99",
                diveShop: "Blue Shop",
                diveShopNumber: "19956",
                cardType: .certification,
                certFrontPicture: Data([0xAA])
            )
            let form = CertificationFormValues(from: cert)
            #expect(form.agency == "PADI")
            #expect(form.certName == "Open Water")
            #expect(form.certNumber == "OW-1")
            #expect(form.dateAttained == attained)
            #expect(form.instructor == "Alex")
            #expect(form.diveShop == "Blue Shop")
            #expect(form.diveShopNumber == "19956")
            #expect(form.cardType == .certification)
            #expect(form.certFrontPicture == Data([0xAA]))
        }

        @Test func certificationPresentation_title_prefersCertName() {
            let cert = Certification(agency: "PADI", certName: "Rescue Diver", certNumber: "123")
            #expect(CertificationPresentation.title(for: cert) == "Rescue Diver")
        }

        @Test func certificationPresentation_addSheetAccessibilityIdentifiers() {
            #expect(CertificationPresentation.addSheetCancelAccessibilityIdentifier == "CertificationAddSheet.Cancel")
            #expect(CertificationPresentation.addSheetDoneAccessibilityIdentifier == "CertificationAddSheet.Done")
        }

        @Test func certificationPresentation_title_fallsBackToAgencyAndNumber() {
            let cert = Certification(agency: "PADI", certNumber: "123")
            #expect(CertificationPresentation.title(for: cert) == "PADI · #123")
        }

        @Test func certificationPresentation_listRows_showAgencyNumberAndDateSeparately() {
            let cert = Certification(
                agency: "PADI",
                certName: "Rescue Diver",
                certNumber: "240988",
                dateAttained: Date(timeIntervalSince1970: 1_700_000_000)
            )
            #expect(CertificationPresentation.listAgencyNumberLine(for: cert) == "PADI · #240988")
            #expect(CertificationPresentation.listAgencyLine(for: cert) == "PADI")
            #expect(CertificationPresentation.formattedCertNumber("240988") == "#240988")
            #expect(CertificationPresentation.formattedCertNumber("#99") == "#99")
            #expect(CertificationPresentation.formattedCertNumber("  ") == nil)
            #expect(CertificationPresentation.listAgencyNumberLine(for: Certification()) == "—")
            #expect(CertificationPresentation.listAgencyLine(for: Certification()) == "—")
            #expect(
                CertificationPresentation.listDateLine(for: cert)
                    == CertificationPresentation.formattedDate(cert.dateAttained)
            )
            #expect(
                CertificationPresentation.subtitle(for: cert)
                    == "PADI · #240988 · \(CertificationPresentation.listDateLine(for: cert))"
            )
        }

        @Test func certificationPresentation_profileFeaturedCertificationCard_returnsNewestCertificationType() {
            let older = Certification(
                agency: "PADI",
                certName: "Open Water",
                certNumber: "1",
                dateAttained: Date(timeIntervalSince1970: 1_000),
                cardType: .certification
            )
            let newer = Certification(
                agency: "PADI",
                certName: "Rescue Diver",
                certNumber: "2",
                dateAttained: Date(timeIntervalSince1970: 2_000),
                cardType: .certification
            )
            let featured = CertificationPresentation.profileFeaturedCertificationCard(from: [older, newer])
            #expect(featured?.certName == "Rescue Diver")
        }

        @Test func certificationPresentation_profileFeaturedCertificationCard_nilWhenOnlySpecialty() {
            let specialty = Certification(
                agency: "PADI",
                certName: "Enriched Air",
                certNumber: "1",
                cardType: .specialty
            )
            #expect(CertificationPresentation.profileFeaturedCertificationCard(from: [specialty]) == nil)
        }

        @Test func certificationPresentation_profileSubtitle_usesNewestCertificationTypeName() {
            let older = Certification(
                agency: "PADI",
                certName: "Open Water",
                certNumber: "1",
                dateAttained: Date(timeIntervalSince1970: 1_000),
                cardType: .certification
            )
            let newer = Certification(
                agency: "PADI",
                certName: "Rescue Diver",
                certNumber: "2",
                dateAttained: Date(timeIntervalSince1970: 2_000),
                cardType: .certification
            )
            let subtitle = CertificationPresentation.profileCertificationSubtitle(from: [older, newer])
            #expect(subtitle == "Rescue Diver")
        }

        @Test func certificationPresentation_profileSubtitle_ignoresNewerSpecialty() {
            let olderCert = Certification(
                agency: "PADI",
                certName: "Open Water",
                certNumber: "1",
                dateAttained: Date(timeIntervalSince1970: 1_000),
                cardType: .certification
            )
            let newerSpecialty = Certification(
                agency: "PADI",
                certName: "Enriched Air",
                certNumber: "2",
                dateAttained: Date(timeIntervalSince1970: 2_000),
                cardType: .specialty
            )
            let subtitle = CertificationPresentation.profileCertificationSubtitle(
                from: [olderCert, newerSpecialty]
            )
            #expect(subtitle == "Open Water")
        }

        @Test func certificationPresentation_profileSubtitle_nilWithoutCertificationType() {
            let cert = Certification(
                agency: "PADI",
                certName: "Wreck Diver",
                certNumber: "1",
                dateAttained: .now,
                cardType: .specialty
            )
            #expect(CertificationPresentation.profileCertificationSubtitle(from: [cert]) == nil)
            #expect(CertificationPresentation.profileFeaturedCertification(from: [cert]) == nil)
        }

        @Test func certificationPresentation_profileSubtitle_nilWhenNoCertifications() {
            #expect(CertificationPresentation.profileCertificationSubtitle(from: []) == nil)
            #expect(CertificationPresentation.profileFeaturedCertification(from: []) == nil)
        }

        @Test func certificationPresentation_profileFeatured_includesCertNumberUnderName() {
            let cert = Certification(
                agency: "PADI",
                certName: "Rescue Diver",
                certNumber: "  RD-991  ",
                dateAttained: .now,
                cardType: .certification
            )
            let display = CertificationPresentation.profileFeaturedCertification(from: [cert])
            #expect(display?.title == "Rescue Diver")
            #expect(display?.certNumber == "RD-991")
        }

        @Test func certificationPresentation_profileFeatured_omitsNumberWhenNameMissing() {
            let cert = Certification(
                agency: "PADI",
                certNumber: "RD-991",
                dateAttained: .now,
                cardType: .certification
            )
            let display = CertificationPresentation.profileFeaturedCertification(from: [cert])
            #expect(display?.title == "PADI · #RD-991")
            #expect(display?.certNumber == nil)
        }

        @Test func certificationPresentation_profileFeatured_omitsNumberWhenEmpty() {
            let cert = Certification(
                agency: "PADI",
                certName: "Rescue Diver",
                certNumber: "   ",
                dateAttained: .now,
                cardType: .certification
            )
            let display = CertificationPresentation.profileFeaturedCertification(from: [cert])
            #expect(display?.title == "Rescue Diver")
            #expect(display?.certNumber == nil)
        }

        @Test func certificationPresentation_typeBadgeStyle_differsByCardType() {
            let certification = CertificationPresentation.typeBadgeStyle(for: .certification)
            let specialty = CertificationPresentation.typeBadgeStyle(for: .specialty)
            #expect(certification.label == "Certification")
            #expect(specialty.label == "Specialty")
            #expect(certification.foreground != specialty.foreground)
            #expect(certification.background != specialty.background)
        }

        @Test func certificationPresentation_detailHeaderName_prefersCertName() {
            let cert = Certification(agency: "PADI", certName: "Rescue Diver", certNumber: "99")
            #expect(CertificationPresentation.detailHeaderName(for: cert) == "Rescue Diver")
        }

        @Test func certificationPresentation_detailHeaderName_fallsBackToTitle() {
            let cert = Certification(agency: "PADI", certNumber: "99")
            #expect(CertificationPresentation.detailHeaderName(for: cert) == "PADI · #99")
        }

        @Test func certificationPresentation_sortedForList_newestDateAttainedFirst() {
            let older = Certification(
                agency: "PADI",
                certName: "Open Water",
                certNumber: "1",
                dateAttained: Date(timeIntervalSince1970: 1_000),
                cardType: .certification
            )
            let newer = Certification(
                agency: "NAUI",
                certName: "Rescue Diver",
                certNumber: "2",
                dateAttained: Date(timeIntervalSince1970: 2_000),
                cardType: .specialty
            )
            let sorted = CertificationPresentation.sortedForList([older, newer])
            #expect(sorted.map(\.certName) == ["Rescue Diver", "Open Water"])
        }

        @Test func certificationPresentation_divesLoggedSinceAttainedCount_includesAttainedDayOnward() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let attainedDay = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15))!
            let sameDayMorning = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 9))!
            let dayBefore = calendar.date(from: DateComponents(year: 2024, month: 6, day: 14, hour: 18))!
            let dayAfter = calendar.date(from: DateComponents(year: 2024, month: 6, day: 16, hour: 10))!
            let count = CertificationPresentation.divesLoggedSinceAttainedCount(
                startTimes: [dayBefore, sameDayMorning, dayAfter],
                dateAttained: attainedDay,
                calendar: calendar
            )
            #expect(count == 2)
            #expect(CertificationPresentation.divesLoggedSinceAttainedLabel(count: 0) == "0 dives")
            #expect(CertificationPresentation.divesLoggedSinceAttainedLabel(count: 1) == "1 dive")
            #expect(CertificationPresentation.divesLoggedSinceAttainedLabel(count: 2) == "2 dives")
        }

        @Test func certificationDetailHeroPresentation_showsToggleOnlyWhenBothFacesPresent() {
            #expect(
                CertificationDetailHeroPresentation.showsHeroSideToggle(hasFront: true, hasBack: true)
            )
            #expect(
                !CertificationDetailHeroPresentation.showsHeroSideToggle(hasFront: true, hasBack: false)
            )
            #expect(
                !CertificationDetailHeroPresentation.showsHeroSideToggle(hasFront: false, hasBack: true)
            )
            #expect(
                !CertificationDetailHeroPresentation.showsHeroSideToggle(hasFront: false, hasBack: false)
            )
            #expect(
                CertificationDetailHeroPresentation.defaultHeroSide(hasFront: false, hasBack: true) == .back
            )
            #expect(
                CertificationDetailHeroPresentation.defaultHeroSide(hasFront: true, hasBack: false) == .front
            )
            let front = Data([0x01])
            let back = Data([0x02])
            #expect(
                CertificationDetailHeroPresentation.photoData(
                    for: .front,
                    frontPicture: front,
                    backPicture: back
                ) == front
            )
            #expect(
                CertificationDetailHeroPresentation.photoData(
                    for: .back,
                    frontPicture: nil,
                    backPicture: back
                ) == back
            )
            #expect(CertificationDetailHeroPresentation.cardPhotoSeamBottomInset == HomeOverviewLayout.panelOverlap)
            #expect(CertificationDetailHeroPresentation.cardPhotoHorizontalInset == 0)
        }

        @Test func certificationDetailContentPagerPresentation_twoTabs() {
            #expect(CertificationDetailContentPagerPresentation.pageCount == 2)
            #expect(CertificationDetailContentPagerPresentation.defaultPage == .details)
            #expect(
                CertificationDetailContentPagerPresentation.pages == [
                    .details,
                    .instructorAndShop,
                ]
            )
            #expect(
                CertificationDetailContentPagerPresentation.pageTitle(for: .details) == "Details"
            )
            #expect(
                CertificationDetailContentPagerPresentation.pageTitle(for: .instructorAndShop)
                    == "Instructor & shop"
            )
            #expect(
                CertificationDetailContentPagerPresentation.accessibilityIdentifier(for: .details)
                    == "CertificationDetails.ContentPager.Details"
            )
        }
}
