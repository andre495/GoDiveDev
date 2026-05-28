import SwiftUI

/// Suggested tag filters under the logbook search field (oval outline buttons).
struct LogbookSearchTagSuggestionsView: View {
    let suggestions: [LogbookTagSearchSuggestion]
    let onSelect: (LogbookTagSearchSuggestion) -> Void

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: AppTheme.Spacing.sm)]

    var body: some View {
        ActivityTagsOutlinedSection(appliesLogbookOuterMargins: true) {
            EmptyView()
        } content: {
            LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        ActivityTagOvalChipLabel(title: suggestion.tagName)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Logbook.TagSuggestion.\(suggestion.id)")
                    .accessibilityLabel("Filter by tag \(suggestion.tagName)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Logbook.TagSuggestions")
    }
}

/// Confirmed tag filter with clear control inside the **Tags** section card.
struct LogbookActiveTagFilterChip: View {
    let tagName: String
    let onClear: () -> Void

    var body: some View {
        ActivityTagsOutlinedSection(appliesLogbookOuterMargins: true) {
            Button("Clear", action: onClear)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
        } content: {
            HStack(spacing: AppTheme.Spacing.sm) {
                ActivityTagOvalChipLabel(title: tagName, isEmphasized: true)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("Logbook.ActiveTagFilter")
        .accessibilityLabel("Filtering by tag \(tagName)")
    }
}
