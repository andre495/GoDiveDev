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

        @Test @MainActor func snorkelActivityMediaStorage_removeMedia_deletesItemAndClearsFeatured() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = container.mainContext
            let owner = UserProfile(appleUserIdentifier: "remove-snorkel-media", displayName: "Snorkeler")
            let activity = SnorkelActivity(
                source: .manual,
                startTime: Date(timeIntervalSince1970: 5_200_000),
                durationMinutes: 30
            )
            activity.owner = owner
            activity.ownerProfileID = owner.id
            let keep = SnorkelMediaPhoto(
                sortOrder: 0,
                mediaKind: .image,
                capturedAt: Date(timeIntervalSince1970: 5_200_100),
                snorkelActivity: activity
            )
            let remove = SnorkelMediaPhoto(
                sortOrder: 1,
                mediaKind: .video,
                capturedAt: Date(timeIntervalSince1970: 5_200_200),
                snorkelActivity: activity
            )
            activity.mediaPhotos = [keep, remove]
            activity.featuredMediaPhotoID = remove.id
            activity.friendShareBuddySettingsConfigured = true
            activity.friendShareMediaSelectedIDsJSON = ActivityFriendShareConfiguration.encodeMediaIDs(
                [keep.id, remove.id]
            )
            let species = MarineLife(uuid: "marine-life-remove-snorkel-media", commonName: "Snorkel Fish")
            context.insert(owner)
            context.insert(activity)
            context.insert(keep)
            context.insert(remove)
            context.insert(species)
            try context.save()

            _ = try MarineLifeSightingRecorder.tagSpecies(
                species,
                on: remove,
                snorkel: activity,
                owner: owner,
                modelContext: context
            )

            try SnorkelActivityMediaStorage.removeMedia(
                remove,
                from: activity,
                owner: owner,
                modelContext: context
            )

            #expect(Set(activity.mediaPhotos.map(\.id)) == [keep.id])
            #expect(activity.featuredMediaPhotoID == nil)
            #expect(
                ActivityFriendShareConfiguration.decodeMediaIDs(
                    from: activity.friendShareMediaSelectedIDsJSON
                ) == [keep.id]
            )
            #expect(
                try MarineLifeSightingRecorder.sightings(
                    forSnorkelActivityID: activity.id,
                    modelContext: context
                ).isEmpty
            )
            #expect(Set(try context.fetch(FetchDescriptor<SnorkelMediaPhoto>()).map(\.id)) == [keep.id])
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
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
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
            #expect(SnorkelActivityStoreSync.isSnorkelAbsent(snorkelID: activity.id, container: container))
        }

        @Test func snorkelBackgroundDeletionWorker_deleteSnorkel_removesActivityBuddiesAndMedia() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)

            let activityID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let activity = SnorkelActivity(
                    source: .manual,
                    startTime: .now,
                    durationMinutes: 12
                )
                let person = DiveBuddy(displayName: "Pat")
                let tag = SnorkelBuddyTag(buddy: person, snorkelActivity: activity)
                activity.buddies.append(tag)
                let photo = SnorkelMediaPhoto(sortOrder: 0, mediaKind: .image, snorkelActivity: activity)
                activity.mediaPhotos.append(photo)
                context.insert(person)
                context.insert(activity)
                context.insert(tag)
                try context.save()
                return activity.id
            }

            try await SnorkelBackgroundDeletionWorker(modelContainer: container)
                .deleteSnorkel(id: activityID)

            let counts = try await MainActor.run { () throws -> (Int, Int, Int, Int) in
                let context = ModelContext(container)
                let snorkels = try context.fetch(FetchDescriptor<SnorkelActivity>())
                let tags = try context.fetch(FetchDescriptor<SnorkelBuddyTag>())
                let people = try context.fetch(FetchDescriptor<DiveBuddy>())
                let media = try context.fetch(FetchDescriptor<SnorkelMediaPhoto>())
                return (snorkels.count, tags.count, people.count, media.count)
            }
            #expect(counts.0 == 0)
            #expect(counts.1 == 0)
            #expect(counts.2 == 1)
            #expect(counts.3 == 0)
        }

        @Test func snorkelBackgroundDeletionWorker_deleteSnorkel_withLinkedSite_removesProfilePointsAndCatalogSite() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)

            let snorkelID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let site = DiveSite(siteName: "Batch Delete Snorkel Site", latCoords: 12, longCoords: -68)
                let activity = SnorkelActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40
                )
                context.insert(site)
                context.insert(activity)
                DiveActivitySiteAssociation.link(activity, to: site)
                for i in 0 ..< 80 {
                    activity.profilePoints.append(
                        SnorkelProfilePoint(
                            timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
                            latitude: 12,
                            longitude: -68,
                            snorkelActivityID: activity.id
                        )
                    )
                }
                SnorkelProfilePointStore.insertStagedPoints(for: activity, into: context)
                try context.save()
                return activity.id
            }

            try await SnorkelBackgroundDeletionWorker(modelContainer: container)
                .deleteSnorkel(id: snorkelID)

            let counts = try await MainActor.run { () throws -> (Int, Int, Int) in
                let context = ModelContext(container)
                let snorkels = try context.fetch(FetchDescriptor<SnorkelActivity>())
                let points = try context.fetch(FetchDescriptor<SnorkelProfilePoint>())
                let sites = try context.fetch(FetchDescriptor<DiveSite>())
                return (snorkels.count, points.count, sites.count)
            }
            #expect(counts.0 == 0)
            #expect(counts.1 == 0)
            #expect(counts.2 == 0)
        }

        @Test func snorkelBackgroundDeletionWorker_deleteSnorkel_withSightingsTagsAndMarineLifeRecord_removesAllReferences() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)

            let snorkelID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "delete-snorkel-sightings", displayName: "Snorkeler")
                let site = DiveSite(siteName: "Reef", latCoords: 12, longCoords: -68)
                let species = MarineLife(
                    uuid: "snorkel-fish-001",
                    commonName: "Parrotfish",
                    scientificName: "Scarus",
                    category: "Fish"
                )
                let activity = SnorkelActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 40
                )
                activity.owner = owner
                activity.ownerProfileID = owner.id
                activity.diveSiteID = site.id

                let tag = ActivityTag(name: "Night", normalizedName: "night", ownerProfileID: owner.id)
                activity.activityTags.append(tag)
                tag.snorkels.append(activity)

                let photo = SnorkelMediaPhoto(sortOrder: 0, mediaKind: .image, snorkelActivity: activity)
                activity.mediaPhotos.append(photo)

                let sighting = SightingInstance(
                    marineLifeUUID: species.uuid,
                    sightingDateTime: activity.startTime,
                    snorkelActivity: activity,
                    diveSiteID: site.id,
                    snorkelMediaPhoto: photo
                )
                activity.marineLifeSightings.append(sighting)
                let record = MarineLifeUserRecord(
                    owner: owner,
                    marineLifeUUID: species.uuid,
                    isSighted: true,
                    activitiesSightedOn: [activity.id],
                    sitesSightedOn: [site.id],
                    userTaggedMedia: [DiveActivityDeletionMarineLifeCleanup.userTaggedMediaLink(for: photo.id)]
                )
                record.link(marineLifeUUID: species.uuid, owner: owner)

                context.insert(owner)
                context.insert(site)
                context.insert(species)
                context.insert(tag)
                context.insert(activity)
                context.insert(sighting)
                context.insert(record)
                try context.save()
                return activity.id
            }

            try await SnorkelBackgroundDeletionWorker(modelContainer: container)
                .deleteSnorkel(id: snorkelID)

            try await MainActor.run { () throws -> Void in
                let context = ModelContext(container)
                #expect(try context.fetch(FetchDescriptor<SnorkelActivity>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<SightingInstance>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<SnorkelMediaPhoto>()).isEmpty)

                let tag = try #require(try context.fetch(FetchDescriptor<ActivityTag>()).first)
                #expect(tag.snorkels.isEmpty)

                let record = try #require(try context.fetch(FetchDescriptor<MarineLifeUserRecord>()).first)
                #expect(record.activitiesSightedOn.isEmpty)
                #expect(record.sitesSightedOn.isEmpty)
                #expect(record.userTaggedMedia.isEmpty)
            }
            #expect(SnorkelActivityStoreSync.isSnorkelAbsent(snorkelID: snorkelID, container: container))
        }

        @Test func snorkelBackgroundDeletionWorker_deleteSnorkel_withMediaBuddyTags_removesJoinRowsKeepsBuddy() async throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)

            let snorkelID = try await MainActor.run { () throws -> UUID in
                let context = ModelContext(container)
                let owner = UserProfile(appleUserIdentifier: "delete-snorkel-media-buddy", displayName: "Snorkeler")
                let activity = SnorkelActivity(
                    source: .manual,
                    startTime: Date(),
                    durationMinutes: 25
                )
                activity.owner = owner
                activity.ownerProfileID = owner.id
                let person = DiveBuddy(displayName: "Alex", owner: owner)
                let photo = SnorkelMediaPhoto(sortOrder: 0, mediaKind: .image, snorkelActivity: activity)
                activity.mediaPhotos.append(photo)
                context.insert(owner)
                context.insert(activity)
                context.insert(person)
                _ = SnorkelBuddyActivityAssociation.tagBuddy(person, on: activity, modelContext: context)
                _ = try SnorkelMediaBuddyAssociation.tagBuddy(
                    person,
                    on: photo,
                    snorkel: activity,
                    modelContext: context
                )
                try context.save()
                return activity.id
            }

            try await SnorkelBackgroundDeletionWorker(modelContainer: container)
                .deleteSnorkel(id: snorkelID)

            try await MainActor.run { () throws -> Void in
                let context = ModelContext(container)
                #expect(try context.fetch(FetchDescriptor<SnorkelActivity>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<SnorkelBuddyTag>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<SnorkelMediaPhoto>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<DiveMediaBuddyTag>()).isEmpty)
                #expect(try context.fetch(FetchDescriptor<DiveBuddy>()).count == 1)
            }
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

        @Test func snorkelActivityRelationshipDetachment_clearsBuddyAndMediaJoinRows() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)

            let owner = UserProfile(appleUserIdentifier: "snorkel-detach-joins", displayName: "Snorkeler")
            let activity = SnorkelActivity(startTime: Date(), durationMinutes: 20)
            activity.owner = owner
            activity.ownerProfileID = owner.id
            let person = DiveBuddy(displayName: "Jordan", owner: owner)
            let photo = SnorkelMediaPhoto(sortOrder: 0, mediaKind: .image, snorkelActivity: activity)
            activity.mediaPhotos.append(photo)
            context.insert(owner)
            context.insert(activity)
            context.insert(person)
            _ = SnorkelBuddyActivityAssociation.tagBuddy(person, on: activity, modelContext: context)
            _ = try SnorkelMediaBuddyAssociation.tagBuddy(
                person,
                on: photo,
                snorkel: activity,
                modelContext: context,
                persistImmediately: false
            )
            try context.save()

            SnorkelActivityRelationshipDetachment.detachNonCascadeRelationships(
                from: activity,
                modelContext: context
            )
            try context.save()

            #expect(activity.buddies.isEmpty)
            #expect(activity.mediaBuddyTags.isEmpty)
            #expect(person.snorkelParticipations.isEmpty)
            #expect(person.mediaBuddyTags.isEmpty)
            #expect(try context.fetch(FetchDescriptor<SnorkelBuddyTag>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<DiveMediaBuddyTag>()).isEmpty)
            #expect(try context.fetch(FetchDescriptor<DiveBuddy>()).count == 1)
        }

        @Test func snorkelActivityManualCreation_makeBlank_usesManualSourceAndNoSourceActivityId() {
            let snorkel = SnorkelActivityManualCreation.makeBlankActivity()
            #expect(snorkel.source == .manual)
            #expect(snorkel.sourceActivityId == nil)
            #expect(snorkel.durationMinutes == 0)
            #expect(snorkel.maxDepthMeters == nil)
            #expect(snorkel.swimDistanceMeters == nil)
            #expect(snorkel.profilePoints.isEmpty)
        }

        @Test func snorkelActivityManualCreation_sheetAccessibilityIdentifiers() {
            #expect(SnorkelActivityManualCreation.cancelAccessibilityIdentifier == "ManualSnorkelEntry.Cancel")
            #expect(SnorkelActivityManualCreation.doneAccessibilityIdentifier == "ManualSnorkelEntry.Done")
        }

        @Test func snorkelActivityManualCreation_makeBlank_appliesStartTime() {
            let when = Date(timeIntervalSince1970: 1_700_000_000)
            let snorkel = SnorkelActivityManualCreation.makeBlankActivity(startTime: when)
            #expect(snorkel.startTime == when)
        }

        @Test @MainActor
        func snorkelActivityManualCreation_persist_linksExistingCatalogSite() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let profile = UserProfile(appleUserIdentifier: "manual-snorkel-existing-site", displayName: "Snorkeler")
            context.insert(profile)

            let catalogSite = DiveSite(siteName: "Salt Pier", country: "Bonaire", waterType: .saltwater)
            context.insert(catalogSite)
            try context.save()

            let snorkel = SnorkelActivityManualCreation.makeBlankActivity()
            let outcome = SnorkelActivityManualCreation.persist(
                snorkel,
                siteSelection: .existingSite(id: catalogSite.id),
                modelContext: context,
                owner: profile
            )
            #expect(outcome.primaryInsertedActivityId == snorkel.id)
            #expect(snorkel.diveSiteID == catalogSite.id)
            #expect(snorkel.resolvedLinkedSite?.siteName == "Salt Pier")
        }

        @Test @MainActor
        func snorkelActivityManualCreation_persist_createsAndLinksNewCatalogSite() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let profile = UserProfile(appleUserIdentifier: "manual-snorkel-new-site", displayName: "Snorkeler")
            context.insert(profile)
            try context.save()

            let draft = DiveSiteFormDraft(
                siteName: "Trunk Bay",
                country: "US Virgin Islands",
                region: "St. John",
                bodyOfWater: "",
                latitudeText: "18.35190",
                longitudeText: "-64.76820",
                waterType: .saltwater
            )
            let snorkel = SnorkelActivityManualCreation.makeBlankActivity()
            let outcome = SnorkelActivityManualCreation.persist(
                snorkel,
                siteSelection: .newSite(draft),
                modelContext: context,
                owner: profile
            )
            #expect(outcome.primaryInsertedActivityId == snorkel.id)
            #expect(snorkel.resolvedLinkedSite?.siteName == "Trunk Bay")
            #expect(snorkel.resolvedLinkedSite?.resolvedWaterType == .saltwater)
            #expect(try context.fetchCount(FetchDescriptor<DiveSite>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<UserDiveSite>()) == 1)
        }

        @Test @MainActor
        func snorkelActivityManualCreation_persist_insertsOwnedSnorkel() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let profile = UserProfile(appleUserIdentifier: "manual-snorkel-create-test", displayName: "Snorkeler")
            context.insert(profile)
            try context.save()

            let snorkel = SnorkelActivityManualCreation.makeBlankActivity()
            let outcome = SnorkelActivityManualCreation.persist(snorkel, modelContext: context, owner: profile)
            #expect(outcome.primaryInsertedActivityId == snorkel.id)
            #expect(outcome.userMessage.hasPrefix(SnorkelActivityManualCreation.successMessagePrefix))

            let stored = try SnorkelActivityOwnership.activities(forOwnerProfileID: profile.id, modelContext: context)
            #expect(stored.count == 1)
            #expect(stored.first?.source == .manual)
            #expect(stored.first?.sourceActivityId == nil)
            #expect(stored.first?.ownerProfileID == profile.id)
        }

        @Test @MainActor
        func snorkelActivityManualCreation_persist_rejectsImportedSource() throws {
            let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
            let context = ModelContext(container)
            let profile = UserProfile(appleUserIdentifier: "manual-snorkel-reject-fit", displayName: "Snorkeler")
            context.insert(profile)
            try context.save()

            let snorkel = SnorkelActivity(
                source: .garminMK3,
                sourceActivityId: "fit-snorkel-1",
                startTime: Date(),
                durationMinutes: 20
            )
            let outcome = SnorkelActivityManualCreation.persist(snorkel, modelContext: context, owner: profile)
            #expect(outcome.primaryInsertedActivityId == nil)
            #expect(try SnorkelActivityOwnership.activities(forOwnerProfileID: profile.id, modelContext: context).isEmpty)
        }
}
