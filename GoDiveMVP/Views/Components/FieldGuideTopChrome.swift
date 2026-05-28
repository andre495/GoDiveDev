import SwiftUI

/// Field Guide top bar: species search (logbook-style row; no trailing action).
struct FieldGuideTopChrome: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        CatalogListSearchChrome(
            searchText: $searchText,
            isSearchFocused: $isSearchFocused,
            placeholder: "Search species",
            searchFieldAccessibilityIdentifier: "fieldGuideSpeciesSearchField",
            cancelAccessibilityIdentifier: "fieldGuideSearchCancel"
        ) {
            EmptyView()
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }
}
