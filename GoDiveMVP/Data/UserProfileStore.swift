import Foundation
import SwiftData

/// Persists and updates **`UserProfile`** rows for Sign in with Apple.
enum UserProfileStore {
    static let defaultDisplayName = "Diver"

    /// Formats **`PersonNameComponents`** from the first Sign in with Apple authorization.
    nonisolated static func displayName(from fullName: PersonNameComponents?) -> String? {
        guard let fullName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let formatted = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
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
}
