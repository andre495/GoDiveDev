import SwiftUI

/// Compact site-name filter for **`LogbookTopChrome`** (inline with trailing actions).
struct LogbookSiteSearchField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        CatalogSearchField(
            text: $text,
            isFocused: $isFocused,
            placeholder: "Search by dive site",
            accessibilityIdentifier: "logbookSiteSearchField"
        )
    }
}

#Preview {
    @Previewable @State var query = "salt"
    @Previewable @FocusState var focused: Bool
    LogbookSiteSearchField(text: $query, isFocused: $focused)
        .padding()
}
