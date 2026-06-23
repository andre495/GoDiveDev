import SwiftUI

/// Field Guide top bar — hub title + species search above the catalog hub.
struct FieldGuideTopChrome: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let showsSpeciesSearch: Bool
    var showsHubTitle = false
    let statusBarSafeAreaTop: CGFloat

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if showsHubTitle {
                Text("Reef Life Field Guide")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("FieldGuide.Hub.Title")
            }

            if showsSpeciesSearch {
                fieldGuideSearchRow
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
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

    private var fieldGuideSearchRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            CatalogSearchField(
                text: $searchText,
                isFocused: $isSearchFocused,
                placeholder: "Search Marine Life",
                accessibilityIdentifier: "fieldGuideSpeciesSearchField"
            )
            .frame(maxWidth: .infinity)

            if isSearchFocused {
                Button {
                    isSearchFocused = false
                    searchText = ""
                } label: {
                    Text("Cancel")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Colors.tabSelected)
                .accessibilityIdentifier("fieldGuideSearchCancel")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
    }
}
