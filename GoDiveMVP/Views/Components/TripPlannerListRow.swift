import SwiftUI

/// Compact trip list tile — logbook-style text + optional trailing media preview.
struct TripPlannerListRow: View, Equatable {
    let data: TripPlannerListRowDisplayData
    /// Opens trip overview on the **media** pager (does not trigger the row **`NavigationLink`**).
    var onTapMediaPreview: (() -> Void)?

    @State private var textColumnHeight: CGFloat = 0

    static func == (lhs: TripPlannerListRow, rhs: TripPlannerListRow) -> Bool {
        lhs.data == rhs.data
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: LogbookActivityRowLayout.contentSpacing) {
                Text(data.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let linkedDiveCountLabel = data.linkedDiveCountLabel {
                    Text(linkedDiveCountLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text(data.secondaryDetailLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TripPlannerRowTextColumnHeightKey.self,
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
        .onPreferenceChange(TripPlannerRowTextColumnHeightKey.self) { height in
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(TripPlannerPresentation.listRowAccessibilityLabel(for: data))
    }

    @ViewBuilder
    private func mediaPreview(photoID: UUID) -> some View {
        let preview = LogbookRowMediaPreviewView(photoID: photoID, extent: textColumnHeight)
        if let onTapMediaPreview {
            Button(action: onTapMediaPreview) {
                preview
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Open trip media")
            .accessibilityHint("Opens this trip's media gallery")
            .accessibilityIdentifier("TripPlanner.ListRow.MediaPreview")
        } else {
            preview
        }
    }
}

private struct TripPlannerRowTextColumnHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
