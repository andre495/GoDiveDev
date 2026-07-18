import Foundation

/// Device-local hints that survive **sign out** so a returning Apple ID is not treated as a brand-new **Diver** signup.
enum ReturningAccountHints: Sendable {
    nonisolated static let lastAppleUserIdentifierKey = "godive.account.lastAppleUserIdentifier"
    nonisolated static let lastDisplayNameKey = "godive.account.lastDisplayName"
    nonisolated static let lastProfileIDKey = "godive.account.lastProfileID"

    /// Call whenever a signed-in profile is persisted (not cleared on sign out).
    nonisolated static func remember(profile: UserProfile, userDefaults: UserDefaults = .standard) {
        let appleID = profile.appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appleID.isEmpty else { return }
        userDefaults.set(appleID, forKey: lastAppleUserIdentifierKey)
        userDefaults.set(profile.id.uuidString, forKey: lastProfileIDKey)

        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != UserProfileStore.defaultDisplayName {
            userDefaults.set(name, forKey: lastDisplayNameKey)
            UserProfileStore.cacheDisplayName(name, forAppleUserIdentifier: appleID)
        }
    }

    nonisolated static func hasPriorSession(
        forAppleUserIdentifier appleUserIdentifier: String,
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        let trimmed = appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return userDefaults.string(forKey: lastAppleUserIdentifierKey) == trimmed
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
        let raw = userDefaults.string(forKey: lastDisplayNameKey)?
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
        guard let raw = userDefaults.string(forKey: lastProfileIDKey) else { return nil }
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
        userDefaults.removeObject(forKey: lastAppleUserIdentifierKey)
        userDefaults.removeObject(forKey: lastDisplayNameKey)
        userDefaults.removeObject(forKey: lastProfileIDKey)
    }
}
