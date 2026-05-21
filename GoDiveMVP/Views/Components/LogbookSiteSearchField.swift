import SwiftUI

/// Compact site-name filter for **`LogbookTopChrome`** (inline with trailing actions).
struct LogbookSiteSearchField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            TextField("Search by dive site", text: $text)
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logbookSiteSearchField")
    }
}

#Preview {
    @Previewable @State var query = "salt"
    @Previewable @FocusState var focused: Bool
    LogbookSiteSearchField(text: $query, isFocused: $focused)
        .padding()
}
