import SwiftUI

/// Compact logbook row: name, dive **#**, date · depth · duration.
struct LogbookActivityRow: View, Equatable {
    let data: DiveLogbookRowDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text(data.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(data.diveNumberLabel)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .accessibilityLabel("Dive number \(diveNumberForAccessibility)")
            }

            Text(data.detailLine)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if data.showsDuplicateHint {
                Text("Possible duplicate")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.mutedText)
                    .accessibilityLabel("Possible duplicate dive in log")
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

    private var diveNumberForAccessibility: String {
        let trimmed = data.diveNumberLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "-" { return "none" }
        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    /// Dive site name when set; otherwise **"New Dive"**.
    static func displayName(for activity: DiveActivity) -> String {
        if let name = activity.siteName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return "New Dive"
    }
}

#Preview {
    let a = DiveActivity(
        deviceSource: .garminMK3,
        sourceDiveId: "fit-123-0-456",
        startTime: .now,
        durationMinutes: 34,
        maxDepthMeters: 22.5,
        diveNumber: 12
    )
    let data = DiveLogbookRowDisplayData(
        id: a.id,
        displayName: "Salt Pier",
        diveNumberLabel: "#12",
        detailLine: "May 17, 2026 · 74 ft · 34 min",
        showsDuplicateHint: false
    )
    return LogbookActivityRow(data: data)
        .padding()
}
