import Foundation

/// Shared map-overview notes display for dive and snorkel activities.
enum ActivityNotesPresentation: Sendable {
    nonisolated static let emptyDisplayValue = "—"
    nonisolated static let sectionTitle = "Notes"

    /// Trimmed notes body, or **`emptyDisplayValue`** when unset / blank.
    nonisolated static func displayValue(notes: String?) -> String {
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? emptyDisplayValue : trimmed
    }

    nonisolated static func hasContent(notes: String?) -> Bool {
        displayValue(notes: notes) != emptyDisplayValue
    }
}
