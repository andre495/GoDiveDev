//
//  SnorkelActivityTests.swift
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


struct SnorkelActivityTests {
        @Test @MainActor func snorkelBuddyActivityTagDraftPresentation_apply_syncsRoster() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext

            let owner = UserProfile(appleUserIdentifier: "snorkel-buddy-draft", displayName: "Diver")
            let snorkel = SnorkelActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 3_450_000),
                durationMinutes: 35
            )
            snorkel.ownerProfileID = owner.id
            let jamie = DiveBuddy(displayName: "Jamie", owner: owner)
            let alex = DiveBuddy(displayName: "Alex", owner: owner)
            context.insert(owner)
            context.insert(snorkel)
            context.insert(jamie)
            context.insert(alex)

            _ = SnorkelBuddyActivityAssociation.tagBuddy(jamie, on: snorkel, modelContext: context)
            try context.save()
            #expect(snorkel.buddies.count == 1)

            let roster = [jamie.id: jamie, alex.id: alex]
            SnorkelBuddyActivityTagDraftPresentation.apply(
                draftTaggedBuddyIDs: [alex.id],
                to: snorkel,
                rosterByID: roster,
                modelContext: context
            )
            try context.save()

            #expect(Set(snorkel.buddies.compactMap(\.buddyID)) == [alex.id])
        }

        @Test func snorkelActivityMediaStorage_setFeaturedMedia_persistsAndClears() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let activity = SnorkelActivity(
                source: .manual,
                startTime: Date(),
                durationMinutes: 0,
                maxDepthMeters: 0
            )
            context.insert(activity)
            try context.save()

            let featured = UUID()
            try SnorkelActivityMediaStorage.setFeaturedMedia(featured, on: activity, modelContext: context)
            #expect(activity.featuredMediaPhotoID == featured)

            try SnorkelActivityMediaStorage.setFeaturedMedia(nil, on: activity, modelContext: context)
            #expect(activity.featuredMediaPhotoID == nil)
        }

        @Test @MainActor
        func snorkelActivityOwnership_claimUnowned_assignsOrphanSnorkels() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "apple-snorkel-claim", displayName: "Snorkeler")
            context.insert(owner)

            let orphan = SnorkelActivity(startTime: Date(), durationMinutes: 20)
            context.insert(orphan)
            try context.save()

            let claimed = try SnorkelActivityOwnership.claimUnownedSnorkels(for: owner, modelContext: context)
            #expect(claimed == 1)
            #expect(orphan.ownerProfileID == owner.id)
            #expect(orphan.owner?.id == owner.id)
        }

        @Test func snorkelActivityDeletionMarineLifeCleanup_removeSnorkelReferences_stripsActivityMediaAndSite() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let ownerID = UUID()
            let snorkelID = UUID()
            let siteID = UUID()
            let mediaID = UUID()
            let species = MarineLife(
                uuid: "fish-snorkel",
                commonName: "Snorkel Fish",
                scientificName: "Snorkelus",
                category: "Fish"
            )
            let record = MarineLifeUserRecord(
                marineLifeUUID: species.uuid,
                isSighted: true,
                activitiesSightedOn: [snorkelID],
                sitesSightedOn: [siteID],
                userTaggedMedia: [DiveActivityDeletionMarineLifeCleanup.userTaggedMediaLink(for: mediaID)]
            )
            record.ownerProfileID = ownerID
            context.insert(species)
            context.insert(record)

            let activity = SnorkelActivity(id: snorkelID, startTime: .now, durationMinutes: 10)
            let photo = SnorkelMediaPhoto(id: mediaID, sortOrder: 0, mediaKind: .image, snorkelActivity: activity)
            activity.mediaPhotos.append(photo)
            context.insert(activity)
            try context.save()

            try SnorkelActivityDeletionMarineLifeCleanup.removeSnorkelReferences(
                snorkelID: snorkelID,
                mediaPhotoIDs: [mediaID],
                diveSiteID: siteID,
                ownerProfileID: ownerID,
                modelContext: context
            )

            #expect(record.activitiesSightedOn.isEmpty)
            #expect(record.sitesSightedOn.isEmpty)
            #expect(record.userTaggedMedia.isEmpty)
        }

        @Test @MainActor
        func snorkelActivityDeletion_removesActivityAndCascadedBuddy() async throws {
            let schema = Schema([
                SnorkelActivity.self,
                SnorkelBuddyTag.self,
                DiveBuddy.self,
                SnorkelProfilePoint.self,
                DiveSite.self,
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let activity = SnorkelActivity(startTime: .now, durationMinutes: 12)
            let person = DiveBuddy(displayName: "Pat")
            let tag = SnorkelBuddyTag(buddy: person, snorkelActivity: activity)
            activity.buddies.append(tag)
            context.insert(person)
            context.insert(activity)
            context.insert(tag)
            try context.save()

            try await SnorkelActivityDeletion.deletePermanently(activity, modelContext: context)

            let snorkels = try context.fetch(FetchDescriptor<SnorkelActivity>())
            let tags = try context.fetch(FetchDescriptor<SnorkelBuddyTag>())
            let people = try context.fetch(FetchDescriptor<DiveBuddy>())
            #expect(snorkels.isEmpty)
            #expect(tags.isEmpty)
            #expect(people.count == 1)
        }

        @Test func snorkelActivityRelationshipDetachment_clearsOwnerInverseBeforeDelete() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "snorkel-detach-owner", displayName: "Snorkeler")
            let activity = SnorkelActivity(startTime: Date(), durationMinutes: 25)
            activity.owner = owner
            activity.ownerProfileID = owner.id
            owner.snorkelActivities.append(activity)

            context.insert(owner)
            context.insert(activity)
            try context.save()

            SnorkelActivityRelationshipDetachment.detachNonCascadeRelationships(
                from: activity,
                modelContext: context
            )
            try context.save()

            #expect(owner.snorkelActivities.isEmpty)
            #expect(activity.owner == nil)
            #expect(activity.diveSiteID == nil)
        }
}
