import SwiftUI

/// Kind filter for **My Activities** — adjacent to **`LogbookFeedScopeToggle`**.
struct LogbookMyActivitiesKindFilterMenu: View {
    @Binding var selection: LogbookMyActivitiesKindFilter

    var body: some View {
        Menu {
            Picker(
                "Activity kind",
                selection: $selection
            ) {
                ForEach(LogbookMyActivitiesKindFilter.allCases) { filter in
                    Text(LogbookMyActivitiesKindFilterPresentation.menuTitle(for: filter))
                        .tag(filter)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .appToolbarIconButtonLabel()
                .symbolVariant(selection == .all ? .none : .fill)
        }
        .appStandaloneIconButtonStyle()
        .foregroundStyle(
            selection == .all
                ? AppTheme.Colors.headerChromeIconForeground
                : AppTheme.Colors.accent
        )
        .accessibilityLabel(
            LogbookMyActivitiesKindFilterPresentation.filterButtonAccessibilityLabel(filter: selection)
        )
        .accessibilityIdentifier(
            LogbookMyActivitiesKindFilterPresentation.filterButtonAccessibilityIdentifier
        )
        .accessibilityHint("Opens activity kind filter")
    }
}
