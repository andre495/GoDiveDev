import SwiftUI

/// Trip rows on buddy detail — opens **`TripDetailView`**.
struct DiveBuddyTripListRows: View, Equatable {
    @Environment(\.openTripDetail) private var openTripDetail

    let rows: [DiveBuddyTripRowDisplayData]
    var listAccessibilityIdentifier: String

    init(
        rows: [DiveBuddyTripRowDisplayData],
        listAccessibilityIdentifier: String = "DiveBuddyTripListRows.List"
    ) {
        self.rows = rows
        self.listAccessibilityIdentifier = listAccessibilityIdentifier
    }

    static func == (lhs: DiveBuddyTripListRows, rhs: DiveBuddyTripListRows) -> Bool {
        lhs.rows == rhs.rows && lhs.listAccessibilityIdentifier == rhs.listAccessibilityIdentifier
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(rows) { row in
                tripRow(for: row)
            }
        }
        .accessibilityIdentifier(listAccessibilityIdentifier)
    }

    @ViewBuilder
    private func tripRow(for row: DiveBuddyTripRowDisplayData) -> some View {
        let label = DiveBuddyTripListRowView(row: row)

        if let openTripDetail {
            Button {
                openTripDetail(row.id)
            } label: {
                label
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("DiveBuddyDetails.Trip.\(row.id.uuidString)")
        } else {
            NavigationLink {
                TripDetailView(tripID: row.id)
                    .hidesBottomTabBarWhenPushed()
            } label: {
                label
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityIdentifier("DiveBuddyDetails.Trip.\(row.id.uuidString)")
        }
    }
}

private struct DiveBuddyTripListRowView: View {
    let row: DiveBuddyTripRowDisplayData

    private var secondaryDetailLine: String {
        DiveBuddyTripPresentation.listRowSecondaryDetail(
            phaseLabel: row.phaseLabel,
            secondaryDetailLine: row.secondaryDetailLine
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LogbookActivityRowLayout.contentSpacing) {
            Text(row.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if let linkedDiveCountLabel = row.linkedDiveCountLabel {
                HStack(spacing: 0) {
                    Text(secondaryDetailLine)
                    Text(" · ")
                    Text(linkedDiveCountLabel)
                        .foregroundStyle(AppTheme.Colors.accent)
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            } else {
                Text(secondaryDetailLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(LogbookActivityRowLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(DiveBuddyTripPresentation.listRowAccessibilityLabel(for: row))
    }
}
