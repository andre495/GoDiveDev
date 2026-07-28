import Foundation
import os
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftData

/// Mirrors friend-visible dive projections to Firestore for accepted friends.
enum GoDiveSharedDiveProjectionSync: Sendable {
    nonisolated private static let log = Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "FriendShareSync")

    @MainActor
    static func shareOptions(userDefaults: UserDefaults = .standard) -> GoDiveSharedDiveProjectionMapping.ShareOptions {
        GoDiveSharedDiveProjectionMapping.ShareOptions(
            includeNotes: AppUserSettings.shareNotesWithFriends(userDefaults: userDefaults),
            includeMedia: AppUserSettings.shareMediaWithFriends(userDefaults: userDefaults)
        )
    }

    /// Whether the owner should publish projections right now.
    @MainActor
    static func shouldPublishProjections(
        userDefaults: UserDefaults = .standard,
        assumeHasFriends: Bool = false
    ) async -> Bool {
        guard AppUserSettings.shareDivesWithFriends(userDefaults: userDefaults) else { return false }
        if assumeHasFriends { return true }
        return await GoDiveFriendGraphService.hasAnyFriends()
    }

    @MainActor
    static func republishAllOwnedDives(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard,
        assumeHasFriends: Bool = false
    ) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        let shouldPublish = await shouldPublishProjections(
            userDefaults: userDefaults,
            assumeHasFriends: assumeHasFriends
        )
        if !shouldPublish {
            await deleteAllSharedDivesForCurrentUser()
            return
        }

        let dives = (try? modelContext.fetch(FetchDescriptor<DiveActivity>()))?
            .filter { $0.ownerProfileID == ownerProfileID } ?? []
        let options = shareOptions(userDefaults: userDefaults)

        for dive in dives {
            ensureProfileTrackBlob(for: dive, modelContext: modelContext)
        }

        for dive in dives {
            await upsertDive(
                dive,
                ownerUID: uid,
                options: options,
                modelContext: modelContext
            )
        }

        let snorkels = (try? modelContext.fetch(FetchDescriptor<SnorkelActivity>()))?
            .filter { $0.ownerProfileID == ownerProfileID } ?? []
        for snorkel in snorkels {
            ensureSwimTrackBlob(for: snorkel, modelContext: modelContext)
        }
        for snorkel in snorkels {
            await upsertSnorkel(
                snorkel,
                ownerUID: uid,
                options: options,
                modelContext: modelContext
            )
        }
    }

    @MainActor
    static func upsertDive(
        _ dive: DiveActivity,
        ownerUID: String? = nil,
        options: GoDiveSharedDiveProjectionMapping.ShareOptions? = nil,
        modelContext: ModelContext
    ) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard await shouldPublishProjections() else { return }
        guard let uid = ownerUID ?? Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        let shareOptions = options ?? shareOptions()
        var mediaPreviews: [GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot] = []
        if shareOptions.includeMedia {
            mediaPreviews = await uploadMediaPreviewsIfNeeded(dive: dive, ownerUID: uid)
        }

        let snapshot = makeSnapshot(
            from: dive,
            mediaPreviews: mediaPreviews,
            modelContext: modelContext
        )
        let fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: shareOptions
        )

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .document(dive.id.uuidString)
                .setData(fields, merge: true)
        } catch {
            GoDiveSecurityEvent.record(.friendShareSyncFailed, detail: "upsert")
            log.error("Shared dive upsert failed: \(String(describing: error), privacy: .private)")
        }
    }

    @MainActor
    static func upsertSnorkel(
        _ snorkel: SnorkelActivity,
        ownerUID: String? = nil,
        options: GoDiveSharedDiveProjectionMapping.ShareOptions? = nil,
        modelContext: ModelContext
    ) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard await shouldPublishProjections() else { return }
        guard let uid = ownerUID ?? Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        let shareOptions = options ?? shareOptions()
        let snapshot = makeSnorkelSnapshot(from: snorkel, modelContext: modelContext)
        let fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: shareOptions
        )

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .document(snorkel.id.uuidString)
                .setData(fields, merge: true)
        } catch {
            GoDiveSecurityEvent.record(.friendShareSyncFailed, detail: "upsertSnorkel")
            log.error("Shared snorkel upsert failed: \(String(describing: error), privacy: .private)")
        }
    }

    @MainActor
    static func deleteActivityProjection(activityID: UUID) async {
        await deleteDiveProjection(diveID: activityID)
    }

    @MainActor
    static func deleteDiveProjection(diveID: UUID) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .document(diveID.uuidString)
                .delete()
            await GoDiveSharedMediaStorage.deleteAllPreviews(ownerUID: uid, diveID: diveID)
        } catch {
            log.error("Shared dive delete failed: \(String(describing: error), privacy: .private)")
        }
    }

    @MainActor
    static func deleteAllSharedDivesForCurrentUser() async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("users").document(uid)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .getDocuments()
            for doc in snap.documents {
                try await doc.reference.delete()
            }
            await GoDiveSharedMediaStorage.deleteAllForOwner(ownerUID: uid)
        } catch {
            log.error("Shared dives wipe failed: \(String(describing: error), privacy: .private)")
        }
    }

    @MainActor
    static func fetchBuddyFeedSnapshot() async -> (
        friends: [GoDiveFriendGraphService.FriendEdge],
        rows: [LogbookBuddyFeedPresentation.Row]
    ) {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return ([], []) }
        guard Auth.auth().currentUser != nil else { return ([], []) }

        let friends: [GoDiveFriendGraphService.FriendEdge]
        do {
            friends = try await GoDiveFriendGraphService.listFriendEdges()
        } catch {
            log.error("Buddy feed friend list failed: \(String(describing: error), privacy: .private)")
            return ([], [])
        }

        var divesByFriendUID: [String: [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]] = [:]
        divesByFriendUID.reserveCapacity(friends.count)
        await withTaskGroup(of: (String, [GoDiveSharedDiveProjectionMapping.FriendVisibleDive]).self) { group in
            for friend in friends {
                let friendUID = friend.friendUID
                group.addTask {
                    let dives = await fetchFriendSharedDives(friendUID: friendUID)
                    return (friendUID, dives)
                }
            }
            for await (uid, dives) in group {
                divesByFriendUID[uid] = dives
            }
        }
        let rows = LogbookBuddyFeedPresentation.rows(friends: friends, divesByFriendUID: divesByFriendUID)
        return (friends, rows)
    }

    @MainActor
    static func fetchBuddyFeedRows() async -> [LogbookBuddyFeedPresentation.Row] {
        await fetchBuddyFeedSnapshot().rows
    }

    nonisolated static func fetchFriendSharedDives(friendUID: String) async -> [GoDiveSharedDiveProjectionMapping.FriendVisibleDive] {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return [] }
        guard Auth.auth().currentUser != nil else { return [] }
        let trimmed = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        do {
            let snap = try await Firestore.firestore()
                .collection("users")
                .document(trimmed)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .order(by: "startTime", descending: true)
                .getDocuments()
            let dives = snap.documents.map {
                GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(id: $0.documentID, data: $0.data())
            }
            return LogbookBuddyFeedPresentation.sortFriendVisibleDivesNewestFirst(dives)
        } catch {
            log.error("Friend shared dives fetch failed: \(String(describing: error), privacy: .private)")
            return []
        }
    }

    @MainActor
    private static func makeSnapshot(
        from dive: DiveActivity,
        mediaPreviews: [GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot],
        modelContext: ModelContext
    ) -> GoDiveSharedDiveProjectionMapping.DiveSnapshot {
        let tagNames = dive.activityTags.map(\.name).filter { !$0.isEmpty }
        let buddies: [GoDiveSharedDiveProjectionMapping.TaggedBuddySnapshot] = dive.buddies.compactMap { tag in
            guard let buddy = tag.buddy else { return nil }
            let name = buddy.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return .init(displayName: name, firebaseUID: buddy.linkedFirebaseUID)
        }
        let sightings: [GoDiveSharedDiveProjectionMapping.SightingSnapshot] = dive.marineLifeSightings.map { sighting in
            let catalogID = sighting.marineLifeUUID.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(
                commonName: catalogID.isEmpty ? "Species" : catalogID,
                scientificName: nil,
                catalogUUID: catalogID.isEmpty ? nil : catalogID
            )
        }
        let equipment = dive.equipmentList?.entries.compactMap { entry -> String? in
            guard let item = entry.equipment else { return nil }
            let manufacturer = item.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let model = item.model.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = [manufacturer, model].filter { !$0.isEmpty }.joined(separator: " ")
            return label.isEmpty ? nil : label
        } ?? []

        let place = regionCountryFields(
            linkedSite: dive.resolvedLinkedSite,
            locationName: dive.locationName
        )

        return GoDiveSharedDiveProjectionMapping.DiveSnapshot(
            id: dive.id,
            activityKind: .scubaDive,
            startTime: dive.startTime,
            timeZoneOffsetSeconds: dive.timeZoneOffsetSeconds,
            durationMinutes: dive.durationMinutes,
            maxDepthMeters: dive.maxDepthMeters,
            averageDepthMeters: dive.averageDepthMeters,
            bottomTimeSeconds: dive.bottomTimeSeconds,
            diveNumber: dive.diveNumber,
            waterTempAvgCelsius: dive.waterTempAvgCelsius,
            waterTempMinCelsius: dive.waterTempMinCelsius,
            waterTempMaxCelsius: dive.waterTempMaxCelsius,
            siteName: dive.siteName,
            locationName: dive.locationName,
            region: place.region,
            country: place.country,
            swimDistanceMeters: nil,
            entryLatitude: dive.entryLatitude,
            entryLongitude: dive.entryLongitude,
            notes: dive.notes,
            diveCurrentStrengthRaw: dive.diveCurrentStrengthRaw,
            surfaceCondition: dive.surfaceCondition,
            entryType: dive.entryType,
            diveVisibilityRaw: dive.diveVisibilityRaw,
            diveOperatorName: dive.diveOperatorName,
            diveMasterName: dive.diveMasterName,
            diveWaterTypeRaw: dive.diveWaterTypeRaw,
            diverWeightKilograms: dive.diverWeightKilograms,
            tankMaterial: dive.tankMaterial,
            tankVolumeDescription: dive.tankVolumeDescription,
            tankPressureStartPSI: dive.tankPressureStartPSI,
            tankPressureEndPSI: dive.tankPressureEndPSI,
            gasType: dive.gasType,
            oxygenMix: dive.oxygenMix,
            avgSAC: dive.avgSAC,
            avgRMV: dive.avgRMV,
            activityTagNames: tagNames,
            sightings: sightings,
            taggedBuddies: buddies,
            equipmentSummary: equipment,
            profileTrackData: resolvedProfileTrackData(for: dive, modelContext: modelContext),
            swimTrackData: nil,
            mediaPreviews: mediaPreviews,
            featuredMediaPhotoID: DiveActivityMediaPresentation.featuredPhotoID(on: dive)?.uuidString
        )
    }

    @MainActor
    private static func makeSnorkelSnapshot(
        from snorkel: SnorkelActivity,
        modelContext: ModelContext
    ) -> GoDiveSharedDiveProjectionMapping.DiveSnapshot {
        let place = regionCountryFields(
            linkedSite: snorkel.resolvedLinkedSite,
            locationName: snorkel.locationName
        )

        return GoDiveSharedDiveProjectionMapping.DiveSnapshot(
            id: snorkel.id,
            activityKind: .snorkel,
            startTime: snorkel.startTime,
            timeZoneOffsetSeconds: snorkel.timeZoneOffsetSeconds,
            durationMinutes: snorkel.durationMinutes,
            maxDepthMeters: snorkel.maxDepthMeters ?? 0,
            averageDepthMeters: nil,
            bottomTimeSeconds: nil,
            diveNumber: nil,
            waterTempAvgCelsius: snorkel.avgTemperatureCelsius,
            waterTempMinCelsius: nil,
            waterTempMaxCelsius: nil,
            siteName: snorkel.siteName,
            locationName: snorkel.locationName,
            region: place.region,
            country: place.country,
            swimDistanceMeters: snorkel.swimDistanceMeters,
            entryLatitude: snorkel.entryLatitude,
            entryLongitude: snorkel.entryLongitude,
            notes: snorkel.notes,
            diveCurrentStrengthRaw: nil,
            surfaceCondition: nil,
            entryType: nil,
            diveVisibilityRaw: nil,
            diveOperatorName: nil,
            diveMasterName: nil,
            diveWaterTypeRaw: nil,
            diverWeightKilograms: nil,
            tankMaterial: nil,
            tankVolumeDescription: nil,
            tankPressureStartPSI: nil,
            tankPressureEndPSI: nil,
            gasType: nil,
            oxygenMix: nil,
            avgSAC: nil,
            avgRMV: nil,
            activityTagNames: [],
            sightings: [],
            taggedBuddies: [],
            equipmentSummary: [],
            profileTrackData: nil,
            swimTrackData: resolvedSwimTrackData(for: snorkel, modelContext: modelContext),
            mediaPreviews: []
        )
    }

    @MainActor
    private static func ensureProfileTrackBlob(
        for dive: DiveActivity,
        modelContext: ModelContext
    ) {
        let hadTrack = !(dive.profileTrackData?.isEmpty ?? true)
        guard let encoded = try? DiveProfilePointStore.profileTrackDataForSharing(
            activity: dive,
            modelContext: modelContext
        ), !encoded.isEmpty else { return }
        if !hadTrack {
            try? modelContext.save()
        }
    }

    @MainActor
    private static func resolvedProfileTrackData(
        for dive: DiveActivity,
        modelContext: ModelContext
    ) -> Data? {
        ensureProfileTrackBlob(for: dive, modelContext: modelContext)
        return dive.profileTrackData
    }

    @MainActor
    private static func ensureSwimTrackBlob(
        for snorkel: SnorkelActivity,
        modelContext: ModelContext
    ) {
        let hadTrack = !(snorkel.swimTrackData?.isEmpty ?? true)
        guard let encoded = try? SnorkelProfilePointStore.swimTrackDataForSharing(
            activity: snorkel,
            modelContext: modelContext
        ), !encoded.isEmpty else { return }
        if !hadTrack {
            try? modelContext.save()
        }
    }

    @MainActor
    private static func resolvedSwimTrackData(
        for snorkel: SnorkelActivity,
        modelContext: ModelContext
    ) -> Data? {
        ensureSwimTrackBlob(for: snorkel, modelContext: modelContext)
        return snorkel.swimTrackData
    }

    @MainActor
    private static func regionCountryFields(
        linkedSite: DiveLinkedSiteResolver.ResolvedSite?,
        locationName: String?
    ) -> (region: String?, country: String?) {
        if let linkedSite {
            let region = linkedSite.region.trimmingCharacters(in: .whitespacesAndNewlines)
            let country = linkedSite.country.trimmingCharacters(in: .whitespacesAndNewlines)
            if !region.isEmpty || !country.isEmpty {
                return (
                    region.isEmpty ? nil : region,
                    country.isEmpty ? nil : country
                )
            }
        }
        let fields = DiveImportedLocationParsing.placeFields(fromLocationName: locationName)
        let region = fields.region.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = DiveSiteCountryPresentation.canonicalDisplayName(
            for: fields.country.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return (
            region.isEmpty ? nil : region,
            country.isEmpty ? nil : country
        )
    }

    @MainActor
    private static func uploadMediaPreviewsIfNeeded(
        dive: DiveActivity,
        ownerUID: String
    ) async -> [GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot] {
        let sortedPhotos = DiveActivityMediaPresentation.sortedPhotos(on: dive)
        let featuredID = DiveActivityMediaPresentation.featuredPhotoID(on: dive)
        let uploadOrder: [DiveMediaPhoto]
        if let featuredID,
           let featured = sortedPhotos.first(where: { $0.id == featuredID }) {
            uploadOrder = [featured] + sortedPhotos.filter { $0.id != featuredID }
        } else {
            uploadOrder = sortedPhotos
        }

        var results: [GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot] = []
        for photo in uploadOrder {
            guard let jpeg = photo.previewJPEGData, !jpeg.isEmpty else { continue }
            if let url = await GoDiveSharedMediaStorage.uploadPreview(
                ownerUID: ownerUID,
                diveID: dive.id,
                photoID: photo.id,
                jpegData: jpeg
            ) {
                results.append(.init(photoID: photo.id.uuidString, previewURL: url))
            }
        }
        return results
    }
}
