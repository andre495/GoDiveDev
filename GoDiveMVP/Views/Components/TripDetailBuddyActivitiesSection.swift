import SwiftUI

/// Trip detail **Trip Activities** — buddy-shared dives/snorkels inside the trip dates.
struct TripDetailBuddyActivitiesSection: View {
    let rows: [LogbookBuddyFeedPresentation.Row]
    let isLoading: Bool
    let onOpenRow: (LogbookBuddyFeedPresentation.Row) -> Void

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                HStack(spacing: AppTheme.Spacing.sm) {
                    GoDiveRotateLoadingIndicator()
                    Text(TripDetailBuddyActivitiesPresentation.loadingMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("TripDetail.BuddyActivities.Loading")
            } else if rows.isEmpty {
                Text(TripDetailBuddyActivitiesPresentation.emptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("TripDetail.BuddyActivities.Empty")
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(rows) { row in
                        Button {
                            onOpenRow(row)
                        } label: {
                            TripDetailBuddyActivityRow(row: row)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("TripDetail.BuddyActivities.Row.\(row.id)")
                    }
                }
                .accessibilityIdentifier("TripDetail.BuddyActivities.List")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("TripDetail.BuddyActivitiesSection")
    }
}

private struct TripDetailBuddyActivityRow: View {
    let row: LogbookBuddyFeedPresentation.Row

    private var kindSymbol: String {
        row.dive.resolvedActivityKind == .snorkel
            ? LogbookActivityRowPresentation.snorkelLeadingSymbolName
            : LogbookActivityRowPresentation.scubaDiveLeadingSymbolName
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            FriendSharedMapOwnerAvatarView(
                displayName: row.friendDisplayName,
                photoURL: row.friendPhotoURL,
                diameter: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(row.friendDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                Text(TripDetailBuddyActivitiesPresentation.subtitleLine(for: row))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: kindSymbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)
        }
        .padding(LogbookActivityRowLayout.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(row.friendDisplayName), \(TripDetailBuddyActivitiesPresentation.subtitleLine(for: row))"
        )
    }
}
