//
//  TaggingSheetTests.swift
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


struct TaggingSheetTests {
        @Test @MainActor func activityTagDetailContentPagerPresentation_pagesMatchTripStartedOrder() {
            #expect(ActivityTagDetailContentPagerPresentation.pageCount == 5)
            #expect(
                ActivityTagDetailContentPagerPresentation.pages == [
                    .stats, .activities, .marineLife, .buddies, .media,
                ]
            )
            #expect(ActivityTagDetailContentPagerPresentation.defaultPage == .stats)
            #expect(
                ActivityTagDetailContentPagerPresentation.accessibilityIdentifier(for: .stats)
                    == "ActivityTagDetails.ContentPager.Stats"
            )
            #expect(ActivityTagDetailContentPagerPresentation.usesStaticPagerLayout(for: .stats))
            #expect(!ActivityTagDetailContentPagerPresentation.usesStaticPagerLayout(for: .media))
            #expect(
                ActivityTagDetailContentPagerPresentation.staticPagerContentAlignment(for: .stats) == .center
            )
        }

        @Test @MainActor func activityTagDetailPresentation_headerUsesTagIcon() {
            #expect(ActivityTagDetailPresentation.headerSystemImage == "tag.fill")
            #expect(ActivityTagDetailPresentation.headerTypeAccessibilityLabel == "Activity tag")
            #expect(
                ActivityTagDetailPresentation.pinnedHeaderAccessibilityLabel(
                    tagName: "Reef",
                    diveCount: 3
                ) == "Activity tag, Reef, 3 dives"
            )
        }

        @Test @MainActor func activityTagDetailPresentation_ordersTaggedDivesNewestFirst() {
            let tag = ActivityTag(name: "Wreck", normalizedName: "wreck", ownerProfileID: UUID())
            let older = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 1_000_000),
                durationMinutes: 40,
                maxDepthMeters: 18
            )
            let newer = DiveActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 2_000_000),
                durationMinutes: 42,
                maxDepthMeters: 24
            )
            tag.dives = [older, newer]

            let ordered = ActivityTagDetailPresentation.taggedDives(on: tag)
            #expect(ordered.map(\.id) == [newer.id, older.id])
            #expect(ActivityTagDetailPresentation.diveCountLabel(count: 2) == "2 dives")
            #expect(ActivityTagDetailPresentation.diveCountLabel(count: 1) == "1 dive")
        }

        @Test func activityTagStore_normalizedName_collapsesWhitespaceAndCase() {
            #expect(ActivityTagStore.normalizedName(from: "  Night  Dive  ") == "night dive")
            #expect(ActivityTagStore.displayName(from: "  Wreck  ") == "Wreck")
            #expect(ActivityTagPresentation.chipTitleMaxLength == 25)
            #expect(ActivityTagPresentation.chipDisplayTitle(for: "Night Dive") == "Night Dive")
            #expect(
                ActivityTagPresentation.chipDisplayTitle(for: String(repeating: "A", count: 30))
                    == String(repeating: "A", count: 25) + "…"
            )
            #expect(ActivityTagPresentation.chipDisplayTitle(for: "  Drift Dive  ") == "Drift Dive")
        }

        @Test @MainActor func activityTagStore_findOrCreate_dedupesPerOwner() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let ownerID = UUID()

            let first = try ActivityTagStore.findOrCreateTag(
                rawName: "Night Dive",
                ownerProfileID: ownerID,
                modelContext: context
            )
            let second = try ActivityTagStore.findOrCreateTag(
                rawName: "night dive",
                ownerProfileID: ownerID,
                modelContext: context
            )
            #expect(first?.id == second?.id)

            let allTags = try ActivityTagStore.fetchTags(ownerProfileID: ownerID, modelContext: context)
            #expect(allTags.count == 1)
            #expect(allTags[0].name == "Night Dive")
        }

        @Test @MainActor func activityTagStore_applyAndRemove_updatesDiveMembership() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let ownerID = UUID()
            let dive = DiveActivity(source: .manual, startTime: .now, durationMinutes: 1, maxDepthMeters: 1)
            dive.ownerProfileID = ownerID
            context.insert(dive)

            let tag = try ActivityTagStore.findOrCreateTag(
                rawName: "Training",
                ownerProfileID: ownerID,
                modelContext: context
            )
            #expect(tag != nil)

            ActivityTagStore.applyTag(tag!, to: dive)
            #expect(ActivityTagStore.sortedTags(on: dive).map(\.name) == ["Training"])
            #expect(ActivityTagStore.summaryLine(for: dive) == "Training")

            ActivityTagStore.removeTag(tag!, from: dive)
            #expect(dive.activityTags.isEmpty)
        }

        @Test @MainActor func activityTagStore_applyAndRemove_updatesSnorkelMembership() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let ownerID = UUID()
            let snorkel = SnorkelActivity(source: .manual, startTime: .now, durationMinutes: 30)
            snorkel.ownerProfileID = ownerID
            context.insert(snorkel)

            let tag = try ActivityTagStore.findOrCreateTag(
                rawName: "Shallow Reef",
                ownerProfileID: ownerID,
                modelContext: context
            )
            #expect(tag != nil)

            ActivityTagStore.applyTag(tag!, to: snorkel)
            #expect(ActivityTagStore.sortedTags(on: snorkel).map(\.name) == ["Shallow Reef"])
            #expect(ActivityTagStore.summaryLine(for: snorkel) == "Shallow Reef")

            ActivityTagStore.removeTag(tag!, from: snorkel)
            #expect(snorkel.activityTags.isEmpty)
        }
}
