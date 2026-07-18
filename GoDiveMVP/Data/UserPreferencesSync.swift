import Foundation
import SwiftData

/// Bridges synced **`UserPreferences`** (SwiftData / CloudKit) ↔ **`UserDefaults`** cache.
enum UserPreferencesSync: Sendable {

    struct FindOrCreateResult: Equatable, Sendable {
        let preferencesID: UUID
        let didCreate: Bool
    }

    /// Finds the owner's preferences row or inserts one seeded from **`UserDefaults`**.
    @discardableResult
    nonisolated static func findOrCreate(
        for owner: UserProfile,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) throws -> FindOrCreateResult {
        let ownerID = owner.id
        var descriptor = FetchDescriptor<UserPreferences>(
            predicate: #Predicate<UserPreferences> { $0.ownerProfileID == ownerID }
        )
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            if existing.owner == nil {
                existing.owner = owner
            }
            return FindOrCreateResult(preferencesID: existing.id, didCreate: false)
        }

        let prefs = UserPreferences(owner: owner)
        applyFromUserDefaults(to: prefs, userDefaults: userDefaults)
        modelContext.insert(prefs)
        return FindOrCreateResult(preferencesID: prefs.id, didCreate: true)
    }

    /// On sign-in / launch: create if needed; otherwise refresh **`UserDefaults`** from the store (CloudKit truth).
    nonisolated static func syncForSignedInOwner(
        _ owner: UserProfile,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) throws {
        let result = try findOrCreate(for: owner, modelContext: modelContext, userDefaults: userDefaults)
        guard let prefs = try preferences(id: result.preferencesID, modelContext: modelContext) else { return }
        if result.didCreate {
            try modelContext.save()
            return
        }
        applyToUserDefaults(prefs, userDefaults: userDefaults)
        try modelContext.save()
    }

    /// Writes current **`UserDefaults`** synced keys into the owner's SwiftData row (Settings edits).
    nonisolated static func pushUserDefaultsToStore(
        owner: UserProfile,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) throws {
        let result = try findOrCreate(for: owner, modelContext: modelContext, userDefaults: userDefaults)
        guard let prefs = try preferences(id: result.preferencesID, modelContext: modelContext) else { return }
        applyFromUserDefaults(to: prefs, userDefaults: userDefaults)
        prefs.updatedAt = Date()
        try modelContext.save()
    }

    /// Applies store values into **`UserDefaults`** so `@AppStorage` / nonisolated readers see CloudKit updates.
    nonisolated static func pullStoreToUserDefaults(
        ownerProfileID: UUID,
        modelContext: ModelContext,
        userDefaults: UserDefaults = .standard
    ) throws {
        var descriptor = FetchDescriptor<UserPreferences>(
            predicate: #Predicate<UserPreferences> { $0.ownerProfileID == ownerProfileID }
        )
        descriptor.fetchLimit = 1
        guard let prefs = try modelContext.fetch(descriptor).first else { return }
        applyToUserDefaults(prefs, userDefaults: userDefaults)
    }

    nonisolated static func applyToUserDefaults(
        _ prefs: UserPreferences,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(prefs.automaticallyRenumberDives, forKey: AppUserSettings.automaticallyRenumberDivesKey)
        userDefaults.set(prefs.useImperialDisplayUnits, forKey: AppUserSettings.useImperialDisplayUnitsKey)
        userDefaults.set(prefs.defaultTankSizeRaw, forKey: AppUserSettings.defaultTankSizeKey)
        userDefaults.set(prefs.bulkUddfCreateDiveSites, forKey: AppUserSettings.bulkUddfCreateDiveSitesKey)
        userDefaults.set(prefs.autoUploadMediaToActivities, forKey: AppUserSettings.autoUploadMediaToActivitiesKey)
        AppUserSettings.setDefaultSaltwaterWeightKilograms(
            prefs.defaultSaltwaterWeightKilograms,
            userDefaults: userDefaults
        )
        AppUserSettings.setDefaultFreshwaterWeightKilograms(
            prefs.defaultFreshwaterWeightKilograms,
            userDefaults: userDefaults
        )
    }

    nonisolated static func applyFromUserDefaults(
        to prefs: UserPreferences,
        userDefaults: UserDefaults = .standard
    ) {
        prefs.automaticallyRenumberDives = userDefaults.bool(forKey: AppUserSettings.automaticallyRenumberDivesKey)
        prefs.useImperialDisplayUnits = userDefaults.bool(forKey: AppUserSettings.useImperialDisplayUnitsKey)
        let tankRaw = userDefaults.string(forKey: AppUserSettings.defaultTankSizeKey)
        prefs.defaultTankSizeRaw = tankRaw.flatMap(DefaultTankSize.init(rawValue:))?.rawValue
            ?? DefaultTankSize.al80.rawValue
        prefs.bulkUddfCreateDiveSites = userDefaults.object(forKey: AppUserSettings.bulkUddfCreateDiveSitesKey) == nil
            ? true
            : userDefaults.bool(forKey: AppUserSettings.bulkUddfCreateDiveSitesKey)
        prefs.autoUploadMediaToActivities = userDefaults.bool(forKey: AppUserSettings.autoUploadMediaToActivitiesKey)
        prefs.defaultSaltwaterWeightKilograms = AppUserSettings.defaultSaltwaterWeightKilograms(
            userDefaults: userDefaults
        )
        prefs.defaultFreshwaterWeightKilograms = AppUserSettings.defaultFreshwaterWeightKilograms(
            userDefaults: userDefaults
        )
        prefs.updatedAt = Date()
    }

    private nonisolated static func preferences(
        id: UUID,
        modelContext: ModelContext
    ) throws -> UserPreferences? {
        let descriptor = FetchDescriptor<UserPreferences>(
            predicate: #Predicate<UserPreferences> { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
}
