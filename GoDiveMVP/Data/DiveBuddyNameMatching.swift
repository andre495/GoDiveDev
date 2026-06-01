import Foundation

/// Heuristic name matching for linking import buddy strings to an existing roster person.
enum DiveBuddyNameMatching {
    /// Whitespace-separated tokens from a normalized display name.
    nonisolated static func nameTokens(_ name: String) -> [String] {
        DiveBuddyCatalog.normalizedNameKey(name)
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    /// Whether an imported label likely refers to the same person as a roster display name.
    nonisolated static func isLikelySamePerson(importedName: String, rosterName: String) -> Bool {
        let importedKey = DiveBuddyCatalog.normalizedNameKey(importedName)
        let rosterKey = DiveBuddyCatalog.normalizedNameKey(rosterName)
        guard !importedKey.isEmpty, !rosterKey.isEmpty else { return false }
        if importedKey == rosterKey { return true }

        let importedTokens = nameTokens(importedName)
        let rosterTokens = nameTokens(rosterName)
        guard !importedTokens.isEmpty, !rosterTokens.isEmpty else { return false }

        if importedTokens == rosterTokens { return true }
        if Set(importedTokens) == Set(rosterTokens) { return true }

        if importedTokens.count == 1, importedTokens[0] == rosterTokens[0] { return true }
        if rosterTokens.count == 1, rosterTokens[0] == importedTokens[0] { return true }

        if importedTokens.count >= 2, rosterTokens.count >= 2 {
            if importedTokens[0] == rosterTokens[0],
               importedTokens[importedTokens.count - 1] == rosterTokens[rosterTokens.count - 1] {
                return true
            }
        }

        return false
    }

    /// Whether a buddy label likely names the signed-in diver (import / tagging should skip).
    nonisolated static func isLikelyDiverSelf(buddyName: String, diverDisplayName: String) -> Bool {
        let diver = diverDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !diver.isEmpty else { return false }
        if diver.caseInsensitiveCompare("Diver") == .orderedSame { return false }
        return isLikelySamePerson(importedName: buddyName, rosterName: diver)
    }

    /// Higher scores win when several roster rows fuzzy-match; `0` means no match.
    nonisolated static func matchScore(importedName: String, rosterName: String) -> Int {
        guard isLikelySamePerson(importedName: importedName, rosterName: rosterName) else { return 0 }

        let importedKey = DiveBuddyCatalog.normalizedNameKey(importedName)
        let rosterKey = DiveBuddyCatalog.normalizedNameKey(rosterName)
        if importedKey == rosterKey { return 100 }

        let importedTokens = nameTokens(importedName)
        let rosterTokens = nameTokens(rosterName)
        if importedTokens == rosterTokens { return 95 }
        if Set(importedTokens) == Set(rosterTokens) { return 90 }

        if importedTokens.count >= 2, rosterTokens.count >= 2,
           importedTokens[0] == rosterTokens[0],
           importedTokens[importedTokens.count - 1] == rosterTokens[rosterTokens.count - 1] {
            return 85
        }

        return 80
    }

    /// Prefers the more complete label when merging import text with roster.
    nonisolated static func preferredDisplayName(imported: String, existing: String) -> String {
        let importedTokens = nameTokens(imported)
        let existingTokens = nameTokens(existing)
        let importedTrimmed = imported.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingTrimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)

        if importedTokens.count > existingTokens.count {
            return String(importedTrimmed.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        }
        if existingTokens.count > importedTokens.count {
            return existingTrimmed
        }
        if importedTrimmed.count > existingTrimmed.count {
            return String(importedTrimmed.prefix(DiveBuddyCatalog.maxDisplayNameLength))
        }
        return existingTrimmed
    }
}
