import SwiftUI

/// Read-only **Media** overview sheet for friend activities — mirrors owned **`ActivityPhotosPanelContent`**
/// (carousel at **minimized**, tagged species / buddy detail at **large**) without import or tagging controls.
struct FriendSharedActivityMediaPanelContent: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    @Binding var overviewSheetDetent: DiveActivityOverviewDetent
    var layoutHeight: CGFloat = 0
    @Binding var selectedPreviewID: String?

    @State private var selectedTaggedSpeciesUUID: String?
    @State private var largeDetentMode: DiveActivityMediaLargeDetentMode = .marineLife

    private var displayItems: [FriendSharedMediaPresentation.DisplayItem] {
        FriendSharedMediaPresentation.orderedDisplayItems(for: dive)
    }

    private var sheetDetent: DiveActivityOverviewDetent {
        overviewSheetDetent
    }

    private var showsMediaCarousel: Bool {
        DiveActivityMediaPresentation.showsMediaCarouselInSheet(for: sheetDetent)
    }

    private var showsMarineLifeDetail: Bool {
        DiveActivityMediaPresentation.showsMarineLifeDetailInSheet(for: sheetDetent)
    }

    private var usesCarouselPinnedLayout: Bool {
        showsMediaCarousel && sheetDetent != .minimized && layoutHeight > 0
    }

    private var pinsCarouselToSheetBottom: Bool {
        DiveActivityMediaPresentation.pinsMediaCarouselToSheetBottom(for: sheetDetent)
    }

    private var taggedSpecies: [MarineLife] {
        FriendSharedActivityDetailPresentation.displayMarineLife(from: dive)
    }

    private var taggedBuddies: [DiveBuddy] {
        FriendSharedActivityDetailPresentation.displayBuddies(
            from: dive,
            mediaID: resolvedSelectedMediaID
        )
    }

    private var featuredMediaID: String? {
        FriendSharedMediaPresentation.resolvedFeaturedMediaID(for: dive)
    }

    private var resolvedSelectedMediaID: String? {
        FriendSharedMediaPresentation.resolvedSelectedMediaID(
            selectedID: selectedPreviewID,
            in: displayItems,
            preferredID: featuredMediaID
        )
    }

    private var activityKind: ActivityOverviewHeaderKind {
        dive.resolvedActivityKind == .snorkel ? .snorkel : .scubaDive
    }

    var body: some View {
        Group {
            if displayItems.isEmpty {
                emptyPanelBody
            } else {
                mediaPanelBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: selectedPreviewID) { _, _ in
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

    private var emptyPanelBody: some View {
        Text(GoDiveFriendsPresentation.mediaHiddenLabel)
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, AppTheme.Spacing.md)
    }

    @ViewBuilder
    private var mediaPanelBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if showsMarineLifeDetail {
                DiveActivityMediaLargeDetentOverviewContent(
                    mode: $largeDetentMode,
                    media: nil,
                    taggedSpecies: taggedSpecies,
                    taggedBuddies: taggedBuddies,
                    onTagMarineLife: nil,
                    onTagBuddies: nil,
                    onIdentifyFish: nil,
                    selectedTaggedSpeciesUUID: $selectedTaggedSpeciesUUID,
                    overlaysChrome: true,
                    onCollapseToMedium: {
                        withAnimation(.diveOverviewPanelDetent) {
                            overviewSheetDetent = .large
                        }
                    }
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
            diveIdentityHeader

            if DiveActivityMediaPresentation.showsMarineLifeTagSummaryInSheet(for: sheetDetent) {
                readOnlyMarineLifeSummary
            }

            if DiveActivityMediaPresentation.showsBuddyTagSummaryInSheet(for: sheetDetent) {
                readOnlyBuddySummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var diveIdentityHeader: some View {
        DiveActivityMapOverviewHeader(
            activityKind: activityKind,
            diveNumberChip: FriendSharedActivityDetailPresentation.diveNumberChip(for: dive),
            siteTitle: FriendSharedActivityDetailPresentation.siteHeaderTitle(for: dive),
            linkedCatalogSiteID: nil,
            onOpenLinkedSite: nil,
            regionCountryLine: FriendSharedActivityDetailPresentation.regionCountryLine(for: dive),
            dateDashTimeLine: FriendSharedActivityDetailPresentation.dateDashTimeLine(for: dive)
        )
    }

    private var carouselRow: some View {
        FriendSharedActivityMediaCarouselView(
            items: displayItems,
            selectedMediaID: $selectedPreviewID,
            featuredMediaID: featuredMediaID
        )
    }

    @ViewBuilder
    private var readOnlyMarineLifeSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(MarineLifeMediaTagPresentation.sectionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .textCase(.uppercase)

            if taggedSpecies.isEmpty {
                Text(MarineLifeMediaTagPresentation.untaggedPrompt)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .multilineTextAlignment(.leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MarineLifeMediaTagPresentation.chipRowSpacing) {
                        ForEach(taggedSpecies, id: \.uuid) { species in
                            Button {
                                selectedTaggedSpeciesUUID = species.uuid
                                largeDetentMode = .marineLife
                                withAnimation(.diveOverviewPanelDetent) {
                                    overviewSheetDetent = .large
                                }
                            } label: {
                                ActivityTagOvalChipLabel(
                                    title: MarineLifeMediaTagPresentation.chipDisplayTitle(
                                        for: species.commonName
                                    ),
                                    showsFishialBadge: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("FriendSharedDiveDetail.MediaMarineLifeTags")
    }

    @ViewBuilder
    private var readOnlyBuddySummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(DiveMediaBuddyTagPresentation.mediumSectionTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
                .textCase(.uppercase)

            if taggedBuddies.isEmpty {
                Text(DiveMediaBuddyTagPresentation.mediumUntaggedPrompt)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .multilineTextAlignment(.leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(taggedBuddies, id: \.id) { buddy in
                            Button {
                                largeDetentMode = .buddies
                                withAnimation(.diveOverviewPanelDetent) {
                                    overviewSheetDetent = .large
                                }
                            } label: {
                                DiveActivityBuddyAvatarChip(
                                    displayName: buddy.displayName,
                                    profilePhoto: buddy.profilePhoto,
                                    avatarDiameter: DiveMediaBuddyTagPresentation.mediumAvatarDiameter,
                                    showsGoDiveUserPin: DiveBuddyFriendLinkPresentation.isLinkedFriend(buddy)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("FriendSharedDiveDetail.MediaBuddyTags")
    }
}

/// Horizontal thumbnail strip for friend-shared media — mirrors **`ActivityMediaCarouselView`**.
struct FriendSharedActivityMediaCarouselView: View {
    private struct MediaSelectionSignature: Equatable {
        var count: Int
        var firstID: String?
        var lastID: String?
    }

    let items: [FriendSharedMediaPresentation.DisplayItem]
    @Binding var selectedMediaID: String?
    var featuredMediaID: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DiveActivityMediaPresentation.carouselThumbnailSpacing) {
                    ForEach(items) { item in
                        carouselItem(for: item)
                            .id(item.mediaID)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: DiveActivityMediaPresentation.carouselRowHeight)
            .accessibilityIdentifier("FriendSharedDiveDetail.MediaCarousel")
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
            count: items.count,
            firstID: items.first?.mediaID,
            lastID: items.last?.mediaID
        )
    }

    private func carouselItem(for item: FriendSharedMediaPresentation.DisplayItem) -> some View {
        let isSelected = selectedMediaID == item.mediaID
        let isFeatured = item.mediaID == featuredMediaID
        let showsStar = DiveActivityMediaPresentation.showsCarouselFeaturedStar(
            isSelected: isSelected,
            isFeatured: isFeatured
        )

        return ZStack(alignment: .topTrailing) {
            Button {
                guard selectedMediaID != item.mediaID else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    selectedMediaID = item.mediaID
                }
            } label: {
                carouselThumbnail(for: item, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(thumbnailAccessibilityLabel(for: item, isFeatured: isFeatured))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("FriendSharedDiveDetail.MediaCarousel.Item.\(item.mediaID)")

            if showsStar {
                Image(systemName: "star.fill")
                    .font(
                        .system(
                            size: DiveActivityMediaPresentation.carouselFeaturedStarFontSize(
                                isSelected: isSelected
                            ),
                            weight: .bold
                        )
                    )
                    .foregroundStyle(AppTheme.Colors.accent)
                    .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                    .padding(5)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Featured photo")
            }
        }
    }

    private func carouselThumbnail(
        for item: FriendSharedMediaPresentation.DisplayItem,
        isSelected: Bool
    ) -> some View {
        let size = DiveActivityMediaPresentation.carouselThumbnailExtent(isSelected: isSelected)
        let cornerRadius = DiveActivityMediaPresentation.carouselThumbnailCornerRadius

        return FriendSharedMediaImageView(
            item: item,
            fidelity: .thumbnailOnly,
            showsVideoBadge: true
        )
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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

    private func thumbnailAccessibilityLabel(
        for item: FriendSharedMediaPresentation.DisplayItem,
        isFeatured: Bool
    ) -> String {
        let kind = item.kind == .video ? "Video" : "Photo"
        let featured = isFeatured ? "Featured " : ""
        if selectedMediaID == item.mediaID {
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
