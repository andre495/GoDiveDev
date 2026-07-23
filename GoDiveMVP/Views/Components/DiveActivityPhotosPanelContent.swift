import PhotosUI
import SwiftUI

/// **Media** overview sheet — carousel at **minimized** / **medium**; scrollable tagged-species detail at **large**.
struct ActivityPhotosPanelContent<Media: PhotoLibraryMediaRow>: View {
    let mediaItems: [Media]
    @Binding var selectedMediaID: UUID?
    let timeZoneOffsetSeconds: Int?
    var sheetDetent: DiveActivityOverviewDetent = .large
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
    /// Soft-collapses **large** tagged detail back to **medium** when scrolling past the top.
    var onCollapsePanelToMedium: (() -> Void)? = nil
    /// Resolved featured media id (user-chosen, else oldest); marks the carousel item and the toggle state.
    var featuredMediaID: UUID?
    /// Toggles the selected media as the featured logbook preview (tap a featured item to revert to default).
    var onToggleFeatured: ((Media) -> Void)?
    /// User tapped a different carousel thumbnail.
    var onUserSelectMedia: ((Media) -> Void)? = nil
    /// Catalog species tagged on the selected media item.
    var taggedSpecies: [MarineLife] = []
    /// Buddies tagged on the selected media item.
    var taggedBuddies: [DiveBuddy] = []
    /// Owner for Field Guide / buddy detail covers opened from **large** overview.
    var ownerProfileID: UUID? = nil
    var onOpenDive: ((UUID) -> Void)? = nil
    /// Map-style identity header (activity symbol, dive **#**, site, place, date) — shown at **medium**.
    var activityKind: ActivityOverviewHeaderKind = .scubaDive
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

    private var selectedMedia: Media? {
        DiveActivityMediaPresentation.selectedMedia(selectedID: selectedMediaID, in: mediaItems)
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

    private var showsBuddyTagSummary: Bool {
        DiveActivityMediaPresentation.showsBuddyTagSummaryInSheet(for: sheetDetent)
    }

    private var showsDiveIdentityHeader: Bool {
        DiveActivityMediaPresentation.showsDiveIdentityHeaderInSheet(for: sheetDetent)
            && siteTitle != nil
            && dateDashTimeLine != nil
    }

    private var showsMarineLifeDetail: Bool {
        DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: sheetDetent)
    }

    private var showsMarineLifeTagInCarousel: Bool {
        DiveActivityMediaPresentation.showsMarineLifeTagInCarousel(for: sheetDetent)
            && onTagMarineLife != nil
    }

    private var showsMediumTrailingTagChrome: Bool {
        DiveActivityMediaPresentation.showsMediumDetentTrailingTagChrome(for: sheetDetent)
            && (showsMarineLifeTagInSheet || showsBuddyTagInSheet)
    }

    private var usesCarouselPinnedLayout: Bool {
        showsMediaCarousel && sheetDetent != .minimized && layoutHeight > 0
    }

    private var pinsCarouselToSheetBottom: Bool {
        DiveActivityMediaPresentation.pinsMediaCarouselToSheetBottom(for: sheetDetent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if showsMarineLifeDetail {
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
                    overlaysChrome: true,
                    onCollapseToMedium: onCollapsePanelToMedium
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if usesCarouselPinnedLayout {
                carouselPinnedSheetContent {
                    mediumDetentBody
                }
            } else {
                minimizedDetentContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            body()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()

            if showsMediaCarousel {
                carouselRow
                    .padding(
                        .bottom,
                        pinsCarouselToSheetBottom
                            ? DiveActivityMediaPresentation.mediumCarouselBottomPadding
                            : 0
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
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
            mediumDetentIdentityRow

            if showsMarineLifeTagSummary {
                marineLifeTagsSection
            }

            if showsBuddyTagSummary {
                buddiesTagsSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Dive identity (same as **Map** / **Tank**) with fish / buddy trailing the dive-number row.
    private var mediumDetentIdentityRow: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            diveIdentityHeader

            if showsMediumTrailingTagChrome {
                mediumDetentTrailingTagChrome
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var diveIdentityHeader: some View {
        if let siteTitle, let dateDashTimeLine {
            DiveActivityMapOverviewHeader(
                activityKind: activityKind,
                diveNumberChip: diveNumberChip,
                siteTitle: siteTitle,
                linkedCatalogSiteID: linkedCatalogSiteID,
                onOpenLinkedSite: onOpenLinkedSite,
                regionCountryLine: regionCountryLine,
                dateDashTimeLine: dateDashTimeLine
            )
        } else {
            Spacer(minLength: 0)
        }
    }

    private var mediumDetentTrailingTagChrome: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if showsMarineLifeTagInSheet {
                mediumSheetMarineLifeChromeButton
            }

            if showsBuddyTagInSheet {
                mediumSheetBuddyChromeButton
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveOverview.MediaMediumTrailingTagChrome")
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
            ActivityMediaCarouselView(
                mediaItems: mediaItems,
                selectedMediaID: $selectedMediaID,
                featuredMediaID: featuredMediaID,
                onToggleFeatured: isImportInProgress ? nil : onToggleFeatured,
                onUserSelectMedia: isImportInProgress ? nil : onUserSelectMedia
            )

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

    private var buddiesTagsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(DiveMediaBuddyTagPresentation.mediumSectionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .textCase(.uppercase)

            if taggedBuddies.isEmpty {
                Button {
                    openBuddyTaggingOrOverview()
                } label: {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "person.2")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.accent)
                            .accessibilityHidden(true)

                        Text(DiveMediaBuddyTagPresentation.mediumUntaggedPrompt)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .disabled(onTagBuddies == nil && onExpandMarineLifeDetail == nil)
            } else {
                mediumDetentBuddyChips
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveOverview.MediaBuddyTags")
    }

    private var mediumDetentMarineLifeTagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MarineLifeMediaTagPresentation.chipRowSpacing) {
                ForEach(taggedSpecies, id: \.uuid) { species in
                    if let onExpandMarineLifeDetail {
                        Button {
                            selectedTaggedSpeciesUUID = species.uuid
                            largeDetentMode = .marineLife
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

    private var mediumDetentBuddyChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DiveMediaBuddyTagPresentation.mediumChipRowSpacing) {
                ForEach(taggedBuddies, id: \.id) { buddy in
                    if let onExpandMarineLifeDetail {
                        Button {
                            largeDetentMode = .buddies
                            onExpandMarineLifeDetail()
                        } label: {
                            DiveActivityBuddyAvatarChip(
                                displayName: buddy.displayName,
                                profilePhoto: buddy.profilePhoto,
                                avatarDiameter: DiveMediaBuddyTagPresentation.mediumAvatarDiameter
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows buddy details")
                        .accessibilityIdentifier("DiveOverview.MediaBuddyTag.\(buddy.id.uuidString)")
                    } else {
                        DiveActivityBuddyAvatarChip(
                            displayName: buddy.displayName,
                            profilePhoto: buddy.profilePhoto,
                            avatarDiameter: DiveMediaBuddyTagPresentation.mediumAvatarDiameter
                        )
                        .accessibilityIdentifier("DiveOverview.MediaBuddyTag.\(buddy.id.uuidString)")
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func openBuddyTaggingOrOverview() {
        if DiveActivityMediaPresentation.opensBuddyOverviewOnSheetBuddyTap(detent: sheetDetent),
           let onExpandMarineLifeDetail
        {
            largeDetentMode = .buddies
            onExpandMarineLifeDetail()
        } else {
            onTagBuddies?()
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

typealias DiveActivityPhotosPanelContent = ActivityPhotosPanelContent<DiveMediaPhoto>
typealias SnorkelActivityPhotosPanelContent = ActivityPhotosPanelContent<SnorkelMediaPhoto>
