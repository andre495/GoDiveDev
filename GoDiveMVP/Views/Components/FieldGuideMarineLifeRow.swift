import SwiftUI

/// Field Guide catalog row — same card chrome as **`LogbookActivityRow`** / **`ExploreDiveSiteRow`**.
struct FieldGuideMarineLifeRow: View, Equatable {
    let data: FieldGuidePresentation.MarineLifeRowDisplayData
    /// Optional third line (e.g. trip sighting count on **`TripDetailMarineLifeSection`** cards).
    var footerLine: String?

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

            if let footerLine, !footerLine.isEmpty {
                Text(footerLine)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }
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

    static func == (lhs: FieldGuideMarineLifeRow, rhs: FieldGuideMarineLifeRow) -> Bool {
        lhs.data == rhs.data && lhs.footerLine == rhs.footerLine
    }
}

#Preview {
    let data = FieldGuidePresentation.MarineLifeRowDisplayData(
        marineLifeUUID: "marine-life-preview",
        displayName: "French Angelfish",
        trailingLabel: "Fish",
        detailLine: "Pomacanthus paru · up to 18 in · avg 45 ft",
        isSighted: false
    )
    return FieldGuideMarineLifeRow(data: data)
        .padding()
}
