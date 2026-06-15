import SwiftUI

/// Expandable linked-dive lists (buddy detail, trip detail) — standard logbook row chrome.
struct LinkedDiveLogbookListRows: View, Equatable {
    let rows: [DiveLogbookRowDisplayData]
    var listAccessibilityIdentifier: String
    var onOpenDive: ((UUID) -> Void)?

    init(
        rows: [DiveLogbookRowDisplayData],
        listAccessibilityIdentifier: String = "LinkedDiveLogbookListRows.List",
        onOpenDive: ((UUID) -> Void)? = nil
    ) {
        self.rows = rows
        self.listAccessibilityIdentifier = listAccessibilityIdentifier
        self.onOpenDive = onOpenDive
    }

    static func == (lhs: LinkedDiveLogbookListRows, rhs: LinkedDiveLogbookListRows) -> Bool {
        lhs.rows == rhs.rows
            && lhs.listAccessibilityIdentifier == rhs.listAccessibilityIdentifier
            && (lhs.onOpenDive == nil) == (rhs.onOpenDive == nil)
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(rows) { row in
                if let onOpenDive {
                    Button {
                        onOpenDive(row.id)
                    } label: {
                        LogbookActivityRow(data: row)
                            .equatable()
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(value: row.id) {
                        LogbookActivityRow(data: row)
                            .equatable()
                    }
                    .buttonStyle(.plain)
                    .navigationLinkIndicatorVisibility(.hidden)
                }
            }
        }
        .accessibilityIdentifier(listAccessibilityIdentifier)
    }
}
