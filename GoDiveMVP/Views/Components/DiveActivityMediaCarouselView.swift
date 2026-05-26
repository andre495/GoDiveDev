import SwiftUI

/// Horizontal thumbnail strip — tap to select which item plays in the **Media** hero.
struct DiveActivityMediaCarouselView: View {
    let mediaItems: [DiveMediaPhoto]
    @Binding var selectedMediaID: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DiveActivityMediaPresentation.carouselThumbnailSpacing) {
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

    private var mediaIDsSignature: String {
        mediaItems.map(\.id.uuidString).joined(separator: ",")
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
        .shadow(
            color: isSelected ? AppTheme.Colors.accent.opacity(0.35) : .clear,
            radius: isSelected ? 6 : 0,
            y: 2
        )
    }

    private func thumbnailAccessibilityLabel(for item: DiveMediaPhoto) -> String {
        let kind = item.resolvedMediaKind == .video ? "Video" : "Photo"
        if selectedMediaID == item.id {
            return "Selected \(kind), show in viewer"
        }
        return "\(kind), show in viewer"
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
