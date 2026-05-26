import PhotosUI
import SwiftUI

/// **Media** overview sheet — carousel at **minimized** / **medium**; title, capture date, and **+** at **medium** only.
struct DiveActivityPhotosPanelContent: View {
    let mediaItems: [DiveMediaPhoto]
    @Binding var selectedMediaID: UUID?
    let timeZoneOffsetSeconds: Int?
    var showsMediaCarousel = false
    var showsSheetDetails = false
    /// When this changes (e.g. sheet detent), remounts the carousel so thumbnails reload after hidden minimized layout.
    var carouselLayoutToken: AnyHashable = 0
    @Binding var mediaPickerItems: [PhotosPickerItem]
    var isImportInProgress = false

    private var selectedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(selectedID: selectedMediaID, in: mediaItems)
    }

    private var positionLabel: String? {
        DiveActivityMediaPresentation.mediaPositionLabel(selectedID: selectedMediaID, in: mediaItems)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if showsSheetDetails {
                headerRow
            }

            if mediaItems.isEmpty {
                Text(DiveActivityMediaPresentation.emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            } else {
                if showsMediaCarousel {
                    carouselRow
                        .id(carouselLayoutToken)
                }

                if showsSheetDetails, let selectedMedia {
                    captureDetails(for: selectedMedia)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var carouselRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            DiveActivityMediaCarouselView(
                mediaItems: mediaItems,
                selectedMediaID: $selectedMediaID
            )

            if !showsSheetDetails {
                addMediaButton
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Media")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                if let positionLabel {
                    Text(positionLabel)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                }
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            addMediaButton
        }
    }

    private func captureDetails(for media: DiveMediaPhoto) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Captured")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .textCase(.uppercase)

            Text(
                DiveActivityMediaPresentation.captureDatePanelText(
                    for: media,
                    timeZoneOffsetSeconds: timeZoneOffsetSeconds
                )
            )
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Captured \(DiveActivityMediaPresentation.captureDatePanelText(for: media, timeZoneOffsetSeconds: timeZoneOffsetSeconds))"
        )
    }

    private var addMediaButton: some View {
        PhotosPicker(
            selection: $mediaPickerItems,
            maxSelectionCount: 20,
            matching: .any(of: [.images, .videos]),
            photoLibrary: .shared()
        ) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(isImportInProgress)
        .opacity(isImportInProgress ? 0.45 : 1)
        .accessibilityLabel("Add photos or videos")
        .accessibilityIdentifier("DiveOverview.MediaAdd")
    }
}
