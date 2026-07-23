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
    var usesSnorkelMedia: Bool = false
    var placeholderStyle: PlaceholderStyle = .surfaceMuted
    /// When **`true`**, use **`extent`** as-is (search compact rows); logbook rows still enforce **`logbookRowMediaPreviewMinExtent`**.
    var allowsCompactExtent: Bool = false

    @Environment(\.modelContext) private var modelContext
    @State private var diveMedia: DiveMediaPhoto?
    @State private var snorkelMedia: SnorkelMediaPhoto?

    private var accessibilityPreviewLabel: String {
        usesSnorkelMedia ? "Snorkel media preview" : "Dive media preview"
    }

    private var resolvedExtent: CGFloat {
        if allowsCompactExtent { return extent }
        return max(extent, DiveActivityMediaPresentation.logbookRowMediaPreviewMinExtent)
    }

    var body: some View {
        Group {
            if let diveMedia {
                DiveActivityMediaThumbnailView(
                    media: diveMedia,
                    size: resolvedExtent,
                    cornerRadius: DiveActivityMediaPresentation.logbookRowMediaPreviewCornerRadius,
                    showsPlayBadge: true
                )
            } else if let snorkelMedia {
                SnorkelActivityMediaThumbnailView(
                    media: snorkelMedia,
                    size: resolvedExtent,
                    cornerRadius: DiveActivityMediaPresentation.logbookRowMediaPreviewCornerRadius,
                    showsPlayBadge: true
                )
            } else {
                logbookRowMediaPlaceholder
            }
        }
        .frame(width: resolvedExtent, height: resolvedExtent, alignment: .trailing)
        .accessibilityLabel(accessibilityPreviewLabel)
        .task(id: loadTaskID) {
            await loadMedia()
        }
    }

    private var loadTaskID: String {
        "\(photoID.uuidString)-\(usesSnorkelMedia ? "snorkel" : "dive")"
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
        if usesSnorkelMedia {
            var descriptor = FetchDescriptor<SnorkelMediaPhoto>(
                predicate: #Predicate { $0.id == targetID }
            )
            descriptor.fetchLimit = 1
            snorkelMedia = (try? modelContext.fetch(descriptor))?.first
            diveMedia = nil
        } else {
            var descriptor = FetchDescriptor<DiveMediaPhoto>(
                predicate: #Predicate { $0.id == targetID }
            )
            descriptor.fetchLimit = 1
            diveMedia = (try? modelContext.fetch(descriptor))?.first
            snorkelMedia = nil
        }
    }
}
