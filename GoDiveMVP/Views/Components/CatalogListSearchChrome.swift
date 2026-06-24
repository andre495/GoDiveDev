import SwiftUI

/// Top search row with optional leading / trailing actions and **Cancel** while focused (logbook pattern).
struct CatalogListSearchChrome<LeadingActions: View, TrailingActions: View>: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let placeholder: String
    let searchFieldAccessibilityIdentifier: String
    let cancelAccessibilityIdentifier: String
    /// When **`false`**, the search field spans the row until focused (**Cancel** still appears while editing).
    var showsTrailingActions: Bool = true
    /// Keeps a fixed **Cancel** slot width while unfocused (Field Guide species search with no trailing actions).
    var reservesCancelSlotWhenUnfocused: Bool = false
    var onCancel: (() -> Void)?
    @ViewBuilder let leadingActions: () -> LeadingActions
    @ViewBuilder let trailingActions: () -> TrailingActions

    init(
        searchText: Binding<String>,
        isSearchFocused: FocusState<Bool>.Binding,
        placeholder: String,
        searchFieldAccessibilityIdentifier: String,
        cancelAccessibilityIdentifier: String,
        showsTrailingActions: Bool = true,
        reservesCancelSlotWhenUnfocused: Bool = false,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder leadingActions: @escaping () -> LeadingActions,
        @ViewBuilder trailingActions: @escaping () -> TrailingActions
    ) {
        _searchText = searchText
        _isSearchFocused = isSearchFocused
        self.placeholder = placeholder
        self.searchFieldAccessibilityIdentifier = searchFieldAccessibilityIdentifier
        self.cancelAccessibilityIdentifier = cancelAccessibilityIdentifier
        self.showsTrailingActions = showsTrailingActions
        self.reservesCancelSlotWhenUnfocused = reservesCancelSlotWhenUnfocused
        self.onCancel = onCancel
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            leadingActions()
            searchField

            if showsTrailingSlot {
                trailingSlot
            }
        }
        .animation(reservesCancelSlotWhenUnfocused ? nil : .easeInOut(duration: 0.2), value: isSearchFocused)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .appTopChromeVerticalPadding()
    }

    private var showsTrailingSlot: Bool {
        showsTrailingActions || isSearchFocused || reservesCancelSlotWhenUnfocused
    }

    @ViewBuilder
    private var searchField: some View {
        CatalogSearchField(
            text: $searchText,
            isFocused: $isSearchFocused,
            placeholder: placeholder,
            accessibilityIdentifier: searchFieldAccessibilityIdentifier
        )
        .frame(maxWidth: .infinity)
    }

    private var trailingSlot: some View {
        ZStack(alignment: .trailing) {
            if showsTrailingActions {
                trailingActions()
                    .opacity(isSearchFocused ? 0 : 1)
                    .allowsHitTesting(!isSearchFocused)
                    .accessibilityHidden(isSearchFocused)
            }

            cancelButton
                .opacity(isSearchFocused ? 1 : 0)
                .allowsHitTesting(isSearchFocused)
                .accessibilityHidden(!isSearchFocused)
        }
        .foregroundStyle(AppTheme.Colors.iconPrimary)
        .fixedSize(horizontal: true, vertical: false)
        .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
    }

    private var cancelButton: some View {
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

    private func cancelSearch() {
        isSearchFocused = false
        if let onCancel {
            onCancel()
        } else {
            searchText = ""
        }
    }
}

extension CatalogListSearchChrome where LeadingActions == EmptyView {
    init(
        searchText: Binding<String>,
        isSearchFocused: FocusState<Bool>.Binding,
        placeholder: String,
        searchFieldAccessibilityIdentifier: String,
        cancelAccessibilityIdentifier: String,
        showsTrailingActions: Bool = true,
        reservesCancelSlotWhenUnfocused: Bool = false,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder trailingActions: @escaping () -> TrailingActions
    ) {
        self.init(
            searchText: searchText,
            isSearchFocused: isSearchFocused,
            placeholder: placeholder,
            searchFieldAccessibilityIdentifier: searchFieldAccessibilityIdentifier,
            cancelAccessibilityIdentifier: cancelAccessibilityIdentifier,
            showsTrailingActions: showsTrailingActions,
            reservesCancelSlotWhenUnfocused: reservesCancelSlotWhenUnfocused,
            onCancel: onCancel,
            leadingActions: { EmptyView() },
            trailingActions: trailingActions
        )
    }
}
