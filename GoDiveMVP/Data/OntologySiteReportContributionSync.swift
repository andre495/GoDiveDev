import Foundation
import os
import FirebaseAuth
import FirebaseFirestore
import SwiftData

/// Syncs anonymized **SiteReport** contributions (1:1 with dive/snorkel activities).
/// Cloud Function mirrors active rows into **`communitySiteReports/{contributionId}`**.
enum OntologySiteReportContributionSync: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "PrimoSoftware.GoDiveMVP",
        category: "OntologySiteReportSync"
    )

    nonisolated static let contributionsCollection = "ontologySiteReportContributions"
    nonisolated static let contributionIdDefaultsKey = "godive.ontologySiteReport.contributionIds"

    nonisolated struct StagingDocumentWrite: Equatable, Sendable {
        var documentID: String
        var payload: SiteReportGraphExportPayload
    }

    /// Opaque contribution id per local activity UUID (never the public-facing identity).
    nonisolated static func contributionId(
        forActivityUUID activityUUID: UUID,
        userDefaults: UserDefaults = .standard
    ) -> String {
        contributionId(forActivityUUIDString: activityUUID.uuidString.lowercased(), userDefaults: userDefaults)
    }

    nonisolated static func contributionId(
        forActivityUUIDString activityUUID: String,
        userDefaults: UserDefaults = .standard
    ) -> String {
        let key = activityUUID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var map = userDefaults.dictionary(forKey: contributionIdDefaultsKey) as? [String: String] ?? [:]
        if let existing = map[key], !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        map[key] = created
        userDefaults.set(map, forKey: contributionIdDefaultsKey)
        return created
    }

    // MARK: - Collect

    @MainActor
    static func stagingWrite(
        dive: DiveActivity,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard,
        status: SiteReportGraphExportPayload.Status = .active
    ) -> StagingDocumentWrite? {
        let catalogSites = (try? modelContext.fetch(FetchDescriptor<DiveSite>())) ?? []
        let userSites = (try? modelContext.fetch(FetchDescriptor<UserDiveSite>())) ?? []
        let contributionId = contributionId(forActivityUUID: dive.id, userDefaults: userDefaults)
        guard let payload = SiteReportGraphExport.payload(
            from: dive,
            contributionId: contributionId,
            catalogSites: catalogSites,
            userSites: userSites,
            status: status
        ) else { return nil }
        return StagingDocumentWrite(documentID: dive.id.uuidString.lowercased(), payload: payload)
    }

    @MainActor
    static func stagingWrite(
        snorkel: SnorkelActivity,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard,
        status: SiteReportGraphExportPayload.Status = .active
    ) -> StagingDocumentWrite? {
        let catalogSites = (try? modelContext.fetch(FetchDescriptor<DiveSite>())) ?? []
        let userSites = (try? modelContext.fetch(FetchDescriptor<UserDiveSite>())) ?? []
        let contributionId = contributionId(forActivityUUID: snorkel.id, userDefaults: userDefaults)
        guard let payload = SiteReportGraphExport.payload(
            from: snorkel,
            contributionId: contributionId,
            catalogSites: catalogSites,
            userSites: userSites,
            status: status
        ) else { return nil }
        return StagingDocumentWrite(documentID: snorkel.id.uuidString.lowercased(), payload: payload)
    }

    @MainActor
    static func ownedStagingWrites(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) -> [StagingDocumentWrite] {
        let dives = (try? modelContext.fetch(
            FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { $0.ownerProfileID == ownerProfileID }
            )
        )) ?? []
        let snorkels = (try? modelContext.fetch(
            FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate<SnorkelActivity> { $0.ownerProfileID == ownerProfileID }
            )
        )) ?? []
        var writes: [StagingDocumentWrite] = []
        writes.reserveCapacity(dives.count + snorkels.count)
        for dive in dives {
            if let write = stagingWrite(dive: dive, modelContext: modelContext, userDefaults: userDefaults) {
                writes.append(write)
            }
        }
        for snorkel in snorkels {
            if let write = stagingWrite(snorkel: snorkel, modelContext: modelContext, userDefaults: userDefaults) {
                writes.append(write)
            }
        }
        return writes
    }

    // MARK: - Entry points

    /// After FIT/UDDF/manual dive persist — soft-fail when community contribution is off.
    @MainActor
    static func syncAfterDivePersisted(
        dive: DiveActivity,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async {
        guard OntologySightingContributionSync.shouldContribute(userDefaults: userDefaults) else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard let write = stagingWrite(dive: dive, modelContext: modelContext, userDefaults: userDefaults) else {
            return
        }
        await commitActiveStagingBatches(uid: uid, writes: [write])
    }

    @MainActor
    static func syncAfterSnorkelPersisted(
        snorkel: SnorkelActivity,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async {
        guard OntologySightingContributionSync.shouldContribute(userDefaults: userDefaults) else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        guard let write = stagingWrite(snorkel: snorkel, modelContext: modelContext, userDefaults: userDefaults) else {
            return
        }
        await commitActiveStagingBatches(uid: uid, writes: [write])
    }

    /// Refresh the activity’s SiteReport (e.g. when tags are saved and conditions may have changed).
    @MainActor
    static func syncSiteReportForSightingActivity(
        sighting: SightingInstance,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async {
        if let diveID = sighting.diveActivityID {
            var descriptor = FetchDescriptor<DiveActivity>(
                predicate: #Predicate<DiveActivity> { $0.id == diveID }
            )
            descriptor.fetchLimit = 1
            if let dive = try? modelContext.fetch(descriptor).first {
                await syncAfterDivePersisted(dive: dive, modelContext: modelContext, userDefaults: userDefaults)
            }
            return
        }
        if let snorkelID = sighting.snorkelActivityID {
            var descriptor = FetchDescriptor<SnorkelActivity>(
                predicate: #Predicate<SnorkelActivity> { $0.id == snorkelID }
            )
            descriptor.fetchLimit = 1
            if let snorkel = try? modelContext.fetch(descriptor).first {
                await syncAfterSnorkelPersisted(
                    snorkel: snorkel,
                    modelContext: modelContext,
                    userDefaults: userDefaults
                )
            }
        }
    }

    @MainActor
    static func backfillAllOwnedSiteReports(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) async {
        guard OntologySightingContributionSync.shouldContribute(userDefaults: userDefaults) else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }
        let writes = ownedStagingWrites(
            ownerProfileID: ownerProfileID,
            modelContext: modelContext,
            userDefaults: userDefaults
        )
        await commitActiveStagingBatches(uid: uid, writes: writes)
    }

    @MainActor
    static func markDeleted(
        activityUUID: UUID,
        userDefaults: UserDefaults = .standard
    ) async {
        await markDeleted(activityUUIDs: [activityUUID], userDefaults: userDefaults)
    }

    @MainActor
    static func markDeleted(
        activityUUIDs: [UUID],
        userDefaults: UserDefaults = .standard
    ) async {
        guard AppUserSettings.contributeCommunitySightings(userDefaults: userDefaults) else { return }
        let unique = Array(Set(activityUUIDs))
        guard !unique.isEmpty else { return }
        GoDiveFirebaseBootstrap.configureIfNeeded()
        guard GoDiveFirebaseBootstrap.isConfigured else { return }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else { return }

        let marks = unique.map { id in
            DeletedStagingMark(
                documentID: id.uuidString.lowercased(),
                contributionId: contributionId(forActivityUUID: id, userDefaults: userDefaults)
            )
        }
        await commitDeletedStagingMarks(uid: uid, marks: marks)
    }

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
            for chunk in OntologySightingContributionSync.chunkedBatches(documentIDs) {
                let batch = db.batch()
                for documentID in chunk {
                    batch.setData(
                        [
                            "status": SiteReportGraphExportPayload.Status.deleted.rawValue,
                            "updatedAt": FieldValue.serverTimestamp(),
                        ],
                        forDocument: col.document(documentID),
                        merge: true
                    )
                }
                try await batch.commit()
            }
        } catch {
            log.notice("Ontology site report opt-out wipe failed")
        }
    }

    // MARK: - Firestore

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
        for chunk in OntologySightingContributionSync.chunkedBatches(writes) {
            let batch = db.batch()
            for write in chunk {
                var fields = SiteReportGraphExport.firestoreFields(from: write.payload)
                fields["updatedAt"] = FieldValue.serverTimestamp()
                batch.setData(fields, forDocument: col.document(write.documentID), merge: true)
            }
            do {
                try await batch.commit()
            } catch {
                log.notice("Ontology site report batch upsert failed")
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
        for chunk in OntologySightingContributionSync.chunkedBatches(marks) {
            let batch = db.batch()
            for mark in chunk {
                batch.setData(
                    [
                        "contributionId": mark.contributionId,
                        "status": SiteReportGraphExportPayload.Status.deleted.rawValue,
                        "updatedAt": FieldValue.serverTimestamp(),
                        "schemaVersion": SiteReportGraphExport.schemaVersion,
                        "kind": "siteReport",
                    ],
                    forDocument: col.document(mark.documentID),
                    merge: true
                )
            }
            do {
                try await batch.commit()
            } catch {
                log.notice("Ontology site report delete mark failed")
                return
            }
        }
    }

    #if DEBUG
    nonisolated static func resetContributionIdsForTesting(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: contributionIdDefaultsKey)
    }
    #endif
}
