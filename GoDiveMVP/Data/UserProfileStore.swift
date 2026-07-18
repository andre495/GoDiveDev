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

    /// Prefer a fresh Apple **`fullName`**, then cached name, then a sign-out-surviving returning-user hint.
    nonisolated static func resolvedDisplayName(
        appleProvided: String?,
        appleUserIdentifier: String
    ) -> String? {
        if let appleProvided, !appleProvided.isEmpty {
            return appleProvided
        }
        if let cached = cachedDisplayName(forAppleUserIdentifier: appleUserIdentifier) {
            return cached
        }
        return ReturningAccountHints.rememberedDisplayName(forAppleUserIdentifier: appleUserIdentifier)
    }

    nonisolated static func profile(
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

    /// Applies Sign in with Apple name to **`displayName`**: fresh **`fullName`** wins; else cached name upgrades placeholder **Diver**.
    nonisolated static func applyDisplayNameFromApple(
        to profile: UserProfile,
        appleProvided: String?,
        appleUserIdentifier: String,
        modelContext: ModelContext
    ) throws {
        if let appleProvided, !appleProvided.isEmpty {
            profile.displayName = appleProvided
            try modelContext.save()
            return
        }
        try applyCachedDisplayNameIfNeeded(to: profile, modelContext: modelContext)
    }

    /// Applies a cached / remembered Apple name when the stored profile still has the placeholder.
    nonisolated static func applyCachedDisplayNameIfNeeded(
        to profile: UserProfile,
        modelContext: ModelContext
    ) throws {
        guard profile.displayName == defaultDisplayName || profile.displayName.isEmpty else { return }
        let restored =
            cachedDisplayName(forAppleUserIdentifier: profile.appleUserIdentifier)
            ?? ReturningAccountHints.rememberedDisplayName(
                forAppleUserIdentifier: profile.appleUserIdentifier
            )
        guard let restored else { return }
        profile.displayName = restored
        try modelContext.save()
    }

    /// Upgrades a placeholder **Diver** name from an explicit restored value (e.g. Firestore).
    @discardableResult
    nonisolated static func applyRestoredDisplayNameIfNeeded(
        to profile: UserProfile,
        restoredName: String?,
        modelContext: ModelContext
    ) throws -> Bool {
        let trimmed = restoredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed != defaultDisplayName else { return false }
        guard profile.displayName == defaultDisplayName || profile.displayName.isEmpty else { return false }
        profile.displayName = trimmed
        cacheDisplayName(trimmed, forAppleUserIdentifier: profile.appleUserIdentifier)
        try modelContext.save()
        return true
    }

    /// Trims and validates a user-entered display name (post-sign-in prompt).
    nonisolated static func sanitizedUserEnteredDisplayName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Trims a DAN membership number; empty input clears the field. Letters, digits, spaces, and hyphens only (max 40).
    nonisolated static func sanitizedDanInsuranceNumber(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -")
        let filteredScalars = trimmed.unicodeScalars.filter { allowed.contains($0) }
        let filtered = String(String.UnicodeScalarView(filteredScalars))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !filtered.isEmpty else { return nil }
        return String(filtered.prefix(40))
    }

    /// Applies logged-out onboarding activity picks to a profile row.
    static func applyActivitySelection(
        _ selection: UserOnboardingActivitySelection,
        to profile: UserProfile,
        modelContext: ModelContext
    ) throws {
        profile.doesScubaDiving = selection.doesScubaDiving
        profile.doesFreeDiving = selection.doesFreeDiving
        profile.doesSnorkeling = selection.doesSnorkeling
        try modelContext.save()
    }
}
