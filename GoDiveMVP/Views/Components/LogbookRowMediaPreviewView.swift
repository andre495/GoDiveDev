import SwiftData
import SwiftUI

/// Trailing logbook thumbnail — loads **`DiveMediaPhoto`** by id so row cache stays **`Sendable`**.
struct LogbookRowMediaPreviewView: View {
    enum PlaceholderStyle: Sendable {
        case surfaceMuted
        case translucentOnDarkBubble
    }

    let photoID: UUID
    /// Square edge length (matches logbook row text column height).
    var extent: CGFloat
    var placeholderStyle: PlaceholderStyle = .surfaceMuted
    /// When **`true`**, use **`extent`** as-is (search compact rows); logbook rows still enforce **`logbookRowMediaPreviewMinExtent`**.
    var allowsCompactExtent: Bool = false

    @Environment(\.modelContext) private var modelContext
    @State private var media: DiveMediaPhoto?

    private var resolvedExtent: CGFloat {
        if allowsCompactExtent { return extent }
        return max(extent, DiveActivityMediaPresentation.logbookRowMediaPreviewMinExtent)
    }

    var body: some View {
        Group {
            if let media {
                DiveActivityMediaThumbnailView(
                    media: media,
                    size: resolvedExtent,
                    cornerRadius: DiveActivityMediaPresentation.logbookRowMediaPreviewCornerRadius,
                    showsPlayBadge: true
                )
            } else {
                logbookRowMediaPlaceholder
            }
        }
        .frame(width: resolvedExtent, height: resolvedExtent, alignment: .trailing)
        .accessibilityLabel("Dive media preview")
        .task(id: photoID) {
            await loadMedia()
        }
    }

    private var logbookRowMediaPlaceholder: some View {
        RoundedRectangle(cornerRadius: DiveActivityMediaPresentation.logbookRowMediaPreviewCornerRadius, style: .continuous)
            .fill(placeholderFill)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(placeholderIconColor)
            }
    }

    private var placeholderFill: Color {
        switch placeholderStyle {
        case .surfaceMuted:
            AppTheme.Colors.surfaceMuted
        case .translucentOnDarkBubble:
            Color.white.opacity(0.08)
        }
    }

    private var placeholderIconColor: Color {
        switch placeholderStyle {
        case .surfaceMuted:
            AppTheme.Colors.tabUnselected
        case .translucentOnDarkBubble:
            Color.white.opacity(0.85)
        }
    }

    @MainActor
    private func loadMedia() async {
        let targetID = photoID
        var descriptor = FetchDescriptor<DiveMediaPhoto>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        media = (try? modelContext.fetch(descriptor))?.first
    }
}
