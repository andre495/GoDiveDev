import SwiftData
import SwiftUI

struct LogbookView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.diveDisplayUnitSystem) private var diveDisplayUnitSystem

    private enum Route: Hashable {
        case addActivity
        case diveDetail(UUID)
    }

    /// Newest **`startTime`** first (full instant = calendar date + time). **`id`** breaks ties deterministically.
    @Query(
        sort: [
            SortDescriptor(\DiveActivity.startTime, order: .reverse),
            SortDescriptor(\DiveActivity.id, order: .forward),
        ]
    ) private var activities: [DiveActivity]

    @State private var path: [Route] = []
    @State private var activityPendingDeletion: DiveActivity?
    /// Rows hidden until **`deletePermanently`** finishes (or fails); keeps the list responsive while **`save()`** runs (renumber is background).
    @State private var optimisticallyRemovedActivityIDs: Set<UUID> = []
    @State private var logbookHeaderClearance: CGFloat = AppTheme.Layout.appHeaderClearanceFallback

    private var ownedActivities: [DiveActivity] {
        guard let ownerID = accountSession.currentProfile?.id else { return [] }
        return activities.filter { $0.ownerProfileID == ownerID }
    }

    private var visibleActivities: [DiveActivity] {
        ownedActivities.filter { !optimisticallyRemovedActivityIDs.contains($0.id) }
    }

    @MainActor
    private var duplicateActivityIds: Set<UUID> {
        let signatures = visibleActivities.map(DiveActivityDuplicateMatcher.Signature.init)
        return DiveActivityDuplicateMatcher.idsWithDuplicates(in: signatures)
    }

    /// Row snapshots: **#** from chronology when auto-renumber is on (not live **`diveNumber`**), so background persist does not force row re-layout.
    private var logbookDisplayRows: [DiveLogbookRowDisplayData] {
        DiveLogbookDisplay.rowData(
            activities: visibleActivities,
            unitSystem: diveDisplayUnitSystem,
            duplicateIds: duplicateActivityIds,
            useChronologicalNumbers: AppUserSettings.automaticallyRenumberDives
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            AppHeaderlessPage {
                GeometryReader { proxy in
                    /// **`List`** uses **`ignoresSafeArea(edges: .top)`**, so coordinates start at the **window** top; **`AppHeader`** on Home does not, so its spacer is only the measured row. Match **row** padding to **`AppHeader`**, then add **`safeAreaInsets.top`** here only.
                    let logbookListTopInset = proxy.safeAreaInsets.top + logbookHeaderClearance
                    ZStack {
                        ZStack(alignment: .top) {
                            if !GoDiveUITestConfiguration.isActive {
                                WaterBubbleBackground()
                            }

                            Group {
                                if visibleActivities.isEmpty {
                                    logbookEmptyState
                                        .padding(.top, logbookListTopInset)
                                } else {
                                    List {
                                        Color.clear
                                            .frame(height: logbookListTopInset)
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                            .accessibilityHidden(true)

                                        ForEach(logbookDisplayRows) { row in
                                            NavigationLink(value: Route.diveDetail(row.id)) {
                                                LogbookActivityRow(data: row)
                                                    .equatable()
                                            }
                                            .buttonStyle(.plain)
                                            .navigationLinkIndicatorVisibility(.hidden)
                                            .listRowInsets(
                                                EdgeInsets(
                                                    top: 0,
                                                    leading: AppTheme.Spacing.lg,
                                                    bottom: 0,
                                                    trailing: AppTheme.Spacing.lg
                                                )
                                            )
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    activityPendingDeletion = visibleActivities.first { $0.id == row.id }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                    .listStyle(.plain)
                                    .listRowSpacing(AppTheme.Spacing.md)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .padding(.bottom, AppTheme.Spacing.md)
                                    .animation(nil, value: visibleActivities.count)
                                    .ignoresSafeArea(edges: .top)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            AppHeader(
                                title: "Logbook",
                                showsBackButton: false,
                                showsBrandWordmark: false,
                                statusBarSafeAreaTop: proxy.safeAreaInsets.top
                            ) {
                                NavigationLink(value: Route.addActivity) {
                                    Image(systemName: "plus")
                                        .font(.title3.weight(.semibold))
                                        .frame(minWidth: 44, minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add activity")
                            }
                            .zIndex(1)
                        }

                        if activityPendingDeletion != nil {
                            deleteFlowOverlay
                                .zIndex(2)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .onPreferenceChange(AppHeaderMetrics.HeightKey.self) { height in
                    if height > 0 { logbookHeaderClearance = height }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .addActivity:
                    ActivityUploadView { diveId in
                        if !path.isEmpty {
                            path.removeLast()
                        }
                        path.append(.diveDetail(diveId))
                    }
                case .diveDetail(let id):
                    if let activity = activities.first(where: { $0.id == id }) {
                        ViewSingleActivity(activity: activity)
                    } else {
                        Text("This dive is no longer in your log.")
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding()
                    }
                }
            }
        }
        .navigationInteractivePopGestureForHiddenNavBar()
    }

    private var logbookEmptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: "water.waves")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text("No dives in your log yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Tap + in the corner to import a dive (.fit or .uddf). Other sources will list dives here the same way as we add them.")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.lg)

            NavigationLink(value: Route.addActivity) {
                Text("Import a dive")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deleteFlowOverlay: some View {
        Group {
            if let activity = activityPendingDeletion {
                confirmDeleteDiveOverlay(activity: activity)
            }
        }
    }

    private func confirmDeleteDiveOverlay(activity: DiveActivity) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.16)) {
                        activityPendingDeletion = nil
                    }
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Delete dive?")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Are you sure? This cannot be undone.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center) {
                    Button("Cancel") {
                        withAnimation(.easeOut(duration: 0.16)) {
                            activityPendingDeletion = nil
                        }
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .buttonStyle(.plain)

                    Spacer(minLength: AppTheme.Spacing.lg)

                    Button("Delete") {
                        confirmDeleteDive(activity)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .buttonStyle(.plain)
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: 320, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func confirmDeleteDive(_ activity: DiveActivity) {
        let id = activity.id
        dismissDeleteOverlayImmediately()
        optimisticallyRemovedActivityIDs.insert(id)
        path.removeAll {
            if case .diveDetail(let detailId) = $0 { return detailId == id }
            return false
        }
        Task(priority: .userInitiated) { @MainActor in
            await Task.yield()
            defer { optimisticallyRemovedActivityIDs.remove(id) }
            try? await DiveActivityDeletion.deletePermanently(
                activity,
                modelContext: modelContext,
                awaitPostDeleteRenumber: false
            )
        }
    }

    /// Removes the confirmation sheet without waiting on a fade or on **`save()`**.
    private func dismissDeleteOverlayImmediately() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            activityPendingDeletion = nil
        }
    }
}

#Preview {
    LogbookView()
}
