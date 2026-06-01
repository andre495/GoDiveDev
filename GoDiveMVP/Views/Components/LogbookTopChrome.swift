import SwiftUI

/// Logbook top bar: site search, optional tag / buddy suggestions, trailing actions.
struct LogbookTopChrome<TrailingActions: View>: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let tagSuggestions: [LogbookTagSearchSuggestion]
    let buddySuggestions: [LogbookBuddySearchSuggestion]
    let activeTagFilter: String?
    let activeBuddyFilter: String?
    let onSelectTagSuggestion: (LogbookTagSearchSuggestion) -> Void
    let onSelectBuddySuggestion: (LogbookBuddySearchSuggestion) -> Void
    let onClearConfirmedFilters: () -> Void
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
                    onClearConfirmedFilters()
                },
                trailingActions: trailingActions
            )

            if let activeBuddyFilter {
                LogbookActiveBuddyFilterChip(
                    buddyName: activeBuddyFilter,
                    onClear: onClearConfirmedFilters
                )
            } else if let activeTagFilter {
                LogbookActiveTagFilterChip(
                    tagName: activeTagFilter,
                    onClear: onClearConfirmedFilters
                )
            } else {
                if !buddySuggestions.isEmpty {
                    LogbookSearchBuddySuggestionsView(
                        suggestions: buddySuggestions,
                        onSelect: onSelectBuddySuggestion
                    )
                }
                if !tagSuggestions.isEmpty {
                    LogbookSearchTagSuggestionsView(
                        suggestions: tagSuggestions,
                        onSelect: onSelectTagSuggestion
                    )
                }
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }
}
