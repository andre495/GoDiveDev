import SwiftUI

/// Horizontal thumbnail strip — tap to select which item plays in the **Media** hero.
struct ActivityMediaCarouselView<Media: PhotoLibraryMediaRow>: View {
    private struct MediaSelectionSignature: Equatable {
        var count: Int
        var firstID: UUID?
        var lastID: UUID?
    }

    let mediaItems: [Media]
    @Binding var selectedMediaID: UUID?
    /// Resolved featured media id — star badge on that thumbnail (and selected non-featured).
    var featuredMediaID: UUID?
    /// Toggles featured logbook preview for the tapped carousel item.
    var onToggleFeatured: ((Media) -> Void)? = nil
    /// Fired when the user picks a different thumbnail (not when selection is synced programmatically).
    var onUserSelectMedia: ((Media) -> Void)? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DiveActivityMediaPresentation.carouselThumbnailSpacing) {
                    ForEach(mediaItems, id: \.id) { item in
                        carouselItem(for: item)
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

    private func carouselItem(for item: Media) -> some View {
        let isSelected = selectedMediaID == item.id
        let isFeatured = item.id == featuredMediaID
        let showsStar = DiveActivityMediaPresentation.showsCarouselFeaturedStar(
            isSelected: isSelected,
            isFeatured: isFeatured
        )

        return ZStack(alignment: .topTrailing) {
            Button {
                guard selectedMediaID != item.id else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    selectedMediaID = item.id
                }
                onUserSelectMedia?(item)
            } label: {
                carouselThumbnail(for: item, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(thumbnailAccessibilityLabel(for: item, isFeatured: isFeatured))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("DiveActivity.MediaCarousel.Item.\(item.id.uuidString)")

            if showsStar {
                featuredStarButton(for: item, isSelected: isSelected, isFeatured: isFeatured)
            }
        }
    }

    private func carouselThumbnail(for item: Media, isSelected: Bool) -> some View {
        let size = DiveActivityMediaPresentation.carouselThumbnailExtent(isSelected: isSelected)
        let cornerRadius = DiveActivityMediaPresentation.carouselThumbnailCornerRadius

        return ActivityMediaThumbnailView(
            media: item,
            size: size,
            cornerRadius: cornerRadius
        )
        .animation(.easeInOut(duration: 0.22), value: isSelected)
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

    private func featuredStarButton(
        for item: Media,
        isSelected: Bool,
        isFeatured: Bool
    ) -> some View {
        let usesAccent = DiveActivityMediaPresentation.carouselFeaturedStarUsesAccent(isFeatured: isFeatured)
        let fontSize = DiveActivityMediaPresentation.carouselFeaturedStarFontSize(isSelected: isSelected)

        return Button {
            onToggleFeatured?(item)
        } label: {
            Image(systemName: isFeatured ? "star.fill" : "star")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(usesAccent ? AppTheme.Colors.accent : Color.white)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .padding(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onToggleFeatured == nil)
        .accessibilityLabel(isFeatured ? "Featured photo" : "Set as featured")
        .accessibilityHint(
            isFeatured
                ? "Removes this as the logbook preview, reverting to the default."
                : "Uses this as the logbook preview for this activity."
        )
        .accessibilityIdentifier("DiveOverview.MediaFeatureToggle")
    }

    private func thumbnailAccessibilityLabel(for item: Media, isFeatured: Bool) -> String {
        let kind = item.resolvedMediaKind == .video ? "Video" : "Photo"
        let featured = isFeatured ? "Featured " : ""
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

typealias DiveActivityMediaCarouselView = ActivityMediaCarouselView<DiveMediaPhoto>
typealias SnorkelActivityMediaCarouselView = ActivityMediaCarouselView<SnorkelMediaPhoto>
