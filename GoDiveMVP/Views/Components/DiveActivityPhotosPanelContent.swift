import PhotosUI
import SwiftUI

/// **Media** overview sheet — carousel at **minimized** / **medium**; capture date and **+** at **medium** only.
struct DiveActivityPhotosPanelContent: View {
    let mediaItems: [DiveMediaPhoto]
    @Binding var selectedMediaID: UUID?
    let timeZoneOffsetSeconds: Int?
    var sheetDetent: DiveActivityOverviewDetent = .medium
    var layoutHeight: CGFloat = 0
    var showsMediaCarousel = false
    var showsSheetDetails = false
    var showsMarineLifeTagInSheet = false
    var onTagMarineLife: (() -> Void)?
    /// Resolved featured media id (user-chosen, else oldest); marks the carousel item and the toggle state.
    var featuredMediaID: UUID?
    /// Toggles the selected media as the featured logbook preview (tap a featured item to revert to default).
    var onToggleFeatured: ((DiveMediaPhoto) -> Void)?
    @Binding var mediaPickerItems: [PhotosPickerItem]
    var isImportInProgress = false

    private var selectedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(selectedID: selectedMediaID, in: mediaItems)
    }

    private var isSelectedMediaFeatured: Bool {
        guard let selectedMedia, let featuredMediaID else { return false }
        return selectedMedia.id == featuredMediaID
    }

    private var carouselTopInset: CGFloat {
        guard showsMediaCarousel,
              sheetDetent == .medium,
              layoutHeight > 0
        else { return 0 }
        return DiveActivityOverviewPanelMetrics.mediaCarouselScreenAlignmentTopInset(
            layoutHeight: layoutHeight
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                if carouselTopInset > 0 {
                    Color.clear
                        .frame(height: carouselTopInset)
                        .accessibilityHidden(true)
                }

                if mediaItems.isEmpty {
                    Text(DiveActivityMediaPresentation.emptyStateMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                } else {
                    if showsMediaCarousel {
                        carouselRow
                    }

                    if showsSheetDetails, let selectedMedia {
                        captureDetails(for: selectedMedia)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsSheetDetails || showsMarineLifeTagInSheet {
                sheetTopChromeRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sheetTopChromeRow: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            if showsMarineLifeTagInSheet, let onTagMarineLife {
                DiveActivityMediaMarineLifeTagButton(action: onTagMarineLife)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            if showsSheetDetails, onToggleFeatured != nil, selectedMedia != nil {
                featuredButton
            }

            if showsSheetDetails {
                addMediaButton
            }
        }
    }

    private var carouselRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            DiveActivityMediaCarouselView(
                mediaItems: mediaItems,
                selectedMediaID: $selectedMediaID,
                featuredMediaID: featuredMediaID
            )

            if !showsSheetDetails {
                addMediaButton
            }
        }
    }

    private var featuredButton: some View {
        Button {
            guard let selectedMedia, let onToggleFeatured else { return }
            onToggleFeatured(selectedMedia)
        } label: {
            Image(systemName: isSelectedMediaFeatured ? "star.fill" : "star")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(isImportInProgress)
        .opacity(isImportInProgress ? 0.45 : 1)
        .accessibilityLabel(isSelectedMediaFeatured ? "Featured photo" : "Set as featured")
        .accessibilityHint(
            isSelectedMediaFeatured
                ? "Removes this as the logbook preview, reverting to the default."
                : "Uses this as the logbook preview for this dive."
        )
        .accessibilityIdentifier("DiveOverview.MediaFeatureToggle")
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
            Image(systemName: "photo.badge.plus")
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
