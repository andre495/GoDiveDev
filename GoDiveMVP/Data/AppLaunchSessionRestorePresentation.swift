import Foundation

/// Fast local session restore — profile id in **Keychain** (UserDefaults migrated once).
enum AppLaunchSessionRestorePresentation: Sendable {
    /// Legacy key — migrated into Keychain on first read/write.
    nonisolated static let currentProfileIDUserDefaultsKey = "goDiveCurrentProfileID"

    nonisolated static func persistedProfileID(storedUUIDString: String?) -> UUID? {
        guard let storedUUIDString, let id = UUID(uuidString: storedUUIDString) else { return nil }
        return id
    }

    /// Loads the signed-in profile id from Keychain, migrating a legacy UserDefaults value when present.
    nonisolated static func loadPersistedProfileID(
        userDefaults: UserDefaults = .standard
    ) -> UUID? {
        if let fromKeychain = GoDiveKeychainStore.string(for: .currentProfileID),
           let id = UUID(uuidString: fromKeychain) {
            return id
        }
        guard let legacy = userDefaults.string(forKey: currentProfileIDUserDefaultsKey),
              let id = UUID(uuidString: legacy)
        else {
            return nil
        }
        _ = GoDiveKeychainStore.setString(id.uuidString, account: .currentProfileID)
        userDefaults.removeObject(forKey: currentProfileIDUserDefaultsKey)
        return id
    }

    nonisolated static func savePersistedProfileID(
        _ id: UUID,
        userDefaults: UserDefaults = .standard
    ) {
        _ = GoDiveKeychainStore.setString(id.uuidString, account: .currentProfileID)
        userDefaults.removeObject(forKey: currentProfileIDUserDefaultsKey)
    }

    nonisolated static func clearPersistedProfileID(
        userDefaults: UserDefaults = .standard
    ) {
        _ = GoDiveKeychainStore.remove(.currentProfileID)
        userDefaults.removeObject(forKey: currentProfileIDUserDefaultsKey)
    }
}
