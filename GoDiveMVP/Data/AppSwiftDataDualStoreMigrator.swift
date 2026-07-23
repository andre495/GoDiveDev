import Foundation
import SwiftData

enum AppSwiftDataDualStoreMigrationError: Error, LocalizedError {
    case copiedZeroDivesFromNonEmptyLegacy(legacyByteCount: UInt64)

    var errorDescription: String? {
        switch self {
        case .copiedZeroDivesFromNonEmptyLegacy(let bytes):
            return "Dual-store migration copied 0 dives from a legacy store (\(bytes) bytes)."
        }
    }
}

/// Copies rows from a unified SwiftData store into a dual-configuration container.
///
/// Destination inserts route by type into user / catalog / diagnostics stores. Business UUIDs
/// are preserved; SwiftData relationships are rewired after both ends exist.
enum AppSwiftDataDualStoreMigrator {

    struct Result: Equatable, Sendable {
        var catalogMarineLifeCount: Int = 0
        var catalogDiveSiteCount: Int = 0
        var diagnosticsCount: Int = 0
        var userProfileCount: Int = 0
        var diveActivityCount: Int = 0
        var snorkelActivityCount: Int = 0
        var totalInsertedCount: Int = 0

        nonisolated init(
            catalogMarineLifeCount: Int = 0,
            catalogDiveSiteCount: Int = 0,
            diagnosticsCount: Int = 0,
            userProfileCount: Int = 0,
            diveActivityCount: Int = 0,
            snorkelActivityCount: Int = 0,
            totalInsertedCount: Int = 0
        ) {
            self.catalogMarineLifeCount = catalogMarineLifeCount
            self.catalogDiveSiteCount = catalogDiveSiteCount
            self.diagnosticsCount = diagnosticsCount
            self.userProfileCount = userProfileCount
            self.diveActivityCount = diveActivityCount
            self.snorkelActivityCount = snorkelActivityCount
            self.totalInsertedCount = totalInsertedCount
        }
    }

    /// Opens the legacy unified on-disk store, migrates hybrid rows, copies into dual stores under
    /// **`dualRootDirectory`**, then renames the legacy store aside.
    @discardableResult
    nonisolated static func migrateLegacyUnifiedStoreToDual(dualRootDirectory: URL) throws -> Result {
        let legacyURL = AppSwiftDataDualStoreFactory.legacyUnifiedStoreURL()
        let legacySchema = Schema(AppSwiftDataStorePartition.allModelTypes)
        let legacyConfiguration = ModelConfiguration(
            schema: legacySchema,
            url: legacyURL,
            cloudKitDatabase: .none
        )
        let legacyContainer = try ModelContainer(for: legacySchema, configurations: [legacyConfiguration])
        let legacyContext = ModelContext(legacyContainer)
        try AppSwiftDataHybridRowMigration.migrateIfNeeded(modelContext: legacyContext)

        // Copy into local-only dual stores first; production reopen enables user CloudKit (Phase 2).
        let dualStores = try AppSwiftDataDualStoreFactory.makeOnDiskSplitContainer(
            rootDirectory: dualRootDirectory,
            enableUserCloudKitSync: false
        )
        let dualContext = ModelContext(dualStores.container)
        let legacyDiveCount = try legacyContext.fetchCount(FetchDescriptor<DiveActivity>())
        try? "legacyDiveFetchCount=\(legacyDiveCount)\n"
            .write(
                to: dualRootDirectory.appendingPathComponent("dual-migrate-debug.txt"),
                atomically: true,
                encoding: .utf8
            )
        let result = try migrate(from: legacyContext, to: dualContext)
        try dualContext.save()

        let legacyBytes = AppSwiftDataDualStoreFactory.legacyUnifiedStoreByteCount()
        try? [
            "legacyDiveFetchCount=\(legacyDiveCount)",
            "copiedDives=\(result.diveActivityCount)",
            "copiedProfiles=\(result.userProfileCount)",
            "totalInserted=\(result.totalInsertedCount)",
            "legacyBytes=\(legacyBytes)",
        ].joined(separator: "\n").write(
            to: dualRootDirectory.appendingPathComponent("dual-migrate-debug.txt"),
            atomically: true,
            encoding: .utf8
        )
        if result.diveActivityCount == 0, legacyBytes > 1_000_000 {
            throw AppSwiftDataDualStoreMigrationError.copiedZeroDivesFromNonEmptyLegacy(
                legacyByteCount: legacyBytes
            )
        }

        renameLegacyStoreAside(legacyURL)
        return result
    }

    /// Property-for-property copy between two contexts that share the full GoDive schema.
    @discardableResult
    nonisolated static func migrate(from source: ModelContext, to destination: ModelContext) throws -> Result {
        var result = Result()
        var profilesByID: [UUID: UserProfile] = [:]
        var divesByID: [UUID: DiveActivity] = [:]
        var buddiesByID: [UUID: DiveBuddy] = [:]
        var tripsByID: [UUID: DiveTrip] = [:]
        var equipmentByID: [UUID: EquipmentItem] = [:]
        var mediaByID: [UUID: DiveMediaPhoto] = [:]
        var equipmentListsByID: [UUID: DiveActivityEquipmentList] = [:]
        var activityTagsByID: [UUID: ActivityTag] = [:]
        var snorkelsByID: [UUID: SnorkelActivity] = [:]
        var snorkelMediaByID: [UUID: SnorkelMediaPhoto] = [:]

        // MARK: Catalog
        for species in try source.fetch(FetchDescriptor<MarineLife>()) {
            let copy = MarineLife(
                uuid: species.uuid,
                commonName: species.commonName,
                featureImageURL: species.featureImageURL,
                featureImageResourceName: species.featureImageResourceName,
                featureModelResourceName: species.featureModelResourceName,
                featureModelURL: species.featureModelURL,
                scientificName: species.scientificName,
                category: species.category,
                subcategory: species.subcategory,
                familyName: species.familyName,
                aboutText: species.aboutText,
                minSizeMeters: species.minSizeMeters,
                maxSizeMeters: species.maxSizeMeters,
                minDepthMeters: species.minDepthMeters,
                maxDepthMeters: species.maxDepthMeters,
                avgDepthMeters: species.avgDepthMeters,
                distinctiveFeatures: species.distinctiveFeatures,
                abundance: species.abundance,
                habitatBehavior: species.habitatBehavior,
                diverReaction: species.diverReaction
            )
            copy.ownershipRaw = species.ownershipRaw
            destination.insert(copy)
            result.catalogMarineLifeCount += 1
            result.totalInsertedCount += 1
        }

        for site in try source.fetch(FetchDescriptor<DiveSite>()) {
            let copy = DiveSite(
                id: site.id,
                siteName: site.siteName,
                country: site.country,
                region: site.region,
                bodyOfWater: site.bodyOfWater,
                latCoords: site.latCoords,
                longCoords: site.longCoords,
                timeZoneIdentifier: site.timeZoneIdentifier,
                timeZoneOffsetSeconds: site.timeZoneOffsetSeconds,
                siteTags: site.siteTags,
                siteRating: site.siteRating,
                entry: site.entry,
                environment: site.environment,
                maxDepthMeters: site.maxDepthMeters,
                waterType: site.waterType
            )
            copy.ownershipRaw = site.ownershipRaw
            destination.insert(copy)
            result.catalogDiveSiteCount += 1
            result.totalInsertedCount += 1
        }

        // MARK: Diagnostics
        for report in try source.fetch(FetchDescriptor<CrashReportRecord>()) {
            let copy = CrashReportRecord(
                id: report.id,
                capturedAt: report.capturedAt,
                kindRaw: report.kindRaw,
                reason: report.reason,
                appVersion: report.appVersion,
                osVersion: report.osVersion,
                details: report.details,
                sharedToCloudAt: report.sharedToCloudAt
            )
            destination.insert(copy)
            result.diagnosticsCount += 1
            result.totalInsertedCount += 1
        }

        // MARK: User roots
        for profile in try source.fetch(FetchDescriptor<UserProfile>()) {
            let copy = UserProfile(
                id: profile.id,
                appleUserIdentifier: profile.appleUserIdentifier,
                displayName: profile.displayName,
                profilePhoto: profile.profilePhoto,
                danInsuranceNumber: profile.danInsuranceNumber,
                doesScubaDiving: profile.doesScubaDiving,
                doesFreeDiving: profile.doesFreeDiving,
                doesSnorkeling: profile.doesSnorkeling,
                createdAt: profile.createdAt,
                lastSignedInAt: profile.lastSignedInAt
            )
            destination.insert(copy)
            profilesByID[copy.id] = copy
            result.userProfileCount += 1
            result.totalInsertedCount += 1
        }

        for cert in try source.fetch(FetchDescriptor<Certification>()) {
            let copy = Certification(
                id: cert.id,
                agency: cert.agency,
                certName: cert.certName,
                certNumber: cert.certNumber,
                dateAttained: cert.dateAttained,
                instructor: cert.instructor,
                instructorNumber: cert.instructorNumber,
                diveShop: cert.diveShop,
                diveShopNumber: cert.diveShopNumber,
                cardType: CertificationCardType(rawValue: cert.cardTypeRaw) ?? .certification,
                certFrontPicture: cert.certFrontPicture,
                certBackPicture: cert.certBackPicture,
                owner: (cert.ownerProfileID ?? cert.owner?.id).flatMap { profilesByID[$0] }
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for item in try source.fetch(FetchDescriptor<EquipmentItem>()) {
            let copy = EquipmentItem(
                id: item.id,
                manufacturer: item.manufacturer,
                model: item.model,
                type: item.type,
                gearType: item.gearType,
                isRetired: item.isRetired,
                autoAdd: item.autoAdd,
                purchaseDate: item.purchaseDate,
                purchasedShop: item.purchasedShop,
                price: item.price,
                serviceDate: item.serviceDate,
                nextServiceDate: item.nextServiceDate,
                serviceRecurrenceDays: item.serviceRecurrenceDays,
                serviceNotes: item.serviceNotes,
                notes: item.notes,
                equipmentPhoto: item.equipmentPhoto,
                owner: (item.ownerProfileID ?? item.owner?.id).flatMap { profilesByID[$0] }
            )
            destination.insert(copy)
            equipmentByID[copy.id] = copy
            result.totalInsertedCount += 1
        }

        for buddy in try source.fetch(FetchDescriptor<DiveBuddy>()) {
            let copy = DiveBuddy(
                id: buddy.id,
                displayName: buddy.displayName,
                profilePhoto: buddy.profilePhoto,
                contactsIdentifier: buddy.contactsIdentifier,
                owner: (buddy.ownerProfileID ?? buddy.owner?.id).flatMap { profilesByID[$0] }
            )
            copy.featuredTaggedMediaPhotoID = buddy.featuredTaggedMediaPhotoID
            destination.insert(copy)
            buddiesByID[copy.id] = copy
            result.totalInsertedCount += 1
        }

        for trip in try source.fetch(FetchDescriptor<DiveTrip>()) {
            let copy = DiveTrip(
                id: trip.id,
                startDate: trip.startDate,
                endDate: trip.endDate,
                countries: trip.countries,
                title: trip.title,
                plannedSiteIDs: trip.plannedSiteIDs,
                ownerProfileID: trip.ownerProfileID ?? trip.owner?.id,
                owner: (trip.ownerProfileID ?? trip.owner?.id).flatMap { profilesByID[$0] },
                createdAt: trip.createdAt,
                updatedAt: trip.updatedAt
            )
            copy.featuredTripMediaPhotoID = trip.featuredTripMediaPhotoID
            destination.insert(copy)
            tripsByID[copy.id] = copy
            result.totalInsertedCount += 1
        }

        for species in try source.fetch(FetchDescriptor<UserMarineLife>()) {
            let copy = UserMarineLife(
                uuid: species.uuid,
                commonName: species.commonName,
                featureImageURL: species.featureImageURL,
                featureImageResourceName: species.featureImageResourceName,
                featureModelResourceName: species.featureModelResourceName,
                scientificName: species.scientificName,
                category: species.category,
                subcategory: species.subcategory,
                familyName: species.familyName,
                aboutText: species.aboutText,
                minSizeMeters: species.minSizeMeters,
                maxSizeMeters: species.maxSizeMeters,
                minDepthMeters: species.minDepthMeters,
                maxDepthMeters: species.maxDepthMeters,
                avgDepthMeters: species.avgDepthMeters,
                distinctiveFeatures: species.distinctiveFeatures,
                abundance: species.abundance,
                habitatBehavior: species.habitatBehavior,
                diverReaction: species.diverReaction,
                owner: (species.ownerProfileID ?? species.owner?.id).flatMap { profilesByID[$0] },
                createdAt: species.createdAt,
                updatedAt: species.updatedAt
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for site in try source.fetch(FetchDescriptor<UserDiveSite>()) {
            let copy = UserDiveSite(
                id: site.id,
                siteName: site.siteName,
                country: site.country,
                region: site.region,
                bodyOfWater: site.bodyOfWater,
                latCoords: site.latCoords,
                longCoords: site.longCoords,
                timeZoneIdentifier: site.timeZoneIdentifier,
                timeZoneOffsetSeconds: site.timeZoneOffsetSeconds,
                siteTags: site.siteTags,
                siteRating: site.siteRating,
                entry: site.entry,
                environment: site.environment,
                maxDepthMeters: site.maxDepthMeters,
                waterType: site.waterType,
                owner: (site.ownerProfileID ?? site.owner?.id).flatMap { profilesByID[$0] },
                catalogDiveSiteID: site.catalogDiveSiteID,
                openDiveMapReferenceID: site.openDiveMapReferenceID,
                createdAt: site.createdAt,
                updatedAt: site.updatedAt
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for event in try source.fetch(FetchDescriptor<SecurityEventRecord>()) {
            let copy = SecurityEventRecord(
                id: event.id,
                capturedAt: event.capturedAt,
                kindRaw: event.kindRaw,
                detail: event.detail,
                appVersion: event.appVersion,
                osVersion: event.osVersion,
                ownerProfileID: event.ownerProfileID,
                sharedToCloudAt: event.sharedToCloudAt
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for record in try source.fetch(FetchDescriptor<MarineLifeUserRecord>()) {
            let copy = MarineLifeUserRecord(
                id: record.id,
                owner: (record.ownerProfileID ?? record.owner?.id).flatMap { profilesByID[$0] },
                marineLifeUUID: record.marineLifeUUID,
                isSighted: record.isSighted,
                activitiesSightedOn: record.activitiesSightedOn,
                sitesSightedOn: record.sitesSightedOn,
                userTaggedMedia: record.userTaggedMedia
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for tag in try source.fetch(FetchDescriptor<ActivityTag>()) {
            let copy = ActivityTag(
                id: tag.id,
                name: tag.name,
                normalizedName: tag.normalizedName,
                ownerProfileID: tag.ownerProfileID
            )
            destination.insert(copy)
            activityTagsByID[copy.id] = copy
            result.totalInsertedCount += 1
        }

        for dive in try source.fetch(FetchDescriptor<DiveActivity>()) {
            let ownerID = dive.ownerProfileID ?? dive.owner?.id
            let copy = cloneDiveActivity(dive, owner: ownerID.flatMap { profilesByID[$0] })
            destination.insert(copy)
            divesByID[copy.id] = copy
            result.diveActivityCount += 1
            result.totalInsertedCount += 1
        }

        for snorkel in try source.fetch(FetchDescriptor<SnorkelActivity>()) {
            let ownerID = snorkel.ownerProfileID ?? snorkel.owner?.id
            let copy = cloneSnorkelActivity(snorkel, owner: ownerID.flatMap { profilesByID[$0] })
            destination.insert(copy)
            snorkelsByID[copy.id] = copy
            result.snorkelActivityCount += 1
            result.totalInsertedCount += 1
        }

        // MARK: Dive children
        for media in try source.fetch(FetchDescriptor<DiveMediaPhoto>()) {
            let dive = media.diveActivityID.flatMap { divesByID[$0] } ?? media.dive.flatMap { divesByID[$0.id] }
            let copy = DiveMediaPhoto(
                id: media.id,
                sortOrder: media.sortOrder,
                mediaKind: DiveMediaKind(rawValue: media.mediaKind) ?? .image,
                capturedAt: media.capturedAt,
                photosLocalIdentifier: media.photosLocalIdentifier,
                photosCloudIdentifier: media.photosCloudIdentifier,
                fishialConfirmedSpeciesName: media.fishialConfirmedSpeciesName,
                previewJPEGData: media.previewJPEGData,
                dive: dive
            )
            destination.insert(copy)
            mediaByID[copy.id] = copy
            result.totalInsertedCount += 1
        }

        for media in try source.fetch(FetchDescriptor<SnorkelMediaPhoto>()) {
            let snorkel = media.snorkelActivityID.flatMap { snorkelsByID[$0] }
                ?? media.snorkelActivity.flatMap { snorkelsByID[$0.id] }
            let copy = SnorkelMediaPhoto(
                id: media.id,
                sortOrder: media.sortOrder,
                mediaKind: DiveMediaKind(rawValue: media.mediaKind) ?? .image,
                capturedAt: media.capturedAt,
                photosLocalIdentifier: media.photosLocalIdentifier,
                photosCloudIdentifier: media.photosCloudIdentifier,
                fishialConfirmedSpeciesName: media.fishialConfirmedSpeciesName,
                previewJPEGData: media.previewJPEGData,
                snorkelActivity: snorkel
            )
            destination.insert(copy)
            snorkelMediaByID[copy.id] = copy
            result.totalInsertedCount += 1
        }

        // Profile points: copy per dive with periodic saves (full-table fetch of 100k+ rows hangs launch).
        destination.autosaveEnabled = false
        var profilePointCount = 0
        for diveID in divesByID.keys {
            let targetDiveID = diveID
            let points = try source.fetch(
                FetchDescriptor<DiveProfilePoint>(
                    predicate: #Predicate { $0.diveActivityID == targetDiveID }
                )
            )
            for point in points {
                let copy = DiveProfilePoint(
                    timestamp: point.timestamp,
                    depthMeters: point.depthMeters,
                    temperatureCelsius: point.temperatureCelsius,
                    ascentRateMetersPerSecond: point.ascentRateMetersPerSecond,
                    ndlSeconds: point.ndlSeconds,
                    timeToSurfaceSeconds: point.timeToSurfaceSeconds,
                    tankPressurePSI: point.tankPressurePSI,
                    heartRateBPM: point.heartRateBPM,
                    po2Bars: point.po2Bars,
                    n2Load: point.n2Load,
                    cnsLoad: point.cnsLoad
                )
                copy.diveActivityID = diveID
                destination.insert(copy)
                result.totalInsertedCount += 1
                profilePointCount += 1
            }
            if destination.hasChanges {
                try destination.save()
            }
        }
        // Encode synced track blobs for dives that have local points but no profileTrackData yet.
        for (diveID, destDive) in divesByID {
            if destDive.profileTrackData != nil { continue }
            let points = try destination.fetch(
                FetchDescriptor<DiveProfilePoint>(
                    predicate: #Predicate { $0.diveActivityID == diveID }
                )
            )
            guard !points.isEmpty else { continue }
            destDive.profilePoints = points
            DiveProfilePointStore.syncTrackData(from: destDive)
        }
        // Snorkel GPS/HR samples: same per-activity batching as dive profile points.
        for snorkelID in snorkelsByID.keys {
            let targetSnorkelID = snorkelID
            let points = try source.fetch(
                FetchDescriptor<SnorkelProfilePoint>(
                    predicate: #Predicate { $0.snorkelActivityID == targetSnorkelID }
                )
            )
            for point in points {
                let copy = SnorkelProfilePoint(
                    timestamp: point.timestamp,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    heartRateBPM: point.heartRateBPM,
                    snorkelActivityID: snorkelID
                )
                destination.insert(copy)
                result.totalInsertedCount += 1
                profilePointCount += 1
            }
            if destination.hasChanges {
                try destination.save()
            }
        }
        for (snorkelID, destSnorkel) in snorkelsByID {
            if destSnorkel.swimTrackData != nil { continue }
            let points = try destination.fetch(
                FetchDescriptor<SnorkelProfilePoint>(
                    predicate: #Predicate { $0.snorkelActivityID == snorkelID }
                )
            )
            guard !points.isEmpty else { continue }
            destSnorkel.profilePoints = points
            SnorkelProfilePointStore.syncTrackData(from: destSnorkel)
        }

        if destination.hasChanges {
            try destination.save()
        }
        try? "profilePointsCopied=\(profilePointCount)\n"
            .write(
                to: FileManager.default.temporaryDirectory.appendingPathComponent("godive-migrate-points.txt"),
                atomically: true,
                encoding: .utf8
            )

        for list in try source.fetch(FetchDescriptor<DiveActivityEquipmentList>()) {
            let dive = list.diveActivityID.flatMap { divesByID[$0] } ?? list.dive.flatMap { divesByID[$0.id] }
            let copy = DiveActivityEquipmentList(
                id: list.id,
                diveActivityID: dive?.id,
                dive: dive
            )
            destination.insert(copy)
            equipmentListsByID[copy.id] = copy
            result.totalInsertedCount += 1
        }

        // MARK: Joins
        for entry in try source.fetch(FetchDescriptor<DiveEquipmentEntry>()) {
            let list = entry.equipmentList.flatMap { equipmentListsByID[$0.id] }
            let equipment = equipmentByID[entry.equipmentItemID] ?? entry.equipment.flatMap { equipmentByID[$0.id] }
            let copy = DiveEquipmentEntry(
                id: entry.id,
                equipmentItemID: entry.equipmentItemID,
                diveActivityID: entry.diveActivityID,
                equipment: equipment,
                equipmentList: list
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for tag in try source.fetch(FetchDescriptor<DiveBuddyTag>()) {
            guard let buddy = tag.buddyID.flatMap({ buddiesByID[$0] }) ?? tag.buddy.flatMap({ buddiesByID[$0.id] })
            else { continue }
            let dive = tag.diveActivityID.flatMap { divesByID[$0] } ?? tag.dive.flatMap { divesByID[$0.id] }
            let copy = DiveBuddyTag(id: tag.id, buddy: buddy, dive: dive)
            copy.legacyDisplayName = tag.legacyDisplayName
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for tag in try source.fetch(FetchDescriptor<SnorkelBuddyTag>()) {
            guard let buddy = tag.buddyID.flatMap({ buddiesByID[$0] }) ?? tag.buddy.flatMap({ buddiesByID[$0.id] })
            else { continue }
            let snorkel = tag.snorkelActivityID.flatMap { snorkelsByID[$0] }
                ?? tag.snorkelActivity.flatMap { snorkelsByID[$0.id] }
            let copy = SnorkelBuddyTag(id: tag.id, buddy: buddy, snorkelActivity: snorkel)
            copy.legacyDisplayName = tag.legacyDisplayName
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for tag in try source.fetch(FetchDescriptor<DiveMediaBuddyTag>()) {
            guard let buddy = tag.buddyID.flatMap({ buddiesByID[$0] }) ?? tag.buddy.flatMap({ buddiesByID[$0.id] })
            else { continue }
            let snorkelMedia = tag.snorkelMediaPhoto.flatMap { snorkelMediaByID[$0.id] }
                ?? tag.mediaPhotoID.flatMap { snorkelMediaByID[$0] }
            let snorkel = tag.snorkelActivityID.flatMap { snorkelsByID[$0] }
                ?? tag.snorkelActivity.flatMap { snorkelsByID[$0.id] }
            if let snorkelMedia, let snorkel {
                let copy = DiveMediaBuddyTag(
                    id: tag.id,
                    buddy: buddy,
                    snorkelMediaPhoto: snorkelMedia,
                    snorkelActivity: snorkel
                )
                destination.insert(copy)
                result.totalInsertedCount += 1
                continue
            }
            let media = tag.mediaPhotoID.flatMap { mediaByID[$0] } ?? tag.mediaPhoto.flatMap { mediaByID[$0.id] }
            let dive = tag.diveActivityID.flatMap { divesByID[$0] } ?? tag.diveActivity.flatMap { divesByID[$0.id] }
            let copy = DiveMediaBuddyTag(id: tag.id, buddy: buddy, mediaPhoto: media, diveActivity: dive)
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for sighting in try source.fetch(FetchDescriptor<SightingInstance>()) {
            let dive = sighting.diveActivityID.flatMap { divesByID[$0] }
                ?? sighting.diveActivity.flatMap { divesByID[$0.id] }
            let media = sighting.mediaPhotoID.flatMap { mediaByID[$0] }
                ?? sighting.mediaPhoto.flatMap { mediaByID[$0.id] }
            let snorkel = sighting.snorkelActivityID.flatMap { snorkelsByID[$0] }
                ?? sighting.snorkelActivity.flatMap { snorkelsByID[$0.id] }
            let snorkelMedia = sighting.snorkelMediaPhotoID.flatMap { snorkelMediaByID[$0] }
                ?? sighting.snorkelMediaPhoto.flatMap { snorkelMediaByID[$0.id] }
            let copy = SightingInstance(
                sightingUUID: sighting.sightingUUID,
                marineLifeUUID: sighting.marineLifeUUID,
                sightingDateTime: sighting.sightingDateTime,
                diveActivity: dive,
                snorkelActivity: snorkel,
                diveSiteID: sighting.diveSiteID,
                sightingDepthMeters: sighting.sightingDepthMeters,
                mediaPhoto: media,
                snorkelMediaPhoto: snorkelMedia
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for link in try source.fetch(FetchDescriptor<DiveTripActivityLink>()) {
            guard let trip = link.tripID.flatMap({ tripsByID[$0] }) ?? link.trip.flatMap({ tripsByID[$0.id] }),
                  let dive = link.diveActivityID.flatMap({ divesByID[$0] })
                    ?? link.diveActivity.flatMap({ divesByID[$0.id] })
            else { continue }
            let copy = DiveTripActivityLink(
                id: link.id,
                trip: trip,
                diveActivity: dive,
                linkedAt: link.linkedAt
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        for link in try source.fetch(FetchDescriptor<DiveTripBuddyLink>()) {
            guard let trip = link.tripID.flatMap({ tripsByID[$0] }) ?? link.trip.flatMap({ tripsByID[$0.id] }),
                  let buddy = link.buddyID.flatMap({ buddiesByID[$0] }) ?? link.buddy.flatMap({ buddiesByID[$0.id] })
            else { continue }
            let copy = DiveTripBuddyLink(
                id: link.id,
                trip: trip,
                buddy: buddy,
                addedAt: link.addedAt
            )
            destination.insert(copy)
            result.totalInsertedCount += 1
        }

        // ActivityTag ↔ DiveActivity many-to-many
        for sourceTag in try source.fetch(FetchDescriptor<ActivityTag>()) {
            guard let destTag = activityTagsByID[sourceTag.id] else { continue }
            let linked = sourceTag.dives.compactMap { divesByID[$0.id] }
            destTag.dives = linked
        }

        if destination.hasChanges {
            try destination.save()
        }
        return result
    }

    private nonisolated static func cloneDiveActivity(_ source: DiveActivity, owner: UserProfile?) -> DiveActivity {
        let copy = DiveActivity(
            id: source.id,
            source: source.source,
            sourceDiveId: source.sourceDiveId,
            startTime: source.startTime,
            timeZoneOffsetSeconds: source.timeZoneOffsetSeconds,
            durationMinutes: source.durationMinutes,
            maxDepthMeters: source.maxDepthMeters,
            averageDepthMeters: source.averageDepthMeters,
            bottomTimeSeconds: source.bottomTimeSeconds,
            surfaceIntervalSeconds: source.surfaceIntervalSeconds,
            diveNumber: source.diveNumber,
            diveNumberExplicitlyNone: source.diveNumberExplicitlyNone,
            waterTempAvgCelsius: source.waterTempAvgCelsius,
            waterTempMaxCelsius: source.waterTempMaxCelsius,
            waterTempMinCelsius: source.waterTempMinCelsius,
            avgAscentRateMetersPerSecond: source.avgAscentRateMetersPerSecond,
            siteName: source.siteName,
            locationName: source.locationName,
            entryCoordinate: source.entryCoordinate,
            diveSiteID: source.diveSiteID,
            notes: source.notes,
            diveCurrentStrength: source.diveCurrentStrength,
            surfaceCondition: source.surfaceCondition,
            entryType: source.entryType,
            diveVisibility: source.diveVisibility,
            diveOperatorName: source.diveOperatorName,
            diveMasterName: source.diveMasterName,
            diveSignatureData: source.diveSignatureData,
            diveWaterType: source.diveWaterType,
            diverWeightKilograms: source.diverWeightKilograms,
            tankMaterial: source.tankMaterial,
            tankVolumeDescription: source.tankVolumeDescription,
            tankPressureStartPSI: source.tankPressureStartPSI,
            tankPressureEndPSI: source.tankPressureEndPSI,
            gasType: source.gasType,
            oxygenMix: source.oxygenMix,
            avgSAC: source.avgSAC,
            avgRMV: source.avgRMV,
            rawImportVersion: source.rawImportVersion
        )
        copy.featuredMediaPhotoID = source.featuredMediaPhotoID
        copy.profileTrackData = source.profileTrackData
        copy.activityWeatherSnapshotData = source.activityWeatherSnapshotData
        copy.owner = owner
        copy.ownerProfileID = owner?.id ?? source.ownerProfileID
        return copy
    }

    private nonisolated static func cloneSnorkelActivity(
        _ source: SnorkelActivity,
        owner: UserProfile?
    ) -> SnorkelActivity {
        let copy = SnorkelActivity(
            id: source.id,
            source: source.source,
            sourceActivityId: source.sourceActivityId,
            startTime: source.startTime,
            timeZoneOffsetSeconds: source.timeZoneOffsetSeconds,
            durationMinutes: source.durationMinutes,
            swimDistanceMeters: source.swimDistanceMeters,
            totalCalories: source.totalCalories,
            avgHeartRateBPM: source.avgHeartRateBPM,
            maxHeartRateBPM: source.maxHeartRateBPM,
            avgTemperatureCelsius: source.avgTemperatureCelsius,
            avgMovingSpeedMetersPerSecond: source.avgMovingSpeedMetersPerSecond,
            maxDepthMeters: source.maxDepthMeters,
            entryCoordinate: source.entryCoordinate,
            rawImportVersion: source.rawImportVersion
        )
        copy.siteName = source.siteName
        copy.locationName = source.locationName
        copy.diveSiteID = source.diveSiteID
        copy.notes = source.notes
        copy.featuredMediaPhotoID = source.featuredMediaPhotoID
        copy.swimTrackData = source.swimTrackData
        copy.activityWeatherSnapshotData = source.activityWeatherSnapshotData
        copy.owner = owner
        copy.ownerProfileID = owner?.id ?? source.ownerProfileID
        return copy
    }

    private nonisolated static func renameLegacyStoreAside(_ url: URL) {
        let fm = FileManager.default
        let bak = URL(fileURLWithPath: url.path + ".migrated-bak")
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            let dest = URL(fileURLWithPath: bak.path + suffix)
            guard fm.fileExists(atPath: source.path) else { continue }
            try? fm.removeItem(at: dest)
            try? fm.moveItem(at: source, to: dest)
        }
    }

    /// Visible to bootstrap when dual already has content but the legacy rename was skipped.
    nonisolated static func renameLegacyStoreAsideForBootstrap(_ url: URL) {
        renameLegacyStoreAside(url)
    }

    /// Copies a parked pre–CloudKit **`GoDiveUser`** bak (policy rename-aside) into a fresh split container.
    ///
    /// Catalog / diagnostics reseed from bundled sources; only the user store bak is required.
    /// Profile points land in **`GoDiveUserLocal`** via the destination schema partition.
    @discardableResult
    nonisolated static func migrateFromParkedPreCloudKitUserStore(
        rootDirectory: URL,
        destinationContainer: ModelContainer,
        policyVersion: Int
    ) throws -> Result {
        let stamp = "pre-cloudkit-v\(policyVersion)"
        let userBase = AppSwiftDataDualStoreFactory.storeURL(
            named: AppSwiftDataDualStoreFactory.userStoreName,
            rootDirectory: rootDirectory
        )
        let parkedUserURL = URL(fileURLWithPath: userBase.path + ".\(stamp)")
        guard FileManager.default.fileExists(atPath: parkedUserURL.path) else {
            return Result()
        }

        let legacySchema = Schema(AppSwiftDataStorePartition.legacyCloudKitUserModelTypes)
        let sourceConfiguration = ModelConfiguration(
            "GoDiveUserParkedPreCloudKit",
            schema: legacySchema,
            url: parkedUserURL,
            cloudKitDatabase: .none
        )
        let sourceContainer = try ModelContainer(for: legacySchema, configurations: [sourceConfiguration])
        let sourceContext = ModelContext(sourceContainer)
        let destinationContext = ModelContext(destinationContainer)
        let result = try migrate(from: sourceContext, to: destinationContext)
        try destinationContext.save()
        return result
    }
}
