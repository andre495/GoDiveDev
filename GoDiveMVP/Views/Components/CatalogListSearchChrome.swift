import SwiftUI

/// Top search row with optional trailing actions and **Cancel** while focused (logbook pattern).
struct CatalogListSearchChrome<TrailingActions: View>: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let placeholder: String
    let searchFieldAccessibilityIdentifier: String
    let cancelAccessibilityIdentifier: String
    var onCancel: (() -> Void)?
    @ViewBuilder let trailingActions: () -> TrailingActions

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            CatalogSearchField(
                text: $searchText,
                isFocused: $isSearchFocused,
                placeholder: placeholder,
                accessibilityIdentifier: searchFieldAccessibilityIdentifier
            )

            trailingSlot
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
    }

    private var trailingSlot: some View {
        ZStack(alignment: .trailing) {
            trailingActions()
                .opacity(isSearchFocused ? 0 : 1)
                .allowsHitTesting(!isSearchFocused)
                .accessibilityHidden(isSearchFocused)

            if isSearchFocused {
                Button(action: cancelSearch) {
                    Text("Cancel")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Colors.tabSelected)
                .accessibilityIdentifier(cancelAccessibilityIdentifier)
            }
        }
        .foregroundStyle(AppTheme.Colors.iconPrimary)
        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
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
