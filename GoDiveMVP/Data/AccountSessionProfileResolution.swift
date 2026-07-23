import Foundation
import SwiftData

/// Resolves the signed-in **`UserProfile`** after a CloudKit-backed store opens (fresh store or import in flight).
enum AccountSessionProfileResolution: Sendable {
    nonisolated static let defaultImportTimeoutSeconds = 90
    /// Cold launch — dismiss splash before CloudKit finishes a full historical import.
    nonisolated static let launchImportTimeoutSeconds = 25

    @MainActor
    static func resolve(
        preferredProfileID: UUID,
        appleUserIdentifier: String,
        modelContext: ModelContext,
        waitForCloudKitImport: Bool,
        importTimeoutSeconds: Int = defaultImportTimeoutSeconds
    ) async -> UserProfile? {
        if let immediate = lookup(
            preferredProfileID: preferredProfileID,
            appleUserIdentifier: appleUserIdentifier,
            modelContext: modelContext
        ) {
            return immediate
        }
        guard waitForCloudKitImport else { return nil }

        let appleID = appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appleID.isEmpty else { return nil }

        let deadline = ContinuousClock.now + .seconds(importTimeoutSeconds)
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return nil }
            modelContext.processPendingChanges()
            if let profile = lookup(
                preferredProfileID: preferredProfileID,
                appleUserIdentifier: appleID,
                modelContext: modelContext
            ) {
                return profile
            }
        }
        return nil
    }

    /// After private CloudKit reconnect — wait until owned dives/snorkels appear for this Apple ID
    /// (or timeout). Empty local SIWA profiles satisfy **`resolve`** immediately; this waits for the log.
    @MainActor
    @discardableResult
    static func waitForOwnedActivities(
        appleUserIdentifier: String,
        modelContext: ModelContext,
        timeoutSeconds: Int = 90
    ) async -> Int {
        let appleID = appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appleID.isEmpty else { return 0 }

        if let count = ownedActivityCount(appleUserIdentifier: appleID, modelContext: modelContext),
           count > 0 {
            return count
        }

        let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return 0 }
            modelContext.processPendingChanges()
            if let count = ownedActivityCount(appleUserIdentifier: appleID, modelContext: modelContext),
               count > 0 {
                return count
            }
        }
        return ownedActivityCount(appleUserIdentifier: appleID, modelContext: modelContext) ?? 0
    }

    /// Total dives + snorkels owned by any **`UserProfile`** with this Apple user id (session-agnostic).
    @MainActor
    static func totalOwnedActivityCount(
        appleUserIdentifier: String,
        modelContext: ModelContext
    ) -> Int {
        ownedActivityCount(appleUserIdentifier: appleUserIdentifier, modelContext: modelContext) ?? 0
    }

    @MainActor
    private static func ownedActivityCount(
        appleUserIdentifier: String,
        modelContext: ModelContext
    ) -> Int? {
        guard let profiles = try? modelContext.fetch(
            FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.appleUserIdentifier == appleUserIdentifier }
            )
        ), !profiles.isEmpty else {
            return nil
        }
        var total = 0
        for profile in profiles {
            let id = profile.id
            total += (try? modelContext.fetchCount(
                FetchDescriptor<DiveActivity>(predicate: #Predicate { $0.ownerProfileID == id })
            )) ?? 0
            total += (try? modelContext.fetchCount(
                FetchDescriptor<SnorkelActivity>(predicate: #Predicate { $0.ownerProfileID == id })
            )) ?? 0
        }
        return total
    }

    @MainActor
    private static func lookup(
        preferredProfileID: UUID,
        appleUserIdentifier: String,
        modelContext: ModelContext
    ) -> UserProfile? {
        modelContext.processPendingChanges()
        // Prefer the Apple-ID match that already owns activities (CloudKit import), not the SIWA mint.
        if let profiles = try? modelContext.fetch(
            FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.appleUserIdentifier == appleUserIdentifier }
            )
        ), !profiles.isEmpty {
            var best: UserProfile?
            var bestCount = -1
            for profile in profiles.sorted(by: { $0.createdAt < $1.createdAt }) {
                let id = profile.id
                let dives = (try? modelContext.fetchCount(
                    FetchDescriptor<DiveActivity>(predicate: #Predicate { $0.ownerProfileID == id })
                )) ?? 0
                let snorkels = (try? modelContext.fetchCount(
                    FetchDescriptor<SnorkelActivity>(predicate: #Predicate { $0.ownerProfileID == id })
                )) ?? 0
                let count = dives + snorkels
                if count > bestCount {
                    bestCount = count
                    best = profile
                } else if count == bestCount, let current = best, profile.createdAt < current.createdAt {
                    best = profile
                }
            }
            if let best { return best }
        }
        if let byID = try? UserProfileStore.profile(id: preferredProfileID, modelContext: modelContext) {
            return byID
        }
        if let remembered = ReturningAccountHints.rememberedProfileID(
            forAppleUserIdentifier: appleUserIdentifier
        ),
            let byRemembered = try? UserProfileStore.profile(id: remembered, modelContext: modelContext)
        {
            return byRemembered
        }
        return nil
    }
}
