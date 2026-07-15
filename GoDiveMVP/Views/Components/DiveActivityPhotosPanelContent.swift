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
    var showsBuddyTagInSheet = false
    var onTagBuddies: (() -> Void)?
    /// Opens Fishial identify from the **large** marine-life chrome (sparkles leading **+**).
    var onIdentifyFish: (() -> Void)? = nil
    /// Expands the overview sheet to **large** tagged-species detail (medium oval chips).
    var onExpandMarineLifeDetail: (() -> Void)?
    /// Resolved featured media id (user-chosen, else oldest); marks the carousel item and the toggle state.
    var featuredMediaID: UUID?
    /// Toggles the selected media as the featured logbook preview (tap a featured item to revert to default).
    var onToggleFeatured: ((DiveMediaPhoto) -> Void)?
    /// Catalog species tagged on the selected media item.
    var taggedSpecies: [MarineLife] = []
    /// Buddies tagged on the selected media item.
    var taggedBuddies: [DiveBuddy] = []
    /// Owner for Field Guide / buddy detail covers opened from **large** overview.
    var ownerProfileID: UUID? = nil
    var onOpenDive: ((UUID) -> Void)? = nil
    /// Map-style identity header (dive **#**, site, place, date) — shown at **medium**.
    var diveNumberChip: String? = nil
    var siteTitle: String? = nil
    var linkedCatalogSiteID: UUID? = nil
    var onOpenLinkedSite: (() -> Void)? = nil
    var regionCountryLine: String? = nil
    var dateDashTimeLine: String? = nil
    @Binding var mediaPickerItems: [PhotosPickerItem]
    var isImportInProgress = false

    @State private var selectedTaggedSpeciesUUID: String?
    @State private var largeDetentMode: DiveActivityMediaLargeDetentMode = .marineLife

    private var selectedMedia: DiveMediaPhoto? {
        DiveActivityMediaPresentation.selectedMedia(selectedID: selectedMediaID, in: mediaItems)
    }

    private var isSelectedMediaFeatured: Bool {
        guard let selectedMedia, let featuredMediaID else { return false }
        return selectedMedia.id == featuredMediaID
    }

    private var isMarineLifeTagControlActive: Bool {
        DiveActivityMediaPresentation.marineLifeTagControlIsActive(
            taggedSpeciesCount: taggedSpecies.count
        )
    }

    private var isBuddyTagControlActive: Bool {
        DiveActivityMediaPresentation.buddyTagControlIsActive(
            taggedBuddyCount: taggedBuddies.count
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

    private var showsDiveIdentityHeader: Bool {
        DiveActivityMediaPresentation.showsDiveIdentityHeaderInSheet(for: sheetDetent)
            && siteTitle != nil
            && dateDashTimeLine != nil
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                if mediaItems.isEmpty {
                    emptyMediaPanelContent
                } else if showsMarineLifeDetail {
                    DiveActivityMediaLargeDetentOverviewContent(
                        mode: $largeDetentMode,
                        media: selectedMedia,
                        taggedSpecies: taggedSpecies,
                        taggedBuddies: taggedBuddies,
                        onTagMarineLife: onTagMarineLife,
                        onTagBuddies: onTagBuddies,
                        onIdentifyFish: onIdentifyFish,
                        ownerProfileID: ownerProfileID,
                        onOpenDive: onOpenDive,
                        selectedTaggedSpeciesUUID: $selectedTaggedSpeciesUUID,
                        overlaysChrome: true
                    )
                } else if usesCarouselPinnedLayout {
                    carouselPinnedSheetContent {
                        mediumDetentBody
                    }
                } else {
                    minimizedDetentContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsSheetChromeActions || (mediaItems.isEmpty && sheetDetent == .large) {
                sheetTopChromeRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: selectedMediaID) { _, _ in
            selectedTaggedSpeciesUUID = nil
            largeDetentMode = .marineLife
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

    @ViewBuilder
    private var emptyMediaPanelContent: some View {
        switch sheetDetent {
        case .minimized:
            HStack {
                Spacer(minLength: 0)
                addMediaButton
            }
        case .medium:
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: sheetChromeClearance)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    if showsDiveIdentityHeader {
                        diveIdentityHeader
                    }
                    emptyUploadPromptTextBlock
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: sheetBodyHeight, alignment: .top)
            }
            .frame(height: carouselPinnedStackHeight, alignment: .top)
        case .large:
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Color.clear
                    .frame(height: DiveActivityMediaPresentation.sheetChromeRowHeight)
                    .accessibilityHidden(true)

                emptyUploadPromptTextBlock
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var emptyUploadPromptTextBlock: some View {
        MediaUploadEmptyPromptTextBlock(
            title: DiveActivityMediaEmptyHeroPresentation.title,
            message: DiveActivityMediaEmptyHeroPresentation.message,
            horizontalAlignment: .leading
        )
        .accessibilityIdentifier("DiveOverview.MediaEmptyUploadPrompt")
    }

    @ViewBuilder
    private var minimizedDetentContent: some View {
        if showsMediaCarousel {
            carouselRow
        }
    }

    @ViewBuilder
    private var mediumDetentBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if showsDiveIdentityHeader {
                diveIdentityHeader
            }

            if showsMarineLifeTagSummary {
                marineLifeTagsSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var diveIdentityHeader: some View {
        if let siteTitle, let dateDashTimeLine {
            DiveActivityMapOverviewHeader(
                diveNumberChip: diveNumberChip,
                siteTitle: siteTitle,
                linkedCatalogSiteID: linkedCatalogSiteID,
                onOpenLinkedSite: onOpenLinkedSite,
                regionCountryLine: regionCountryLine,
                dateDashTimeLine: dateDashTimeLine
            )
        }
    }

    private var sheetTopChromeRow: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if showsMarineLifeTagInSheet {
                    mediumSheetMarineLifeChromeButton
                }

                if showsBuddyTagInSheet {
                    mediumSheetBuddyChromeButton
                }
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            if onToggleFeatured != nil, selectedMedia != nil {
                featuredButton
            }

            addMediaButton
        }
    }

    @ViewBuilder
    private var mediumSheetMarineLifeChromeButton: some View {
        if let onExpandMarineLifeDetail {
            DiveActivityMediaMarineLifeTagButton(
                isActive: isMarineLifeTagControlActive,
                action: {
                    largeDetentMode = .marineLife
                    onExpandMarineLifeDetail()
                }
            )
            .accessibilityHint("Opens marine life details")
        } else if let onTagMarineLife {
            DiveActivityMediaMarineLifeTagButton(
                isActive: isMarineLifeTagControlActive,
                action: onTagMarineLife
            )
            .accessibilityHint("Shows species tagged on this photo")
        }
    }

    @ViewBuilder
    private var mediumSheetBuddyChromeButton: some View {
        if DiveActivityMediaPresentation.opensBuddyOverviewOnSheetBuddyTap(detent: sheetDetent),
           let onExpandMarineLifeDetail
        {
            DiveActivityMediaBuddyTagButton(
                isActive: isBuddyTagControlActive,
                action: {
                    largeDetentMode = .buddies
                    onExpandMarineLifeDetail()
                }
            )
            .accessibilityHint("Opens buddy details")
        } else if let onTagBuddies {
            DiveActivityMediaBuddyTagButton(
                isActive: isBuddyTagControlActive,
                action: onTagBuddies
            )
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MarineLifeMediaTagPresentation.chipRowSpacing) {
                ForEach(taggedSpecies, id: \.uuid) { species in
                    if let onExpandMarineLifeDetail {
                        Button {
                            selectedTaggedSpeciesUUID = species.uuid
                            onExpandMarineLifeDetail()
                        } label: {
                            marineLifeSpeciesChip(for: species)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows \(species.commonName) details")
                        .accessibilityIdentifier("DiveOverview.MediaMarineLifeTag.\(species.uuid)")
                    } else {
                        marineLifeSpeciesChip(for: species)
                    }
                }
            }
        }
    }

    private func marineLifeSpeciesChip(for species: MarineLife) -> some View {
        ActivityTagOvalChipLabel(
            title: MarineLifeMediaTagPresentation.chipDisplayTitle(for: species.commonName),
            showsFishialBadge: showsFishialBadge(for: species)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private func showsFishialBadge(for species: MarineLife) -> Bool {
        guard let selectedMedia else { return false }
        return DiveActivityMediaPresentation.speciesWasFishialIdentified(species: species, on: selectedMedia)
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
