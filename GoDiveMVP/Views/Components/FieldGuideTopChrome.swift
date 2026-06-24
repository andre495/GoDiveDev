import SwiftUI

/// Field Guide top bar — global species search (hub root).
struct FieldGuideTopChrome: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let statusBarSafeAreaTop: CGFloat
    let onAddSpecies: () -> Void

    var body: some View {
        CatalogListSearchChrome(
            searchText: $searchText,
            isSearchFocused: $isSearchFocused,
            placeholder: FieldGuideSpeciesSearchEnvironment.searchPlaceholder,
            searchFieldAccessibilityIdentifier: FieldGuideSpeciesSearchEnvironment.searchFieldAccessibilityIdentifier,
            cancelAccessibilityIdentifier: FieldGuideSpeciesSearchEnvironment.cancelAccessibilityIdentifier,
            showsTrailingActions: true,
            reservesCancelSlotWhenUnfocused: true,
            trailingActions: {
                FieldGuideMarineLifeAddToolbarButton(action: onAddSpecies)
            }
        )
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) {
            if statusBarSafeAreaTop > 0.5 {
                AppStatusBarEdgeScrim(safeAreaTop: statusBarSafeAreaTop)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: AppHeaderMetrics.HeightKey.self, value: proxy.size.height)
            }
        }
    }
}
