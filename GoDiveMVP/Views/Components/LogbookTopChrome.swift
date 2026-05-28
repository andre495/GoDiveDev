import SwiftUI

/// Logbook top bar: site search inline with trailing actions (e.g. **+**).
struct LogbookTopChrome<TrailingActions: View>: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    @ViewBuilder let trailingActions: () -> TrailingActions

    var body: some View {
        CatalogListSearchChrome(
            searchText: $searchText,
            isSearchFocused: $isSearchFocused,
            placeholder: "Search by dive site",
            searchFieldAccessibilityIdentifier: "logbookSiteSearchField",
            cancelAccessibilityIdentifier: "logbookSearchCancel",
            trailingActions: trailingActions
        )
    }
}
