import PhotosUI
import SwiftUI

/// **Media** overview sheet — carousel at **minimized** / **medium**; species detail at **large**.
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
    /// Catalog species tagged on the selected media item.
    var taggedSpecies: [MarineLife] = []
    @Binding var mediaPickerItems: [PhotosPickerItem]
    var isImportInProgress = false

    @State private var selectedTaggedSpeciesUUID: String?

    private var selectedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(selectedID: selectedMediaID, in: mediaItems)
    }

    private var isSelectedMediaFeatured: Bool {
        guard let selectedMedia, let featuredMediaID else { return false }
        return selectedMedia.id == featuredMediaID
    }

    private var taggedSpeciesNames: [String] {
        taggedSpecies.map(\.commonName)
    }

    private var showsMarineLifeTagSummary: Bool {
        DiveActivityMediaPresentation.showsMarineLifeTagSummaryInSheet(for: sheetDetent)
    }

    private var showsMarineLifeDetail: Bool {
        DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: sheetDetent)
    }

    private var showsSheetChromeActions: Bool {
        DiveActivityMediaPresentation.showsMediaSheetChromeActions(for: sheetDetent)
    }

    private var resolvedSelectedTaggedSpecies: MarineLife? {
        guard !taggedSpecies.isEmpty else { return nil }
        if let selectedTaggedSpeciesUUID,
           let match = taggedSpecies.first(where: { $0.uuid == selectedTaggedSpeciesUUID }) {
            return match
        }
        return taggedSpecies.first
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
                if showsMarineLifeDetail {
                    largeDetentContent
                } else {
                    compactDetentContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsSheetChromeActions {
                sheetTopChromeRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: selectedMediaID) { _, _ in
            selectedTaggedSpeciesUUID = nil
        }
        .onChange(of: taggedSpecies.map(\.uuid)) { _, uuids in
            if let selectedTaggedSpeciesUUID, uuids.contains(selectedTaggedSpeciesUUID) {
                return
            }
            selectedTaggedSpeciesUUID = uuids.first
        }
    }

    @ViewBuilder
    private var compactDetentContent: some View {
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
            if showsMarineLifeTagSummary {
                marineLifeTagsSection
            }

            if showsMediaCarousel {
                carouselRow
            }

            if showsSheetDetails, let selectedMedia {
                captureDetails(for: selectedMedia)
            }
        }
    }

    @ViewBuilder
    private var largeDetentContent: some View {
        if mediaItems.isEmpty {
            Text(DiveActivityMediaPresentation.emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        } else if taggedSpecies.isEmpty {
            marineLifeTagsSection
        } else {
            if taggedSpecies.count > 1 {
                DiveActivityMediaTaggedSpeciesSelector(
                    species: taggedSpecies,
                    selectedUUID: $selectedTaggedSpeciesUUID
                )
            } else {
                Text(MarineLifeMediaTagPresentation.sectionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .textCase(.uppercase)
            }

            if let resolvedSelectedTaggedSpecies {
                DiveActivityMediaTaggedSpeciesDetailContent(
                    species: resolvedSelectedTaggedSpecies,
                    heroHeight: DiveActivityMediaPresentation.largeDetentSpeciesHeroHeight
                )
            }
        }
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

            addMediaButton
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

    private var marineLifeTagsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if !showsMarineLifeDetail {
                Text(MarineLifeMediaTagPresentation.sectionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .textCase(.uppercase)
            }

            if taggedSpeciesNames.isEmpty {
                Button {
                    onTagMarineLife?()
                } label: {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "fish")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .accessibilityHidden(true)

                        Text(MarineLifeMediaTagPresentation.untaggedPrompt)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .disabled(onTagMarineLife == nil)
            } else if showsMarineLifeTagSummary {
                DiveActivityTagChipFlow(tagNames: taggedSpeciesNames)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            MarineLifeMediaTagPresentation.mediumDetentAccessibilityLabel(taggedNames: taggedSpeciesNames)
        )
        .accessibilityIdentifier("DiveOverview.MediaMarineLifeTags")
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
