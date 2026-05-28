import SwiftUI

/// Logbook top bar: site search, optional tag suggestions / active tag filter, trailing actions.
struct LogbookTopChrome<TrailingActions: View>: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let tagSuggestions: [LogbookTagSearchSuggestion]
    let activeTagFilter: String?
    let onSelectTagSuggestion: (LogbookTagSearchSuggestion) -> Void
    let onClearTagFilter: () -> Void
    @ViewBuilder let trailingActions: () -> TrailingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CatalogListSearchChrome(
                searchText: $searchText,
                isSearchFocused: $isSearchFocused,
                placeholder: "Search Activities",
                searchFieldAccessibilityIdentifier: "logbookSiteSearchField",
                cancelAccessibilityIdentifier: "logbookSearchCancel",
                onCancel: {
                    searchText = ""
                    onClearTagFilter()
                },
                trailingActions: trailingActions
            )

            if let activeTagFilter {
                LogbookActiveTagFilterChip(
                    tagName: activeTagFilter,
                    onClear: onClearTagFilter
                )
            } else if !tagSuggestions.isEmpty {
                LogbookSearchTagSuggestionsView(
                    suggestions: tagSuggestions,
                    onSelect: onSelectTagSuggestion
                )
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }
}
