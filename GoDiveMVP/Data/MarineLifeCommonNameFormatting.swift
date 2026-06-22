import Foundation
import SwiftData

/// Title-cases each word in catalog common names (e.g. "French angelfish" → "French Angelfish").
enum MarineLifeCommonNameFormatting: Sendable {
    nonisolated static func normalized(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed
            .split(whereSeparator: \.isWhitespace)
            .map { titleCaseToken(String($0)) }
            .joined(separator: " ")
    }

    nonisolated private static func titleCaseToken(_ token: String) -> String {
        token
            .split(separator: "-", omittingEmptySubsequences: false)
            .map { titleCaseDelimitedSegment(String($0), delimiter: "-") }
            .joined(separator: "-")
    }

    nonisolated private static func titleCaseDelimitedSegment(_ segment: String, delimiter: String) -> String {
        segment
            .split(separator: "'", omittingEmptySubsequences: false)
            .map { capitalizeWord(String($0)) }
            .joined(separator: "'")
    }

    nonisolated private static func capitalizeWord(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst().lowercased()
    }
}

/// Idempotent backfill for catalog rows created before common-name normalization.
enum MarineLifeCommonNameNormalization {
    static func normalizeStoredCatalogIfNeeded(modelContext: ModelContext) throws {
        let species = try modelContext.fetch(FetchDescriptor<MarineLife>())
        var changed = false
        for item in species {
            let normalized = MarineLifeCommonNameFormatting.normalized(item.commonName)
            guard item.commonName != normalized else { continue }
            item.commonName = normalized
            changed = true
        }
        if changed {
            try modelContext.save()
        }
    }
}
