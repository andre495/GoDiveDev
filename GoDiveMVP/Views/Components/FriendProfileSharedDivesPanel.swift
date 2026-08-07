import SwiftUI

/// Friend-profile shared-activities page body (list only; title + filter are pager-pinned).
struct FriendProfileSharedDivesPanel: View {
    let rows: [DiveLogbookRowDisplayData]
    let isLoading: Bool
    let filter: FriendProfileActivityListFilter
    let onOpenDive: (UUID) -> Void

    var body: some View {
        Group {
            if isLoading {
                GoDiveRotateLoadingIndicator()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.lg)
            } else if rows.isEmpty {
                Text(emptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(
                        FriendProfileSharedDiveListPresentation.emptyAccessibilityIdentifier
                    )
            } else {
                LinkedDiveLogbookListRows(
                    rows: rows,
                    listAccessibilityIdentifier:
                        FriendProfileSharedDiveListPresentation.listAccessibilityIdentifier,
                    onOpenDive: onOpenDive
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(FriendProfileSharedDiveListPresentation.panelAccessibilityIdentifier)
    }

    private var emptyMessage: String {
        switch filter {
        case .all:
            return GoDiveFriendsPresentation.sharedLogbookEmptyMessage
        case .together:
            return FriendProfileSharedDiveListPresentation.emptyTogetherMessage
        }
    }
}
