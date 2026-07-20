import Foundation

/// Device-local hints that survive **sign out** so a returning Apple ID is not treated as a brand-new **Diver** signup.
/// Identifiers live in **Keychain**; legacy UserDefaults values migrate on read.
enum ReturningAccountHints: Sendable {
    nonisolated static let lastAppleUserIdentifierKey = "godive.account.lastAppleUserIdentifier"
    nonisolated static let lastDisplayNameKey = "godive.account.lastDisplayName"
    nonisolated static let lastProfileIDKey = "godive.account.lastProfileID"

    /// Call whenever a signed-in profile is persisted (not cleared on sign out).
    nonisolated static func remember(profile: UserProfile, userDefaults: UserDefaults = .standard) {
        let appleID = profile.appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appleID.isEmpty else { return }
        _ = GoDiveKeychainStore.setString(appleID, account: .lastAppleUserIdentifier)
        _ = GoDiveKeychainStore.setString(profile.id.uuidString, account: .lastProfileID)
        userDefaults.removeObject(forKey: lastAppleUserIdentifierKey)
        userDefaults.removeObject(forKey: lastProfileIDKey)

        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != UserProfileStore.defaultDisplayName {
            _ = GoDiveKeychainStore.setString(name, account: .lastDisplayName)
            userDefaults.removeObject(forKey: lastDisplayNameKey)
            UserProfileStore.cacheDisplayName(name, forAppleUserIdentifier: appleID)
        }
    }

    nonisolated static func hasPriorSession(
        forAppleUserIdentifier appleUserIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        let trimmed = appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        migrateLegacyHintsIfNeeded(userDefaults: userDefaults)
        return GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) == trimmed
    }

    nonisolated static func rememberedDisplayName(
        forAppleUserIdentifier appleUserIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) -> String? {
        guard hasPriorSession(forAppleUserIdentifier: appleUserIdentifier, userDefaults: userDefaults) else {
            return nil
        }
        if let cached = UserProfileStore.cachedDisplayName(forAppleUserIdentifier: appleUserIdentifier) {
            return cached
        }
        let raw = GoDiveKeychainStore.string(for: .lastDisplayName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty, raw != UserProfileStore.defaultDisplayName else { return nil }
        return raw
    }

    nonisolated static func rememberedProfileID(
        forAppleUserIdentifier appleUserIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) -> UUID? {
        guard hasPriorSession(forAppleUserIdentifier: appleUserIdentifier, userDefaults: userDefaults) else {
            return nil
        }
        guard let raw = GoDiveKeychainStore.string(for: .lastProfileID) else { return nil }
        return UUID(uuidString: raw)
    }

    /// Whether post-signup / new-account chrome should run after Sign in with Apple.
    nonisolated static func treatAsNewAccount(
        profileDidExistLocally: Bool,
        mergedDuplicateCount: Int,
        ownedDiveCount: Int,
        appleUserIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        guard !profileDidExistLocally else { return false }
        guard mergedDuplicateCount == 0 else { return false }
        guard ownedDiveCount == 0 else { return false }
        guard !hasPriorSession(forAppleUserIdentifier: appleUserIdentifier, userDefaults: userDefaults) else {
            return false
        }
        return true
    }

    /// Clears returning-user hints (account deletion only — not used for normal sign out).
    nonisolated static func clearAll(userDefaults: UserDefaults = .standard) {
        _ = GoDiveKeychainStore.remove(.lastAppleUserIdentifier)
        _ = GoDiveKeychainStore.remove(.lastDisplayName)
        _ = GoDiveKeychainStore.remove(.lastProfileID)
        userDefaults.removeObject(forKey: lastAppleUserIdentifierKey)
        userDefaults.removeObject(forKey: lastDisplayNameKey)
        userDefaults.removeObject(forKey: lastProfileIDKey)
    }

    /// One-shot migrate of legacy UserDefaults hints into Keychain.
    private nonisolated static func migrateLegacyHintsIfNeeded(userDefaults: UserDefaults) {
        if GoDiveKeychainStore.string(for: .lastAppleUserIdentifier) == nil,
           let apple = userDefaults.string(forKey: lastAppleUserIdentifierKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !apple.isEmpty {
            _ = GoDiveKeychainStore.setString(apple, account: .lastAppleUserIdentifier)
            userDefaults.removeObject(forKey: lastAppleUserIdentifierKey)
        }
        if GoDiveKeychainStore.string(for: .lastProfileID) == nil,
           let profileID = userDefaults.string(forKey: lastProfileIDKey),
           UUID(uuidString: profileID) != nil {
            _ = GoDiveKeychainStore.setString(profileID, account: .lastProfileID)
            userDefaults.removeObject(forKey: lastProfileIDKey)
        }
        if GoDiveKeychainStore.string(for: .lastDisplayName) == nil,
           let name = userDefaults.string(forKey: lastDisplayNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            _ = GoDiveKeychainStore.setString(name, account: .lastDisplayName)
            userDefaults.removeObject(forKey: lastDisplayNameKey)
        }
    }
}
