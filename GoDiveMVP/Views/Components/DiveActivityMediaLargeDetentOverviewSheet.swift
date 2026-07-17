import SwiftUI

/// Shared dive Media **large** detent overview — fish/buddy toggle, **+**, species detail / buddy grid.
struct DiveActivityMediaLargeDetentOverviewContent: View {
    private struct BuddyDetailCover: Identifiable {
        let buddy: DiveBuddy
        var id: UUID { buddy.id }
    }

    private struct SpeciesDetailCover: Identifiable {
        let species: MarineLife
        var id: String { species.uuid }
    }

    @Binding var mode: DiveActivityMediaLargeDetentMode
    let media: DiveMediaPhoto?
    let taggedSpecies: [MarineLife]
    let taggedBuddies: [DiveBuddy]
    var onTagMarineLife: (() -> Void)?
    var onTagBuddies: (() -> Void)?
    /// Opens Fishial identify when marine-life mode chrome shows sparkles (configured builds only).
    var onIdentifyFish: (() -> Void)? = nil
    /// Field Guide / buddy detail owners — used when opening **Learn More** or a buddy avatar.
    var ownerProfileID: UUID? = nil
    var onOpenDive: ((UUID) -> Void)? = nil
    @Binding var selectedTaggedSpeciesUUID: String?
    /// When true, draws the toggle/**+** row pinned above scroll. When false, only body content.
    var overlaysChrome: Bool = true
    /// Soft-collapse the dive overview panel when the user overscrolls past the top of tagged detail.
    var onCollapseToMedium: (() -> Void)? = nil

    @State private var buddyDetailCover: BuddyDetailCover?
    @State private var speciesDetailCover: SpeciesDetailCover?

    private var addTagAction: (() -> Void)? {
        switch mode {
        case .marineLife: onTagMarineLife
        case .buddies: onTagBuddies
        }
    }

    private var showsFishialIdentifyAction: Bool {
        mode == .marineLife
            && onIdentifyFish != nil
            && DiveMarineLifeTagSheetPresentation.showsFishialIdentifyAction
    }

    private var resolvedSelectedSpecies: MarineLife? {
        guard let resolvedUUID = DiveActivityMediaPresentation.resolvedTaggedSpeciesUUID(
            selectedUUID: selectedTaggedSpeciesUUID,
            taggedSpeciesUUIDs: taggedSpecies.map(\.uuid)
        ) else { return nil }
        return taggedSpecies.first(where: { $0.uuid == resolvedUUID })
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            pinnedChromeScrollHost

            if overlaysChrome {
                chromeRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: taggedSpecies.map(\.uuid)) { _, uuids in
            if let selectedTaggedSpeciesUUID, uuids.contains(selectedTaggedSpeciesUUID) {
                return
            }
            selectedTaggedSpeciesUUID = uuids.first
        }
        .fullScreenCover(item: $buddyDetailCover) { cover in
            NavigationStack {
                ViewDiveBuddyDetails(buddy: cover.buddy)
                    .hidesBottomTabBarWhenPushed()
            }
        }
        .fullScreenCover(item: $speciesDetailCover) { cover in
            NavigationStack {
                FieldGuideMarineLifeDetailView(
                    species: cover.species,
                    ownerProfileID: ownerProfileID,
                    onOpenDive: { diveID in
                        speciesDetailCover = nil
                        onOpenDive?(diveID)
                    }
                )
                .hidesBottomTabBarWhenPushed()
            }
        }
    }

    private var scrollFadeHeight: CGFloat {
        overlaysChrome
            ? DiveActivityMediaPresentation.largeDetentPinnedChromeScrollFadeHeight
            : 0
    }

    @ViewBuilder
    private var pinnedChromeScrollHost: some View {
        if let onCollapseToMedium {
            OverviewPanelScrollArea(
                restingDetent: .large,
                onExpand: {},
                onCollapseToMedium: onCollapseToMedium,
                topScrollFadeHeight: scrollFadeHeight
            ) {
                scrollableBody
            }
        } else {
            ScrollView {
                scrollableBody
            }
            .scrollIndicators(.hidden)
            .overviewPanelTopScrollFade(height: scrollFadeHeight)
        }
    }

    private var scrollableBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if overlaysChrome {
                Color.clear
                    .frame(height: DiveActivityMediaPresentation.largeDetentTagOverviewChromeHeight)
                    .accessibilityHidden(true)
            }

            switch mode {
            case .marineLife:
                marineLifeBody
            case .buddies:
                buddiesBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var chromeRow: some View {
        ZStack {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Spacer(minLength: 0)

                trailingChromeActions
            }

            DiveActivityMediaLargeDetentModeToggle(selectedMode: $mode)
        }
    }

    @ViewBuilder
    private var trailingChromeActions: some View {
        switch mode {
        case .marineLife:
            if showsFishialIdentifyAction || onTagMarineLife != nil {
                DiveActivityMediaLargeDetentMarineLifeTrailingActions(
                    showsFishialIdentifyAction: showsFishialIdentifyAction,
                    onIdentifyFish: onIdentifyFish,
                    onAddTags: onTagMarineLife,
                    addTagsAccessibilityLabel: DiveActivityMediaLargeDetentMode.marineLife.addTagsAccessibilityLabel,
                    addTagsAccessibilityIdentifier: DiveActivityMediaLargeDetentMode.marineLife.addTagsAccessibilityIdentifier
                )
            }
        case .buddies:
            if let addTagAction {
                LinkedMediaTaggedOverviewAddTagsButton(
                    accessibilityLabel: mode.addTagsAccessibilityLabel,
                    accessibilityIdentifier: mode.addTagsAccessibilityIdentifier
                ) {
                    addTagAction()
                }
            }
        }
    }

    @ViewBuilder
    private var marineLifeBody: some View {
        if taggedSpecies.isEmpty {
            untaggedMarineLifePrompt
        } else {
            if taggedSpecies.count > 1 {
                DiveActivityMediaTaggedSpeciesSelector(
                    species: taggedSpecies,
                    media: media,
                    selectedUUID: $selectedTaggedSpeciesUUID
                )
            } else if let species = taggedSpecies.first {
                ActivityTagOvalChipLabel(
                    title: MarineLifeMediaTagPresentation.chipDisplayTitle(for: species.commonName),
                    showsFishialBadge: fishialBadge(for: species)
                )
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityIdentifier("DiveOverview.MediaMarineLifeTag.\(species.uuid)")
            }

            if let resolvedSelectedSpecies {
                DiveActivityMediaTaggedSpeciesDetailContent(
                    species: resolvedSelectedSpecies
                )

                Button {
                    speciesDetailCover = SpeciesDetailCover(species: resolvedSelectedSpecies)
                } label: {
                    Text(MarineLifeMediaTagPresentation.learnMoreLabel)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("DiveOverview.MediaLargeLearnMore")
            }
        }
    }

    @ViewBuilder
    private var buddiesBody: some View {
        if taggedBuddies.isEmpty {
            untaggedBuddiesPrompt
        } else {
            LazyVGrid(
                columns: buddyColumns,
                spacing: LinkedMediaTaggedBuddiesSheetPresentation.gridSpacing
            ) {
                ForEach(taggedBuddies, id: \.id) { buddy in
                    buddyCell(for: buddy)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("DiveOverview.MediaLargeBuddyGrid")
        }
    }

    private var buddyColumns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(),
                spacing: LinkedMediaTaggedBuddiesSheetPresentation.gridSpacing
            ),
            count: LinkedMediaTaggedBuddiesSheetPresentation.columnCount
        )
    }

    private func buddyCell(for buddy: DiveBuddy) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Button {
                buddyDetailCover = BuddyDetailCover(buddy: buddy)
            } label: {
                ProfileAvatarView(
                    profilePhoto: buddy.profilePhoto,
                    diameter: LinkedMediaTaggedBuddiesSheetPresentation.avatarDiameter,
                    iconFont: .title2,
                    placeholderInitials: DiveBuddyPresentation.initials(from: buddy.displayName)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(buddy.displayName)")
            .accessibilityHint("Opens buddy details")
            .accessibilityIdentifier("DiveOverview.MediaLargeBuddyAvatar.\(buddy.id.uuidString)")

            Text(buddy.displayName)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .top)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveOverview.MediaLargeBuddy.\(buddy.id.uuidString)")
    }

    private var untaggedMarineLifePrompt: some View {
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

    private var untaggedBuddiesPrompt: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Image(systemName: "person.2")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityHidden(true)

            Text(DiveMediaBuddyTagPresentation.largeDetentUntaggedPrompt)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(DiveMediaBuddyTagPresentation.largeDetentUntaggedPrompt)
        .accessibilityIdentifier("DiveOverview.MediaLargeUntaggedBuddiesPrompt")
    }

    private func fishialBadge(for species: MarineLife) -> Bool {
        guard let media else { return false }
        return DiveActivityMediaPresentation.speciesWasFishialIdentified(species: species, on: media)
    }
}

/// Frosted **large**-detent sheet matching dive Media — presented over fullscreen / gallery media.
struct DiveActivityMediaLargeDetentOverviewSheet: View {
    @Binding var mode: DiveActivityMediaLargeDetentMode
    let media: DiveMediaPhoto
    let dive: DiveActivity?
    let taggedSpecies: [MarineLife]
    let taggedBuddies: [DiveBuddy]
    @Binding var selectedTaggedSpeciesUUID: String?
    var onOpenDive: ((UUID) -> Void)? = nil

    @State private var showsMarineLifeTagPicker = false
    @State private var showsBuddyTagPicker = false
    @State private var showsFishialIdentifySheet = false

    private var canIdentifyFish: Bool {
        dive != nil && DiveMarineLifeTagSheetPresentation.showsFishialIdentifyAction
    }

    var body: some View {
        DiveActivityMediaLargeDetentOverviewContent(
            mode: $mode,
            media: media,
            taggedSpecies: taggedSpecies,
            taggedBuddies: taggedBuddies,
            onTagMarineLife: dive != nil ? { showsMarineLifeTagPicker = true } : nil,
            onTagBuddies: dive != nil ? { showsBuddyTagPicker = true } : nil,
            onIdentifyFish: canIdentifyFish ? { showsFishialIdentifySheet = true } : nil,
            ownerProfileID: dive?.ownerProfileID,
            onOpenDive: onOpenDive,
            selectedTaggedSpeciesUUID: $selectedTaggedSpeciesUUID,
            overlaysChrome: true
        )
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .appSheetContentTopSpacing()
        .accessibilityIdentifier("DiveOverview.MediaLargeDetentOverviewSheet")
        .sheet(isPresented: $showsMarineLifeTagPicker) {
            if let dive {
                DiveMarineLifeTagPickerSheet(
                    media: media,
                    dive: dive,
                    captureContext: nil,
                    onTagged: {}
                )
            }
        }
        .sheet(isPresented: $showsBuddyTagPicker) {
            if let dive {
                DiveMediaBuddyTagPickerSheet(
                    media: media,
                    dive: dive,
                    onTagged: {}
                )
            }
        }
        .sheet(isPresented: $showsFishialIdentifySheet) {
            if let dive {
                DiveMediaFishialIdentifySheet(
                    media: media,
                    dive: dive,
                    catalogSites: [],
                    captureContext: nil
                )
            }
        }
    }
}

extension View {
    /// Prefer the **embedded** translucent panel over a system **`.sheet`** when covering playing
    /// fullscreen media (system sheets composite opaquely over **`fullScreenCover`**).
    /// Kept for rare modal hosts — clears the system fill and paints dive Media frost on the content.
    func diveActivityMediaLargeDetentOverviewSheetPresentation() -> some View {
        background {
            Rectangle()
                .fill(.thinMaterial)
                .opacity(AppTheme.Sheet.embeddedOverviewTranslucentOpacity)
                .modifier(DiveActivityMediaFrostedOverlayDarkAppearance(enabled: true))
                .ignoresSafeArea(edges: .bottom)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(AppTheme.Sheet.cornerRadius)
        .presentationBackground(.clear)
        .presentationBackgroundInteraction(.enabled)
        .modifier(DiveActivityMediaFrostedOverlayDarkAppearance(enabled: true))
    }

    /// Same frosted chrome as dive Media **`usesTranslucentChrome`** — use on an in-hierarchy panel
    /// over **`LinkedMediaFullscreenView`** so video / photo stays visible underneath.
    func diveActivityMediaLargeDetentOverviewEmbeddedChrome() -> some View {
        diveActivityOverviewEmbeddedPanelChrome(translucent: true)
    }
}
