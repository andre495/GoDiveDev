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
            notesText: nil,
            includeMedia: AppUserSettings.shareMediaWithFriends(userDefaults: userDefaults),
            selectedMediaIDs: []
        )
    }

    @MainActor
    static func shareOptions(
        for dive: DiveActivity,
        userDefaults: UserDefaults = .standard
    ) -> GoDiveSharedDiveProjectionMapping.ShareOptions {
        ActivityFriendShareConfiguration.shareOptions(for: dive, userDefaults: userDefaults)
    }

    @MainActor
    static func shareOptions(
        for snorkel: SnorkelActivity,
        userDefaults: UserDefaults = .standard
    ) -> GoDiveSharedDiveProjectionMapping.ShareOptions {
        ActivityFriendShareConfiguration.shareOptions(for: snorkel, userDefaults: userDefaults)
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

        for dive in dives {
            ensureProfileTrackBlob(for: dive, modelContext: modelContext)
        }

        for dive in dives {
            if ActivityFriendShareConfiguration.shouldPublish(dive: dive, userDefaults: userDefaults) {
                _ = await upsertDive(
                    dive,
                    ownerUID: uid,
                    options: shareOptions(for: dive, userDefaults: userDefaults),
                    modelContext: modelContext
                )
            } else {
                await deleteDiveProjection(diveID: dive.id)
            }
        }

        let snorkels = (try? modelContext.fetch(FetchDescriptor<SnorkelActivity>()))?
            .filter { $0.ownerProfileID == ownerProfileID } ?? []
        for snorkel in snorkels {
            ensureSwimTrackBlob(for: snorkel, modelContext: modelContext)
        }
        for snorkel in snorkels {
            if ActivityFriendShareConfiguration.shouldPublish(snorkel: snorkel, userDefaults: userDefaults) {
                _ = await upsertSnorkel(
                    snorkel,
                    ownerUID: uid,
                    options: shareOptions(for: snorkel, userDefaults: userDefaults),
                    modelContext: modelContext
                )
            } else {
                await deleteDiveProjection(diveID: snorkel.id)
            }
        }
    }

    @MainActor
    static func upsertDive(
        _ dive: DiveActivity,
        ownerUID: String? = nil,
        options: GoDiveSharedDiveProjectionMapping.ShareOptions? = nil,
        modelContext: ModelContext
    ) async -> Bool {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard let uid = ownerUID ?? Auth.auth().currentUser?.uid, !uid.isEmpty else { return false }

        guard ActivityFriendShareConfiguration.shouldPublish(dive: dive) else {
            await deleteDiveProjection(diveID: dive.id, ownerUID: uid)
            return true
        }

        guard await shouldPublishProjections() else { return false }

        let shareOptions = options ?? shareOptions(for: dive)
        for photo in dive.mediaPhotos {
            DiveMediaLibraryIdentifierRepair.resolveLocalIdentifierIfNeeded(
                for: photo,
                modelContext: modelContext
            )
        }
        var mediaItems: [GoDiveSharedDiveProjectionMapping.MediaItemSnapshot] = []
        if shareOptions.includeMedia {
            mediaItems = await GoDiveSharedMediaUpload.uploadMediaItems(
                activityID: dive.id,
                on: dive,
                ownerUID: uid,
                selectedMediaIDs: shareOptions.selectedMediaIDs,
                restrictsToExplicitSelection: shareOptions.restrictsMediaToExplicitSelection
            )
        } else {
            await GoDiveSharedMediaUpload.clearActivityMedia(ownerUID: uid, activityID: dive.id)
        }

        let snapshot = makeSnapshot(
            from: dive,
            mediaItems: mediaItems,
            modelContext: modelContext
        )
        var fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: shareOptions
        )
        applyOptOutFieldDeletes(to: &fields, options: shareOptions)

        let projectionRef = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(dive.id.uuidString)

        do {
            let existingProjection = try await projectionRef.getDocument()
            try await projectionRef.setData(fields, merge: true)
            await GoDiveSharedMediaUpload.syncFirestoreMediaItemsFromPublishStateIfProjectionExists(
                ownerUID: uid,
                activityID: dive.id
            )
            // One push per activity: only on first projection create, and never again after
            // a signal was recorded (media/notes republishes must not re-notify).
            if GoDiveBuddyActivityPushSignalSync.shouldRecordPushSignal(
                projectionAlreadyExisted: existingProjection.exists,
                pushSignalAlreadyRecorded: dive.friendSharePushSignalRecorded
            ) {
                let recorded = await GoDiveBuddyActivityPushSignalSync.recordFirstShareIfNeeded(
                    ownerUID: uid,
                    activityID: dive.id,
                    activityKind: snapshot.activityKind,
                    startTime: dive.startTime,
                    taggedBuddies: GoDiveSharedDiveProjectionMapping.taggedBuddiesFirestoreRows(
                        from: snapshot.taggedBuddies
                    )
                )
                if recorded {
                    dive.friendSharePushSignalRecorded = true
                    try? modelContext.save()
                }
            }
            return true
        } catch {
            GoDiveSecurityEvent.record(.friendShareSyncFailed, detail: "upsert")
            log.error("Shared dive upsert failed: \(String(describing: error), privacy: .private)")
            return false
        }
    }

    @MainActor
    static func upsertSnorkel(
        _ snorkel: SnorkelActivity,
        ownerUID: String? = nil,
        options: GoDiveSharedDiveProjectionMapping.ShareOptions? = nil,
        modelContext: ModelContext
    ) async -> Bool {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard let uid = ownerUID ?? Auth.auth().currentUser?.uid, !uid.isEmpty else { return false }

        guard ActivityFriendShareConfiguration.shouldPublish(snorkel: snorkel) else {
            await deleteDiveProjection(diveID: snorkel.id, ownerUID: uid)
            return true
        }

        guard await shouldPublishProjections() else { return false }

        let shareOptions = options ?? shareOptions(for: snorkel)
        for photo in snorkel.mediaPhotos {
            SnorkelMediaLibraryIdentifierRepair.resolveLocalIdentifierIfNeeded(
                for: photo,
                modelContext: modelContext
            )
        }
        var mediaItems: [GoDiveSharedDiveProjectionMapping.MediaItemSnapshot] = []
        if shareOptions.includeMedia {
            mediaItems = await GoDiveSharedMediaUpload.uploadMediaItems(
                activityID: snorkel.id,
                on: snorkel,
                ownerUID: uid,
                selectedMediaIDs: shareOptions.selectedMediaIDs,
                restrictsToExplicitSelection: shareOptions.restrictsMediaToExplicitSelection
            )
        } else {
            await GoDiveSharedMediaUpload.clearActivityMedia(ownerUID: uid, activityID: snorkel.id)
        }

        let snapshot = makeSnorkelSnapshot(
            from: snorkel,
            mediaItems: mediaItems,
            modelContext: modelContext
        )
        var fields = GoDiveSharedDiveProjectionMapping.projectionFields(
            from: snapshot,
            options: shareOptions
        )
        applyOptOutFieldDeletes(to: &fields, options: shareOptions)

        let projectionRef = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
            .document(snorkel.id.uuidString)

        do {
            let existingProjection = try await projectionRef.getDocument()
            try await projectionRef.setData(fields, merge: true)
            await GoDiveSharedMediaUpload.syncFirestoreMediaItemsFromPublishStateIfProjectionExists(
                ownerUID: uid,
                activityID: snorkel.id
            )
            if GoDiveBuddyActivityPushSignalSync.shouldRecordPushSignal(
                projectionAlreadyExisted: existingProjection.exists,
                pushSignalAlreadyRecorded: snorkel.friendSharePushSignalRecorded
            ) {
                let recorded = await GoDiveBuddyActivityPushSignalSync.recordFirstShareIfNeeded(
                    ownerUID: uid,
                    activityID: snorkel.id,
                    activityKind: snapshot.activityKind,
                    startTime: snorkel.startTime,
                    taggedBuddies: GoDiveSharedDiveProjectionMapping.taggedBuddiesFirestoreRows(
                        from: snapshot.taggedBuddies
                    )
                )
                if recorded {
                    snorkel.friendSharePushSignalRecorded = true
                    try? modelContext.save()
                }
            }
            return true
        } catch {
            GoDiveSecurityEvent.record(.friendShareSyncFailed, detail: "upsertSnorkel")
            log.error("Shared snorkel upsert failed: \(String(describing: error), privacy: .private)")
            return false
        }
    }

    @MainActor
    static func deleteActivityProjection(activityID: UUID) async {
        await deleteDiveProjection(diveID: activityID)
    }

    @MainActor
    static func deleteDiveProjection(diveID: UUID, ownerUID: String? = nil) async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = ownerUID ?? Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        await GoDiveSharedMediaUpload.clearActivityMedia(ownerUID: uid, activityID: diveID)

        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .document(diveID.uuidString)
                .delete()
            await GoDiveBuddyActivityPushSignalSync.deleteSignal(
                ownerUID: uid,
                activityID: diveID
            )
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
            GoDiveSharedMediaPublishState.clearOwner(ownerUID: uid)
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

    nonisolated static func fetchFriendSharedDive(
        friendUID: String,
        diveDocumentID: String
    ) async -> GoDiveSharedDiveProjectionMapping.FriendVisibleDive? {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return nil }
        guard Auth.auth().currentUser != nil else { return nil }
        let trimmedUID = friendUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDiveID = diveDocumentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUID.isEmpty, !trimmedDiveID.isEmpty else { return nil }

        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(trimmedUID)
                .collection(GoDiveSharedDiveProjectionMapping.sharedDivesSubcollection)
                .document(trimmedDiveID)
                .getDocument()
            guard doc.exists, let data = doc.data() else { return nil }
            return GoDiveSharedDiveProjectionMapping.parseFriendVisibleDive(
                id: doc.documentID,
                data: data
            )
        } catch {
            log.error("Friend shared dive fetch failed: \(String(describing: error), privacy: .private)")
            return nil
        }
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
        mediaItems: [GoDiveSharedDiveProjectionMapping.MediaItemSnapshot],
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
        let sharedMediaIDs = Set(mediaItems.map(\.mediaID))
        let mediaBuddyTags = projectionMediaBuddyTags(
            from: dive.mediaBuddyTags,
            sharedMediaIDs: sharedMediaIDs
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
            mediaItems: mediaItems,
            mediaBuddyTags: mediaBuddyTags,
            mediaPreviews: [],
            featuredMediaPhotoID: DiveActivityMediaPresentation.featuredPhotoID(on: dive)?.uuidString
        )
    }

    @MainActor
    private static func makeSnorkelSnapshot(
        from snorkel: SnorkelActivity,
        mediaItems: [GoDiveSharedDiveProjectionMapping.MediaItemSnapshot],
        modelContext: ModelContext
    ) -> GoDiveSharedDiveProjectionMapping.DiveSnapshot {
        let place = regionCountryFields(
            linkedSite: snorkel.resolvedLinkedSite,
            locationName: snorkel.locationName
        )
        let sharedMediaIDs = Set(mediaItems.map(\.mediaID))
        let mediaBuddyTags = projectionMediaBuddyTags(
            from: snorkel.mediaBuddyTags,
            sharedMediaIDs: sharedMediaIDs
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
            mediaItems: mediaItems,
            mediaBuddyTags: mediaBuddyTags,
            mediaPreviews: [],
            featuredMediaPhotoID: SnorkelActivityMediaPresentation.featuredPhotoID(on: snorkel)?.uuidString
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
    private static func projectionMediaBuddyTags(
        from tags: [DiveMediaBuddyTag],
        sharedMediaIDs: Set<String>
    ) -> [GoDiveSharedDiveProjectionMapping.MediaBuddyTagSnapshot] {
        var seen = Set<String>()
        return tags.compactMap { tag -> GoDiveSharedDiveProjectionMapping.MediaBuddyTagSnapshot? in
            guard let mediaPhotoID = tag.mediaPhotoID,
                  sharedMediaIDs.contains(mediaPhotoID.uuidString),
                  let buddy = tag.buddy
            else { return nil }
            let name = buddy.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let dedupeKey = "\(mediaPhotoID.uuidString)|\(name)"
            guard seen.insert(dedupeKey).inserted else { return nil }
            return GoDiveSharedDiveProjectionMapping.MediaBuddyTagSnapshot(
                mediaID: mediaPhotoID.uuidString,
                displayName: name,
                firebaseUID: buddy.linkedFirebaseUID
            )
        }
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

    nonisolated static func applyOptOutFieldDeletes(
        to fields: inout [String: Any],
        options: GoDiveSharedDiveProjectionMapping.ShareOptions
    ) {
        if !options.includeNotes {
            fields["notes"] = FieldValue.delete()
        }
        if !options.includeMedia {
            fields["mediaItems"] = FieldValue.delete()
            fields["featuredMediaId"] = FieldValue.delete()
            fields["mediaPreviews"] = FieldValue.delete()
            fields["featuredMediaPhotoId"] = FieldValue.delete()
        }
    }
}
