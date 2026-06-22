import SwiftUI

/// Large preview + thumbnail carousel for tagged dive media (same carousel as **Media** tab).
struct FieldGuideTaggedMediaGalleryView: View {
    let mediaItems: [DiveMediaPhoto]
    let timeZoneOffsetByMediaID: [UUID: Int?]
    var showsTitle = true
    var previewAccessibilityIdentifier = "FieldGuide.SpeciesDetail.TaggedMediaPreview"
    var carouselAccessibilityIdentifier = "FieldGuide.SpeciesDetail.TaggedMediaCarousel"

    private struct MediaSelectionSignature: Equatable {
        var count: Int
        var firstID: UUID?
        var lastID: UUID?
    }

    @State private var selectedMediaID: UUID?

    private var selectedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(selectedID: selectedMediaID, in: mediaItems)
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
                    Text("Your tagged photos")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    if let positionLabel = DiveActivityMediaPresentation.mediaPositionLabel(
                        selectedID: selectedMediaID,
                        in: mediaItems
                    ) {
                        Text(positionLabel)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
            } else if let positionLabel = DiveActivityMediaPresentation.mediaPositionLabel(
                selectedID: selectedMediaID,
                in: mediaItems
            ) {
                Text(positionLabel)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            largePreview
            DiveActivityMediaCarouselView(
                mediaItems: mediaItems,
                selectedMediaID: $selectedMediaID
            )
            .accessibilityIdentifier(carouselAccessibilityIdentifier)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your tagged photos")
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
        selectedMediaID = DiveActivityMediaPresentation.resolvedSelectedPhotoID(
            selectedID: selectedMediaID,
            in: mediaItems
        )
    }

    private static let previewHeight: CGFloat = 280
}
