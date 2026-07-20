import Foundation
import SwiftData

/// Find-or-create **`DiveBuddy`** rows for the signed-in diver.
enum DiveBuddyCatalog {
    nonisolated static let maxDisplayNameLength = GoDiveInputSanitization.maxDisplayNameLength

    /// Do not tag a dive buddy when the name fuzzy-matches the owner's profile display name.
    nonisolated static func shouldExcludeBuddyName(_ buddyName: String, owner: UserProfile?) -> Bool {
        guard let owner else { return false }
        return DiveBuddyNameMatching.isLikelyDiverSelf(
            buddyName: buddyName,
            diverDisplayName: owner.displayName
        )
    }

    static func findOrCreate(
        displayName: String,
        contactsIdentifier: String? = nil,
        profilePhoto: Data? = nil,
        owner: UserProfile?,
        modelContext: ModelContext
    ) -> DiveBuddy {
        var rosterCache: DiveBuddyImportConsolidation.RosterCache?
        return findOrCreate(
            displayName: displayName,
            contactsIdentifier: contactsIdentifier,
            profilePhoto: profilePhoto,
            owner: owner,
            modelContext: modelContext,
            rosterCache: &rosterCache
        )
    }

    static func findOrCreate(
        displayName: String,
        contactsIdentifier: String? = nil,
        profilePhoto: Data? = nil,
        owner: UserProfile?,
        modelContext: ModelContext,
        rosterCache: inout DiveBuddyImportConsolidation.RosterCache
    ) -> DiveBuddy {
        var optionalCache: DiveBuddyImportConsolidation.RosterCache? = rosterCache
        let buddy = findOrCreate(
            displayName: displayName,
            contactsIdentifier: contactsIdentifier,
            profilePhoto: profilePhoto,
            owner: owner,
            modelContext: modelContext,
            rosterCache: &optionalCache
        )
        if let optionalCache {
            rosterCache = optionalCache
        }
        return buddy
    }

    private static func findOrCreate(
        displayName: String,
        contactsIdentifier: String?,
        profilePhoto: Data?,
        owner: UserProfile?,
        modelContext: ModelContext,
        rosterCache: inout DiveBuddyImportConsolidation.RosterCache?
    ) -> DiveBuddy {
        let trimmedName = GoDiveInputSanitization.trimmedAndCapped(
            displayName,
            maxLength: maxDisplayNameLength
        )
        let resolvedName = trimmedName.isEmpty ? "Buddy" : trimmedName

        if var cache = rosterCache,
           let cached = findInRosterCache(displayName: resolvedName, cache: &cache) {
            rosterCache = cache
            applyProfilePhotoIfNeeded(profilePhoto, to: cached)
            if let contactsIdentifier {
                cached.contactsIdentifier = contactsIdentifier
            }
            let preferred = DiveBuddyNameMatching.preferredDisplayName(
                imported: resolvedName,
                existing: cached.displayName
            )
            if cached.displayName != preferred {
                cached.displayName = preferred
            }
            registerInRosterCache(cached, cache: &cache)
            rosterCache = cache
            return cached
        }

        if let contactsIdentifier,
           let ownerProfileID = owner?.id,
           let existing = try? findByContactsIdentifier(
               contactsIdentifier,
               ownerProfileID: ownerProfileID,
               modelContext: modelContext
           ) {
            applyProfilePhotoIfNeeded(profilePhoto, to: existing)
            if existing.displayName != resolvedName {
                existing.displayName = resolvedName
            }
            registerInRosterCache(existing, rosterCache: &rosterCache)
            return existing
        }

        if let ownerProfileID = owner?.id,
           let existing = try? findByNormalizedName(
               resolvedName,
               ownerProfileID: ownerProfileID,
               modelContext: modelContext
           ),
           contactsIdentifier == nil || existing.contactsIdentifier == nil || existing.contactsIdentifier == contactsIdentifier
        {
            if let contactsIdentifier {
                existing.contactsIdentifier = contactsIdentifier
            }
            applyProfilePhotoIfNeeded(profilePhoto, to: existing)
            registerInRosterCache(existing, rosterCache: &rosterCache)
            return existing
        }

        if let ownerProfileID = owner?.id,
           let existing = try? findFuzzyMatch(
               displayName: resolvedName,
               ownerProfileID: ownerProfileID,
               modelContext: modelContext
           ),
           contactsIdentifier == nil || existing.contactsIdentifier == nil || existing.contactsIdentifier == contactsIdentifier
        {
            let preferred = DiveBuddyNameMatching.preferredDisplayName(
                imported: resolvedName,
                existing: existing.displayName
            )
            if existing.displayName != preferred {
                existing.displayName = preferred
            }
            if let contactsIdentifier {
                existing.contactsIdentifier = contactsIdentifier
            }
            applyProfilePhotoIfNeeded(profilePhoto, to: existing)
            registerInRosterCache(existing, rosterCache: &rosterCache)
            return existing
        }

        let buddy = DiveBuddy(
            displayName: resolvedName,
            profilePhoto: profilePhoto,
            contactsIdentifier: contactsIdentifier,
            owner: owner
        )
        modelContext.insert(buddy)
        if let owner {
            DiveBuddyOwnership.assignOwner(owner, to: buddy)
        }
        registerInRosterCache(buddy, rosterCache: &rosterCache)
        return buddy
    }

    private static func findInRosterCache(
        displayName: String,
        cache: inout DiveBuddyImportConsolidation.RosterCache
    ) -> DiveBuddy? {
        let key = normalizedNameKey(displayName)
        if let exact = cache[key] {
            return exact
        }
        let fuzzyMatches = cache.values.filter {
            DiveBuddyNameMatching.isLikelySamePerson(importedName: displayName, rosterName: $0.displayName)
        }
        guard !fuzzyMatches.isEmpty else { return nil }
        let scored = fuzzyMatches.map { buddy in
            (buddy, DiveBuddyNameMatching.matchScore(importedName: displayName, rosterName: buddy.displayName))
        }
        guard let topScore = scored.map(\.1).max() else { return nil }
        let top = scored.filter { $0.1 == topScore }.map(\.0)
        return top.count == 1 ? top[0] : nil
    }

    private static func registerInRosterCache(
        _ buddy: DiveBuddy,
        rosterCache: inout DiveBuddyImportConsolidation.RosterCache?
    ) {
        guard var cache = rosterCache else { return }
        registerInRosterCache(buddy, cache: &cache)
        rosterCache = cache
    }

    private static func registerInRosterCache(
        _ buddy: DiveBuddy,
        cache: inout DiveBuddyImportConsolidation.RosterCache
    ) {
        let key = normalizedNameKey(buddy.displayName)
        if cache[key] == nil {
            cache[key] = buddy
        }
    }

    /// Preloads the signed-in diver's roster for a multi-dive import batch.
    static func rosterCacheForImport(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> DiveBuddyImportConsolidation.RosterCache {
        var cache: DiveBuddyImportConsolidation.RosterCache = [:]
        let buddies = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
        for buddy in buddies where buddy.ownerProfileID == ownerProfileID {
            registerInRosterCache(buddy, cache: &cache)
        }
        return cache
    }

    static func findByContactsIdentifier(
        _ contactsIdentifier: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> DiveBuddy? {
        let all = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
        return all.first {
            $0.ownerProfileID == ownerProfileID && $0.contactsIdentifier == contactsIdentifier
        }
    }

    static func findByNormalizedName(
        _ displayName: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> DiveBuddy? {
        let key = normalizedNameKey(displayName)
        let all = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
        return all.first {
            $0.ownerProfileID == ownerProfileID && normalizedNameKey($0.displayName) == key
        }
    }

    /// Links import/manual names to roster buddies when normalized or token-heuristic names align.
    /// Returns `nil` when several roster rows tie at the top score (e.g. two "Mike …" people).
    static func findFuzzyMatch(
        displayName: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> DiveBuddy? {
        let candidates = try modelContext.fetch(FetchDescriptor<DiveBuddy>())
            .filter { $0.ownerProfileID == ownerProfileID }

        let scored: [(buddy: DiveBuddy, score: Int)] = candidates.compactMap { buddy in
            let score = DiveBuddyNameMatching.matchScore(
                importedName: displayName,
                rosterName: buddy.displayName
            )
            guard score > 0 else { return nil }
            return (buddy, score)
        }
        guard let topScore = scored.map(\.score).max() else { return nil }

        let topMatches = scored.filter { $0.score == topScore }.map(\.buddy)
        if topMatches.count == 1 {
            return topMatches[0]
        }
        return nil
    }

    nonisolated static func normalizedNameKey(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed.lowercased()
    }

    private static func applyProfilePhotoIfNeeded(_ data: Data?, to buddy: DiveBuddy) {
        guard let data, !data.isEmpty else { return }
        buddy.profilePhoto = data
    }
}
