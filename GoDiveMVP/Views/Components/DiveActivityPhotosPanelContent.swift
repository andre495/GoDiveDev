import PhotosUI
import SwiftUI

/// **Media** overview sheet — carousel at **minimized** / **medium**; scrollable tagged-species detail at **large**.
struct DiveActivityPhotosPanelContent: View {
    let mediaItems: [DiveMediaPhoto]
    @Binding var selectedMediaID: UUID?
    let timeZoneOffsetSeconds: Int?
    var sheetDetent: DiveActivityOverviewDetent = .medium
    var layoutHeight: CGFloat = 0
    var showsMediaCarousel = false
    var showsMarineLifeTagInSheet = false
    var onTagMarineLife: (() -> Void)?
    /// Expands the overview sheet to **large** tagged-species detail (medium oval chips).
    var onExpandMarineLifeDetail: (() -> Void)?
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

    private var selectedMediaFishialSpeciesName: String? {
        selectedMedia?.resolvedFishialConfirmedSpeciesName
    }

    private var isMarineLifeTagControlActive: Bool {
        DiveActivityMediaPresentation.marineLifeTagControlIsActive(
            taggedSpeciesCount: taggedSpecies.count
        )
    }

    private var showsFishialIdentificationSummary: Bool {
        DiveActivityMediaPresentation.fishialIdentifyControlIsActive(
            confirmedSpeciesName: selectedMediaFishialSpeciesName
        )
    }

    private var taggedSpeciesNames: [String] {
        taggedSpecies.map(\.commonName)
    }

    private var taggedSpeciesChipTitles: [String] {
        taggedSpecies.map { MarineLifeMediaTagPresentation.chipDisplayTitle(for: $0.commonName) }
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

    private var showsMarineLifeTagInCarousel: Bool {
        DiveActivityMediaPresentation.showsMarineLifeTagInCarousel(for: sheetDetent)
            && onTagMarineLife != nil
    }

    private var usesCarouselPinnedLayout: Bool {
        showsMediaCarousel && sheetDetent != .minimized && layoutHeight > 0
    }

    private var sheetChromeClearance: CGFloat {
        showsSheetChromeActions ? DiveActivityMediaPresentation.sheetChromeRowHeight : 0
    }

    private var sheetBodyHeight: CGFloat {
        DiveActivityMediaPresentation.sheetBodyHeightAboveMediaCarousel(
            layoutHeight: layoutHeight,
            detent: sheetDetent
        )
    }

    private var carouselPinnedStackHeight: CGFloat {
        DiveActivityMediaPresentation.mediaCarouselPinnedStackHeight(
            layoutHeight: layoutHeight,
            detent: sheetDetent
        )
    }

    private var resolvedSelectedTaggedSpecies: MarineLife? {
        guard let resolvedUUID = DiveActivityMediaPresentation.resolvedTaggedSpeciesUUID(
            selectedUUID: selectedTaggedSpeciesUUID,
            taggedSpeciesUUIDs: taggedSpecies.map(\.uuid)
        ) else { return nil }
        return taggedSpecies.first(where: { $0.uuid == resolvedUUID })
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                if showsMarineLifeDetail {
                    largeDetentContent
                } else if usesCarouselPinnedLayout {
                    carouselPinnedSheetContent {
                        mediumDetentBody
                    }
                } else {
                    minimizedDetentContent
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
    private func carouselPinnedSheetContent<Body: View>(
        @ViewBuilder body: () -> Body
    ) -> some View {
        if mediaItems.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text(DiveActivityMediaPresentation.emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: sheetBodyHeight + sheetChromeClearance, alignment: .top)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: sheetChromeClearance)
                    .accessibilityHidden(true)

                body()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: sheetBodyHeight, alignment: .top)
                    .clipped()

                if showsMediaCarousel {
                    carouselRow
                }
            }
            .frame(height: carouselPinnedStackHeight, alignment: .top)
        }
    }

    @ViewBuilder
    private var largeDetentContent: some View {
        if mediaItems.isEmpty {
            Text(DiveActivityMediaPresentation.emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        } else {
            largeDetentBody
        }
    }

    @ViewBuilder
    private var minimizedDetentContent: some View {
        if mediaItems.isEmpty {
            Text(DiveActivityMediaPresentation.emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        } else if showsMediaCarousel {
            carouselRow
        }
    }

    @ViewBuilder
    private var mediumDetentBody: some View {
        if showsMarineLifeTagSummary {
            marineLifeTagsSection
        }
        if showsFishialIdentificationSummary, let fishialName = selectedMediaFishialSpeciesName {
            fishialIdentificationSection(name: fishialName)
        }
    }

    @ViewBuilder
    private var largeDetentBody: some View {
        if taggedSpecies.isEmpty {
            largeDetentUntaggedPrompt
        } else {
            if taggedSpecies.count > 1 {
                DiveActivityMediaTaggedSpeciesSelector(
                    species: taggedSpecies,
                    selectedUUID: $selectedTaggedSpeciesUUID
                )
            } else {
                DiveActivityTagChipFlow(tagNames: taggedSpeciesChipTitles)
            }

            if let resolvedSelectedTaggedSpecies {
                DiveActivityMediaTaggedSpeciesDetailContent(
                    species: resolvedSelectedTaggedSpecies
                )
            }
        }
    }

    private var largeDetentUntaggedPrompt: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Image(systemName: "fish")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)

            Text(MarineLifeMediaTagPresentation.largeDetentUntaggedPrompt)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(MarineLifeMediaTagPresentation.largeDetentUntaggedPrompt)
        .accessibilityIdentifier("DiveOverview.MediaLargeUntaggedPrompt")
    }

    private var sheetTopChromeRow: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            if showsMarineLifeTagInSheet, let onTagMarineLife {
                DiveActivityMediaMarineLifeTagButton(
                    isActive: isMarineLifeTagControlActive,
                    action: onTagMarineLife
                )
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            if onToggleFeatured != nil, selectedMedia != nil {
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

            if !showsSheetChromeActions {
                if showsMarineLifeTagInCarousel, let onTagMarineLife {
                    DiveActivityMediaMarineLifeTagButton(
                        isActive: isMarineLifeTagControlActive,
                        action: onTagMarineLife
                    )
                    .disabled(isImportInProgress)
                    .opacity(isImportInProgress ? 0.45 : 1)
                }

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
                .foregroundStyle(
                    isSelectedMediaFeatured
                        ? AppTheme.Colors.accent
                        : AppTheme.Colors.tabUnselected
                )
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
                mediumDetentMarineLifeTagChips
            }
        }
        .accessibilityElement(children: onExpandMarineLifeDetail != nil ? .contain : .combine)
        .accessibilityLabel(
            MarineLifeMediaTagPresentation.mediumDetentAccessibilityLabel(taggedNames: taggedSpeciesNames)
        )
        .accessibilityIdentifier("DiveOverview.MediaMarineLifeTags")
    }

    private var mediumDetentMarineLifeTagChips: some View {
        let columns = [GridItem(.adaptive(minimum: 88), spacing: AppTheme.Spacing.sm)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ForEach(taggedSpecies, id: \.uuid) { species in
                if let onExpandMarineLifeDetail {
                    Button {
                        selectedTaggedSpeciesUUID = species.uuid
                        onExpandMarineLifeDetail()
                    } label: {
                        ActivityTagOvalChipLabel(
                            title: MarineLifeMediaTagPresentation.chipDisplayTitle(for: species.commonName)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(species.commonName)
                    .accessibilityHint("Shows \(species.commonName) details")
                    .accessibilityIdentifier("DiveOverview.MediaMarineLifeTag.\(species.uuid)")
                } else {
                    ActivityTagOvalChipLabel(
                        title: MarineLifeMediaTagPresentation.chipDisplayTitle(for: species.commonName)
                    )
                    .accessibilityLabel(species.commonName)
                }
            }
        }
    }

    private func fishialIdentificationSection(name: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(FishialIdentificationReviewPresentation.mediumDetentSectionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .accessibilityHidden(true)

                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            FishialIdentificationReviewPresentation.mediumDetentAccessibilityLabel(speciesName: name)
        )
        .accessibilityIdentifier("DiveOverview.MediaFishialIdentification")
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
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(isImportInProgress)
        .opacity(isImportInProgress ? 0.45 : 1)
        .accessibilityLabel("Add photos or videos")
        .accessibilityIdentifier("DiveOverview.MediaAdd")
    }
}
