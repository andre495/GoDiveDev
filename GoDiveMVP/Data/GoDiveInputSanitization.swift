import Foundation

/// Central length / control-character rules for user-entered and imported free text (OWASP Phase 2).
///
/// Hazardous markup characters (`<`, `>`, quotes, etc.) are allowed in display strings because
/// SwiftUI **`Text(String)`** / **`Text(verbatim:)`** is not an HTML engine. Prefer **`Text(verbatim:)`**
/// (or a `String` variable) for API / user values — avoid **`Text("…\(untrusted)")`** which uses
/// **`LocalizedStringKey`** and can interpret Markdown.
enum GoDiveInputSanitization: Sendable {
    nonisolated static let maxSiteNameLength = 120
    nonisolated static let maxPlaceFieldLength = 120
    nonisolated static let maxDisplayNameLength = 80
    nonisolated static let maxNotesLength = 2_500
    nonisolated static let maxDanInsuranceNumberLength = 40
    nonisolated static let maxUserLogShortTextLength = 120

    /// Removes ASCII / Unicode control characters (keeps normal whitespace for later trim).
    ///
    /// Note: **`CharacterSet.controlCharacters`** includes newlines and tabs. Prefer
    /// **`strippingHazardousControlCharacters`** for multiline notes editors.
    nonisolated static func strippingControlCharacters(_ raw: String) -> String {
        String(raw.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
    }

    /// Removes hazardous control characters while keeping spaces, tabs, and newlines
    /// so **`TextEditor`** typing stays natural.
    nonisolated static func strippingHazardousControlCharacters(_ raw: String) -> String {
        String(
            raw.unicodeScalars.filter { scalar in
                if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                    return true
                }
                return !CharacterSet.controlCharacters.contains(scalar)
            }
        )
    }

    nonisolated static func trimmedAndCapped(_ raw: String, maxLength: Int) -> String {
        let cleaned = strippingControlCharacters(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard maxLength > 0 else { return cleaned }
        return String(cleaned.prefix(maxLength))
    }

    /// Live notes typing: strip hazardous controls + length cap; **do not trim**
    /// (preserves trailing spaces and newlines between words / paragraphs).
    nonisolated static func cappedNotesDraft(_ raw: String) -> String {
        let cleaned = strippingHazardousControlCharacters(raw)
        guard maxNotesLength > 0 else { return cleaned }
        return String(cleaned.prefix(maxNotesLength))
    }

    /// Trim + strip controls; empty → `nil`; otherwise capped.
    nonisolated static func sanitizedOptionalText(_ raw: String, maxLength: Int) -> String? {
        let capped = trimmedAndCapped(raw, maxLength: maxLength)
        return capped.isEmpty ? nil : capped
    }

    /// Persist notes: keep internal spaces/newlines; trim ends; empty → `nil`.
    nonisolated static func sanitizedNotes(_ raw: String) -> String? {
        let cleaned = strippingHazardousControlCharacters(raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(maxNotesLength))
    }

    nonisolated static func sanitizedDisplayName(_ raw: String) -> String? {
        sanitizedOptionalText(raw, maxLength: maxDisplayNameLength)
    }
}

/// Shared dive notes cap used by edit sheets and persist paths.
enum DiveNotesValidation: Sendable {
    nonisolated static let maxCharacterCount = GoDiveInputSanitization.maxNotesLength

    /// Live **`TextEditor`** binding — no trim so spaces / Return work normally.
    nonisolated static func draftNotes(_ raw: String) -> String {
        GoDiveInputSanitization.cappedNotesDraft(raw)
    }

    /// Length clamp for already-stored notes (trims ends; keeps internal whitespace).
    nonisolated static func cappedNotes(_ raw: String) -> String {
        GoDiveInputSanitization.sanitizedNotes(raw) ?? ""
    }
}
