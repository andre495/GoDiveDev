import SwiftUI

/// Horizontal thumbnail strip — tap to select which item plays in the **Media** hero.
struct DiveActivityMediaCarouselView: View {
    private struct MediaSelectionSignature: Equatable {
        var count: Int
        var firstID: UUID?
        var lastID: UUID?
    }

    let mediaItems: [DiveMediaPhoto]
    @Binding var selectedMediaID: UUID?
    /// Resolved featured media id — shows a star badge on that thumbnail.
    var featuredMediaID: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DiveActivityMediaPresentation.carouselThumbnailSpacing) {
                    ForEach(mediaItems, id: \.id) { item in
                        carouselButton(for: item)
                            .id(item.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: DiveActivityMediaPresentation.carouselRowHeight)
            .accessibilityIdentifier("DiveActivity.MediaCarousel")
            .onAppear {
                scrollToSelected(proxy, animated: false)
            }
            .onChange(of: selectedMediaID) { _, _ in
                scrollToSelected(proxy, animated: true)
            }
            .onChange(of: mediaIDsSignature) { _, _ in
                scrollToSelected(proxy, animated: false)
            }
        }
    }

    private var mediaIDsSignature: MediaSelectionSignature {
        MediaSelectionSignature(
            count: mediaItems.count,
            firstID: mediaItems.first?.id,
            lastID: mediaItems.last?.id
        )
    }

    private func carouselButton(for item: DiveMediaPhoto) -> some View {
        Button {
            guard selectedMediaID != item.id else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                selectedMediaID = item.id
            }
        } label: {
            carouselThumbnail(for: item)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(thumbnailAccessibilityLabel(for: item))
        .accessibilityAddTraits(selectedMediaID == item.id ? .isSelected : [])
        .accessibilityIdentifier("DiveActivity.MediaCarousel.Item.\(item.id.uuidString)")
    }

    private func carouselThumbnail(for item: DiveMediaPhoto) -> some View {
        let size = DiveActivityMediaPresentation.carouselThumbnailSize
        let cornerRadius = DiveActivityMediaPresentation.carouselThumbnailCornerRadius
        let isSelected = selectedMediaID == item.id

        return DiveActivityMediaThumbnailView(
            media: item,
            size: size,
            cornerRadius: cornerRadius
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? AppTheme.Colors.accent : Color.clear,
                    lineWidth: isSelected ? 3 : 0
                )
        }
        .overlay(alignment: .topTrailing) {
            if item.id == featuredMediaID {
                featuredBadge
                    .padding(5)
            }
        }
        .shadow(
            color: isSelected ? AppTheme.Colors.accent.opacity(0.35) : .clear,
            radius: isSelected ? 6 : 0,
            y: 2
        )
    }

    private var featuredBadge: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background {
                Circle().fill(AppTheme.Colors.accent)
            }
            .overlay {
                Circle().stroke(.white.opacity(0.9), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .accessibilityLabel("Featured")
    }

    private func thumbnailAccessibilityLabel(for item: DiveMediaPhoto) -> String {
        let kind = item.resolvedMediaKind == .video ? "Video" : "Photo"
        let featured = item.id == featuredMediaID ? "Featured " : ""
        if selectedMediaID == item.id {
            return "Selected \(featured)\(kind), show in viewer"
        }
        return "\(featured)\(kind), show in viewer"
    }

    private func scrollToSelected(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedMediaID else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(selectedMediaID, anchor: .center)
            }
        } else {
            proxy.scrollTo(selectedMediaID, anchor: .center)
        }
    }
}
