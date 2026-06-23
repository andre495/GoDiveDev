import Foundation

/// Display helpers for **`DiveBuddy`** on dive overview UI.
enum DiveBuddyPresentation {

    /// First token of **`displayName`** for compact labels (e.g. **Pat** from **Pat Lee**).
    nonisolated static func firstName(from displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Buddy" }
        let token = trimmed.split(whereSeparator: \.isWhitespace).first.map(String.init)
        guard let token, !token.isEmpty else { return trimmed }
        return token
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
