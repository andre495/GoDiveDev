import SwiftUI

/// Compact logbook row layout tokens (list tiles + trailing preview).
enum LogbookActivityRowLayout {
    static let contentSpacing: CGFloat = 4
    static let cardPadding: CGFloat = AppTheme.Spacing.sm
    static let previewGap: CGFloat = AppTheme.Spacing.sm
    static let cardCornerRadius: CGFloat = 10
}

/// Compact logbook row: activity-kind icon (+ oval **#** for scuba), name + stats, optional media preview (trailing).
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
                logbookActivityLeadingChrome
                    .accessibilityLabel(chipAccessibilityLabel)

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
                        .accessibilityLabel(
                            data.activityKind == .snorkel
                                ? "Possible duplicate snorkel in log"
                                : "Possible duplicate dive in log"
                        )
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
                .fill(AppListTileCardChrome.fill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius)
                .stroke(AppListTileCardChrome.stroke, lineWidth: AppListTileCardChrome.strokeWidth)
        }
    }

    /// Activity kind icon sits **outside** the dive-number oval; snorkel rows show the icon only (no chip).
    @ViewBuilder
    private var logbookActivityLeadingChrome: some View {
        HStack(spacing: 6) {
            if let symbolName = data.diveNumberLeadingSymbolName {
                Image(systemName: symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(logbookActivityKindSymbolColor)
                    .accessibilityHidden(true)
            }

            switch data.activityKind {
            case .scubaDive:
                ActivityTagOvalChipLabel(
                    title: data.diveNumberLabel,
                    isCompact: true
                )
            case .snorkel:
                EmptyView()
            }
        }
    }

    private var logbookActivityKindSymbolColor: Color {
        switch data.activityKind {
        case .snorkel:
            return .red
        case .scubaDive:
            return AppTheme.Colors.accent
        }
    }

    /// Trailing thumbnail. When **`onTapMediaPreview`** is set it becomes a borderless button so the tap
    /// opens the dive's Media tab (and does not trigger the surrounding row **`NavigationLink`**).
    @ViewBuilder
    private func mediaPreview(photoID: UUID) -> some View {
        let preview = LogbookRowMediaPreviewView(
            photoID: photoID,
            extent: textColumnHeight,
            usesSnorkelMedia: data.previewMediaIsSnorkel
        )
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

    private var chipAccessibilityLabel: String {
        switch data.activityKind {
        case .snorkel:
            return "Snorkel activity"
        case .scubaDive:
            return "Scuba dive number \(diveNumberForAccessibility)"
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
    nonisolated static func displayName(resolvedSiteName: String?, defaultUntitled: String = "New Dive") -> String {
        let trimmed = resolvedSiteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultUntitled : trimmed
    }

    @MainActor
    static func displayName(for activity: DiveActivity) -> String {
        displayName(resolvedSiteName: activity.resolvedSiteName)
    }

    @MainActor
    static func displayName(for activity: SnorkelActivity) -> String {
        displayName(resolvedSiteName: activity.resolvedSiteName, defaultUntitled: "New Snorkel")
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
