import SwiftUI

/// Divider list chrome matching Home notifications (inset dividers under leading art).
struct TaggingSheetListChrome<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One selectable row plus an inset divider (omit divider on the last row).
struct TaggingSheetListRowContainer<Content: View>: View {
    let showsDivider: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
            if showsDivider {
                Divider()
                    .padding(.leading, TaggingSheetSelectionPresentation.dividerLeadingInset)
            }
        }
    }
}
