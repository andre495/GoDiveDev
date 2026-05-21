import SwiftUI

/// Logbook top bar: site search inline with trailing actions (e.g. **+**).
struct LogbookTopChrome<TrailingActions: View>: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let statusBarSafeAreaTop: CGFloat
    @ViewBuilder let trailingActions: () -> TrailingActions

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            LogbookSiteSearchField(text: $searchText, isFocused: $isSearchFocused)

            Group {
                if isSearchFocused {
                    Button("Cancel", action: cancelSearch)
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("logbookSearchCancel")
                } else {
                    trailingActions()
                }
            }
            .foregroundStyle(isSearchFocused ? AppTheme.Colors.tabSelected : AppTheme.Colors.iconPrimary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
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

    private func cancelSearch() {
        isSearchFocused = false
        searchText = ""
    }
}
