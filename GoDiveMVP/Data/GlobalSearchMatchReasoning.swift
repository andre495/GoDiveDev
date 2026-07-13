import Foundation

/// Explains *why* a search result matched — scans an entry's labeled `SearchField`s for the query
/// and produces italic "Label: text" reason lines (with windowed snippets for long text like notes).
enum GlobalSearchMatchReasoning {

    /// Reason lines for the fields that contain `query`, in field order, capped at `maxReasons`.
    /// Returns empty when the query is blank (nothing to explain).
    nonisolated static func reasons(
        query: String,
        fields: [GlobalSearchPresentation.SearchField],
        maxReasons: Int = 3,
        wordsAround: Int = 3
    ) -> [GlobalSearchPresentation.MatchReason] {
        guard let needle = CatalogSubstringSearch.normalizedQuery(query) else { return [] }

        var reasons: [GlobalSearchPresentation.MatchReason] = []
        var seen = Set<String>()
        for field in fields {
            guard field.value.lowercased().contains(needle) else { continue }
            let text = field.isSnippet
                ? GlobalSearchMatchSnippet.snippet(from: field.displayText, query: query, wordsAround: wordsAround)
                : field.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let dedupeKey = "\(field.label)|\(text.lowercased())"
            guard seen.insert(dedupeKey).inserted else { continue }
            reasons.append(GlobalSearchPresentation.MatchReason(label: field.label, text: text))
            if reasons.count >= maxReasons { break }
        }
        return reasons
    }
}

/// Windows a match inside longer text (e.g. dive notes) to a few words of context on each side,
/// with leading/trailing ellipses when truncated. Preserves the original casing of the source text.
enum GlobalSearchMatchSnippet {

    nonisolated static func snippet(
        from text: String,
        query: String,
        wordsAround: Int = 3
    ) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let needle = CatalogSubstringSearch.normalizedQuery(query),
              let matchRange = trimmed.range(of: needle, options: .caseInsensitive)
        else { return trimmed }

        // Expand the match to whole-word boundaries so partial-word matches read naturally.
        var wordStart = matchRange.lowerBound
        while wordStart > trimmed.startIndex {
            let previous = trimmed.index(before: wordStart)
            if trimmed[previous].isWhitespace { break }
            wordStart = previous
        }
        var wordEnd = matchRange.upperBound
        while wordEnd < trimmed.endIndex, !trimmed[wordEnd].isWhitespace {
            wordEnd = trimmed.index(after: wordEnd)
        }

        let matchedWord = String(trimmed[wordStart..<wordEnd])
        let beforeWords = trimmed[trimmed.startIndex..<wordStart].split(whereSeparator: \.isWhitespace)
        let afterWords = trimmed[wordEnd...].split(whereSeparator: \.isWhitespace)

        let leading = beforeWords.suffix(wordsAround)
        let trailing = afterWords.prefix(wordsAround)

        var pieces: [String] = leading.map(String.init)
        pieces.append(matchedWord)
        pieces.append(contentsOf: trailing.map(String.init))
        var result = pieces.joined(separator: " ")

        if beforeWords.count > leading.count {
            result = "… " + result
        }
        if afterWords.count > trailing.count {
            result += " …"
        }
        return result
    }
}
