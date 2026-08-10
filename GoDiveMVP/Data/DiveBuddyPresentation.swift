import Foundation

/// Display helpers for **`DiveBuddy`** on dive overview UI.
enum DiveBuddyPresentation {

    nonisolated static let addBuddySheetCancelAccessibilityIdentifier = "DiveActivityAddBuddySheet.Cancel"
    nonisolated static let addBuddySheetDoneAccessibilityIdentifier = "DiveActivityAddBuddySheet.Done"

    /// Two-line name for trip buddy grids: given names on line 1, family name on line 2.
    struct TwoLineDisplayName: Equatable, Sendable {
        var firstLine: String
        /// `nil` when the display name is a single token (no last name).
        var secondLine: String?
    }

    /// First token of **`displayName`** for compact labels (e.g. **Pat** from **Pat Lee**).
    nonisolated static func firstName(from displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Buddy" }
        let token = trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init)
        guard let token, !token.isEmpty else { return trimmed }
        return token
    }

    /// Splits a display name for stacked trip-buddy captions.
    /// - One word → first line only.
    /// - Two or more words → everything before the last space is line 1; the last word is line 2.
    nonisolated static func twoLineDisplayName(from displayName: String) -> TwoLineDisplayName {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return TwoLineDisplayName(firstLine: "Buddy", secondLine: nil)
        }
        let tokens = trimmed
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let last = tokens.last else {
            return TwoLineDisplayName(firstLine: trimmed, secondLine: nil)
        }
        guard tokens.count >= 2 else {
            return TwoLineDisplayName(firstLine: last, secondLine: nil)
        }
        let firstLine = tokens.dropLast().joined(separator: " ")
        return TwoLineDisplayName(firstLine: firstLine, secondLine: last)
    }

    /// Up to two initials for avatar placeholders (e.g. **JB** from **Judy Belair**).
    nonisolated static func initials(from displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "B" }
        let tokens = trimmed
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        guard let first = tokens.first else { return "B" }
        guard tokens.count > 1, let last = tokens.last, last != first else {
            return String(first.prefix(1)).uppercased()
        }
        return "\(first.prefix(1))\(last.prefix(1))".uppercased()
    }
}
