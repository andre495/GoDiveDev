import SwiftUI

/// Bottom-pinned Liquid Glass search for tagging / picker sheets (list-only filter).
struct TaggingSheetBottomSearchChrome: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let placeholder: String
    let searchFieldAccessibilityIdentifier: String
    let cancelAccessibilityIdentifier: String
    var onCancel: (() -> Void)?

    var body: some View {
        GlassEffectContainer {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                CatalogSearchField(
                    text: $searchText,
                    isFocused: $isSearchFocused,
                    placeholder: placeholder,
                    accessibilityIdentifier: searchFieldAccessibilityIdentifier
                )
                .frame(maxWidth: .infinity)

                if isSearchFocused {
                    CatalogSearchDismissButton(
                        action: cancelSearch,
                        accessibilityIdentifier: cancelAccessibilityIdentifier
                    )
                }
            }
            .appGlassChromeControlRowHeight()
            .appHeaderChromeIconForeground()
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.sm)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func cancelSearch() {
        isSearchFocused = false
        if let onCancel {
            onCancel()
        } else {
            searchText = ""
        }
    }
}
