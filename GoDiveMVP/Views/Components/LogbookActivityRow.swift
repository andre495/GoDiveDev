import SwiftUI

/// Compact logbook row: name, persisted dive **#**, date · depth · duration.
struct LogbookActivityRow: View {
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    let activity: DiveActivity
    var showsDuplicateHint: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Text(Self.displayName(for: activity))
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(activity.diveNumberLogbookLabel)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .accessibilityLabel("Dive number \(diveNumberForAccessibility)")
            }

            Text(detailLine)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if showsDuplicateHint {
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
        if let n = activity.diveNumber {
            return String(n)
        }
        return "none"
    }

    private var detailLine: String {
        let dateStr = activity.startTime.formatted(date: .abbreviated, time: .omitted)
        let depth = DiveQuantityFormatting.depth(meters: activity.maxDepthMeters, system: diveDisplayUnitSystem)
        let dur = "\(activity.durationMinutes) min"
        return "\(dateStr) · \(depth) · \(dur)"
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
        diveNumber: 3,
        siteName: nil,
        rawImportVersion: "FITSwiftSDK-21.202.0"
    )
    return LogbookActivityRow(activity: a)
        .padding()
        .background(AppTheme.Colors.screenBackgroundGradient)
}
