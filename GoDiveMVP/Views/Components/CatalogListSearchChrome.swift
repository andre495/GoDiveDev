import SwiftUI

/// Trailing **×** control to end search and clear focus (Logbook / Explore / Field Guide pattern).
struct CatalogSearchDismissButton: View {
    let action: () -> Void
    let accessibilityIdentifier: String
    var usesGlassButtonStyle: Bool = true

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .appToolbarIconButtonLabel()
        }
        .modifier(CatalogSearchDismissButtonStyleModifier(usesGlass: usesGlassButtonStyle))
        .foregroundStyle(AppTheme.Colors.tabSelected)
        .accessibilityLabel("Cancel search")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CatalogSearchDismissButtonStyleModifier: ViewModifier {
    let usesGlass: Bool

    func body(content: Content) -> some View {
        if usesGlass {
            content.appStandaloneIconButtonStyle()
        } else {
            content.buttonStyle(.plain)
        }
    }
}

/// Top search row with optional leading / trailing actions and dismiss (**×**) while focused (logbook pattern).
struct CatalogListSearchChrome<LeadingActions: View, TrailingActions: View>: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let placeholder: String
    let searchFieldAccessibilityIdentifier: String
    let cancelAccessibilityIdentifier: String
    /// When **`false`**, the search field spans the row until focused (dismiss control still appears while editing).
    var showsTrailingActions: Bool = true
    /// Keeps a fixed dismiss slot width while unfocused (Field Guide species search with no trailing actions).
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
        GlassEffectContainer {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                leadingActions()
                searchField

                if showsTrailingSlot {
                    trailingSlot
                }
            }
            .appGlassChromeControlRowHeight()
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

    @ViewBuilder
    private var trailingSlot: some View {
        Group {
            if isSearchFocused {
                CatalogSearchDismissButton(
                    action: cancelSearch,
                    accessibilityIdentifier: cancelAccessibilityIdentifier
                )
            } else if showsTrailingActions {
                trailingActions()
            } else if reservesCancelSlotWhenUnfocused {
                Color.clear
                    .appGlassChromeControlRowHeight()
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(AppTheme.Colors.iconPrimary)
        .fixedSize(horizontal: true, vertical: false)
        .appGlassChromeControlRowHeight()
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
