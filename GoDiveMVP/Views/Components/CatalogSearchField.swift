import SwiftUI

/// Compact oval list search field (logbook, field guide, explore).
struct CatalogSearchField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let placeholder: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(
                    isFocused ? AppTheme.Colors.tabSelected : AppTheme.Colors.tabUnselected
                )

            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search text")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        .frame(height: AppTheme.Layout.logbookSearchFieldHeight)
        .background {
            Capsule(style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    isFocused
                        ? AppTheme.SearchField.outlineFocusedColor
                        : AppTheme.SearchField.outlineColor,
                    lineWidth: isFocused
                        ? AppTheme.SearchField.outlineFocusedWidth
                        : AppTheme.SearchField.outlineWidth
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
