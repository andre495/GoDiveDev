import CoreGraphics
import Foundation

/// Shared metrics and selection chrome for tagging / multi-select picker sheets.
enum TaggingSheetSelectionPresentation: Sendable {
    /// Leading avatar / thumb / placeholder diameter (matches notification center).
    nonisolated static let leadingArtDiameter: CGFloat = 44

    nonisolated static let titleLineLimit = 1
    nonisolated static let subtitleLineLimit = 2

    nonisolated static let selectedCheckmarkSystemName = "checkmark.circle.fill"
    nonisolated static let unselectedCheckmarkSystemName = "circle"

    nonisolated static let tagPlaceholderSystemName = "tag.fill"
    nonisolated static let sitePlaceholderSystemName = "mappin.and.ellipse"
    nonisolated static let countryPlaceholderSystemName = "globe"

    /// Leading inset for row dividers (art diameter + horizontal gap).
    nonisolated static var dividerLeadingInset: CGFloat {
        leadingArtDiameter + 16 // AppTheme.Spacing.md
    }

    nonisolated static func selectionSystemName(isSelected: Bool) -> String {
        isSelected ? selectedCheckmarkSystemName : unselectedCheckmarkSystemName
    }

    /// Case-insensitive substring match used by tagging-sheet bottom search.
    nonisolated static func matchesSearchQuery(_ text: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
