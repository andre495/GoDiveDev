import SwiftUI

/// Explore catalog row — same card chrome as **`LogbookActivityRow`**.
struct ExploreDiveSiteRow: View, Equatable {
    let data: ExploreDiveSiteRowDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text(data.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(data.trailingLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Text(data.detailLine)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
    }
}

#Preview {
    let data = ExploreDiveSiteRowDisplayData(
        id: UUID(),
        displayName: "Salt Pier",
        trailingLabel: "★ 4",
        detailLine: "Bonaire · Caribbean · 12.0835, -68.2835"
    )
    return ExploreDiveSiteRow(data: data)
        .padding()
}
