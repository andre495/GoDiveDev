import SwiftUI

/// Large preview + thumbnail carousel for tagged dive media (same carousel as **Media** tab).
struct FieldGuideTaggedMediaGalleryView: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    var selectedMediaID: Binding<UUID?>?
    var showsTitle = true
    var showsLargePreview = true
    var sectionTitle = "Your tagged photos"
    var previewAccessibilityIdentifier = "FieldGuide.SpeciesDetail.TaggedMediaPreview"
    var carouselAccessibilityIdentifier = "FieldGuide.SpeciesDetail.TaggedMediaCarousel"

    private struct MediaSelectionSignature: Equatable {
        var count: Int
        var firstID: UUID?
        var lastID: UUID?
    }

    @State private var internalSelectedMediaID: UUID?

    private var selectedMediaIDBinding: Binding<UUID?> {
        selectedMediaID ?? $internalSelectedMediaID
    }

    private var selectedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(
            selectedID: selectedMediaIDBinding.wrappedValue,
            in: mediaItems
        )
    }

    private var mediaIDsSignature: MediaSelectionSignature {
        MediaSelectionSignature(
            count: mediaItems.count,
            firstID: mediaItems.first?.id,
            lastID: mediaItems.last?.id
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if showsTitle {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(sectionTitle)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    if let positionLabel = DiveActivityMediaPresentation.mediaPositionLabel(
                        selectedID: selectedMediaIDBinding.wrappedValue,
                        in: mediaItems
                    ) {
                        Text(positionLabel)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
            } else if let positionLabel = DiveActivityMediaPresentation.mediaPositionLabel(
                selectedID: selectedMediaIDBinding.wrappedValue,
                in: mediaItems
            ) {
                Text(positionLabel)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            if showsLargePreview {
                largePreview
            }
            DiveActivityMediaCarouselView(
                mediaItems: mediaItems,
                selectedMediaID: selectedMediaIDBinding
            )
            .accessibilityIdentifier(carouselAccessibilityIdentifier)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(sectionTitle)
        .onAppear {
            syncSelectionToMedia()
        }
        .onChange(of: mediaIDsSignature) { _, _ in
            syncSelectionToMedia()
        }
    }

    @ViewBuilder
    private var largePreview: some View {
        Group {
            if let selectedMedia {
                DiveActivityMediaItemView(
                    media: selectedMedia,
                    timeZoneOffsetSeconds: timeZoneOffsetByMediaID[selectedMedia.id] ?? nil,
                    showsCaptureDateOverlay: true,
                    isVideoPlaybackActive: selectedMedia.resolvedMediaKind == .video,
                    loopsVideoPlayback: true
                )
                .id(selectedMedia.id)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.tabUnselected.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
        .accessibilityIdentifier(previewAccessibilityIdentifier)
    }

    private func syncSelectionToMedia() {
        selectedMediaIDBinding.wrappedValue = DiveActivityMediaPresentation.resolvedSelectedPhotoID(
            selectedID: selectedMediaIDBinding.wrappedValue,
            in: mediaItems
        )
    }

    private static let previewHeight: CGFloat = 280
}
