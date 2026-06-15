import SwiftUI

/// Compact logbook row layout tokens (list tiles + trailing preview).
enum LogbookActivityRowLayout {
    static let contentSpacing: CGFloat = 4
    static let cardPadding: CGFloat = AppTheme.Spacing.sm
    static let previewGap: CGFloat = AppTheme.Spacing.sm
    static let cardCornerRadius: CGFloat = 10
}

/// Compact logbook row: oval dive **#** (top leading), name + stats, optional oldest-media preview (trailing).
struct LogbookActivityRow: View, Equatable {
    let data: DiveLogbookRowDisplayData
    /// When set, tapping the trailing media thumbnail runs this (open dive Media tab) instead of the row link.
    var onTapMediaPreview: (() -> Void)?

    @State private var textColumnHeight: CGFloat = 0

    /// Closures are excluded from equality on purpose; row identity/content lives in **`data`**.
    static func == (lhs: LogbookActivityRow, rhs: LogbookActivityRow) -> Bool {
        lhs.data == rhs.data
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: LogbookActivityRowLayout.contentSpacing) {
                ActivityTagOvalChipLabel(title: data.diveNumberLabel, isCompact: true)
                    .accessibilityLabel("Dive number \(diveNumberForAccessibility)")

                Text(data.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(data.detailLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if data.showsDuplicateHint {
                    Text("Possible duplicate")
                        .font(.caption2)
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
                Spacer(minLength: LogbookActivityRowLayout.previewGap)

                mediaPreview(photoID: previewMediaPhotoID)
            }
        }
        .onPreferenceChange(LogbookRowTextColumnHeightKey.self) { height in
            textColumnHeight = height
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
    }

    /// Trailing thumbnail. When **`onTapMediaPreview`** is set it becomes a borderless button so the tap
    /// opens the dive's Media tab (and does not trigger the surrounding row **`NavigationLink`**).
    @ViewBuilder
    private func mediaPreview(photoID: UUID) -> some View {
        let preview = LogbookRowMediaPreviewView(photoID: photoID, extent: textColumnHeight)
        if let onTapMediaPreview {
            Button(action: onTapMediaPreview) {
                preview
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Open dive media")
            .accessibilityHint("Opens this dive's media on the selected photo")
        } else {
            preview
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
        previewMediaPhotoID: nil,
        startTime: a.startTime
    )
    return LogbookActivityRow(data: data)
        .padding()
}
