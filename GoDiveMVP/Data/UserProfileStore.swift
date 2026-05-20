import Foundation
import SwiftData

/// Persists and updates **`UserProfile`** rows for Sign in with Apple.
enum UserProfileStore {
    nonisolated static let defaultDisplayName = "Diver"

    private nonisolated static let cachedDisplayNameKeyPrefix = "goDiveAppleDisplayName."

    /// Formats **`PersonNameComponents`** from Sign in with Apple (only sent on first authorization per Apple ID).
    nonisolated static func displayName(from fullName: PersonNameComponents?) -> String? {
        guard let fullName else { return nil }

        let formatter = PersonNameComponentsFormatter()
        let formatted = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.isEmpty {
            return formatted
        }

        let parts = [fullName.givenName, fullName.middleName, fullName.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    /// Apple only returns **`fullName`** once; keep any name we receive for later sign-ins.
    nonisolated static func cachedDisplayName(forAppleUserIdentifier appleUserIdentifier: String) -> String? {
        let key = cachedDisplayNameKeyPrefix + appleUserIdentifier
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func cacheDisplayName(_ displayName: String?, forAppleUserIdentifier appleUserIdentifier: String) {
        let key = cachedDisplayNameKeyPrefix + appleUserIdentifier
        guard let displayName else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key)
        }
    }

    /// Prefer a fresh Apple **`fullName`**, then cached name from a prior first-time authorization.
    nonisolated static func resolvedDisplayName(
        appleProvided: String?,
        appleUserIdentifier: String
    ) -> String? {
        if let appleProvided, !appleProvided.isEmpty {
            return appleProvided
        }
        return cachedDisplayName(forAppleUserIdentifier: appleUserIdentifier)
    }

    static func profile(
        id: UUID,
        modelContext: ModelContext
    ) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    static func profile(
        appleUserIdentifier: String,
        modelContext: ModelContext
    ) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserIdentifier == appleUserIdentifier }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Finds an existing profile for this Apple ID or inserts a new one.
    @discardableResult
    static func findOrCreateProfile(
        appleUserIdentifier: String,
        displayName: String?,
        modelContext: ModelContext
    ) throws -> UserProfile {
        if let existing = try profile(appleUserIdentifier: appleUserIdentifier, modelContext: modelContext) {
            if let displayName, !displayName.isEmpty,
               existing.displayName == defaultDisplayName || existing.displayName.isEmpty {
                existing.displayName = displayName
            }
            existing.lastSignedInAt = .now
            return existing
        }

        let resolvedName = displayName.flatMap { $0.isEmpty ? nil : $0 } ?? defaultDisplayName
        let profile = UserProfile(
            appleUserIdentifier: appleUserIdentifier,
            displayName: resolvedName
        )
        modelContext.insert(profile)
        return profile
    }

    /// Applies a cached Apple name when the stored profile still has the placeholder.
    static func applyCachedDisplayNameIfNeeded(
        to profile: UserProfile,
        modelContext: ModelContext
    ) throws {
        guard profile.displayName == defaultDisplayName || profile.displayName.isEmpty else { return }
        guard let cached = cachedDisplayName(forAppleUserIdentifier: profile.appleUserIdentifier) else { return }
        profile.displayName = cached
        try modelContext.save()
    }

    /// Trims and validates a user-entered display name (post-sign-in prompt).
    nonisolated static func sanitizedUserEnteredDisplayName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
