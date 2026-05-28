import SwiftUI

/// Compact logbook row: oval dive **#** (top leading), name + stats, optional oldest-media preview (trailing).
struct LogbookActivityRow: View, Equatable {
    let data: DiveLogbookRowDisplayData

    @State private var textColumnHeight: CGFloat = 0

    static func == (lhs: LogbookActivityRow, rhs: LogbookActivityRow) -> Bool {
        lhs.data == rhs.data
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                ActivityTagOvalChipLabel(title: data.diveNumberLabel)
                    .accessibilityLabel("Dive number \(diveNumberForAccessibility)")

                Text(data.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

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
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: LogbookRowTextColumnHeightKey.self,
                        value: proxy.size.height
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let previewMediaPhotoID = data.previewMediaPhotoID {
                Spacer(minLength: AppTheme.Spacing.md)

                LogbookRowMediaPreviewView(
                    photoID: previewMediaPhotoID,
                    extent: textColumnHeight
                )
            }
        }
        .onPreferenceChange(LogbookRowTextColumnHeightKey.self) { height in
            textColumnHeight = height
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
    nonisolated static func displayName(resolvedSiteName: String?) -> String {
        let trimmed = resolvedSiteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "New Dive" : trimmed
    }

    @MainActor
    static func displayName(for activity: DiveActivity) -> String {
        displayName(resolvedSiteName: activity.resolvedSiteName)
    }
}

private struct LogbookRowTextColumnHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    let a = DiveActivity(
        source: .garminMK3,
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
        showsDuplicateHint: false,
        previewMediaPhotoID: nil
    )
    return LogbookActivityRow(data: data)
        .padding()
}
