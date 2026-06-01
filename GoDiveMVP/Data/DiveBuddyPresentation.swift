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
}
