import MapKit
import SwiftData
import SwiftUI

/// Field Guide **Sightings** tab — map hero with Strava-style embedded overview panel.
struct FieldGuideSightingsOverviewView: View {
    @Environment(AccountSession.self) private var accountSession
    @Query(sort: \SightingInstance.sightingDateTime, order: .reverse) private var sightings: [SightingInstance]
    @Query(sort: \DiveSite.siteName) private var diveSites: [DiveSite]
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    )
    private var diveActivities: [DiveActivity]

    let topChromeInset: CGFloat

    @State private var overviewSheetDetent: DiveActivityOverviewDetent = .medium

    private var ownerActivityIDs: Set<UUID> {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return Set(diveActivities.filter { $0.ownerProfileID == ownerID }.map(\.id))
    }

    private var diveSitesByID: [UUID: FieldGuideSightingsHeatPresentation.DiveSiteLocationSnapshot] {
        Dictionary(uniqueKeysWithValues: diveSites.map { site in
            (
                site.id,
                FieldGuideSightingsHeatPresentation.DiveSiteLocationSnapshot(
                    id: site.id,
                    latitude: site.latCoords,
                    longitude: site.longCoords,
                    region: site.region,
                    country: site.country
                )
            )
        })
    }

    private var sightingInputs: [FieldGuideSightingsHeatPresentation.SightingPlotInput] {
        sightings.map {
            FieldGuideSightingsHeatPresentation.SightingPlotInput(
                sightingUUID: $0.sightingUUID,
                marineLifeUUID: $0.marineLifeUUID,
                diveActivityID: $0.diveActivityID,
                diveSiteID: $0.diveSiteID
            )
        }
    }

    private var overviewData: FieldGuideSightingsHeatPresentation.OverviewData {
        FieldGuideSightingsHeatPresentation.overviewData(
            sightings: sightingInputs,
            diveSitesByID: diveSitesByID,
            ownerActivityIDs: ownerActivityIDs
        )
    }

    private var mapRegion: MKCoordinateRegion {
        FieldGuideSightingsHeatPresentation.mapRegion(for: overviewData.heatCells)
    }

    var body: some View {
        GeometryReader { geometry in
            let layoutHeight = max(geometry.size.height, 1)
            let bottomSafeInset = geometry.safeAreaInsets.bottom
            let mapCameraDetent = overviewSheetDetent.mapCameraDetent
            let mapBottomObstruction = DiveActivityOverviewDetent.bottomObstructionHeight(
                layoutHeight: layoutHeight,
                detent: mapCameraDetent,
                bottomSafeInset: bottomSafeInset
            )
            let isMapInteractive = overviewSheetDetent.allowsMapInteraction

            ZStack(alignment: .bottom) {
                FieldGuideSightingsHeatMapView(
                    heatCells: overviewData.heatCells,
                    mapRegion: mapRegion,
                    bottomContentMargin: mapBottomObstruction,
                    topObstructionHeight: topChromeInset,
                    layoutHeight: layoutHeight,
                    isUserInteractionEnabled: isMapInteractive
                )
                .allowsHitTesting(isMapInteractive)
                .ignoresSafeArea()

                DiveActivityOverviewEmbeddedPanel(
                    selectedDetent: $overviewSheetDetent,
                    layoutHeight: layoutHeight,
                    bottomSafeInset: bottomSafeInset,
                    collapsedSummary: {
                        FieldGuideSightingsCollapsedSummary(
                            totalSightings: overviewData.totalSightings,
                            uniqueSpeciesCount: overviewData.uniqueSpeciesCount,
                            regionCount: overviewData.regionCount,
                            topRegionLabel: overviewData.topRegionLabel
                        )
                    },
                    panelContent: {
                        sightingsPanelContent
                    }
                )
                .zIndex(1)
            }
            .overlay(alignment: .top) {
                DiveOverviewMapTopScrim(topObstructionHeight: topChromeInset)
                    .ignoresSafeArea(edges: .top)
            }
            .animation(.easeInOut(duration: 0.25), value: overviewSheetDetent)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("FieldGuide.Sightings.Overview")
    }

    private var sightingsPanelContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Sightings overview")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Heat map by dive region")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)

                if overviewData.plottableSightings == 0 {
                    emptyStateCopy
                } else if let topRegion = overviewData.topRegionLabel, overviewData.topRegionCount > 0 {
                    Text("Most active: \(topRegion) · \(overviewData.topRegionCount) sightings")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: AppTheme.Spacing.md) {
                statBlock(value: "\(overviewData.totalSightings)", label: "Logged")
                statBlock(value: "\(overviewData.uniqueSpeciesCount)", label: "Species")
                statBlock(value: "\(overviewData.regionCount)", label: "Regions")
            }

            if !overviewData.heatCells.isEmpty {
                regionBreakdownSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var regionBreakdownSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("By region")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)

            ForEach(overviewData.heatCells) { cell in
                HStack(alignment: .firstTextBaseline) {
                    Text(cell.regionLabel)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer(minLength: AppTheme.Spacing.sm)
                    Text("\(cell.sightingCount)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                }
            }
        }
    }

    private var emptyStateCopy: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: "binoculars.fill")
                .foregroundStyle(AppTheme.Colors.accent)
            Text("Tag marine life on dives with a linked dive site to build your heat map.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, AppTheme.Spacing.sm)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
