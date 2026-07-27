import SwiftUI

// MARK: - Map panel

struct FriendSharedActivityMapPanelContent: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    let friendName: String
    let showsTaggedYou: Bool
    @Binding var overviewSheetDetent: DiveActivityOverviewDetent

    @Environment(\.diveOverviewPanelHeightFraction) private var panelHeightFraction
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            mapOverviewHeader
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard overviewSheetDetent == .minimized else { return }
                    withAnimation(.diveOverviewPanelDetent) {
                        overviewSheetDetent = .large
                    }
                }
                .accessibilityAddTraits(overviewSheetDetent == .minimized ? .isButton : [])
                .accessibilityHint(overviewSheetDetent == .minimized ? "Expands activity details" : "")

            if showsStatsBox {
                DiveActivityMapOverviewStatsBox(
                    layout: mapStatsLayout,
                    fillsAvailableHeight: false,
                    showsEditButton: false
                )
                .frame(height: statsBoxHeight, alignment: .top)
                .clipped()
            }

            if showsDetailsSection {
                FriendSharedActivityReadOnlySectionsView(
                    dive: dive,
                    friendName: friendName,
                    showsTaggedYou: showsTaggedYou
                )
                .opacity(detailsOpacity)
                .offset(y: detailsVerticalOffset)
                .allowsHitTesting(detailsOpacity > 0.35)
                .accessibilityHidden(detailsOpacity < 0.05)
            }
        }
        .animation(.diveOverviewPanelDetent, value: panelHeightFraction)
        .animation(.diveOverviewPanelDetent, value: overviewSheetDetent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mapOverviewHeader: some View {
        DiveActivityMapOverviewHeader(
            activityKind: dive.resolvedActivityKind == .snorkel ? .snorkel : .scubaDive,
            diveNumberChip: FriendSharedActivityDetailPresentation.diveNumberChip(for: dive),
            siteTitle: FriendSharedActivityDetailPresentation.siteHeaderTitle(for: dive),
            linkedCatalogSiteID: nil,
            onOpenLinkedSite: nil,
            regionCountryLine: FriendSharedActivityDetailPresentation.regionCountryLine(for: dive),
            dateDashTimeLine: FriendSharedActivityDetailPresentation.dateDashTimeLine(for: dive)
        )
    }

    private var mapStatsLayout: DiveActivityOverviewPresentation.MapOverviewStatsLayout {
        switch dive.resolvedActivityKind {
        case .scubaDive:
            FriendSharedActivityDetailPresentation.scubaMapStatsLayout(
                for: dive,
                unitSystem: diveDisplayUnitSystem
            )
        case .snorkel:
            FriendSharedActivityDetailPresentation.snorkelMapStatsLayout(
                for: dive,
                unitSystem: diveDisplayUnitSystem
            )
        }
    }

    private var showsStatsBox: Bool {
        DiveActivityOverviewPanelMetrics.mapPanelShowsStatsBox(
            restingDetent: overviewSheetDetent,
            heightFraction: panelHeightFraction
        )
    }

    private var showsDetailsSection: Bool {
        DiveActivityOverviewPanelMetrics.mapPanelShowsDetails(
            restingDetent: overviewSheetDetent,
            heightFraction: panelHeightFraction
        )
    }

    private var statsBoxHeight: CGFloat {
        DiveActivityOverviewPanelMetrics.mapStatsBoxRevealHeight(
            restingDetent: overviewSheetDetent,
            heightFraction: panelHeightFraction,
            expandedHeight: DiveActivityMapOverviewStatsBox.estimatedExpandedHeight
        )
    }

    private var detailsOpacity: CGFloat {
        DiveActivityOverviewPanelMetrics.mapDetailsPresentationOpacity(
            restingDetent: overviewSheetDetent,
            heightFraction: panelHeightFraction
        )
    }

    private var detailsVerticalOffset: CGFloat {
        guard overviewSheetDetent != .large else { return 0 }
        let reveal = DiveActivityOverviewPanelMetrics.mapDetailsRevealProgress(
            heightFraction: panelHeightFraction
        )
        return (1 - reveal) * 10
    }
}

// MARK: - Tank panel (scuba)

struct FriendSharedActivityTankPanelContent: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    let friendName: String
    let showsTaggedYou: Bool
    @Binding var overviewSheetDetent: DiveActivityOverviewDetent

    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if overviewSheetDetent != .minimized {
                DiveActivityMapOverviewHeader(
                    diveNumberChip: FriendSharedActivityDetailPresentation.diveNumberChip(for: dive),
                    siteTitle: FriendSharedActivityDetailPresentation.siteHeaderTitle(for: dive),
                    linkedCatalogSiteID: nil,
                    onOpenLinkedSite: nil,
                    regionCountryLine: FriendSharedActivityDetailPresentation.regionCountryLine(for: dive),
                    dateDashTimeLine: FriendSharedActivityDetailPresentation.dateDashTimeLine(for: dive)
                )
            }

            tankGasSection

            FriendSharedActivityReadOnlySectionsView(
                dive: dive,
                friendName: friendName,
                showsTaggedYou: showsTaggedYou
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tankGasSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Tank & gas")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)

            VStack(spacing: 0) {
                readOnlyRow("Tank", dive.tankVolumeDescription)
                readOnlyRow("Gas", dive.gasType)
                if let mix = dive.oxygenMix {
                    readOnlyRow("O₂", String(format: "%.0f%%", mix))
                }
                readOnlyRow(
                    "Start pressure",
                    FriendSharedActivityDetailPresentation.formattedPressure(
                        psi: dive.tankPressureStartPSI,
                        unitSystem: diveDisplayUnitSystem
                    )
                )
                readOnlyRow(
                    "End pressure",
                    FriendSharedActivityDetailPresentation.formattedPressure(
                        psi: dive.tankPressureEndPSI,
                        unitSystem: diveDisplayUnitSystem
                    )
                )
                if let temp = dive.waterTempMinCelsius {
                    readOnlyRow(
                        "Min water temp",
                        DiveQuantityFormatting.waterTemperature(
                            celsius: temp,
                            system: diveDisplayUnitSystem
                        )
                    )
                }
            }
            .padding(AppTheme.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func readOnlyRow(_ label: String, _ value: String?) -> some View {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty, trimmed != "—" {
            HStack {
                Text(label)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                Spacer()
                Text(trimmed)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .font(.body)
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Heart rate panel (snorkel)

struct FriendSharedActivityHeartRatePanelContent: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    let friendName: String
    let showsTaggedYou: Bool
    let snorkelSnapshot: FriendSharedActivityDetailPresentation.SnorkelDerivedSnapshot
    @Binding var overviewSheetDetent: DiveActivityOverviewDetent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SnorkelHeartRateOverviewPanelContent(
                siteTitle: FriendSharedActivityDetailPresentation.siteHeaderTitle(for: dive),
                linkedCatalogSiteID: nil,
                onOpenLinkedSite: nil,
                regionCountryLine: FriendSharedActivityDetailPresentation.regionCountryLine(for: dive),
                dateDashTimeLine: FriendSharedActivityDetailPresentation.dateDashTimeLine(for: dive),
                overviewSheetDetent: $overviewSheetDetent,
                avgHeartRateBPM: snorkelSnapshot.avgHeartRateBPM,
                maxHeartRateBPM: snorkelSnapshot.maxHeartRateBPM,
                profileHeartRateStats: snorkelSnapshot.heartRateStats,
                totalCalories: nil
            )

            FriendSharedActivityReadOnlySectionsView(
                dive: dive,
                friendName: friendName,
                showsTaggedYou: showsTaggedYou
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Media panel

struct FriendSharedActivityMediaPanelContent: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    let friendName: String
    let showsTaggedYou: Bool
    @Binding var selectedPreviewID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if dive.mediaPreviews.isEmpty {
                Text(GoDiveFriendsPresentation.mediaHiddenLabel)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppTheme.Spacing.md)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 108), spacing: AppTheme.Spacing.sm)],
                    spacing: AppTheme.Spacing.sm
                ) {
                    ForEach(dive.mediaPreviews, id: \.photoID) { preview in
                        Button {
                            selectedPreviewID = preview.photoID
                        } label: {
                            FriendSharedMediaPreviewThumbnail(preview: preview)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            FriendSharedActivityReadOnlySectionsView(
                dive: dive,
                friendName: friendName,
                showsTaggedYou: showsTaggedYou,
                showsNotesAndTags: false
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FriendSharedMediaPreviewThumbnail: View {
    let preview: GoDiveSharedDiveProjectionMapping.MediaPreviewSnapshot

    var body: some View {
        AsyncImage(url: URL(string: preview.previewURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                AppTheme.Colors.surfaceElevated
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .frame(minWidth: 108, minHeight: 108)
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Shared read-only sections

struct FriendSharedActivityReadOnlySectionsView: View {
    let dive: GoDiveSharedDiveProjectionMapping.FriendVisibleDive
    let friendName: String
    let showsTaggedYou: Bool
    var showsNotesAndTags: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            sharedBySection

            if showsTaggedYou {
                Label(
                    GoDiveFriendsPresentation.taggedYouLabel,
                    systemImage: "person.crop.circle.badge.checkmark"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.accent)
            }

            if showsNotesAndTags {
                notesSection
                tagsSection
            }

            buddiesSection
            marineLifeSection
            equipmentSection
        }
    }

    private var sharedBySection: some View {
        HStack {
            Text("Shared by")
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Spacer()
            Text(friendName)
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .font(.body)
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = dive.notes, !notes.isEmpty {
            sectionCard(title: "Notes") {
                Text(notes)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(GoDiveFriendsPresentation.notesHiddenLabel)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !dive.activityTagNames.isEmpty {
            ActivityTagsOutlinedSection(appliesLogbookOuterMargins: false) {
                EmptyView()
            } content: {
                DiveActivityTagChipFlow(tagNames: dive.activityTagNames)
            }
        }
    }

    @ViewBuilder
    private var buddiesSection: some View {
        if !dive.taggedBuddies.isEmpty {
            sectionCard(title: "Buddies") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(dive.taggedBuddies.enumerated()), id: \.offset) { _, buddy in
                        Text(buddy.displayName)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var marineLifeSection: some View {
        if !dive.sightings.isEmpty {
            sectionCard(title: "Marine life") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(dive.sightings.enumerated()), id: \.offset) { _, sighting in
                        Text(sighting.commonName)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var equipmentSection: some View {
        if !dive.equipmentSummary.isEmpty {
            sectionCard(title: "Equipment") {
                Text(dive.equipmentSummary.joined(separator: ", "))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
            content()
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.Colors.tabUnselected.opacity(0.12), lineWidth: 1)
        }
    }
}
