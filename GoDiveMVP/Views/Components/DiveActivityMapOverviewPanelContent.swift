import SwiftUI
import SwiftData

/// Map-tab overview panel body — reads **`diveOverviewPanelHeightFraction`** from the embedded sheet subtree.
struct DiveActivityMapOverviewPanelContent: View {
    @Bindable var activity: DiveActivity
    @Binding var overviewSheetDetent: DiveActivityOverviewDetent
    let profileGasStats: DiveActivityTankPanelSummary.ProfilePressureStats
    let siteTitle: String
    let linkedCatalogSiteID: UUID?
    let onOpenLinkedSite: () -> Void
    let regionCountryLine: String?
    let onEditSection: (DiveActivityEditableCatalog.Section) -> Void
    let onManageEquipment: () -> Void
    let onManageBuddies: () -> Void
    let onEditNotes: () -> Void
    let onAddTags: () -> Void
    let canAddTags: Bool

    @Environment(\.diveOverviewPanelHeightFraction) private var panelHeightFraction
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

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

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            mapOverviewHeader
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard overviewSheetDetent == .minimized else { return }
                    withAnimation(.diveOverviewPanelDetent) {
                        overviewSheetDetent = .medium
                    }
                }
                .accessibilityAddTraits(overviewSheetDetent == .minimized ? .isButton : [])
                .accessibilityHint(overviewSheetDetent == .minimized ? "Expands dive details" : "")

            if showsStatsBox {
                DiveActivityMapOverviewStatsBox(
                    layout: mapStatsLayout,
                    fillsAvailableHeight: false,
                    showsEditButton: DiveActivityEditableCatalog.mapStatsBoxShowsEditButton(for: activity),
                    onEdit: {
                        onEditSection(DiveActivityEditableCatalog.mapDiveSummarySection)
                    }
                )
                .frame(height: statsBoxHeight, alignment: .top)
                .clipped()
                .accessibilityIdentifier("DiveOverview.MapStatsBox")
            }

            if showsDetailsSection {
                mapDetailsSection
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

    private var mapDetailsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            DiveActivityEditableSectionsView(
                activity: activity,
                tab: .map,
                panelDetent: overviewSheetDetent,
                displayUnits: diveDisplayUnitSystem,
                profileGasStats: profileGasStats,
                onEditSection: onEditSection,
                onManageEquipment: onManageEquipment,
                onManageBuddies: onManageBuddies,
                onEditNotes: onEditNotes
            )

            DiveActivityTagsSectionView(
                tags: ActivityTagStore.sortedTags(on: activity),
                canAddTags: canAddTags,
                onAddTags: onAddTags
            )
        }
        .accessibilityIdentifier("DiveOverview.MapDetailsSection")
    }

    private var mapOverviewHeader: some View {
        DiveActivityMapOverviewHeader(
            diveNumberChip: DiveActivityOverviewPresentation.diveNumberChipLabel(
                diveNumber: activity.diveNumber,
                diveNumberExplicitlyNone: activity.diveNumberExplicitlyNone
            ),
            siteTitle: siteTitle,
            linkedCatalogSiteID: linkedCatalogSiteID,
            onOpenLinkedSite: onOpenLinkedSite,
            regionCountryLine: regionCountryLine,
            dateDashTimeLine: DiveActivityOverviewPresentation.startDateDashTimeLine(
                startTime: activity.startTime,
                timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds
            )
        )
    }

    private var mapStatsLayout: DiveActivityOverviewPresentation.MapOverviewStatsLayout {
        DiveActivityOverviewPresentation.mapOverviewStatsLayout(
            durationMinutes: activity.durationMinutes,
            maxDepthMeters: activity.maxDepthMeters,
            averageDepthMeters: activity.averageDepthMeters,
            surfaceIntervalSeconds: activity.surfaceIntervalSeconds,
            displayUnits: diveDisplayUnitSystem
        )
    }
}
