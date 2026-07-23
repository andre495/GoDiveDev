import Foundation
import SwiftData

/// Collapses duplicate **`UserProfile`** rows that share an **`appleUserIdentifier`** after CloudKit import.
///
/// Sign in with Apple can mint a new local profile UUID before CloudKit downloads the existing account.
/// UI filters by **`ownerProfileID`**, so without a merge the logbook looks empty even though synced
/// dives are present under the older profile UUID.
enum UserProfileCloudKitIdentityMerge: Sendable {

    struct Outcome: Equatable, Sendable {
        let canonicalProfileID: UUID
        let mergedDuplicateCount: Int
        let reassignedOwnedRowCount: Int
        let didChangeCanonicalID: Bool
    }

    /// Picks one canonical profile for **`appleUserIdentifier`**, reassigns owned rows, deletes duplicates.
    @discardableResult
    nonisolated static func reconcile(
        appleUserIdentifier: String,
        preferredSessionProfileID: UUID?,
        modelContext: ModelContext
    ) throws -> Outcome {
        let trimmed = appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MergeError.emptyAppleUserIdentifier
        }

        let matches = try modelContext.fetch(
            FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.appleUserIdentifier == trimmed }
            )
        )
        guard let first = matches.first else {
            throw MergeError.noProfilesForAppleUser
        }
        guard matches.count > 1 else {
            return Outcome(
                canonicalProfileID: first.id,
                mergedDuplicateCount: 0,
                reassignedOwnedRowCount: 0,
                didChangeCanonicalID: false
            )
        }

        let activityCounts = try ownedActivityCounts(for: matches, modelContext: modelContext)
        let canonical = chooseCanonical(
            profiles: matches,
            diveCounts: activityCounts,
            preferredSessionProfileID: preferredSessionProfileID
        )
        let totalOwnedActivities = activityCounts.values.reduce(0, +)
        // CloudKit often imports the twin **`UserProfile`** before its dives/snorkels. Deleting the
        // empty twin here permanently orphans the upcoming import under the deleted UUID.
        if totalOwnedActivities == 0 {
            return Outcome(
                canonicalProfileID: canonical.id,
                mergedDuplicateCount: 0,
                reassignedOwnedRowCount: 0,
                didChangeCanonicalID: preferredSessionProfileID.map { $0 != canonical.id } ?? false
            )
        }

        let duplicates = matches.filter { $0.id != canonical.id }

        var reassigned = 0
        for duplicate in duplicates {
            reassigned += try reassignOwnedRows(
                from: duplicate,
                to: canonical,
                modelContext: modelContext
            )
            mergeProfileMetadata(from: duplicate, into: canonical)
            // Clear inverses so cascade delete on the duplicate does not wipe adopted rows.
            duplicate.diveActivities = []
            duplicate.snorkelActivities = []
            duplicate.diveBuddies = []
            duplicate.diveTrips = []
            duplicate.equipmentItems = []
            duplicate.certifications = []
            duplicate.userDiveSites = []
            duplicate.userMarineLifeSpecies = []
            duplicate.marineLifeUserRecords = []
            duplicate.preferences = nil
            modelContext.delete(duplicate)
        }

        canonical.lastSignedInAt = .now
        try modelContext.save()

        return Outcome(
            canonicalProfileID: canonical.id,
            mergedDuplicateCount: duplicates.count,
            reassignedOwnedRowCount: reassigned,
            didChangeCanonicalID: preferredSessionProfileID.map { $0 != canonical.id } ?? false
        )
    }

    /// Scoring: most owned activities, then non-placeholder display name, then older **`createdAt`**.
    ///
    /// Never prefer the session profile when it owns **zero** activities — that empty SIWA-minted
    /// row would otherwise win ties and delete the CloudKit profile before dives import.
    nonisolated static func chooseCanonical(
        profiles: [UserProfile],
        diveCounts: [UUID: Int],
        preferredSessionProfileID: UUID?
    ) -> UserProfile {
        let ranked = profiles.sorted { lhs, rhs in
            let leftScore = score(profile: lhs, diveCount: diveCounts[lhs.id] ?? 0)
            let rightScore = score(profile: rhs, diveCount: diveCounts[rhs.id] ?? 0)
            if leftScore != rightScore { return leftScore > rightScore }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        if let preferred = preferredSessionProfileID,
           let preferredProfile = ranked.first(where: { $0.id == preferred }),
           (diveCounts[preferred] ?? 0) > 0,
           (diveCounts[preferred] ?? 0) == (diveCounts[ranked[0].id] ?? 0),
           score(profile: preferredProfile, diveCount: diveCounts[preferred] ?? 0)
               == score(profile: ranked[0], diveCount: diveCounts[ranked[0].id] ?? 0) {
            return preferredProfile
        }
        return ranked[0]
    }

    nonisolated static func score(profile: UserProfile, diveCount: Int) -> Int {
        var value = diveCount * 1_000
        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != UserProfileStore.defaultDisplayName {
            value += 100
        }
        if profile.profilePhoto != nil { value += 20 }
        if profile.danInsuranceNumber != nil { value += 10 }
        if profile.doesScubaDiving || profile.doesFreeDiving || profile.doesSnorkeling {
            value += 5
        }
        return value
    }

    enum MergeError: Error, Equatable {
        case emptyAppleUserIdentifier
        case noProfilesForAppleUser
    }

    // MARK: - Private

    private nonisolated static func ownedActivityCounts(
        for profiles: [UserProfile],
        modelContext: ModelContext
    ) throws -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for profile in profiles {
            let id = profile.id
            let dives = try modelContext.fetchCount(
                FetchDescriptor<DiveActivity>(
                    predicate: #Predicate<DiveActivity> { $0.ownerProfileID == id }
                )
            )
            let snorkels = try modelContext.fetchCount(
                FetchDescriptor<SnorkelActivity>(
                    predicate: #Predicate<SnorkelActivity> { $0.ownerProfileID == id }
                )
            )
            counts[id] = dives + snorkels
        }
        return counts
    }

    private nonisolated static func reassignOwnedRows(
        from duplicate: UserProfile,
        to canonical: UserProfile,
        modelContext: ModelContext
    ) throws -> Int {
        let duplicateID = duplicate.id
        var count = 0

        count += try reassign(
            FetchDescriptor<DiveActivity>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { activity in
            activity.owner = canonical
            activity.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<SnorkelActivity>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { activity in
            activity.owner = canonical
            activity.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<DiveBuddy>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { buddy in
            buddy.owner = canonical
            buddy.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<DiveTrip>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { trip in
            trip.owner = canonical
            trip.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<EquipmentItem>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { item in
            item.owner = canonical
            item.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<Certification>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { cert in
            cert.owner = canonical
            cert.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<UserDiveSite>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { site in
            site.owner = canonical
            site.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<UserMarineLife>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { species in
            species.owner = canonical
            species.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<MarineLifeUserRecord>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { record in
            record.owner = canonical
            record.ownerProfileID = canonical.id
        }
        count += try reassign(
            FetchDescriptor<ActivityTag>(predicate: #Predicate { $0.ownerProfileID == duplicateID }),
            modelContext: modelContext
        ) { tag in
            tag.ownerProfileID = canonical.id
        }

        let duplicatePrefs = try modelContext.fetch(
            FetchDescriptor<UserPreferences>(
                predicate: #Predicate<UserPreferences> { $0.ownerProfileID == duplicateID }
            )
        )
        for prefs in duplicatePrefs {
            if let existing = canonical.preferences {
                if prefs.updatedAt > existing.updatedAt {
                    existing.automaticallyRenumberDives = prefs.automaticallyRenumberDives
                    existing.useImperialDisplayUnits = prefs.useImperialDisplayUnits
                    existing.defaultTankSizeRaw = prefs.defaultTankSizeRaw
                    existing.defaultSaltwaterWeightKilograms = prefs.defaultSaltwaterWeightKilograms
                    existing.defaultFreshwaterWeightKilograms = prefs.defaultFreshwaterWeightKilograms
                    existing.bulkUddfCreateDiveSites = prefs.bulkUddfCreateDiveSites
                    existing.autoUploadMediaToActivities = prefs.autoUploadMediaToActivities
                    existing.updatedAt = prefs.updatedAt
                }
                modelContext.delete(prefs)
            } else {
                prefs.owner = canonical
                prefs.ownerProfileID = canonical.id
            }
            count += 1
        }

        return count
    }

    private nonisolated static func reassign<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        modelContext: ModelContext,
        update: (T) -> Void
    ) throws -> Int {
        let rows = try modelContext.fetch(descriptor)
        for row in rows {
            update(row)
        }
        return rows.count
    }

    private nonisolated static func mergeProfileMetadata(from duplicate: UserProfile, into canonical: UserProfile) {
        let canonicalName = canonical.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let duplicateName = duplicate.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if (canonicalName.isEmpty || canonicalName == UserProfileStore.defaultDisplayName),
           !duplicateName.isEmpty,
           duplicateName != UserProfileStore.defaultDisplayName {
            canonical.displayName = duplicate.displayName
        }
        if canonical.profilePhoto == nil {
            canonical.profilePhoto = duplicate.profilePhoto
        }
        if canonical.danInsuranceNumber == nil {
            canonical.danInsuranceNumber = duplicate.danInsuranceNumber
        }
        canonical.doesScubaDiving = canonical.doesScubaDiving || duplicate.doesScubaDiving
        canonical.doesFreeDiving = canonical.doesFreeDiving || duplicate.doesFreeDiving
        canonical.doesSnorkeling = canonical.doesSnorkeling || duplicate.doesSnorkeling
        if duplicate.createdAt < canonical.createdAt {
            canonical.createdAt = duplicate.createdAt
        }
    }
}
