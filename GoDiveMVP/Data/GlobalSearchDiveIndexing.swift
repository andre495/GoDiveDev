import Foundation

/// Date helpers for the dive search index — spelled-out month name and 4-digit year tokens
/// (so `march` / `2026` match). Pure + `nonisolated` so they can be unit tested and run off-main.
enum GlobalSearchDiveIndexing {

    /// Standalone month names for `locale` (e.g. `January`…`December`). Built once per catalog
    /// rebuild and passed into `dateSearchTokens` so we don't allocate a formatter per dive.
    nonisolated static func monthSymbols(locale: Locale = .current) -> [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.standaloneMonthSymbols ?? formatter.monthSymbols ?? []
    }

    /// 4-digit year without grouping separators (e.g. `2026`), or `nil` if undecodable.
    nonisolated static func yearString(for date: Date, calendar: Calendar = .current) -> String? {
        guard let year = calendar.dateComponents([.year], from: date).year else { return nil }
        return String(year)
    }

    /// Spelled-out month name (e.g. `March`) for `date`, or `nil` if undecodable.
    nonisolated static func monthName(
        for date: Date,
        calendar: Calendar = .current,
        monthSymbols: [String]
    ) -> String? {
        guard let month = calendar.dateComponents([.month], from: date).month,
              month >= 1, month <= monthSymbols.count
        else { return nil }
        return monthSymbols[month - 1]
    }

    /// Search tokens for a dive date: 4-digit year (no grouping separators) plus the spelled-out
    /// month, so `march` or `2026` match.
    nonisolated static func dateSearchTokens(
        for date: Date,
        calendar: Calendar = .current,
        monthSymbols: [String]
    ) -> [String] {
        var tokens: [String] = []
        if let year = yearString(for: date, calendar: calendar) {
            tokens.append(year)
        }
        if let month = monthName(for: date, calendar: calendar, monthSymbols: monthSymbols) {
            tokens.append(month)
        }
        return tokens
    }
}
