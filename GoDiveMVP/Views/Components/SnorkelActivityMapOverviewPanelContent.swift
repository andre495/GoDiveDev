import SwiftUI
import SwiftData

/// Map-tab overview panel for snorkel activities.
struct SnorkelActivityMapOverviewPanelContent: View {
    @Bindable var activity: SnorkelActivity
    @Binding var overviewSheetDetent: DiveActivityOverviewDetent
    let mapCoordinate: DiveCoordinate?
    let siteTitle: String
    let linkedCatalogSiteID: UUID?
    let onOpenLinkedSite: () -> Void
    let regionCountryLine: String?
    let onEditNotes: () -> Void
    var opensCommentsOnAppear: Bool = false
    var onOpenCommentsOnAppearConsumed: (() -> Void)? = nil

    @Environment(\.diveOverviewPanelHeightFraction) private var panelHeightFraction
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem
    @Environment(AccountSession.self) private var accountSession
    @AppStorage(AppUserSettings.shareDivesWithFriendsKey) private var shareDivesWithFriends = true

    private var showsStatsBox: Bool {
        DiveActivityOverviewPanelMetrics.mapPanelShowsStatsBox(
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

    private var showsDetailsSection: Bool {
        DiveActivityOverviewPanelMetrics.mapPanelShowsDetails(
            restingDetent: overviewSheetDetent,
            heightFraction: panelHeightFraction
        )
    }

    private var detailsOpacity: CGFloat {
        DiveActivityOverviewPanelMetrics.mapDetailsPresentationOpacity(
            restingDetent: overviewSheetDetent,
            heightFraction: panelHeightFraction
        )
    }

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

            if showsStatsBox {
                DiveActivityMapOverviewStatsBox(
                    layout: mapStatsLayout,
                    fillsAvailableHeight: false,
                    showsEditButton: false,
                    onEdit: {}
                )
                .frame(height: statsBoxHeight, alignment: .top)
                .clipped()
            }

            if showsDetailsSection {
                mapDetailsSection
                    .opacity(detailsOpacity)
                    .allowsHitTesting(detailsOpacity > 0.35)
                    .accessibilityHidden(detailsOpacity < 0.05)
            }
        }
        .animation(nil, value: panelHeightFraction)
        .animation(.diveOverviewPanelDetent, value: overviewSheetDetent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsOwnedMapSocial: Bool {
        _ = shareDivesWithFriends
        return OwnedActivityMapSocialPresentation.shouldShowSocial(
            isPublishedWithFriends: ActivityFriendShareConfiguration.shouldPublish(snorkel: activity),
            firebaseUID: GoDiveFirebaseAuthSession.currentFirebaseUID()
        )
    }

    private var mapDetailsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if showsOwnedMapSocial,
               let ownerUID = GoDiveFirebaseAuthSession.currentFirebaseUID()
            {
                FriendSharedActivityMapSocialSection(
                    ownerUID: ownerUID,
                    activityID: activity.id.uuidString,
                    seedLikeCount: 0,
                    seedCommentCount: 0,
                    authorDisplayName: accountSession.currentProfile?.displayName ?? "A dive buddy",
                    opensCommentsOnAppear: opensCommentsOnAppear,
                    onOpenCommentsOnAppearConsumed: onOpenCommentsOnAppearConsumed,
                    allowsLiking: OwnedActivityMapSocialPresentation.allowsOwnerLiking
                )
            }

            ActivityMapWeatherConditionsSection(
                activityID: activity.id,
                mapCoordinate: mapCoordinate,
                activityStart: activity.startTime,
                timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds,
                displayUnits: diveDisplayUnitSystem,
                isSectionVisible: overviewSheetDetent == .large,
                importedSnapshot: ActivityWeatherSnapshotStorage.displaySnapshot(
                    from: activity.activityWeatherSnapshotData,
                    activityStart: activity.startTime,
                    timeZoneOffsetSeconds: activity.timeZoneOffsetSeconds,
                    displayUnits: diveDisplayUnitSystem
                )
            )

            SnorkelActivityNotesOverviewSection(
                notes: activity.notes,
                mentionDisplayNames: GoDiveMentionPresentation.knownDisplayNames(
                    taggedBuddyNames: activity.buddies.compactMap { $0.buddy?.displayName }
                ),
                onEditNotes: onEditNotes
            )
        }
        .accessibilityIdentifier("SnorkelOverview.MapDetailsSection")
    }

    private var mapOverviewHeader: some View {
        DiveActivityMapOverviewHeader(
            activityKind: .snorkel,
            diveNumberChip: nil,
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
        SnorkelActivityOverviewPresentation.mapOverviewStatsLayout(
            durationMinutes: activity.durationMinutes,
            swimDistanceMeters: activity.swimDistanceMeters,
            maxDepthMeters: activity.maxDepthMeters,
            avgTemperatureCelsius: activity.avgTemperatureCelsius,
            displayUnits: diveDisplayUnitSystem
        )
    }
}
