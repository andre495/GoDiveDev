import SwiftUI

/// Scrollable matching dive-site tiles under the Explore map search field.
struct ExploreDiveSiteSearchSuggestionsView: View {
    let suggestions: [ExploreDiveSiteSearchSuggestion]
    let onSelect: (ExploreDiveSiteSearchSuggestion) -> Void

    private var panelHeight: CGFloat {
        AppTheme.Layout.exploreMapSearchSuggestionPanelHeight
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.md) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        ExploreDiveSiteRow(data: suggestion.rowDisplayData)
                            .equatable()
                            .frame(height: AppTheme.Layout.exploreMapSearchSuggestionRowHeight)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Explore.MapSiteSuggestion.\(suggestion.id)")
                    .accessibilityLabel("Show \(suggestion.siteName) on map")
                }
            }
            .padding(AppTheme.Spacing.sm)
        }
        .frame(height: panelHeight)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Explore.MapSiteSuggestions")
    }
}
