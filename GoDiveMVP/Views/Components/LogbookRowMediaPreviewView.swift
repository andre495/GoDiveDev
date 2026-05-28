import SwiftData
import SwiftUI

/// Trailing logbook thumbnail — loads **`DiveMediaPhoto`** by id so row cache stays **`Sendable`**.
struct LogbookRowMediaPreviewView: View {
    let photoID: UUID
    /// Square edge length (matches logbook row text column height).
    var extent: CGFloat

    @Environment(\.modelContext) private var modelContext
    @State private var media: DiveMediaPhoto?

    private var resolvedExtent: CGFloat {
        max(extent, DiveActivityMediaPresentation.logbookRowMediaPreviewMinExtent)
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
            .fill(AppTheme.Colors.surfaceMuted)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
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
