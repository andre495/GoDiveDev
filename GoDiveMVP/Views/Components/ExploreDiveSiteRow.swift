import SwiftUI

/// Explore catalog row — same card chrome as **`LogbookActivityRow`**.
struct ExploreDiveSiteRow: View, Equatable {
    let data: ExploreDiveSiteRowDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text(data.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let diveCountLabel = data.diveCountLabel {
                    Text(diveCountLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
            }

            Text(data.coordinateLine)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if let placeLine = data.placeLine {
                Text(placeLine)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [data.displayName, data.coordinateLine]
        if let diveCountLabel = data.diveCountLabel {
            parts.append(diveCountLabel)
        }
        if let placeLine = data.placeLine {
            parts.append(placeLine)
        }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    let data = ExploreDiveSiteRowDisplayData(
        id: UUID(),
        displayName: "Salt Pier",
        diveCountLabel: "12 dives",
        coordinateLine: "12.084°, -68.283°",
        placeLine: "Caribbean, Bonaire"
    )
    return ExploreDiveSiteRow(data: data)
        .padding()
}
