//
//  SwiftDataInfrastructureTests.swift
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


struct SwiftDataInfrastructureTests {
        @Test func mockDataSeeding_launchSeedingDisabledByDefault() {
            #expect(!MockDataSeeding.isLaunchSeedingEnabled)
            #expect(GoDiveReleaseConfigurationGates.isLaunchSeedingDisabled)
            #expect(GoDiveReleaseConfigurationGates.criticalStaticGatesPass)
        }

            @Test func ontologySightingContributionSync_gateRespectsOptOutAndStableContributionId() throws {
                let suiteName = "GoDiveOntologySyncGate-\(UUID().uuidString)"
                let defaults = try #require(UserDefaults(suiteName: suiteName))
                defer { defaults.removePersistentDomain(forName: suiteName) }

                // Default on, but still soft-fail closed without Firebase Auth.
                #expect(AppUserSettings.contributeCommunitySightings(userDefaults: defaults))
                #expect(!OntologySightingContributionSync.shouldContribute(userDefaults: defaults))

                defaults.set(false, forKey: AppUserSettings.contributeCommunitySightingsKey)
                #expect(!AppUserSettings.contributeCommunitySightings(userDefaults: defaults))
                #expect(!OntologySightingContributionSync.shouldContribute(userDefaults: defaults))

                defaults.set(true, forKey: AppUserSettings.contributeCommunitySightingsKey)
                // Preference alone is insufficient without Firebase Auth — soft-fail closed.
                #expect(!OntologySightingContributionSync.shouldContribute(userDefaults: defaults))

                let first = OntologySightingContributionSync.contributionId(
                    forSightingUUID: "sighting-a",
                    userDefaults: defaults
                )
                let second = OntologySightingContributionSync.contributionId(
                    forSightingUUID: "sighting-a",
                    userDefaults: defaults
                )
                let other = OntologySightingContributionSync.contributionId(
                    forSightingUUID: "sighting-b",
                    userDefaults: defaults
                )
                #expect(first == second)
                #expect(first != other)
                #expect(!first.isEmpty)
            }
            @Test func ontologySightingContributionSync_chunkedBatches_respectsFirestoreLimit() {
                #expect(OntologySightingContributionSync.firestoreBatchMaxOps == 400)
                #expect(OntologySightingContributionSync.chunkedBatches([Int]()).isEmpty)
                #expect(OntologySightingContributionSync.chunkedBatches([1, 2, 3], size: 2) == [[1, 2], [3]])
                let items = Array(0 ..< 801)
                let chunks = OntologySightingContributionSync.chunkedBatches(items)
                #expect(chunks.count == 3)
                #expect(chunks[0].count == 400)
                #expect(chunks[1].count == 400)
                #expect(chunks[2].count == 1)
                #expect(chunks.flatMap { $0 } == items)
            }
            @Test @MainActor func ontologySightingContributionSync_ownedStagingWrites_filtersByOwner() throws {
                let suiteName = "GoDiveOntologyOwnedWrites-\(UUID().uuidString)"
                let defaults = try #require(UserDefaults(suiteName: suiteName))
                defer { defaults.removePersistentDomain(forName: suiteName) }

                let container = try AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true)
                let context = container.mainContext
                let owner = UserProfile(appleUserIdentifier: "owner-ontology-batch", displayName: "Pat")
                let other = UserProfile(appleUserIdentifier: "other-ontology-batch", displayName: "Other")
                let ownedDive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 2_300_000),
                    durationMinutes: 40,
                    maxDepthMeters: 12
                )
                ownedDive.owner = owner
                ownedDive.ownerProfileID = owner.id
                let otherDive = DiveActivity(
                    source: .manual,
                    startTime: Date(timeIntervalSince1970: 2_300_100),
                    durationMinutes: 30,
                    maxDepthMeters: 10
                )
                otherDive.owner = other
                otherDive.ownerProfileID = other.id
                context.insert(owner)
                context.insert(other)
                context.insert(ownedDive)
                context.insert(otherDive)

                let ownedSighting = SightingInstance(
                    sightingUUID: "owned-sighting-1",
                    marineLifeUUID: "marine-life-french-angelfish",
                    sightingDateTime: ownedDive.startTime,
                    diveActivity: ownedDive,
                    sightingDepthMeters: 8
                )
                let otherSighting = SightingInstance(
                    sightingUUID: "other-sighting-1",
                    marineLifeUUID: "marine-life-queen-angelfish",
                    sightingDateTime: otherDive.startTime,
                    diveActivity: otherDive,
                    sightingDepthMeters: 6
                )
                context.insert(ownedSighting)
                context.insert(otherSighting)
                try context.save()

                let writes = OntologySightingContributionSync.ownedStagingWrites(
                    ownerProfileID: owner.id,
                    modelContext: context,
                    userDefaults: defaults
                )
                #expect(writes.count == 1)
                #expect(writes[0].documentID == "owned-sighting-1")
                #expect(writes[0].payload.marineLifeUUID == "marine-life-french-angelfish")
                #expect(writes[0].payload.status == "active")
                #expect(writes[0].payload.activityKind == "dive")
            }
}
