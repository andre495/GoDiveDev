import Foundation
import os
import FirebaseAuth
import FirebaseFirestore
import SwiftData

/// Syncs anonymized sighting contributions to the owner's private Firestore staging collection.
/// A Cloud Function mirrors active rows into **`communitySightings/{contributionId}`**.
///
/// Toggle backfill / opt-out use **WriteBatch** (≤400 ops) and commit **off the main actor**
/// after SwiftData collection on the caller’s context.
enum OntologySightingContributionSync: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "OntologySightingSync"
    )

    nonisolated static let contributionsCollection = "ontologySightingContributions"
    nonisolated static let contributionIdDefaultsKey = "godive.ontologySighting.contributionIds"
    /// Firestore WriteBatch hard limit is 500; stay under for merge + timestamp fields.
    nonisolated static let firestoreBatchMaxOps = 400

    /// One staging document ready for a batched Firestore write.
    nonisolated struct StagingDocumentWrite: Equatable, Sendable {
        var documentID: String
        var payload: SightingGraphExportPayload
    }

    /// Whether the device may write staging docs right now.
    nonisolated static func shouldContribute(userDefaults: UserDefaults = .standard) -> Bool {
        guard AppUserSettings.contributeCommunitySightings(userDefaults: userDefaults) else {
            return false
        }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return false }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return false }
        return true
    }

    /// Stable opaque contribution id per local sighting UUID (never the public-facing identity).
    nonisolated static func contributionId(
        forSightingUUID sightingUUID: String,
        userDefaults: UserDefaults = .standard
    ) -> String {
        var map = userDefaults.dictionary(forKey: contributionIdDefaultsKey) as? [String: String] ?? [:]
        if let existing = map[sightingUUID], !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        map[sightingUUID] = created
        userDefaults.set(map, forKey: contributionIdDefaultsKey)
        return created
    }

    /// Splits work into Firestore-safe batch chunks (pure; unit-tested).
    nonisolated static func chunkedBatches<T>(
        _ items: [T],
        size: Int = firestoreBatchMaxOps
    ) -> [[T]] {
        let chunkSize = max(1, size)
        guard !items.isEmpty else { return [] }
        var out: [[T]] = []
        var index = items.startIndex
        while index < items.endIndex {
            let end = items.index(index, offsetBy: chunkSize, limitedBy: items.endIndex) ?? items.endIndex
            out.append(Array(items[index ..< end]))
            index = end
        }
        return out
    }

    // MARK: - Collect (MainActor / SwiftData)

    /// Builds anonymized staging writes for every sighting on the owner’s dives/snorkels.
    @MainActor
    static func ownedStagingWrites(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) -> [StagingDocumentWrite] {
        let diveIDs = Set(
            ((try? modelContext.fetch(
                FetchDescriptor<DiveActivity>(
                    predicate: #Predicate<DiveActivity> { $0.ownerProfileID == ownerProfileID }
                )
            )) ?? []).map(\.id)
        )
        let snorkelIDs = Set(
            ((try? modelContext.fetch(
                FetchDescriptor<SnorkelActivity>(
                    predicate: #Predicate<SnorkelActivity> { $0.ownerProfileID == ownerProfileID }
                )
            )) ?? []).map(\.id)
        )
        let all = (try? modelContext.fetch(FetchDescriptor<SightingInstance>())) ?? []
        let owned = all.filter { sighting in
            if let diveID = sighting.diveActivityID, diveIDs.contains(diveID) { return true }
            if let snorkelID = sighting.snorkelActivityID, snorkelIDs.contains(snorkelID) { return true }
            return false
        }
        return stagingWrites(from: owned, modelContext: modelContext, userDefaults: userDefaults)
    }

    @MainActor
    static func stagingWrites(
        from sightings: [SightingInstance],
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard,
        status: SightingGraphExportPayload.Status = .active
    ) -> [StagingDocumentWrite] {
        let catalogSites = (try? modelContext.fetch(FetchDescriptor<DiveSite>())) ?? []
        let userSites = (try? modelContext.fetch(FetchDescriptor<UserDiveSite>())) ?? []
        let dives = (try? modelContext.fetch(FetchDescriptor<DiveActivity>())) ?? []
        let snorkels = (try? modelContext.fetch(FetchDescriptor<SnorkelActivity>())) ?? []
        let diveByID = Dictionary(uniqueKeysWithValues: dives.map { ($0.id, $0) })
        let snorkelByID = Dictionary(uniqueKeysWithValues: snorkels.map { ($0.id, $0) })

        var writes: [StagingDocumentWrite] = []
        writes.reserveCapacity(sightings.count)
        for sighting in sightings {
            let contributionId = contributionId(
                forSightingUUID: sighting.sightingUUID,
                userDefaults: userDefaults
            )
            let activity = activityContext(
                for: sighting,
                diveByID: diveByID,
                snorkelByID: snorkelByID
            )
            let siteReportId = siteReportContributionId(
                for: sighting,
                userDefaults: userDefaults
            )
            guard let payload = SightingGraphExport.payload(
                from: sighting,
                contributionId: contributionId,
                catalogSites: catalogSites,
                userSites: userSites,
                activity: activity,
                siteReportId: siteReportId,
                status: status
            ) else { continue }
            writes.append(
                StagingDocumentWrite(documentID: sighting.sightingUUID, payload: payload)
            )
        }
        return writes
    }

    /// Opaque SiteReport id for the sighting’s parent activity (1:1).
    nonisolated static func siteReportContributionId(
        for sighting: SightingInstance,
        userDefaults: UserDefaults = .standard
    ) -> String? {
        if let diveID = sighting.diveActivityID {
            return OntologySiteReportContributionSync.contributionId(
                forActivityUUID: diveID,
                userDefaults: userDefaults
            )
        }
        if let snorkelID = sighting.snorkelActivityID {
            return OntologySiteReportContributionSync.contributionId(
                forActivityUUID: snorkelID,
                userDefaults: userDefaults
            )
        }
        return nil
    }

    @MainActor
    private static func activityContext(
        for sighting: SightingInstance,
        diveByID: [UUID: DiveActivity],
        snorkelByID: [UUID: SnorkelActivity]
    ) -> SightingGraphExport.ActivityContext? {
        if let diveID = sighting.diveActivityID, let dive = diveByID[diveID] {
            return SightingGraphExport.ActivityContext(
                diveSiteID: dive.diveSiteID,
                timeZoneOffsetSeconds: dive.timeZoneOffsetSeconds
            )
        }
        if let snorkelID = sighting.snorkelActivityID, let snorkel = snorkelByID[snorkelID] {
            return SightingGraphExport.ActivityContext(
                diveSiteID: snorkel.diveSiteID,
                timeZoneOffsetSeconds: snorkel.timeZoneOffsetSeconds
            )
        }
        return nil
    }

    // MARK: - Public entry points

    @MainActor
    static func upsert(
        sighting: SightingInstance,
        catalogSites: [DiveSite],
        modelContext: ModelContext? = nil,
        userDefaults: UserDefaults = .standard
    ) async {
        guard shouldContribute(userDefaults: userDefaults) else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let writes: [StagingDocumentWrite]
        if let modelContext {
            writes = stagingWrites(
                from: [sighting],
                modelContext: modelContext,
                userDefaults: userDefaults,
                status: .active
            )
        } else {
            // Fallback when caller only has catalog sites (no activity/user-site join).
            let contributionId = contributionId(
                forSightingUUID: sighting.sightingUUID,
                userDefaults: userDefaults
            )
            guard let payload = SightingGraphExport.payload(
                from: sighting,
                contributionId: contributionId,
                catalogSites: catalogSites,
                status: .active
            ) else { return }
            writes = [StagingDocumentWrite(documentID: sighting.sightingUUID, payload: payload)]
        }
        await commitActiveStagingBatches(uid: uid, writes: writes)
    }

    @MainActor
    static func markDeleted(
        sightingUUID: String,
        userDefaults: UserDefaults = .standard
    ) async {
        await markDeleted(sightingUUIDs: [sightingUUID], userDefaults: userDefaults)
    }

    @MainActor
    static func markDeleted(
        sightingUUIDs: [String],
        userDefaults: UserDefaults = .standard
    ) async {
        guard AppUserSettings.contributeCommunitySightings(userDefaults: userDefaults) else { return }
        let unique = Array(Set(sightingUUIDs.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        let marks = unique.map { uuid in
            DeletedStagingMark(
                documentID: uuid,
                contributionId: contributionId(forSightingUUID: uuid, userDefaults: userDefaults)
            )
        }
        await commitDeletedStagingMarks(uid: uid, marks: marks)
    }

    /// After a successful local tag save — soft-fail sync.
    @MainActor
    static func syncAfterTag(
        sighting: SightingInstance,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async {
        await syncAfterTags(
            sightings: [sighting],
            modelContext: modelContext,
            userDefaults: userDefaults
        )
    }

    @MainActor
    static func syncAfterTags(
        sightings: [SightingInstance],
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async {
        guard shouldContribute(userDefaults: userDefaults) else { return }
        guard !sightings.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        // Keep the 1:1 SiteReport for the parent activity in sync, then write sightings
        // that reference that report via **`siteReportId`**.
        var refreshedActivityKeys = Set<String>()
        for sighting in sightings {
            let key: String?
            if let diveID = sighting.diveActivityID {
                key = "dive:\(diveID.uuidString)"
            } else if let snorkelID = sighting.snorkelActivityID {
                key = "snorkel:\(snorkelID.uuidString)"
            } else {
                key = nil
            }
            guard let key, refreshedActivityKeys.insert(key).inserted else { continue }
            await OntologySiteReportContributionSync.syncSiteReportForSightingActivity(
                sighting: sighting,
                modelContext: modelContext,
                userDefaults: userDefaults
            )
        }
        let writes = stagingWrites(
            from: sightings,
            modelContext: modelContext,
            userDefaults: userDefaults,
            status: .active
        )
        await commitActiveStagingBatches(uid: uid, writes: writes)
    }

    @MainActor
    static func backfillAllOwnedSightings(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async {
        guard shouldContribute(userDefaults: userDefaults) else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let writes = ownedStagingWrites(
            ownerProfileID: ownerProfileID,
            modelContext: modelContext,
            userDefaults: userDefaults
        )
        await commitActiveStagingBatches(uid: uid, writes: writes)
    }

    /// Opt-out: mark every private staging doc deleted so the ingest Function removes public rows.
    /// Network work runs off the main actor.
    nonisolated static func markAllContributionsDeleted() async {
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let db = Firestore.firestore()
        let col = db.collection("users").document(uid).collection(contributionsCollection)
        do {
            let snapshot = try await col.getDocuments()
            let documentIDs = snapshot.documents.map(\.documentID)
            guard !documentIDs.isEmpty else { return }
            try await commitStatusDeletedBatches(collection: col, documentIDs: documentIDs)
        } catch {
            log.notice("Ontology sighting opt-out wipe failed")
        }
    }

    // MARK: - Firestore batches (off main actor)

    nonisolated private struct DeletedStagingMark: Sendable {
        var documentID: String
        var contributionId: String
    }

    nonisolated static func commitActiveStagingBatches(
        uid: String,
        writes: [StagingDocumentWrite]
    ) async {
        guard !writes.isEmpty else { return }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        let db = Firestore.firestore()
        let col = db.collection("users").document(uid).collection(contributionsCollection)
        for chunk in chunkedBatches(writes) {
            let batch = db.batch()
            for write in chunk {
                var fields = SightingGraphExport.firestoreFields(from: write.payload)
                fields["updatedAt"] = FieldValue.serverTimestamp()
                batch.setData(fields, forDocument: col.document(write.documentID), merge: true)
            }
            do {
                try await batch.commit()
            } catch {
                log.notice("Ontology sighting batch upsert failed")
                return
            }
        }
    }

    nonisolated private static func commitDeletedStagingMarks(
        uid: String,
        marks: [DeletedStagingMark]
    ) async {
        guard !marks.isEmpty else { return }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        let db = Firestore.firestore()
        let col = db.collection("users").document(uid).collection(contributionsCollection)
        for chunk in chunkedBatches(marks) {
            let batch = db.batch()
            for mark in chunk {
                batch.setData(
                    [
                        "contributionId": mark.contributionId,
                        "status": SightingGraphExportPayload.Status.deleted.rawValue,
                        "updatedAt": FieldValue.serverTimestamp(),
                        "schemaVersion": SightingGraphExport.schemaVersion,
                    ],
                    forDocument: col.document(mark.documentID),
                    merge: true
                )
            }
            do {
                try await batch.commit()
            } catch {
                log.notice("Ontology sighting delete mark failed")
                return
            }
        }
    }

    nonisolated private static func commitStatusDeletedBatches(
        collection: CollectionReference,
        documentIDs: [String]
    ) async throws {
        for chunk in chunkedBatches(documentIDs) {
            let batch = collection.firestore.batch()
            for documentID in chunk {
                batch.setData(
                    [
                        "status": SightingGraphExportPayload.Status.deleted.rawValue,
                        "updatedAt": FieldValue.serverTimestamp(),
                    ],
                    forDocument: collection.document(documentID),
                    merge: true
                )
            }
            try await batch.commit()
        }
    }

    #if DEBUG
    nonisolated static func resetContributionIdsForTesting(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: contributionIdDefaultsKey)
    }
    #endif
}
